#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt5"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
WORK="$SCRATCH/attempt5"
U1=563907E1-703D-4322-AE5F-FC3B06D03143

if [[ -e "$ROOT" || -e "$WORK" ]]; then
  print -u2 "refusing to overwrite existing attempt5 output or scratch"
  exit 73
fi
mkdir -p "$ROOT" "$WORK"

capture() {
  local row=$1 label=$2 cwd=$3
  shift 3
  mkdir -p "$ROOT/$row"
  { print -r -- "cwd=$cwd"; printf 'command:'; printf ' %q' "$@"; printf '\n'; } >> "$ROOT/$row/commands.txt"
  (cd "$cwd" && "$@") > "$ROOT/$row/$label.out" 2> "$ROOT/$row/$label.err"
  local rc=$?
  print "exit=$rc output=$label.out stderr=$label.err" >> "$ROOT/$row/commands.txt"
  return 0
}

mkdir -p "$WORK/CLI-048/sub" "$WORK/CLI-049"
cat > "$WORK/CLI-048/sub/flow.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- takeScreenshot: RelativeSubflow
YAML
cat > "$WORK/CLI-048/grantiva.yml" <<'YAML'
bundle_id: com.kylebrowning.Landmarks
simulator: cov3-ios-26
screens:
  - name: Relative
    path:
      - run_flow: "sub/flow.yaml"
YAML
capture CLI-048 relative "$WORK/CLI-048" "$GRANTIVA" diff capture --no-build --simulator "$U1"
cp "$WORK/CLI-048/grantiva.yml" "$ROOT/CLI-048/relative.grantiva.yml"
mv "$WORK/CLI-048/grantiva.yml" "$WORK/CLI-048/relative.grantiva.yml"
cat > "$WORK/CLI-048/grantiva.yml" <<'YAML'
bundle_id: com.kylebrowning.Landmarks
simulator: cov3-ios-26
screens:
  - name: Missing
    path:
      - run_flow: "sub/missing.yaml"
YAML
capture CLI-048 missing "$WORK/CLI-048" "$GRANTIVA" diff capture --no-build --simulator "$U1"
cp "$WORK/CLI-048/grantiva.yml" "$ROOT/CLI-048/missing.grantiva.yml"
cp "$WORK/CLI-048/sub/flow.yaml" "$ROOT/CLI-048/sub-flow.yaml"

cat > "$WORK/CLI-049/grantiva.yml" <<'YAML'
bundle_id: com.kylebrowning.Landmarks
simulator: cov3-ios-26
screens:
  - name: Cycle
    path:
      - run_flow: "a.yaml"
YAML
cat > "$WORK/CLI-049/a.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- runFlow: b.yaml
YAML
cat > "$WORK/CLI-049/b.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- runFlow: a.yaml
YAML
capture CLI-049 cycle "$WORK/CLI-049" "$GRANTIVA" diff capture --no-build --simulator "$U1"
cp "$WORK/CLI-049/"*.yaml "$ROOT/CLI-049/"

mkdir -p "$WORK/flows"
cat > "$WORK/flows/quote-emoji.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Mount \"Denali\" 🏔️"
- takeScreenshot: QuoteEmoji
YAML
cat > "$WORK/flows/id-selector.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: {text: "Favorites"}
- tapOn: {id: "heart"}
- takeScreenshot: IdSelector
YAML
cat > "$WORK/flows/scroll.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- scroll
- scroll: {direction: up}
- takeScreenshot: Scroll
YAML
capture CLI-061 run "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow "$WORK/flows/quote-emoji.yaml" --verbose --report-dir "$ROOT/CLI-061/report"
capture CLI-064 run "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow "$WORK/flows/id-selector.yaml" --verbose --report-dir "$ROOT/CLI-064/report"
capture CLI-066 run "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow "$WORK/flows/scroll.yaml" --verbose --report-dir "$ROOT/CLI-066/report"
cp "$WORK/flows/quote-emoji.yaml" "$ROOT/CLI-061/input.yaml"
cp "$WORK/flows/id-selector.yaml" "$ROOT/CLI-064/input.yaml"
cp "$WORK/flows/scroll.yaml" "$ROOT/CLI-066/input.yaml"

find "$APP/.grantiva" "$WORK" -type f -name 'maestro-runner.log' -print > "$ROOT/maestro-log-paths.txt" 2> "$ROOT/find-logs.err"
xcrun simctl list devices booted > "$ROOT/booted-after.txt" 2> "$ROOT/booted-after.err"
