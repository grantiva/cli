#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt68"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt68-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
PASS=.maestro/01-browse.yaml; FAIL=.maestro/coverage/02-exact-negative.yaml
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt68'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'D2-19 complete passing/failing quiet, JSON, JSON+verbose matrix plus plain no-report notice.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
run() { local n="$1"; shift; print -r -- "$GRANTIVA $*" > "$ROOT/$n.command.txt"; (cd "$A" && "$GRANTIVA" "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"); print -r -- "$?" > "$ROOT/$n.exit.txt"; }
run pass-quiet run --no-build --flow "$PASS" --simulator "$U1" --platform ios --quiet --report-dir "$ROOT/pass-quiet-report"
run fail-quiet run --no-build --flow "$FAIL" --simulator "$U1" --platform ios --quiet --report-dir "$ROOT/fail-quiet-report"
run pass-json run --no-build --flow "$PASS" --simulator "$U1" --platform ios --json --report-dir "$ROOT/pass-json-report"
run fail-json run --no-build --flow "$FAIL" --simulator "$U1" --platform ios --json --report-dir "$ROOT/fail-json-report"
run pass-json-verbose run --no-build --flow "$PASS" --simulator "$U1" --platform ios --json --verbose --report-dir "$ROOT/pass-json-verbose-report"
run fail-json-verbose run --no-build --flow "$FAIL" --simulator "$U1" --platform ios --json --verbose --report-dir "$ROOT/fail-json-verbose-report"
run pass-plain-no-report run --no-build --flow "$PASS" --simulator "$U1" --platform ios
run fail-plain-no-report run --no-build --flow "$FAIL" --simulator "$U1" --platform ios
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); bad=[]
for n in ['pass-quiet','pass-json','pass-json-verbose','pass-plain-no-report']:
 if int((r/f'{n}.exit.txt').read_text()) != 0: bad.append((n,'pass'))
for n in ['fail-quiet','fail-json','fail-json-verbose','fail-plain-no-report']:
 if int((r/f'{n}.exit.txt').read_text()) == 0: bad.append((n,'must fail'))
print(bad); raise SystemExit(bool(bad))
PY
