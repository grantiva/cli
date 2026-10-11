#!/bin/bash
# usage: helpcorpus.sh <grantiva-binary> <outdir>
G=$1; OUT=$2
walk() {
  local name file
  if [ $# -eq 0 ]; then file=$OUT/grantiva.txt; else name=$(IFS=_; echo "$*"); file=$OUT/$name.txt; fi
  [ $# -gt 4 ] && { echo "depth guard: $*" >&2; return; }
  "$G" "$@" --help > "$file" 2>&1
  local subs
  subs=$(awk '/^SUBCOMMANDS:/{f=1;next} f && /^  See /{f=0} f && /^  [a-z]/{s=$1; sub(/,$/,"",s); print s}' "$file")
  for s in $subs; do walk "$@" "$s"; done
}
walk
