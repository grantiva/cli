#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/B2-K27-pty-windowed-rerun2"
name=cov3-android-k27-pty-r3
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k27-pty-windowed-v2.sh" "$base/input/controller-script.sh"
cat >"$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
cat >"$base/input/pty-child.sh" <<'SH'
#!/bin/bash
if [ -t 0 ]; then stdin_tty=true; else stdin_tty=false; fi
if [ -t 1 ]; then stdout_tty=true; else stdout_tty=false; fi
if [ -t 2 ]; then stderr_tty=true; else stderr_tty=false; fi
printf 'stdin_is_tty=%s stdout_is_tty=%s stderr_is_tty=%s CI=%s GRANTIVA_EMULATOR_HEADLESS=%s\n' \
 "$stdin_tty" "$stdout_tty" "$stderr_tty" "${CI-unset}" "${GRANTIVA_EMULATOR_HEADLESS-unset}"
exec "$GRANTIVA" emulator ensure --name "$K27_AVD_NAME"
SH
chmod +x "$base/input/pty-child.sh"

adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
avdmanager_bin=/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager
"$avdmanager_bin" list avd -c >"$base/avds-before.txt"
grep -Fxq "$name" "$base/avds-before.txt" && { echo name-already-exists >&2; exit 3; }
"$adb_bin" devices -l >"$base/adb-before.txt"

serial=''
cleanup() {
 if [ -n "$serial" ]; then
  (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) >>"$base/trap-teardown.json" 2>>"$base/trap-teardown.err" || true
 fi
 "$avdmanager_bin" list avd -c | grep -Fxq "$name" && \
  (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >>"$base/trap-delete.json" 2>>"$base/trap-delete.err" || true
}
trap cleanup EXIT

(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) >"$base/create.out" 2>"$base/create.err" || exit 4
printf '# actual PTY via /usr/bin/script; child verifies fd tty state and receives CI/headless unset\n' >"$base/commands.txt"
printf '$ env -u CI -u GRANTIVA_EMULATOR_HEADLESS K27_AVD_NAME=%q script -q %q %q\n' "$name" "$base/pty-transcript.txt" "$base/input/pty-child.sh" >>"$base/commands.txt"

(cd "$base/project" && /usr/bin/env -u CI -u GRANTIVA_EMULATOR_HEADLESS K27_AVD_NAME="$name" \
 /usr/bin/script -q "$base/pty-transcript.txt" "$base/input/pty-child.sh") >"$base/script.out" 2>"$base/script.err"; prc=$?
echo "$prc" >"$base/script.exit"
[ "$prc" -eq 0 ] || exit 5

for _ in $(seq 1 120); do
 serial="$($adb_bin devices | awk '$2=="device"{print $1}' | while read -r s; do n="$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; [ "$n" = "$name" ] && echo "$s"; done | head -1)"
 [ -n "$serial" ] && break
 sleep 1
done
[ -n "$serial" ] || { echo owned-serial-not-found >&2; exit 6; }
echo "$serial" >"$base/serial.txt"
ps -axo pid=,ppid=,etime=,command= | grep "[q]emu-system.*-avd $name" >"$base/qemu-process.txt" || exit 7
grep -q 'stdout_is_tty=true' "$base/pty-transcript.txt" || exit 8
grep -q 'CI=unset GRANTIVA_EMULATOR_HEADLESS=unset' "$base/pty-transcript.txt" || exit 9
if grep -q -- ' -no-window' "$base/qemu-process.txt"; then echo unexpected-headless >&2; exit 10; fi

(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --json) >"$base/teardown.json" 2>"$base/teardown.err" || exit 11
serial=''
(cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --json) >"$base/delete.json" 2>"$base/delete.err" || exit 12

trap - EXIT
"$avdmanager_bin" list avd -c >"$base/avds-after.txt"
"$adb_bin" devices -l >"$base/adb-after.txt"
grep -Fxq "$name" "$base/avds-after.txt" && exit 13
ps -axo pid=,ppid=,etime=,command= >"$base/processes-after.txt"
grep -q "$name" "$base/processes-after.txt" && exit 14

sed -n '935,990p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/EmulatorManagerTests.swift >"$base/input/EmulatorManagerTests.swift.excerpt"
sed -n '20,75p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/EmulatorCommand.swift >"$base/input/EmulatorCommand.swift.excerpt"
sed -n '45,70p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/android.md >"$base/input/android-docs.excerpt"
python3 -I - "$base" "$name" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name=sys.argv[2]
checks={
 'ptyStdout': 'stdout_is_tty=true' in (b/'pty-transcript.txt').read_text(errors='replace'),
 'ciUnset': 'CI=unset GRANTIVA_EMULATOR_HEADLESS=unset' in (b/'pty-transcript.txt').read_text(errors='replace'),
 'windowed': ' -no-window' not in (b/'qemu-process.txt').read_text(errors='replace'),
 'targetedTeardown': json.loads((b/'teardown.json').read_text()) is not None,
 'targetedDelete': json.loads((b/'delete.json').read_text()) is not None,
 'avdAbsent': name not in (b/'avds-after.txt').read_text().splitlines(),
}
(b/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
raise SystemExit(0 if all(checks.values()) else 1)
PY
find "$base" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$base/all-files.sha256"
