#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
ROOT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
U1=563907E1-703D-4322-AE5F-FC3B06D03143
capture() {
  local row="$1" label="$2" cwd="$3"; shift 3
  mkdir -p "$ROOT/$row"
  { uptime; print -r -- "cwd: $cwd"; printf 'command:'; printf ' %q' "$@"; printf '\n'; } >> "$ROOT/$row/commands.txt"
  local start=$(date +%s)
  (cd "$cwd" && "$@") >"$ROOT/$row/$label.out" 2>"$ROOT/$row/$label.err"
  local code=$?
  print -r -- "exit=$code elapsed=$(( $(date +%s) - start ))s output=$label.out stderr=$label.err" >> "$ROOT/$row/commands.txt"
  return 0
}
capture B3-L43 start "$APP" "$GRANTIVA" runner start --detach --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --json
capture B3-L43 session "$APP" jq -S . .grantiva/session.json
capture N3-07 hierarchy "$APP" "$GRANTIVA" hierarchy --udid "$U1" --format json
capture N3-07 dump "$APP" "$GRANTIVA" runner dump-hierarchy --udid "$U1" --format json
capture B3-L13 stop "$APP" "$GRANTIVA" runner stop --json
