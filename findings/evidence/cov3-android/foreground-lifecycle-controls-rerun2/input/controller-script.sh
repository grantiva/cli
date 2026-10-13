#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/foreground-lifecycle-controls-rerun2"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/foreground" "$base/pass-sigint"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-foreground-lifecycle-v2.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/foreground-lifecycle-client-v2.py" "$base/input/client.py"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
printf '# cwd=%s\n$ python3 -I %q %q %q %q %q\n' "$PWD" "$base/input/client.py" "$base/foreground" "$P" "$GRANTIVA" "$serial" > "$base/commands.txt"
python3 -I "$base/input/client.py" "$base/foreground" "$P" "$GRANTIVA" "$serial"
fg_rc=$?
# Passing keep-alive released by SIGINT after its terminal result earns exit 0.
ready="$base/pass-sigint/ready.json"
printf '$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/01-browse.yaml --ready-file %q --report-dir %q\n' "$GRANTIVA" "$serial" "$ready" "$base/pass-sigint/report" >> "$base/commands.txt"
"$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/01-browse.yaml --ready-file "$ready" --report-dir "$base/pass-sigint/report" > "$base/pass-sigint/stdout.log" 2> "$base/pass-sigint/stderr.log" &
rp=$!
printf '%s\n' "$rp" > "$base/pass-sigint/grantiva-pid.txt"
passed=0
for attempt in $(seq 1 600); do
  if [ "$(jq -r '.status // empty' "$ready" 2>/dev/null || true)" = passed ] && kill -0 "$rp" 2>/dev/null; then cp "$ready" "$base/pass-sigint/ready-before-sigint.json"; passed=1; break; fi
  kill -0 "$rp" 2>/dev/null || break
  sleep 0.1
done
if [ "$passed" -ne 1 ]; then kill -INT "$rp" 2>/dev/null || true; wait "$rp" 2>/dev/null || true; exit 7; fi
kill -INT "$rp"
wait "$rp"
pass_rc=$?
printf '%s\n' "$pass_rc" > "$base/pass-sigint/exit.txt"
cp "$ready" "$base/pass-sigint/ready-after-sigint.json"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print | LC_ALL=C sort > "$base/session-files-after.txt"
printf 'foreground=%s pass-sigint=%s ready=%s\n' "$fg_rc" "$pass_rc" "$(jq -r '.status' "$ready")" > "$base/summary.txt"
[ "$fg_rc" -eq 0 ] && [ "$pass_rc" -eq 0 ] && [ "$(jq -r '.status' "$ready")" = passed ] && test ! -e .grantiva/session.json
