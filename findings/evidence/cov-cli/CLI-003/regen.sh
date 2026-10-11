#!/bin/bash
# Regenerates every help page named in findings/help into $1 and reports exit code + section presence
out=$1; help=$2
for f in "$help"/*.txt; do
  b=$(basename "$f" .txt)
  if [ "$b" = grantiva ]; then args=(); else IFS=_ read -ra args <<< "$b"; fi
  "$GRANTIVA" "${args[@]}" --help > "$out/$b.txt" 2> "$out/$b.err"; rc=$?
  ov=$(grep -c '^OVERVIEW:' "$out/$b.txt"); us=$(grep -c '^USAGE:' "$out/$b.txt"); op=$(grep -c '^OPTIONS:' "$out/$b.txt")
  cmp -s "$out/$b.txt" "$f" && same=same || same=DIFF
  echo "$b rc=$rc OVERVIEW=$ov USAGE=$us OPTIONS=$op $same"
done
