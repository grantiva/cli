#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K79-K104-D230-realpath-kill-rerun3"
tmp_alias=/tmp/cov3-android-k79-r3c-20261013
private_project=/private/tmp/cov3-android-k79-r3c-20261013
if [ -e "$base" ] || [ -e "$tmp_alias" ] || [ -e "$private_project" ]; then echo refusing-existing-path >&2; exit 2; fi
mkdir -p "$base/input" "$base/keepalive" "$base/detached" "$tmp_alias/.maestro/coverage"
touch "$base/owned-temp-marker"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k79-k104-d230-realpath-kill-v3.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/B2-K56-X011-MCP076-context-resources-rerun4/input/client.py" "$base/input/mcp-client.py"
cp "$P/grantiva-android.yml" "$tmp_alias/grantiva-android.yml"
cp "$P/.maestro/coverage/18-long-wait.yaml" "$tmp_alias/.maestro/coverage/18-long-wait.yaml"
cp "$P/.maestro/01-browse.yaml" "$tmp_alias/.maestro/01-browse.yaml"
cp -R "$tmp_alias/." "$base/input/project/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
rp=''
cleanup() {
  (cd "$private_project" 2>/dev/null && "$GRANTIVA" runner stop --json) > "$base/trap-stop.out" 2> "$base/trap-stop.err" || true
  if [ -n "$rp" ] && kill -0 "$rp" 2>/dev/null; then kill -INT "$rp" 2>/dev/null || true; wait "$rp" 2>/dev/null || true; fi
  if [ -f "$base/owned-temp-marker" ]; then rm -rf "$private_project"; fi
}
trap cleanup EXIT INT TERM
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml\n' "$tmp_alias" "$GRANTIVA" "$serial" > "$base/keepalive/command.txt"
(cd "$tmp_alias" && exec "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml) > "$base/keepalive/run.out" 2> "$base/keepalive/run.err" & rp=$!
seen=0; owner=''
for attempt in $(seq 1 120); do
  for candidate in /tmp/grantiva-sessions/*.owner.json /private/tmp/grantiva-sessions/*.owner.json; do
    [ -f "$candidate" ] || continue
    if [ "$(jq -r '.grantivaPid // 0' "$candidate")" = "$rp" ] && [ "$(jq -r '.udid // empty' "$candidate")" = "$serial" ]; then owner="$candidate"; fi
  done
  if [ -n "$owner" ] && grep -q '\[1/1\] 18-long-wait' "$base/keepalive/run.err" && grep -q launchApp "$base/keepalive/run.err"; then seen=1; break; fi
  kill -0 "$rp" 2>/dev/null || break; sleep .25
done
[ "$seen" -eq 1 ] || exit 5
cp "$owner" "$base/keepalive/owner-before-kill.json"
runner_pid="$(jq -r '.runnerPid' "$owner")"
[ "$(jq -r '.projectDirectory' "$owner")" = "$private_project" ] || exit 6
kill -0 "$runner_pid" 2>/dev/null || exit 7
cat > "$base/keepalive/mcp-requests.json" <<'JSON'
[{"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cov3-k104","version":"1"}}},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"}]
JSON
python3 -I "$base/input/mcp-client.py" "$base/keepalive/mcp-requests.json" "$base/keepalive/mcp-before" "$private_project" -- "$GRANTIVA" mcp --project-dir "$tmp_alias"
printf 'kill -9 %s\n' "$rp" > "$base/keepalive/kill-command.txt"
kill -9 "$rp"; wait "$rp" 2>/dev/null; printf '%s\n' "$?" > "$base/keepalive/parent-wait-exit.txt"; rp=''
runner_dead=0
for attempt in $(seq 1 40); do kill -0 "$runner_pid" 2>/dev/null || { runner_dead=1; break; }; sleep .25; done
printf '%s\n' "$runner_dead" > "$base/keepalive/runner-dead.txt"
ht0="$(python3 -I -c 'import time;print(time.monotonic())')"
(cd "$private_project" && "$GRANTIVA" hierarchy --udid "$serial" --format json) > "$base/keepalive/hierarchy-after.out" 2> "$base/keepalive/hierarchy-after.err"; hrc=$?
ht1="$(python3 -I -c 'import time;print(time.monotonic())')"
python3 -I -c "import sys;print(float(sys.argv[2])-float(sys.argv[1]))" "$ht0" "$ht1" > "$base/keepalive/hierarchy-after-elapsed.txt"
(cd "$private_project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json) > "$base/keepalive/dump-after.out" 2> "$base/keepalive/dump-after.err"; drc=$?
find /tmp/grantiva-sessions /private/tmp/grantiva-sessions -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort > "$base/keepalive/session-files-after.txt"
python3 -I "$base/input/mcp-client.py" "$base/keepalive/mcp-requests.json" "$base/keepalive/mcp-after" "$private_project" -- "$GRANTIVA" mcp --project-dir "$tmp_alias"
printf '# cwd=%s\n$ %q runner start --platform android --device %q --detach --json\n' "$tmp_alias" "$GRANTIVA" "$serial" > "$base/detached/command.txt"
(cd "$tmp_alias" && "$GRANTIVA" runner start --platform android --device "$serial" --detach --json) > "$base/detached/start.json" 2> "$base/detached/start.err"; src=$?
detached_owner=""
for attempt in $(seq 1 40); do
  for candidate in /tmp/grantiva-sessions/*.owner.json /private/tmp/grantiva-sessions/*.owner.json; do
    [ -f "$candidate" ] || continue
    if [ "$(jq -r '.detached // false' "$candidate")" = true ] && [ "$(jq -r '.udid // empty' "$candidate")" = "$serial" ] && [ "$(jq -r '.projectDirectory // empty' "$candidate")" = "$private_project" ]; then detached_owner="$candidate"; break; fi
  done
  [ -n "$detached_owner" ] && break; sleep .25
done
[ -n "$detached_owner" ] && cp "$detached_owner" "$base/detached/owner.json"
tree_ok=0
for attempt in $(seq 1 40); do
  (cd "$private_project" && "$GRANTIVA" hierarchy --udid "$serial" --format json) > "$base/detached/hierarchy.out" 2> "$base/detached/hierarchy.err"; x=$?
  if [ "$x" -eq 0 ]; then tree_ok=1; break; fi
  sleep .5
done
(cd "$private_project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json) > "$base/detached/dump.out" 2> "$base/detached/dump.err"; ddrc=$?
(cd "$private_project" && "$GRANTIVA" runner stop --json) > "$base/detached/stop.json" 2> "$base/detached/stop.err"; stc=$?
python3 -I - "$base" "$hrc" "$drc" "$src" "$tree_ok" "$ddrc" "$stc" "$runner_dead" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); owner=json.loads((b/'keepalive/owner-before-kill.json').read_text()); tree=json.loads((b/'keepalive/mcp-before/tree.json').read_text()); after=json.loads((b/'keepalive/mcp-after/tree.json').read_text()); detached=json.loads((b/'detached/owner.json').read_text()) if (b/'detached/owner.json').exists() else {}
checks={
 'ownerPrivateRealpath':owner.get('projectDirectory')=='/private/tmp/cov3-android-k79-r3c-20261013',
 'ownerNotDetached':owner.get('detached') is False,
 'mcpAttachedAcrossTmpSpelling':'isError' not in json.dumps(tree),
 'runnerDiedAfterParentKill':int(sys.argv[8])==1,
 'hierarchyAfterKillNonzero':int(sys.argv[2])!=0,
 'hierarchyAfterKillUnder1s':float((b/'keepalive/hierarchy-after-elapsed.txt').read_text())<=1.0,
 'mcpAfterKillNoSession':after.get('result',{}).get('isError') is True and 'No active runner session' in json.dumps(after),
 'dumpAfterKillNonzero':int(sys.argv[3])!=0,
 'detachedStart0':int(sys.argv[4])==0,
 'detachedOwnerShape':detached.get('detached') is True and detached.get('platform')=='android' and detached.get('udid')=='emulator-5554' and detached.get('projectDirectory')=='/private/tmp/cov3-android-k79-r3c-20261013',
 'detachedHierarchyWorks':int(sys.argv[5])==1,
 'detachedDumpWorks':int(sys.argv[6])==0,
 'detachedStop0':int(sys.argv[7])==0,
}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?
cleanup; trap - EXIT INT TERM
exit "$rc"
