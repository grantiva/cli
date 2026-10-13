#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-A02.2-B-R02.1-N2-17-farside-ten-rerun1"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k09-farside-ten-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/c-direction-left-from.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- tapOn: "Landmarks"
- tapOn: "Favorites"
- assertVisible: "Lake Tahoe"
- takeScreenshot: "Before"
- swipe:
    direction: LEFT
    from: "Lake Tahoe"
- waitForAnimationToEnd
- takeScreenshot: "After"
- assertNotVisible: "Lake Tahoe"
- assertVisible: "Remove from favorites"
YAML
cp "$base/project/.maestro/c-direction-left-from.yaml" "$base/input/c-direction-left-from.yaml"
cp "$P/.maestro/02-favorite.yaml" "$base/input/02-favorite.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
old_pointer="$($adb_bin -s "$serial" shell settings get system pointer_location 2>/dev/null|tr -d '\r')"; printf '%s\n' "$old_pointer" > "$base/pointer-before.txt"
cleanup(){ if [ "$old_pointer" = null ] || [ -z "$old_pointer" ]; then $adb_bin -s "$serial" shell settings delete system pointer_location >/dev/null 2>&1 || true; else $adb_bin -s "$serial" shell settings put system pointer_location "$old_pointer" >/dev/null 2>&1 || true; fi; }
trap cleanup EXIT INT TERM
$adb_bin -s "$serial" shell settings put system pointer_location 1 >/dev/null
failures=0
for i in $(seq 1 10); do
 d="$base/runs/$i"; mkdir -p "$d"; $adb_bin -s "$serial" shell pm clear com.kylebrowning.landmarks > "$d/pm-clear.out" 2> "$d/pm-clear.err" || { failures=$((failures+1)); continue; }
 uptime > "$d/uptime-before.txt"
 printf '$ %q run --platform android --device %q --no-build --flow .maestro/c-direction-left-from.yaml --report-dir %q\n' "$GRANTIVA" "$serial" "$d/report" > "$d/command.txt"
 (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/c-direction-left-from.yaml --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; [ "$rc" -eq 0 ] || failures=$((failures+1)); uptime > "$d/uptime-after.txt"
 find "$d/report" -type f -iname '*.png' -print > "$d/png-inventory.txt" 2>/dev/null || true
done
# Required stock control, independently preserved.
d="$base/stock-02-favorite"; mkdir -p "$d"; $adb_bin -s "$serial" shell pm clear com.kylebrowning.landmarks > "$d/pm-clear.out" 2> "$d/pm-clear.err"
printf '$ %q run --platform android --device %q --no-build --flow %q --report-dir %q\n' "$GRANTIVA" "$serial" "$base/input/02-favorite.yaml" "$d/report" > "$d/command.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow "$base/input/02-favorite.yaml" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; src=$?; echo "$src" > "$d/exit.txt"; [ "$src" -eq 0 ] || failures=$((failures+1))
cleanup; trap - EXIT INT TERM
$adb_bin -s "$serial" shell settings get system pointer_location > "$base/pointer-after.txt" 2>&1
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir(),key=lambda x:int(x.name)):
 report=json.loads((d/'report/report.json').read_text()) if (d/'report/report.json').exists() else {}
 log=(d/'report/maestro-runner.log').read_text() if (d/'report/maestro-runner.log').exists() else ''
 pngs=(d/'png-inventory.txt').read_text().splitlines() if (d/'png-inventory.txt').exists() else []
 rows.append({'run':int(d.name),'exitCode':int((d/'exit.txt').read_text()),'status':report.get('status'),'swipeLogged':'swipe' in log.lower() and 'Lake Tahoe' in log,'removeAsserted':'Remove from favorites' in log,'beforeAfterPNGs':any('Before' in x for x in pngs) and any('After' in x for x in pngs),'pngs':pngs})
checks={'tenRuns':len(rows)==10,'allPass':all(x['exitCode']==0 and x['status']=='passed' for x in rows),'allSwipeLogged':all(x['swipeLogged'] for x in rows),'allRemoveRevealed':all(x['removeAsserted'] for x in rows),'allBeforeAfterPNGs':all(x['beforeAfterPNGs'] for x in rows),'stockPass':int((b/'stock-02-favorite/exit.txt').read_text())==0}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':rows},indent=2,sort_keys=True)+'\n')
raise SystemExit(0 if all(checks.values()) else 1)
PY
dec=$?; [ "$dec" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
