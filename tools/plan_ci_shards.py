"""Re-plan tools/ci_shards.txt from measured suite seconds (longest first onto the lightest shard).

  python3 tools/plan_ci_shards.py --timings-dir <dir> --run <id> --shards 12
      <dir> holds the suite-timings-*/shard-*.tsv files of a full green main run:
      gh run download <id> -p 'suite-timings-*' -D <dir>
  python3 tools/plan_ci_shards.py --shards 12      # re-plan from tools/ci_suite_timings.json

balance, league_balance and calibration are off most pull-request runs (tests.yml), so they
are planned last, onto the lightest shards, and the pull-request shards stay balanced without them.
"""
import argparse
import datetime
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LATE = ("league_balance", "balance", "calibration")  # longest first among themselves


def plan(times, count):
    bins = [[0, []] for _ in range(count)]
    order = sorted((s for s in times if s not in LATE), key=lambda s: (-times[s], s))
    order += sorted((s for s in LATE if s in times), key=lambda s: -times[s])
    for suite in order:
        lightest = min(bins, key=lambda b: b[0])
        lightest[0] += times[suite]
        lightest[1].append(suite)
    return bins


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shards", type=int, default=12)
    parser.add_argument("--timings-dir")
    parser.add_argument("--run", type=int)
    args = parser.parse_args()
    timings_file = ROOT / "tools/ci_suite_timings.json"
    baseline = json.loads(timings_file.read_text())
    if args.timings_dir:
        times = {}
        for file in pathlib.Path(args.timings_dir).rglob("*.tsv"):
            for line in file.read_text().splitlines():
                suite, seconds = line.split("\t")
                times[suite] = int(seconds)
        baseline = {"measured_on": datetime.date.today().isoformat(),
                    "source_run": args.run or 0, "seconds": dict(sorted(times.items()))}
        timings_file.write_text(json.dumps(baseline, indent=2) + "\n")
    times = baseline["seconds"]
    bins = plan(times, args.shards)
    pr_totals = [sum(times[s] for s in b[1] if s not in LATE) for b in bins]
    header = (ROOT / "tools/ci_shards.txt").read_text().split("\n# --- plan ---")[0].rstrip("\n")
    lines = [header, "# --- plan ---",
             f"# From main run {baseline['source_run']} ({baseline['measured_on']}), {len(times)} suites,"
             f" by tools/plan_ci_shards.py --shards {args.shards}.",
             "# Pull-request suite seconds per shard: " + " ".join(str(t) for t in pr_totals)]
    lines += [f"{i}: {' '.join(b[1])}" for i, b in enumerate(bins, 1)]
    (ROOT / "tools/ci_shards.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines[-args.shards - 1:]))


if __name__ == "__main__":
    main()
