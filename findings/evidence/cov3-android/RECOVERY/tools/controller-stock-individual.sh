#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-043-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/runs"
cp "$0" "$d/input/controller-script.sh"
overall=0
for flow in .maestro/01-browse.yaml .maestro/02-favorite.yaml .maestro/03-edit.yaml .maestro/04-discard.yaml .maestro/05-category.yaml .maestro/06-visit.yaml .maestro/07-deeplink.yaml .maestro/08-caching.yaml .maestro/09-seed-empty.yaml .maestro/10-seed-many.yaml .maestro/11-slow.yaml .maestro/12-quote-label.yaml; do
  name=$(basename "$flow" .yaml); rd="$d/runs/$name"; mkdir -p "$rd/report"; cp "$flow" "$d/input/"
  printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --flow %s --report-dir %s\n' "$P" "$GRANTIVA" "$flow" "$rd/report" > "$rd/commands.txt"
  "$GRANTIVA" run --device emulator-5554 --no-build --flow "$flow" --report-dir "$rd/report" > "$rd/stdout.log" 2> "$rd/stderr.log"; rc=$?
  printf 'rc=%s\n' "$rc" >> "$rd/commands.txt"
  if [ "$rc" -ne 0 ]; then overall=1; fi
  jq '{status,summary,flows:[.flows[]|{name,sourceFile,status}]}' "$rd/report/report.json" > "$rd/report-summary.json"
done
exit "$overall"
