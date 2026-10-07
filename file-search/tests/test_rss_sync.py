from __future__ import annotations

import base64
import importlib.util
import gzip
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "contents" / "tools" / "rss_sync.py"
SPEC = importlib.util.spec_from_file_location("rss_sync", MODULE_PATH)
rss_sync = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(rss_sync)


class FakeResponse:
    def __init__(self, chunks: list[bytes], content_length: str | None = None):
        self._chunks = list(chunks)
        self.headers = {} if content_length is None else {"Content-Length": content_length}

    def read(self, _size: int) -> bytes:
        return self._chunks.pop(0) if self._chunks else b""


class RssSyncTests(unittest.TestCase):
    def test_rejects_non_https_and_credentials(self):
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.validate_remote_url("http://example.com/feed", resolve=False)
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.validate_remote_url("https://user:pass@example.com/feed", resolve=False)

    def test_rejects_private_dns_answers(self):
        answer = [(2, 1, 6, "", ("127.0.0.1", 443))]
        with mock.patch.object(rss_sync.socket, "getaddrinfo", return_value=answer):
            with self.assertRaises(rss_sync.SyncError):
                rss_sync.validate_public_host("feed.example", 443)

    def test_redirect_policy_revalidates_scheme_and_address(self):
        handler = rss_sync.ValidatingRedirectHandler()
        with self.assertRaises(rss_sync.SyncError):
            handler.redirect_request(None, None, 302, "Found", {}, "http://example.com/feed")
        answer = [(2, 1, 6, "", ("10.0.0.4", 443))]
        with mock.patch.object(rss_sync.socket, "getaddrinfo", return_value=answer):
            with self.assertRaises(rss_sync.SyncError):
                handler.redirect_request(None, None, 302, "Found", {}, "https://feed.example/private")

    def test_enforces_declared_and_streamed_body_limits(self):
        too_large = str(rss_sync.MAX_RESPONSE_BYTES + 1)
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.read_bounded_response(FakeResponse([], too_large))
        chunks = [b"x" * rss_sync.MAX_RESPONSE_BYTES, b"y"]
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.read_bounded_response(FakeResponse(chunks))

    def test_rejects_entities_and_excessive_depth(self):
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.parse_rss('<!DOCTYPE rss [<!ENTITY x "boom">]><rss/>', "Feed", "https://example.com", 10)
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.parse_rss(" " * 5000 + '<!DOCTYPE rss><rss/>', "Feed", "https://example.com", 10)
        nested = "<rss>" + "<x>" * 65 + "</x>" * 65 + "</rss>"
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.parse_rss(nested, "Feed", "https://example.com", 10)

    def test_parser_caps_entries_fields_and_cross_origin_images(self):
        items = []
        for index in range(20):
            items.append(
                "<item>"
                f"<title>{'T' * 500}{index}</title>"
                f"<link>https://example.com/{index}</link>"
                "<description><![CDATA[<img src='https://tracker.example/pixel'>Body]]></description>"
                "</item>"
            )
        entries = rss_sync.parse_rss("<rss><channel>" + "".join(items) + "</channel></rss>", "Feed", "https://example.com/feed", 7)
        self.assertEqual(len(entries), 7)
        self.assertLessEqual(len(entries[0]["display"]), rss_sync.MAX_TITLE_CHARS)
        self.assertEqual(entries[0]["imageUrl"], "")

    def test_merge_is_bounded_sorted_and_atomic(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            older = [{"display": "old", "rawDate": "Mon, 01 Jan 2024 00:00:00 +0000"}]
            newer = [{"display": "new", "rawDate": "2025-01-01T00:00:00Z"}]
            for index, value in enumerate((older, newer)):
                encoded = base64.b64encode(json.dumps(value).encode()).decode()
                (cache / f"source_{index}.json").write_text(encoded, encoding="utf-8")
            self.assertEqual(rss_sync.merge_cache(cache), 0)
            combined = json.loads((cache / "combined.json").read_text(encoding="utf-8"))
            self.assertEqual([entry["display"] for entry in combined], ["new", "old"])
            self.assertEqual(stat.S_IMODE((cache / "combined.json").stat().st_mode), 0o600)
            self.assertFalse(list(cache.glob(".combined.json.*")))

    def test_failed_parse_preserves_last_known_good_source(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            target = rss_sync.source_path(cache, "https://example.com/feed")
            target.write_text("last-known-good", encoding="utf-8")
            with mock.patch.object(rss_sync, "fetch_feed", return_value=("<rss><broken>", {})), self.assertRaises(rss_sync.SyncError):
                rss_sync.sync_source(cache, "https://example.com/feed", "Feed", "10")
            self.assertEqual(target.read_text(encoding="utf-8"), "last-known-good")

    def test_gzip_rejects_bombs_truncation_trailing_and_unknown_encoding(self):
        payload = gzip.compress(b"<rss/>")
        self.assertEqual(rss_sync.decode_body(payload, "gzip"), b"<rss/>")
        for encoded in (payload[:-2], payload + b"junk", payload + payload,
                        gzip.compress(b"x" * (rss_sync.MAX_RESPONSE_BYTES + 1))):
            with self.assertRaises(rss_sync.SyncError):
                rss_sync.decode_body(encoded, "gzip")
        with self.assertRaises(rss_sync.SyncError):
            rss_sync.decode_body(payload, "br")

    def test_validators_reject_header_injection_and_unexpected_304(self):
        request = rss_sync.build_feed_request("https://example.com/feed", {
            "etag": '"good"\r\nInjected: header', "last_modified": "x" * 513,
        })
        self.assertFalse(request.has_header("If-none-match"))
        self.assertFalse(request.has_header("If-modified-since"))
        error = rss_sync.urllib.error.HTTPError("https://example.com/feed", 304, "unchanged", {}, None)
        with mock.patch.object(rss_sync, "validate_remote_url"), mock.patch.object(
                rss_sync.urllib.request.OpenerDirector, "open", side_effect=error):
            with self.assertRaises(rss_sync.SyncError):
                rss_sync.fetch_feed("https://example.com/feed", {})

    def test_validators_bound_to_body_url_and_config_and_cleared_on_fresh_response(self):
        url = "https://example.com/feed"
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            with mock.patch.object(rss_sync, "fetch_feed", return_value=("<rss/>", {"etag": '"v1"'})):
                rss_sync.sync_source(cache, url, "Feed", "10")
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Feed", 10)["etag"], '"v1"')
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Renamed", 10), {})
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Feed", 20), {})
            target = rss_sync.source_path(cache, url)
            saved = target.read_bytes()
            with mock.patch.object(rss_sync, "fetch_feed", return_value=(None, {})) as fetch:
                rss_sync.sync_source(cache, url, "Feed", "10")
                self.assertEqual(fetch.call_args.args[1]["etag"], '"v1"')
            self.assertEqual(target.read_bytes(), saved)
            target.write_text("broken")
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Feed", 10), {})
            target.write_bytes(saved)
            meta = json.loads(rss_sync.meta_path(cache, url).read_text())
            meta["url"] = "https://example.com/other"
            rss_sync.meta_path(cache, url).write_text(json.dumps(meta))
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Feed", 10), {})
            with mock.patch.object(rss_sync, "fetch_feed", return_value=("<rss/>", {})):
                rss_sync.sync_source(cache, url, "Feed", "10")
            self.assertEqual(rss_sync.load_http_meta(cache, url, "Feed", 10)["etag"], "")

    def test_dedup_keeps_newest_across_feeds_and_does_not_count_repeats_toward_limit(self):
        item = "<item><title>One</title><link>https://example.com/one</link></item>"
        other = "<item><title>Two</title><link>https://example.com/two</link></item>"
        entries = rss_sync.parse_rss("<rss>" + item * 3 + other + "</rss>", "Feed", "https://example.com", 2)
        self.assertEqual([e["display"] for e in entries], ["One", "Two"])
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            for index, date in enumerate(("2024-01-01", "2025-01-01")):
                entry = dict(entries[0], rawDate=date, display=date)
                (cache / f"source_{index}.json").write_text(json.dumps([entry]))
            rss_sync.merge_cache(cache)
            self.assertEqual(json.loads((cache / "combined.json").read_text())[0]["display"], "2025-01-01")
            self.assertEqual(len(json.loads((cache / "combined.json").read_text())), 1)


if __name__ == "__main__":
    unittest.main()
