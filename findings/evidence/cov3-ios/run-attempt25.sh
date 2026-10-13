#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt25"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
A="$BASE/attempt25-project-a"; B="$BASE/attempt25-project-b"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt16-client.py"
if [[ -e "$ROOT" || -e "$A" || -e "$B" ]]; then print -u2 'refusing overwrite attempt25'; exit 73; fi
mkdir -p "$ROOT" "$A" "$B"
cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"
for d in "$A" "$B"; do
cat > "$d/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
YAML
done
cat > "$ROOT/a-requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..16}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/a-readiness-\$n.json 2> $ROOT/a-readiness-\$n.err && grep -q 'Landmarks' $ROOT/a-readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"a-context-full.json"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Deep Links"},{"tap":"Edit Landmark"},{"tap":"Name"}]}},"_save":"a-focus-full.json"},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"Yosemite"}},"_save":"a-type-full.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"a-tree-after-type-full.json"}
]
JSON
cat > "$ROOT/b-requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"b-tree.json"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"b-context.json"},
 {"_shell":"$GRANTIVA hierarchy --udid $U1 --format json > $ROOT/a-still-live.json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "project_a=$A"; echo "project_b=$B"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/a-requests.json" "$ROOT/mcp-a" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios > "$ROOT/a-client.out" 2> "$ROOT/a-client.err"; a_rc=$?
python3 -I "$ROOT/client.py" "$ROOT/b-requests.json" "$ROOT/mcp-b" "$B" -- "$GRANTIVA" mcp --project-dir "$B" --platform ios > "$ROOT/b-client.out" 2> "$ROOT/b-client.err"; b_rc=$?
(cd "$A" && "$GRANTIVA" runner stop --json > "$ROOT/stop.out" 2> "$ROOT/stop.err"); stop_rc=$?
{
 echo "a_client_exit=$a_rc"; echo "b_client_exit=$b_rc"; echo "stop_exit=$stop_rc"; echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( a_rc == 0 && b_rc == 0 && stop_rc == 0 ))
