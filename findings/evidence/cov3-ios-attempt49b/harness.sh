#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt49b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt49b-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt49b'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/crash-launch-only.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
YAML
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Crash before Home
    path:
      - run_flow: "crash-launch-only.yaml"
YAML
cp "$SCRATCH/crash-launch-only.yaml" "$SCRATCH/grantiva.yml" "$ROOT/"
cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo "command=$GRANTIVA diff capture --no-build --simulator $U1"
} > "$ROOT/commands.txt"
"$GRANTIVA" diff capture --no-build --simulator "$U1" > "$ROOT/crash-screens.out" 2> "$ROOT/crash-screens.err"
print -r -- "$?" > "$ROOT/crash-screens.exit.txt"
find "$SCRATCH/.grantiva/captures" -type f -print > "$ROOT/captures.txt" 2> "$ROOT/captures.err"
cp -R "$SCRATCH/.grantiva" "$ROOT/final-grantiva" 2> "$ROOT/copy-grantiva.err" || true
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
