#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt55b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt55b-a"; EMPTY="$BASE/attempt55b-empty"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
if [[ -e "$ROOT" || -e "$A" || -e "$EMPTY" ]]; then print -u2 'refusing overwrite attempt55b'; exit 73; fi
mkdir -p "$ROOT" "$EMPTY"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva-android.yml" <<'YAML'
module: app
variant: debug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
YAML
cat > "$ROOT/empty-requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{"simulator":"$U1"}},"_save":"build.json"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"vrt.json"},
 {"method":"tools/call","params":{"name":"grantiva_sim_list","arguments":{"filter":"booted"}},"_save":"list.json"},
 {"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"cov3-ios-26"}},"_save":"boot-owned.json"},
 {"method":"tools/list","params":{}}
]
JSON
cat > "$ROOT/ios-start.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..12}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && rg -q Landmarks $ROOT/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"ios-context.json"}
]
JSON
cat > "$ROOT/android-isolation.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"android-tree.json"},
 {"_shell":"$GRANTIVA hierarchy --udid $U1 --format json > $ROOT/ios-still-live.json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo "owned_device_udid=$U1"
 echo 'safety: build names owned U1 explicitly; sim_boot names cov3-ios-26 explicitly; VRT no-config fails during config resolution before target/device selection (VRTTools.capture -> diff capture).'
} > "$ROOT/commands.txt"
xcrun simctl list devices --json > "$ROOT/simulators-before.json"
python3 -I "$ROOT/client.py" "$ROOT/empty-requests.json" "$ROOT/mcp-empty" "$EMPTY" -- "$GRANTIVA" mcp --project-dir "$EMPTY" --platform ios; e=$?
xcrun simctl list devices --json > "$ROOT/simulators-after-empty.json"
python3 -I "$ROOT/client.py" "$ROOT/ios-start.json" "$ROOT/mcp-ios" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios; i=$?
python3 -I "$ROOT/client.py" "$ROOT/android-isolation.json" "$ROOT/mcp-android" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform android; a=$?
(cd "$A" && "$GRANTIVA" runner stop --json > "$ROOT/stop.out" 2> "$ROOT/stop.err"); st=$?
print -r -- "empty=$e ios=$i android=$a stop=$st finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( e == 0 && i == 0 && a == 0 && st == 0 ))
