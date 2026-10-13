#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt67b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt67b-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt67b'; exit 73; fi
mkdir -p "$ROOT/configs"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva.yml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- runFlow: sub-shot.yaml
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- scroll: DOWN
- scrollUntilVisible:
    element: {text: "Cache Policy", exact: true}
    direction: DOWN
    timeout: 10000
    speed: 40
    centerElement: true
- extendedWaitUntil:
    visible: {text: "Cache Policy", exact: true}
    timeout: 5000
- takeScreenshot: Main
YAML
cat > "$A/sub-shot.yaml" <<'YAML'
- takeScreenshot: FromSub
YAML
cp "$A/grantiva.yml" "$A/sub-shot.yaml" "$ROOT/configs/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'D2-05 Maestro-format grantiva.yml through diff capture/staging; joins attempt59 mapping+inline forms and exact-head staging tests.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
(cd "$A" && "$GRANTIVA" diff capture --no-build --simulator "$U1" --platform ios --verbose --json > "$ROOT/capture.out" 2> "$ROOT/capture.err"); print -r -- "$?" > "$ROOT/capture.exit.txt"
cp -R "$A/.grantiva" "$ROOT/final-grantiva"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ $(<"$ROOT/capture.exit.txt") == 0 ]]
