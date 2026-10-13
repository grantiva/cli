#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-115-primary-offline-rerun2"; name=cov3-android; serial=emulator-5554
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and115-primary-offline-v2.sh" "$base/input/controller-script.sh"; cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"; cp "$W/findings/evidence/cov3-android/D2-09-shutdown-appfile-capture-rerun1/input/app.apk" "$base/input/app.apk"
cat > "$base/project/grantiva-android.yml" <<'YAML'
platform: android
application_id: com.kylebrowning.landmarks
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 3
[ "$(adb devices|awk '$2=="device"{n++} END{print n+0}')" -eq 1 ] || exit 4
ensure_pid=""
restore_primary(){
 if [ -n "$ensure_pid" ] && kill -0 "$ensure_pid" 2>/dev/null; then wait "$ensure_pid" 2>/dev/null || true; ensure_pid=""; fi
 if [ "$(adb -s "$serial" get-state 2>/dev/null)" != device ]; then (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name") >> "$base/restore-ensure.out" 2>> "$base/restore-ensure.err" || true; fi
 if [ "$(adb -s "$serial" get-state 2>/dev/null)" = device ]; then adb -s "$serial" install -r -t -d "$base/input/app.apk" >> "$base/restore-install.out" 2>> "$base/restore-install.err" || true; fi
}
trap restore_primary EXIT
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) > "$base/teardown.json" 2> "$base/teardown.err" || exit 5
for i in $(seq 1 100); do adb -s "$serial" get-state >/dev/null 2>&1 || break; sleep .1; done; adb devices -l > "$base/adb-shutdown.txt"
(cd "$base/project" && exec "$GRANTIVA" emulator ensure --name "$name") > "$base/ensure.out" 2> "$base/ensure.err" & ensure_pid=$!; echo "$ensure_pid" > "$base/ensure.pid"
observed=0
for i in $(seq 1 200); do state="$(adb devices | awk -v s="$serial" '$1==s{print $2}')"; printf '%s %s\n' "$i" "$state" >> "$base/offline-poll.txt"; if [ "$state" = offline ]; then observed=1; break; fi; kill -0 "$ensure_pid" 2>/dev/null || break; sleep .1; done
[ "$observed" -eq 1 ] || exit 6; cp "$HOME/.grantiva/android/started.json" "$base/started-offline.json"; adb devices -l > "$base/adb-offline.txt"
printf '$ %q run --platform android --no-build --app-file %q --flow .maestro/01-browse.yaml --report-dir %q --verbose\n' "$GRANTIVA" "$base/input/app.apk" "$base/report" > "$base/run-command.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --no-build --app-file "$base/input/app.apk" --flow .maestro/01-browse.yaml --report-dir "$base/report" --verbose) > "$base/run.out" 2> "$base/run.err"; rrc=$?; echo "$rrc" > "$base/run.exit.txt"
wait "$ensure_pid"; erc=$?; ensure_pid=""; echo "$erc" > "$base/ensure.exit.txt"
restore_primary; trap - EXIT; adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/installed-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$name" "$serial" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,serial=sys.argv[2:]; text=(b/'run.out').read_text()+(b/'run.err').read_text(); report=json.loads((b/'report/report.json').read_text())
checks={'primaryWasShutdown':serial not in (b/'adb-shutdown.txt').read_text(),'observedOfflineBeforeRun':' offline' in (b/'adb-offline.txt').read_text(),'noEmulatorInConfig':'emulator:' not in (b/'project/grantiva-android.yml').read_text(),'runHasNoTargetFlag':'--device' not in (b/'run-command.txt').read_text() and '--emulator' not in (b/'run-command.txt').read_text(),'waitNarration':'Waiting for' in text and serial in text and 'finish booting' in text,'selectedBootingPrimary':name in text and serial in text,'run0':(b/'run.exit.txt').read_text().strip()=='0' and report.get('status')=='passed','ensure0':(b/'ensure.exit.txt').read_text().strip()=='0','primaryRestored':serial in (b/'adb-after.txt').read_text() and 'package:' in (b/'installed-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
