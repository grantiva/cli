#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt77"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
export GRANTIVA_RUNNER_HOME="$BASE/attempt77-runner-home"
export GRANTIVA_SESSION_ID=cov3-ios-a77
N1='cov3-ios-77-shutdown iPhone 17'; N2='cov3-ios-77-active iPhone 17'
if [[ -e "$ROOT" || -e "$GRANTIVA_RUNNER_HOME" ]]; then print -u2 'refusing overwrite attempt77'; exit 73; fi
mkdir -p "$ROOT" "$GRANTIVA_RUNNER_HOME"; cp "$0" "$ROOT/harness.sh"; : > "$ROOT/owned.tsv"
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
python3 - "$ROOT/before.json" "$N1" "$N2" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); names={x['name'] for xs in d['devices'].values() for x in xs}
assert sys.argv[2] not in names and sys.argv[3] not in names
PY
for ledger in /Users/kyle/.grantiva-qa/runner/simulator-capacity/created.json /Users/kyle/.grantiva/simulator-capacity/created.json; do
  key=$(print -r -- "$ledger" | shasum -a 256 | cut -c1-12)
  [[ -f "$ledger" ]] && shasum -a 256 "$ledger" > "$ROOT/global-$key-before.sha256" || print absent > "$ROOT/global-$key-before.sha256"
done
"$GRANTIVA" simulator ensure --name "$N1" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/ensure-shutdown.out" 2> "$ROOT/ensure-shutdown.err" || exit 75
U1=$(jq -r .udid "$ROOT/ensure-shutdown.out"); printf '%s\t%s\n' "$N1" "$U1" >> "$ROOT/owned.tsv"
"$GRANTIVA" simulator ensure --name "$N2" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/ensure-active.out" 2> "$ROOT/ensure-active.err" || exit 76
U2=$(jq -r .udid "$ROOT/ensure-active.out"); printf '%s\t%s\n' "$N2" "$U2" >> "$ROOT/owned.tsv"
python3 - "$U1" "$U2" <<'PY' || exit 76
import re,sys
for value in sys.argv[1:]: assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',value)
assert sys.argv[1] != sys.argv[2]
PY
xcrun simctl list devices -j > "$ROOT/after-ensures.json"
python3 - "$ROOT/after-ensures.json" "$N1" "$U1" "$N2" "$U2" <<'PY' || exit 76
import json,sys
d=json.load(open(sys.argv[1])); pairs={(x['name'],x['udid']) for xs in d['devices'].values() for x in xs}
assert (sys.argv[2],sys.argv[3]) in pairs and (sys.argv[4],sys.argv[5]) in pairs
PY
xcrun simctl shutdown "$U1" > "$ROOT/shutdown.out" 2> "$ROOT/shutdown.err" || exit 77
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created-before.json"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/sessions.json" "$ROOT/sessions-before.json"
python3 - "$ROOT/created-before.json" "$ROOT/sessions-before.json" "$U1" "$U2" <<'PY' || exit 78
import json,sys
c=json.load(open(sys.argv[1])); s=json.load(open(sys.argv[2])); wanted={sys.argv[3],sys.argv[4]}
assert {x['udid'] for x in c}==wanted
assert {x['udid'] for x in s}==wanted
assert next(x for x in s if x['udid']==sys.argv[4])['state']=='active'
PY
xcrun simctl list devices -j > "$ROOT/before-cleanup.json"
"$GRANTIVA" simulator cleanup --json > "$ROOT/cleanup-command.out" 2> "$ROOT/cleanup-command.err"; print -r -- "$?" > "$ROOT/cleanup-command.exit.txt"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created-after.json"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/sessions.json" "$ROOT/sessions-after.json"
xcrun simctl list devices -j > "$ROOT/after-cleanup.json"
python3 - "$ROOT/after-cleanup.json" "$ROOT/created-after.json" "$U1" "$U2" <<'PY' || exit 79
import json,sys
d=json.load(open(sys.argv[1])); devices={x['udid']:x for xs in d['devices'].values() for x in xs}
assert sys.argv[3] not in devices and sys.argv[4] in devices
c=json.load(open(sys.argv[2])); assert [x['udid'] for x in c]==[sys.argv[4]],c
PY
for ledger in /Users/kyle/.grantiva-qa/runner/simulator-capacity/created.json /Users/kyle/.grantiva/simulator-capacity/created.json; do
  key=$(print -r -- "$ledger" | shasum -a 256 | cut -c1-12)
  [[ -f "$ledger" ]] && shasum -a 256 "$ledger" > "$ROOT/global-$key-after.sha256" || print absent > "$ROOT/global-$key-after.sha256"
  cmp "$ROOT/global-$key-before.sha256" "$ROOT/global-$key-after.sha256" || exit 80
done
"$GRANTIVA" simulator teardown --session-id "$GRANTIVA_SESSION_ID" --json > "$ROOT/teardown.out" 2> "$ROOT/teardown.err" || exit 81
xcrun simctl list devices -j > "$ROOT/final.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/completed.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
