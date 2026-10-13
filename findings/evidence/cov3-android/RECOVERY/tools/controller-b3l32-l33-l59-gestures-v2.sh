#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L32-L33-L59-gesture-counters-rerun2"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l32-l33-l59-gestures-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/coverage/03-gesture-lab-taps.yaml" "$base/project/.maestro/stock.yaml"
cp "$base/project/.maestro/stock.yaml" "$base/input/stock.yaml"
cat > "$base/project/.maestro/double-first.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- assertVisible: "Taps: 0"
- doubleTapOn: {id: "gesture-pad"}
- assertVisible: "Double taps: 1"
- assertVisible: "Taps: 0"
YAML
cat > "$base/project/.maestro/relative.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- doubleTapOn: {id: "gesture-pad", point: "50%,50%"}
- assertVisible: "Double taps: 1"
- assertVisible: "Taps: 0"
YAML
cat > "$base/project/.maestro/point-only.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- doubleTapOn: {point: "50%,50%"}
- assertVisible: "Double taps: 1"
- assertVisible: "Taps: 0"
- longPressOn: {point: "50%,50%"}
- assertVisible: "Long presses: 1"
YAML
cat > "$base/project/.maestro/empty.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- doubleTapOn: {}
YAML
cp "$base/project/.maestro/"*.yaml "$base/input/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
: > "$base/commands.txt"; failures=0
run_case() {
  stem="$1"; flow="$2"; expect="$3"; d="$base/runs/$stem"; mkdir -p "$d/report"; python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$d/host-load-before.json"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" ".maestro/$flow" "$d/report" >> "$base/commands.txt"
  (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow ".maestro/$flow" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
  printf '%s\n' "$rc" > "$d/exit.txt"
  if [ "$expect" = zero ]; then [ "$rc" -eq 0 ] || failures=$((failures+1)); else [ "$rc" -ne 0 ] || failures=$((failures+1)); fi
}
for n in $(seq -w 1 10); do run_case "stock-$n" stock.yaml zero; done
for n in $(seq -w 1 5); do run_case "double-first-$n" double-first.yaml zero; done
for n in $(seq -w 1 3); do run_case "relative-$n" relative.yaml zero; done
for n in $(seq -w 1 3); do run_case "point-only-$n" point-only.yaml zero; done
run_case empty empty.yaml nonzero
python3 -I - "$base" "$failures" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); runs=[]
for d in sorted((b/'runs').iterdir()):
    report=d/'report/report.json'
    runs.append({'name':d.name,'exitCode':int((d/'exit.txt').read_text()),'report':json.loads(report.read_text()) if report.exists() else None,'stderr':(d/'stderr.txt').read_text()[-1000:]})
(b/'summary.json').write_text(json.dumps({'harnessFailures':int(sys.argv[2]),'runs':runs},indent=2)+'\n')
raise SystemExit(0 if int(sys.argv[2])==0 else 1)
PY
