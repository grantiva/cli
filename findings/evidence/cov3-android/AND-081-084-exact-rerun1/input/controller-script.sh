#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/AND-081-084-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-runner-hierarchy-stale-group.sh"
cp "$script_path" "$base/input/controller-script.sh"
cd "$P"

printf '# cwd=%s\n' "$PWD" > "$base/commands.txt"
if [ -e .grantiva/session.json ]; then
  echo 'precondition failed: an existing project session must be reviewed, not adopted' | tee "$base/precondition-error.txt" >&2
  exit 3
fi
adb -s emulator-5554 shell am force-stop com.kylebrowning.landmarks > "$base/pre-force-stop.out" 2> "$base/pre-force-stop.err"
adb forward --list > "$base/forwards-before.txt"
ps -axo pid,ppid,etime,command | grep -E '[g]rantiva-runner|[a]pp_process.*uiautomator' > "$base/processes-before.txt" || true

printf '$ %s runner start --device emulator-5554 --detach --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner start --device emulator-5554 --detach --json > "$base/start.json" 2> "$base/start.err"
start_rc=$?
printf 'start-rc=%s\n' "$start_rc" >> "$base/commands.txt"
if [ "$start_rc" -ne 0 ] || [ ! -f .grantiva/session.json ]; then
  echo 'initial runner start did not create the expected owned session' | tee "$base/start-guard-error.txt" >&2
  exit 4
fi
cp .grantiva/session.json "$base/session-after-start.json"
runner_pid=$(python3 -I -c 'import json; print(json.load(open(".grantiva/session.json"))["pid"])')
if ! python3 -I -c 'import json,sys; d=json.load(open(".grantiva/session.json")); sys.exit(0 if d.get("platform")=="android" and d.get("serial")=="emulator-5554" and isinstance(d.get("pid"),int) else 1)'; then
  echo 'initial session identity does not match the explicitly requested Android serial' | tee "$base/start-identity-error.txt" >&2
  "$GRANTIVA" runner stop --json > "$base/start-identity-cleanup.json" 2> "$base/start-identity-cleanup.err"
  exit 9
fi

# The detached session's generated flow launches the configured application asynchronously.
# Poll the tree, preserving every observation, until the application hierarchy is visible.
ready=0
for attempt in 0 1 2 3 4 5 6 7 8 9 10; do
  printf '$ %s runner dump-hierarchy --format tree # attempt=%s\n' "$GRANTIVA" "$attempt" >> "$base/commands.txt"
  "$GRANTIVA" runner dump-hierarchy --format tree > "$base/tree-poll-$attempt.out" 2> "$base/tree-poll-$attempt.err"
  poll_rc=$?
  printf 'tree-poll-%s-rc=%s\n' "$attempt" "$poll_rc" >> "$base/commands.txt"
  if [ "$poll_rc" -eq 0 ] && grep -q 'Landmarks' "$base/tree-poll-$attempt.out"; then ready=1; break; fi
  sleep 1
done

printf '$ %s runner dump-hierarchy --format tree\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner dump-hierarchy --format tree > "$base/tree.out" 2> "$base/tree.err"; tree_rc=$?
printf '$ %s runner dump-hierarchy --format json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner dump-hierarchy --format json > "$base/hierarchy.json" 2> "$base/json.err"; json_rc=$?
printf '$ %s runner dump-hierarchy --format xml\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner dump-hierarchy --format xml > "$base/hierarchy.xml" 2> "$base/xml.err"; xml_rc=$?
printf 'tree-rc=%s json-rc=%s xml-rc=%s app-ready=%s\n' "$tree_rc" "$json_rc" "$xml_rc" "$ready" >> "$base/commands.txt"
adb forward --list > "$base/forwards-during.txt"
ps -axo pid,ppid,etime,command | grep -E '[g]rantiva-runner|[a]pp_process.*uiautomator' > "$base/processes-during.txt" || true

printf '$ %s runner stop --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner stop --json > "$base/stop.json" 2> "$base/stop.err"; stop_rc=$?
printf 'stop-rc=%s\n' "$stop_rc" >> "$base/commands.txt"
adb forward --list > "$base/forwards-after-stop.txt"
ps -axo pid,ppid,etime,command | grep -E '[g]rantiva-runner|[a]pp_process.*uiautomator' > "$base/processes-after-stop.txt" || true
if kill -0 "$runner_pid" 2>/dev/null; then echo "runner pid unexpectedly alive: $runner_pid" > "$base/runner-pid-after-stop.txt"; pid_dead=0; else echo "runner pid dead: $runner_pid" > "$base/runner-pid-after-stop.txt"; pid_dead=1; fi
if [ "$stop_rc" -ne 0 ] || [ "$pid_dead" -ne 1 ] || [ -e .grantiva/session.json ]; then
  echo 'first owned session did not stop cleanly; refusing subsequent lifecycle cases' | tee "$base/first-stop-guard-error.txt" >&2
  exit 5
