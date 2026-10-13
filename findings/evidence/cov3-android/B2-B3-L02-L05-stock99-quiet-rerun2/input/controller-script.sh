#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-B3-L02-L05-stock99-quiet-rerun2"
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-stock99-crash-quiet-timing-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/99-crash.yaml" "$base/project/.maestro/99-crash.yaml"
cp "$P/.maestro/99-crash.yaml" "$base/input/99-crash.yaml"
cmp "$base/input/99-crash.yaml" "$P/.maestro/99-crash.yaml" || exit 3

adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || { echo "unexpected serial: $serial" >&2; exit 4; }
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 5
[ ! -e "$P/.grantiva/session.json" ] || { echo existing-project-session >&2; exit 6; }

: >"$base/commands.txt"; failures=0
for n in 1 2 3; do
 d="$base/runs/run-$n"; mkdir -p "$d/report"
 # Prefer the quiet-host target for up to one minute, but the campaign's hard
 # safety gate remains load1 < 20 immediately before each device run.
 for _ in $(seq 1 12); do
  load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"
  python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<8 else 1)' "$load" && break
  sleep 5
 done
 load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"
 echo "$load" >"$d/load1-immediately-before.txt"
 python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<20 else 1)' "$load" || { echo "load1 $load not below 20" >&2; exit 7; }
 "$adb_bin" -s "$serial" logcat -b all -c >"$d/logcat-clear.out" 2>"$d/logcat-clear.err" || exit 8
 python3 -I -c 'import json,os,time;print(json.dumps({"epoch":time.time(),"monotonic":time.monotonic(),"load":os.getloadavg()}))' >"$d/before.json"
 printf '# run=%s cwd=%s load1=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/99-crash.yaml --report-dir %q\n' "$n" "$base/project" "$load" "$GRANTIVA" "$serial" "$d/report" >>"$base/commands.txt"
 t0="$(python3 -I -c 'import time;print(time.monotonic())')"
 (cd "$base/project" && /usr/bin/time -p "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/99-crash.yaml --report-dir "$d/report") >"$d/stdout.txt" 2>"$d/stderr.txt"; rc=$?
 t1="$(python3 -I -c 'import time;print(time.monotonic())')"
 "$adb_bin" -s "$serial" logcat -b all -d -v epoch >"$d/logcat.txt" 2>"$d/logcat.err" || exit 9
 rg 'am_crash|FATAL EXCEPTION|LANDMARKS_CRASH_ON_LAUNCH' "$d/logcat.txt" >"$d/crash-lines.txt" || true
 python3 -I - "$d/report" >"$d/report-file-mtimes.txt" <<'PY'
import pathlib,sys
for p in sorted(pathlib.Path(sys.argv[1]).rglob('*')):
 if p.is_file(): print(f'{p.stat().st_mtime_ns/1e9:.9f} {p}')
PY
 python3 -I - "$t0" "$t1" "$rc" >"$d/result.json" <<'PY'
import json,sys
print(json.dumps({'wallElapsedSeconds':float(sys.argv[2])-float(sys.argv[1]),'exitCode':int(sys.argv[3])},indent=2))
PY
 [ "$rc" -ne 0 ] || failures=$((failures+1))
done

python3 -I - "$base" "$failures" <<'PY'
import datetime,json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); rows=[]; harness=int(sys.argv[2])
def iso_epoch(v): return datetime.datetime.fromisoformat(v).timestamp()
for d in sorted((b/'runs').iterdir()):
 r=json.loads((d/'result.json').read_text()); r['name']=d.name;r['load1']=float((d/'load1-immediately-before.txt').read_text())
 f=d/'report'/'flows'/'flow-000.json'
 if not f.exists(): f=d/'report'/'flow-000.json'
 if not f.exists(): harness+=1; r['decodeError']='missing flow-000.json';rows.append(r);continue
 flow=json.loads(f.read_text()); cmds=flow.get('commands',[]); failed=next((x for x in cmds if x.get('status')=='failed'),None)
 crash=[]
 for line in (d/'crash-lines.txt').read_text(errors='replace').splitlines():
  m=re.match(r'\s*(\d+\.\d+)\s+',line)
  if m and 'am_crash' in line:crash.append(float(m.group(1)))
 am=min(crash) if crash else None; fend=iso_epoch(failed['endTime']) if failed and failed.get('endTime') else None
 mt=[]
 for line in (d/'report-file-mtimes.txt').read_text().splitlines():
  t,p=line.split(' ',1)
  if pathlib.Path(p).suffix.lower() in {'.png','.jpg','.jpeg','.xml'}:mt.append({'epoch':float(t),'path':p})
 r.update({'flowDurationMilliseconds':flow.get('duration'),'failedCommand':failed,'amCrashEpoch':am,'failureEndEpoch':fend,
           'amCrashToFailureSeconds':None if am is None or fend is None else fend-am,'failureArtifacts':mt,
           'amCrashToFirstArtifactSeconds':None if am is None or not mt else min(x['epoch'] for x in mt)-am})
 if am is None or fend is None or not failed or ((failed.get('error') or {}).get('type')!='app_crash') or 'LANDMARKS_CRASH_ON_LAUNCH' not in json.dumps(failed): harness+=1
 rows.append(r)
(b/'summary.json').write_text(json.dumps({'harnessFailures':harness,'runs':rows},indent=2)+'\n')
raise SystemExit(0 if harness==0 else 1)
PY
find "$base" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$base/all-files.sha256"
