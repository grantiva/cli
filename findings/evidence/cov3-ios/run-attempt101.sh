#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt101";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt101;DD="$A/mismatch Derived Data";U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh"
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
cd "$A"
"$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --derived-data-path "$DD" --no-launch --bundle-id com.example.Other --json >"$ROOT/mismatch.out" 2>"$ROOT/mismatch.err";E1=$?;echo $E1 >"$ROOT/mismatch.exit.txt"
"$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --derived-data-path "$DD" --no-build --no-launch --bundle-id com.kylebrowning.Landmarks --json >"$ROOT/matching.out" 2>"$ROOT/matching.err";E2=$?;echo $E2 >"$ROOT/matching.exit.txt"
find "$DD/Build/Products" -name Info.plist -path '*.app/Info.plist' -print -exec /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' {} \; >"$ROOT/product-identities.txt" 2>"$ROOT/product-identities.err"||true
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
((E1!=0&&E2==0))&&rg -q 'com.example.Other' "$ROOT/mismatch.err"&&rg -q 'com.kylebrowning.Landmarks' "$ROOT/mismatch.err"&&! rg -q 'NSPOSIXErrorDomain' "$ROOT/mismatch.err"
