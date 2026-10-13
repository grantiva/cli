#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios; ROOT="$WT/findings/evidence/cov3-ios-attempt92"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt92-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
APP="$BASE/attempt26-ios/flag-derived-data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" ]] || { print -u2 refusing-attempt92;exit 73; }
mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$WT/findings/evidence/cov3-ios-attempt39/grantiva.yml" "$A/grantiva.yml";cp "$0" "$ROOT/harness.sh";cp "$A/grantiva.yml" "$ROOT/grantiva.yml"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)";shasum -a 256 "$GRANTIVA" "$APP/Info.plist";echo "owned_device_udid=$U1";echo "$GRANTIVA diff capture --app-file $APP --simulator $U1"; } > "$ROOT/commands.txt"
(cd "$A" && "$GRANTIVA" diff capture --app-file "$APP" --simulator "$U1") > "$ROOT/capture-five.out" 2> "$ROOT/capture-five.err";e=$?
print -r -- "$e" > "$ROOT/capture-five.exit.txt"
find "$A/.grantiva" -type f -print > "$ROOT/generated-files.txt" 2>/dev/null || true
rsync -a "$A/.grantiva/" "$ROOT/final-grantiva/" 2> "$ROOT/copy.err" || true
python3 - "$ROOT" <<'PY' || exit 74
import sys
from pathlib import Path
r=Path(sys.argv[1]);assert (r/'capture-five.exit.txt').read_text().strip()=='0'
t=(r/'capture-five.out').read_text();
for n in ['Home','Favorites','Deep Links','Lakes','Detail']:assert n in t,(n,t)
PY
print -r -- "exit=$e finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit $e
