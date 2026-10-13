#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/flow-contracts-bulk-exact-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/no-config"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-flow-contracts-bulk.sh" "$base/input/controller-script.sh"
for f in 14b-runflow-inline.yaml 14-runflow-sub.yaml 16-setpermissions.yaml 02-exact-negative.yaml; do cp "$P/.maestro/coverage/$f" "$base/input/$f" 2>/dev/null || true; done
cp "$P/.maestro/coverage/16-setpermissions.yaml" "$base/no-config/16-setpermissions.yaml"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 4; echo "$serial" > "$base/input/serial.txt"
run(){ n=$1; expect=$2; shift 2; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$n/commands.txt"; "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; echo rc=$rc >>"$base/$n/commands.txt"; if [ "$expect" = zero ]; then [ $rc -eq 0 ]; else [ $rc -ne 0 ]; fi; }
cd "$P"; failures=0
run K22-inline zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/14b-runflow-inline.yaml --report-dir "$base/K22-inline/report" || failures=$((failures+1))
cd "$base/no-config"; run K23-header zero "$GRANTIVA" run --platform android --device "$serial" --no-build --flow 16-setpermissions.yaml --report-dir "$base/K23-header/report" || failures=$((failures+1))
cd "$P"; run K17-fail-json nonzero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --report-dir "$base/K17-fail-json/report" --json || failures=$((failures+1))
run K17-capture-json zero "$GRANTIVA" diff capture --device "$serial" --no-build --json || failures=$((failures+1))
[ -d .grantiva/captures ] && cp -R .grantiva/captures "$base/K17-capture-json/captures"
run K18-run-ephemeral zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/01-browse.yaml || failures=$((failures+1))
run K18-run-kept zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/01-browse.yaml --report-dir "$base/K18-run-kept/report" || failures=$((failures+1))
run K18-diff-ephemeral zero "$GRANTIVA" diff capture --device "$serial" --no-build || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"; exit "$failures"
