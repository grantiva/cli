#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt35"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt35-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt35'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: Favorites
  - name: Deep Links
    path:
      - tap: Deep Links
YAML
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"; cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
runone compare-no-baselines "$GRANTIVA" diff compare --json
runone approve-all "$GRANTIVA" diff approve --json
runone compare-unchanged "$GRANTIVA" diff compare
runone compare-json "$GRANTIVA" diff compare --json
runone compare-capture "$GRANTIVA" diff compare --capture --no-build --simulator "$U1" --json
shasum -a 256 .grantiva/baselines/*.png > "$ROOT/baselines-before-selective.sha256"
cp '.grantiva/captures/Deep Links.png' .grantiva/captures/Home.png
shasum -a 256 .grantiva/captures/*.png > "$ROOT/captures-before-selective.sha256"
runone approve-home "$GRANTIVA" diff approve Home --json
shasum -a 256 .grantiva/baselines/*.png > "$ROOT/baselines-after-selective.sha256"
cp -pR .grantiva "$ROOT/final-grantiva"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
