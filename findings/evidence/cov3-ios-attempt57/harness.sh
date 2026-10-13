#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt57"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt57-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt57'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Deep Links
    path: [{tap: "Deep Links"}]
YAML
cp "$A/grantiva.yml" "$ROOT/grantiva.yml"
runone() {
  local name="$1"; shift
  { print -r -- "cwd=$A"; print -r -- "$*"; } > "$ROOT/$name.command.txt"
  (cd "$A" && "$@") > "$ROOT/$name.out" 2> "$ROOT/$name.err"
  print -r -- "$?" > "$ROOT/$name.exit.txt"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
runone approve-initial "$GRANTIVA" diff approve --json
cp "$A/.grantiva/captures/Home.png" "$A/.grantiva/captures/Deep Links.png"
runone compare-changed "$GRANTIVA" diff compare --json
find "$A/.grantiva" -type f -print | sort > "$ROOT/changed-files.txt"
cp -pR "$A/.grantiva/diffs" "$ROOT/diffs-after-changed"
mv "$A/.grantiva/baselines/Deep Links.png" "$A/.grantiva/baselines/Deep%20Links.png"
find "$A/.grantiva/baselines" -type f -print | sort > "$ROOT/baselines-legacy-before.txt"
shasum -a 256 "$A/.grantiva/baselines/Deep%20Links.png" > "$ROOT/legacy-before.sha256"
runone compare-legacy "$GRANTIVA" diff compare --json
runone approve-migrate "$GRANTIVA" diff approve 'Deep Links' --json
find "$A/.grantiva/baselines" -type f -print | sort > "$ROOT/baselines-after-migrate.txt"
shasum -a 256 "$A/.grantiva/baselines"/*.png > "$ROOT/baselines-after-migrate.sha256"
cp -pR "$A/.grantiva" "$ROOT/final-grantiva"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ "$(cat "$ROOT/capture.exit.txt")" == 0 && "$(cat "$ROOT/approve-initial.exit.txt")" == 0 && "$(cat "$ROOT/compare-changed.exit.txt")" == 1 && "$(cat "$ROOT/compare-legacy.exit.txt")" == 1 && "$(cat "$ROOT/approve-migrate.exit.txt")" == 0 ]]
