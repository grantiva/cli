#!/bin/bash
set -u
corpus=$1; output=$2; mkdir -p "$output"; total=0; passed=0
for file in "$corpus"/*.txt; do
 base=$(basename "$file" .txt); args=(); if [ "$base" != grantiva ]; then IFS=_ read -ra args <<< "$base"; fi
 /Users/kyle/.grantiva-qa/bin/grantiva ${args[@]+"${args[@]}"} --version > "$output/$base.stdout" 2> "$output/$base.stderr"; rc=$?; value=$(tr -d '\r\n' < "$output/$base.stdout")
 [ "$rc" -eq 0 ] && [ "$value" = 2.1.0 ] && [ ! -s "$output/$base.stderr" ] && passed=$((passed+1)); total=$((total+1)); printf '%s rc=%s value=%s\n' "$base" "$rc" "$value"
done
printf 'total=%s passed=%s\n' "$total" "$passed"; test "$total" -eq 172 && test "$passed" -eq 172
