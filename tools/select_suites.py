"""Which test suites does a pull request need? Derived from the code, no list kept by hand.

Each suite runner (tests/run_<suite>_tests.gd) reaches res:// scripts and scenes through
preload/load paths, scene references and class names (class_name lines, plus the autoloads
in project.godot, found by name anywhere in a file, strings included: get_node("GameState")).
A changed file selects every suite whose closure contains it, plus the smoke set.

  python3 tools/select_suites.py --base origin/main   # suites for the files changed since base
  python3 tools/select_suites.py --files a.gd b.gd    # same for named files
  python3 tools/select_suites.py --closures           # every suite's size, for a look

Anything that cannot be traced goes to the full wall: data/, project.godot, export presets,
the test harness (tests/functions_ran.gd, tests/tap.gd, tests/fixtures, tools/run_tests.sh), the
workflow, the CI planner itself, a deleted or renamed file, and any file type the walker does
not follow. Pushes to main never call this: they run the full wall.
"""
import argparse
import json
from collections import deque
import pathlib
import re
import subprocess
import sys

from ci_shards import ROOT, discover

# The always-on set: the broadest quick suites (measured seconds in tools/ci_suite_timings.json),
# so a break the walker cannot see still shows up in a PR run.
SMOKE = ("chronology", "career_ui", "ratings")

REACH = 1  # a suite covers a script its own files name (a hop of 1), not what that script calls in turn
FOLLOWED = (".gd", ".tscn", ".tres", ".gdshader", ".uid")
# Leaf resources: referenced from scripts and scenes, never a source of further references.
LEAF_DIRS = ("assets/",)
IDENT = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
RES = re.compile(r"res://[A-Za-z0-9_./\- ]*[A-Za-z0-9_./\-]")
CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def rel(path, root):
    return path.relative_to(root).as_posix()


def project_files(root):
    skip = {".git", ".godot", ".claude", "node_modules"}
    out = []
    for p in root.rglob("*"):
        if p.is_file() and not (skip & set(p.relative_to(root).parts)):
            out.append(rel(p, root))
    return sorted(out)


def autoloads(root):
    names = {}
    text = (root / "project.godot").read_text(errors="replace")
    section = ""
    for line in text.splitlines():
        if line.startswith("["):
            section = line.strip("[]")
        elif section == "autoload" and "=" in line:
            name, _, value = line.partition("=")
            path = value.strip().strip('"').lstrip("*")
            if path.startswith("res://"):
                names[name.strip()] = path[len("res://"):]
    return names


def build_graph(root=ROOT):
    """Returns (edges {file: set(files)}, files). Over-reaching is safe, missing an edge is not."""
    files = project_files(root)
    fileset = set(files)
    classes = dict(autoloads(root))
    for f in files:
        if f.endswith(".gd"):
            for name in CLASS_NAME.findall((root / f).read_text(errors="replace")):
                classes[name] = f
    edges = {}
    for f in files:
        if not f.endswith((".gd", ".tscn", ".tres", ".gdshader")):
            continue
        text = (root / f).read_text(errors="replace")
        deps = set()
        for literal in RES.findall(text):
            path = literal[len("res://"):]
            if path in fileset:
                deps.add(path)
            elif path:  # a path built at run time ("res://scenes/" + name): every file under that prefix
                deps.update(x for x in files if x.startswith(path))
        if f.endswith(".gd"):
            for line in text.splitlines():
                if line.lstrip().startswith("#"):
                    continue
                for ident in IDENT.findall(line):
                    if ident in classes:
                        deps.add(classes[ident])
        deps.discard(f)
        edges[f] = deps
    return edges, files


def distances(start, edges, autoload_files):
    """Fewest script hops from a suite's runner to each file. A hop is a script naming another
    script; the test files themselves, scenes and resources are free (a scene is its scripts), the
    Router (the screen table) is free for a suite that names it, and the other autoloads are left out:
    every suite names GameState and GameDB, and through them every suite would reach the whole sim."""
    dist, queue = {start: 0}, deque([start])
    router = next((f for f in autoload_files if f.endswith("/Router.gd")), None)
    while queue:
        node = queue.popleft()
        for dep in edges.get(node, ()):
            if dep in autoload_files and dep != router:
                continue
            free = (node.startswith("tests/") and dep.startswith("tests/")) or dep.endswith((".tscn", ".tres"))                 or node.endswith((".tscn", ".tres")) or node == router
            step = dist[node] + (0 if free else 1)
            if step < dist.get(dep, 99):
                dist[dep] = step
                (queue.appendleft if free else queue.append)(dep)
    return dist


def suite_distances(root=ROOT):
    edges, files = build_graph(root)
    auto = set(autoloads(root).values())
    return {s: distances(f"tests/run_{s}_tests.gd", edges, auto) for s in discover(root)}, files, auto


def select(changed, root=ROOT, smoke=SMOKE):
    """Returns (suites, why). why is non-empty when the whole wall must run."""
    dists, files, auto = suite_distances(root)
    suites = set(dists)
    wanted = {s for s in smoke if s in suites}
    for path in changed:
        base = path[:-len(".uid")] if path.endswith(".uid") else path
        if path.startswith(("docs/", "tools/audit/", "tools/visual/")) or path.endswith(".md"):
            continue
        harness = base.startswith(("tests/fixtures/", "tests/functions_ran", "tests/tap", "tests/export_data"))
        traced = (base.startswith("tests/") and base.endswith(".gd") and not harness)             or (base.startswith(("scripts/", "scenes/")) and base.endswith(FOLLOWED)) or base.startswith(LEAF_DIRS)
        if not traced:
            return sorted(suites), f"{path} cannot be traced to suites"
        if base not in files:
            return sorted(suites), f"{path} was deleted or renamed"
        if base in auto:
            return sorted(suites), f"{path} is an autoload every suite loads"
        wanted |= {s for s, d in dists.items() if d.get(base, 99) <= REACH}
    return sorted(wanted), ""


def changed_files(base):
    merge_base = subprocess.run(["git", "merge-base", base, "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    out = subprocess.run(["git", "diff", "--name-only", merge_base, "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base")
    parser.add_argument("--files", nargs="*")
    parser.add_argument("--closures", action="store_true")
    parser.add_argument("--json", action="store_true", help='print {"suites", "partial", "note"} (the CI plan job)')
    args = parser.parse_args()
    if args.closures:
        dists, _, _ = suite_distances()
        for s, d in sorted(dists.items(), key=lambda kv: len(kv[1])):
            print(f"{s:14} {sum(1 for v in d.values() if v <= REACH)} files covered")
        return 0
    changed = args.files if args.files is not None else changed_files(args.base or "origin/main")
    suites, why = select(changed)
    note = "full wall: " + why if why else f"{len(suites)} of {len(discover())} suites"
    if args.json:
        print(json.dumps({"suites": " ".join(suites), "partial": len(suites) < len(discover()), "note": note}))
    else:
        print(" ".join(suites))
        print(note, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
