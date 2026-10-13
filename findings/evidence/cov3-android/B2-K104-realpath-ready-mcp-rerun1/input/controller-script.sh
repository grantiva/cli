#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K104-realpath-ready-mcp-rerun1"
tmp_alias=/tmp/cov3-android-k104-ready-r3
private_project=/private/tmp/cov3-android-k104-ready-r3
if [ -e "$base" ] || [ -e "$tmp_alias" ] || [ -e "$private_project" ]; then echo refusing-existing-path >&2; exit 2; fi
mkdir -p "$base/input" "$tmp_alias/.maestro"
touch "$base/owned-temp-marker"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k104-realpath-ready-mcp-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/B2-K56-X011-MCP076-context-resources-rerun4/input/client.py" "$base/input/mcp-client.py"
cp "$P/grantiva-android.yml" "$tmp_alias/grantiva-android.yml"
cp "$P/.maestro/01-browse.yaml" "$tmp_alias/.maestro/01-browse.yaml"
cp -R "$tmp_alias/." "$base/input/project/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup() { (cd "$private_project" 2>/dev/null && "$GRANTIVA" runner stop --json) > "$base/trap-stop.out" 2> "$base/trap-stop.err" || true; [ -f "$base/owned-temp-marker" ] && rm -rf "$private_project"; }
trap cleanup EXIT INT TERM
printf '# cwd=%s\n$ %q runner start --platform android --device %q --detach --json\n' "$tmp_alias" "$GRANTIVA" "$serial" > "$base/command.txt"
(cd "$tmp_alias" && "$GRANTIVA" runner start --platform android --device "$serial" --detach --json) > "$base/start.json" 2> "$base/start.err"; src=$?
tree_ok=0
for attempt in $(seq 1 60); do
  (cd "$private_project" && "$GRANTIVA" hierarchy --udid "$serial" --format json) > "$base/hierarchy.json" 2> "$base/hierarchy.err"; hrc=$?
  if [ "$hrc" -eq 0 ]; then tree_ok=1; break; fi
  sleep .5
done
owner=''
for candidate in /tmp/grantiva-sessions/*.owner.json /private/tmp/grantiva-sessions/*.owner.json; do
  [ -f "$candidate" ] || continue
  if [ "$(jq -r '.detached // false' "$candidate")" = true ] && [ "$(jq -r '.udid // empty' "$candidate")" = "$serial" ] && [ "$(jq -r '.projectDirectory // empty' "$candidate")" = "$private_project" ]; then owner="$candidate"; break; fi
done
[ -n "$owner" ] && cp "$owner" "$base/owner.json"
cat > "$base/requests.json" <<'JSON'
[{"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cov3-k104-ready","version":"1"}}},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"}]
JSON
python3 -I "$base/input/mcp-client.py" "$base/requests.json" "$base/mcp" "$private_project" -- "$GRANTIVA" mcp --project-dir "$tmp_alias"
(cd "$private_project" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err"; stc=$?
python3 -I - "$base" "$src" "$tree_ok" "$stc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); owner=json.loads((b/'owner.json').read_text()) if (b/'owner.json').exists() else {}; tree=json.loads((b/'mcp/tree.json').read_text())
checks={'start0':int(sys.argv[2])==0,'hierarchyReady':int(sys.argv[3])==1,'ownerPrivateRealpath':owner.get('projectDirectory')=='/private/tmp/cov3-android-k104-ready-r3','ownerDetached':owner.get('detached') is True,'mcpReadyAcrossSpellings':tree.get('result',{}).get('isError') is not True and 'children' in json.dumps(tree),'stop0':int(sys.argv[4])==0}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?; cleanup; trap - EXIT INT TERM; exit "$rc"
