"""Regression checks for the CI scheduling gate, without running Godot."""
import datetime
import json
import pathlib
import tempfile
import unittest

from check_ci_balance import check


class BalanceGateTests(unittest.TestCase):
    def fixture(self, shards, times, date=None):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = pathlib.Path(temp.name)
        (root / "tools").mkdir()
        (root / "tools/ci_shards.txt").write_text(shards)
        (root / "tools/ci_suite_timings.json").write_text(json.dumps({
            "seconds": times, "measured_on": date or datetime.date.today().isoformat(), "source_run": 1,
        }))
        return root

    def test_balanced(self):
        self.assertTrue(check(self.fixture("1: a\n2: b\n", {"a": 100, "b": 100})))

    def test_imbalance_rejected(self):
        self.assertFalse(check(self.fixture("1: a\n2: b\n", {"a": 347, "b": 778})))

    def test_missing_timing_rejected(self):
        self.assertFalse(check(self.fixture("1: a b\n", {"a": 100})))

    def test_duplicate_rejected(self):
        self.assertFalse(check(self.fixture("1: a\n2: a\n", {"a": 100})))

    def test_stale_evidence_rejected(self):
        old = (datetime.date.today() - datetime.timedelta(days=31)).isoformat()
        self.assertFalse(check(self.fixture("1: a\n", {"a": 100}, old)))


if __name__ == "__main__":
    unittest.main()
