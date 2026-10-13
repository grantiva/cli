#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt78c"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt78c-a"; B="$BASE/attempt78c-b"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
HELPER="$WT/findings/evidence/cov3-ios/attempt78c-n3.py"
if [[ -e "$ROOT" || -e "$A" || -e "$B" ]]; then print -u2 'refusing overwrite attempt78c'; exit 73; fi
mkdir -p "$ROOT" "$B"; cp "$0" "$ROOT/harness.sh"; cp "$HELPER" "$ROOT/n3-helper.py"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
run() { local n=$1; shift; print -r -- "$GRANTIVA $*" > "$ROOT/$n.command.txt"; (cd "$A" && "$GRANTIVA" "$@") > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$HELPER"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('udid')==sys.argv[2]]
assert len(hits)==1 and hits[0]['name']=='cov3-ios-26'
PY
run start-json runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach --json
run start-again-json runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach --json
run stop-json runner stop --json
run stop-none-json runner stop --json
python3 -I "$HELPER" "$ROOT" "$A" "$B" > "$ROOT/helper.out" 2> "$ROOT/helper.err"; print -r -- "$?" > "$ROOT/helper.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
python3 - "$ROOT/simulators-after.json" "$U1" <<'PY' || exit 75
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('udid')==sys.argv[2]]
assert len(hits)==1 and hits[0]['name']=='cov3-ios-26'
PY
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
import json,sys
from pathlib import Path
r=Path(sys.argv[1])
assert all((r/f'{n}.exit.txt').read_text().strip()=='0' for n in ['start-json','start-again-json','stop-json','stop-none-json'])
assert (r/'helper.exit.txt').read_text().strip()=='0'
PY
