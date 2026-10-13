#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/B2-L05-L06-exact-rerun3"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro/coverage" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2l05-l06-exact-v3.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/99-crash.yaml" "$base/input/99-crash.yaml"

python3 -I - "$base/project/.maestro/coverage" <<'PY'
import pathlib, sys
d=pathlib.Path(sys.argv[1])
head='appId: com.kylebrowning.landmarks\nenv:\n  LANDMARKS_CRASH_ON_LAUNCH: "1"\n---\n- launchApp\n'
flows={
 'l06-index0': head+'- assertVisible: {text: "Landmarks", index: 0}\n- tapOn: {text: "Landmarks", index: 0}\n',
 'l06-below': head+'- assertVisible: {text: ".*", below: "Landmarks"}\n- tapOn: {text: ".*", below: "Landmarks"}\n',
 'l06-width': head+'- assertVisible: {text: "Landmarks", width: 290}\n- tapOn: {text: "Landmarks", width: 290}\n',
 # B3-L06 exact complement; kept separate from B2-L06's corrected index:0 input.
 'b3l06-index1': head+'- assertVisible: {text: ".*", index: 1}\n',
 'b3l06-tapfallback': head+'- tapOn: {text: ".*", index: 1}\n',
 'l05-absent': 'appId: com.kylebrowning.landmarks\n---\n- launchApp: {clearState: true}\n- tapOn: {text: "No Such", optional: true}\n',
}
for name, body in flows.items(): (d/(name+'.yaml')).write_text(body)
PY
cp "$base/project/.maestro/coverage/"*.yaml "$base/input/"

adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || { echo "unexpected serial: $serial" >&2; exit 3; }
avd="$($adb_bin -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "unexpected AVD: $avd" >&2; exit 4; }
[ ! -e "$P/.grantiva/session.json" ] || { echo existing-project-session >&2; exit 5; }

: > "$base/commands.txt"
harness_failures=0
run_case() {
  stem="$1"; rel="$2"; expected="$3"; d="$base/runs/$stem"
  mkdir -p "$d/report"
  $adb_bin -s "$serial" logcat -c > "$d/logcat-clear.out" 2> "$d/logcat-clear.err" || exit 6
  python3 -I -c 'import json,os,time;print(json.dumps({"load":os.getloadavg(),"epoch":time.time()}))' > "$d/before.json"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$rel" "$d/report" >> "$base/commands.txt"
  t0="$(python3 -I -c 'import time;print(time.monotonic())')"
  (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow "$rel" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
  t1="$(python3 -I -c 'import time;print(time.monotonic())')"
  $adb_bin -s "$serial" logcat -d -v epoch > "$d/logcat.txt" 2> "$d/logcat.err" || exit 7
  rg 'am_crash|FATAL EXCEPTION|LANDMARKS_CRASH_ON_LAUNCH' "$d/logcat.txt" > "$d/crash-lines.txt" || true
  python3 -I - "$t0" "$t1" "$rc" > "$d/result.json" <<'PY'
import json,sys
print(json.dumps({'elapsedSeconds':float(sys.argv[2])-float(sys.argv[1]),'exitCode':int(sys.argv[3])},indent=2))
PY
  if [ "$expected" = nonzero ]; then [ "$rc" -ne 0 ] || harness_failures=$((harness_failures+1)); else [ "$rc" -eq 0 ] || harness_failures=$((harness_failures+1)); fi
}

# CF-crash1/2/3 already retain the exact stock 99-crash input, reports, wall time,
# client logs, and am_crash events. This batch supplies only missing exact inputs.
for kind in l06-index0 l06-below l06-width b3l06-index1 b3l06-tapfallback; do
  for n in 1 2 3; do run_case "$kind-$n" ".maestro/coverage/$kind.yaml" nonzero; done
done
for n in 1 2 3; do run_case "l05-absent-$n" ".maestro/coverage/l05-absent.yaml" zero; done

python3 -I - "$base" "$harness_failures" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir()):
 r=json.loads((d/'result.json').read_text()); r['name']=d.name
 f=d/'report'/'flows'/'flow-000.json'
 if not f.exists(): f=d/'report'/'flow-000.json'
 if f.exists():
  doc=json.loads(f.read_text()); cmds=doc.get('commands',[])
  r['commands']=[{'type':c.get('type'),'status':c.get('status'),'duration':c.get('duration'),'error':c.get('error')} for c in cmds]
  failed=next((c for c in cmds if c.get('status')=='failed'),None)
  r['firstFailureType']=((failed or {}).get('error') or {}).get('type')
 log=(d/'report'/'client.log').read_text(errors='replace') if (d/'report'/'client.log').exists() else ''
 r['firstElementRequest']=next((x for x in log.splitlines() if re.search(r'(GET|POST) /session/.*/element ',x)),None)
 r['crashLines']=(d/'crash-lines.txt').read_text(errors='replace').splitlines()
 rows.append(r)
(b/'summary.json').write_text(json.dumps({'harnessFailures':int(sys.argv[2]),'runs':rows},indent=2)+'\n')
raise SystemExit(0 if int(sys.argv[2])==0 else 1)
PY
