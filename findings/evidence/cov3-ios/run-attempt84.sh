#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt84"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt84-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt84'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); h=[x for xs in d['devices'].values() for x in xs if x.get('udid')==sys.argv[2]]
assert len(h)==1 and h[0]['name']=='cov3-ios-26'
PY
(cd "$A" && "$GRANTIVA" runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach --json) > "$ROOT/start.out" 2> "$ROOT/start.err"; print -r -- "$?" > "$ROOT/start.exit.txt"
(cd "$A" && "$GRANTIVA" runner stop --json) > "$ROOT/stop.out" 2> "$ROOT/stop.err"; print -r -- "$?" > "$ROOT/stop.exit.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$ROOT/wait-started.txt"
sleep 120
date -u +%Y-%m-%dT%H:%M:%SZ > "$ROOT/wait-finished.txt"
ps -axo pid,ppid,pgid,etime,command > "$ROOT/ps-after-wait.txt"
rg -F "$U1" "$ROOT/ps-after-wait.txt" > "$ROOT/ps-matching-udid.txt" || true
(cd "$A" && "$GRANTIVA" simulator teardown --udid "$U1" --force --json) > "$ROOT/teardown.out" 2> "$ROOT/teardown.err"; print -r -- "$?" > "$ROOT/teardown.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
python3 - "$ROOT" "$U1" <<'PY' || exit 75
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); u=sys.argv[2]
assert all((r/f'{x}.exit.txt').read_text().strip()=='0' for x in ['start','stop','teardown'])
start=json.loads((r/'start.out').read_text()); stop=json.loads((r/'stop.out').read_text()); tear=json.loads((r/'teardown.out').read_text())
assert start['pid']==stop['runnerPid'] and stop['status']=='stopped'
assert len(tear)==1 and tear[0]['udid']==u and tear[0]['reclaimed'] is False and tear[0]['processes']==[]
assert 'Killed diagnose pid' not in (r/'teardown.err').read_text(errors='replace')+(r/'teardown.out').read_text(errors='replace')
d=json.loads((r/'simulators-after.json').read_text()); assert any(x.get('udid')==u for xs in d['devices'].values() for x in xs)
PY
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
