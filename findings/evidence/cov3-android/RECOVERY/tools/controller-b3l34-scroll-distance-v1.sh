#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L34-scroll-distance-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l34-scroll-distance-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/coverage/08-scroll.yaml" "$base/project/.maestro/08-scroll.yaml"
cp "$base/project/.maestro/08-scroll.yaml" "$base/input/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
failures=0
for n in 1 2 3 4 5; do
 d="$base/runs/$n"; mkdir -p "$d/report"; python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$d/host-load-before.json"
 printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/08-scroll.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$d/report" > "$d/command.txt"
 (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/08-scroll.yaml --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; printf '%s\n' "$rc" > "$d/exit.txt"; [ "$rc" -eq 0 ] || failures=$((failures+1))
done
python3 -I - "$base" "$failures" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir()):
 report=json.loads((d/'report/report.json').read_text()) if (d/'report/report.json').exists() else {}; log=(d/'report/client.log').read_text() if (d/'report/client.log').exists() else ''; rows.append({'run':d.name,'exitCode':int((d/'exit.txt').read_text()),'status':report.get('status'),'draggedLines':[x for x in log.splitlines() if 'dragged' in x.lower() or 'content moved' in x.lower()],'inputSwipe': 'input swipe' in log.lower()})
(b/'summary.json').write_text(json.dumps({'harnessFailures':int(sys.argv[2]),'runs':rows},indent=2)+'\n'); raise SystemExit(0 if int(sys.argv[2])==0 else 1)
PY
