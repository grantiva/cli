#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L62-remove-five-rerun4"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs" "$base/device-speed"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l62-remove-five-v4.sh" "$base/input/controller-script.sh"
cp "$S/tools/client.py" "$base/input/client.py"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/l62-prefix.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- tapOn: "Landmarks"
- tapOn: "Favorites"
- assertVisible: "Lake Tahoe"
- takeScreenshot: "Favorites With Item"
- swipe:
    direction: LEFT
    from: "Lake Tahoe"
- assertVisible: "Remove from favorites"
YAML
cat > "$base/project/.maestro/l62-continuation.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- takeScreenshot: "Before Continuation Tap"
- tapOn: "Remove from favorites"
- assertNotVisible: "Lake Tahoe"
- assertVisible: "Landmarks you favorite will appear here."
- takeScreenshot: "Favorites Empty"
YAML
cp "$base/project/.maestro/l62-prefix.yaml" "$base/input/l62-prefix.yaml"; cp "$base/project/.maestro/l62-continuation.yaml" "$base/input/l62-continuation.yaml"
cat > "$base/input/read-only-requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-l62","version":"2"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{"format":"base64"}},"_save":"screenshot.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"}
]
JSON
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
$adb_bin -s "$serial" emu avd name > "$base/device-speed/avd-name.txt" 2>&1
cp "$HOME/.android/avd/cov3-android.avd/config.ini" "$base/device-speed/config.ini"
$adb_bin -s "$serial" shell getprop ro.hardware.egl > "$base/device-speed/ro-hardware-egl.txt" 2>&1
$adb_bin -s "$serial" shell getprop debug.hwui.renderer > "$base/device-speed/debug-hwui-renderer.txt" 2>&1
ps -axo pid,ppid,etime,command | grep '[q]emu-system.*-avd cov3-android' > "$base/device-speed/qemu-process.txt" || true
active_pid=""
cleanup(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; [ -n "$active_pid" ] && kill -INT "$active_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
probe(){ local d="$1"; mkdir -p "$d"; python3 -I "$base/input/client.py" "$base/input/read-only-requests.json" "$d" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project" --platform android > "$d/client.out" 2> "$d/client.err"; }
failures=0
for i in 1 2 3 4 5; do
  d="$base/runs/$i"; mkdir -p "$d/prefix-readiness" "$d/before" "$d/after"; uptime > "$d/uptime-before.txt"
  printf '# prefix cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/l62-prefix.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$d/prefix-report" > "$d/commands.txt"
  (cd "$base/project" && exec "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/l62-prefix.yaml --report-dir "$d/prefix-report") > "$d/prefix.out" 2> "$d/prefix.err" & active_pid=$!
  ready=0
  for attempt in $(seq 1 120); do
    (cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial") > "$d/prefix-readiness/$attempt.out" 2> "$d/prefix-readiness/$attempt.err"; hrc=$?
    if [ "$hrc" -eq 0 ] && grep -q 'Remove from favorites' "$d/prefix-readiness/$attempt.out"; then ready=1; cp "$d/prefix-readiness/$attempt.out" "$d/before/hierarchy.txt"; break; fi
    kill -0 "$active_pid" 2>/dev/null || break; sleep 1
  done
  if [ "$ready" -ne 1 ]; then failures=$((failures+1)); cleanup; wait "$active_pid" 2>/dev/null; active_pid=""; continue; fi
  probe "$d/before"; bmrc=$?
  (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$d/prefix-stop.json" 2> "$d/prefix-stop.err"; bsrc=$?
  wait "$active_pid"; bkr=$?; active_pid=""
  $adb_bin -s "$serial" shell uiautomator dump /sdcard/l62-before-continuation.xml > "$d/before/adb-dump.out" 2> "$d/before/adb-dump.err"
  $adb_bin -s "$serial" pull /sdcard/l62-before-continuation.xml "$d/before/adb-hierarchy.xml" > "$d/before/adb-pull.out" 2> "$d/before/adb-pull.err"
  readyfile="$d/continuation-ready.json"
  printf '# continuation cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/l62-continuation.yaml --ready-file %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$readyfile" "$d/continuation-report" >> "$d/commands.txt"
  (cd "$base/project" && exec "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/l62-continuation.yaml --ready-file "$readyfile" --report-dir "$d/continuation-report") > "$d/continuation.out" 2> "$d/continuation.err" & active_pid=$!
  settled=0
  for attempt in $(seq 1 120); do [ -f "$readyfile" ] && { settled=1; break; }; kill -0 "$active_pid" 2>/dev/null || break; sleep 1; done
  if [ "$settled" -eq 1 ]; then
    (cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial") > "$d/after/hierarchy.txt" 2> "$d/after/hierarchy.err"; ahrc=$?
    probe "$d/after"; amrc=$?
    (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$d/continuation-stop.json" 2> "$d/continuation-stop.err"; asrc=$?
  else
    ahrc=1; amrc=1
    (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$d/continuation-timeout-stop.json" 2> "$d/continuation-timeout-stop.err"; asrc=$?
    for reap in $(seq 1 50); do kill -0 "$active_pid" 2>/dev/null || break; sleep .1; done
    kill -INT "$active_pid" 2>/dev/null || true
    for reap in $(seq 1 20); do kill -0 "$active_pid" 2>/dev/null || break; sleep .1; done
    kill -TERM "$active_pid" 2>/dev/null || true
    for reap in $(seq 1 20); do kill -0 "$active_pid" 2>/dev/null || break; sleep .1; done
    kill -KILL "$active_pid" 2>/dev/null || true
  fi
  wait "$active_pid"; ckr=$?; active_pid=""; uptime > "$d/uptime-after.txt"
  printf 'beforeMcp=%s beforeStop=%s prefixExit=%s afterHierarchy=%s afterMcp=%s afterStop=%s continuationExit=%s\n' "$bmrc" "$bsrc" "$bkr" "$ahrc" "$amrc" "$asrc" "$ckr" > "$d/exits.txt"
  [ "$bmrc" -eq 0 ] && [ "$bsrc" -eq 0 ] && [ "$bkr" -eq 0 ] && [ "$ahrc" -eq 0 ] && [ "$amrc" -eq 0 ] && [ "$asrc" -eq 0 ] || failures=$((failures+1))
  [ "$ckr" -eq 0 ] || [ "$ckr" -eq 1 ] || failures=$((failures+1))
done
trap - EXIT INT TERM
python3 -I - "$base" <<'PY'
import base64,json,pathlib,sys
b=pathlib.Path(sys.argv[1]); runs=[]
for d in sorted((b/'runs').iterdir(),key=lambda p:int(p.name)):
 for side in ['before','after']:
  f=d/side/'screenshot.json'
  if f.exists():
   shot=json.loads(f.read_text()); data=next((x.get('data') for x in shot.get('result',{}).get('content',[]) if x.get('type')=='image'),None)
   if data: (d/side/'screenshot.png').write_bytes(base64.b64decode(data))
 before=(d/'before/hierarchy.txt').read_text() if (d/'before/hierarchy.txt').exists() else ''
 adb_before=(d/'before/adb-hierarchy.xml').read_text() if (d/'before/adb-hierarchy.xml').exists() else ''
 after=(d/'after/hierarchy.txt').read_text() if (d/'after/hierarchy.txt').exists() else ''
 err=(d/'continuation.err').read_text() if (d/'continuation.err').exists() else ''
 log=(d/'continuation-report/maestro-runner.log').read_text() if (d/'continuation-report/maestro-runner.log').exists() else ''
 ready=json.loads((d/'continuation-ready.json').read_text()) if (d/'continuation-ready.json').exists() else {}
 passed=ready.get('status')=='passed'; failed=ready.get('status')=='failed'
 failureExpected=failed and 'tapOn: text="Remove from favorites"' in log and 'assertNotVisible: text="Lake Tahoe"' in log and ('still visible' in err.lower() or 'Lake Tahoe' in after)
 runs.append({'run':int(d.name),'beforeRevealed':'Remove from favorites' in before and 'Lake Tahoe' in before,'preservedAcrossRestart':'Remove from favorites' in adb_before and 'Lake Tahoe' in adb_before,'runnerTapRecorded':'tapOn: text="Remove from favorites"' in log,'runnerBeforeTapScreenshot':'Before Continuation Tap' in log,'readyStatus':ready.get('status'),'afterHasRemove':'Remove from favorites' in after,'afterHasLakeTahoe':'Lake Tahoe' in after,'afterHasEmpty':'Landmarks you favorite will appear here' in after,'screenshotsPreserved':(d/'before/screenshot.png').exists() and (d/'after/screenshot.png').exists(),'expectedOutcome':passed or failureExpected})
checks={'fiveRuns':len(runs)==5,'allBeforeRevealed':all(x['beforeRevealed'] for x in runs),'allPreservedAcrossRestart':all(x['preservedAcrossRestart'] for x in runs),'allRunnerBeforeTapScreenshot':all(x['runnerBeforeTapScreenshot'] for x in runs),'allRunnerTapRecorded':all(x['runnerTapRecorded'] for x in runs),'allScreenshotsPreserved':all(x['screenshotsPreserved'] for x in runs),'onlyExpectedOutcomes':all(x['expectedOutcome'] for x in runs)}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':runs,'passes':sum(x['readyStatus']=='passed' for x in runs),'failures':sum(x['readyStatus']=='failed' for x in runs)},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
decoded=$?; [ "$decoded" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
