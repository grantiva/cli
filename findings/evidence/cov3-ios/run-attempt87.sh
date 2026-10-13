#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt87"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt87-ios"; DD="$BASE/attempt87-iphoneos-dd"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" || -e "$DD" ]]; then print -u2 'refusing overwrite attempt87'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
(cd "$A" && xcodebuild -project Landmarks.xcodeproj -scheme 'Landmarks (UI Testing)' -configuration UITesting -sdk iphoneos -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build) > "$ROOT/iphoneos-build.out" 2> "$ROOT/iphoneos-build.err"; print -r -- "$?" > "$ROOT/iphoneos-build.exit.txt"
APP=$(find "$DD/Build/Products" -type d -path '*iphoneos/Landmarks.app' -print -quit)
[[ -n "$APP" ]] || exit 74
print -r -- "$APP" > "$ROOT/app-path.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms' "$APP/Info.plist" > "$ROOT/supported-platforms.txt"
file "$APP/Landmarks" > "$ROOT/executable.file.txt"
find "$APP" -type f -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/app-files.sha256"
(cd "$A" && "$GRANTIVA" run --no-build --app-file "$APP" --simulator "$U1" --flow .maestro/01-browse.yaml) > "$ROOT/run.out" 2> "$ROOT/run.err"; print -r -- "$?" > "$ROOT/run.exit.txt"
python3 - "$ROOT" <<'PY' || exit 75
import sys
from pathlib import Path
r=Path(sys.argv[1]); assert (r/'iphoneos-build.exit.txt').read_text().strip()=='0'; assert (r/'run.exit.txt').read_text().strip()=='1'
assert 'iPhoneOS' in (r/'supported-platforms.txt').read_text()
t=(r/'run.out').read_text(errors='replace')+(r/'run.err').read_text(errors='replace')
assert 'simulator' in t.lower() and ('device build' in t.lower() or 'iphoneos' in t.lower() or 'not a simulator' in t.lower())
PY
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
