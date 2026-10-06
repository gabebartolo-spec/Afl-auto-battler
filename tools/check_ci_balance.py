"""Gate shard estimates and report actual runtime drift; no game tests are skipped."""
import argparse
import datetime
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def check(root=ROOT, observed=None):
    baseline = json.loads((root / "tools/ci_suite_timings.json").read_text())
    times = baseline["seconds"]
    groups = {}
    for line in (root / "tools/ci_shards.txt").read_text().splitlines():
        if line and not line.startswith("#"):
            key, suites = line.split(":", 1)
            groups[key] = suites.split()
    errors = []
    assigned = [suite for suites in groups.values() for suite in suites]
    if set(assigned) != set(times) or len(assigned) != len(set(assigned)):
        errors.append("Every suite needs exactly one shard and a measured timing; refresh the timing baseline when adding/removing suites.")
    age = (datetime.date.today() - datetime.date.fromisoformat(baseline["measured_on"])).days
    if age > 30 or age < 0:
        errors.append("Timing evidence must be dated within the last 30 days; refresh it from a complete CI run.")
    if not errors:
        totals = {key: sum(times[s] for s in suites) for key, suites in groups.items()}
        mean = sum(totals.values()) / len(totals)
        print(f"Estimated shard seconds: {totals}; source run {baseline['source_run']}")
        if max(totals.values()) > mean * 1.20:
            errors.append("Longest shard exceeds 120% of average estimated workload. Redistribute suites; do not remove coverage or inflate timings.")
    for error in errors:
        print(f"::error::{error}")
    if observed:
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
        if seen == set(assigned) and len(actual) == len(groups):
            mean = sum(actual.values()) / len(actual)
            if max(actual.values()) > mean * 1.35:
                print("::warning::Measured shard imbalance exceeds 135% of average. Refresh timings and rebalance before the next CI scheduling change. Runner variability means this observation alone does not fail gameplay checks.")
        else:
            print("::warning::Incomplete runtime evidence; no observed balance conclusion available.")
    return not errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--observed")
    args = parser.parse_args()
    sys.exit(0 if check(observed=args.observed) else 1)
