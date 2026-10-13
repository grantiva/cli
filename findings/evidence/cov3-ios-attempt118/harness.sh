#!/bin/zsh
set -euo pipefail
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt118"
SRC="$WT/findings/evidence/cov3-ios-attempt19/snapshots/threshold-after-recapture"
WORK=/private/tmp/cov3-ios-attempt118
[[ -x "$GRANTIVA" && -d "$SRC/baselines" && -d "$SRC/captures" && ! -e "$ROOT" && ! -e "$WORK" ]] || exit 73
mkdir -p "$ROOT" "$WORK/.grantiva"
cp "$0" "$ROOT/harness.sh"
cp -R "$SRC/baselines" "$SRC/captures" "$WORK/.grantiva/"
cp "$SRC/grantiva.yml" "$WORK/grantiva.yml"
cp -R "$WORK/.grantiva" "$ROOT/input-corpus"
cp "$WORK/grantiva.yml" "$ROOT/input-grantiva.yml"
run_case() {
  local name=$1 pixel=$2 perceptual=$3
  python3 - "$WORK/grantiva.yml" "$pixel" "$perceptual" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
s=re.sub(r'(?m)^  threshold: .*$',f'  threshold: {sys.argv[2]}',s)
s=re.sub(r'(?m)^  perceptual_threshold: .*$',f'  perceptual_threshold: {sys.argv[3]}',s)
p.write_text(s)
PY
  cp "$WORK/grantiva.yml" "$ROOT/$name-grantiva.yml"
  set +e
  (cd "$WORK" && "$GRANTIVA" diff compare) >"$ROOT/$name-text.out" 2>"$ROOT/$name-text.err"
  print -r -- $? >"$ROOT/$name-text.exit"
  (cd "$WORK" && "$GRANTIVA" diff compare --json) >"$ROOT/$name-json.out" 2>"$ROOT/$name-json.err"
  print -r -- $? >"$ROOT/$name-json.exit"
  set -e
}
{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  shasum -a 256 "$GRANTIVA"
  print -r -- 'frozen corpus: attempt19 exact baseline/capture pair'
} >"$ROOT/commands.txt"
run_case perceptual-only 0.02 5.0
run_case pixel-only 0.0001 80.0
run_case both 0.0001 5.0
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
want={'perceptual-only':'perceptual_threshold','pixel-only':'threshold','both':'perceptual_threshold'}
for name,needle in want.items():
 assert int((r/f'{name}-text.exit').read_text())==1
 assert int((r/f'{name}-json.exit').read_text())==1
 d=json.loads((r/f'{name}-json.out').read_text())
 failed=[x for x in d['screens'] if x['status']=='failed']
 assert failed and needle in failed[0]['message'],(name,failed)
 text=(r/f'{name}-text.out').read_text()+(r/f'{name}-text.err').read_text()
 assert failed[0]['message'].removeprefix('Failed: ') in text
both=json.loads((r/'both-json.out').read_text())
msg=next(x['message'] for x in both['screens'] if x['status']=='failed')
assert 'threshold' in msg and 'perceptual_threshold' in msg,msg
PY
sed -n '1,260p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/DiffCommandTests.swift >"$ROOT/DiffCommandTests.swift.excerpt"
sed -n '1,280p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/CIComparisonPipelineTests.swift >"$ROOT/CIComparisonPipelineTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
