#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt36"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt36-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
APP="$BASE/attempt26-ios/flag-derived-data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt36'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
mkdir -p "$SCRATCH/a" "$SCRATCH/b"
cp "$SCRATCH/.maestro/01-browse.yaml" "$SCRATCH/a/same.yaml"
cp "$SCRATCH/.maestro/05-category.yaml" "$SCRATCH/b/same.yaml"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
flows:
  - a/same.yaml
  - b/same.yaml
YAML
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
cp "$SCRATCH/a/same.yaml" "$ROOT/a-same.yaml"
cp "$SCRATCH/b/same.yaml" "$ROOT/b-same.yaml"
{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_udid=$U1"
  echo "app_file=$APP"
} > "$ROOT/commands.txt"
if [[ -f "$APP/Info.plist" ]]; then
  cp "$APP/Info.plist" "$ROOT/Landmarks.Info.plist"
  shasum -a 256 "$APP/Info.plist" "$APP/Landmarks" > "$ROOT/app-artifact.sha256"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" > "$ROOT/app-bundle-id.txt"
else
  print -u2 'attempt26 app artifact unavailable' > "$ROOT/app-artifact-missing.err"
fi
cd "$SCRATCH"
print -r -- "$GRANTIVA run --no-build --simulator $U1 --json --report-dir $ROOT/duplicate-config-report" > "$ROOT/duplicate-config.command.txt"
"$GRANTIVA" run --no-build --simulator "$U1" --json --report-dir "$ROOT/duplicate-config-report" > "$ROOT/duplicate-config.out" 2> "$ROOT/duplicate-config.err"
print -r -- "$?" > "$ROOT/duplicate-config.exit.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
