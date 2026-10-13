#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-068-interrupted-settings-rerun1"; serial=emulator-5554; state="$base/project/.grantiva/android-settings-emulator-5554.json"
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project/.maestro" "$base/interrupted/report" "$base/recovery/report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and068-interrupted-settings-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/11-slow.yaml" "$base/project/.maestro/11-slow.yaml"; cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"; cp "$base/project/.maestro/11-slow.yaml" "$base/input/11-slow.yaml"
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ ! -e "$state" ] || exit 4
snapshot(){ d="$1"; mkdir -p "$d"; for k in sysui_demo_allowed window_animation_scale transition_animation_scale animator_duration_scale; do adb -s "$serial" shell settings get global "$k" > "$d/$k.txt" 2> "$d/$k.err"; done; }
run_pid=""; runner_pid=""
cleanup(){ if [ -n "$run_pid" ] && kill -0 "$run_pid" 2>/dev/null; then kill -TERM "$run_pid" 2>/dev/null || true; wait "$run_pid" 2>/dev/null || true; fi; if [ -n "$runner_pid" ] && ps -p "$runner_pid" -o command= 2>/dev/null | grep -Fq -- '--platform android'; then kill -TERM "$runner_pid" 2>/dev/null || true; fi; }
trap cleanup EXIT
snapshot "$base/before"
(cd "$base/project" && exec "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/11-slow.yaml --report-dir "$base/interrupted/report" --verbose) > "$base/interrupted/stdout.txt" 2> "$base/interrupted/stderr.txt" & run_pid=$!; echo "$run_pid" > "$base/interrupted/run.pid"
active=0
for i in $(seq 1 200); do
 if [ -s "$state" ] && [ "$(adb -s "$serial" shell settings get global window_animation_scale 2>/dev/null|tr -d '\r')" = 0 ]; then active=1; break; fi
 kill -0 "$run_pid" 2>/dev/null || break; sleep .1
done
[ "$active" -eq 1 ] || exit 5; cp "$state" "$base/interrupted/settings-state.json"; snapshot "$base/during"
runner_pid="$(ps -axo pid,ppid,command | awk -v p="$run_pid" '$2==p && /grantiva-runner/ {print $1; exit}')"; [ -n "$runner_pid" ] && ps -p "$runner_pid" -o pid,ppid,etime,command > "$base/interrupted/runner-process.txt" || true
kill -9 "$run_pid"; wait "$run_pid" 2>/dev/null || true; echo 137 > "$base/interrupted/exit.txt"; run_pid=""
for i in $(seq 1 300); do [ -z "$runner_pid" ] || ! kill -0 "$runner_pid" 2>/dev/null && break; sleep .1; done
if [ -n "$runner_pid" ] && kill -0 "$runner_pid" 2>/dev/null; then ps -p "$runner_pid" -o pid,ppid,etime,command > "$base/interrupted/runner-still-alive.txt"; exit 6; fi
[ -s "$state" ] || exit 7; cp "$state" "$base/interrupted/settings-state-after-kill.json"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --report-dir "$base/recovery/report" --verbose) > "$base/recovery/stdout.txt" 2> "$base/recovery/stderr.txt"; rrc=$?; echo "$rrc" > "$base/recovery/exit.txt"; snapshot "$base/after"
[ ! -e "$state" ] || cp "$state" "$base/recovery/unexpected-state-after.json"
trap - EXIT; cleanup
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); text=(b/'recovery/stdout.txt').read_text()+(b/'recovery/stderr.txt').read_text(); report=json.loads((b/'recovery/report/report.json').read_text())
keys=['sysui_demo_allowed','window_animation_scale','transition_animation_scale','animator_duration_scale']; before={k:(b/'before'/f'{k}.txt').read_text().strip() for k in keys}; during={k:(b/'during'/f'{k}.txt').read_text().strip() for k in keys}; after={k:(b/'after'/f'{k}.txt').read_text().strip() for k in keys}
checks={'interruptedExit137':(b/'interrupted/exit.txt').read_text().strip()=='137','stateRetainedAfterKill':(b/'interrupted/settings-state-after-kill.json').is_file(),'captureSettingsApplied':during['sysui_demo_allowed']=='1' and all(during[k]=='0' for k in keys[1:]),'warningPrinted':'restoring Android settings left by an interrupted run on emulator-5554' in text,'recoveryRun0':(b/'recovery/exit.txt').read_text().strip()=='0' and report.get('status')=='passed','settingsRestored':before==after,'stateRemoved':not (b/'recovery/unexpected-state-after.json').exists()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'before':before,'during':during,'after':after},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
