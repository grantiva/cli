#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K86-b-live-cli-capture-rerun2"; serial=emulator-5554
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k86b-live-cli-capture-v2.sh" "$base/input/controller-script.sh"; sed '/^emulator:/d' "$P/grantiva-android.yml" > "$base/project/grantiva-android.yml"; cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android-no-emulator.yml"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; }
trap cleanup EXIT INT TERM
printf '$ %q runner start --platform android --device %q --application-id com.kylebrowning.landmarks --detach --json\n' "$GRANTIVA" "$serial" > "$base/start.command.txt"
(cd "$base/project" && "$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json) > "$base/start.json" 2> "$base/start.err"; src=$?; echo "$src" > "$base/start.exit.txt"; [ "$src" -eq 0 ] || exit 5
ready=0
mkdir -p "$base/readiness"
for n in $(seq 1 120); do (cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial") > "$base/readiness/$n.out" 2> "$base/readiness/$n.err"; rc=$?; if [ "$rc" -eq 0 ] && grep -Fq '[hierarchy]' "$base/readiness/$n.out"; then ready=1; cp "$base/readiness/$n.out" "$base/hierarchy-before.txt"; break; fi; sleep .25; done
[ "$ready" -eq 1 ] || exit 6
printf '$ %q diff capture --no-build\n' "$GRANTIVA" > "$base/capture.command.txt"
(cd "$base/project" && "$GRANTIVA" diff capture --no-build) > "$base/capture.out" 2> "$base/capture.err"; crc=$?; echo "$crc" > "$base/capture.exit.txt"
find "$base/project/.grantiva" -type f -print | sort > "$base/capture-files.txt" 2>/dev/null || true
(cd "$base/project" && "$GRANTIVA" runner dump-hierarchy) > "$base/hierarchy-after.txt" 2> "$base/hierarchy-after.err"; hrc=$?; echo "$hrc" > "$base/hierarchy-after.exit.txt"
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err"; trc=$?; echo "$trc" > "$base/stop.exit.txt"
trap - EXIT INT TERM
python3 -I - "$base" "$src" "$crc" "$hrc" "$trc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); src,crc,hrc,trc=map(int,sys.argv[2:]); files=(b/'capture-files.txt').read_text().splitlines(); text=(b/'capture.out').read_text()+(b/'capture.err').read_text(); hierarchy=(b/'hierarchy-after.txt').read_text(); expected=['Home','Favorites','Deep Links','Lakes','Detail']
command=(b/'capture.command.txt').read_text(); config=(b/'input/grantiva-android-no-emulator.yml').read_text()
checks={'start0':src==0,'implicitCaptureTarget':'--device' not in command and 'emulator:' not in config,'capture0':crc==0,'allFiveNamed':all(x in text for x in expected),'fivePNGs':len([x for x in files if x.lower().endswith('.png')])>=5,'postDump0':hrc==0 and '[hierarchy]' in hierarchy,'stop0':trc==0}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'files':files},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
