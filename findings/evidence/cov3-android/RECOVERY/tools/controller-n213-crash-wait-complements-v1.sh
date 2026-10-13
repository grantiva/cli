#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N2-13-crash-wait-complements-rerun1"; serial=emulator-5554
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n213-crash-wait-complements-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/crash-scroll.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- scrollUntilVisible:
    element: "Landmarks"
    direction: DOWN
    timeout: 20000
YAML
cat > "$base/project/.maestro/crash-animation.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- waitForAnimationToEnd:
    timeout: 20000
YAML
cp "$base/project/.maestro/"*.yaml "$base/input/"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
failures=0
for kind in scroll animation; do d="$base/runs/$kind"; mkdir -p "$d"; t0=$(python3 -I -c 'import time;print(time.monotonic())'); printf '$ %q run --platform android --device %q --no-build --flow .maestro/crash-%s.yaml --report-dir %q\n' "$GRANTIVA" "$serial" "$kind" "$d/report" > "$d/command.txt"; (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow ".maestro/crash-$kind.yaml" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; t1=$(python3 -I -c 'import time;print(time.monotonic())'); echo "$rc" > "$d/exit.txt"; python3 -I -c 'import sys;print(float(sys.argv[2])-float(sys.argv[1]))' "$t0" "$t1" > "$d/elapsed.txt"; [ "$rc" -ne 0 ] || failures=$((failures+1)); done
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir()):
 flow=json.loads(next((d/'report/flows').glob('*.json')).read_text()); first=flow['commands'][0]; err=first.get('error') or {}; elapsed=float((d/'elapsed.txt').read_text()); rows.append({'kind':d.name,'exitCode':int((d/'exit.txt').read_text()),'elapsedSeconds':elapsed,'launchStatus':first.get('status'),'errorType':err.get('type'),'message':err.get('message'),'waitStatus':flow['commands'][1].get('status')})
checks={'twoForms':len(rows)==2,'bothNonzero':all(x['exitCode']!=0 for x in rows),'bothAppCrash':all(x['launchStatus']=='failed' and x['errorType']=='app_crash' and 'RuntimeException' in (x['message'] or '') for x in rows),'waitsNeverPass':all(x['waitStatus']=='skipped' for x in rows),'bothFast':all(x['elapsedSeconds']<10 for x in rows)}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':rows},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
