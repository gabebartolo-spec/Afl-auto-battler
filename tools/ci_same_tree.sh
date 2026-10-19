#!/usr/bin/env bash
# For a push to main: did a green pull-request run already test exactly these files?
# A squash of an up-to-date branch gives the same tree as the merge commit its
# last green Tests run checked out, so running every shard again proves nothing.
#
#   GH_TOKEN=... tools/ci_same_tree.sh <sha> <owner/repo>
#
# Prints one line saying why, and exits 0 only when the tree is identical to the
# tree recorded by a fully green PR run (artifact "tested-tree", written by the
# test job only when every shard ran and passed). Any doubt (no PR, no green run,
# no artifact, an API error, a different tree) exits 1: run the tests.
set -u
sha="$1"
repo="$2"
tree=$(git rev-parse "$sha^{tree}" 2>/dev/null) || { echo "Run: cannot read the tree of $sha"; exit 1; }
pr=$(gh api "repos/$repo/commits/$sha/pulls" -q '[.[] | select(.merged_at != null)][0].number' 2>/dev/null)
[ -n "$pr" ] && [ "$pr" != null ] || { echo "Run: $sha is not a merged pull request"; exit 1; }
head=$(gh api "repos/$repo/pulls/$pr" -q .head.sha 2>/dev/null)
[ -n "$head" ] || { echo "Run: cannot read the head of #$pr"; exit 1; }
run=$(gh api "repos/$repo/actions/workflows/tests.yml/runs?event=pull_request&head_sha=$head&status=success&per_page=1" \
	-q '.workflow_runs[0].id // empty' 2>/dev/null)
[ -n "$run" ] || { echo "Run: no green Tests run of #$pr at its final head ${head:0:8}"; exit 1; }
tested=$(gh api "repos/$repo/actions/runs/$run/artifacts" -q '.artifacts[] | select(.name | startswith("tested-tree-")) | .name' 2>/dev/null | head -1)
tested="${tested#tested-tree-}"
[ -n "$tested" ] || { echo "Run: green run $run of #$pr recorded no tested tree"; exit 1; }
if [ "$tested" = "$tree" ]; then
	echo "Skip: tree $tree is the one #$pr's green run $run tested"
	exit 0
fi
echo "Run: tree $tree differs from the tree #$pr's green run $run tested ($tested); main moved after that run"
exit 1
