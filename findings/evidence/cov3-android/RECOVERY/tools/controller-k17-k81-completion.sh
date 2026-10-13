#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K17-K81-completion-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/tmp" "$base/K17" "$base/K81"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k17-k81-completion.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/input/config.yml"; cp "$P/.maestro/coverage/02-exact-negative.yaml" "$base/input/02-exact-negative.yaml"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 4
cd "$P"
# K17: observe/copy the command-owned ephemeral report while diff capture runs.
printf '# cwd=%s\n$ TMPDIR=%q %q diff capture --device %q --no-build --json\n' "$PWD" "$base/tmp" "$GRANTIVA" "$serial" > "$base/K17/commands.txt"
TMPDIR="$base/tmp" "$GRANTIVA" diff capture --device "$serial" --no-build --json > "$base/K17/stdout.log" 2> "$base/K17/stderr.log" & pid=$!; echo owned-shell-pid=$pid >> "$base/K17/commands.txt"
i=0
while kill -0 "$pid" 2>/dev/null; do
  for d in "$base"/tmp/grantiva-report-*; do
    [ -d "$d" ] || continue; i=$((i+1)); [ -f "$d/report.json" ] && cp "$d/report.json" "$base/K17/latest-report.json"; [ -f "$d/flows/flow-000.json" ] && cp "$d/flows/flow-000.json" "$base/K17/latest-flow-000.json"; printf '%s %s\n' "$i" "$(date -u +%FT%T.%NZ)" >> "$base/K17/poll-log.txt"
  done
  sleep 0.05
done
wait "$pid"; rc17=$?; echo rc=$rc17 >> "$base/K17/commands.txt"
# One final copy if cleanup has not yet removed the report.
for d in "$base"/tmp/grantiva-report-*; do [ -d "$d" ] || continue; i=$((i+1)); [ -f "$d/report.json" ] && cp "$d/report.json" "$base/K17/latest-report.json"; [ -f "$d/flows/flow-000.json" ] && cp "$d/flows/flow-000.json" "$base/K17/latest-flow-000.json"; done
find "$base/K17" -type f -print | LC_ALL=C sort > "$base/K17/snapshot-files.txt"
# K81 missing no-report branch; inventory visible run-captures exactly before and after.
find .grantiva/run-captures -type f -print 2>/dev/null | LC_ALL=C sort > "$base/K81/before-files.txt"
printf '# cwd=%s\n$ %q run --device %q --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing\n' "$PWD" "$GRANTIVA" "$serial" > "$base/K81/commands.txt"
"$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing > "$base/K81/stdout.log" 2> "$base/K81/stderr.log"; rc81=$?; echo rc=$rc81 >> "$base/K81/commands.txt"
find .grantiva/run-captures -type f -print 2>/dev/null | LC_ALL=C sort > "$base/K81/after-files.txt"; cp -R .grantiva/run-captures "$base/K81/run-captures-after"
printf 'K17-rc=%s snapshots=%s K81-rc=%s\n' "$rc17" "$i" "$rc81" > "$base/summary.txt"
[ "$rc17" -eq 0 ] && [ -s "$base/K17/latest-report.json" ] && [ -s "$base/K17/latest-flow-000.json" ] && [ "$rc81" -ne 0 ]
