#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
unset GRANTIVA_API_KEY GRANTIVA_SESSION_ID
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt106c";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt106c;APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt44-ios/round3\ derived\ data/Build/Products/UITesting-iphonesimulator/Landmarks.app;U1=563907E1-703D-4322-AE5F-FC3B06D03143;MAN='cov3-ios-106-manual iPhone 17';READ='cov-ios-3 iPhone 17';
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";xcrun simctl list devices -j >"$ROOT/before.json"
python3 - "$ROOT/before.json" "$MAN" "$READ" <<'PY'||exit 74
import json,sys
d=json.load(open(sys.argv[1]));names={x.get('name') for a in d['devices'].values() for x in a};assert sys.argv[2] not in names and sys.argv[3] not in names
PY
cleanup(){
 for sid in cov3-ios-106-readme cov-ios-tmp;do GRANTIVA_SESSION_ID=$sid "$GRANTIVA" simulator teardown --session-id "$sid" --json >>"$ROOT/cleanup-sessions.out" 2>>"$ROOT/cleanup-sessions.err"||true;done
 xcrun simctl list devices -j >"$ROOT/cleanup-before.json" 2>"$ROOT/cleanup-before.err"||return
 python3 - "$ROOT/cleanup-before.json" "$MAN" "$READ" >"$ROOT/cleanup-uuids.txt" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1]));
for a in d['devices'].values():
 for x in a:
  if x.get('name') in sys.argv[2:] and re.fullmatch(r'[0-9A-F-]{36}',x.get('udid','')):print(x['udid'])
