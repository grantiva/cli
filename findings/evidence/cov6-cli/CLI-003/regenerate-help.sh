#!/bin/bash
set -u
corpus=$1
output=$2
mkdir -p "$output"
identical=0
different=0
total=0
for file in "$corpus"/*.txt; do
  base=$(basename "$file" .txt)
  args=()
  if [ "$base" = grantiva ]; then args=(); else IFS=_ read -ra args <<< "$base"; fi
  /Users/kyle/.grantiva-qa/bin/grantiva ${args[@]+"${args[@]}"} --help > "$output/$base.stdout" 2> "$output/$base.stderr"
  rc=$?
  overview=$(grep -c '^OVERVIEW:' "$output/$base.stdout")
  usage=$(grep -c '^USAGE:' "$output/$base.stdout")
  options=$(grep -c '^OPTIONS:' "$output/$base.stdout")
  if cmp -s "$file" "$output/$base.stdout" && [ "$rc" -eq 0 ] && [ "$overview" -eq 1 ] && [ "$usage" -eq 1 ] && [ "$options" -eq 1 ]; then
    status=IDENTICAL
    identical=$((identical+1))
  else
    status=DIFFERENT
    different=$((different+1))
  fi
  total=$((total+1))
  printf '%s rc=%s overview=%s usage=%s options=%s %s\n' "$base" "$rc" "$overview" "$usage" "$options" "$status"
done
printf 'total=%s identical=%s different=%s\n' "$total" "$identical" "$different"
test "$total" -eq 172 && test "$identical" -eq 172 && test "$different" -eq 0
