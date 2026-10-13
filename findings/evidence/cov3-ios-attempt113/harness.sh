#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt113";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt113-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh"
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
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_u1=$U1; } >"$ROOT/commands.txt"
(cd "$A"&&"$GRANTIVA" diff capture --no-build --simulator "$U1" --json >"$ROOT/capture.out" 2>"$ROOT/capture.err");echo $? >"$ROOT/capture.exit"
(cd "$A"&&"$GRANTIVA" diff compare >"$ROOT/no-baseline-text.out" 2>"$ROOT/no-baseline-text.err");echo $? >"$ROOT/no-baseline-text.exit"
(cd "$A"&&"$GRANTIVA" diff compare --json >"$ROOT/no-baseline-json.out" 2>"$ROOT/no-baseline-json.err");echo $? >"$ROOT/no-baseline-json.exit"
(cd "$A"&&"$GRANTIVA" diff approve Home --json >"$ROOT/approve-home.out" 2>"$ROOT/approve-home.err");echo $? >"$ROOT/approve-home.exit"
(cd "$A"&&"$GRANTIVA" diff compare >"$ROOT/mixed-text.out" 2>"$ROOT/mixed-text.err");echo $? >"$ROOT/mixed-text.exit"
(cd "$A"&&"$GRANTIVA" diff compare --json >"$ROOT/mixed-json.out" 2>"$ROOT/mixed-json.err");echo $? >"$ROOT/mixed-json.exit"
mkdir "$ROOT/captures" "$ROOT/baselines";cp -p "$A"/.grantiva/captures/*.png "$ROOT/captures/";cp -p "$A"/.grantiva/baselines/*.png "$ROOT/baselines/"
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);assert int((r/'capture.exit').read_text())==0 and int((r/'approve-home.exit').read_text())==0
assert all(int((r/p).read_text())!=0 for p in ('no-baseline-text.exit','no-baseline-json.exit','mixed-text.exit','mixed-json.exit'))
for p in ('no-baseline-json.out','mixed-json.out'):
 d=json.load(open(r/p));assert d['passed'] is False and len(d['screens'])==5
assert len(list((r/'captures').glob('*.png')))==5 and len(list((r/'baselines').glob('*.png')))==1
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
