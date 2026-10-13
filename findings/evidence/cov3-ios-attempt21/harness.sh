#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt21"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SCRATCH="$BASE/attempt21-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt21'; exit 73; fi
mkdir -p "$ROOT" "$SCRATCH"; cp "$0" "$ROOT/harness.sh"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: "Favorites"
  - name: Deep Links
    path:
      - tap: "Deep Links"
  - name: Lakes
    path:
      - tap: "Landmarks"
      - tap: "Lakes"
  - name: Detail
    path:
      - tap: "Landmarks"
      - tap: "Golden Gate Bridge"
      - assert_visible: "Plan Visit"
YAML
run() {
  local name="$1"; shift; local p="$ROOT/$name"
  { print -r -- "cwd=$SCRATCH"; print -r -- "$*"; } > "$p.command.txt"
  local start=$(date +%s); (cd "$SCRATCH" && "$@") > "$p.out" 2> "$p.err"; local rc=$? end=$(date +%s)
  print -r -- "$rc" > "$p.exit.txt"; print -r -- "$((end-start))" > "$p.elapsed-seconds.txt"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
run 01-start "$GRANTIVA" runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
run 02-launch xcrun simctl launch "$U1" com.kylebrowning.Landmarks
run 03-readiness /bin/zsh -c "for n in {1..12}; do '$GRANTIVA' hierarchy --udid '$U1' --format json > '$ROOT/readiness-'\$n'.json' 2> '$ROOT/readiness-'\$n'.err' && exit 0; sleep 1; done; exit 1"
if [[ "$(cat "$ROOT/03-readiness.exit.txt")" != 0 ]]; then
  run 04-stop-after-readiness-failure "$GRANTIVA" runner stop --json
  exit 74
fi
run 04-start-already-running "$GRANTIVA" runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
run 05-session-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
mkdir -p "$ROOT/preserved-captures"; cp -p "$SCRATCH"/.grantiva/captures/*.png "$ROOT/preserved-captures/" 2>/dev/null || true
run 06-stop "$GRANTIVA" runner stop --json
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit 0
