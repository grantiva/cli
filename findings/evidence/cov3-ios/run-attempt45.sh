#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt45"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt45-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt45'; exit 73; fi
mkdir -p "$ROOT/flows"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
make_crash_flow() {
 local file=$1 body=$2
 cat > "$SCRATCH/$file" <<'YAML'
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
YAML
 printf '%b\n' "$body" >> "$SCRATCH/$file"
 cp "$SCRATCH/$file" "$ROOT/flows/${file:t}"
}
make_crash_flow wait-visible.yaml '- extendedWaitUntil:
    visible: "Landmarks"
    timeout: 15000'
make_crash_flow not-visible.yaml '- assertNotVisible: "Landmarks"'
make_crash_flow scroll-until.yaml '- scrollUntilVisible:
    element: "Landmark 70"
    direction: DOWN
    timeout: 15000'
make_crash_flow wait-anim.yaml '- waitForAnimationToEnd:
    timeout: 5000
- assertVisible: "Featured"'
cat > "$SCRATCH/intentional-stop.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- stopApp
- waitForAnimationToEnd:
    timeout: 5000
YAML
cp "$SCRATCH/intentional-stop.yaml" "$ROOT/flows/intentional-stop.yaml"
cp "$SCRATCH/.maestro/99-crash.yaml" "$ROOT/flows/99-crash.yaml"
cp "$SCRATCH/.maestro/03-edit.yaml" "$ROOT/flows/03-edit.yaml"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone edit "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/03-edit.yaml --report-dir "$ROOT/edit-report"
for i in 1 2 3; do runone "crash-$i" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/99-crash.yaml --report-dir "$ROOT/crash-$i-report"; done
runone wait-visible "$GRANTIVA" run --no-build --simulator "$U1" --flow wait-visible.yaml --report-dir "$ROOT/wait-visible-report"
runone not-visible "$GRANTIVA" run --no-build --simulator "$U1" --flow not-visible.yaml --report-dir "$ROOT/not-visible-report"
runone scroll-until "$GRANTIVA" run --no-build --simulator "$U1" --flow scroll-until.yaml --report-dir "$ROOT/scroll-until-report"
runone wait-anim "$GRANTIVA" run --no-build --simulator "$U1" --flow wait-anim.yaml --report-dir "$ROOT/wait-anim-report"
runone intentional-stop "$GRANTIVA" run --no-build --simulator "$U1" --flow intentional-stop.yaml --report-dir "$ROOT/intentional-stop-report"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
