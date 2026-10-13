#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt69b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; P="$BASE/attempt69b-pass"; F="$BASE/attempt69b-fail"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$P" || -e "$F" ]]; then print -u2 'refusing overwrite attempt69b'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$P/"; rsync -a --exclude '.grantiva' "$SRC/" "$F/"
python3 - "$F/grantiva.yml" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
s,n=re.subn(r'(?m)^flows:\n(?:  - .*\n)+', 'flows:\n  - .maestro/coverage/02-exact-negative.yaml\n', s, count=1)
assert n==1 and s.count('  - name:')==5 and '\nscreens:\n' in s and '\ndiff:\n' in s
p.write_text(s)
PY
cp "$P/grantiva.yml" "$ROOT/pass-grantiva.yml"; cp "$F/grantiva.yml" "$ROOT/fail-grantiva.yml"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'D2-02 stock screens+flows combined run; explicit report-dir and ready-file in both pass and fail.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
(cd "$P" && "$GRANTIVA" run --no-build --simulator "$U1" --platform ios --snapshot full --ready-file "$ROOT/pass.ready" --report-dir "$ROOT/pass-report" > "$ROOT/pass.out" 2> "$ROOT/pass.err"); print -r -- "$?" > "$ROOT/pass.exit.txt"
(cd "$F" && "$GRANTIVA" run --no-build --simulator "$U1" --platform ios --ready-file "$ROOT/fail.ready" --report-dir "$ROOT/fail-report" > "$ROOT/fail.out" 2> "$ROOT/fail.err"); print -r -- "$?" > "$ROOT/fail.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json,sys
r=Path(sys.argv[1]); bad=[]
if int((r/'pass.exit.txt').read_text())!=0:bad.append('pass')
if int((r/'fail.exit.txt').read_text())==0:bad.append('fail')
assert (r/'pass-grantiva.yml').read_text().count('  - name:')==5
assert (r/'fail-grantiva.yml').read_text().count('  - name:')==5
for n in ['pass','fail']:
 try:j=json.load(open(r/f'{n}.ready'))
 except Exception as e:bad.append((n,'ready',str(e)));continue
 if j.get('reportDir') != str(r/f'{n}-report'):bad.append((n,'reportDir',j.get('reportDir')))
 if not (r/f'{n}-report').is_dir():bad.append((n,'missing-report'))
print(bad);raise SystemExit(bool(bad))
PY
