#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt49"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt49-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt49'; exit 73; fi
mkdir -p "$ROOT/flows"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/wait-anim-crash.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- waitForAnimationToEnd:
    timeout: 5000
- assertVisible: "Featured"
YAML
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Crash before Home
    path:
      - run_flow: ".maestro/99-crash.yaml"
YAML
cp "$SCRATCH/wait-anim-crash.yaml" "$ROOT/flows/wait-anim-crash.yaml"
cp "$SCRATCH/.maestro/99-crash.yaml" "$ROOT/flows/99-crash.yaml"
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
cd "$SCRATCH"
runone() {
  local n=$1; shift
  print -r -- "$*" > "$ROOT/$n.command.txt"
  local t0=$(python3 -c 'import time; print(time.monotonic())')
  "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"
  local rc=$? t1=$(python3 -c 'import time; print(time.monotonic())')
  print -r -- "$rc" > "$ROOT/$n.exit.txt"
  python3 -c 'import sys; print(float(sys.argv[2])-float(sys.argv[1]))' "$t0" "$t1" > "$ROOT/$n.wall-seconds.txt"
}
{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
for i in 1 2 3; do
  runone "wait-anim-$i" "$GRANTIVA" run --no-build --simulator "$U1" --flow wait-anim-crash.yaml --report-dir "$ROOT/wait-anim-$i-report"
done
runone crash-screens "$GRANTIVA" diff capture --no-build --simulator "$U1"
find "$SCRATCH/.grantiva/captures" -type f -print > "$ROOT/crash-screens-captures.txt" 2> "$ROOT/crash-screens-captures.err"
cp -R "$SCRATCH/.grantiva" "$ROOT/final-grantiva" 2> "$ROOT/copy-grantiva.err" || true
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
