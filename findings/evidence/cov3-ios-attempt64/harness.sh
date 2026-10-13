#!/bin/zsh
set -u
setopt NO_BG_NICE
zmodload zsh/datetime
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt64"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt64-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143; U2=1B1102EC-224B-4EF7-937E-370A0DC317DA
CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt64'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo "owned_u1=$U1 owned_u2=$U2"
 echo 'IOS090 exact config U1 capture while U2 observed; IOS086 live keep-alive fallback dump; IOS060 same-UDID refusal; IOS107 exact MCP script.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" "$U2" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); wanted=set(sys.argv[2:]); found={d['udid']:d for ds in j['devices'].values() for d in ds if d['udid'] in wanted}
assert set(found)==wanted, found
assert all(found[u]['state']=='Booted' for u in wanted), found
PY
xcrun simctl io "$U2" screenshot "$ROOT/u2-before.png" > "$ROOT/u2-before.out" 2> "$ROOT/u2-before.err"
xcrun simctl get_app_container "$U2" com.kylebrowning.Landmarks > "$ROOT/u2-app-container-before.txt" 2> "$ROOT/u2-app-container-before.err"
# IOS-090: frozen config selects U1; no device override is needed or supplied.
(cd "$A" && "$GRANTIVA" diff capture --no-build > "$ROOT/ios090.out" 2> "$ROOT/ios090.err"); print -r -- "$?" > "$ROOT/ios090.exit.txt"
mkdir -p "$ROOT/ios090-captures"; cp -R "$A/.grantiva/captures/." "$ROOT/ios090-captures/"
xcrun simctl io "$U2" screenshot "$ROOT/u2-after.png" > "$ROOT/u2-after.out" 2> "$ROOT/u2-after.err"
xcrun simctl get_app_container "$U2" com.kylebrowning.Landmarks > "$ROOT/u2-app-container-after.txt" 2> "$ROOT/u2-app-container-after.err"
# IOS-086/060: no runner start; a foreground keep-alive run owns explicit U1.
print -r -- "$GRANTIVA run --no-build --flow .maestro/01-browse.yaml --simulator $U1 --keep-alive --ready-file $ROOT/keep.ready --report-dir $ROOT/keep-report" > "$ROOT/keep.command.txt"
(cd "$A" && "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --simulator "$U1" --keep-alive --ready-file "$ROOT/keep.ready" --report-dir "$ROOT/keep-report" > "$ROOT/keep.out" 2> "$ROOT/keep.err") &
keeppid=$!; print -r -- "$keeppid" > "$ROOT/keep.pid"
ready=0
for n in {1..300}; do
  ps -p "$keeppid" -o pid= >/dev/null 2>&1 || break
  if [[ -f "$ROOT/keep.ready" ]] && rg -q '"status"[[:space:]]*:[[:space:]]*"passed"' "$ROOT/keep.ready"; then print -r -- "$n" > "$ROOT/keep-ready-poll.txt"; ready=1; break; fi
  sleep 0.2
done
if (( ! ready )); then print -u2 'keep-alive never reached passed hold'; kill -INT "$keeppid" 2>/dev/null; wait "$keeppid" 2>/dev/null; exit 74; fi
(cd "$A" && "$GRANTIVA" runner dump-hierarchy --udid "$U1" > "$ROOT/fallback-dump.xml" 2> "$ROOT/fallback-dump.err"); print -r -- "$?" > "$ROOT/fallback-dump.exit.txt"
t0=$EPOCHREALTIME
(cd "$A" && "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --simulator "$U1" > "$ROOT/second-run.out" 2> "$ROOT/second-run.err"); print -r -- "$?" > "$ROOT/second-run.exit.txt"
t1=$EPOCHREALTIME; printf '%.6f\n' "$((t1-t0))" > "$ROOT/second-run.elapsed.txt"
kill -INT "$keeppid"; wait "$keeppid"; print -r -- "$?" > "$ROOT/keep.exit.txt"
# IOS-107: exact single request on a new proven-ready detached U1 session.
cat > "$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..12}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && rg -q Landmarks $ROOT/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Favorites"},{"wait":1},{"tap_xy":{"x":200,"y":400}}]}},"_save":"exact-script.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"post-script-tree.json"},
 {"method":"tools/list","params":{}}
]
JSON
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios; print -r -- "$?" > "$ROOT/mcp-client.exit.txt"
(cd "$A" && "$GRANTIVA" runner stop --json > "$ROOT/final-stop.out" 2> "$ROOT/final-stop.err"); print -r -- "$?" > "$ROOT/final-stop.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); expected={'ios090':0,'fallback-dump':0,'keep':0,'mcp-client':0,'final-stop':0}; bad=[]
for n,w in expected.items():
 g=int((r/f'{n}.exit.txt').read_text());
 if g!=w: bad.append((n,w,g))
if int((r/'second-run.exit.txt').read_text())==0: bad.append(('second-run-must-refuse',))
print(bad); raise SystemExit(bool(bad))
PY
