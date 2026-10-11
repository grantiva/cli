#!/bin/bash
# regenerate every help page named in findings/help into $2 and compare with the corpus ($1)
H=$1; O=$2; mkdir -p $O; ok=0; bad=0
for f in "$H"/*.txt; do b=$(basename "$f" .txt); if [ "$b" = grantiva ]; then args=(); else IFS=_ read -ra args <<< "$b"; fi
"$GRANTIVA" "${args[@]}" --help > "$O/$b.txt" 2> "$O/$b.err"; rc=$?
hdr=$(grep -c -E '^(OVERVIEW|USAGE|OPTIONS):' "$O/$b.txt")
if cmp -s "$f" "$O/$b.txt" && [ $rc = 0 ]; then ok=$((ok+1)); st=IDENT; else bad=$((bad+1)); st=DIFF; fi
echo "$b rc=$rc headers=$hdr $st"; done; echo "ident=$ok diff=$bad"
