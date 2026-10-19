"""Print the estimated shard seconds; after a run, report observed shard imbalance (a warning, never a failure).

The layout is tools/ci_shards.py's: a suite with no timing yet counts as DEFAULT_SECONDS.
"""
import argparse
import json
import pathlib
import sys

from ci_shards import DEFAULT_SECONDS, ROOT, layout, timings


def check(root=ROOT, observed=None):
    shards, _notes, errors = layout(root)
    for error in errors:
        print(f"::error::{error}")
    if errors:
        return False
    times = timings(root)
    groups = {key: names for key, names in shards if names}
    totals = {key: sum(times.get(s, DEFAULT_SECONDS) for s in names) for key, names in groups.items()}
    baseline = json.loads((root / "tools/ci_suite_timings.json").read_text()) if (root / "tools/ci_suite_timings.json").exists() else {}
    print(f"Estimated shard seconds: {totals}; source run {baseline.get('source_run')}, measured {baseline.get('measured_on')}")
    if observed:
        assigned = {s for names in groups.values() for s in names}
        actual = {}
        seen = set()
        for file in pathlib.Path(observed).glob("*.tsv"):
            total = 0
            for line in file.read_text().splitlines():
                suite, seconds = line.split("\t")
                seen.add(suite)
                total += int(seconds)
            actual[file.stem] = total
        print(f"Actual shard suite seconds: {actual}")
        if seen == assigned and len(actual) == len(groups):
            mean = sum(actual.values()) / len(actual)
            if max(actual.values()) > mean * 1.35:
                print("::warning::Measured shard imbalance exceeds 135% of average. Re-plan with tools/plan_ci_shards.py from a green main run. Runner variability means this observation alone does not fail gameplay checks.")
        else:
            print("::warning::Incomplete runtime evidence (a pull request skips the balance suites); no observed balance conclusion available.")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--observed")
    args = parser.parse_args()
    sys.exit(0 if check(observed=args.observed) else 1)
