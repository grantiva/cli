#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt72b"
SID=cov3-ios-a72
if [[ -e "$ROOT" ]]; then print -u2 'refusing overwrite attempt72b'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; : > "$ROOT/owned.tsv"
cleanup() {
  xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err" || return
  while IFS=$'\t' read -r name uuid; do
    [[ -n "$uuid" ]] || continue
    python3 - "$ROOT/cleanup-before.json" "$name" "$uuid" <<'PY' || continue
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('name')==sys.argv[2] and x.get('udid')==sys.argv[3]]
raise SystemExit(0 if len(hits)==1 else 1)
PY
    xcrun simctl delete "$uuid" >> "$ROOT/cleanup.out" 2>> "$ROOT/cleanup.err" || true
  done < "$ROOT/owned.tsv"
  xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err" || true
}
trap cleanup EXIT
xcrun simctl list devices -j > "$ROOT/before.json"
python3 - "$ROOT/before.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); names={x['name'] for xs in d['devices'].values() for x in xs}
wanted={f'cov3-ios-72-race-{i} iPhone 17' for i in range(1,6)}
assert not names&wanted, names&wanted
PY
[[ $? == 0 ]] || exit 74
"$GRANTIVA" simulator sessions --json > "$ROOT/sessions-preflight.json" 2> "$ROOT/sessions-preflight.err" || exit 74
if jq -e --arg sid "$SID" '.[] | select(.sessionId==$sid)' "$ROOT/sessions-preflight.json" >/dev/null; then print -u2 'refusing pre-existing session'; exit 74; fi
export GRANTIVA_SESSION_ID="$SID"
for i in 1 2 3 4 5; do
  name="cov3-ios-72-race-$i iPhone 17"
  "$GRANTIVA" simulator ensure --name "$name" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/$i-a.out" 2> "$ROOT/$i-a.err" & a=$!
  "$GRANTIVA" simulator ensure --name "$name" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/$i-b.out" 2> "$ROOT/$i-b.err" & b=$!
  wait $a; ra=$?; wait $b; rb=$?; print -r -- "$ra" > "$ROOT/$i-a.exit.txt"; print -r -- "$rb" > "$ROOT/$i-b.exit.txt"
  [[ $ra == 0 && $rb == 0 ]] || exit 75
  ua=$(jq -r .udid "$ROOT/$i-a.out"); ub=$(jq -r .udid "$ROOT/$i-b.out")
  printf '%s\t%s\n' "$name" "$ua" >> "$ROOT/owned.tsv"
  [[ "$ub" == "$ua" ]] || printf '%s\t%s\n' "$name" "$ub" >> "$ROOT/owned.tsv"
  [[ "$ua" == "$ub" ]] || exit 76
  python3 - "$ua" <<'PY' || exit 76
import re,sys
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',sys.argv[1])
PY
  xcrun simctl list devices -j > "$ROOT/$i-after-ensure.json"
  python3 - "$ROOT/$i-after-ensure.json" "$name" "$ua" <<'PY' || exit 77
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('name')==sys.argv[2]]
assert len(hits)==1 and hits[0]['udid']==sys.argv[3], hits
PY
  "$GRANTIVA" simulator sessions --json > "$ROOT/$i-sessions.json" 2> "$ROOT/$i-sessions.err" || exit 78
  cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/$i-created.json"
  "$GRANTIVA" simulator teardown --session-id "$SID" --json > "$ROOT/$i-teardown.json" 2> "$ROOT/$i-teardown.err" || exit 79
  xcrun simctl list devices -j > "$ROOT/$i-after-teardown.json"
  python3 - "$ROOT/$i-after-teardown.json" "$ua" <<'PY' || exit 80
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('udid')==sys.argv[2] for xs in d['devices'].values() for x in xs)
PY
done
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/completed.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
