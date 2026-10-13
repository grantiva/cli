#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt12"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"
SCRATCH="$BASE/attempt12-ios"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt12'; exit 73; fi
mkdir -p "$ROOT"; rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"
cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
runone() {
 local name=$1; shift; mkdir -p "$ROOT/$name"
 print -r -- "command: $GRANTIVA $*" >> "$ROOT/commands.txt"
 "$GRANTIVA" "$@" > "$ROOT/$name/stdout" 2> "$ROOT/$name/stderr"; local rc=$?
 print -r -- "exit=$rc row=$name" >> "$ROOT/commands.txt"
}
# Exact relative report-directory variants from the scratch project cwd.
runone IOS-070 run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir out-pass
runone IOS-071 run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --report-dir out-fail
# Identical command inputs for the three output modes.
runone IOS-152-plain run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml
runone IOS-152-quiet run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --quiet
runone IOS-152-verbose run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --verbose
runone IOS-152-quiet-fail run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --quiet
mkdir -p "$ROOT/IOS-070/report" "$ROOT/IOS-071/report"
cp -R out-pass/. "$ROOT/IOS-070/report/"
cp -R out-fail/. "$ROOT/IOS-071/report/"
shasum -a 256 "$ROOT/IOS-152-plain/stdout" "$ROOT/IOS-152-quiet/stdout" "$ROOT/IOS-152-verbose/stdout" > "$ROOT/IOS-152-stdout-sha256.txt"
# Preserve exact staged source and confirm relative output did not fall back to the default capture directory.
find out-pass out-fail -type f -print | sort > "$ROOT/report-files.txt"
find .grantiva -type f -print 2>/dev/null | sort > "$ROOT/default-grantiva-files.txt" || true
exit 0
