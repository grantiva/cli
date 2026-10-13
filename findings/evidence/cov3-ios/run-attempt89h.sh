#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt89h"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt89h-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
PY="$WT/findings/evidence/cov3-ios/attempt89h.py"
[[ ! -e "$ROOT" && ! -e "$A" ]] || { print -u2 refusing-overwrite-attempt89h; exit 73; }
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"; cp "$PY" "$ROOT/client.py"
xcrun simctl list devices --json > "$ROOT/simulators-before.json"
"$GRANTIVA" simulator sessions --json > "$ROOT/sessions-before.json" || exit 74
ps -axo pid=,ppid=,state=,command= > "$ROOT/processes-before.txt"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); u=sys.argv[2]; h=[x for a in d['devices'].values() for x in a if x.get('udid')==u]
assert len(h)==1 and h[0]['name']=='cov3-ios-26' and h[0]['state']=='Booted',h
PY
python3 - "$ROOT/sessions-before.json" "$U1" <<'PY' || exit 74
import json,sys,glob,os
d=json.load(open(sys.argv[1])); u=sys.argv[2]
rows=d if isinstance(d,list) else d.get('sessions',[])
mine=[x for x in rows if x.get('udid')==u or x.get('deviceUDID')==u]
assert len(mine)==1 and mine[0].get('sessionId')=='cov3-ios',mine
# Capacity reservations are expected. A live runner owner for U1 is not.
owners=[]
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:
  x=json.load(open(p))
  if str(x.get('udid'))==u: owners.append((p,x))
 except Exception: pass
assert not owners,owners
session_files=[]
for p in glob.glob('/tmp/grantiva-sessions/*'):
 try:
  if u in open(p,errors='ignore').read(): session_files.append(p)
 except (OSError,UnicodeError): pass
assert not session_files,session_files
PY
python3 - "$ROOT/processes-before.txt" "$U1" <<'PY' || exit 74
import sys
t=open(sys.argv[1],errors='replace').read(); u=sys.argv[2]
hits=[x for x in t.splitlines() if u in x and ('grantiva-runner' in x or 'maestro-runner' in x)]
assert not hits,hits
PY
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$PY"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT" "$A" "$GRANTIVA" "$U1"; e=$?
xcrun simctl list devices --json > "$ROOT/simulators-after.json"
print -r -- "client_exit=$e finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit $e
