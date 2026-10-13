#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt40"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt40-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt40'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cd "$SCRATCH"
runone() {
 local n=$1; shift
 print -r -- "$*" > "$ROOT/$n.command.txt"
 python3 -I - "$ROOT/$n" "$@" <<'PY'
import json,subprocess,sys,time
prefix,*cmd=sys.argv[1:]
t=time.monotonic(); r=subprocess.run(cmd,capture_output=True,text=True); elapsed=time.monotonic()-t
open(prefix+'.out','w').write(r.stdout); open(prefix+'.err','w').write(r.stderr)
open(prefix+'.exit.txt','w').write(str(r.returncode)+'\n'); open(prefix+'.elapsed.json','w').write(json.dumps({'seconds':elapsed})+'\n')
PY
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
xcrun simctl list devices --json > "$ROOT/simctl-before.json"
runone missing-build "$GRANTIVA" run --simulator "$U1" --flow missing.yaml
runone missing-no-build "$GRANTIVA" run --no-build --simulator "$U1" --flow missing.yaml
mkdir -p not-a-flow
runone directory "$GRANTIVA" run --no-build --simulator "$U1" --flow not-a-flow
cat > grantiva.yml <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
flows:
  - configured-missing.yaml
YAML
cp grantiva.yml "$ROOT/grantiva.yml"
runone configured-missing "$GRANTIVA" run --no-build --simulator "$U1"
xcrun simctl list devices --json > "$ROOT/simctl-after.json"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
