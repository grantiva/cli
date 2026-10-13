#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt52"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt52-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt52'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SCRATCH/.maestro/09-seed-empty.yaml" "$SCRATCH/.maestro/08-caching.yaml" "$ROOT/"
runone() {
 local n=$1; shift
 print -r -- "$*" > "$ROOT/$n.command.txt"
 "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"
}
cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone seed-empty "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/09-seed-empty.yaml --report-dir "$ROOT/seed-empty-report"
runone logs-default "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs --report-dir "$ROOT/logs-default-report"
runone logs-verbose "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs --verbose --report-dir "$ROOT/logs-verbose-report"
rg -n 'getpwuid_r|Filtering the log data|\[log\]' "$ROOT/logs-default.err" > "$ROOT/logs-default-filter-audit.txt" || true
rg -n 'predicate|process ==|processImagePath|CFBundleExecutable|log stream' "$ROOT/logs-verbose.err" > "$ROOT/logs-verbose-predicate-audit.txt" || true
rg -n '/var/folders|sourceFile|09-seed-empty' "$ROOT/seed-empty-report" > "$ROOT/seed-empty-path-audit.txt" || true
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
