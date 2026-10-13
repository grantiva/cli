#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/duration-snapshot-contracts-exact-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input"; cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-duration-snapshot-contracts.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/input/config.yml"; cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"; cp "$P/.maestro/coverage/02-exact-negative.yaml" "$base/input/02-exact-negative.yaml"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 4
run(){ n=$1; expect=$2; shift 2; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } >"$base/$n/commands.txt"; "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; echo rc=$rc >>"$base/$n/commands.txt"; if [ -d .grantiva/run-captures ]; then cp -R .grantiva/run-captures "$base/$n/run-captures"; fi; if [ "$expect" = zero ]; then [ $rc -eq 0 ]; else [ $rc -ne 0 ]; fi; }
cd "$P"; failures=0
run pass-full zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/01-browse.yaml --snapshot full --report-dir "$base/pass-full/report" || failures=$((failures+1))
run fail-full nonzero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot full --report-dir "$base/fail-full/report" || failures=$((failures+1))
run fail-trailing nonzero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing --report-dir "$base/fail-trailing/report" || failures=$((failures+1))
run fail-failure nonzero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot failure --report-dir "$base/fail-failure/report" || failures=$((failures+1))
run pass-trailing zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/01-browse.yaml --snapshot trailing --report-dir "$base/pass-trailing/report" || failures=$((failures+1))
# Preserve complete file/reference inventories for exact count and dangling-reference review.
for n in pass-full fail-full fail-trailing fail-failure pass-trailing; do find "$base/$n/report" -type f -print | LC_ALL=C sort > "$base/$n/report-files.txt"; find "$base/$n/run-captures" -type f -print 2>/dev/null | LC_ALL=C sort > "$base/$n/run-capture-files.txt"; done
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"; exit "$failures"
