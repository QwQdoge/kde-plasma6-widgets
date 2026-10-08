#!/usr/bin/env python3
"""Generate a bounded local-file preview through KDE's KIO thumbnail protocol."""
from __future__ import annotations

import argparse
import ctypes
import os
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import time
import urllib.parse

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
SAFE_ENCODED = re.compile(r"^[A-Za-z0-9._~%\-]+$")
SAFE_KEY = re.compile(r"^[0-9a-f]{1,64}$")
DEFAULT_TIMEOUT = 10.0
DEFAULT_MAX_BYTES = 10 * 1024 * 1024
DEFAULT_CACHE_TTL = 24 * 60 * 60
DEFAULT_CACHE_FILES = 64
DEFAULT_CACHE_BYTES = 32 * 1024 * 1024


class PreviewError(RuntimeError):
    def __init__(self, message: str, code: int = 1):
        super().__init__(message)
        self.code = code


def fail(message: str, code: int = 1):
    raise PreviewError(message, code)


def decode_structured(value: str, label: str) -> str:
    if not value or not SAFE_ENCODED.fullmatch(value):
        fail(f"invalid {label}", 2)
    try:
        decoded = urllib.parse.unquote(value, errors="strict")
    except (UnicodeDecodeError, ValueError):
        fail(f"invalid {label} encoding", 2)
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in decoded):
        fail(f"control character in {label}", 2)
    return decoded


def local_path(value: str, label: str) -> str:
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme:
        if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
            fail(f"unsupported {label} scheme", 2)
        try:
            value = urllib.parse.unquote(parsed.path, errors="strict")
        except (UnicodeDecodeError, ValueError):
            fail(f"invalid {label} URI", 2)
    if not os.path.isabs(value):
        fail(f"{label} must be absolute", 2)
    return os.path.normpath(value)


def ensure_cache_dir(path: str) -> int:
    if os.path.lexists(path):
        st = os.lstat(path)
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
            fail("unsafe preview cache directory", 2)
    else:
        os.makedirs(path, mode=0o700, exist_ok=False)
    os.chmod(path, 0o700)
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        return os.open(path, flags)
    except OSError as exc:
        fail(f"cannot open preview cache directory: {exc}", 2)


def lstat_at(dir_fd: int, name: str):
    try:
        return os.stat(name, dir_fd=dir_fd, follow_symlinks=False)
    except FileNotFoundError:
        return None


def is_valid_cached(dir_fd: int, name: str, source_mtime: float, max_bytes: int, ttl: int) -> bool:
    st = lstat_at(dir_fd, name)
    if st is None:
        return False
    if not stat.S_ISREG(st.st_mode) or st.st_size <= 0 or st.st_size > max_bytes:
        return False
    if st.st_mtime < source_mtime or time.time() - st.st_mtime > ttl:
        return False
    fd = os.open(name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=dir_fd)
    try:
        return os.read(fd, len(PNG_SIGNATURE)) == PNG_SIGNATURE
    finally:
        os.close(fd)


def prune_cache(dir_fd: int, cache_dir: str, ttl: int, max_files: int, max_total_bytes: int) -> None:
    now = time.time()
    entries = []
    for name in os.listdir(cache_dir):
        if not name.endswith(".png") or name.startswith("."):
            continue
        st = lstat_at(dir_fd, name)
        if st is None or not stat.S_ISREG(st.st_mode):
            continue
        if now - st.st_mtime > ttl:
            try:
                os.unlink(name, dir_fd=dir_fd)
            except FileNotFoundError:
                pass
            continue
        entries.append((st.st_mtime, st.st_size, name))
    entries.sort(reverse=True)
    total = 0
    for index, (_, size, name) in enumerate(entries):
        total += size
        if index >= max_files or total > max_total_bytes:
            try:
                os.unlink(name, dir_fd=dir_fd)
            except FileNotFoundError:
                pass


def child_parent_death_signal() -> None:
    if sys.platform.startswith("linux"):
        ctypes.CDLL(None).prctl(1, signal.SIGKILL)


