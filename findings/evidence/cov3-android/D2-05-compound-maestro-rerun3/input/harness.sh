#!/bin/zsh
set -euo pipefail

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY

ANDROID_WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android
CLI_SOURCE=/Users/kyle/Developer/grantiva-cli/.worktrees/release-main
OUT="$ANDROID_WT/findings/evidence/cov3-android/D2-05-compound-maestro-rerun3"
WORK=/private/tmp/cov3-android-d2-05-compound-maestro-rerun3
SERIAL=emulator-5554
ADB=/Users/kyle/Library/Android/sdk/platform-tools/adb

[[ -x "$GRANTIVA" && -x "$ADB" && ! -e "$OUT" && ! -e "$WORK" ]] || exit 73
mkdir -p "$OUT/input" "$WORK"
cp "$0" "$OUT/input/harness.sh"
finalize() {
  local status=$?
  print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ) status=$status" >>"$OUT/commands.txt"
  find "$OUT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$OUT/all-files.sha256"
}
trap finalize EXIT

cat >"$WORK/grantiva-android.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- scrollUntilVisible:
    element:
      text: "Deep Links"
    direction: DOWN
    timeout: 5000
- takeScreenshot: "Scrolled"
- runFlow: sub-scalar.yaml
- runFlow:
    file: sub-mapping.yaml
- runFlow:
    commands:
      - launchApp
      - tapOn: "Deep Links"
      - tapOn: "Caching Demo"
      - extendedWaitUntil:
          visible: "Cache Policy"
          timeout: 5000
      - takeScreenshot: "From Inline"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- takeScreenshot: "Main"
YAML

cat >"$WORK/sub-scalar.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- takeScreenshot: "From Scalar"
YAML

cat >"$WORK/sub-mapping.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Favorites"
- takeScreenshot: "From Mapping"
YAML

cp "$WORK/grantiva-android.yml" "$WORK/sub-scalar.yaml" "$WORK/sub-mapping.yaml" "$OUT/input/"
sed -n '1,420p' "$CLI_SOURCE/Tests/GrantivaCoreTests/FlowStagingTests.swift" >"$OUT/FlowStagingTests.swift.excerpt"
sed -n '160,188p' "$CLI_SOURCE/README.md" >"$OUT/README-maestro-compatibility.txt"
sed -n '25,40p' "$CLI_SOURCE/docs/android.md" >"$OUT/docs-android-maestro.txt"
git -C "$CLI_SOURCE" rev-parse HEAD >"$OUT/candidate-head.txt"

# Freeze the intended state-sensitive tail before any device interaction.
python3 - "$WORK/grantiva-android.yml" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
tail = '''      - takeScreenshot: "From Inline"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- takeScreenshot: "Main"
'''
assert s.endswith(tail), repr(s[-len(tail)-80:])
assert '- launchApp\n- extendedWaitUntil:\n    visible: "Featured"' not in s
PY

[[ "$($ADB devices | awk '$2=="device" && $1~/^emulator-/{print $1}')" == "$SERIAL" ]] || exit 74
[[ "$($ADB -s "$SERIAL" emu avd name 2>/dev/null | tr -d '\r' | head -1)" == cov3-android ]] || exit 75

{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  shasum -a 256 "$GRANTIVA" "$OUT/input/"*.y*ml
  print -r -- "cwd=$WORK"
  print -r -- "$GRANTIVA diff capture --platform android --device $SERIAL --no-build --verbose --json"
} >"$OUT/commands.txt"

set +e
(cd "$WORK" && "$GRANTIVA" diff capture --platform android --device "$SERIAL" --no-build --verbose --json) >"$OUT/capture.json" 2>"$OUT/capture.err"
RC=$?
set -e
print -r -- "$RC" >"$OUT/capture.exit"
[[ -d "$WORK/.grantiva/captures/android" ]] && cp -R "$WORK/.grantiva/captures/android" "$OUT/captures" || true

python3 - "$OUT" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); assert int((r/'capture.exit').read_text())==0
d=json.load(open(r/'capture.json')); rows={x['screenName']:x for x in d['screens']}
expected={'Scrolled','From Scalar','From Mapping','From Inline','Main'}
assert set(rows)==expected,(set(rows),expected)
for name,row in rows.items():
 assert pathlib.Path(r/'captures'/f'{name}.png').is_file(),name
 assert row['sizeBytes'] > 0,row
 assert all(x['status']=='passed' for x in row['steps']),(name,row['steps'])
cfg=(r/'input'/'grantiva-android.yml').read_text()
for exact in ('appId: com.kylebrowning.landmarks','- scrollUntilVisible:',
              '    direction: DOWN','    timeout: 5000','- runFlow: sub-scalar.yaml',
              '    file: sub-mapping.yaml','    commands:','- extendedWaitUntil:',
              '    visible: "Cache Policy"'):
 assert exact in cfg,exact
assert '- launchApp\n- extendedWaitUntil:\n    visible: "Featured"' not in cfg
PY