PY
 while IFS= read -r u;do [[ -z "$u" ]]||xcrun simctl delete "$u" >>"$ROOT/cleanup-delete.out" 2>>"$ROOT/cleanup-delete.err";done <"$ROOT/cleanup-uuids.txt"
 xcrun simctl list devices -j >"$ROOT/cleanup-after.json" 2>"$ROOT/cleanup-after.err"||true
};trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";shasum -a 256 "$APP/Info.plist";echo owned_campaign_u1=$U1; }>"$ROOT/commands.txt"
MU=$(xcrun simctl create "$MAN" 'iPhone 17' 'iOS 26.0')||exit 75;echo "$MU">"$ROOT/manual.udid";xcrun simctl boot "$MU">"$ROOT/manual-boot.out" 2>"$ROOT/manual-boot.err"||exit 76;xcrun simctl bootstatus "$MU" -b >"$ROOT/manual-bootstatus.out" 2>"$ROOT/manual-bootstatus.err"||exit 77
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created-before-run.json" 2>/dev/null||echo '[]'>"$ROOT/created-before-run.json"; "$GRANTIVA" simulator sessions --json >"$ROOT/sessions-before-run.json"; test -e "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" && cp "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" "$ROOT/lock-before-run" || true
(cd "$A"&&env -u GRANTIVA_SESSION_ID "$GRANTIVA" run --app-file "$APP" --simulator "$MU" --flow .maestro/01-browse.yaml --report-dir "$ROOT/manual-report" >"$ROOT/manual-run.out" 2>"$ROOT/manual-run.err");echo $? >"$ROOT/manual-run.exit"
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created-after-run.json" 2>/dev/null||echo '[]'>"$ROOT/created-after-run.json"; "$GRANTIVA" simulator sessions --json >"$ROOT/sessions-after-run.json"; test -e "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" && cp "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" "$ROOT/lock-after-run" || true; xcrun simctl list devices -j >"$ROOT/manual-after-run.json"
GRANTIVA_SESSION_ID=cov3-ios-106-manual "$GRANTIVA" simulator teardown --session-id cov3-ios-106-manual --json >"$ROOT/manual-session-teardown.out" 2>"$ROOT/manual-session-teardown.err";echo $? >"$ROOT/manual-session-teardown.exit";xcrun simctl list devices -j >"$ROOT/manual-after-session-teardown.json"; "$GRANTIVA" simulator sessions --json >"$ROOT/sessions-after-session-teardown.json"; test -e "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" && cp "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" "$ROOT/lock-after-session-teardown" || true
(cd "$A"&&env -u GRANTIVA_SESSION_ID "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml >"$ROOT/owned-sessionless.out" 2>"$ROOT/owned-sessionless.err");echo $? >"$ROOT/owned-sessionless.exit"
find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$MU" -type d -print >"$ROOT/manual-homes-before-teardown.txt"
"$GRANTIVA" simulator teardown --udid "$MU" --json >"$ROOT/manual-udid-teardown.out" 2>"$ROOT/manual-udid-teardown.err";echo $? >"$ROOT/manual-udid-teardown.exit";find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$MU" -type d -print >"$ROOT/manual-homes-after-teardown.txt";xcrun simctl list devices -j >"$ROOT/manual-before-delete.json"
xcrun simctl delete "$MU" >"$ROOT/manual-delete.out" 2>"$ROOT/manual-delete.err";echo $? >"$ROOT/manual-delete.exit"; test -e "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" && cp "$GRANTIVA_RUNNER_HOME/locks/$MU.lock" "$ROOT/lock-after-delete" || true; xcrun simctl list devices -j >"$ROOT/manual-after-delete.json";
export GRANTIVA_SESSION_ID=cov3-ios-106-readme
"$GRANTIVA" simulator ensure --name "$READ" --json >"$ROOT/readme-ensure.out" 2>"$ROOT/readme-ensure.err"||exit 78;RU=$(jq -r .udid "$ROOT/readme-ensure.out");echo "$RU">"$ROOT/readme.udid"
(cd "$A"&&"$GRANTIVA" run --app-file "$APP" --simulator "$RU" --flow .maestro/01-browse.yaml --report-dir "$ROOT/readme-report" >"$ROOT/readme-run.out" 2>"$ROOT/readme-run.err");echo $? >"$ROOT/readme-run.exit"
"$GRANTIVA" simulator teardown --session-id cov3-ios-106-readme --json >"$ROOT/readme-teardown.out" 2>"$ROOT/readme-teardown.err";echo $? >"$ROOT/readme-teardown.exit"
export GRANTIVA_SESSION_ID=cov-ios-tmp
"$GRANTIVA" simulator ensure --name "$READ" --json >"$ROOT/session-ensure.out" 2>"$ROOT/session-ensure.err"||exit 79;SU=$(jq -r .udid "$ROOT/session-ensure.out");echo "$SU">"$ROOT/session.udid"
"$GRANTIVA" simulator teardown --session-id cov-ios-tmp --json >"$ROOT/session-teardown.out" 2>"$ROOT/session-teardown.err";echo $? >"$ROOT/session-teardown.exit";xcrun simctl list devices -j >"$ROOT/after.json"
python3 - "$ROOT" "$MU" "$U1" "$RU" "$SU" <<'PY'||exit 80
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);mu,u1,ru,su=sys.argv[2:]
def n(p): return int((r/p).read_text().strip())
def devices(p):
 d=json.load(open(r/p));return {x.get("udid"):x for a in d["devices"].values() for x in a}
assert n("manual-run.exit")==0
assert mu not in {x.get("udid") for x in json.load(open(r/"created-after-run.json"))}
for p in ("sessions-before-run.json","sessions-after-run.json","sessions-after-session-teardown.json"):
 assert mu not in {x.get("udid") for x in json.load(open(r/p))}
assert devices("manual-after-session-teardown.json")[mu]["state"]=="Booted"
assert n("owned-sessionless.exit")!=0 and "session" in (r/"owned-sessionless.err").read_text().lower()
assert n("manual-udid-teardown.exit")==0 and not (r/"manual-homes-after-teardown.txt").read_text().strip()
assert n("manual-delete.exit")==0 and mu not in devices("manual-after-delete.json")
assert not any((r/p).exists() for p in ("lock-after-run","lock-after-session-teardown","lock-after-delete"))
assert n("readme-run.exit")==0 and n("readme-teardown.exit")==0 and ru not in devices("after.json")
assert n("session-teardown.exit")==0 and su not in devices("after.json")
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
