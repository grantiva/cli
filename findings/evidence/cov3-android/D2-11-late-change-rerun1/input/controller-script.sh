#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/D2-11-late-change-rerun1"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb; ffprobe_bin=/opt/homebrew/bin/ffprobe
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/record"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-d211-late-change-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/park.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Landmarks"
- assertVisible: "Featured"
YAML
cp "$base/project/.maestro/park.yaml" "$base/input/park.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/park.yaml --report-dir "$base/park-report") > "$base/park.out" 2> "$base/park.err"; prc=$?; echo "$prc" > "$base/park.exit.txt"; [ "$prc" -eq 0 ] || exit 5
$adb_bin -s "$serial" exec-out screencap -p > "$base/before.png"; $adb_bin -s "$serial" shell uiautomator dump /sdcard/d211-before.xml > "$base/before-dump.out" 2> "$base/before-dump.err"; $adb_bin -s "$serial" pull /sdcard/d211-before.xml "$base/before.xml" > "$base/before-pull.out" 2>&1
video="$base/record/late-change.mp4"; printf '$ %q record --platform android --device %q --duration 4 --output %q --json --verbose\n' "$GRANTIVA" "$serial" "$video" > "$base/record/command.txt"
(cd "$base/project" && exec "$GRANTIVA" record --platform android --device "$serial" --duration 4 --output "$video" --json --verbose) > "$base/record/record.json" 2> "$base/record/record.err" & rp=$!
started=0
for i in $(seq 1 100); do if grep -Fq "shell screenrecord --time-limit 4" "$base/record/record.err"; then started=1; break; fi; kill -0 "$rp" 2>/dev/null || break; sleep .05; done
[ "$started" -eq 1 ] || { kill -INT "$rp" 2>/dev/null || true; wait "$rp" 2>/dev/null; exit 6; }
python3 -I -c 'import time; time.sleep(3.35)'
python3 -I -c 'import time; print(time.monotonic_ns())' > "$base/record/tap-monotonic-ns.txt"
$adb_bin -s "$serial" shell input tap 900 2220 > "$base/record/tap.out" 2> "$base/record/tap.err"; trc=$?; echo "$trc" > "$base/record/tap.exit.txt"
wait "$rp"; rrc=$?; echo "$rrc" > "$base/record/record.exit.txt"
$adb_bin -s "$serial" exec-out screencap -p > "$base/after.png"; $adb_bin -s "$serial" shell uiautomator dump /sdcard/d211-after.xml > "$base/after-dump.out" 2> "$base/after-dump.err"; $adb_bin -s "$serial" pull /sdcard/d211-after.xml "$base/after.xml" > "$base/after-pull.out" 2>&1
$ffprobe_bin -v error -show_entries format=duration -of default=nw=1:nk=1 "$video" > "$base/record/ffprobe-duration.txt" 2> "$base/record/ffprobe.err"; frc=$?
python3 -I - "$base" "$rrc" "$trc" "$frc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rrc,trc,frc=map(int,sys.argv[2:]); j=json.loads((b/'record/record.json').read_text()); e=(b/'record/record.err').read_text(); before=(b/'before.xml').read_text(); after=(b/'after.xml').read_text(); dur=float((b/'record/ffprobe-duration.txt').read_text())
line=next((x for x in e.splitlines() if 'Held frame:' in x), '')
checks={'recordExit0':rrc==0,'tapExit0':trc==0,'ffprobe4s':frc==0 and 3.9<=dur<=4.1,'screenChanged':'Featured' in before and 'Deep Links' in after and before!=after,'diagnosticPresent':bool(line) and 'frames=' in line and 'lastFrame=' in line and 'trackEnd=' in line and 'held=' in line and 'noteThreshold=' in line,'noteNotPrinted':'note=not-printed' in line or 'note=suppressed' in line,'jsonTimingFields':isinstance(j.get('lastFrameMilliseconds'),int) and isinstance(j.get('recordedMilliseconds'),int) and j.get('lastFrameMilliseconds',0)>=3000,'noUserWarning':"Warning: The recording's last frame" not in e}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'heldFrameLine':line,'json':j,'ffprobeSeconds':dur},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
