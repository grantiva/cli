#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K86-a-handedoff-refusal-rerun2"
serial=emulator-5554
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2k86a-handedoff-refusal-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"; cp "$base/project/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; }
trap cleanup EXIT INT TERM
printf '# cwd=%s\n$ %q runner start --platform android --device %q --detach --json\n' "$base/project" "$GRANTIVA" "$serial" > "$base/start.command.txt"
(cd "$base/project" && "$GRANTIVA" runner start --platform android --device "$serial" --detach --json) > "$base/start.json" 2> "$base/start.err"; src=$?
[ "$src" -eq 0 ] || exit 5
pid="$(jq -r '.pid' "$base/start.json")"; [ "$pid" -gt 1 ] || exit 6
mkdir -p "$base/readiness"
ready=0
for attempt in $(seq 1 120); do
  (cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial") > "$base/readiness/$attempt.out" 2> "$base/readiness/$attempt.err"; drc=$?; echo "$drc" > "$base/readiness/$attempt.exit.txt"
  if [ "$drc" -eq 0 ]; then ready=1; printf '%s\n' "$attempt" > "$base/readiness/success-attempt.txt"; break; fi
  kill -0 "$pid" 2>/dev/null || exit 7; sleep 1
done
[ "$ready" -eq 1 ] || exit 8
cp "$base/project/.grantiva/session.json" "$base/session-before.json"; shasum -a 256 "$base/session-before.json" > "$base/session-before.sha256"
lease="$GRANTIVA_RUNNER_HOME/locks/$serial.lock"; [ -f "$lease" ] || exit 7; cp "$lease" "$base/lease-before.txt"
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/01-browse.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$base/refused-report" > "$base/refused.command.txt"
t0="$(python3 -I -c 'import time;print(time.monotonic())')"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --report-dir "$base/refused-report") > "$base/refused.out" 2> "$base/refused.err"; rrc=$?
t1="$(python3 -I -c 'import time;print(time.monotonic())')"; elapsed="$(python3 -I -c 'import sys;print(float(sys.argv[2])-float(sys.argv[1]))' "$t0" "$t1")"; printf '%s\n' "$elapsed" > "$base/refused.elapsed.txt"
kill -0 "$pid" 2>/dev/null; alive=$?
cp "$base/project/.grantiva/session.json" "$base/session-after.json"; shasum -a 256 "$base/session-after.json" > "$base/session-after.sha256"
cmp -s "$base/session-before.json" "$base/session-after.json"; same=$?
test -f "$lease"; lease_live=$?
test ! -e "$base/refused-report"; no_report=$?
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err"; stc=$?
python3 -I - "$base" "$rrc" "$alive" "$same" "$lease_live" "$no_report" "$stc" "$pid" "$elapsed" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); msg=(b/'refused.out').read_text()+(b/'refused.err').read_text(); stop=json.loads((b/'stop.json').read_text())
normalized=msg.replace('`','').lower()
checks={'runRefused':int(sys.argv[2])!=0,'exactHeldWording':'held by a grantiva runner start session' in normalized,'runnerStopRemedy':'runner stop' in msg.lower(),'runnerRemainsAlive':int(sys.argv[3])==0,'sessionUnchanged':int(sys.argv[4])==0,'leaseRemainsLive':int(sys.argv[5])==0,'noReportCreated':int(sys.argv[6])==0,'fastRefusal':float(sys.argv[9])<5,'stop0':int(sys.argv[7])==0,'stoppedExactPid':stop.get('pid')==int(sys.argv[8]) or stop.get('runnerPid')==int(sys.argv[8])}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'elapsed':float(sys.argv[9]),'message':msg,'stop':stop},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?; trap - EXIT INT TERM; exit "$rc"
