#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt48b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt48b-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt48b-client.py"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt48b'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo "owned_device_udid=$U1"
 echo "command=python3 -I $ROOT/client.py $ROOT $SCRATCH $GRANTIVA $U1"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" > "$ROOT/client.out" 2> "$ROOT/client.err"
print -r -- "$?" > "$ROOT/client.exit.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
