#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt14"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"; SCRATCH="$BASE/attempt14-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt14'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"; cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
runone() { local name=$1; shift; mkdir -p "$ROOT/$name"; print -r -- "command: $GRANTIVA $*" >> "$ROOT/commands.txt"; "$GRANTIVA" "$@" > "$ROOT/$name/stdout" 2> "$ROOT/$name/stderr"; local rc=$?; print -r -- "exit=$rc row=$name" >> "$ROOT/commands.txt"; }
# Exact detached text workflow: start, all documented hierarchy forms, stop.
runone IOS-084 runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
cp .grantiva/session.json "$ROOT/IOS-084/session.json"
PORT=$(jq -r '.wdaPort // .port' .grantiva/session.json); print -r -- "recorded_wda_port=$PORT" >> "$ROOT/commands.txt"
runone IOS-085-tree runner dump-hierarchy --format tree
runone IOS-085-json runner dump-hierarchy -f json
runone IOS-085-xml runner dump-hierarchy --format xml
runone IOS-085-port runner dump-hierarchy -p "$PORT" -f tree
runone IOS-140-json runner dump-hierarchy --format json
runone IOS-087 runner stop
find .grantiva -maxdepth 2 -type f -print | sort > "$ROOT/IOS-087/post-stop-files.txt" 2>/dev/null || true
# Exact JSON start/stop pair in a fresh session.
runone IOS-138-start runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
cp .grantiva/session.json "$ROOT/IOS-138-start/session.json"
runone IOS-138-stop runner stop --json
find .grantiva -maxdepth 2 -type f -print | sort > "$ROOT/IOS-138-stop/post-stop-files.txt" 2>/dev/null || true
