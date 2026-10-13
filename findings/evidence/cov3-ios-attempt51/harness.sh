#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt51"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt51-ios"; EMPTY="$BASE/attempt51-no-config"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" || -e "$EMPTY" ]]; then print -u2 'refusing overwrite attempt51'; exit 73; fi
mkdir -p "$ROOT" "$EMPTY/.maestro/coverage"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cp "$SRC/.maestro/coverage/16-setpermissions.yaml" "$EMPTY/.maestro/coverage/"
cp "$EMPTY/.maestro/coverage/16-setpermissions.yaml" "$ROOT/"
runone() {
 local cwd=$1 n=$2; shift 2
 print -r -- "cwd=$cwd" > "$ROOT/$n.command.txt"; print -r -- "$*" >> "$ROOT/$n.command.txt"
 (cd "$cwd" && "$@") > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone "$EMPTY" no-config-header "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/16-setpermissions.yaml --report-dir "$ROOT/no-config-report"
runone "$SCRATCH" start "$GRANTIVA" runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
runone "$SCRATCH" launch xcrun simctl launch "$U1" com.kylebrowning.Landmarks
integer ready=0
for i in {1..12}; do
 runone "$SCRATCH" "readiness-$i" "$GRANTIVA" hierarchy --udid "$U1" --format json
 if [[ $(cat "$ROOT/readiness-$i.exit.txt") == 0 ]] && rg -q 'Landmarks' "$ROOT/readiness-$i.out"; then ready=1; break; fi
 sleep 1
done
if (( ! ready )); then print -u2 'readiness failed'; runone "$SCRATCH" cleanup-stop "$GRANTIVA" runner stop --json; exit 74; fi
runone "$SCRATCH" hierarchy-json "$GRANTIVA" hierarchy --udid "$U1" --json
runone "$SCRATCH" hierarchy-conflict "$GRANTIVA" hierarchy --udid "$U1" --json --format xml
runone "$SCRATCH" dump-json "$GRANTIVA" runner dump-hierarchy --json
runone "$SCRATCH" dump-conflict "$GRANTIVA" runner dump-hierarchy --json --format xml
runone "$SCRATCH" stop "$GRANTIVA" runner stop --json
(cd "$SCRATCH" && "$GRANTIVA" runner stop 2> /dev/null) > "$ROOT/stop-suppressed.out"
print -r -- "$?" > "$ROOT/stop-suppressed.exit.txt"
runone "$SCRATCH" stop-json-none "$GRANTIVA" runner stop --json
runone "$SCRATCH" record-mp4 "$GRANTIVA" record --simulator "$U1" --duration 1 --output "$ROOT/rejected.mp4"
runone "$SCRATCH" record-mov "$GRANTIVA" record --simulator "$U1" --duration 1 --output "$ROOT/accepted.mov"
file "$ROOT/accepted.mov" > "$ROOT/accepted.file.txt" 2> "$ROOT/accepted.file.err"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
