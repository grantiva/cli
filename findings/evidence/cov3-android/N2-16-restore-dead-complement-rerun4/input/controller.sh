#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N2-16-restore-dead-complement-rerun4";name=cov3-android-n216-r4
[ ! -e "$base" ]||exit 2;mkdir -p "$base/input" "$base/project" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n216-restore-dead-complement-v4.sh" "$base/input/controller.sh"
rsync -a --exclude .grantiva --exclude .gradle --exclude build --exclude '*/build' "$P/" "$base/project/"
apk="$P/app/build/outputs/apk/free/debug/app-free-debug.apk";[ -f "$apk" ]||exit 3
cat >"$base/input/run-and-reap.py" <<'PY2'
import json,pathlib,subprocess,sys
out,cwd,g,serial,apk=sys.argv[1:];o=pathlib.Path(out);o.mkdir(parents=True,exist_ok=True)
cmd=[g,'run','--platform','android','--device',serial,'--no-build','--app-file',apk,'--flow','.maestro/11-slow.yaml','--report-dir',str(o/'report')]
(o/'command.json').write_text(json.dumps(cmd)+'\n');so=open(o/'run.out','w');se=open(o/'run.err','w')
p=subprocess.Popen(cmd,cwd=cwd,stdout=so,stderr=se);(o/'cli.pid').write_text(str(p.pid)+'\n');rc=p.wait();so.close();se.close();(o/'run.exit').write_text(str(rc)+'\n')
PY2
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb;avdmanager_bin=/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager
"$avdmanager_bin" list avd -c >"$base/avds-before.txt";grep -Fxq "$name" "$base/avds-before.txt"&&exit 4
serial='';owned=0;run_pid=''
cleanup(){
 if [ -n "$run_pid" ]&&kill -0 "$run_pid" 2>/dev/null;then kill -INT "$run_pid" 2>/dev/null||true;wait "$run_pid" 2>/dev/null||true;fi
 if [ -n "$serial" ];then (cd "$base/project"&&"$GRANTIVA" emulator teardown --serial "$serial" --force --json)>>"$base/trap-teardown.json" 2>>"$base/trap-teardown.err"||true;fi
 if [ "$owned" -eq 1 ];then (cd "$base/project"&&"$GRANTIVA" emulator delete --name "$name" --force --json)>>"$base/trap-delete.json" 2>>"$base/trap-delete.err"||true;fi
}
trap cleanup EXIT INT TERM
printf 'joins retained K06 three fresh first-capture passes; this complement kills exact row-owned secondary during .maestro/11-slow.yaml\n' >"$base/commands.txt"
(cd "$base/project"&&"$GRANTIVA" emulator ensure --name "$name" --no-boot)>"$base/create.out" 2>"$base/create.err"||exit 5;owned=1
(cd "$base/project"&&"$GRANTIVA" emulator ensure --name "$name" --headless)>"$base/boot.out" 2>"$base/boot.err"||exit 6
for _ in $(seq 1 120);do serial="$($adb_bin devices|awk '$2=="device"{print $1}'|while read -r s;do [ "$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]&&echo "$s";done|head -1)";[ -n "$serial" ]&&break;sleep 1;done
[ -n "$serial" ]||exit 7
(cd "$base/project"&&"$GRANTIVA" build install --no-build --no-launch --app-file "$apk" --device "$serial")>"$base/install.out" 2>"$base/install.err"||exit 8
python3 -I "$base/input/run-and-reap.py" "$base/run" "$base/project" "$GRANTIVA" "$serial" "$apk"&run_pid=$!
active=0;for _ in $(seq 1 600);do grep -q launchApp "$base/run/run.err" 2>/dev/null&&{ active=1;break;};kill -0 "$run_pid" 2>/dev/null||break;sleep .05;done
[ "$active" -eq 1 ]||exit 9
python3 -I -c 'import time;print(time.monotonic())' >"$base/run/teardown-start.monotonic"
(cd "$base/project"&&"$GRANTIVA" emulator teardown --serial "$serial" --force --json)>"$base/run/teardown.json" 2>"$base/run/teardown.err";echo $? >"$base/run/teardown.exit"
wait "$run_pid";helper_rc=$?;run_pid='';printf '%s\n' "$helper_rc" >"$base/run/helper.exit";rrc="$(cat "$base/run/run.exit")"
python3 -I -c 'import time;print(time.monotonic())' >"$base/run/run-end.monotonic"
$adb_bin devices -l >"$base/run/adb-after.txt"
# A second row-owned boot kills the exact qemu process, rather than asking
# teardown to stop the CLI first, so restoration observes a serial that left adb.
(cd "$base/project"&&"$GRANTIVA" emulator ensure --name "$name" --headless)>"$base/direct-boot.out" 2>"$base/direct-boot.err"||exit 12
serial='';for _ in $(seq 1 120);do serial="$($adb_bin devices|awk '$2=="device"{print $1}'|while read -r s;do [ "$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]&&echo "$s";done|head -1)";[ -n "$serial" ]&&break;sleep 1;done
[ -n "$serial" ]||exit 13
(cd "$base/project"&&"$GRANTIVA" build install --no-build --no-launch --app-file "$apk" --device "$serial")>"$base/direct-install.out" 2>"$base/direct-install.err"||exit 14
python3 -I "$base/input/run-and-reap.py" "$base/direct" "$base/project" "$GRANTIVA" "$serial" "$apk"&run_pid=$!
active=0;for _ in $(seq 1 600);do grep -q launchApp "$base/direct/run.err" 2>/dev/null&&{ active=1;break;};kill -0 "$run_pid" 2>/dev/null||break;sleep .05;done
[ "$active" -eq 1 ]||exit 15
ps -axo pid=,command= >"$base/direct/ps-before-kill.txt"
qpid="$(python3 -I - "$base/direct/ps-before-kill.txt" "$name" <<'PYQ'
import pathlib,shlex,sys
hits=[]
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
 p,_,cmd=line.strip().partition(' ')
 try:a=shlex.split(cmd)
 except ValueError:continue
 if any(a[i]=='-avd' and i+1<len(a) and a[i+1]==sys.argv[2] for i in range(len(a))):hits.append(p)
