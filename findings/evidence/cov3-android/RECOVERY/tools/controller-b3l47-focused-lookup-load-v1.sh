#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L47-focused-lookup-load-rerun1"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs" "$base/load"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l47-focused-lookup-load-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/03-edit.yaml" "$base/project/.maestro/03-edit.yaml"
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"; cp "$base/project/.maestro/03-edit.yaml" "$base/input/03-edit.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
pids=""
cleanup(){ for p in $pids; do kill "$p" 2>/dev/null || true; done; for p in $pids; do wait "$p" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM
jobs="$(sysctl -n hw.logicalcpu)"; [ "$jobs" -gt 16 ] && jobs=16; [ "$jobs" -lt 8 ] && jobs=8
for i in $(seq 1 "$jobs"); do yes > /dev/null & pids="$pids $!"; done
printf '%s\n' $pids > "$base/load/owned-pids.txt"
reached=0
for attempt in $(seq 1 120); do load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"; printf '%s %s\n' "$attempt" "$load" >> "$base/load/poll.txt"; python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])>=8 else 1)' "$load" && { reached=1; break; }; sleep 1; done
[ "$reached" -eq 1 ] || exit 5
failures=0
for i in 1 2 3 4 5; do
  d="$base/runs/$i"; mkdir -p "$d"; uptime > "$d/uptime-before.txt"; python3 -I -c 'import os;print(os.getloadavg()[0])' > "$d/load1-before.txt"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/03-edit.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$d/report" > "$d/command.txt"
  (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/03-edit.yaml --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; uptime > "$d/uptime-after.txt"; python3 -I -c 'import os;print(os.getloadavg()[0])' > "$d/load1-after.txt"
  [ "$rc" -eq 0 ] || failures=$((failures+1))
done
cleanup; pids=""; trap - EXIT INT TERM
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); runs=[]
def ms(v,u): return float(v)*(1000 if u=='s' else 1)
for d in sorted((b/'runs').iterdir(),key=lambda p:int(p.name)):
 c=(d/'report/client.log').read_text(); rc=int((d/'exit.txt').read_text()); before=float((d/'load1-before.txt').read_text()); after=float((d/'load1-after.txt').read_text())
 active=[ms(v,u) for v,u in re.findall(r'GET .*?/element/active \[([0-9.]+)(ms|s)\]',c)]
 actions=[ms(v,u) for v,u in re.findall(r'POST .*?/actions \[([0-9.]+)(ms|s)\]',c)]
 runs.append({'run':int(d.name),'exitCode':rc,'load1Before':before,'load1After':after,'activeLookupMs':active,'actionsMs':actions,'inputTextPassed':'inputText' in (d/'stderr.txt').read_text()})
checks={'fiveRuns':len(runs)==5,'allLoadAtLeast8':all(x['load1Before']>=8 for x in runs),'allPass':all(x['exitCode']==0 for x in runs),'allHaveActiveLookup':all(x['activeLookupMs'] for x in runs),'allHaveActions':all(x['actionsMs'] for x in runs)}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':runs},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
decoded=$?; [ "$decoded" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
