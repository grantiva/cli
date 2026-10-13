#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/keepalive-stop-contracts-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-keepalive-stop-contracts-v1.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
cp "$P/.maestro/coverage/02-exact-negative.yaml" "$base/input/02-exact-negative.yaml"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
run_case() {
  name="$1"; flow="$2"; terminal="$3"; d="$base/$name"; mkdir -p "$d"; ready="$d/ready.json"
  printf '# cwd=%s\n$ %q run --device %q --no-build --keep-alive --flow %q --ready-file %q --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$flow" "$ready" "$d/report" > "$d/commands.txt"
  "$GRANTIVA" run --device "$serial" --no-build --keep-alive --flow "$flow" --ready-file "$ready" --report-dir "$d/report" > "$d/run.out" 2> "$d/run.err" & rp=$!
  echo "owned-run-pid=$rp" >> "$d/commands.txt"; seen=0
  for attempt in $(seq 1 60); do
    if [ -f "$ready" ]; then status="$(jq -r '.status // empty' "$ready" 2>/dev/null || true)"; echo "attempt=$attempt status=$status" >> "$d/poll.txt"; if [ "$status" = "$terminal" ]; then seen=1; break; fi; fi
    kill -0 "$rp" 2>/dev/null || break; sleep 1
  done
  [ "$seen" -eq 1 ] || { kill -INT "$rp" 2>/dev/null || true; wait "$rp" 2>/dev/null || true; return 1; }
  kill -0 "$rp" 2>/dev/null || return 1
  cp "$ready" "$d/ready-before-stop.json"
  [ -f .grantiva/session.json ] && cp .grantiva/session.json "$d/session-before-stop.json"
  find .grantiva -maxdepth 2 -type f -print | LC_ALL=C sort > "$d/grantiva-before-stop.txt"
  "$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"; src=$?
  wait "$rp"; rrc=$?
  cp "$ready" "$d/ready-after-stop.json"; find .grantiva -maxdepth 2 -type f -print | LC_ALL=C sort > "$d/grantiva-after-stop.txt"; adb forward --list > "$d/forwards-after.txt"
  printf 'stop-rc=%s run-rc=%s\n' "$src" "$rrc" >> "$d/commands.txt"
  [ "$src" -eq 0 ] && [ "$(jq -r '.status' "$d/ready-after-stop.json")" = "$terminal" ] && cmp -s "$d/ready-before-stop.json" "$d/ready-after-stop.json" && test ! -e .grantiva/session.json
}
failures=0
run_case pass .maestro/01-browse.yaml passed || failures=$((failures+1))
run_case fail .maestro/coverage/02-exact-negative.yaml failed || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
