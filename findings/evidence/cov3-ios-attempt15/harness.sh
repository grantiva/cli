#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt15"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"; SCRATCH="$BASE/attempt15-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
READYDIR=/private/tmp/cov3-ios-attempt15-missing
if [[ -e "$ROOT" || -e "$SCRATCH" || -e "$READYDIR" ]]; then print -u2 'refusing overwrite attempt15 output/scratch/ready path'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"; cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
runone() { local row=$1; shift; mkdir -p "$ROOT/$row"; print -r -- "command: $GRANTIVA $*" >> "$ROOT/commands.txt"; "$GRANTIVA" "$@" > "$ROOT/$row/stdout" 2> "$ROOT/$row/stderr"; local rc=$?; print -r -- "exit=$rc row=$row" >> "$ROOT/commands.txt"; }
# Empty-suite fixture: expected to fail before simulator/build work. Explicit U1 is the campaign safety equivalent.
mkdir -p "$SCRATCH/empty-suite"; cat > "$SCRATCH/empty-suite/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
flows: []
screens: []
YAML
cp "$SCRATCH/empty-suite/grantiva.yml" "$ROOT/IOS-031-config.yml"
cd "$SCRATCH/empty-suite"
runone IOS-031 run --simulator "$U1" --report-dir out --ready-file out.ready
[[ -e out.ready ]] && cp out.ready "$ROOT/IOS-031/out.ready"
find . -maxdepth 3 -type f -print | sort > "$ROOT/IOS-031/files.txt"
cd "$SCRATCH"
# Ready-file lifecycle using the exact passing stock flow.
print '{"status":"passed","finishedAt":"2000-01-01T00:00:00Z"}\n' > stale.ready
cp stale.ready "$ROOT/IOS-032/stale.before" 2>/dev/null || { mkdir -p "$ROOT/IOS-032"; cp stale.ready "$ROOT/IOS-032/stale.before"; }
runone IOS-032 run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --ready-file stale.ready
cp stale.ready "$ROOT/IOS-032/stale.after"
# Uncreatable absolute path must fail before build/device action.
runone IOS-033 run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --ready-file /nonexistent-cov/sub/x.ready
# Creatable missing parent is created and receives the verdict.
runone IOS-034 run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --ready-file "$READYDIR/x.ready"
cp "$READYDIR/x.ready" "$ROOT/IOS-034/x.ready"
# Crash-on-launch with ready-file and preserved report/failure capture.
runone IOS-039 run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --env LANDMARKS_CRASH_ON_LAUNCH=1 --ready-file crash.ready --report-dir "$ROOT/IOS-039/report"
cp crash.ready "$ROOT/IOS-039/crash.ready"
