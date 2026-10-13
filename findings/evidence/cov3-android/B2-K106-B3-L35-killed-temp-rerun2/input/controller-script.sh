#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K106-B3-L35-killed-temp-rerun2"; name=cov3-android-k106-r4
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/live-project" "$base/secondary-project" "$base/legs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k106-b3l35-killed-temp-v2.sh" "$base/input/controller-script.sh"
rsync -a --exclude .grantiva --exclude .gradle --exclude build --exclude '*/build' "$P/" "$base/live-project/"
rsync -a --exclude .grantiva --exclude .gradle --exclude build --exclude '*/build' "$P/" "$base/secondary-project/"
apk="$P/app/build/outputs/apk/free/debug/app-free-debug.apk"; [ -f "$apk" ] || exit 3
shasum -a 256 "$apk" >"$base/input/app-free-debug.apk.sha256"
cat >"$base/input/kill-run.py" <<'PY'
import json,os,pathlib,signal,subprocess,sys,time
out,cwd,g,serial,apk,home,mode,report=sys.argv[1:]
o=pathlib.Path(out);cmd=[g,'run','--platform','android','--device',serial,'--no-build','--app-file',apk,'--flow','.maestro/11-slow.yaml']
if mode=='keepalive':cmd.append('--keep-alive')
if report!='-':cmd += ['--report-dir',report]
(o/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');stdout=open(o/'run.out','wb');stderr=open(o/'run.err','wb')
p=subprocess.Popen(cmd,cwd=cwd,stdout=stdout,stderr=stderr,start_new_session=True);(o/'parent.pid').write_text(str(p.pid)+'\n')
lock=pathlib.Path(home)/'locks'/(serial+'.lock');deadline=time.monotonic()+45;claim=None
while time.monotonic()<deadline and p.poll() is None:
 try:
  claim=json.loads(lock.read_text())
  if claim.get('pid')==p.pid and len(claim.get('temporaryDirectories',[])) >= (2 if report=='-' else 1):break
 except Exception:pass
 time.sleep(.05)
else:
 try: os.kill(p.pid,signal.SIGINT)
 except ProcessLookupError: pass
 try: p.wait(timeout=15)
 except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=10)
 stdout.close(); stderr.close()
 raise SystemExit('owned live claim with two temp directories not observed')
(o/'lease-path.txt').write_text(str(lock)+'\n');(o/'claim-before-kill.json').write_text(json.dumps(claim,indent=2)+'\n')
for x in claim['temporaryDirectories']:
 if not pathlib.Path(x).exists():raise SystemExit('claimed directory absent '+x)
os.kill(p.pid,signal.SIGKILL);rc=p.wait(timeout=20);stdout.close();stderr.close();(o/'run.exit').write_text(str(rc)+'\n')
PY

adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb; avdmanager_bin=/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager
primary="$($adb_bin devices|awk '$2=="device"{print $1}'|while read -r s;do [ "$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ]&&echo "$s";done)"
[ "$primary" = emulator-5554 ] || exit 4
"$avdmanager_bin" list avd -c >"$base/avds-before.txt"; grep -Fxq "$name" "$base/avds-before.txt" && exit 5
secondary=''; live_pid=''; owned=0
cleanup(){
 if [ -n "$live_pid" ] && kill -0 "$live_pid" 2>/dev/null;then kill -INT "$live_pid" 2>/dev/null||true;wait "$live_pid" 2>/dev/null||true;fi
 if [ -n "$secondary" ];then (cd "$base/secondary-project"&&"$GRANTIVA" emulator teardown --serial "$secondary" --force --json)>>"$base/trap-teardown.json" 2>>"$base/trap-teardown.err"||true;fi
 if [ "$owned" -eq 1 ];then (cd "$base/secondary-project"&&"$GRANTIVA" emulator delete --name "$name" --force --json)>>"$base/trap-delete.json" 2>>"$base/trap-delete.err"||true;fi
}
trap cleanup EXIT INT TERM
{
 echo "owned_avd=$name"
 echo "primary_live_control=$primary"
 echo 'three exact kill -9 legs: keep-alive text teardown, plain JSON teardown, preserved-report JSON teardown'
 echo 'no --all; targeted secondary serial only'
} >"$base/commands.txt"

(cd "$base/secondary-project"&&"$GRANTIVA" emulator ensure --name "$name" --no-boot)>"$base/create.out" 2>"$base/create.err"||exit 6;owned=1
boot_secondary(){
 (cd "$base/secondary-project"&&"$GRANTIVA" emulator ensure --name "$name" --headless)>"$1-boot.out" 2>"$1-boot.err"||return 1
 secondary='';for _ in $(seq 1 90);do secondary="$($adb_bin devices|awk '$2=="device"{print $1}'|while read -r s;do [ "$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]&&echo "$s";done|head -1)";[ -n "$secondary" ]&&break;sleep 1;done
 [ -n "$secondary" ]||return 2
}
boot_secondary "$base/initial"||exit 7
(cd "$base/secondary-project"&&"$GRANTIVA" build install --no-build --app-file "$apk" --device "$secondary" --no-launch)>"$base/install.out" 2>"$base/install.err"||exit 8

