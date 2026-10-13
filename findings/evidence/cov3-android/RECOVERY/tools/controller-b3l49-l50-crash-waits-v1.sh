#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L49-L50-crash-waits-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l49-l50-crash-waits-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
python3 -I - "$base/project/.maestro" <<'PY'
import pathlib,sys
d=pathlib.Path(sys.argv[1]); head='appId: com.kylebrowning.landmarks\nenv:\n  LANDMARKS_CRASH_ON_LAUNCH: "1"\n---\n- launchApp\n'
flows={
'crash-notvisible':head+'- assertNotVisible: "No Such"\n',
'crash-extended-notvisible':head+'- extendedWaitUntil: {notVisible: "No Such", timeout: 20000}\n',
'crash-page-source':head+'- assertNotVisible: {text: ".*", below: "No Such"}\n',
'crash-count':head+'- assertVisible: {text: ".*", count: 3}\n',
'crash-extended-visible':head+'- extendedWaitUntil: {visible: "Landmarks", timeout: 20000}\n',
'intentional-stop':'appId: com.kylebrowning.landmarks\n---\n- launchApp: {clearState: true}\n- stopApp\n- assertNotVisible: "Landmarks"\n',
'live-gone':'appId: com.kylebrowning.landmarks\n---\n- launchApp: {clearState: true}\n- assertVisible: "Featured"\n- tapOn: "Deep Links"\n- assertNotVisible: "Featured"\n',
'live-stays':'appId: com.kylebrowning.landmarks\n---\n- launchApp: {clearState: true}\n- extendedWaitUntil: {notVisible: "Landmarks", timeout: 2000}\n',
'live-count':'appId: com.kylebrowning.landmarks\n---\n- launchApp: {clearState: true}\n- assertVisible: {text: "Golden Gate Bridge", count: 1}\n'}
for name,text in flows.items():(d/(name+'.yaml')).write_text(text)
PY
cp "$base/project/.maestro/"*.yaml "$base/input/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
: > "$base/commands.txt"; harness_failures=0
run_case() {
  stem="$1"; flow="$2"; expected="$3"; d="$base/runs/$stem"; mkdir -p "$d/report"
  python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$d/host-load-before.json"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" ".maestro/$flow.yaml" "$d/report" >> "$base/commands.txt"
  t0="$(python3 -I -c 'import time;print(time.monotonic())')"
  (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow ".maestro/$flow.yaml" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
  t1="$(python3 -I -c 'import time;print(time.monotonic())')"
  python3 -I -c 'import json,sys;print(json.dumps({"exitCode":int(sys.argv[3]),"elapsedSeconds":float(sys.argv[2])-float(sys.argv[1])},indent=2))' "$t0" "$t1" "$rc" > "$d/result.json"
  if [ "$expected" = zero ]; then [ "$rc" -eq 0 ] || harness_failures=$((harness_failures+1)); else [ "$rc" -ne 0 ] || harness_failures=$((harness_failures+1)); fi
}
for kind in crash-notvisible crash-extended-notvisible crash-page-source crash-count crash-extended-visible; do for n in 1 2 3; do run_case "$kind-$n" "$kind" nonzero; done; done
run_case intentional-stop intentional-stop zero
run_case live-gone live-gone zero
run_case live-stays live-stays nonzero
run_case live-count live-count zero
python3 -I - "$base" "$harness_failures" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); runs=[]
for d in sorted((b/'runs').iterdir()):
 r=json.loads((d/'result.json').read_text()); r['name']=d.name; r['stderrTail']=(d/'stderr.txt').read_text()[-1200:]; runs.append(r)
(b/'summary.json').write_text(json.dumps({'harnessFailures':int(sys.argv[2]),'runs':runs},indent=2)+'\n'); raise SystemExit(0 if int(sys.argv[2])==0 else 1)
PY
