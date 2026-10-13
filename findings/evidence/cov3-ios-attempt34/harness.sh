#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt34"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt34-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt34'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
flows:
  - .maestro/99-crash.yaml
  - .maestro/01-browse.yaml
YAML
mkdir -p "$SCRATCH/a" "$SCRATCH/b"; cp "$SCRATCH/.maestro/01-browse.yaml" "$SCRATCH/a/same.yaml"; cp "$SCRATCH/.maestro/05-category.yaml" "$SCRATCH/b/same.yaml"
cp "$SCRATCH/grantiva.yml" "$ROOT/crash-config.yml"; cp "$SCRATCH/a/same.yaml" "$ROOT/a-same.yaml"; cp "$SCRATCH/b/same.yaml" "$ROOT/b-same.yaml"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone crash-continue "$GRANTIVA" run --no-build --simulator "$U1" --continue-on-failure --report-dir "$ROOT/crash-continue-report"
runone crash-fail-fast "$GRANTIVA" run --no-build --simulator "$U1" --report-dir "$ROOT/crash-fail-fast-report"
runone duplicate-basename "$GRANTIVA" run --no-build --simulator "$U1" --flow a/same.yaml --flow b/same.yaml --json --report-dir "$ROOT/duplicate-report"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
