#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K22-completeness-rerun2"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k22-completeness-rerun2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
cp "$P/.maestro/coverage/14-runflow-sub.yaml" "$base/project/sub.yaml"
cat > "$base/project/inline-nested.yaml" <<'Y'
appId: com.kylebrowning.landmarks
---
- launchApp
- runFlow:
    commands:
      - runFlow: sub.yaml
Y
cat > "$base/project/file-when.yaml" <<'Y'
appId: com.kylebrowning.landmarks
---
- launchApp
- runFlow:
    file: sub.yaml
    when:
      visible: "Landmarks"
Y
cat > "$base/project/empty.yaml" <<'Y'
appId: com.kylebrowning.landmarks
---
- launchApp
- runFlow: {}
Y
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 4
run(){ n=$1; expect=$2; shift 2; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$n/commands.txt"; "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; echo rc=$rc >> "$base/$n/commands.txt"; if [ "$expect" = zero ]; then [ $rc -eq 0 ]; else [ $rc -ne 0 ]; fi; }
cd "$base/project"; failures=0
run inline-nested zero "$GRANTIVA" run --device "$serial" --no-build --flow inline-nested.yaml --report-dir "$base/inline-nested/report" || failures=$((failures+1))
run file-when zero "$GRANTIVA" run --device "$serial" --no-build --flow file-when.yaml --report-dir "$base/file-when/report" || failures=$((failures+1))
run empty nonzero "$GRANTIVA" run --device "$serial" --no-build --flow empty.yaml --report-dir "$base/empty/report" || failures=$((failures+1))
find "$base/empty" -type f -name 'failure-*.png' -print > "$base/empty/failure-screenshots.txt"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"; exit "$failures"
