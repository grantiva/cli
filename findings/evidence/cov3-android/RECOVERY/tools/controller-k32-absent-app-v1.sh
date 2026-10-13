#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K32-absent-app-rerun1"; name=cov3-android-k32-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k32-absent-app-v1.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){
 (cd "$base/project" && "$GRANTIVA" runner stop --json) >> "$base/trap-stop.out" 2>> "$base/trap-stop.err" || true
 for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$base/ensure.out" 2> "$base/ensure.err" || exit 4
serial=$(tail -1 "$base/ensure.out"|tr -d '[:space:]'); [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 5
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/pm-before.txt" 2> "$base/pm-before.err" || true
[ ! -s "$base/pm-before.txt" ] || exit 6
(cd "$base/project" && "$GRANTIVA" build install --platform android --device "$serial" --application-id com.kylebrowning.landmarks --no-build --no-launch) > "$base/install.out" 2> "$base/install.err"; irc=$?; echo "$irc" > "$base/install.exit.txt"
(cd "$base/project" && "$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach) > "$base/start.out" 2> "$base/start.err"; src=$?; echo "$src" > "$base/start.exit.txt"
if [ "$src" -eq 0 ]; then (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err" || exit 7; fi
rg -n -C 8 'monkey|No activities found|not installed' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests > "$base/source/adb-tests.txt" || true
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); install=(b/'install.out').read_text()+(b/'install.err').read_text(); start=(b/'start.out').read_text()+(b/'start.err').read_text(); bad=lambda x:any(re.search(r'(^|\s)(data|arg)=',line) for line in x.splitlines())
checks={'appInitiallyAbsent':not (b/'pm-before.txt').read_text().strip(),'installRefuses':(b/'install.exit.txt').read_text().strip()=='1','installNamesAppDevice':'com.kylebrowning.landmarks' in install and 'emulator-' in install and 'not installed' in install.lower(),'installNoMonkeyTrace':not bad(install),'detachedStart0':(b/'start.exit.txt').read_text().strip()=='0','startNoMonkeyTrace':not bad(start),'detachedBlock':'Runner started (detached)' in (b/'start.out').read_text(),'avdRemoved':'cov3-android-k32-r3' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}; (b/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
