#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt43"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt43-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt43'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone bad-device-json "$GRANTIVA" run --no-build --simulator 00000000-0000-0000-0000-000000000000 --flow .maestro/01-browse.yaml --json
runone bad-scheme-json "$GRANTIVA" run --scheme 'Round3 Missing Scheme' --simulator "$U1" --flow .maestro/01-browse.yaml --json
runone doctor-text env DEVELOPER_DIR=/nonexistent "$GRANTIVA" doctor
runone doctor-json env DEVELOPER_DIR=/nonexistent "$GRANTIVA" doctor --json
runone diff-ephemeral "$GRANTIVA" diff capture --no-build --simulator "$U1"
runone diff-preserved "$GRANTIVA" diff capture --no-build --simulator "$U1" --report-dir "$ROOT/diff-report"
find "$ROOT/diff-report" -type f -print | sort > "$ROOT/diff-report-files.txt"
runone ci-no-key "$GRANTIVA" ci run --no-build --simulator "$U1" --report-dir "$ROOT/ci-report"
find "$ROOT/ci-report" -type f -print 2>/dev/null | sort > "$ROOT/ci-report-files.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
