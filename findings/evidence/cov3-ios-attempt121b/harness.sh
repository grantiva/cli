#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt121b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt121b
U=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" && -f "$SRC/grantiva.yml" ]] || exit 73
mkdir -p "$ROOT"
rsync -a --exclude .grantiva "$SRC/" "$A/"
cp "$0" "$ROOT/harness.sh"
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
 print -r -- 'command=grantiva diff capture --no-build --simulator <U> --json --verbose'
} >"$ROOT/commands.txt"
(cd "$A" && exec "$GRANTIVA" diff capture --no-build --simulator "$U" --json --verbose) >"$ROOT/capture.out" 2>"$ROOT/capture.err" &
P=$!
print -r -- "$P" >"$ROOT/client.pid"
REPORT=''; integer copies=0
mkdir -p "$ROOT/latest-flows"
for n in {1..10000}; do
  if [[ -z "$REPORT" ]]; then
    line=$(rg -m1 '\$ .*grantiva-runner --platform ios .* --output ' "$ROOT/capture.err" 2>/dev/null || true)
    if [[ -n "$line" ]]; then
      print -r -- "$line" >"$ROOT/runner-command-line.txt"
      REPORT=$(python3 - "$line" <<'PY'
import shlex,sys
a=shlex.split(sys.argv[1].split('$ ',1)[-1]); print(a[a.index('--output')+1])
PY
)
      print -r -- "$REPORT" >"$ROOT/report-path.txt"
      [[ "$line" == *"--device $U"* || "$line" == *"--simulator $U"* ]] || { kill -INT "$P" 2>/dev/null || true; wait "$P" 2>/dev/null || true; exit 74; }
      [[ "$REPORT" == /var/folders/*/T/grantiva-report-* || "$REPORT" == /private/var/folders/*/T/grantiva-report-* ]] || { kill -INT "$P" 2>/dev/null || true; wait "$P" 2>/dev/null || true; exit 75; }
    fi
  fi
  if [[ -n "$REPORT" && -d "$REPORT" ]]; then
    ((copies++))
    [[ -f "$REPORT/report.json" ]] && cp "$REPORT/report.json" "$ROOT/latest-report.json"
    for f in "$REPORT"/flows/flow-*.json(N); do cp "$f" "$ROOT/latest-flows/${f:t}"; done
  fi
  kill -0 "$P" 2>/dev/null || break
  sleep 0.02
done
wait "$P"; rc=$?
if [[ -n "$REPORT" && -d "$REPORT" ]]; then
  [[ -f "$REPORT/report.json" ]] && cp "$REPORT/report.json" "$ROOT/latest-report.json"
  for f in "$REPORT"/flows/flow-*.json(N); do cp "$f" "$ROOT/latest-flows/${f:t}"; done
fi
print -r -- "$rc" >"$ROOT/capture.exit"
print -r -- "copies=$copies" >>"$ROOT/commands.txt"
[[ $rc == 0 && -s "$ROOT/latest-report.json" && -s "$ROOT/latest-flows/flow-000.json" ]] || exit 76
cp -pR "$A/.grantiva" "$ROOT/final-grantiva"
python3 - "$ROOT" <<'PY' || exit 77
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); out=json.loads((r/'capture.out').read_text()); rep=json.loads((r/'latest-report.json').read_text())
assert out['passed'] is True
assert len(out['screens'])==5
assert rep
assert len(list((r/'latest-flows').glob('flow-*.json')))==len(rep['flows'])==5
assert all(s.get('steps') for s in out['screens'])
assert all(step.get('status') in ('passed','failed','skipped') for s in out['screens'] for step in s['steps'])
assert all(step.get('duration') is None or step['duration']>0 for s in out['screens'] for step in s['steps'])
PY
sed -n '44,100p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/RunnerReportContractTests.swift >"$ROOT/RunnerReportContractTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
