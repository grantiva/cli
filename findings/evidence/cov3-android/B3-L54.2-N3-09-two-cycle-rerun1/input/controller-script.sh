#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L54.2-N3-09-two-cycle-rerun1"; name=cov3-android-l54-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project" "$base/other"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-l54-n309-two-cycle-v1.sh" "$base/input/controller-script.sh"; cp "$W/findings/evidence/cov3-android/RECOVERY/tools/l54-n309-cycle-client-v1.py" "$base/input/client.py"; cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app.apk"; shasum -a 256 "$base/input/app.apk" > "$base/input/app.sha256"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){
 for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/other" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-cleanup.out" 2>> "$base/trap-cleanup.err" || true; done
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/other" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 4
touch "$base/ownership-established"
for cycle in 1 2; do
 d="$base/cycle-$cycle"; mkdir -p "$d"; (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$d/boot.out" 2> "$d/boot.err" || exit 5
 serial=""; for n in $(seq 1 120); do for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done; [ -n "$serial" ] && break; sleep 1; done
 [ -n "$serial" ] || exit 6; echo "$serial" > "$d/serial.txt"; adb -s "$serial" install -r "$base/input/app.apk" > "$d/install.out" 2> "$d/install.err" || exit 7
 python3 -I "$base/input/client.py" "$d/run" "$base/project" "$base/other" "$GRANTIVA" "$serial" || exit 8
done
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[json.load(open(b/f'cycle-{i}/run/decoded.json')) for i in (1,2)]; checks={'twoCycles':len(rows)==2,'allChecks':all(all(r['checks'].values()) for r in rows),'avdRemoved':'cov3-android-l54-r3' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'cycles':rows},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
