#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt58"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt58-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt58'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
header='appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Caching Demo"'
mkdir -p "$ROOT/configs"
cat > "$ROOT/configs/visible-5s.yml" <<EOF
$header
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- tapOn: {id: "clock"}
- assertVisible: {id: "clock"}
- takeScreenshot: "Visible 5s ID"
EOF
cat > "$ROOT/configs/missing-2s.yml" <<EOF
$header
- extendedWaitUntil:
    visible: "No Such Element"
    timeout: 2000
- takeScreenshot: "Should Not Exist"
EOF
cat > "$ROOT/configs/notvisible-2s.yml" <<EOF
$header
- extendedWaitUntil:
    notVisible: "No Such Element"
    timeout: 2000
- takeScreenshot: "Not Visible 2s"
EOF
cat > "$ROOT/configs/exact-5s.yml" <<EOF
$header
- extendedWaitUntil:
    visible: {text: "Cache Policy", exact: true}
    timeout: 5000
- takeScreenshot: "Exact 5s"
EOF
cat > "$ROOT/configs/no-timeout.yml" <<EOF
$header
- extendedWaitUntil:
    visible: "Cache Policy"
- takeScreenshot: "No Timeout"
EOF
runone() {
  local name="$1" expected="$2"; shift 2
  { print -r -- "cwd=$A"; print -r -- "$*"; } > "$ROOT/$name.command.txt"
  local start=$(python3 -c 'import time; print(time.monotonic())')
  (cd "$A" && "$@") > "$ROOT/$name.out" 2> "$ROOT/$name.err"; local rc=$?
  local end=$(python3 -c 'import time; print(time.monotonic())')
  print -r -- "$rc" > "$ROOT/$name.exit.txt"
  python3 - "$start" "$end" > "$ROOT/$name.elapsed.txt" <<'PY'
import sys
print(float(sys.argv[2])-float(sys.argv[1]))
PY
  [[ "$rc" == "$expected" ]]
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
integer bad=0
for spec in visible-5s:0 missing-2s:1 notvisible-2s:0 exact-5s:0 no-timeout:0; do
  name=${spec%%:*}; expected=${spec##*:}
  cp "$ROOT/configs/$name.yml" "$A/grantiva.yml"
  runone "$name" "$expected" "$GRANTIVA" diff capture --no-build --simulator "$U1" --verbose --json || bad=$((bad+1))
  if [[ -d "$A/.grantiva/captures" ]]; then mv "$A/.grantiva/captures" "$ROOT/$name-captures"; fi
done
print -r -- "bad=$bad finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( bad == 0 ))
