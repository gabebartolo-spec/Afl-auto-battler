"""Regression checks for the one-version gate and the bump script, without running Godot."""
import pathlib
import re
import unittest

from bump_version import bump
from check_version import problems

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
PRESETS = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
SCRIPTS = {p.name: p.read_text(encoding="utf-8", errors="replace") for p in (ROOT / "scripts").rglob("*.gd")}


class VersionGateTests(unittest.TestCase):
    def test_real_repo_has_one_copy(self):
        self.assertEqual(problems(PROJECT, PRESETS, SCRIPTS), [])

    def test_planted_literal_in_a_script_fails(self):
        planted = dict(SCRIPTS, **{"Planted.gd": 'var v := "Version 0.1.0"\n'})
        self.assertTrue(problems(PROJECT, PRESETS, planted))

    def test_planted_current_version_in_a_script_fails(self):
        planted = dict(SCRIPTS, **{"Planted.gd": 'var v := "0.1.99"\n'})
        self.assertTrue(problems(PROJECT, PRESETS, planted))

    def test_hard_coded_android_name_fails(self):
        self.assertTrue(problems(PROJECT, PRESETS + '\nversion/name="0.1.0"\n', SCRIPTS))

    def test_hard_coded_windows_version_fails(self):
        self.assertTrue(problems(PROJECT, PRESETS + '\napplication/file_version="0.1.0.0"\n', SCRIPTS))

    def test_version_code_drift_fails(self):
        self.assertTrue(problems(PROJECT, PRESETS.replace("version/code=", "version/code=9"), SCRIPTS))

    def test_bad_project_version_fails(self):
        self.assertTrue(problems(PROJECT.replace("config/version=", "config/version=x"), PRESETS, SCRIPTS))


class BumpTests(unittest.TestCase):
    def test_bump_moves_the_patch_and_the_code_together(self):
        p, e, new = bump(PROJECT, PRESETS)
        major, minor, patch = (int(x) for x in new.split("."))
        self.assertEqual(problems(p, e, SCRIPTS), [])
        self.assertIn('config/version="%s"' % new, p)
        self.assertEqual(p.count("config/version="), 1)
        self.assertEqual(len(p.splitlines()), len(PROJECT.splitlines()))
        self.assertEqual(len(e.splitlines()), len(PRESETS.splitlines()))

    def test_bump_adds_one(self):
        old = re.sub(r'config/version="[^"]*"', 'config/version="0.1.9"', PROJECT)
        _, _, new = bump(old, PRESETS)
        self.assertEqual(new, "0.1.10")


if __name__ == "__main__":
    unittest.main()