assert len(hits)==1,hits
print(hits[0])
PYQ
)";case "$qpid" in ''|*[!0-9]*) exit 16;;esac
printf 'kill -9 %s # exact qemu -avd %s\n' "$qpid" "$name" >"$base/direct/kill-command.txt"
python3 -I -c 'import time;print(time.monotonic())' >"$base/direct/kill-start.monotonic";kill -9 "$qpid"
wait "$run_pid";echo $? >"$base/direct/helper.exit";run_pid='';python3 -I -c 'import time;print(time.monotonic())' >"$base/direct/run-end.monotonic"
python3 -I - "$base" <<'PY3' || exit 17
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]);err=(b/'direct/run.err').read_text();lines=[x for x in err.splitlines() if 'restor' in x.lower() or 'left adb' in x.lower()];elapsed=float((b/'direct/run-end.monotonic').read_text())-float((b/'direct/kill-start.monotonic').read_text())
d={'secondsKillThroughRunExit':elapsed,'restoreLines':lines,'runExit':(b/'direct/run.exit').read_text().strip()};(b/'direct/decoded.json').write_text(json.dumps(d,indent=2)+'\n')
assert any('5 s' in x or '5s' in x or 'within 5' in x for x in lines),lines
assert elapsed < 15,elapsed
PY3
python3 -I - "$base" "$serial" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]);serial=sys.argv[2];err=(b/'run/run.err').read_text();t0=float((b/'run/teardown-start.monotonic').read_text());t1=float((b/'run/run-end.monotonic').read_text())
warnings=[x for x in err.splitlines() if 'restor' in x.lower() or 'left adb' in x.lower()]
decoded={'serial':serial,'secondsFromTeardownThroughRunExit':t1-t0,'restoreLines':warnings,'serialAbsentAfter':serial not in (b/'run/adb-after.txt').read_text(),'teardownExit':(b/'run/teardown.exit').read_text().strip(),'runExit':(b/'run/run.exit').read_text().strip()}
(b/'decoded.json').write_text(json.dumps(decoded,indent=2)+'\n')
assert decoded['serialAbsentAfter'] and decoded['teardownExit']=='0'
# The literal teardown leg may stop the CLI before killing the emulator; decoded timing is retained.
assert decoded['secondsFromTeardownThroughRunExit'] < 40
PY
rc=$?
rg -n "30|offline|5 s|left adb|restore Android settings" /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests >"$base/input/offline-timeout-source-hits.txt"||true
(cd "$base/project"&&"$GRANTIVA" emulator delete --name "$name" --force --json)>"$base/delete.json" 2>"$base/delete.err"||exit 10
owned=0;serial='';trap - EXIT INT TERM
"$avdmanager_bin" list avd -c >"$base/avds-after.txt";grep -Fxq "$name" "$base/avds-after.txt"&&exit 11
exit "$rc"
