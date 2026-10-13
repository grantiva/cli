#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt107";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt107-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py";rsync -a --exclude .grantiva "$SRC/" "$A/"
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
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >>"$ROOT/cleanup-stop.out" 2>>"$ROOT/cleanup-stop.err")||true; };trap cleanup EXIT
xcrun simctl list devices -j >"$ROOT/before.json";python3 - "$ROOT/before.json" "$U1" <<'PY'||exit 74
import json,sys
d=json.load(open(sys.argv[1]));xs=[x for a in d['devices'].values() for x in a if x.get('udid')==sys.argv[2]];assert len(xs)==1 and xs[0]['name']=='cov3-ios-26' and xs[0]['state']=='Booted'
PY
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1; } >"$ROOT/commands.txt"
for i in 1 2 3;do
 d="$ROOT/cycle-$i";mkdir -p "$d"
 cat >"$d/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..20}; do $GRANTIVA hierarchy --udid $U1 --format json > $d/readiness-\$n.json 2> $d/readiness-\$n.err && rg -q Landmarks $d/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"vrt.json"},
 {"method":"tools/list","params":{}}
]
JSON
 python3 -I "$ROOT/client.py" "$d/requests.json" "$d/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios;echo $? >"$d/mcp.exit"
 (cd "$A"&&"$GRANTIVA" runner stop --json >"$d/stop.out" 2>"$d/stop.err");echo $? >"$d/stop.exit"
 (cd "$A"&&"$GRANTIVA" diff capture --no-build --json >"$d/cli-capture.out" 2>"$d/cli-capture.err");echo $? >"$d/cli-capture.exit"
 mkdir "$d/images";cp -p "$A"/.grantiva/captures/*.png "$d/images/"
done
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
for i in range(1,4):
 d=r/f'cycle-{i}'
 assert all(int((d/p).read_text())==0 for p in ('mcp.exit','stop.exit','cli-capture.exit'))
 m=json.load(open(d/'mcp'/'vrt.json'));text=m['result']['content'][0]['text'];assert all(x in text for x in ('Home','Favorites','Deep Links','Lakes','Detail'))
 c=json.load(open(d/'cli-capture.out'));assert len(c.get('screens',[]))==5 and all(all(y.get('status')=='passed' for y in x.get('steps',[])) for x in c['screens'])
 assert len(list((d/'images').glob('*.png')))==5
PY
xcrun simctl list devices -j >"$ROOT/after.json";echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
