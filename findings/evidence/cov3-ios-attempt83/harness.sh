#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt83"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
export GRANTIVA_RUNNER_HOME="$BASE/attempt83-runner-home"
export GRANTIVA_SESSION_ID=cov3-ios-a83
NAME='cov3-ios-83-session iPhone 17'
if [[ -e "$ROOT" || -e "$GRANTIVA_RUNNER_HOME" ]]; then print -u2 'refusing overwrite attempt83'; exit 73; fi
mkdir -p "$ROOT" "$GRANTIVA_RUNNER_HOME"; cp "$0" "$ROOT/harness.sh"; : > "$ROOT/owned.tsv"
cleanup() {
 xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err" || return
 while IFS=$'\t' read -r name uuid; do
  [[ -n "$uuid" ]] || continue
  python3 - "$ROOT/cleanup-before.json" "$name" "$uuid" <<'PY' || continue
import json,sys
d=json.load(open(sys.argv[1])); h=[x for xs in d['devices'].values() for x in xs if x.get('name')==sys.argv[2] and x.get('udid')==sys.argv[3]]
raise SystemExit(0 if len(h)==1 else 1)
PY
  xcrun simctl delete "$uuid" >> "$ROOT/cleanup.out" 2>> "$ROOT/cleanup.err" || true
 done < "$ROOT/owned.tsv"
 xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err" || true
}
trap cleanup EXIT
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "scratch_runner_home=$GRANTIVA_RUNNER_HOME"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('name')==sys.argv[2] for xs in d['devices'].values() for x in xs)
PY
"$GRANTIVA" simulator ensure --name "$NAME" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/ensure.out" 2> "$ROOT/ensure.err" || exit 75
U=$(jq -r .udid "$ROOT/ensure.out"); printf '%s\t%s\n' "$NAME" "$U" >> "$ROOT/owned.tsv"
"$GRANTIVA" simulator sessions --json > "$ROOT/sessions.out" 2> "$ROOT/sessions.err"; print -r -- "$?" > "$ROOT/sessions.exit.txt"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created.json"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/sessions.json" "$ROOT/sessions-ledger.json"
python3 - "$ROOT/sessions.out" "$ROOT/created.json" "$ROOT/sessions-ledger.json" "$NAME" "$U" <<'PY' || exit 76
import datetime,json,re,sys
shown,created,ledger=map(lambda p:json.load(open(p)),sys.argv[1:4]); name,uuid=sys.argv[4:]
assert len(shown)==len(created)==len(ledger)==1
for row in (shown[0],created[0],ledger[0]): assert row['udid']==uuid and row['name']==name
stamp=shown[0]['acquiredAt']; assert stamp.endswith('Z'); datetime.datetime.fromisoformat(stamp.replace('Z','+00:00'))
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',uuid)
PY
"$GRANTIVA" simulator teardown --session-id "$GRANTIVA_SESSION_ID" --json > "$ROOT/teardown.out" 2> "$ROOT/teardown.err" || exit 77
xcrun simctl list devices -j > "$ROOT/final.json"
python3 - "$ROOT/final.json" "$U" <<'PY' || exit 78
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('udid')==sys.argv[2] for xs in d['devices'].values() for x in xs)
PY
cleanup
trap - EXIT
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
