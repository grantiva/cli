#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt50"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt50-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt50'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/pass.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
flows:
  - .maestro/01-browse.yaml
YAML
cat > "$SCRATCH/fail.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Broken
    path:
      - tap: "No Such Element"
flows:
  - .maestro/01-browse.yaml
YAML
cp "$SCRATCH/pass.yml" "$SCRATCH/fail.yml" "$ROOT/"
cd "$SCRATCH"
runone() {
  local n=$1 config=$2; shift 2
  cp "$config" grantiva.yml
  cp grantiva.yml "$ROOT/$n.grantiva.yml"
  print -r -- "$*" > "$ROOT/$n.command.txt"
  "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"
  print -r -- "$?" > "$ROOT/$n.exit.txt"
  cp "$ROOT/$n.ready" "$ROOT/$n.ready-final" 2> "$ROOT/$n.ready-copy.err" || true
}
{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone pass pass.yml "$GRANTIVA" run --no-build --simulator "$U1" --json --ready-file "$ROOT/pass.ready" --report-dir "$ROOT/pass-report"
runone fail-continue fail.yml "$GRANTIVA" run --no-build --simulator "$U1" --json --continue-on-failure --ready-file "$ROOT/fail-continue.ready" --report-dir "$ROOT/fail-continue-report"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
