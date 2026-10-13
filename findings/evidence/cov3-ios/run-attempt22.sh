#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt22"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SCRATCH="$BASE/attempt22-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt16-client.py"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt22'; exit 73; fi
mkdir -p "$ROOT" "$SCRATCH"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: "Favorites"
  - name: Deep Links
    path:
      - tap: "Deep Links"
YAML
cat > "$ROOT/requests.json" <<'JSON'
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home"]}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}}},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "owned_device_config_name=cov3-ios-26"; echo "scratch=$SCRATCH"
 echo "command=python3 -I $ROOT/client.py $ROOT/requests.json $ROOT/mcp $SCRATCH -- $GRANTIVA mcp --project-dir $SCRATCH --platform ios"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$SCRATCH" -- "$GRANTIVA" mcp --project-dir "$SCRATCH" --platform ios > "$ROOT/client.out" 2> "$ROOT/client.err"
rc=$?
mkdir -p "$ROOT/preserved-project-grantiva"; cp -pR "$SCRATCH/.grantiva/." "$ROOT/preserved-project-grantiva/" 2>/dev/null || true
print -r -- "client_exit=$rc" >> "$ROOT/commands.txt"; exit $rc
