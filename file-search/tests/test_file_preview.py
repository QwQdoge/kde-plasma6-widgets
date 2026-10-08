import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "contents" / "tools" / "thumbnailer.py"
PNG = b"\x89PNG\r\n\x1a\n"


def encoded(value):
    return urllib.parse.quote(str(value), safe="-._~")


class ThumbnailerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.cache = self.root / "cache"
        self.cache.mkdir(mode=0o700)
        self.log = self.root / "argv.json"
        fake = self.bin / "kioclient6"
        fake.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys, time\n"
            "mode = os.environ.get('FAKE_MODE', 'ok')\n"
            "log = os.environ.get('FAKE_LOG')\n"
            "if log:\n"
            "    open(log, 'w', encoding='utf-8').write(json.dumps(sys.argv, ensure_ascii=False))\n"
            "if mode == 'sleep':\n"
            "    time.sleep(5)\n"
            "elif mode == 'huge':\n"
            "    sys.stdout.buffer.write(b'\\x89PNG\\r\\n\\x1a\\n' + b'x' * 200000)\n"
            "elif mode == 'bad':\n"
            "    sys.stdout.buffer.write(b'not a png')\n"
            "else:\n"
            "    sys.stdout.buffer.write(b'\\x89PNG\\r\\n\\x1a\\n' + b'ok')\n",
            encoding="utf-8",
        )
        fake.chmod(0o755)
        self.env = os.environ.copy()
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env.get("PATH", "")
        self.env["FAKE_LOG"] = str(self.log)

    def tearDown(self):
        self.temp.cleanup()

    def run_helper(self, source, key="aabb", *extra, mode="ok", cache=None):
        env = self.env.copy()
        env["FAKE_MODE"] = mode
        cache = cache or self.cache
        command = [
            sys.executable,
            str(HELPER),
            "--source-encoded",
            encoded(source),
            "--cache-encoded",
            encoded(cache),
            "--cache-key",
            key,
            *extra,
        ]
        return subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)

    def test_uri_boundaries_preserve_spaces_unicode_hash_and_percent(self):
        source = self.root / "a b#%测试.pdf"
        source.write_bytes(b"x")
        result = self.run_helper(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = json.loads(self.log.read_text(encoding="utf-8"))
        self.assertEqual(argv[:3], [str(self.bin / "kioclient6"), "--noninteractive", "cat"])
        self.assertEqual(argv[3], "thumbnail:" + urllib.parse.quote(str(source), safe="/"))
        self.assertTrue((self.cache / "aabb.png").read_bytes().startswith(PNG))

    def test_rejects_control_characters_and_remote_schemes(self):
        source = self.root / "plain.pdf"
        source.write_bytes(b"x")
        result = self.run_helper(str(source) + "\n")
        self.assertEqual(result.returncode, 2)
        remote = self.run_helper("https://example.invalid/file.pdf")
        self.assertEqual(remote.returncode, 2)

    def test_output_limit_is_enforced_while_writing(self):
        source = self.root / "large.pdf"
        source.write_bytes(b"x")
        result = self.run_helper(source, "ccdd", "--max-bytes", "1024", mode="huge")
        self.assertEqual(result.returncode, 4)
        self.assertFalse((self.cache / "ccdd.png").exists())
        self.assertFalse(any(path.name.startswith(".ccdd.") for path in self.cache.iterdir()))

    def test_timeout_always_terminates_generation(self):
        source = self.root / "slow.pdf"
        source.write_bytes(b"x")
        started = time.monotonic()
        result = self.run_helper(source, "eeff", "--timeout", "0.2", mode="sleep")
        self.assertEqual(result.returncode, 3)
        self.assertLess(time.monotonic() - started, 2.0)
        self.assertFalse((self.cache / "eeff.png").exists())

    def test_rejects_symlink_cache_directory_and_target(self):
        source = self.root / "safe.pdf"
        source.write_bytes(b"x")
        link_cache = self.root / "cache-link"
        link_cache.symlink_to(self.cache, target_is_directory=True)
        result = self.run_helper(source, "1122", cache=link_cache)
        self.assertEqual(result.returncode, 2)
        target = self.cache / "3344.png"
        target.symlink_to(source)
        result = self.run_helper(source, "3344")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(target.is_symlink())

    def test_cache_hit_does_not_spawn_kio_again(self):
        source = self.root / "cached.pdf"
        source.write_bytes(b"x")
        first = self.run_helper(source, "5566")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.log.unlink()
        second = self.run_helper(source, "5566")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertFalse(self.log.exists())


class PreviewIntegrationContractTests(unittest.TestCase):
    def test_primary_result_uses_cancellable_preview_source(self):
        primary = (ROOT / "contents" / "ui" / "components" / "PrimaryResultPreview.qml").read_text(encoding="utf-8")
        source = (ROOT / "contents" / "ui" / "components" / "FilePreviewSource.qml").read_text(encoding="utf-8")
        manager = (ROOT / "contents" / "ui" / "components" / "FilePreviewManager.qml").read_text(encoding="utf-8")
        self.assertIn("FilePreviewManager {", primary)
        self.assertIn("FilePreviewSource {", primary)
        self.assertIn("requestToken = manager.requestPreview", source)
        self.assertIn("generation !== requestGeneration", source)
        self.assertIn("Component.onDestruction", source)
        self.assertIn("maximumQueuedPaths: 8", manager)
        self.assertIn("maximumConcurrentRequests: 1", manager)
        self.assertIn("failureCacheTtlMs", manager)
        self.assertIn("executor.disconnectSource", manager)
        self.assertNotIn("thumbnailer.sh", manager)


if __name__ == "__main__":
    unittest.main()
