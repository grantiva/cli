#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N2-06-headless-matrix-rerun1"; name=cov3-android-n206-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n206-headless-matrix-v1.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){
 for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 4
run_mode(){
 label="$1"; expect="$2"; shift 2; d="$base/$label"; mkdir -p "$d"
 (cd "$base/project" && "$@" "$GRANTIVA" emulator ensure --name "$name") > "$d/ensure.out" 2> "$d/ensure.err" || return 5
 serial=$(tail -1 "$d/ensure.out" | tr -d '[:space:]'); [ -n "$serial" ] || return 6; echo "$serial" > "$d/serial.txt"
 [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || return 7
 ps -axo pid,ppid,etime,command | grep "[q]emu-system.*-avd $name" > "$d/qemu-process.txt" || return 8
 if grep -q -- ' -no-window' "$d/qemu-process.txt"; then actual=headless; else actual=windowed; fi
 printf 'expected=%s actual=%s\n' "$expect" "$actual" > "$d/result.txt"; [ "$actual" = "$expect" ] || return 9
 (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) > "$d/teardown.json" 2> "$d/teardown.err" || return 10
}
run_mode captured-baseline windowed env -u CI -u GRANTIVA_EMULATOR_HEADLESS || exit $?
run_mode ci-true headless env -u GRANTIVA_EMULATOR_HEADLESS CI=true || exit $?
run_mode ci-one headless env -u GRANTIVA_EMULATOR_HEADLESS CI=1 || exit $?
run_mode ci-zero windowed env -u GRANTIVA_EMULATOR_HEADLESS CI=0 || exit $?
run_mode ci-false windowed env -u GRANTIVA_EMULATOR_HEADLESS CI=false || exit $?
run_mode ci-empty windowed env -u GRANTIVA_EMULATOR_HEADLESS CI= || exit $?
run_mode env-headless headless env -u CI GRANTIVA_EMULATOR_HEADLESS=1 || exit $?
"$GRANTIVA" emulator ensure --help > "$base/input/emulator-ensure-help.txt"; "$GRANTIVA" run --help > "$base/input/run-help.txt"; "$GRANTIVA" build build --help > "$base/input/build-help.txt"; sed -n '52,62p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/android.md > "$base/input/docs-headless.txt"
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); expected={'captured-baseline':'windowed','ci-true':'headless','ci-one':'headless','ci-zero':'windowed','ci-false':'windowed','ci-empty':'windowed','env-headless':'headless'}; rows={k:(b/k/'result.txt').read_text().strip() for k in expected}; docs='\n'.join((b/'input'/x).read_text() for x in ['emulator-ensure-help.txt','run-help.txt','build-help.txt','docs-headless.txt'])
checks={'sevenModes':len(rows)==7,'allExpected':all(f'expected={v} actual={v}'==rows[k] for k,v in expected.items()),'helpDocsRule':'stdout is not a terminal' in docs and '--headless' in docs,'avdRemoved':'cov3-android-n206-r3' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}; (b/'decoded.json').write_text(json.dumps({'checks':checks,'rows':rows},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
