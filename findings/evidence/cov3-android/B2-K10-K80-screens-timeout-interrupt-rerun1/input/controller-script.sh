#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K10-K80-screens-timeout-interrupt-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project" "$base/timeout" "$base/interrupt"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k10-k80-screens-timeout-interrupt-v1.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/coverage/cfg/screens-slow.grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --timeout 30 --ready-file %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$base/timeout/ready.json" "$base/timeout/report" > "$base/timeout/command.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --timeout 30 --ready-file "$base/timeout/ready.json" --report-dir "$base/timeout/report") > "$base/timeout/stdout.txt" 2> "$base/timeout/stderr.txt"; trc=$?
printf '%s\n' "$trc" > "$base/timeout/exit.txt"
printf '# cwd=%s\n$ python3 -I <signal-helper> %q %q %q %q\n' "$base/project" "$GRANTIVA" "$serial" "$base/interrupt/ready.json" "$base/interrupt/report" > "$base/interrupt/command.txt"
python3 -I - "$base/project" "$GRANTIVA" "$serial" "$base/interrupt" <<'PY'
import json, os, pathlib, signal, subprocess, sys, time
project, grantiva, serial, raw = sys.argv[1:]
r = pathlib.Path(raw); ready=r/'ready.json'; report=r/'report'
cmd=[grantiva,'run','--platform','android','--device',serial,'--no-build','--ready-file',str(ready),'--report-dir',str(report)]
out=open(r/'stdout.txt','w'); err=open(r/'stderr.txt','w')
p=subprocess.Popen(cmd,cwd=project,stdout=out,stderr=err,start_new_session=True)
seen=False
for _ in range(240):
    text=(r/'stderr.txt').read_text() if (r/'stderr.txt').exists() else ''
    if '[1/1] screens' in text and 'launchApp' in text:
        seen=True; break
    if p.poll() is not None: break
    time.sleep(.25)
json.dump({'pid':p.pid,'activeScreensObserved':seen},open(r/'signal-observation.json','w'),indent=2)
if seen and p.poll() is None: os.kill(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=45)
except subprocess.TimeoutExpired:
    p.terminate(); rc=p.wait(timeout=10)
out.close(); err.close(); (r/'exit.txt').write_text(str(rc)+'\n')
PY
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1])
def load(path):
    try:return json.loads(path.read_text())
    except Exception:return {}
to=load(b/'timeout/report/report.json'); tf=load(b/'timeout/report/flows/flow-000.json'); tr=load(b/'timeout/ready.json')
io=load(b/'interrupt/report/report.json'); inf=load(b/'interrupt/report/flows/flow-000.json'); ir=load(b/'interrupt/ready.json')
terr=(b/'timeout/stderr.txt').read_text(); ierr=(b/'interrupt/stderr.txt').read_text()
checks={
 'timeoutNonzero':int((b/'timeout/exit.txt').read_text())!=0,
 'timeoutSentenceLast':terr.rstrip().splitlines()[-1].startswith('Error: grantiva killed the screens session after 30s'),
 'timeoutNoTrailingInterrupt':'interrupt' not in terr.rstrip().splitlines()[-1].lower(),
 'timeoutNoRunning':'running' not in json.dumps([to,tf,tr]).lower(),
 'interrupt130':int((b/'interrupt/exit.txt').read_text())==130,
 'interruptNarrated':'interrupt' in ierr.lower(),
 'interruptNoRunning':'running' not in json.dumps([io,inf,ir]).lower(),
 'interruptWasActive':load(b/'interrupt/signal-observation.json').get('activeScreensObserved') is True,
}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
raise SystemExit(0 if all(checks.values()) else 1)
PY
