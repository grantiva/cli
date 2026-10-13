#!/bin/zsh
set -euo pipefail

GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
ANDROID_EVIDENCE=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android
SOURCE_CORPUS="$ANDROID_EVIDENCE/MCP032-037-configless-build-run-rerun1/project/.grantiva"
BASELINE_SOURCE="$SOURCE_CORPUS/baselines/android/Home.png"
CAPTURE_SOURCE="$SOURCE_CORPUS/captures/android/Deep Links.png"
CLI_SOURCE=/Users/kyle/Developer/grantiva-cli/.worktrees/release-main
OUT="$ANDROID_EVIDENCE/B2-K108-threshold-wording-devicefree-rerun1"
WORK=/private/tmp/cov3-android-b2-k108-devicefree-rerun1

[[ -x "$GRANTIVA" && -f "$BASELINE_SOURCE" && -f "$CAPTURE_SOURCE" ]] || exit 72
[[ ! -e "$OUT" && ! -e "$WORK" ]] || exit 73
mkdir -p "$OUT/input" "$WORK/.grantiva/baselines/android" "$WORK/.grantiva/captures/android"
cp "$0" "$OUT/input/harness.sh"
cp "$BASELINE_SOURCE" "$WORK/.grantiva/baselines/android/Probe.png"
cp "$CAPTURE_SOURCE" "$WORK/.grantiva/captures/android/Probe.png"
cp "$BASELINE_SOURCE" "$OUT/input/baseline-Home-as-Probe.png"
cp "$CAPTURE_SOURCE" "$OUT/input/capture-Deep-Links-as-Probe.png"

write_config() {
  local pixel=$1 perceptual=$2
  cat > "$WORK/grantiva-android.yml" <<EOF
application_id: com.kylebrowning.landmarks
emulator: cov3-android
screens:
  - name: Probe
    path: launch
diff:
  threshold: $pixel
  perceptual_threshold: $perceptual
EOF
}

run_compare() {
  local name=$1 pixel=$2 perceptual=$3
  write_config "$pixel" "$perceptual"
  cp "$WORK/grantiva-android.yml" "$OUT/$name-grantiva-android.yml"
  set +e
  (cd "$WORK" && "$GRANTIVA" diff compare --platform android) >"$OUT/$name-text.out" 2>"$OUT/$name-text.err"
  print -r -- $? >"$OUT/$name-text.exit"
  (cd "$WORK" && "$GRANTIVA" diff compare --platform android --json) >"$OUT/$name-json.out" 2>"$OUT/$name-json.err"
  print -r -- $? >"$OUT/$name-json.exit"
  set -e
}

{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  shasum -a 256 "$GRANTIVA" "$BASELINE_SOURCE" "$CAPTURE_SOURCE"
  sips -g pixelWidth -g pixelHeight "$BASELINE_SOURCE" "$CAPTURE_SOURCE"
  print -r -- 'device-free: diff compare only against copied retained PNGs'
} >"$OUT/commands.txt"

# First measure this exact retained pair under thresholds guaranteed to pass.
run_compare metrics 1.0 1000.0

read PIXEL PERCEPTUAL <<EOF
$(python3 - "$OUT/metrics-json.out" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); row=d['screens'][0]
print(row['pixelDiffPercent'],row['perceptualDistance'])
PY
)
EOF

# Config pixel threshold is a fraction; JSON/text pixelDiffPercent is a percent.
read PIXEL_LOW PIXEL_HIGH PERCEPTUAL_LOW PERCEPTUAL_HIGH <<EOF
$(python3 - "$PIXEL" "$PERCEPTUAL" <<'PY'
import sys
p=float(sys.argv[1]); q=float(sys.argv[2])
assert p > 0 and q > 0,(p,q)
print(max(p/200.0,0.0000001), min(p/100.0+0.01,1.0), max(q/2.0,0.0001), q+1.0)
PY
)
EOF

run_compare pixel-only "$PIXEL_LOW" "$PERCEPTUAL_HIGH"
run_compare perceptual-only "$PIXEL_HIGH" "$PERCEPTUAL_LOW"
run_compare both "$PIXEL_LOW" "$PERCEPTUAL_LOW"

python3 - "$OUT" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
for name in ('pixel-only','perceptual-only','both'):
    assert int((r/f'{name}-text.exit').read_text()) == 1,name
    assert int((r/f'{name}-json.exit').read_text()) == 1,name
    doc=json.loads((r/f'{name}-json.out').read_text())
    row=next(x for x in doc['screens'] if x['screenName']=='Probe')
    assert row['status']=='failed',(name,row)
    msg=row['message']
    if name in ('pixel-only','both'):
        assert 'exceeds threshold' in msg and '%' in msg,(name,msg)
    if name in ('perceptual-only','both'):
        assert 'exceeds perceptual_threshold' in msg,(name,msg)
    rendered=(r/f'{name}-text.out').read_text()+(r/f'{name}-text.err').read_text()
    assert msg.removeprefix('Failed: ') in rendered,(name,msg)
    required={'status','message','screenName','screen_name','baselinePath','baseline_path',
              'capturePath','capture_path','pixelDiffPercent','pixel_diff_percent',
              'pixelThreshold','pixel_threshold','perceptualDistance','perceptual_distance',
              'perceptualThreshold','perceptual_threshold'}
    assert required <= set(row),(name,required-set(row))
PY

sed -n '1,280p' "$CLI_SOURCE/Tests/GrantivaCLITests/DiffCommandTests.swift" >"$OUT/DiffCommandTests.swift.excerpt"
sed -n '1,320p' "$CLI_SOURCE/Tests/GrantivaCLITests/CIComparisonPipelineTests.swift" >"$OUT/CIComparisonPipelineTests.swift.excerpt"
git -C "$CLI_SOURCE" rev-parse HEAD >"$OUT/candidate-head.txt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$OUT/commands.txt"
find "$OUT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$OUT/all-files.sha256"

