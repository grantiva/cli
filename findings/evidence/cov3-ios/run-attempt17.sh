#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt17"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"
SCRATCH="$BASE/attempt17-ios"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt17'; exit 73; fi
mkdir -p "$ROOT" "$SCRATCH"/{steps,maestro,fail,slow}
cp "$0" "$ROOT/harness.sh"
mkdir -p "$SCRATCH/steps/.maestro/coverage" "$SCRATCH/fail/.maestro"
cp "$SOURCE/.maestro/coverage/14-runflow-sub.yaml" "$SCRATCH/steps/.maestro/coverage/"
cp "$SOURCE/.maestro/01-browse.yaml" "$SCRATCH/fail/.maestro/"
cat > "$SCRATCH/steps/.maestro/coverage/cfg-relaunch.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
YAML
cat > "$SCRATCH/steps/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Lakes Exact
    path:
      - run_flow: ".maestro/coverage/cfg-relaunch.yaml"
      - assert_visible: "Golden Gate.*"
      - assert_not_visible: {text: "Golden Gate.*", exact: true}
      - tap: {text: "Lakes", exact: true}
      - assert_visible: {text: "Mono Lake", exact: true}
  - name: Caching
    path:
      - run_flow: ".maestro/coverage/cfg-relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Caching Demo"
      - wait: 3
      - assert_visible: "Cache Policy"
  - name: Edit Typed
    path:
      - run_flow: ".maestro/coverage/cfg-relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Edit Landmark"
      - tap: "Name"
      - type: " typed"
      - tap: "Done"
      - assert_visible: "Golden Gate Bridge typed"
  - name: Gestures Swiped
    path:
      - run_flow: ".maestro/coverage/cfg-relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Gesture Lab"
      - swipe: up
      - swipe: DOWN
      - swipe: Left
      - swipe: right
      - assert_visible: "Last swipe: right"
  - name: Sub Flow
    path:
      - run_flow: ".maestro/coverage/cfg-relaunch.yaml"
      - run_flow: ".maestro/coverage/14-runflow-sub.yaml"
diff:
  threshold: 0.02
  perceptual_threshold: 5.0
YAML
cat > "$SCRATCH/maestro/grantiva.yml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- swipe:
    direction: UP
- waitForAnimationToEnd
- takeScreenshot: "Home Swiped"
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- tapOn:
    id: "clock"
- assertVisible:
    id: "clock"
- takeScreenshot: "Caching Maestro"
YAML
cat > "$SCRATCH/fail/grantiva.yml" <<'YAML'
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
cat > "$SCRATCH/slow/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Slow
    path:
      - tap: "Deep Links"
      - wait: 45
YAML
cp -R "$SCRATCH" "$ROOT/fixtures"
integer n=0
run() {
  local cwd="$1" name="$2"; shift 2; n=$((n+1))
  local p="$ROOT/$(printf '%02d' $n)-$name"
  print -r -- "cwd=$cwd" > "$p.command.txt"
  print -r -- "$*" >> "$p.command.txt"
  local start=$(date +%s)
  (cd "$cwd" && "$@") > "$p.out" 2> "$p.err"
  local rc=$? end=$(date +%s)
  print -r -- "$rc" > "$p.exit.txt"
  print -r -- "$((end-start))" > "$p.elapsed-seconds.txt"
}
{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
  echo "owned_device_udid=$U1"; echo "owned_device_name=cov3-ios-26"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
run "$SCRATCH/steps" steps-json "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
run "$SCRATCH/steps" steps-verbose "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
run "$SCRATCH/maestro" maestro-verbose "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
run "$SCRATCH/fail" fail-run "$GRANTIVA" run --no-build --simulator "$U1" --continue-on-failure --report-dir "$ROOT/fail-report"
run "$SCRATCH/fail" fail-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose
run "$SCRATCH/fail" fail-compare "$GRANTIVA" diff compare --json
run "$SCRATCH/slow" slow-timeout "$GRANTIVA" run --no-build --simulator "$U1" --timeout 30 --report-dir "$ROOT/slow-timeout-report"
run "$SCRATCH/slow" slow-full "$GRANTIVA" run --no-build --simulator "$U1" --report-dir "$ROOT/slow-full-report"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
exit 0
