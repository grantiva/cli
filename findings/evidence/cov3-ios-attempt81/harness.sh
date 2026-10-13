#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt81"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt81-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt81'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); h=[x for xs in d['devices'].values() for x in xs if x.get('udid')==sys.argv[2]]
assert len(h)==1 and h[0]['name']=='cov3-ios-26'
PY
for i in {01..10}; do
  (cd "$A" && "$GRANTIVA" runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach --json) > "$ROOT/$i-start.out" 2> "$ROOT/$i-start.err"; print -r -- "$?" > "$ROOT/$i-start.exit.txt"
  pid=$(jq -r .pid "$ROOT/$i-start.out"); print -r -- "$pid" > "$ROOT/$i.pid"
  (cd "$A" && "$GRANTIVA" runner dump-hierarchy --udid "$U1") > "$ROOT/$i-hierarchy.out" 2> "$ROOT/$i-hierarchy.err"; print -r -- "$?" > "$ROOT/$i-hierarchy.exit.txt"
  (cd "$A" && "$GRANTIVA" runner stop --json) > "$ROOT/$i-stop.out" 2> "$ROOT/$i-stop.err"; print -r -- "$?" > "$ROOT/$i-stop.exit.txt"
  find /tmp/grantiva-sessions -maxdepth 1 -type f -name "$pid-*" -print | sort > "$ROOT/$i-sidecars-after.txt"
done
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); seen=set()
for i in range(1,11):
 n=f'{i:02d}'
 assert all((r/f'{n}-{leg}.exit.txt').read_text().strip()=='0' for leg in ['start','hierarchy','stop'])
 start=json.loads((r/f'{n}-start.out').read_text()); stop=json.loads((r/f'{n}-stop.out').read_text())
 assert start['status']=='started' and stop['status']=='stopped' and start['pid']==stop['runnerPid']
 assert start['pid'] not in seen; seen.add(start['pid'])
 assert (r/f'{n}-sidecars-after.txt').read_text()==''
 assert 'Landmarks' in (r/f'{n}-hierarchy.out').read_text(errors='replace')
PY
