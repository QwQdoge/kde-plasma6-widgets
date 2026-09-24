from pathlib import Path
import json
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WIDGET = ROOT / "system-monitor"
MAIN = WIDGET / "contents/ui/main.qml"
CONFIG = WIDGET / "contents/config/main.xml"
META = WIDGET / "metadata.json"


class SystemMonitorContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = MAIN.read_text(encoding="utf-8")
        cls.meta = json.loads(META.read_text(encoding="utf-8"))
        cls.config = ET.parse(CONFIG).getroot()

    def test_plasma6_package_identity_is_stable(self):
        self.assertEqual(self.meta["KPackageStructure"], "Plasma/Applet")
        self.assertEqual(self.meta["X-Plasma-API-Minimum-Version"], "6.0")
        self.assertEqual(self.meta["KPlugin"]["Id"], "com.mcc45tr.systemmonitor")

    def test_uses_kde_native_monitoring_models(self):
        for required in (
            "org.kde.ksysguard.sensors",
            "org.kde.ksysguard.process",
            "ApplicationDataModel",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.main)

    def test_does_not_poll_with_shell_processes(self):
        for forbidden in (
            "QProcess",
            "Process {",
            "exec(",
            "sh -c",
            "bash -c",
            "/proc/",
            "nvidia-smi",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.main)

    def test_refresh_and_history_configuration_are_bounded(self):
        xml = CONFIG.read_text(encoding="utf-8")
        self.assertIn('<entry name="updateInterval" type="Int">', xml)
        self.assertIn("<min>500</min>", xml)
        self.assertIn("<max>10000</max>", xml)
        self.assertIn('<entry name="historyLength" type="Int">', xml)
        self.assertIn("<min>20</min>", xml)
        self.assertIn("<max>180</max>", xml)
        self.assertIn('<entry name="topAppCount" type="Int">', xml)
        self.assertIn("<min>1</min>", xml)
        self.assertIn("<max>8</max>", xml)

    def test_expected_resource_groups_exist(self):
        for key in (
            "showCpu", "showMemory", "showGpu", "showNetwork",
            "showDisk", "showTopApps", "topAppMetric",
        ):
            with self.subTest(key=key):
                self.assertIn(f'name="{key}"', CONFIG.read_text(encoding="utf-8"))

    def test_qml_files_have_balanced_braces(self):
        # Cheap but useful source gate before live Plasma validation: catches
        # truncated/manual edits without pretending to replace qmllint.
        for path in (WIDGET / "contents").rglob("*.qml"):
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertEqual(text.count("{"), text.count("}"))


if __name__ == "__main__":
    unittest.main()
