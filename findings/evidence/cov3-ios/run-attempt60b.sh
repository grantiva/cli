#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt60b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt60b-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt60b'; exit 73; fi
mkdir -p "$ROOT/configs"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$ROOT/configs/id-only.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Clock
    path:
      - tap: "Deep Links"
      - tap: "Caching Demo"
      - tap: {id: "clock"}
      - assert_visible: {id: "clock"}
YAML
cat > "$ROOT/configs/id-and-text.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Clock
    path:
      - tap: {id: "clock", text: "clock"}
YAML
runone() {
  local name="$1"; cp "$ROOT/configs/$name.yml" "$A/grantiva.yml"
  print -r -- "cwd=$A $GRANTIVA diff capture --no-build --simulator $U1 --json" > "$ROOT/$name.command.txt"
  (cd "$A" && "$GRANTIVA" diff capture --no-build --simulator "$U1" --json) > "$ROOT/$name.out" 2> "$ROOT/$name.err"
  print -r -- "$?" > "$ROOT/$name.exit.txt"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'id-only is expected to capture Clock successfully; id+text must fail during config decoding before device work. Explicit U1 is supplied.'
} > "$ROOT/commands.txt"
xcrun simctl list devices --json > "$ROOT/simulators-before.json"
runone id-only
runone id-and-text
xcrun simctl list devices --json > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ "$(cat "$ROOT/id-only.exit.txt")" == 0 && "$(cat "$ROOT/id-and-text.exit.txt")" != 0 ]]
