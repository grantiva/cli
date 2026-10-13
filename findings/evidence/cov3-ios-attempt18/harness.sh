#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt18"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"; SCRATCH="$BASE/attempt18-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt16-client.py"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt18'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"
rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Sub Flow
    path:
      - run_flow: ".maestro/coverage/14-runflow-sub.yaml"
YAML
cat > "$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in 1 2 3 4 5 6 7 8; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Deep Links"},{"tap":"Edit Landmark"},{"tap":"Name"},{"type":" ScriptYosemite"}]}}},
 {"_shell":"xcrun simctl terminate $U1 com.kylebrowning.Landmarks; xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Deep Links"},{"tap":"Edit Landmark"},{"tap":"Name"}]}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":" DirectYosemite"}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}},
 {"_shell":"$GRANTIVA runner stop --json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
 echo "command=python3 -I $ROOT/client.py $ROOT/requests.json $ROOT/mcp $SCRATCH -- $GRANTIVA mcp --project-dir $SCRATCH --platform ios"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$SCRATCH" -- "$GRANTIVA" mcp --project-dir "$SCRATCH" --platform ios > "$ROOT/client.out" 2> "$ROOT/client.err"
rc=$?; print -r -- "client_exit=$rc" >> "$ROOT/commands.txt"; exit $rc
