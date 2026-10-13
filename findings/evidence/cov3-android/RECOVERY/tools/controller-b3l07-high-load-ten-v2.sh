#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L07-high-load-ten-rerun2"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs" "$base/load"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l07-high-load-ten-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/02-favorite.yaml" "$base/project/.maestro/02-favorite.yaml"
cp "$base/project/.maestro/02-favorite.yaml" "$base/input/02-favorite.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
pids=""; old_pointer="$($adb_bin -s "$serial" shell settings get system pointer_location 2>/dev/null|tr -d '\r')"; printf '%s\n' "$old_pointer" > "$base/pointer-before.txt"
cleanup(){ for p in $pids; do kill "$p" 2>/dev/null || true; done; for p in $pids; do wait "$p" 2>/dev/null || true; done; if [ "$old_pointer" = null ] || [ -z "$old_pointer" ]; then $adb_bin -s "$serial" shell settings delete system pointer_location >/dev/null 2>&1 || true; else $adb_bin -s "$serial" shell settings put system pointer_location "$old_pointer" >/dev/null 2>&1 || true; fi; }
trap cleanup EXIT INT TERM
jobs="$(sysctl -n hw.logicalcpu)"; [ "$jobs" -gt 16 ] && jobs=16; [ "$jobs" -lt 8 ] && jobs=8
for i in $(seq 1 "$jobs"); do yes > /dev/null & pids="$pids $!"; done
printf '%s\n' $pids > "$base/load/owned-pids.txt"
reached=0
for attempt in $(seq 1 120); do load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"; printf '%s %s\n' "$attempt" "$load" >> "$base/load/poll.txt"; python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])>=8 else 1)' "$load" && { reached=1; break; }; sleep 1; done
[ "$reached" -eq 1 ] || exit 5
$adb_bin -s "$serial" shell settings put system pointer_location 1 >/dev/null
failures=0
for i in $(seq 1 10); do
 d="$base/runs/$i"; mkdir -p "$d"; uptime > "$d/uptime-before.txt"; python3 -I -c 'import os;print(os.getloadavg()[0])' > "$d/load1-before.txt"
 $adb_bin -s "$serial" shell pm clear com.kylebrowning.landmarks > "$d/pm-clear.out" 2> "$d/pm-clear.err" || { failures=$((failures+1)); continue; }
 printf '$ %q run --platform android --device %q --no-build --flow .maestro/02-favorite.yaml --snapshot full --report-dir %q\n' "$GRANTIVA" "$serial" "$d/report" > "$d/command.txt"
 (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/02-favorite.yaml --snapshot full --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; [ "$rc" -eq 0 ] || failures=$((failures+1))
 uptime > "$d/uptime-after.txt"; python3 -I -c 'import os;print(os.getloadavg()[0])' > "$d/load1-after.txt"; find "$d/report" -type f -iname '*.png' -print > "$d/png-inventory.txt" 2>/dev/null || true
done
cleanup; pids=""; trap - EXIT INT TERM
$adb_bin -s "$serial" shell settings get system pointer_location > "$base/pointer-after.txt" 2>&1
for p in $(cat "$base/load/owned-pids.txt"); do kill -0 "$p" 2>/dev/null && echo "$p"; done > "$base/load/still-alive.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir(),key=lambda x:int(x.name)):
 report=json.loads((d/'report/report.json').read_text()) if (d/'report/report.json').exists() else {}; log=(d/'report/maestro-runner.log').read_text() if (d/'report/maestro-runner.log').exists() else ''; pngs=(d/'png-inventory.txt').read_text().splitlines() if (d/'png-inventory.txt').exists() else []
 rows.append({'run':int(d.name),'exitCode':int((d/'exit.txt').read_text()),'status':report.get('status'),'load1Before':float((d/'load1-before.txt').read_text()),'load1After':float((d/'load1-after.txt').read_text()),'swipeLogged':'swipe' in log.lower() and 'Lake Tahoe' in log,'removeAsserted':'Remove from favorites' in log,'fullSnapshotArtifacts':len(pngs)>=2})
checks={'tenRuns':len(rows)==10,'allLoadAtLeast8':all(x['load1Before']>=8 and x['load1After']>=8 for x in rows),'allPass':all(x['exitCode']==0 and x['status']=='passed' for x in rows),'allSwipeLogged':all(x['swipeLogged'] for x in rows),'allRemoveRevealed':all(x['removeAsserted'] for x in rows),'allFullSnapshotArtifacts':all(x['fullSnapshotArtifacts'] for x in rows),'loadProcessesReaped':not (b/'load/still-alive.txt').read_text().strip()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':rows},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
dec=$?; [ "$dec" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