def terminate_process(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    except OSError:
        proc.kill()
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass


def stream_thumbnail(argv: list[str], dir_fd: int, temp_name: str, timeout: float, max_bytes: int) -> int:
    fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600, dir_fd=dir_fd)
    proc = subprocess.Popen(
        argv,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        preexec_fn=child_parent_death_signal if sys.platform.startswith("linux") else None,
    )
    assert proc.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    written = 0
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                terminate_process(proc)
                fail("thumbnail generation timed out", 3)
            events = selector.select(min(remaining, 0.25))
            if not events:
                if proc.poll() is not None:
                    break
                continue
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                break
            if written + len(chunk) > max_bytes:
                terminate_process(proc)
                fail("generated preview is too large", 4)
            os.write(fd, chunk)
            written += len(chunk)
        try:
            return_code = proc.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            terminate_process(proc)
            fail("thumbnail generation timed out", 3)
        if return_code != 0:
            fail(f"KIO thumbnailer exited with status {return_code}", 5)
        if written == 0:
            fail("KIO returned an empty preview", 5)
        os.fsync(fd)
        return written
    finally:
        selector.close()
        os.close(fd)
        terminate_process(proc)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-encoded", required=True)
    parser.add_argument("--cache-encoded", required=True)
    parser.add_argument("--cache-key", required=True)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument("--cache-ttl", type=int, default=DEFAULT_CACHE_TTL)
    parser.add_argument("--cache-files", type=int, default=DEFAULT_CACHE_FILES)
    parser.add_argument("--cache-bytes", type=int, default=DEFAULT_CACHE_BYTES)
    args = parser.parse_args()
    if args.timeout <= 0 or args.timeout > 60 or args.max_bytes < len(PNG_SIGNATURE) or args.max_bytes > DEFAULT_MAX_BYTES:
        fail("invalid resource limits", 2)
    if args.cache_ttl <= 0 or args.cache_files <= 0 or args.cache_bytes <= 0:
        fail("invalid cache limits", 2)
    return args


def main() -> int:
    args = parse_args()
    if not SAFE_KEY.fullmatch(args.cache_key):
        fail("invalid cache key", 2)
    source = local_path(decode_structured(args.source_encoded, "source"), "source")
    cache_dir = local_path(decode_structured(args.cache_encoded, "cache"), "cache")
    try:
        source_stat = os.stat(source, follow_symlinks=True)
    except OSError as exc:
        fail(f"source is not readable: {exc}", 2)
    if not stat.S_ISREG(source_stat.st_mode):
        fail("source is not a regular file", 2)

    dir_fd = ensure_cache_dir(cache_dir)
    target_name = args.cache_key + ".png"
    try:
        target_stat = lstat_at(dir_fd, target_name)
        if target_stat is not None and stat.S_ISLNK(target_stat.st_mode):
            fail("unsafe preview cache target", 2)
        if is_valid_cached(dir_fd, target_name, source_stat.st_mtime, args.max_bytes, args.cache_ttl):
            print("READY:" + os.path.join(cache_dir, target_name))
            return 0
        prune_cache(dir_fd, cache_dir, args.cache_ttl, args.cache_files, args.cache_bytes)

        kio = shutil.which("kioclient6") or shutil.which("kioclient")
        if not kio:
            fail("KIO thumbnail support is not installed", 5)
        thumbnail_uri = "thumbnail:" + urllib.parse.quote(source, safe="/")
        temp_name = f".{args.cache_key}.{os.getpid()}.{time.time_ns()}"
        try:
            stream_thumbnail([kio, "--noninteractive", "cat", thumbnail_uri], dir_fd, temp_name, args.timeout, args.max_bytes)
            fd = os.open(temp_name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=dir_fd)
            try:
                if os.read(fd, len(PNG_SIGNATURE)) != PNG_SIGNATURE:
                    fail("KIO returned an invalid preview", 5)
            finally:
                os.close(fd)
            os.chmod(temp_name, 0o600, dir_fd=dir_fd, follow_symlinks=False)
            os.replace(temp_name, target_name, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
        finally:
            try:
                os.unlink(temp_name, dir_fd=dir_fd)
            except FileNotFoundError:
                pass
        prune_cache(dir_fd, cache_dir, args.cache_ttl, args.cache_files, args.cache_bytes)
        print("READY:" + os.path.join(cache_dir, target_name))
        return 0
    finally:
        os.close(dir_fd)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PreviewError as exc:
        print("FAIL:" + str(exc), file=sys.stderr)
        raise SystemExit(exc.code)
