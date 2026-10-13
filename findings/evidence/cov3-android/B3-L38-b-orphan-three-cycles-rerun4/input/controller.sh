#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L38-b-orphan-three-cycles-rerun4"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project" "$base/cycles"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l38b-orphan-three-cycles-v4.sh" "$base/input/controller.sh"
rsync -a --exclude .grantiva --exclude .gradle --exclude build --exclude '*/build' "$P/" "$base/project/"
apk="$P/app/build/outputs/apk/free/debug/app-free-debug.apk"; [ -f "$apk" ] || exit 3
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices|awk '$2=="device"{print $1}'|while read -r s;do [ "$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ]&&echo "$s";done)"
[ "$serial" = emulator-5554 ] || exit 4
[ ! -e "$base/project/.grantiva/session.json" ] || exit 5
run_pid='';port=''
cleanup(){
  case "$port" in ''|*[!0-9]*) ;; *) $adb_bin -s "$serial" forward --remove "tcp:$port" >/dev/null 2>&1 || true;; esac
  (cd "$base/project"&&"$GRANTIVA" runner stop --json) >>"$base/final-stop.json" 2>>"$base/final-stop.err" || true
  if [ -n "$run_pid" ]&&kill -0 "$run_pid" 2>/dev/null;then kill -INT "$run_pid" 2>/dev/null||true;wait "$run_pid" 2>/dev/null||true;fi
}
trap cleanup EXIT INT TERM
printf 'primary=%s\nthree cycles: keepalive; kill -9 owned parent; detached verbose start; immediate dump; normal stop\n' "$serial" >"$base/commands.txt"
for cycle in 1 2 3;do
 d="$base/cycles/$cycle";mkdir -p "$d/report"
 (cd "$base/project"&&exec "$GRANTIVA" run --platform android --device "$serial" --no-build --app-file "$apk" --keep-alive --flow .maestro/11-slow.yaml --report-dir "$d/report") >"$d/run.out" 2>"$d/run.err"&run_pid=$!
 owner='';for _ in $(seq 1 600);do
  for f in /tmp/grantiva-sessions/*.owner.json /private/tmp/grantiva-sessions/*.owner.json;do
   [ -f "$f" ]||continue
   [ "$(jq -r '.grantivaPid//0' "$f")" = "$run_pid" ]&&[ "$(jq -r '.udid//empty' "$f")" = "$serial" ]&&owner="$f"
  done
  [ -n "$owner" ]&&grep -q launchApp "$d/run.err"&&break
  kill -0 "$run_pid" 2>/dev/null||break;sleep .05
 done
 [ -n "$owner" ]||exit 10
 cp "$owner" "$d/owner-before-kill.json";runner_pid="$(jq -r .runnerPid "$owner")"
$adb_bin forward --list >"$d/forwards-before.txt"
 port="$($adb_bin -s "$serial" forward tcp:0 tcp:6790)";case "$port" in ''|*[!0-9]*) exit 11;;esac
 printf '%s\n' "$port" >"$d/owned-uia2-forwarded-host-port.txt"
 $adb_bin forward --list >"$d/forwards-with-owned.txt"
 curl -fsS "http://127.0.0.1:$port/wd/hub/sessions" >"$d/sessions-before-kill.json" 2>"$d/sessions-before-kill.err"||exit 11
 old_id="$(jq -r '.value[0].id//empty' "$d/sessions-before-kill.json")";[ -n "$old_id" ]||exit 12
 printf 'kill -9 %s\n' "$run_pid" >"$d/kill-command.txt";kill -9 "$run_pid";wait "$run_pid" 2>/dev/null;echo $? >"$d/killed-parent.exit";run_pid=''
 for _ in $(seq 1 100);do kill -0 "$runner_pid" 2>/dev/null||break;sleep .05;done
 ! kill -0 "$runner_pid" 2>/dev/null||exit 13
 curl -fsS "http://127.0.0.1:$port/wd/hub/sessions" >"$d/orphan-sessions.json"||exit 14
 jq -e --arg x "$old_id" '.value|map(.id)|index($x)!=null' "$d/orphan-sessions.json" >/dev/null||exit 15
 $adb_bin -s "$serial" forward --remove "tcp:$port";echo $? >"$d/remove-owned-forward.exit"
 port=''
 $adb_bin forward --list >"$d/forwards-after-remove.txt"
 (cd "$base/project"&&"$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json --verbose) >"$d/start.json" 2>"$d/start.verbose.err";echo $? >"$d/start.exit"
 jq -e '.state=="ready" and (.port|type=="number")' "$base/project/.grantiva/session.json" >/dev/null||exit 16
 cp "$base/project/.grantiva/session.json" "$d/new-session.json"
 new_port="$(jq -r '.port//empty' "$d/new-session.json")";case "$new_port" in ''|*[!0-9]*) exit 17;;esac
 printf '%s\n' "$new_port" >"$d/new-uia2-session-port.txt"
 curl -fsS "http://127.0.0.1:$new_port/wd/hub/sessions" >"$d/new-uia2-sessions.json" 2>"$d/new-uia2-sessions.err"||exit 17
 new_id="$(jq -r --arg old "$old_id" '[.value[].id|select(.!=$old)][0]//empty' "$d/new-uia2-sessions.json")";[ -n "$new_id" ]&&[ "$new_id" != "$old_id" ]||exit 18
 printf '%s\n' "$old_id" >"$d/old-uia2-session-id.txt";printf '%s\n' "$new_id" >"$d/new-uia2-session-id.txt"
 (cd "$base/project"&&"$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json) >"$d/immediate-dump.json" 2>"$d/immediate-dump.err";echo $? >"$d/immediate-dump.exit"
 (cd "$base/project"&&"$GRANTIVA" runner stop --json) >"$d/stop.json" 2>"$d/stop.err";echo $? >"$d/stop.exit"
done
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]);rows=[]
for n in ('1','2','3'):
 d=b/'cycles'/n;old=(d/'old-uia2-session-id.txt').read_text().strip();new=(d/'new-uia2-session-id.txt').read_text().strip()
 verbose=(d/'start.verbose.err').read_text()
 rows.append({'cycle':int(n),'old':old,'new':new,'different':old!=new,'start0':(d/'start.exit').read_text().strip()=='0','dump0':(d/'immediate-dump.exit').read_text().strip()=='0','stop0':(d/'stop.exit').read_text().strip()=='0','verboseHasNoKill':all(x not in verbose for x in ('force-stop','kill -9','pkill','killall'))})
assert all(all(v for k,v in r.items() if k not in ('cycle','old','new')) for r in rows)
(b/'decoded.json').write_text(json.dumps(rows,indent=2)+'\n')
PY
rc=$?
sed -n '600,760p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift >"$base/input/RunnerLifecycleCommandTests.swift.excerpt"
cleanup;trap - EXIT INT TERM
exit "$rc"
