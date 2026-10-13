#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt38"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt38-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
APP="$BASE/attempt26-ios/flag-derived-data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt38'; exit 73; fi
[[ -f "$APP/Info.plist" && -x "$APP/Landmarks" ]] || { print -u2 'missing proven simulator app artifact'; exit 74; }
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
rm -f "$SCRATCH/grantiva.yml"
cp "$APP/Info.plist" "$ROOT/Landmarks.Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" > "$ROOT/app-bundle-id.txt"
shasum -a 256 "$APP/Info.plist" "$APP/Landmarks" > "$ROOT/app-artifact.sha256"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "app_file=$APP"
} > "$ROOT/commands.txt"
runone appfile-run "$GRANTIVA" run --app-file "$APP" --simulator "$U1" --flow .maestro/01-browse.yaml --json
cat > grantiva.yml <<'YAML'
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: Favorites
  - name: Deep Links
    path:
      - tap: Deep Links
YAML
cp grantiva.yml "$ROOT/grantiva.yml"
runone appfile-capture "$GRANTIVA" diff capture --app-file "$APP" --simulator "$U1" --json
runone approve "$GRANTIVA" diff approve --json
runone appfile-compare-capture "$GRANTIVA" diff compare --capture --app-file "$APP" --simulator "$U1" --json
runone nobuild-compare-capture "$GRANTIVA" diff compare --capture --no-build --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --json
cp -pR .grantiva "$ROOT/final-grantiva"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
