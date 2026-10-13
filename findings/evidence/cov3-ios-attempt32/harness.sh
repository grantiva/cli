#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt32"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt32-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt32'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
YAML
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"; cd "$SCRATCH"
xcrun simctl list devices | rg Booted > "$ROOT/booted-before.txt"
"$GRANTIVA" runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach > "$ROOT/start.out" 2> "$ROOT/start.err"; echo $? > "$ROOT/start.exit.txt"
xcrun simctl launch "$U1" com.kylebrowning.Landmarks > "$ROOT/launch.out" 2> "$ROOT/launch.err"
ready=0
for n in {1..16}; do
 "$GRANTIVA" hierarchy --udid "$U1" --format json > "$ROOT/readiness-$n.json" 2> "$ROOT/readiness-$n.err" && rg -q 'Landmarks' "$ROOT/readiness-$n.json" && { ready=1; break; }
 sleep 1
done
if (( ! ready )); then "$GRANTIVA" runner stop --json > "$ROOT/readiness-failure-stop.out" 2> "$ROOT/readiness-failure-stop.err"; exit 76; fi
"$GRANTIVA" diff capture --no-build --json > "$ROOT/session-resolution.out" 2> "$ROOT/session-resolution.err"; echo $? > "$ROOT/session-resolution.exit.txt"
[[ -d .grantiva/captures ]] && cp -pR .grantiva/captures "$ROOT/session-resolution-captures"
"$GRANTIVA" runner stop --json > "$ROOT/stop.out" 2> "$ROOT/stop.err"; echo $? > "$ROOT/stop.exit.txt"
xcrun simctl list devices | rg Booted > "$ROOT/booted-before-ambiguity.txt"
"$GRANTIVA" diff capture --no-build --json > "$ROOT/ambiguous.out" 2> "$ROOT/ambiguous.err"; echo $? > "$ROOT/ambiguous.exit.txt"
xcrun simctl list devices | rg Booted > "$ROOT/booted-after.txt"
{
 echo "started_and_finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo 'capture commands intentionally omit --simulator and config simulator; first relies on explicit-U1 live session, second has no session and must refuse ambiguity before device command'
} > "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
