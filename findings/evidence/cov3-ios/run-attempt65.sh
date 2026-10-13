#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-a65
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt65"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt65-ios"; NAME='cov3-ios-65 iPhone 17'
APP="$BASE/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt65'; exit 73; fi
[[ -d "$APP" ]] || { print -u2 'proven app product absent'; exit 74; }
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
shasum -a 256 "$APP/Info.plist" "$APP/Landmarks" > "$ROOT/app-product.sha256"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$NAME" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); assert not any(d.get('name')==sys.argv[2] for ds in j['devices'].values() for d in ds)
PY
"$GRANTIVA" simulator ensure --name "$NAME" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot --json > "$ROOT/ensure.json" 2> "$ROOT/ensure.err"; print -r -- "$?" > "$ROOT/ensure.exit.txt"
U=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "$ROOT/ensure.json")
xcrun simctl list devices -j > "$ROOT/simulators-created.json"
python3 - "$ROOT/simulators-before.json" "$ROOT/simulators-created.json" "$NAME" "$U" <<'PY'
import json,re,sys
b,a,name,u=sys.argv[1:]; bj=json.load(open(b)); aj=json.load(open(a)); before={d['udid'] for ds in bj['devices'].values() for d in ds}; found=[d for ds in aj['devices'].values() for d in ds if d['udid']==u]
assert re.fullmatch(r'[0-9A-Fa-f-]{36}',u) and u not in before and len(found)==1 and found[0]['name']==name,(u,found)
PY
if [[ $? -ne 0 ]]; then print -u2 'ownership validation failed; preserve device'; exit 75; fi
printf '%s\t%s\n' "$NAME" "$U" > "$ROOT/owned-device.tsv"
cleanup() {
 xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err"
 python3 - "$ROOT/cleanup-before.json" "$NAME" "$U" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); f=[d for ds in j['devices'].values() for d in ds if d['udid']==sys.argv[3]]
assert not f or (len(f)==1 and f[0]['name']==sys.argv[2]),f
PY
 if [[ $? -eq 0 ]]; then xcrun simctl delete "$U" > "$ROOT/cleanup.out" 2> "$ROOT/cleanup.err"; print -r -- "$?" > "$ROOT/cleanup.exit.txt"; fi
 xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err"
}
trap cleanup EXIT
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_name=$NAME owned_udid=$U app=$APP"
 echo 'Fresh row-owned simulator is uninstalled before each app-file command; D2-09 begins shutdown.'
} > "$ROOT/commands.txt"
run() { local n="$1"; shift; print -r -- "$GRANTIVA $*" > "$ROOT/$n.command.txt"; (cd "$A" && "$GRANTIVA" "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"); print -r -- "$?" > "$ROOT/$n.exit.txt"; }
absent() { xcrun simctl uninstall "$U" com.kylebrowning.Landmarks > "$ROOT/$1-uninstall.out" 2> "$ROOT/$1-uninstall.err" || true; xcrun simctl get_app_container "$U" com.kylebrowning.Landmarks > "$ROOT/$1-before-container.out" 2> "$ROOT/$1-before-container.err"; print -r -- "$?" > "$ROOT/$1-before-container.exit.txt"; }
present() { xcrun simctl get_app_container "$U" com.kylebrowning.Landmarks > "$ROOT/$1-after-container.out" 2> "$ROOT/$1-after-container.err"; print -r -- "$?" > "$ROOT/$1-after-container.exit.txt"; }
absent build-install
run build-install build install --no-build --app-file "$APP" --no-launch --simulator "$U" --platform ios --json
present build-install
absent run
run run run --no-build --app-file "$APP" --flow .maestro/01-browse.yaml --simulator "$U" --platform ios --report-dir "$ROOT/run-report"
present run
absent capture
xcrun simctl shutdown "$U" > "$ROOT/capture-shutdown.out" 2> "$ROOT/capture-shutdown.err"; print -r -- "$?" > "$ROOT/capture-shutdown.exit.txt"
run capture diff capture --no-build --app-file "$APP" --simulator "$U" --platform ios --json
present capture
cp -R "$A/.grantiva" "$ROOT/post-capture-grantiva"
absent ci
run ci ci run --no-build --app-file "$APP" --simulator "$U" --platform ios
present ci
absent skipped
run skipped build install --no-build --no-launch --simulator "$U" --platform ios
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); bad=[]
for n in ['build-install','run','capture']:
 if int((r/f'{n}.exit.txt').read_text()) != 0: bad.append((n,'command'))
 if int((r/f'{n}-before-container.exit.txt').read_text()) == 0: bad.append((n,'not absent'))
 if int((r/f'{n}-after-container.exit.txt').read_text()) != 0: bad.append((n,'not installed'))
if int((r/'ci-before-container.exit.txt').read_text()) == 0: bad.append(('ci','not absent'))
# No API key may make CI fail; record whether it installed before that error instead of requiring command success.
if int((r/'skipped.exit.txt').read_text()) != 0: bad.append(('skipped','command'))
print(bad); raise SystemExit(bool(bad))
PY
