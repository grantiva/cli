#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt97"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt97
U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ; shasum -a 256 "$GRANTIVA"; echo owned_device_udid=$U1; } > "$ROOT/commands.txt"
python3 - "$U1" <<'PY' || exit 74
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except Exception:continue
 assert str(d.get('udid')) != sys.argv[1], (p,d)
PY
cleanup() { (cd "$A" && "$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err") || true; }
trap cleanup EXIT
cd "$A"
"$GRANTIVA" runner start --detach --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios >"$ROOT/start.json" 2>"$ROOT/start.err" || exit 75
R=$(jq -r .pid "$ROOT/start.json"); echo "$R" > "$ROOT/runner.pid"
OWNER=''
for n in {1..100}; do OWNER=$(find /tmp/grantiva-sessions -maxdepth 1 -name "$R.owner.json" -print -quit 2>/dev/null); [[ -n "$OWNER" ]] && break; sleep .1; done
[[ -n "$OWNER" ]] || exit 76
cp "$OWNER" "$ROOT/owner-before.json"
READY=0
for n in {1..40}; do
  "$GRANTIVA" hierarchy --udid "$U1" --format json >"$ROOT/ready-$n.json" 2>"$ROOT/ready-$n.err"; e=$?; echo $e >"$ROOT/ready-$n.exit.txt"
  if ((e==0)) && rg -q Landmarks "$ROOT/ready-$n.json"; then cp "$ROOT/ready-$n.json" "$ROOT/ready.json"; READY=1; break; fi
  sleep .5
done
((READY==1)) || exit 77
find /tmp/grantiva-sessions -maxdepth 1 -name "$R*" -print -exec shasum -a 256 {} \; >"$ROOT/sidecars-before.txt"
kill -9 "$R" || exit 78
for n in {1..100}; do kill -0 "$R" 2>/dev/null || break; sleep .1; done
kill -0 "$R" 2>/dev/null && exit 79
ps -axo pid,ppid,pgid,state,etime,command >"$ROOT/ps-after-kill.txt"
SECONDS=0
"$GRANTIVA" hierarchy --udid "$U1" --timeout 10 --format json >"$ROOT/hierarchy-dead.out" 2>"$ROOT/hierarchy-dead.err"; echo $? >"$ROOT/hierarchy-dead.exit.txt"; echo $SECONDS >"$ROOT/hierarchy-dead.seconds.txt"
"$GRANTIVA" runner stop --json >"$ROOT/stop.json" 2>"$ROOT/stop.err"; echo $? >"$ROOT/stop.exit.txt"
find /tmp/grantiva-sessions -maxdepth 1 -name "$R*" -print >"$ROOT/sidecars-after.txt"
find "$GRANTIVA_RUNNER_HOME" -path "*/devices/$U1" -o -path "*/locks/$U1.lock" >"$ROOT/runner-home-after.txt" 2>"$ROOT/runner-home-after.err" || true
jq -e --argjson r "$R" '.status=="stopped" and .alreadyExited==true and .runnerPid==$r and (.pid|type=="number")' "$ROOT/stop.json" >"$ROOT/stop-contract.txt" 2>"$ROOT/stop-contract.err"; echo $? >"$ROOT/stop-contract.exit.txt"
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ) >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
