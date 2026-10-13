#!/bin/zsh
set -euo pipefail
GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt117"
[[ ! -e "$ROOT" && -d "$GRANTIVA_RUNNER_HOME" ]] || exit 73
mkdir -p "$ROOT"
cp "$0" "$ROOT/harness.sh"
{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  print -r -- 'join_stock_evidence=findings/evidence/cov3-ios-attempt107'
  print -r -- 'join_teardown_evidence=findings/evidence/cov3-ios-attempt115b'
  print -r -- "command=find $GRANTIVA_RUNNER_HOME -name dlrun-* -print"
} >"$ROOT/commands.txt"
find "$GRANTIVA_RUNNER_HOME" -name 'dlrun-*' -print >"$ROOT/dlrun-paths.txt"
[[ ! -s "$ROOT/dlrun-paths.txt" ]] || exit 75
find "$GRANTIVA_RUNNER_HOME" -maxdepth 3 -type d -print | sort >"$ROOT/runner-home-dirs.txt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
