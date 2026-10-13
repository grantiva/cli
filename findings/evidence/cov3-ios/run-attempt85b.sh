#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt85b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt85b-ios"; PKG="$BASE/attempt85b-package"
APP="$BASE/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" || -e "$PKG" ]]; then print -u2 'refusing overwrite attempt85b'; exit 73; fi
restore_app() {
  xcrun simctl install "$U1" "$APP" > "$ROOT/restore-install.out" 2> "$ROOT/restore-install.err" || return
  xcrun simctl get_app_container "$U1" com.kylebrowning.Landmarks app > "$ROOT/restore-container.out" 2> "$ROOT/restore-container.err"
}
trap restore_app EXIT
[[ -d "$APP" ]] || { print -u2 'current candidate app absent'; exit 74; }
mkdir -p "$ROOT" "$PKG/Payload"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"; cp -pR "$APP" "$PKG/Payload/"
(cd "$PKG" && /usr/bin/zip -qry "$ROOT/Landmarks-simulator.ipa" Payload)
find "$APP" -type f -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/app-files.sha256"
/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms' "$APP/Info.plist" > "$ROOT/supported-platforms.txt"
unzip -l "$ROOT/Landmarks-simulator.ipa" > "$ROOT/ipa-contents.txt"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$ROOT/Landmarks-simulator.ipa"; echo "source_app=$APP"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 - "$ROOT/simulators-before.json" "$U1" <<'PY' || exit 75
import json,sys
d=json.load(open(sys.argv[1])); h=[x for xs in d['devices'].values() for x in xs if x.get('udid')==sys.argv[2]]
assert len(h)==1 and h[0]['name']=='cov3-ios-26'
PY
(cd "$A" && "$GRANTIVA" run --no-build --app-file "$ROOT/Landmarks-simulator.ipa" --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir "$ROOT/ipa-report") > "$ROOT/ipa-run.out" 2> "$ROOT/ipa-run.err"; print -r -- "$?" > "$ROOT/ipa-run.exit.txt"
xcrun simctl install "$U1" "$APP" > "$ROOT/install.out" 2> "$ROOT/install.err"; print -r -- "$?" > "$ROOT/install.exit.txt"
(cd "$A" && "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir "$ROOT/installed-report") > "$ROOT/installed-run.out" 2> "$ROOT/installed-run.err"; print -r -- "$?" > "$ROOT/installed-run.exit.txt"
xcrun simctl uninstall "$U1" com.kylebrowning.Landmarks > "$ROOT/uninstall.out" 2> "$ROOT/uninstall.err"; print -r -- "$?" > "$ROOT/uninstall.exit.txt"
(cd "$A" && "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml) > "$ROOT/absent-run.out" 2> "$ROOT/absent-run.err"; print -r -- "$?" > "$ROOT/absent-run.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
python3 - "$ROOT" <<'PY' || exit 76
import json,sys
from pathlib import Path
r=Path(sys.argv[1])
assert all((r/f'{x}.exit.txt').read_text().strip()=='0' for x in ['ipa-run','install','installed-run','uninstall'])
assert (r/'absent-run.exit.txt').read_text().strip()=='1'
t=(r/'absent-run.out').read_text(errors='replace')+(r/'absent-run.err').read_text(errors='replace')
assert 'com.kylebrowning.Landmarks is not installed on cov3-ios-26' in t
assert 'Drop --no-build or run grantiva build install.' in t
assert json.load(open(r/'ipa-report/report.json'))['summary']['failed']==0
assert json.load(open(r/'installed-report/report.json'))['summary']['failed']==0
PY
restore_app || exit 77
trap - EXIT
[[ -s "$ROOT/restore-container.out" ]] || exit 78
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
