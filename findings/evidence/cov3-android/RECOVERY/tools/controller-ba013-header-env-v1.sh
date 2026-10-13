#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-A01.3-flow-header-env-rerun1"; serial=emulator-5554
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project/.maestro" "$base/report" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-ba013-header-env-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/header-env.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_NOTE: round3-header-only
---
- launchApp
- tapOn: "Deep Links"
- assertVisible: "round3-header-only"
YAML
cp "$base/project/.maestro/header-env.yaml" "$base/input/header-env.yaml"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
adb -s "$serial" logcat -c || exit 5
printf '# cwd=%s\n$ %s run --platform android --device %s --no-build --flow .maestro/header-env.yaml --report-dir %s\n' "$base/project" "$GRANTIVA" "$serial" "$base/report" > "$base/commands.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/header-env.yaml --report-dir "$base/report") > "$base/stdout.txt" 2> "$base/stderr.txt"
rc=$?; printf '%s\n' "$rc" > "$base/exit.txt"
adb -s "$serial" logcat -d -s Landmarks:I > "$base/landmarks-logcat.txt"
sed -n '84,98p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/android.md > "$base/source/android-env-docs.txt"
rg -n -C 5 'headerEnv|launchEnvironment|LANDMARKS_NOTE|environment' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg > "$base/source/exact-tests.txt" || true
python3 -I - "$base" "$rc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); log=(b/'landmarks-logcat.txt').read_text(); report=json.loads((b/'report/report.json').read_text())
launch=[x for x in log.splitlines() if 'Landmarks: launch' in x]
checks={'run0':int(sys.argv[2])==0,'reportPassed':report.get('status')=='passed','headerValueVisible':'round3-header-only' in (b/'stdout.txt').read_text(),'launchLogHasIntentExtra':any('LANDMARKS_NOTE=round3-header-only' in x and 'extras=[' in x for x in launch),'noCLIEnvFlag':'--env' not in (b/'commands.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'launchLines':launch},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
