#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt24"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SCRATCH="$BASE/attempt24-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt16-client.py"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt24'; exit 73; fi
if [[ -e /tmp/pwn ]]; then print -u2 'refusing: /tmp/pwn pre-exists'; exit 74; fi
mkdir -p "$ROOT" "$SCRATCH/.grantiva"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"
cp -pR "$WT/findings/evidence/cov3-ios-attempt22/preserved-project-grantiva/." "$SCRATCH/.grantiva/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
YAML
cat > "$SCRATCH/grantiva-android.yml" <<'YAML'
emulator: cov3-unused-android-config
application_id: com.kylebrowning.landmarks
YAML
cat > "$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home; touch /tmp/pwn"]}}},
 {"_shell":"test ! -e /tmp/pwn"},
 {"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_ensure","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_no_such_tool","arguments":{}}},
 {"method":"tools/list","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in 1 2 3 4 5 6 7 8 9 10 11 12; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Deep Links"},{"tap":"Edit Landmark"},{"tap":"Name"}]}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"Yosemite"}}},
 {"_shell":"$GRANTIVA runner stop --json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"; echo "preflight_tmp_pwn=absent"
 echo "command=python3 -I $ROOT/client.py $ROOT/requests.json $ROOT/mcp $SCRATCH -- $GRANTIVA mcp --project-dir $SCRATCH --platform ios"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$SCRATCH" -- "$GRANTIVA" mcp --project-dir "$SCRATCH" --platform ios > "$ROOT/client.out" 2> "$ROOT/client.err"
rc=$?; print -r -- "client_exit=$rc" >> "$ROOT/commands.txt"; print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit $rc
