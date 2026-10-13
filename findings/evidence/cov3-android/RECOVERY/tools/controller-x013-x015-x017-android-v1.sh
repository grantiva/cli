#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/X013-X015-X017-android-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/text" "$base/json" "$base/doctor"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-x013-x015-x017-android-v1.sh" "$base/input/controller-script.sh"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
cleanup() { cd "$P" 2>/dev/null || true; "$GRANTIVA" runner stop --json > "$base/trap-stop.out" 2> "$base/trap-stop.err" || true; }
trap cleanup EXIT INT TERM
# Exact explicit-platform doctor shapes.
printf '# cwd=%s\n$ %q doctor --platform android\n' "$PWD" "$GRANTIVA" > "$base/doctor/commands.txt"
"$GRANTIVA" doctor --platform android > "$base/doctor/text.out" 2> "$base/doctor/text.err"; doctor_text_rc=$?
printf '$ %q doctor --platform android --json\n' "$GRANTIVA" >> "$base/doctor/commands.txt"
"$GRANTIVA" doctor --platform android --json > "$base/doctor/json.out" 2> "$base/doctor/json.err"; doctor_json_rc=$?
jq . "$base/doctor/json.out" > "$base/doctor/json-pretty.json"
# Text detached lifecycle and exact live sessions listing.
printf '# cwd=%s\n$ %q runner start --platform android --device %q --detach\n' "$PWD" "$GRANTIVA" "$serial" > "$base/text/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --detach > "$base/text/start.out" 2> "$base/text/start.err"; text_start_rc=$?
cp .grantiva/session.json "$base/text/session.json"
printf '$ %q emulator sessions --json\n' "$GRANTIVA" >> "$base/text/commands.txt"
"$GRANTIVA" emulator sessions --json > "$base/text/sessions.json" 2> "$base/text/sessions.err"; sessions_rc=$?
jq . "$base/text/sessions.json" > "$base/text/sessions-pretty.json"
printf '$ %q runner stop\n' "$GRANTIVA" >> "$base/text/commands.txt"
"$GRANTIVA" runner stop > "$base/text/stop.out" 2> "$base/text/stop.err"; text_stop_rc=$?
# JSON detached lifecycle.
printf '# cwd=%s\n$ %q runner start --platform android --device %q --detach --json\n' "$PWD" "$GRANTIVA" "$serial" > "$base/json/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --detach --json > "$base/json/start.json" 2> "$base/json/start.err"; json_start_rc=$?
jq . "$base/json/start.json" > "$base/json/start-pretty.json"
cp .grantiva/session.json "$base/json/session.json"
printf '$ %q runner stop --json\n' "$GRANTIVA" >> "$base/json/commands.txt"
"$GRANTIVA" runner stop --json > "$base/json/stop.json" 2> "$base/json/stop.err"; json_stop_rc=$?
jq . "$base/json/stop.json" > "$base/json/stop-pretty.json"
printf '$ %q runner stop --json\n' "$GRANTIVA" >> "$base/json/commands.txt"
"$GRANTIVA" runner stop --json > "$base/json/no-session-stop.json" 2> "$base/json/no-session-stop.err"; no_session_rc=$?
jq . "$base/json/no-session-stop.json" > "$base/json/no-session-stop-pretty.json"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print | LC_ALL=C sort > "$base/session-files-after.txt"
printf 'doctor-text=%s doctor-json=%s text-start=%s sessions=%s text-stop=%s json-start=%s json-stop=%s no-session=%s\n' "$doctor_text_rc" "$doctor_json_rc" "$text_start_rc" "$sessions_rc" "$text_stop_rc" "$json_start_rc" "$json_stop_rc" "$no_session_rc" > "$base/summary.txt"
[ "$text_start_rc" -eq 0 ] && [ "$sessions_rc" -eq 0 ] && [ "$text_stop_rc" -eq 0 ] && [ "$json_start_rc" -eq 0 ] && [ "$json_stop_rc" -eq 0 ] && [ "$no_session_rc" -eq 0 ] && test ! -e .grantiva/session.json