# A live claim on the unrelated primary emulator must survive every secondary teardown.
(cd "$base/live-project"&&"$GRANTIVA" run --platform android --device "$primary" --no-build --app-file "$apk" --keep-alive --flow .maestro/11-slow.yaml)>"$base/live.out" 2>"$base/live.err"&live_pid=$!
live_lock="$GRANTIVA_RUNNER_HOME/locks/$primary.lock";live_ready=0
for _ in $(seq 1 600);do
 python3 -I - "$live_lock" "$live_pid" "$base/live-claim-before.json" <<'PY' && { live_ready=1;break; }
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]);d=json.loads(p.read_text());assert d.get('pid')==int(sys.argv[2]) and len(d.get('temporaryDirectories',[]))>=2
pathlib.Path(sys.argv[3]).write_text(json.dumps(d,indent=2)+'\n')
PY
 sleep .05
done
[ "$live_ready" -eq 1 ]||exit 9

run_killed_leg(){
 leg="$1";mode="$2";format="$3";report="$4";d="$base/legs/$leg";mkdir -p "$d"
 python3 -I "$base/input/kill-run.py" "$d" "$base/secondary-project" "$GRANTIVA" "$secondary" "$apk" "$GRANTIVA_RUNNER_HOME" "$mode" "$report"||return 1
 if [ "$format" = json ];then (cd "$base/secondary-project"&&"$GRANTIVA" emulator teardown --serial "$secondary" --force --json)>"$d/teardown.json" 2>"$d/teardown.err";else (cd "$base/secondary-project"&&"$GRANTIVA" emulator teardown --serial "$secondary" --force)>"$d/teardown.txt" 2>"$d/teardown.err";fi
 echo $? >"$d/teardown.exit"
 cp "$live_lock" "$d/live-claim-after-teardown.json"||return 2
 return 0
}

run_killed_leg keepalive keepalive text -||exit 10
secondary='';boot_secondary "$base/plain"||exit 11
run_killed_leg plain plain json -||exit 12
secondary='';boot_secondary "$base/preserved"||exit 13
mkdir -p "$base/preserved-report";echo sentinel >"$base/preserved-report/row-sentinel.txt"
run_killed_leg preserved plain json "$base/preserved-report"||exit 14

python3 -I - "$base" "$live_pid" <<'PY' || exit 15
import json,os,pathlib,sys
b=pathlib.Path(sys.argv[1]);live0=json.load(open(b/'live-claim-before.json'));livepaths=live0['temporaryDirectories']
assert os.kill(int(sys.argv[2]),0) is None
for p in livepaths:assert pathlib.Path(p).exists(),p
for name in ['keepalive','plain','preserved']:
 d=b/'legs'/name;claim=json.load(open(d/'claim-before-kill.json'));paths=claim['temporaryDirectories'];assert len(paths)>=(1 if name=='preserved' else 2)
 assert not pathlib.Path((d/'lease-path.txt').read_text().strip()).exists()
 assert all(not pathlib.Path(p).exists() for p in paths),paths
 assert (d/'teardown.exit').read_text().strip()=='0'
 if name=='keepalive':
  text=(d/'teardown.txt').read_text()+(d/'teardown.err').read_text();assert all(p in text for p in paths),text
 else:
  raw=json.load(open(d/'teardown.json'));row=raw[0] if isinstance(raw,list) else raw;removed=row.get('temporaryDirectoriesRemoved',[]);assert all(p in removed for p in paths),(paths,removed)
assert (b/'preserved-report/row-sentinel.txt').read_text().strip()=='sentinel'
(b/'decoded.json').write_text(json.dumps({'livePathsPreserved':livepaths,'keepaliveText':True,'plainJSON':True,'preservedReport':True},indent=2)+'\n')
PY

kill -INT "$live_pid";wait "$live_pid";echo $? >"$base/live.exit";live_pid=''
(cd "$base/secondary-project"&&"$GRANTIVA" emulator delete --name "$name" --json)>"$base/delete.json" 2>"$base/delete.err"||exit 16
owned=0;secondary='';trap - EXIT INT TERM
"$avdmanager_bin" list avd -c >"$base/avds-after.txt";grep -Fxq "$name" "$base/avds-after.txt"&&exit 17
sed -n '620,705p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/EmulatorManager.swift >"$base/input/EmulatorManager.swift.excerpt"
sed -n '190,275p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/SimulatorReaper.swift >"$base/input/SimulatorReaper.swift.excerpt"
find "$base" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$base/all-files.sha256"
