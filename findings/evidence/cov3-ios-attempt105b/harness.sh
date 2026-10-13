#!/bin/zsh
set -u
setopt NO_BG_NICE
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt105b";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt105b;U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py";P=0;OWNER='';CONFIG="$A/grantiva.yml"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$ROOT/requests.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},{"method":"tools/list","params":{}}]
JSON
jq -e 'length==3' "$ROOT/requests.json" >/dev/null||exit 72
cleanup(){ [[ -f "$ROOT/config-original.yml" ]]&&cp "$ROOT/config-original.yml" "$CONFIG";[[ -n "$OWNER" && -f "$ROOT/owner-original.json" ]]&&cp "$ROOT/owner-original.json" "$OWNER";if ((P>1))&&kill -0 $P 2>/dev/null;then kill -INT $P 2>/dev/null;wait $P 2>/dev/null;fi;};trap cleanup EXIT
python3 - "$U1" <<'PY'||exit 74
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except:continue
 assert str(d.get('udid'))!=sys.argv[1],(p,d)
PY
cp "$CONFIG" "$ROOT/config-original.yml";{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
(cd "$A"&&exec "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --keep-alive --ready-file "$ROOT/ready.json" >"$ROOT/run.out" 2>"$ROOT/run.err")&P=$!;echo $P >"$ROOT/run.pid"
for n in {1..600};do [[ -f "$ROOT/ready.json" ]]&&[[ $(jq -r .status "$ROOT/ready.json" 2>/dev/null) == passed ]]&&break;kill -0 $P 2>/dev/null||exit 75;sleep .1;done
[[ -f "$ROOT/ready.json" && $(jq -r .status "$ROOT/ready.json" 2>/dev/null) == passed ]]||exit 80
OWNER=$(find /tmp/grantiva-sessions -maxdepth 1 -name '*.owner.json' -type f -print0|xargs -0 rg -l '"grantivaPid"[[:space:]]*:[[:space:]]*'$P 2>/dev/null|head -1);[[ -n "$OWNER" ]]||exit 76;cp "$OWNER" "$ROOT/owner-original.json"
python3 -I "$CLIENT" "$ROOT/requests.json" "$ROOT/current" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios||exit 77
python3 - "$OWNER" "$ROOT/owner-legacy.json" <<'PY'||exit 78
import json,os,sys
d=json.load(open(sys.argv[1]));d.pop('appId',None);json.dump(d,open(sys.argv[2],'w'),indent=2);tmp=sys.argv[1]+'.rowtmp';json.dump(d,open(tmp,'w'));os.replace(tmp,sys.argv[1])
PY
mv "$CONFIG" "$ROOT/config-hidden.yml"
python3 -I "$CLIENT" "$ROOT/requests.json" "$ROOT/legacy" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios||exit 79
mv "$ROOT/config-hidden.yml" "$CONFIG";cp "$ROOT/owner-original.json" "$OWNER"
kill -INT $P;wait $P;echo $? >"$ROOT/run.exit";P=0
find /tmp/grantiva-sessions -maxdepth 1 -name "$(jq -r .runnerPid "$ROOT/owner-original.json")*" -print >"$ROOT/sidecars-after.txt";OWNER=''
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
