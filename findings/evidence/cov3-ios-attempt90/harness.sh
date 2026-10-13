#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt90"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt90-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]] || { print -u2 refusing-overwrite-attempt90; exit 73; }
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
cat > "$A/fail-early.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "No Such Element"
- assertVisible: "Landmarks"
- waitForAnimationToEnd
YAML
cp "$A/fail-early.yaml" "$ROOT/fail-early.yaml"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo "$GRANTIVA run --no-build --simulator $U1 --flow fail-early.yaml --report-dir $ROOT/plain-report"
} > "$ROOT/commands.txt"
(cd "$A" && "$GRANTIVA" run --no-build --simulator "$U1" --flow fail-early.yaml --report-dir "$ROOT/plain-report") > "$ROOT/plain.out" 2> "$ROOT/plain.err"
p=$?; print -r -- "$p" > "$ROOT/plain.exit.txt"
print -r -- "$GRANTIVA run --no-build --simulator $U1 --flow fail-early.yaml --json --report-dir $ROOT/json-report" >> "$ROOT/commands.txt"
(cd "$A" && "$GRANTIVA" run --no-build --simulator "$U1" --flow fail-early.yaml --json --report-dir "$ROOT/json-report") > "$ROOT/json.out" 2> "$ROOT/json.err"
j=$?; print -r -- "$j" > "$ROOT/json.exit.txt"
python3 - "$ROOT" <<'PY' || exit 74
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); assert (r/'plain.exit.txt').read_text().strip()=='1'; assert (r/'json.exit.txt').read_text().strip()=='1'
t=(r/'plain.out').read_text(errors='replace')+(r/'plain.err').read_text(errors='replace')
assert t.count('✗')==1,t
assert t.lower().count('(skipped)')==2,t
assert '2 steps skipped' in t,t
rep=json.load(open(r/'plain-report/report.json')); flow=json.load(open(r/'plain-report/flows/flow-000.json'))
assert rep['summary']['failed']==1 and rep['summary']['skipped']==0
states=[x['status'] for x in flow['commands']]; assert states.count('failed')==1 and states.count('skipped')==2,states
o=json.load(open(r/'json.out')); steps=o['flows'][0]['steps']; assert any(x['status']=='failed' for x in steps)
for x in steps:
    if x.get('duration') is not None: assert x['duration']>0,x
PY
print -r -- "plain_exit=$p json_exit=$j finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( p == 1 && j == 1 ))