fi

# Explicit start flags must override the project's configured application/emulator values.
printf '$ %s runner start --application-id x.y --emulator cov3-android --detach --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner start --application-id x.y --emulator cov3-android --detach --json > "$base/override-start.json" 2> "$base/override-start.err"; override_rc=$?
if [ "$override_rc" -ne 0 ] || [ ! -f .grantiva/session.json ]; then
  echo 'override start did not create the expected owned session' | tee "$base/override-start-guard-error.txt" >&2
  exit 6
fi
cp .grantiva/session.json "$base/session-after-override.json"
if ! python3 -I -c 'import json,sys; d=json.load(open(".grantiva/session.json")); sys.exit(0 if d.get("platform")=="android" and d.get("serial")=="emulator-5554" and d.get("applicationId")=="x.y" and isinstance(d.get("pid"),int) else 1)'; then
  echo 'override session identity does not contain the requested application ID and Android serial' | tee "$base/override-identity-error.txt" >&2
  "$GRANTIVA" runner stop --json > "$base/override-identity-cleanup.json" 2> "$base/override-identity-cleanup.err"
  exit 10
fi
printf '$ %s runner stop --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner stop --json > "$base/override-stop.json" 2> "$base/override-stop.err"; override_stop_rc=$?
printf 'override-start-rc=%s override-stop-rc=%s\n' "$override_rc" "$override_stop_rc" >> "$base/commands.txt"
if [ "$override_stop_rc" -ne 0 ] || [ -e .grantiva/session.json ]; then
  echo 'override session did not stop cleanly; refusing stale-record case' | tee "$base/override-stop-guard-error.txt" >&2
  exit 7
fi

# Restore the first session record only after its owner PID is proven dead.
mkdir -p .grantiva
cp "$base/session-after-start.json" .grantiva/session.json
cp .grantiva/session.json "$base/stale-session-restored.json"
printf '$ %s runner start --device emulator-5554 --detach --json # stale dead-pid session present\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner start --device emulator-5554 --detach --json > "$base/stale-start.json" 2> "$base/stale-start.err"; stale_rc=$?
if [ "$stale_rc" -ne 0 ] || [ ! -f .grantiva/session.json ]; then
  echo 'stale-record start did not create the expected owned session' | tee "$base/stale-start-guard-error.txt" >&2
  exit 8
fi
cp .grantiva/session.json "$base/session-after-stale-start.json"
if ! python3 -I -c 'import json,sys; old=json.load(open("'$base'/stale-session-restored.json")); new=json.load(open(".grantiva/session.json")); sys.exit(0 if new.get("platform")=="android" and new.get("serial")=="emulator-5554" and isinstance(new.get("pid"),int) and new["pid"] != old.get("pid") else 1)'; then
  echo 'fresh session did not replace the restored dead-PID record with the requested Android identity' | tee "$base/stale-identity-error.txt" >&2
  "$GRANTIVA" runner stop --json > "$base/stale-identity-cleanup.json" 2> "$base/stale-identity-cleanup.err"
  exit 11
fi
printf '$ %s runner stop --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner stop --json > "$base/stale-stop.json" 2> "$base/stale-stop.err"; stale_stop_rc=$?
printf 'stale-start-rc=%s stale-stop-rc=%s\n' "$stale_rc" "$stale_stop_rc" >> "$base/commands.txt"
adb forward --list > "$base/forwards-final.txt"

failures=0
[ "$start_rc" -eq 0 ] || failures=$((failures + 1))
[ "$ready" -eq 1 ] || failures=$((failures + 1))
[ "$tree_rc" -eq 0 ] || failures=$((failures + 1))
[ "$json_rc" -eq 0 ] || failures=$((failures + 1))
[ "$xml_rc" -eq 0 ] || failures=$((failures + 1))
[ "$stop_rc" -eq 0 ] || failures=$((failures + 1))
[ "$pid_dead" -eq 1 ] || failures=$((failures + 1))
[ "$override_rc" -eq 0 ] || failures=$((failures + 1))
[ "$override_stop_rc" -eq 0 ] || failures=$((failures + 1))
[ "$stale_rc" -eq 0 ] || failures=$((failures + 1))
[ "$stale_stop_rc" -eq 0 ] || failures=$((failures + 1))
[ ! -e .grantiva/session.json ] || failures=$((failures + 1))
printf 'aggregate-failures=%s\n' "$failures" >> "$base/commands.txt"
exit "$failures"
