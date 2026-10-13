#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K15-live-teardown-refusal-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2k15-live-teardown-refusal-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb; serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3; [ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; }
trap cleanup EXIT INT TERM
(cd "$base/project" && "$GRANTIVA" runner start --platform android --device "$serial" --detach --json) > "$base/start.json" 2> "$base/start.err"; src=$?; [ "$src" -eq 0 ] || exit 5
pid="$(jq -r '.pid' "$base/start.json")"; [ "$pid" -gt 1 ] || exit 6
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial") > "$base/text.out" 2> "$base/text.err"; trc=$?
kill -0 "$pid" 2>/dev/null; live1=$?; adb -s "$serial" get-state > "$base/device-after-text.txt" 2> "$base/device-after-text.err"; dev1=$?
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --json) > "$base/json.out" 2> "$base/json.err"; jrc=$?
kill -0 "$pid" 2>/dev/null; live2=$?; adb -s "$serial" get-state > "$base/device-after-json.txt" 2> "$base/device-after-json.err"; dev2=$?
cp "$base/project/.grantiva/session.json" "$base/session-after-refusals.json"
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err"; stc=$?
python3 -I - "$base" "$trc" "$jrc" "$live1" "$live2" "$dev1" "$dev2" "$stc" "$pid" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); text=(b/'text.out').read_text()+(b/'text.err').read_text(); js=(b/'json.out').read_text()+(b/'json.err').read_text(); sess=json.loads((b/'session-after-refusals.json').read_text())
checks={'textRefuses':int(sys.argv[2])!=0 and 'runner session' in text.lower() and 'runner stop' in text.lower(),'jsonRefuses':int(sys.argv[3])!=0 and 'runner session' in js.lower() and 'runner stop' in js.lower(),'runnerAliveBoth':int(sys.argv[4])==0 and int(sys.argv[5])==0,'deviceAliveBoth':int(sys.argv[6])==0 and int(sys.argv[7])==0,'sessionIntact':sess.get('runnerPid')==int(sys.argv[9]) or sess.get('pid')==int(sys.argv[9]),'stop0':int(sys.argv[8])==0}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?; trap - EXIT INT TERM; exit "$rc"
