#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt94"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt94-ios"
U1=563907E1-703D-4322-AE5F-FC3B06D03143;U2=1B1102EC-224B-4EF7-937E-370A0DC317DA
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh"
cat >"$A/home.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- assertVisible: "Landmarks"
- assertVisible: "Featured"
YAML
P1=0;P2=0
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err")||true;for p in $P1 $P2;do ((p>1))&&kill -0 $p 2>/dev/null&&kill -INT $p 2>/dev/null;done; }
trap cleanup EXIT
xcrun simctl list devices --json >"$ROOT/simulators-before.json"
python3 - "$U1" "$U2" <<'PY'||exit 72
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except Exception:continue
 assert str(d.get('udid')) not in sys.argv[1:],(p,d)
PY
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_devices=$U1,$U2; } >"$ROOT/commands.txt"
(cd "$A"&&"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --keep-alive --ready-file "$ROOT/u1.ready")>"$ROOT/u1.out" 2>"$ROOT/u1.err"&P1=$!;echo $P1 >"$ROOT/u1.pid"
for n in {1..600};do [[ -f "$ROOT/u1.ready" ]]&&[[ $(jq -r .status "$ROOT/u1.ready") == passed ]]&&break;sleep .1;done;[[ -f "$ROOT/u1.ready" ]]||exit 74
(cd "$A"&&"$GRANTIVA" run --no-build --simulator "$U2" --flow home.yaml --keep-alive --ready-file "$ROOT/u2.ready")>"$ROOT/u2.out" 2>"$ROOT/u2.err"&P2=$!;echo $P2 >"$ROOT/u2.pid"
for n in {1..600};do [[ -f "$ROOT/u2.ready" ]]&&[[ $(jq -r .status "$ROOT/u2.ready") == passed ]]&&break;sleep .1;done;[[ -f "$ROOT/u2.ready" ]]||exit 75
(cd "$A"&&"$GRANTIVA" hierarchy --format json)>"$ROOT/newest.json" 2>"$ROOT/newest.err";echo $? >"$ROOT/newest.exit.txt"
(cd "$A"&&"$GRANTIVA" hierarchy --udid "$U1" --format json)>"$ROOT/older-u1.json" 2>"$ROOT/older-u1.err";echo $? >"$ROOT/older-u1.exit.txt"
(cd "$A"&&"$GRANTIVA" runner stop --json)>"$ROOT/stop.json" 2>"$ROOT/stop.err";echo $? >"$ROOT/stop.exit.txt"
wait $P1;echo $? >"$ROOT/u1.exit.txt";P1=0;wait $P2;echo $? >"$ROOT/u2.exit.txt";P2=0
python3 - "$ROOT" "$U1" "$U2" <<'PY'||exit 76
import json,sys
from pathlib import Path
r=Path(sys.argv[1]);u1,u2=sys.argv[2:]
assert 'Featured' in (r/'newest.json').read_text() and 'Plan Visit' not in (r/'newest.json').read_text()
assert 'Plan Visit' in (r/'older-u1.json').read_text()
d=json.load(open(r/'stop.json')); assert d['status']=='stopped' and len(d['sessions'])==2,d
assert {x['udid'] for x in d['sessions']}=={u1,u2},d
assert all(isinstance(x.get('runnerPid'),int) for x in d['sessions']),d
PY
find /tmp/grantiva-sessions -maxdepth 1 -type f -print >"$ROOT/sidecars-after.txt"
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
