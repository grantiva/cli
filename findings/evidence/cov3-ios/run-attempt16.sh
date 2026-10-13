#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt16"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"; SCRATCH="$BASE/attempt16-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt11-client.py"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt16'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"
cat > "$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Landmarks"}}},
 {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}}},
 {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"}]}}},
 {"_shell":"$GRANTIVA runner start --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in 1 2 3 4 5 6 7 8; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-first.json 2> $ROOT/readiness-first.err && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"},{"type":"x"}]}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1},5]}}},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Gesture Lab"},{"wait":1},{"tap_xy":{"x":201,"y":495}},{"swipe":"up"}]}}},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such Element"}}},
 {"_shell":"xcrun simctl terminate $U1 com.kylebrowning.Landmarks"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Landmarks"}}},
 {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}}},
 {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"}]}}},
 {"_shell":"$GRANTIVA runner stop --json"},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in 1 2 3 4 5 6 7 8; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-second.json 2> $ROOT/readiness-second.err && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}},
 {"_shell":"$GRANTIVA runner stop --json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
 echo "command=python3 -I $ROOT/client.py $ROOT/requests.json $ROOT/mcp $SCRATCH -- $GRANTIVA mcp --project-dir $SCRATCH --platform ios"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$SCRATCH" -- "$GRANTIVA" mcp --project-dir "$SCRATCH" --platform ios > "$ROOT/client.out" 2> "$ROOT/client.err"
rc=$?; print -r -- "client_exit=$rc" >> "$ROOT/commands.txt"; exit $rc
