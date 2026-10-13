#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt10"
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
U1=563907E1-703D-4322-AE5F-FC3B06D03143
ROWS=(IOS-065 IOS-066 IOS-067 IOS-070 IOS-071 IOS-074 IOS-152 N-17 X-001 X-002 X-003 X-004 B2-K05 B2-K18 B2-K81 B2-K82-a B2-K93 D2-18)

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT"
for row in $ROWS; do mkdir -p "$ROOT/$row"; done

capture() {
  local label=$1
  shift
  { printf 'command:'; printf ' %q' "$@"; printf '\n'; } >> "$ROOT/commands.txt"
  (cd "$APP" && "$@") > "$ROOT/$label.out" 2> "$ROOT/$label.err"
  local rc=$?
  print "exit=$rc output=$label.out stderr=$label.err" >> "$ROOT/commands.txt"
  return 0
}

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"

xcrun simctl terminate "$U1" com.kylebrowning.Landmarks > "$ROOT/reset-terminate.out" 2> "$ROOT/reset-terminate.err"
xcrun simctl launch "$U1" com.kylebrowning.Landmarks > "$ROOT/reset-launch.out" 2> "$ROOT/reset-launch.err"

capture pass-plain "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir "$ROOT/pass-report" --ready-file "$ROOT/pass.ready"
capture pass-quiet "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --quiet
capture pass-verbose "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --verbose
capture pass-json "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json --report-dir "$ROOT/pass-json-report"
capture full "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --snapshot full --report-dir "$ROOT/full-report"
capture fail-default "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --report-dir "$ROOT/fail-report" --ready-file "$ROOT/fail.ready"
capture fail-trailing "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing --report-dir "$ROOT/trailing-report"
capture fail-json "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --json --report-dir "$ROOT/fail-json-report"
capture fail-quiet "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --quiet
capture fail-ephemeral "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml

for row in $ROWS; do
  cp "$ROOT/commands.txt" "$ROOT/$row/commands.txt"
done

python3 - "$ROOT" > "$ROOT/stdout-hashes.txt" <<'PY'
import hashlib, pathlib, sys
r=pathlib.Path(sys.argv[1])
for n in ('pass-plain.out','pass-quiet.out','pass-verbose.out'):
 p=r/n
 print(n, hashlib.sha256(p.read_bytes()).hexdigest())
PY
