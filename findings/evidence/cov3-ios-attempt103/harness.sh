#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt103";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;BASE=/private/tmp/cov3-ios-attempt103;A="$BASE/a";B="$BASE/b";U1=563907E1-703D-4322-AE5F-FC3B06D03143;C="$WT/findings/evidence/cov3-ios/attempt103-client.py"
[[ ! -e "$ROOT" && ! -e "$BASE" ]]||exit 73;mkdir -p "$ROOT" "$A" "$B";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";cp "$C" "$ROOT/client.py"
python3 - "$U1" <<'PY'||exit 74
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except:continue
 assert str(d.get('udid'))!=sys.argv[1],(p,d)
PY
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup.out" 2>"$ROOT/cleanup.err")||true;};trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$C";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
python3 -I "$C" "$ROOT" "$A" "$B" "$GRANTIVA" "$U1">"$ROOT/client.out" 2>"$ROOT/client.err";RC=$?;echo $RC >"$ROOT/client.exit"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print >"$ROOT/global-after.txt" 2>"$ROOT/global-after.err"||true
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256";exit $RC
