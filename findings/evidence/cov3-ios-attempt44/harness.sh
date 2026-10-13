#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt44"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt44-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
DD="$SCRATCH/round3 derived data"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt44'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
[[ $(awk '$1 == "simulator:" {print $2; exit}' "$ROOT/grantiva.yml") == cov3-ios-26 ]] || { print -u2 'config does not name owned simulator'; exit 74; }
xcrun simctl list devices --json > "$ROOT/simctl-preflight.json"
[[ $(jq -r --arg n cov3-ios-26 --arg u "$U1" '[.devices[][]|select(.name==$n and .udid==$u)]|length' "$ROOT/simctl-preflight.json") == 1 ]] || { print -u2 'owned configured simulator mapping mismatch'; exit 75; }
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "derived_data=$DD"
} > "$ROOT/commands.txt"
runone build-json "$GRANTIVA" build build --json

# Exact README local workflow; the frozen config and guarded preflight bind it to owned U1.
runone readme-capture "$GRANTIVA" diff capture
runone readme-compare-new "$GRANTIVA" diff compare
runone readme-approve "$GRANTIVA" diff approve
runone readme-compare-pass "$GRANTIVA" diff compare

# One shared DerivedData location keeps later build commands incremental while proving both consumers.
runone run-derived "$GRANTIVA" run --simulator "$U1" --derived-data-path "$DD" --flow .maestro/01-browse.yaml --json
runone diff-derived "$GRANTIVA" diff capture --simulator "$U1" --derived-data-path "$DD" --json
runone diff-derived-approve "$GRANTIVA" diff approve --json
runone compare-capture-derived "$GRANTIVA" diff compare --capture --scheme 'Landmarks (UI Testing)' --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --derived-data-path "$DD" --json
find "$DD/Build/Products" -maxdepth 3 -type d -name '*.app' -print | sort > "$ROOT/derived-products.txt"
cp -pR .grantiva "$ROOT/final-grantiva"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
