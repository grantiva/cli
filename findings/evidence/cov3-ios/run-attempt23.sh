#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt23"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"; SCRATCH="$BASE/attempt23-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt23'; exit 73; fi
mkdir -p "$ROOT" "$SCRATCH"; cp "$0" "$ROOT/harness.sh"; cp -pR "$SOURCE/.maestro" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
flows:
  - .maestro/01-browse.yaml
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
run 01-pass-trailing "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --snapshot trailing --report-dir "$ROOT/pass-trailing-report"
run 02-fail-failure "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --snapshot failure --report-dir "$ROOT/fail-failure-report"
run 03-fail-trailing-ephemeral "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing
run 04-crash-no-hint "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/99-crash.yaml --report-dir "$ROOT/crash-report"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit 0
