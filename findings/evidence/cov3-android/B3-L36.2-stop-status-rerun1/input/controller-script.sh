#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L36.2-stop-status-rerun1"; serial=emulator-5554
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l36-2-stop-status-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
cat > "$base/project/.maestro/slow.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- extendedWaitUntil:
    visible: "round3-never-visible-l36"
    timeout: 60000
YAML
cat > "$base/project/.maestro/exact-negative.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "round3-never-visible-l36"
YAML
cp "$base/project/.maestro/slow.yaml" "$base/input/slow.yaml"; cp "$base/project/.maestro/exact-negative.yaml" "$base/input/exact-negative.yaml"
cat > "$base/input/run-and-record.py" <<'PY'
import pathlib,subprocess,sys
cwd,out,err,exitf,*argv=sys.argv[1:]
with open(out,'wb') as o, open(err,'wb') as e:
 r=subprocess.run(argv,cwd=cwd,stdout=o,stderr=e)
pathlib.Path(exitf).write_text(str(r.returncode)+'\n')
PY
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; }
trap cleanup EXIT INT TERM
start_case(){ name="$1" flow="$2"; d="$base/$name"; mkdir -p "$d"; ready="$d/ready.json"; printf '$ %q run --platform android --device %q --no-build --keep-alive --flow %q --ready-file %q --report-dir %q\n' "$GRANTIVA" "$serial" "$flow" "$ready" "$d/report" > "$d/command.txt"; python3 -I "$base/input/run-and-record.py" "$base/project" "$d/stdout.txt" "$d/stderr.txt" "$d/exit.txt" "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow "$flow" --ready-file "$ready" --report-dir "$d/report" & helper=$!; echo "$helper" > "$d/helper.pid"; }
wait_helper(){ d="$1"; helper="$2"; for n in $(seq 1 300); do [ -f "$d/exit.txt" ] && { wait "$helper"; return 0; }; kill -0 "$helper" 2>/dev/null || break; sleep .1; done; kill -TERM "$helper" 2>/dev/null || true; wait "$helper" 2>/dev/null || true; return 1; }
# Stop while slow flow is actively executing.
start_case during .maestro/slow.yaml; during_helper=$helper; active=0
for n in $(seq 1 300); do if grep -Fq 'round3-never-visible-l36' "$base/during/report/maestro-runner.log" 2>/dev/null; then active=1; break; fi; [ -f "$base/during/exit.txt" ] && break; sleep .1; done
echo "$active" > "$base/during/active-detected.txt"; (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/during/stop.json" 2> "$base/during/stop.err"; echo "$?" > "$base/during/stop.exit.txt"; wait_helper "$base/during" "$during_helper"; echo "$?" > "$base/during/helper-wait.exit.txt"
# Stop after a passed flow has armed its keep-alive hold.
start_case passed .maestro/01-browse.yaml; passed_helper=$helper; passed_ready=0
for n in $(seq 1 600); do if [ -f "$base/passed/ready.json" ] && [ "$(jq -r '.status // empty' "$base/passed/ready.json" 2>/dev/null)" = passed ]; then passed_ready=1; break; fi; [ -f "$base/passed/exit.txt" ] && break; sleep .1; done
echo "$passed_ready" > "$base/passed/status-detected.txt"; (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/passed/stop.json" 2> "$base/passed/stop.err"; echo "$?" > "$base/passed/stop.exit.txt"; wait_helper "$base/passed" "$passed_helper"; echo "$?" > "$base/passed/helper-wait.exit.txt"
# Stop after a failed flow has armed its keep-alive hold.
start_case failed .maestro/exact-negative.yaml; failed_helper=$helper; failed_ready=0
for n in $(seq 1 600); do if [ -f "$base/failed/ready.json" ] && [ "$(jq -r '.status // empty' "$base/failed/ready.json" 2>/dev/null)" = failed ]; then failed_ready=1; break; fi; [ -f "$base/failed/exit.txt" ] && break; sleep .1; done
echo "$failed_ready" > "$base/failed/status-detected.txt"; (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/failed/stop.json" 2> "$base/failed/stop.err"; echo "$?" > "$base/failed/stop.exit.txt"; wait_helper "$base/failed" "$failed_helper"; echo "$?" > "$base/failed/helper-wait.exit.txt"
trap - EXIT INT TERM
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]);
def i(p): return int((b/p).read_text())
def j(p): return json.loads((b/p).read_text())
checks={'duringActive':i('during/active-detected.txt')==1,'duringRunInterrupted':i('during/exit.txt')==130,'duringReadyInterrupted':j('during/ready.json').get('status')=='interrupted','duringStop0':i('during/stop.exit.txt')==0,'passedReadyPreserved':j('passed/ready.json').get('status')=='passed','passedRun0':i('passed/exit.txt')==0,'passedStop0':i('passed/stop.exit.txt')==0,'failedReadyPreserved':j('failed/ready.json').get('status')=='failed','failedRun1':i('failed/exit.txt')==1,'failedStop0':i('failed/stop.exit.txt')==0}
(b/'decoded.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
