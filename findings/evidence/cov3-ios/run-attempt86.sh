#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt86"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; F="$BASE/attempt86-flow"; SP="$BASE/attempt86-screen-pass"; SF="$BASE/attempt86-screen-fail"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$F" || -e "$SP" || -e "$SF" ]]; then print -u2 'refusing overwrite attempt86'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"
for d in "$F" "$SP" "$SF"; do rsync -a --exclude '.grantiva' "$SRC/" "$d/"; done
cat > "$SP/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: "Favorites"
YAML
cat > "$SF/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Broken
    path:
      - tap: "No Such Element"
YAML
cp "$SP/grantiva.yml" "$ROOT/screen-pass.yml"; cp "$SF/grantiva.yml" "$ROOT/screen-fail.yml"
run() { local cwd=$1 n=$2; shift 2; print -r -- "$GRANTIVA $*" > "$ROOT/$n.command.txt"; (cd "$cwd" && "$GRANTIVA" "$@") > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
run "$F" flow-pass run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json
run "$F" flow-fail run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --json
run "$SP" screen-pass run --no-build --simulator "$U1" --json
run "$SF" screen-fail run --no-build --simulator "$U1" --json
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
python3 - "$ROOT" <<'PY' || exit 74
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); expected={'flow-pass':0,'flow-fail':1,'screen-pass':0,'screen-fail':1}
for name,rc in expected.items():
 assert int((r/f'{name}.exit.txt').read_text())==rc
 d=json.load(open(r/f'{name}.out')); assert 'reportDir' not in d
 assert d['allPassed'] is (rc==0)
 if rc: assert d.get('error')
 else: assert 'error' not in d
 assert all(set(['name','kind','passed','steps','screenshots']) <= set(x) for x in d['screens'])
assert [x['kind'] for x in json.load(open(r/'flow-pass.out'))['screens']]==['flow']
for name in ['screen-pass','screen-fail']:
 d=json.load(open(r/f'{name}.out')); assert len(d['screens'])==2 and all(x['kind']=='screen' for x in d['screens'])
PY
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
