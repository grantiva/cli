#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/D2-09-shutdown-appfile-capture-rerun1"; name=cov3-android-d209-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-d209-shutdown-appfile-capture-v1.sh" "$base/input/controller-script.sh"; cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app.apk"; shasum -a 256 "$base/input/app.apk" > "$base/input/app.sha256"
python3 -I - "$P/grantiva-android.yml" "$base/project/grantiva-android.yml" "$name" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text(); pathlib.Path(sys.argv[2]).write_text('\n'.join('emulator: '+sys.argv[3] if x.startswith('emulator:') else x for x in s.splitlines())+'\n')
PY
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){
 for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 4
adb devices -l > "$base/adb-before-capture.txt"
for s in $(adb devices|awk '$2=="device"{print $1}'); do printf '%s %s\n' "$s" "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; done > "$base/avd-names-before.txt"
grep -q " $name$" "$base/avd-names-before.txt" && exit 5
(cd "$base/project" && "$GRANTIVA" diff capture --platform android --emulator "$name" --application-id com.kylebrowning.landmarks --no-build --app-file "$base/input/app.apk" --verbose --json) > "$base/capture.json" 2> "$base/capture.err"; rc=$?; echo "$rc" > "$base/capture.exit.txt"
[ "$rc" -eq 0 ] || exit 6
serial=""; for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done; [ -n "$serial" ] || exit 7
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/installed-path.txt" || exit 8
cp -R "$base/project/.grantiva/captures/android" "$base/captures"
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$serial" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); j=json.load(open(b/'capture.json')); checks={'startedShutdownDevice':' cov3-android-d209-r3' not in (b/'avd-names-before.txt').read_text(),'capture0':(b/'capture.exit.txt').read_text().strip()=='0','fiveScreens':len(j.get('screens',[]))==5,'allStepsPassed':all(x.get('status')=='passed' for s in j['screens'] for x in s.get('steps',[])),'bootedResolvedAVD':j.get('emulator',{}).get('name')=='cov3-android-d209-r3' and j.get('emulator',{}).get('udid')==sys.argv[2],'installedApp':'package:' in (b/'installed-path.txt').read_text(),'avdRemoved':'cov3-android-d209-r3' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}; (b/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
