#!/bin/zsh
set -u

QA=/Users/kyle/.grantiva-qa/bin/grantiva
QA_RUNNER=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_RUNNER_HOME="$QA_RUNNER"
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt9b"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt9b
BIN="$SCRATCH/bin/grantiva"
HOME_COPY="$SCRATCH/runner-home"
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
U1=563907E1-703D-4322-AE5F-FC3B06D03143

if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then
  print -u2 "refusing to overwrite existing attempt9b output or scratch"
  exit 73
fi
mkdir -p "$ROOT/N3-11" "$SCRATCH/bin" "$HOME_COPY"
cp "$QA" "$BIN"
rsync -a "$QA_RUNNER/" "$HOME_COPY/"

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source_binary=$QA"
  echo "bundleless_binary=$BIN"
  shasum -a 256 "$QA" "$BIN"
  echo "runner_home_source=$QA_RUNNER"
  echo "runner_home_copy=$HOME_COPY"
  echo "owned_device_udid=$U1"
  echo "session_id=$GRANTIVA_SESSION_ID"
  echo "setup_runner_home=$GRANTIVA_RUNNER_HOME"
  echo "reset_terminate=xcrun simctl terminate $U1 com.kylebrowning.Landmarks"
  echo "reset_launch=xcrun simctl launch $U1 com.kylebrowning.Landmarks"
  echo "start=GRANTIVA_RUNNER_HOME=$HOME_COPY $BIN runner start --detach --simulator $U1 --bundle-id com.kylebrowning.Landmarks --verbose --json"
  echo "stop=GRANTIVA_RUNNER_HOME=$HOME_COPY $BIN runner stop --json"
} > "$ROOT/N3-11/commands.txt"

xcrun simctl terminate "$U1" com.kylebrowning.Landmarks > "$ROOT/N3-11/reset-terminate.out" 2> "$ROOT/N3-11/reset-terminate.err"
xcrun simctl launch "$U1" com.kylebrowning.Landmarks > "$ROOT/N3-11/reset-launch.out" 2> "$ROOT/N3-11/reset-launch.err"
reset_rc=$?
(cd "$APP" && GRANTIVA_RUNNER_HOME="$HOME_COPY" "$BIN" runner start --detach --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --verbose --json) > "$ROOT/N3-11/start.out" 2> "$ROOT/N3-11/start.err"
start_rc=$?
(cd "$APP" && GRANTIVA_RUNNER_HOME="$HOME_COPY" "$BIN" runner stop --json) > "$ROOT/N3-11/stop.out" 2> "$ROOT/N3-11/stop.err"
stop_rc=$?
start_warning_count=$(grep -c 'Warning: The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable' "$ROOT/N3-11/start.err" || true)
stop_warning_count=$(grep -c 'Warning: The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable' "$ROOT/N3-11/stop.err" || true)
print "reset=$reset_rc start=$start_rc stop=$stop_rc start_missing_bundle_warnings=$start_warning_count stop_missing_bundle_warnings=$stop_warning_count" >> "$ROOT/N3-11/commands.txt"
(( reset_rc == 0 && start_rc == 0 && stop_rc == 0 ))
