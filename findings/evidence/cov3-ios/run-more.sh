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
  local row="$1" label="$2" cwd="$3"
  shift 3
  mkdir -p "$ROOT/$row"
  {
    uptime
    print -r -- "cwd: $cwd"
    printf 'command:'
    printf ' %q' "$@"
    printf '\n'
  } >> "$ROOT/$row/commands.txt"
  local start=$(date +%s)
  (cd "$cwd" && "$@") >"$ROOT/$row/$label.out" 2>"$ROOT/$row/$label.err"
  local code=$?
  local elapsed=$(( $(date +%s) - start ))
  print -r -- "exit=$code elapsed=${elapsed}s output=$label.out stderr=$label.err" >> "$ROOT/$row/commands.txt"
  return 0
}

capture B3-L10 plain "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml
capture B3-L10 quiet "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --quiet
capture B3-L10 json "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --json
capture B3-L19 text "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/14-runflow.yaml
capture B3-L19 json "$APP" "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/14-runflow.yaml --json
capture B3-L21 doctor "$APP" "$GRANTIVA" doctor
capture B3-L21 doctor-json "$APP" "$GRANTIVA" doctor --json
capture B3-L21 incompatible "$APP" "$GRANTIVA" simulator ensure --name cov3-ios-26 --runtime 'iOS 27.0'
capture N3-05 ensure "$APP" "$GRANTIVA" simulator ensure --name cov3-ios-26
capture B3-L39 launched "$APP" "$GRANTIVA" build install --simulator "$U1" --scheme 'Landmarks (UI Testing)' --json
capture B3-L39 installed "$APP" "$GRANTIVA" build install --simulator "$U1" --scheme 'Landmarks (UI Testing)' --no-launch --json
capture B3-L39 skipped "$APP" "$GRANTIVA" build install --simulator "$U1" --scheme 'Landmarks (UI Testing)' --no-build --no-launch --json
capture B3-L60 record3 "$APP" "$GRANTIVA" record --simulator "$U1" --duration 3 --output "$ROOT/B3-L60/a.mov"
capture B3-L60 ffprobe "$APP" ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$ROOT/B3-L60/a.mov"
capture N3-14 qa-ledger "$APP" shasum -a 256 /Users/kyle/.grantiva-qa/runner/simulator-capacity/created.json
capture N3-14 owner-ledger "$APP" shasum -a 256 /Users/kyle/.grantiva/runner/simulator-capacity/created.json
capture N3-14 sessions "$APP" "$GRANTIVA" simulator sessions --json
