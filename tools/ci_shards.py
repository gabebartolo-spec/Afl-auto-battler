"""The CI shard layout, with no list kept by hand.

The suites are the runners on disk: every tests/run_<suite>_tests.gd is a suite
(tools/list_suites.sh, which tools/run_tests.sh uses too). tools/ci_shards.txt is the
last plan from measured timings (tools/plan_ci_shards.py, weekly). Between re-plans:
  - a suite on disk that no shard names (a new one) goes onto the lightest shard,
    timed at its measured seconds or DEFAULT_SECONDS when it has none yet;
  - a suite a shard names that is no longer on disk (a removed one) is dropped.
Both are printed as notes, never failures. A suite in two shards is an error.

  python3 tools/ci_shards.py            # print the effective layout
  python3 tools/ci_shards.py --matrix   # print the GitHub matrix as JSON (the plan job)
"""
import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_SECONDS = 60
# Off most pull-request runs (tests.yml), so they do not count toward a shard's weight.
LATE = ("league_balance", "balance", "calibration")


def discover(root=ROOT, runner_dir="tests"):
    return sorted(p.name[len("run_"):-len("_tests.gd")]
                  for p in (root / runner_dir).glob("run_*_tests.gd"))


def timings(root=ROOT):
    path = root / "tools/ci_suite_timings.json"
    return json.loads(path.read_text())["seconds"] if path.exists() else {}


def layout(root=ROOT):
    """Returns (shards as [(id, [suites])], notes, errors)."""
    suites = set(discover(root))
    times = timings(root)
    shards, notes, errors, seen = [], [], [], {}
    for line in (root / "tools/ci_shards.txt").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, names = line.partition(":")
        if not key.strip().isdigit() or not _:
            errors.append(f"tools/ci_shards.txt: not 'N: suite suite ...': {line}")
            continue
        kept = []
        for name in names.split():
            if name in seen:
                errors.append(f"tools/ci_shards.txt: '{name}' is in shard {seen[name]} and shard {key.strip()}")
            elif name not in suites:
                notes.append(f"'{name}' is in shard {key.strip()} but has no tests/run_{name}_tests.gd: dropped")
                seen[name] = key.strip()
            else:
                seen[name] = key.strip()
                kept.append(name)
        shards.append((key.strip(), kept))
    if not shards:
        errors.append("tools/ci_shards.txt has no shards")
        return shards, notes, errors

    def weight(names):
        return sum(times.get(s, DEFAULT_SECONDS) for s in names if s not in LATE)

    for name in sorted(suites - set(seen), key=lambda s: (-times.get(s, DEFAULT_SECONDS), s)):
        target = min(shards, key=lambda shard: weight(shard[1]))
        target[1].append(name)
        estimate = times.get(name)
        notes.append(f"new suite '{name}' ({f'{estimate} s measured' if estimate else f'about {DEFAULT_SECONDS} s, no timing yet'})"
                     f" runs in shard {target[0]}; the weekly re-plan places it for good")
    return shards, notes, errors


SELECTED_TARGET_SECONDS = 240  # a pull request that runs only some suites aims for shards this long


def selected_layout(only, skip=(), root=ROOT, target=SELECTED_TARGET_SECONDS, most=12):
    """Packs just the `only` suites (minus `skip`) into as many shards as they need, longest first
    onto the lightest, by their measured seconds (DEFAULT_SECONDS when untimed). A pull request
    that touches few suites then does not pay for a shard layout planned for all of them."""
    times = timings(root)
    names = [s for s in discover(root) if s in set(only) and s not in set(skip)]
    if not names:
        return []
    total = sum(times.get(s, DEFAULT_SECONDS) for s in names)
    count = max(1, min(most, len(names), -(-total // target)))
    bins = [[0, []] for _ in range(count)]
    for s in sorted(names, key=lambda s: (-times.get(s, DEFAULT_SECONDS), s)):
        lightest = min(bins, key=lambda b: b[0])
        lightest[0] += times.get(s, DEFAULT_SECONDS)
        lightest[1].append(s)
    return [(str(i), b[1]) for i, b in enumerate(bins, 1)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--matrix", action="store_true")
    parser.add_argument("--only", help="space-separated suites: pack just these (a pull request's selection)")
    parser.add_argument("--skip", default="", help="space-separated suites to leave out of --only")
    args = parser.parse_args()
    if args.only is not None:
        shards = selected_layout(args.only.split(), args.skip.split())
        print(json.dumps({"include": [{"shard": key, "suites": " ".join(names)} for key, names in shards]}))
        return 0
    shards, notes, errors = layout()
    for note in notes:
        print(f"note: {note}", file=sys.stderr)
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        return 1
    if args.matrix:
        print(json.dumps({"include": [{"shard": key, "suites": " ".join(names)}
                                      for key, names in shards if names]}))
    else:
        total = sum(len(names) for _, names in shards)
        print(f"ok: {total} suites in {len(shards)} shards, each exactly once")
    return 0


if __name__ == "__main__":
    sys.exit(main())
