"""Regression checks for the CI shard layout and balance report, without running Godot."""
import json
import pathlib
import tempfile
import unittest

from check_ci_balance import check
from ci_shards import DEFAULT_SECONDS, layout


class ShardLayoutTests(unittest.TestCase):
    def fixture(self, shards, times, suites):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = pathlib.Path(temp.name)
        (root / "tools").mkdir()
        (root / "tests").mkdir()
        for suite in suites:
            (root / f"tests/run_{suite}_tests.gd").write_text("")
        (root / "tests/test_helper.gd").write_text("")  # not a runner, not a suite
        (root / "tools/ci_shards.txt").write_text(shards)
        (root / "tools/ci_suite_timings.json").write_text(json.dumps({
            "seconds": times, "measured_on": "2026-10-19", "source_run": 1,
        }))
        return root

    def test_planned(self):
        root = self.fixture("1: a\n2: b\n", {"a": 100, "b": 100}, ["a", "b"])
        self.assertEqual(layout(root), ([("1", ["a"]), ("2", ["b"])], [], []))
        self.assertTrue(check(root))

    def test_new_suite_without_timing_goes_to_lightest_shard(self):
        root = self.fixture("1: a\n2: b\n", {"a": 300, "b": 100}, ["a", "b", "new"])
        shards, notes, errors = layout(root)
        self.assertEqual((shards, errors), ([("1", ["a"]), ("2", ["b", "new"])], []))
        self.assertIn(f"about {DEFAULT_SECONDS} s", notes[0])
        self.assertTrue(check(root))

    def test_balance_suites_do_not_weigh_a_shard(self):
        root = self.fixture("1: a balance\n2: b\n", {"a": 100, "b": 200, "balance": 500}, ["a", "b", "balance", "new"])
        self.assertEqual(layout(root)[0], [("1", ["a", "balance", "new"]), ("2", ["b"])])

    def test_removed_suite_is_dropped(self):
        root = self.fixture("1: a gone\n2: b\n", {"a": 100, "b": 100, "gone": 50}, ["a", "b"])
        shards, notes, errors = layout(root)
        self.assertEqual((shards, errors), ([("1", ["a"]), ("2", ["b"])], []))
        self.assertIn("'gone'", notes[0])

    def test_duplicate_rejected(self):
        root = self.fixture("1: a\n2: a\n", {"a": 100}, ["a"])
        self.assertTrue(layout(root)[2])
        self.assertFalse(check(root))

    def test_estimated_imbalance_is_not_a_failure(self):
        self.assertTrue(check(self.fixture("1: a\n2: b\n", {"a": 347, "b": 778}, ["a", "b"])))


if __name__ == "__main__":
    unittest.main()
