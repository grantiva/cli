#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt122"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt44-ios/round3\ derived\ data/Build/Products/UITesting-iphonesimulator/Landmarks.app
A=/private/tmp/cov3-ios-attempt122
U=563907E1-703D-4322-AE5F-FC3B06D03143
ACTUAL=com.kylebrowning.Landmarks
WRONG=com.example.Cov3Wrong
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" && -f "$SRC/.maestro/01-browse.yaml" ]] || exit 73
mkdir -p "$ROOT" "$A"
cp "$0" "$ROOT/harness.sh"
cleanup(){ xcrun simctl uninstall "$U" "$WRONG" >>"$ROOT/cleanup-uninstall.out" 2>>"$ROOT/cleanup-uninstall.err" || true; }
trap cleanup EXIT
for n in flag config appfile flow; do mkdir -p "$A/$n/.maestro"; cp "$SRC/.maestro/01-browse.yaml" "$A/$n/.maestro/01-browse.yaml"; done
cp -pR "$APP" "$A/Wrong.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $WRONG" "$A/Wrong.app/Info.plist" || exit 74
python3 - "$A" "$ACTUAL" "$WRONG" <<'PY'
from pathlib import Path
import sys
a=Path(sys.argv[1]);actual=sys.argv[2];wrong=sys.argv[3]
for n,bundle in [('flag',wrong),('config',actual),('appfile',None),('flow',None)]:
 lines=['scheme: "Landmarks (UI Testing)"','simulator: cov3-ios-26']
 if bundle: lines.append(f'bundle_id: {bundle}')
 (a/n/'grantiva.yml').write_text('\n'.join(lines)+'\n')
for n,bundle in [('flag',wrong),('config',wrong),('appfile',wrong),('flow',actual)]:
 p=a/n/'.maestro/01-browse.yaml'; lines=p.read_text().splitlines(); lines[0]=f'appId: {bundle}'; p.write_text('\n'.join(lines)+'\n')
PY
run(){ local n=$1; shift; (cd "$A/$n" && "$GRANTIVA" run --simulator "$U" --flow .maestro/01-browse.yaml --report-dir "$ROOT/$n-report" "$@") >"$ROOT/$n.out" 2>"$ROOT/$n.err"; print -r -- $? >"$ROOT/$n.exit"; }
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA" "$APP/Info.plist" "$A/Wrong.app/Info.plist"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
run flag --no-build --bundle-id "$ACTUAL"
run config --app-file "$A/Wrong.app"
run appfile --app-file "$APP"
run flow --no-build
xcrun simctl uninstall "$U" "$WRONG" >"$ROOT/uninstall-wrong.out" 2>"$ROOT/uninstall-wrong.err"; print -r -- $? >"$ROOT/uninstall-wrong.exit"
python3 - "$ROOT" "$ACTUAL" <<'PY' || exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); actual=sys.argv[2]
for n in ('flag','config','appfile','flow'):
 assert int((r/f'{n}.exit').read_text())==0,n
 d=json.load(open(r/f'{n}-report/report.json'))
 assert d['app']['id']==actual,(n,d['app'])
 assert d['status']=='passed',(n,d['status'])
assert int((r/'uninstall-wrong.exit').read_text())==0
PY
cp -pR "$A" "$ROOT/inputs"
sed -n '165,180p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md >"$ROOT/README-precedence.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
