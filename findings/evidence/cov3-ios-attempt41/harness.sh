#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt41"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt41-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt41'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
cp "$SCRATCH/.maestro/01-browse.yaml" "$ROOT/01-browse.yaml"
cp "$SCRATCH/.maestro/coverage/02-exact-negative.yaml" "$ROOT/02-exact-negative.yaml"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone pass-json-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json --report-dir "$ROOT/pass-report"
runone fail-json-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --json --report-dir "$ROOT/fail-report"
runone pass-quiet "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --quiet
runone fail-quiet "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --quiet
runone pass-json "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json
runone fail-json "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --json
runone pass-json-verbose "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json --verbose
runone capture-json "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
find .grantiva -type f -print | sort > "$ROOT/grantiva-files-after-no-report.txt"
cp -pR .grantiva "$ROOT/final-grantiva"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
