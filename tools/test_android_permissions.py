"""Regression checks for the offline-promise gate (P-70), without running Godot."""
import pathlib
import unittest

from check_android_permissions import problems

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
OPT = "permissions/vibrate=true"


class PermissionGateTests(unittest.TestCase):
    def test_real_presets_hold_the_promise(self):
        self.assertEqual(problems(BASE), [])

    def test_internet_rejected(self):
        self.assertTrue(problems(BASE.replace(OPT, OPT + "\npermissions/internet=true")))

    def test_other_permission_rejected(self):
        self.assertTrue(problems(BASE.replace(OPT, OPT + "\npermissions/access_network_state=true")))

    def test_permission_left_false_is_fine(self):
        self.assertEqual(problems(BASE.replace(OPT, OPT + "\npermissions/internet=false")), [])

    def test_custom_permission_rejected(self):
        extra = OPT + '\npermissions/custom_permissions=PackedStringArray("android.permission.INTERNET")'
        self.assertTrue(problems(BASE.replace(OPT, extra)))

    def test_plugin_rejected(self):
        self.assertTrue(problems(BASE.replace(OPT, OPT + "\nplugins/GodotGooglePlayBilling=true")))

    def test_no_android_preset_rejected(self):
        self.assertTrue(problems(BASE.replace('platform="Android"', 'platform="Web"')))

    def test_other_platforms_may_differ(self):
        # Only the Android preset is under the promise; the web preset has no permissions.
        self.assertEqual(problems(BASE + "\n[preset.9.options]\npermissions/internet=true\n"), [])


if __name__ == "__main__":
    unittest.main()
