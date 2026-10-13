#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt66"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt66-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143; DD="$A/derived-data"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt66'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
flows:
  - appvar.yaml
YAML
cat > "$A/appvar.yaml" <<'YAML'
appId: ${APP_ID}
---
- launchApp
- assertVisible: "Landmarks"
YAML
cp "$A/grantiva.yml" "$A/appvar.yaml" "$ROOT/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'D2-06 exact config without bundle_id and APP_ID flow, no-build failure then built detection; D2-07 exact build-install JSON status variants.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
run() { local n="$1"; shift; print -r -- "$GRANTIVA $*" > "$ROOT/$n.command.txt"; (cd "$A" && "$GRANTIVA" "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"); print -r -- "$?" > "$ROOT/$n.exit.txt"; }
run appvar-no-build run --no-build --flow appvar.yaml --simulator "$U1" --platform ios
run appvar-built run --flow appvar.yaml --simulator "$U1" --platform ios --derived-data-path "$DD" --report-dir "$ROOT/appvar-built-report"
run install-launch build install --json --simulator "$U1" --platform ios --derived-data-path "$DD"
run install-no-launch build install --json --no-launch --simulator "$U1" --platform ios --derived-data-path "$DD"
run install-skipped build install --json --no-build --no-launch --simulator "$U1" --platform ios
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json,sys
r=Path(sys.argv[1]); bad=[]
if int((r/'appvar-no-build.exit.txt').read_text())==0: bad.append(('no-build should need app ID'))
for n in ['appvar-built','install-launch','install-no-launch','install-skipped']:
 if int((r/f'{n}.exit.txt').read_text()) != 0: bad.append((n,'exit'))
for n,w in [('install-launch','launched'),('install-no-launch','installed'),('install-skipped','skipped')]:
 try:g=json.load(open(r/f'{n}.out')).get('status')
 except Exception:g=None
 if g!=w: bad.append((n,w,g))
print(bad); raise SystemExit(bool(bad))
PY
