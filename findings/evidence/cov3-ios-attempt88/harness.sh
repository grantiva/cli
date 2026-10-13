#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt88"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"
A="$BASE/attempt88-configless"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]] || { print -u2 'refusing overwrite attempt88'; exit 73; }
mkdir -p "$ROOT"
rsync -a --exclude '.grantiva' --exclude 'grantiva.yml' --exclude 'grantiva-android.yml' "$SRC/" "$A/"
cp "$0" "$ROOT/harness.sh"
cp "$CLIENT" "$ROOT/client.py"
[[ ! -e "$A/grantiva.yml" && ! -e "$A/grantiva-android.yml" ]] || exit 74
xcrun simctl list devices --json > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 75
import json,sys
d=json.load(open(sys.argv[1])); u=sys.argv[2]
hits=[x for a in d['devices'].values() for x in a if x.get('udid')==u]
assert len(hits)==1 and hits[0]['name']=='cov3-ios-26' and hits[0]['state']=='Booted', hits
PY
cat > "$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_run","arguments":{"scheme":"Landmarks (UI Testing)","simulator":"$U1"}},"_save":"run.json"},
 {"method":"tools/list","params":{}}
]
JSON
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 shasum -a 256 "$GRANTIVA" "$CLIENT"
 echo "owned_device_udid=$U1"
 echo 'input variation: matrix names only scheme; simulator is the safety-required explicit owned-device selector and does not provide a bundle ID or config.'
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios
e=$?
xcrun simctl list devices --json > "$ROOT/simulators-after.json"
python3 - "$ROOT" "$U1" <<'PY' || exit 76
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); u=sys.argv[2]
o=json.load(open(r/'mcp/run.json'))
assert not o.get('error'),o
res=o['result']; assert not res.get('isError'),res
t='\n'.join(x.get('text','') for x in res.get('content',[]) if x.get('type')=='text')
assert 'App built and launched.' in t
assert 'Scheme: Landmarks (UI Testing)' in t
assert 'Bundle ID: com.kylebrowning.Landmarks' in t
assert 'Simulator: cov3-ios-26 ('+u+')' in t
assert 'Product:' in t and 'Landmarks.app' in t
assert 'grantiva.yml' not in t
before=json.load(open(r/'simulators-before.json')); after=json.load(open(r/'simulators-after.json'))
def names(d): return sorted((x['udid'],x['name']) for a in d['devices'].values() for x in a)
assert names(before)==names(after)
(r/'run-text.txt').write_text(t+'\n')
PY
print -r -- "client_exit=$e finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( e == 0 ))
