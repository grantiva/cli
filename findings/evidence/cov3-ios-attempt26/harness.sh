#!/bin/zsh
set -u
zmodload zsh/datetime
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt26"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt26-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt26'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"
cp -pR "$SRC" "$SCRATCH"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
build_settings:
  - OTHER_SWIFT_FLAGS=-DROUND3
YAML
cp "$SCRATCH/grantiva.yml" "$ROOT/config-initial.yml"
cd "$SCRATCH"
integer n=0
run_case() {
  local name="$1"; shift; n=$((n+1)); local stem="$ROOT/$(printf '%02d' $n)-$name"
  print -r -- "$*" > "$stem.command.txt"; local t0=$EPOCHREALTIME
  "$@" > "$stem.out" 2> "$stem.err"; local rc=$?
  print -r -- "$rc" > "$stem.exit.txt"; print -r -- "$(( EPOCHREALTIME-t0 ))" > "$stem.elapsed-seconds.txt"; return 0
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_name=cov3-ios-26"; echo "owned_device_udid=$U1"; echo "source_copy=$SRC"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
run_case build-explicit "$GRANTIVA" build build --scheme 'Landmarks (UI Testing)' --simulator "$U1"
run_case install-launch "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1"
xcrun simctl terminate "$U1" com.kylebrowning.Landmarks > "$ROOT/pre-no-launch-terminate.out" 2> "$ROOT/pre-no-launch-terminate.err" || true
run_case install-no-launch-json "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --no-launch --json
xcrun simctl spawn "$U1" launchctl list > "$ROOT/post-no-launch-launchctl.txt" 2> "$ROOT/post-no-launch-launchctl.err"
run_case install-spaced-dd "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --derived-data-path "$SCRATCH/Derived Data spaced" --no-launch --json
mkdir -p "$SCRATCH/relative-parent"
run_case install-relative-dd "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --derived-data-path 'relative-parent/relative Derived Data' --no-launch --json
cat > grantiva.yml <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
build_settings:
  - -derivedDataPath
  - config-derived-data
  - OTHER_SWIFT_FLAGS=-DROUND3
YAML
cp grantiva.yml "$ROOT/config-build-settings.yml"
run_case flag-wins-dd "$GRANTIVA" build build --simulator "$U1" --derived-data-path "$SCRATCH/flag-derived-data"
run_case nonexistent-scheme "$GRANTIVA" build build --scheme NoSuchScheme --simulator "$U1"
cat > grantiva.yml <<'YAML'
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
YAML
cp grantiva.yml "$ROOT/config-no-scheme.yml"
run_case no-scheme-two-project-schemes "$GRANTIVA" build build --simulator "$U1"
run_case install-by-name "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator cov3-ios-26 --no-launch --json
run_case install-by-udid "$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --no-launch --json
{
 find "$SCRATCH/Derived Data spaced" -maxdepth 3 -type d -print 2>/dev/null
 find "$SCRATCH/relative-parent/relative Derived Data" -maxdepth 3 -type d -print 2>/dev/null
 find "$SCRATCH/flag-derived-data" -maxdepth 3 -type d -print 2>/dev/null
} > "$ROOT/derived-data-inventory.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
