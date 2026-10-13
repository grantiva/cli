#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L48-driver-timeout-rerun3"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/env60-detach" "$base/env60-run" "$base/env1-detach" "$base/env1-foreground" "$base/env1-run" "$base/trap"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l48-driver-timeout-v3.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
cp "$base/project/grantiva-android.yml" "$base/input/"; cp "$base/project/.maestro/01-browse.yaml" "$base/input/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$base/host-load-before.json"
stop(){ (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$1/stop.json" 2> "$1/stop.err" || true; }
trap 'stop "$base/trap"' EXIT INT TERM
run_sync(){ d="$1"; shift; python3 -I -c 'import time;print(time.monotonic())' > "$d/start.txt"; (cd "$base/project" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; python3 -I -c 'import time;print(time.monotonic())' > "$d/end.txt"; printf '%s\n' "$rc" > "$d/exit.txt"; }
run_sync "$base/env60-detach" env GRANTIVA_DRIVER_START_TIMEOUT=60 "$GRANTIVA" runner start --platform android --device "$serial" --detach --verbose --json
stop "$base/env60-detach"
run_sync "$base/env60-run" env GRANTIVA_DRIVER_START_TIMEOUT=60 "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --verbose
run_sync "$base/env1-detach" env GRANTIVA_DRIVER_START_TIMEOUT=1 "$GRANTIVA" runner start --platform android --device "$serial" --detach --verbose --json
stop "$base/env1-detach"
python3 -I - "$base/env1-foreground" "$base/project" "$GRANTIVA" "$serial" <<'PY'
import json,os,pathlib,subprocess,sys,time,threading
r=pathlib.Path(sys.argv[1]); project=sys.argv[2]; cmd=[sys.argv[3],'runner','start','--platform','android','--device',sys.argv[4],'--verbose','--json']; env=dict(os.environ); env['GRANTIVA_DRIVER_START_TIMEOUT']='1'; (r/'start.txt').write_text(str(time.monotonic()))
out=open(r/'stdout.txt','w'); err=open(r/'stderr.txt','w'); p=subprocess.Popen(cmd,cwd=project,env=env,stdout=out,stderr=err)
result={}
def reap(): result['rc']=p.wait()
t=threading.Thread(target=reap,daemon=True); t.start()
for _ in range(80):
 if p.poll() is not None: break
 text=(r/'stdout.txt').read_text() if (r/'stdout.txt').exists() else ''
 if 'Runner ready' in text or '"status"' in text: break
 time.sleep(.25)
if p.poll() is None:
 stop=subprocess.run([sys.argv[3],'runner','stop','--json'],cwd=project,capture_output=True,text=True,timeout=45); (r/'stop.json').write_text(stop.stdout); (r/'stop.err').write_text(stop.stderr); (r/'stop.exit.txt').write_text(str(stop.returncode)+'\n')
t.join(timeout=45)
if t.is_alive(): p.terminate(); t.join(timeout=10)
rc=result.get('rc',p.poll()); out.close();err.close();(r/'exit.txt').write_text(str(rc)+'\n');(r/'end.txt').write_text(str(time.monotonic()))
PY
run_sync "$base/env1-run" env GRANTIVA_DRIVER_START_TIMEOUT=1 "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --verbose
stop "$base/env1-run"
python3 -I - "$base" <<'PY'
import json,pathlib
b=pathlib.Path(__import__('sys').argv[1]); summary={}
for name in ['env60-detach','env60-run','env1-detach','env1-foreground','env1-run']:
 d=b/name; summary[name]={'exitCode':int((d/'exit.txt').read_text()),'elapsedSeconds':float((d/'end.txt').read_text())-float((d/'start.txt').read_text()),'stderrTail':(d/'stderr.txt').read_text()[-1200:]}
summary['env60DetachArg']= '--driver-start-timeout 60' in (b/'env60-detach/stderr.txt').read_text()
summary['env60RunArg']= '--driver-start-timeout 60' in (b/'env60-run/stderr.txt').read_text()
(b/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
PY
python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$base/host-load-after.json"
trap - EXIT INT TERM
