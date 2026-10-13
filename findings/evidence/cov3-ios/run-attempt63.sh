#!/bin/zsh
set -u
unsetopt bg_nice
zmodload zsh/datetime
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt63"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt63-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt63'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'Exact B-A05.2/IOS-136 concurrent flow10 recording; K84 validation/overwrite; K85/D2-12 relative+absolute text+JSON paths.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
run() {
 local name="$1"; shift
 print -r -- "$GRANTIVA $*" > "$ROOT/$name.command.txt"
 local t0=$EPOCHREALTIME
 (cd "$A" && "$GRANTIVA" "$@" > "$ROOT/$name.out" 2> "$ROOT/$name.err"); local c=$?
 local t1=$EPOCHREALTIME
 print -r -- "$c" > "$ROOT/$name.exit.txt"; printf '%.6f\n' "$((t1-t0))" > "$ROOT/$name.elapsed.txt"
}
# Establish the exact default video whose bytes the early validation must preserve.
run k84-initial record --platform ios --simulator "$U1" --duration 3 --frames-at 0
shasum -a 256 "$A/.grantiva/recordings/recording.mov" > "$ROOT/k84-before.sha256"
run k84-past record --platform ios --simulator "$U1" --duration 2 --frames-at 5000
shasum -a 256 "$A/.grantiva/recordings/recording.mov" > "$ROOT/k84-after-invalid.sha256"
run k84-equal record --platform ios --simulator "$U1" --duration 2 --frames-at 2000 --output "$ROOT/k84-equal.mov" --json
run x010-json record --platform ios --simulator "$U1" --duration 3 --frames-at 0,1000 --output "$ROOT/x010.mov" --json
# Exact path-style matrix, with unique targets so every raw artifact survives.
run rel-text record --platform ios --simulator "$U1" --duration 2 --frames-at 0,1000 --output rel/text.mov
run rel-json record --platform ios --simulator "$U1" --duration 2 --frames-at 0,1000 --output rel/json.mov --json
run abs-text record --platform ios --simulator "$U1" --duration 2 --frames-at 0,1000 --output "$ROOT/abs-text.mov"
run abs-json record --platform ios --simulator "$U1" --duration 2 --frames-at 0,1000 --output "$ROOT/abs-json.mov" --json
# Flow 10 runs in another shell while the exact 500/1500 ms record is taken.
print -r -- "$GRANTIVA run --no-build --flow .maestro/10-seed-many.yaml --simulator $U1 --report-dir $ROOT/flow10-report" > "$ROOT/flow10.command.txt"
(cd "$A" && "$GRANTIVA" run --no-build --flow .maestro/10-seed-many.yaml --simulator "$U1" --report-dir "$ROOT/flow10-report" > "$ROOT/flow10.out" 2> "$ROOT/flow10.err") &
flowpid=$!; print -r -- "$flowpid" > "$ROOT/flow10.pid"
active=0
for n in {1..300}; do
  ps -p "$flowpid" -o pid= >/dev/null 2>&1 || break
  if rg -n '    [✓✗] scroll:' "$ROOT/flow10.err" > "$ROOT/flow10-active-line.txt" 2>/dev/null; then
    { print -r -- "poll=$n observed_epoch=$EPOCHREALTIME pid=$flowpid"; cat "$ROOT/flow10-active-line.txt"; } > "$ROOT/flow10-active-proof.txt"
    active=1; break
  fi
  sleep 0.1
done
if (( ! active )); then print -u2 'flow10 never reached a completed live scroll while its PID was alive'; kill -INT "$flowpid" 2>/dev/null; wait "$flowpid" 2>/dev/null; exit 74; fi
run concurrent-flow10 record --platform ios --simulator "$U1" --duration 3 --frames-at 500,1500 --output "$ROOT/concurrent-flow10.mov" --json
wait "$flowpid"; print -r -- "$?" > "$ROOT/flow10.exit.txt"
mkdir -p "$ROOT/project-recordings"
[[ ! -d "$A/rel" ]] || cp -R "$A/rel" "$ROOT/project-recordings/"
[[ ! -d "$A/.grantiva/recordings" ]] || cp -R "$A/.grantiva/recordings" "$ROOT/project-recordings/default-recordings"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1])
expected={'k84-initial':0,'k84-past':64,'x010-json':0,'rel-text':0,'rel-json':0,'abs-text':0,'abs-json':0,'concurrent-flow10':0,'flow10':0}
bad=[]
for n,want in expected.items():
    got=int((r/f'{n}.exit.txt').read_text())
    if got != want: bad.append({'case':n,'want':want,'got':got})
equal=int((r/'k84-equal.exit.txt').read_text())
if equal == 64: bad.append({'case':'k84-equal-rejected-by-validation','got':equal})
if (r/'k84-before.sha256').read_text().split()[0] != (r/'k84-after-invalid.sha256').read_text().split()[0]: bad.append({'case':'k84-invalid-overwrote-default'})
print(bad)
raise SystemExit(bool(bad))
PY
