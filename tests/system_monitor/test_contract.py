import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WIDGET = ROOT / "system-monitor"
MAIN = (WIDGET / "contents/ui/main.qml").read_text(encoding="utf-8")
CONFIG = (WIDGET / "contents/config/main.xml").read_text(encoding="utf-8")
META = json.loads((WIDGET / "metadata.json").read_text(encoding="utf-8"))


class SystemMonitorContractTests(unittest.TestCase):
    def test_keeps_existing_package_identity_and_plasma6_contract(self):
        self.assertEqual(META["KPlugin"]["Id"], "com.mcc45tr.systemmonitor")
        self.assertEqual(META["X-Plasma-API-Minimum-Version"], "6.0")
        self.assertEqual(META["KPlugin"]["License"], "GPL-3.0")

    def test_uses_kde_monitoring_backends_not_shell_polling(self):
        self.assertIn("org.kde.ksysguard.sensors", MAIN)
        self.assertIn("org.kde.ksysguard.process", MAIN)
        self.assertIn("ApplicationDataModel", MAIN)
        self.assertGreaterEqual(MAIN.count("updateRateLimit"), 5)
        for forbidden in (
            "Process {", "QProcess", "sh -c", "bash -c",
            "top -", "ps aux", "/proc/stat", "nvidia-smi",
        ):
            self.assertNotIn(forbidden, MAIN)

    def test_refresh_history_and_top_app_ranges_are_bounded(self):
        expected = {
            "updateInterval": ("500", "10000"),
            "historyLength": ("20", "180"),
            "topAppCount": ("1", "8"),
        }
        for key, (minimum, maximum) in expected.items():
            match = re.search(
                rf'<entry name="{key}"[^>]*>.*?<min>\s*{minimum}\s*</min>.*?<max>\s*{maximum}\s*</max>',
                CONFIG,
                re.S,
            )
            self.assertIsNotNone(match, key)

    def test_missing_hardware_is_optional_not_faked(self):
        self.assertIn("showGpu", CONFIG)
        self.assertIn("showNetwork", CONFIG)
        self.assertIn("showDisk", CONFIG)
        self.assertNotRegex(MAIN, r'(?i)(fake|demo|mock)[A-Za-z]*Value')


if __name__ == "__main__":
    unittest.main()
