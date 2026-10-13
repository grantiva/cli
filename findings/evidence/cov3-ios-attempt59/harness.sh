#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt59"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt59-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt59'; exit 73; fi
mkdir -p "$ROOT/configs"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/sub-shot.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- takeScreenshot: FromSub
YAML
cat > "$A/sub-none.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- assertVisible: Landmarks
YAML
cat > "$A/sub-dup.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- takeScreenshot: Main
YAML
cat > "$A/cycle-a.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- runFlow: cycle-b.yaml
YAML
cat > "$A/cycle-b.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- runFlow: cycle-a.yaml
YAML
makecfg() {
  local name="$1" body="$2"
  printf 'appId: com.kylebrowning.Landmarks\n---\n- launchApp\n%s\n- takeScreenshot: Main\n' "$body" > "$ROOT/configs/$name.yml"
}
makecfg scalar '- runFlow: sub-shot.yaml'
makecfg mapping '- runFlow: {file: sub-shot.yaml}'
makecfg inline '- runFlow: {commands: [{takeScreenshot: Inline}]}'
makecfg no-shot '- runFlow: sub-none.yaml'
makecfg missing '- runFlow: absent.yaml'
makecfg cycle '- runFlow: cycle-a.yaml'
makecfg duplicate '- runFlow: sub-dup.yaml'
runone() {
  local name="$1" expected="$2"; shift 2
  cp "$ROOT/configs/$name.yml" "$A/grantiva.yml"
  { print -r -- "cwd=$A"; print -r -- "$*"; } > "$ROOT/$name.command.txt"
  (cd "$A" && "$@") > "$ROOT/$name.out" 2> "$ROOT/$name.err"; local rc=$?
  print -r -- "$rc" > "$ROOT/$name.exit.txt"
  if [[ -d "$A/.grantiva/captures" ]]; then mv "$A/.grantiva/captures" "$ROOT/$name-captures"; fi
  [[ "$rc" == "$expected" ]]
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
integer bad=0
for spec in scalar:0 mapping:0 inline:0 no-shot:0 missing:64 cycle:64 duplicate:64; do
  name=${spec%%:*}; expected=${spec##*:}
  runone "$name" "$expected" "$GRANTIVA" diff capture --no-build --simulator "$U1" --json || bad=$((bad+1))
done
cp -p "$A"/sub-*.yaml "$A"/cycle-*.yaml "$ROOT/"
print -r -- "bad=$bad finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
(( bad == 0 ))
