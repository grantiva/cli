#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K06-N06-three-fresh-captures-rerun2"; name=cov3-android-k06-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k06-n06-three-fresh-captures-v2.sh" "$base/input/controller-script.sh"; cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app.apk"; shasum -a 256 "$base/input/app.apk" > "$base/input/app.sha256"
python3 -I - "$P/grantiva-android.yml" "$base/project/grantiva-android.yml" "$name" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text(); lines=[]
for x in s.splitlines(): lines.append('emulator: '+sys.argv[3] if x.startswith('emulator:') else x)
pathlib.Path(sys.argv[2]).write_text('\n'.join(lines)+'\n')
PY
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){
 for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 4
for cycle in 1 2 3; do
 d="$base/cycle-$cycle"; mkdir -p "$d"
 (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$d/boot.out" 2> "$d/boot.err" || exit 5
 serial=""; for n in $(seq 1 120); do for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done; [ -n "$serial" ] && break; sleep 1; done
 [ -n "$serial" ] || exit 6; echo "$serial" > "$d/serial.txt"; (cd "$base/project" && "$GRANTIVA" build install --platform android --device "$serial" --application-id com.kylebrowning.landmarks --no-build --app-file "$base/input/app.apk" --no-launch) > "$d/install.out" 2> "$d/install.err" || exit 7
 ps -axo pid,ppid,etime,command | grep "[q]emu-system.*-avd $name" > "$d/qemu-process.txt" || exit 7
 (cd "$base/project" && "$GRANTIVA" diff capture --platform android --device "$serial" --application-id com.kylebrowning.landmarks --no-build --verbose --json) > "$d/capture.json" 2> "$d/capture.err"; rc=$?; echo "$rc" > "$d/capture.exit.txt"
 [ "$rc" -eq 0 ] || exit 8; cp -R "$base/project/.grantiva/captures/android" "$d/captures"
 (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) > "$d/teardown.json" 2> "$d/teardown.err" || exit 9
done
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
mkdir -p "$base/source"; rg -n -C 6 'Screenshot.*refus|UIAutomator2.*stopped responding|retried once|connection refused' /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg > "$base/source/recovery-tests.txt" || true
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for i in (1,2,3):
 d=b/f'cycle-{i}'; j=json.load(open(d/'capture.json')); err=(d/'capture.err').read_text(); rows.append({'cycle':i,'screens':len(j.get('screens',[])),'statuses':[step.get('status') for screen in j.get('screens',[]) for step in screen.get('steps',[])],'rawSocket':'dial unix' in err or 'connection refused' in err.lower(),'restoreWarnings':sum('restore' in x.lower() and 'warning' in x.lower() for x in err.splitlines())})
checks={'threeCaptures':len(rows)==3,'allFiveScreens':all(r['screens']==5 for r in rows),'allStepsPresent':all(r['statuses'] for r in rows),'allPassed':all(not r['rawSocket'] and all(x=='passed' for x in r['statuses']) for r in rows),'restoreWarningsBounded':all(r['restoreWarnings']<=1 for r in rows),'coldBootCommands':all('-no-snapshot-load' in (b/f'cycle-{i}/qemu-process.txt').read_text() for i in (1,2,3)),'avdRemoved':'cov3-android-k06-r3' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'cycles':rows},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
