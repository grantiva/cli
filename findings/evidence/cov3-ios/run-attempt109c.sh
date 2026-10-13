#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt109c";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt109c-ios";MCP="$WT/findings/evidence/cov3-ios-attempt109b/mcp-images";U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" && -d "$MCP" ]]||exit 73;[[ $(find "$MCP" -type f -name '*.png'|wc -l|tr -d ' ') == 5 ]]||exit 74;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh"
cat >"$A/grantiva.yml" <<'YAML'
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
mkdir -p "$A/.grantiva/baselines";cp -p "$MCP"/*.png "$A/.grantiva/baselines/";mkdir "$ROOT/mcp-baselines";cp -p "$MCP"/*.png "$ROOT/mcp-baselines/"
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_u1=$U1;echo source_mcp_attempt109b=live_session_u1; } >"$ROOT/commands.txt"
(cd "$A"&&"$GRANTIVA" diff capture --no-build --simulator "$U1" --json >"$ROOT/cli-capture.out" 2>"$ROOT/cli-capture.err");echo $? >"$ROOT/cli-capture.exit"
mkdir "$ROOT/cli-images";cp -p "$A"/.grantiva/captures/*.png "$ROOT/cli-images/"
(cd "$A"&&"$GRANTIVA" diff compare --json >"$ROOT/compare.out" 2>"$ROOT/compare.err");echo $? >"$ROOT/compare.exit"
python3 - "$ROOT" "$U1" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2];c=json.load(open(r/'cli-capture.out'));v=json.load(open(r/'compare.out'))
assert int((r/'cli-capture.exit').read_text())==0 and len(c['screens'])==5 and c['simulator']['udid']==u
assert len(list((r/'mcp-baselines').glob('*.png')))==5 and len(list((r/'cli-images').glob('*.png')))==5
assert len(v['screens'])==5
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
