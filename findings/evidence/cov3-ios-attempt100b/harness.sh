#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt100b";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt100b;DD="$A/cached Derived Data";U1=563907E1-703D-4322-AE5F-FC3B06D03143;SC="$A/Landmarks.xcodeproj/xcshareddata/xcschemes/Landmarks (UI Testing).xcscheme"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";rm -f "$A/grantiva.yml"
cp "$SC" "$ROOT/second-scheme.xcscheme";shasum -a 256 "$A/Landmarks.xcodeproj/xcshareddata/xcschemes/"*.xcscheme >"$ROOT/schemes-before.sha256";rm "$SC"
find "$A/Landmarks.xcodeproj/xcshareddata/xcschemes" -type f -maxdepth 1 -print >"$ROOT/one-scheme-files.txt"
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
cd "$A"
"$GRANTIVA" build build --platform ios --simulator "$U1" --derived-data-path "$DD" --json >"$ROOT/one-first.out" 2>"$ROOT/one-first.err";E1=$?;echo $E1 >"$ROOT/one-first.exit.txt"
"$GRANTIVA" build build --platform ios --simulator "$U1" --derived-data-path "$DD" --json >"$ROOT/one-cached.out" 2>"$ROOT/one-cached.err";E2=$?;echo $E2 >"$ROOT/one-cached.exit.txt"
cp "$ROOT/second-scheme.xcscheme" "$SC";find "$A/Landmarks.xcodeproj/xcshareddata/xcschemes" -type f -maxdepth 1 -print >"$ROOT/two-scheme-files.txt";shasum -a 256 "$A/Landmarks.xcodeproj/xcshareddata/xcschemes/"*.xcscheme >"$ROOT/schemes-restored.sha256"
"$GRANTIVA" build build --platform ios --simulator "$U1" --derived-data-path "$DD" --json >"$ROOT/two-after-cache.out" 2>"$ROOT/two-after-cache.err";E3=$?;echo $E3 >"$ROOT/two-after-cache.exit.txt"
find "$DD/Build/Products" -maxdepth 3 -type d -name '*.app' -print >"$ROOT/products.txt" 2>"$ROOT/products.err"||true
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
((E1==0&&E2==0&&E3!=0))&&rg -q 'No scheme specified' "$ROOT/two-after-cache.err"&&rg -q 'Landmarks \(UI Testing\)' "$ROOT/two-after-cache.err"
