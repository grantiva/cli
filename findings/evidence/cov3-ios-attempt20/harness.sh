#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt20"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SCRATCH="$BASE/attempt20-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
LEASE="$GRANTIVA_RUNNER_HOME/locks/$U1.lock"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt20'; exit 73; fi
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
capture_state() {
  local name="$1"
  local dir="$ROOT/state-$name"; mkdir -p "$dir"
  if [[ -e "$LEASE" ]]; then cp -p "$LEASE" "$dir/device-lease.lock"; print present > "$dir/device-lease.state"; else print absent > "$dir/device-lease.state"; fi
  if [[ -d "$SCRATCH/.grantiva" ]]; then find "$SCRATCH/.grantiva" -maxdepth 2 -type f -print | sort > "$dir/project-files.txt"; cp -pR "$SCRATCH/.grantiva/." "$dir/project-grantiva/" 2>/dev/null || true; else : > "$dir/project-files.txt"; fi
  find /tmp/grantiva-sessions -maxdepth 2 -type f -print 2>/dev/null | sort > "$dir/global-session-files.txt"
  ps -axo pid,ppid,etime,command > "$dir/processes.txt"
}
run() {
  local name="$1"; shift; local p="$ROOT/$name"
  { print -r -- "cwd=$SCRATCH"; print -r -- "$*"; } > "$p.command.txt"
  local start=$(date +%s); (cd "$SCRATCH" && "$@") > "$p.out" 2> "$p.err"; local rc=$? end=$(date +%s)
  print -r -- "$rc" > "$p.exit.txt"; print -r -- "$((end-start))" > "$p.elapsed-seconds.txt"
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "binary=$GRANTIVA"; shasum -a 256 "$GRANTIVA"
 echo "owned_device_udid=$U1"; echo "lease_path=$LEASE"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
capture_state before
run 01-start "$GRANTIVA" runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --detach
capture_state during-start
run 02-launch xcrun simctl launch "$U1" com.kylebrowning.Landmarks
run 03-session-capture "$GRANTIVA" diff capture --no-build --simulator "$U1" --json
capture_state after-capture
run 04-stop "$GRANTIVA" runner stop --json
capture_state after-stop
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
exit 0
