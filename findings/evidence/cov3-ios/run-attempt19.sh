#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt19"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SCRATCH="$BASE/attempt19-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
FIX="$WT/findings/evidence/cov3-ios-attempt17/fixtures"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt19'; exit 73; fi
mkdir -p "$ROOT" "$SCRATCH/threshold" "$SCRATCH/stale/.maestro"
cp "$0" "$ROOT/harness.sh"
cp -R "$FIX/steps/." "$SCRATCH/threshold/"
cp "$FIX/fail/.maestro/01-browse.yaml" "$SCRATCH/stale/.maestro/"
cat > "$SCRATCH/stale/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
YAML
integer n=0
run() {
  local cwd="$1" name="$2"; shift 2; n=$((n+1)); local p="$ROOT/$(printf '%02d' $n)-$name"
  { print -r -- "cwd=$cwd"; print -r -- "$*"; } > "$p.command.txt"
  local start=$(date +%s); (cd "$cwd" && "$@") > "$p.out" 2> "$p.err"; local rc=$? end=$(date +%s)
  print -r -- "$rc" > "$p.exit.txt"; print -r -- "$((end-start))" > "$p.elapsed-seconds.txt"
}
snapshot() {
  local project="$1" name="$2"; mkdir -p "$ROOT/snapshots/$name"
  [[ -d "$project/.grantiva" ]] && cp -pR "$project/.grantiva/." "$ROOT/snapshots/$name/"
  cp -p "$project/grantiva.yml" "$ROOT/snapshots/$name/grantiva.yml"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
run "$SCRATCH/threshold" threshold-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
snapshot "$SCRATCH/threshold" threshold-after-capture
run "$SCRATCH/threshold" threshold-approve "$GRANTIVA" diff approve
snapshot "$SCRATCH/threshold" threshold-after-approve
run "$SCRATCH/threshold" threshold-wait-recapture /bin/zsh -c "sleep 61; '$GRANTIVA' diff capture --no-build --simulator '$U1' --verbose"
snapshot "$SCRATCH/threshold" threshold-after-recapture
run "$SCRATCH/threshold" threshold-default "$GRANTIVA" diff compare --json
sed -i '' 's/threshold: 0.02/threshold: 1.0/' "$SCRATCH/threshold/grantiva.yml"
snapshot "$SCRATCH/threshold" threshold-pixel-raised-config
run "$SCRATCH/threshold" threshold-pixel-raised "$GRANTIVA" diff compare --json
sed -i '' 's/perceptual_threshold: 5.0/perceptual_threshold: 80.0/' "$SCRATCH/threshold/grantiva.yml"
snapshot "$SCRATCH/threshold" threshold-both-raised-config
run "$SCRATCH/threshold" threshold-both-raised "$GRANTIVA" diff compare --json
run "$SCRATCH/stale" stale-initial-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
snapshot "$SCRATCH/stale" stale-after-success
cp "$FIX/fail/grantiva.yml" "$SCRATCH/stale/grantiva.yml"
snapshot "$SCRATCH/stale" stale-failing-config
run "$SCRATCH/stale" stale-failing-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
snapshot "$SCRATCH/stale" stale-after-failure
run "$SCRATCH/stale" stale-compare "$GRANTIVA" diff compare --json
snapshot "$SCRATCH/stale" stale-after-compare
find "$ROOT/snapshots" -type f -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/snapshots.sha256"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
exit 0
