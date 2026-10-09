#!/usr/bin/env bash
# Folds tests/floor_deltas/*.txt into tests/expected_checks.txt and removes them.
set -eu
cd "$(dirname "$0")/.."
base=tests/expected_checks.txt
shopt -s nullglob
files=(tests/floor_deltas/*.txt)
[ ${#files[@]} -eq 0 ] && { echo "no deltas"; exit 0; }
tmp=$(mktemp)
awk 'NR==FNR { if ($1 !~ /^#/ && NF>=2) { v=$2; gsub(/\+/,"",v); add[$1]+=v } next }
     /^#/ || NF<2 { print; next }
     { if ($1 in add) { $2 += add[$1]; delete add[$1] } print $1, $2 }
     END { for (s in add) print "ERROR: delta for unknown suite " s > "/dev/stderr" }' \
  <(cat "${files[@]}") "$base" > "$tmp"
mv "$tmp" "$base"
rm -f "${files[@]}"
echo "folded ${#files[@]} delta file(s) into $base"
