#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt28"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt28-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt28'; exit 73; fi
mkdir -p "$ROOT/capture-pngs"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Deep Links
    path:
      - tap: Deep Links
YAML
cp "$SCRATCH/grantiva.yml" "$ROOT/grantiva.yml"
cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
for i in {01..10}; do
 "$GRANTIVA" diff capture --no-build --simulator "$U1" --json > "$ROOT/capture-$i.out" 2> "$ROOT/capture-$i.err"; rc=$?
 echo "capture_$i=$rc" >> "$ROOT/commands.txt"
 cp .grantiva/captures/Home.png "$ROOT/capture-pngs/$i-Home.png"
 cp '.grantiva/captures/Deep Links.png' "$ROOT/capture-pngs/$i-Deep-Links.png"
 shasum -a 256 "$ROOT/capture-pngs/$i-Home.png" "$ROOT/capture-pngs/$i-Deep-Links.png" > "$ROOT/capture-$i.sha256"
done
for i in {01..10}; do
 "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/04-discard.yaml --json > "$ROOT/discard-$i.out" 2> "$ROOT/discard-$i.err"; rc=$?
 echo "discard_$i=$rc" >> "$ROOT/commands.txt"
done
"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/21-system-alert-maps.yaml --json > "$ROOT/system-alert.out" 2> "$ROOT/system-alert.err"; system_alert_rc=$?
echo "system_alert=$system_alert_rc" >> "$ROOT/commands.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
