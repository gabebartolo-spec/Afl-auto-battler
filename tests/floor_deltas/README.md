# Floor deltas

A PR that adds checks to a suite adds a file here, `tests/floor_deltas/<branch>.txt`,
with one line per suite: `stats +12`. The runner's floor for a suite is the line in
`tests/expected_checks.txt` plus every delta here, so two PRs never edit the same line.
A brand-new suite still gets its own new line in `expected_checks.txt` (a different line
per suite rarely conflicts).

The merger folds the deltas into the base now and then with
`bash tools/fold_floor_deltas.sh` (it rewrites expected_checks.txt and deletes the delta
files; commit that alone, on a quiet main).
