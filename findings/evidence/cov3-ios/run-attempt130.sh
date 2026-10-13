#!/bin/zsh
set -euo pipefail
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt130"
WORK=/private/tmp/cov3-ios-attempt130
[[ ! -e "$ROOT" && ! -e "$WORK" ]] || exit 73
mkdir -p "$ROOT" "$WORK/.grantiva/baselines" "$WORK/.grantiva/captures"
cp "$0" "$ROOT/harness.sh"
cat >"$WORK/grantiva.yml" <<'YAML'
platform: ios
diff:
  threshold: 1.0
  perceptual_threshold: 5.0
screens:
  - name: Color Boundary
    path: launch
YAML
cp "$WORK/grantiva.yml" "$ROOT/grantiva.yml"
python3 - "$ROOT" "$WORK" <<'PY'
from PIL import Image
import PIL, pathlib,sys
r=pathlib.Path(sys.argv[1]); w=pathlib.Path(sys.argv[2])
Image.new('RGB',(16,16),(100,100,100)).save(w/'.grantiva/baselines/Color Boundary.png')
Image.new('RGB',(16,16),(108,100,100)).save(r/'below-capture.png')
Image.new('RGB',(16,16),(112,100,100)).save(r/'above-capture.png')
(r/'generator.txt').write_text(f'Pillow {PIL.__version__}\nsize=16x16 RGB\nbaseline=(100,100,100)\nbelow=(108,100,100)\nabove=(112,100,100)\n')
PY
cp "$WORK/.grantiva/baselines/Color Boundary.png" "$ROOT/baseline.png"
run_case(){
  local name=$1
  cp "$ROOT/$name-capture.png" "$WORK/.grantiva/captures/Color Boundary.png"
  set +e
  (cd "$WORK" && "$GRANTIVA" diff compare) >"$ROOT/$name.out" 2>"$ROOT/$name.err"; print -r -- $? >"$ROOT/$name.exit"
  (cd "$WORK" && "$GRANTIVA" diff compare --json) >"$ROOT/$name.json" 2>"$ROOT/$name-json.err"; print -r -- $? >"$ROOT/$name-json.exit"
  set -e
}
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- 'device-free deterministic RGB-only fixture'
} >"$ROOT/commands.txt"
run_case below
run_case above
python3 - "$ROOT" <<'PY'
from PIL import Image
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
b=Image.open(r/'baseline.png'); lo=Image.open(r/'below-capture.png'); hi=Image.open(r/'above-capture.png')
assert b.mode==lo.mode==hi.mode=='RGB' and b.size==lo.size==hi.size==(16,16)
assert set(b.getdata())=={(100,100,100)} and set(lo.getdata())=={(108,100,100)} and set(hi.getdata())=={(112,100,100)}
below=json.load(open(r/'below.json'))['screens'][0]; above=json.load(open(r/'above.json'))['screens'][0]
assert int((r/'below.exit').read_text())==0 and int((r/'below-json.exit').read_text())==0
assert below['status']=='passed' and 0 < below['perceptualDistance'] < 5.0,below
assert int((r/'above.exit').read_text())==1 and int((r/'above-json.exit').read_text())==1
assert above['status']=='failed' and above['perceptualDistance'] > 5.0,above
assert above['pixelDiffPercent'] <= above['pixelThreshold'],above
assert 'perceptual_threshold 5.0' in above['message'],above
PY
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
