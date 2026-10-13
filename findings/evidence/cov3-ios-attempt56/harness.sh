#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt56"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt56-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt56'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Favorites
    path: [{tap: "Favorites"}]
  - name: Deep Links
    path: [{tap: "Deep Links"}]
  - name: Lakes
    path: [{tap: "Landmarks"}, {tap: "Lakes"}]
  - name: Detail
    path: [{tap: "Landmarks"}, {tap: "Golden Gate Bridge"}, {assert_visible: "Plan Visit"}]
YAML
cat > "$ROOT/live-requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..12}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && rg -q Landmarks $ROOT/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"mcp-capture.json"},
 {"_shell":"$GRANTIVA diff capture --no-build --json > $ROOT/bare-capture.out 2> $ROOT/bare-capture.err"},
 {"_shell":"$GRANTIVA runner dump-hierarchy --json > $ROOT/post-capture-hierarchy.json 2> $ROOT/post-capture-hierarchy.err"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"post-context.json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo "owned_device_udid=$U1"
 echo 'bare diff capture safety: frozen config maps simulator cov3-ios-26 to owned U1; live session was explicitly started on U1 and is proven ready first.'
} > "$ROOT/commands.txt"
xcrun simctl list devices --json > "$ROOT/simulators-before.json"
python3 -I "$ROOT/client.py" "$ROOT/live-requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios; c=$?
mkdir -p "$ROOT/preserved-captures"; cp -p "$A"/.grantiva/captures/*.png "$ROOT/preserved-captures/" 2> "$ROOT/preserve.err"; p=$?
(cd "$A" && "$GRANTIVA" runner stop --json > "$ROOT/stop.out" 2> "$ROOT/stop.err"); s=$?
print -r -- "client=$c preserve=$p stop=$s finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( c == 0 && p == 0 && s == 0 ))
