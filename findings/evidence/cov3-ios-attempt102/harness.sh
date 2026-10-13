#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt102";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt102;U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$ROOT/context.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},{"method":"tools/list","params":{}}]
python3 - "$U1" <<'PY'||exit 74
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except:continue
 assert str(d.get('udid'))!=sys.argv[1],(p,d)
PY
OWNER='';cleanup(){ [[ -n "$OWNER" && -f "$ROOT/owner-original.json" ]]&&cp "$ROOT/owner-original.json" "$OWNER";(cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err")||true;};trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
cd "$A";"$GRANTIVA" runner start --detach --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios >"$ROOT/start.json" 2>"$ROOT/start.err"||exit 75
R=$(jq -r .pid "$ROOT/start.json");for n in {1..100};do [[ -f /tmp/grantiva-sessions/$R.owner.json ]]&&OWNER=/tmp/grantiva-sessions/$R.owner.json&&break;sleep .1;done;[[ -n "$OWNER" ]]||exit 76;cp "$OWNER" "$ROOT/owner-original.json"
READY=0;for n in {1..40};do "$GRANTIVA" hierarchy --udid "$U1" --format json >"$ROOT/ready-$n.json" 2>"$ROOT/ready-$n.err";e=$?;echo $e >"$ROOT/ready-$n.exit";if ((e==0))&&rg -q Landmarks "$ROOT/ready-$n.json";then READY=1;break;fi;sleep .5;done;((READY==1))||exit 77
SECONDS=0;"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml >"$ROOT/owned-run.out" 2>"$ROOT/owned-run.err";echo $? >"$ROOT/owned-run.exit";echo $SECONDS >"$ROOT/owned-run.seconds"
python3 -I "$CLIENT" "$ROOT/context.json" "$ROOT/current-context" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios||exit 78
python3 - "$OWNER" "$ROOT/owner-legacy.json" <<'PY'||exit 79
import json,os,sys,tempfile
d=json.load(open(sys.argv[1]));d.pop('appId',None);json.dump(d,open(sys.argv[2],'w'),indent=2);tmp=sys.argv[1]+'.rowtmp';json.dump(d,open(tmp,'w'));os.replace(tmp,sys.argv[1])
PY
python3 -I "$CLIENT" "$ROOT/context.json" "$ROOT/legacy-context" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios||exit 80
cp "$ROOT/owner-original.json" "$OWNER"
"$GRANTIVA" runner stop --json >"$ROOT/stop.json" 2>"$ROOT/stop.err"||exit 81
find /tmp/grantiva-sessions -maxdepth 1 -name "$R*" -print >"$ROOT/sidecars-after.txt"
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
