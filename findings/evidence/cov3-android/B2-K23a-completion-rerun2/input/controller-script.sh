#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K23a-completion-rerun2"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k23a-completion-rerun2.sh" "$base/input/controller-script.sh"
apk="$E/B2-K25-full-exact-rerun1/input/app-free-debug.apk"; test -s "$apk" || exit 3; cp "$apk" "$base/input/app.apk"; apk="$base/input/app.apk"
cat > "$base/project/template.yaml" <<'Y'
appId: ${APP_ID}
---
- launchApp
- assertVisible: "Landmarks"
Y
cat > "$base/project/wrong-literal.yaml" <<'Y'
appId: com.sentinel.wrong
---
- launchApp
- assertVisible: "Landmarks"
Y
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 5
run(){ n=$1; expect=$2; shift 2; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$n/commands.txt"; "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; echo rc=$rc >>"$base/$n/commands.txt"; if [ "$expect" = zero ]; then [ $rc -eq 0 ]; else [ $rc -ne 0 ]; fi; }
cd "$base/project"; failures=0
unset APP_ID
run template-no-id nonzero "$GRANTIVA" run --platform android --device "$serial" --no-build --flow template.yaml --report-dir "$base/template-no-id/report" || failures=$((failures+1))
run template-apk-id zero "$GRANTIVA" run --platform android --device "$serial" --no-build --app-file "$apk" --flow template.yaml --report-dir "$base/template-apk-id/report" || failures=$((failures+1))
run flag-over-header zero "$GRANTIVA" run --platform android --device "$serial" --no-build --app-file "$apk" --application-id com.kylebrowning.landmarks --flow wrong-literal.yaml --report-dir "$base/flag-over-header/report" || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"; exit "$failures"
