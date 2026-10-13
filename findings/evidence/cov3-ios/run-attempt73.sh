#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
unset GRANTIVA_API_KEY GRANTIVA_SESSION_ID
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt73"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt73-ios"; NAME='cov3-ios-73-free iPhone 17'
APP="$BASE/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt73'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
xcrun simctl list devices -j > "$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('name')==sys.argv[2] for xs in d['devices'].values() for x in xs)
PY
U=''
cleanup() {
  [[ -n "$U" ]] || return
  xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err" || return
  python3 - "$ROOT/cleanup-before.json" "$NAME" "$U" <<'PY' || return
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('name')==sys.argv[2] and x.get('udid')==sys.argv[3]]
raise SystemExit(0 if len(hits)==1 else 1)
PY
  xcrun simctl delete "$U" > "$ROOT/cleanup.out" 2> "$ROOT/cleanup.err" || true
  xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err" || true
}
trap cleanup EXIT
U=$(xcrun simctl create "$NAME" 'iPhone 17' 'iOS 26.0') || exit 75
python3 - "$U" <<'PY' || exit 76
import re,sys
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',sys.argv[1])
PY
print -r -- "$U" > "$ROOT/owned.udid"
cd "$A"
"$GRANTIVA" simulator teardown --udid "$U" --force --json > "$ROOT/free-json.out" 2> "$ROOT/free-json.err"; print -r -- "$?" > "$ROOT/free-json.exit.txt"
"$GRANTIVA" simulator teardown --udid "$U" --force > "$ROOT/free-text.out" 2> "$ROOT/free-text.err"; print -r -- "$?" > "$ROOT/free-text.exit.txt"
"$GRANTIVA" run --app-file "$APP" --simulator "$U" --flow .maestro/01-browse.yaml --report-dir "$ROOT/run-report" > "$ROOT/run.out" 2> "$ROOT/run.err"; print -r -- "$?" > "$ROOT/run.exit.txt"
find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$U" -type d -print > "$ROOT/homes-after-run.txt"
"$GRANTIVA" simulator teardown --udid "$U" --json > "$ROOT/nonforce.out" 2> "$ROOT/nonforce.err"; print -r -- "$?" > "$ROOT/nonforce.exit.txt"
find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$U" -type d -print > "$ROOT/homes-after-nonforce.txt"
xcrun simctl list devices -j > "$ROOT/after-nonforce.json"
export GRANTIVA_SESSION_ID=cov3-ios-a73
"$GRANTIVA" runner start --detach --bundle-id com.kylebrowning.Landmarks --simulator "$U" --platform ios --json > "$ROOT/start.out" 2> "$ROOT/start.err"; print -r -- "$?" > "$ROOT/start.exit.txt"
for n in {1..120}; do
  [[ -f .grantiva/session.json ]] && jq -e --arg u "$U" '.state=="ready" and .udid==$u and (.port>0)' .grantiva/session.json > /dev/null 2>&1 && break
  sleep .25
done
cp .grantiva/session.json "$ROOT/session-before-teardown.json" || exit 77
"$GRANTIVA" runner dump-hierarchy --udid "$U" > "$ROOT/hierarchy.out" 2> "$ROOT/hierarchy.err"; print -r -- "$?" > "$ROOT/hierarchy.exit.txt"
"$GRANTIVA" simulator teardown --udid "$U" --force --json > "$ROOT/live-teardown.out" 2> "$ROOT/live-teardown.err"; print -r -- "$?" > "$ROOT/live-teardown.exit.txt"
[[ -e .grantiva/session.json ]] && print present > "$ROOT/session-after.txt" || print absent > "$ROOT/session-after.txt"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print > "$ROOT/global-sessions-after.txt" 2> "$ROOT/global-sessions-after.err" || true
ps -axo pid,ppid,pgid,etime,command > "$ROOT/ps-after.txt"
xcrun simctl list devices -j > "$ROOT/final.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/completed.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
[[ $(<"$ROOT/free-json.exit.txt") == 0 && $(<"$ROOT/free-text.exit.txt") == 0 && $(<"$ROOT/run.exit.txt") == 0 && $(<"$ROOT/nonforce.exit.txt") == 0 && $(<"$ROOT/start.exit.txt") == 0 && $(<"$ROOT/hierarchy.exit.txt") == 0 && $(<"$ROOT/live-teardown.exit.txt") == 0 && $(<"$ROOT/session-after.txt") == absent ]]
