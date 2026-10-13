#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt66b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt66b-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt66b'; exit 73; fi
mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)";shasum -a 256 "$GRANTIVA";echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl get_app_container "$U1" com.kylebrowning.Landmarks > "$ROOT/container-before.txt" 2> "$ROOT/container-before.err";print -r -- "$?" > "$ROOT/container-before.exit.txt"
(cd "$A" && "$GRANTIVA" build install --json --no-build --no-launch --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios > "$ROOT/skipped.out" 2> "$ROOT/skipped.err");print -r -- "$?" > "$ROOT/skipped.exit.txt"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ $(<"$ROOT/container-before.exit.txt") == 0 && $(<"$ROOT/skipped.exit.txt") == 0 ]] && jq -e '.status=="skipped"' "$ROOT/skipped.out" >/dev/null
