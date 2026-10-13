#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt109b";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt109b-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143;U2=1B1102EC-224B-4EF7-937E-370A0DC317DA;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py";rsync -a --exclude .grantiva "$SRC/" "$A/"
cat >"$A/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-27
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
cat >"$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..20}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && rg -q Landmarks $ROOT/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"vrt.json"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
 {"method":"tools/list","params":{}}
]
JSON
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >>"$ROOT/cleanup-stop.out" 2>>"$ROOT/cleanup-stop.err")||true; };trap cleanup EXIT
xcrun simctl list devices -j >"$ROOT/before.json";{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1;echo configured_other_owned_u2=$U2; } >"$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios;echo $? >"$ROOT/mcp.exit"
mkdir "$ROOT/mcp-images";cp -p "$A"/.grantiva/captures/*.png "$ROOT/mcp-images/";mkdir -p "$A/.grantiva/baselines";cp -p "$ROOT/mcp-images"/*.png "$A/.grantiva/baselines/"
for mode in plain quiet verbose;do
 args=();[[ $mode == quiet ]]&&args+=(--quiet);[[ $mode == verbose ]]&&args+=(--verbose)
 (cd "$A"&&"$GRANTIVA" diff capture --no-build --json "${args[@]}" >"$ROOT/$mode.out" 2>"$ROOT/$mode.err");echo $? >"$ROOT/$mode.exit"
 mkdir "$ROOT/$mode-images";cp -p "$A"/.grantiva/captures/*.png "$ROOT/$mode-images/"
done
(cd "$A"&&"$GRANTIVA" diff compare --json >"$ROOT/compare.out" 2>"$ROOT/compare.err");echo $? >"$ROOT/compare.exit"
shasum -a 256 "$ROOT"/{plain,quiet,verbose}.out >"$ROOT/stdout.sha256";cmp -s "$ROOT/plain.out" "$ROOT/quiet.out";echo $? >"$ROOT/plain-quiet.cmp";cmp -s "$ROOT/plain.out" "$ROOT/verbose.out";echo $? >"$ROOT/plain-verbose.cmp"
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);assert int((r/'mcp.exit').read_text())==0
for mode in ('plain','quiet','verbose'):
 assert int((r/f'{mode}.exit').read_text())==0 and len(json.load(open(r/f'{mode}.out'))['screens'])==5 and len(list((r/f'{mode}-images').glob('*.png')))==5
assert len(list((r/'mcp-images').glob('*.png')))==5
PY
xcrun simctl list devices -j >"$ROOT/after.json";echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
