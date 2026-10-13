#!/bin/bash
# runs <page args> --version for every help page in $1
for f in "$1"/*.txt; do b=$(basename "$f" .txt); if [ "$b" = grantiva ]; then args=(); else IFS=_ read -ra args <<< "$b"; fi
out=$("$GRANTIVA" "${args[@]}" --version 2>&1); rc=$?; echo "$b rc=$rc out=$out"; done
