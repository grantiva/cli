#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt13"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"
SCRATCH="$BASE/attempt13-ios"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt13'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"; cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
runone() {
 local row=$1; shift; mkdir -p "$ROOT/$row"; print -r -- "command: $GRANTIVA $*" >> "$ROOT/commands.txt"
 "$GRANTIVA" "$@" > "$ROOT/$row/stdout" 2> "$ROOT/$row/stderr"; local rc=$?; print -r -- "exit=$rc row=$row" >> "$ROOT/commands.txt"
}
runone IOS-079 record --simulator "$U1" --duration 3
cp .grantiva/recordings/recording.mov "$ROOT/IOS-079/recording.mov"
mkdir -p "$ROOT/IOS-080/cov rec"
runone IOS-080 record --simulator "$U1" --duration 2 --output "$ROOT/IOS-080/cov rec/a.mov"
runone IOS-081 record --simulator "$U1" --duration 3 --frames-at 0,150,300,2900 --output "$ROOT/IOS-081/frames.mov"
runone IOS-082 record --simulator "$U1" --duration 2 --frames-at 5000 --output "$ROOT/IOS-082/past.mov"
runone IOS-083 record --simulator "$U1" --duration 3 --frames-at 0,1000 --json --output "$ROOT/IOS-083/json.mov"
mkdir -p "$ROOT/IOS-137"; print -r -- "command: $GRANTIVA record --simulator $U1 --duration 2 --output $ROOT/IOS-137/quiet.mov 2>/dev/null" >> "$ROOT/commands.txt"
"$GRANTIVA" record --simulator "$U1" --duration 2 --output "$ROOT/IOS-137/quiet.mov" > "$ROOT/IOS-137/stdout" 2>/dev/null; print -r -- "exit=$? row=IOS-137" >> "$ROOT/commands.txt"
COMMON="$ROOT/IOS-154/common.mov"; mkdir -p "$ROOT/IOS-154"
for mode in plain quiet verbose; do
 args=(record --simulator "$U1" --duration 2 --json --output "$COMMON"); [[ $mode == quiet ]] && args+=(--quiet); [[ $mode == verbose ]] && args+=(--verbose)
 print -r -- "command[$mode]: $GRANTIVA ${args[*]}" >> "$ROOT/commands.txt"; "$GRANTIVA" "${args[@]}" > "$ROOT/IOS-154/$mode.stdout" 2> "$ROOT/IOS-154/$mode.stderr"; print -r -- "exit=$? row=IOS-154-$mode" >> "$ROOT/commands.txt"
done
shasum -a 256 "$ROOT/IOS-154/"*.stdout > "$ROOT/IOS-154/stdout-sha256.txt"
for mov in "$ROOT"/**/*.mov(N); do ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$mov" > "$mov.duration.txt" 2> "$mov.ffprobe.err"; done
find "$ROOT/IOS-081" -type f -print | sort > "$ROOT/IOS-081/files.txt"
find "$ROOT/IOS-083" -type f -print | sort > "$ROOT/IOS-083/files.txt"
