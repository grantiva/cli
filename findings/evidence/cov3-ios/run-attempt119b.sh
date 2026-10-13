#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt119b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt119b
U=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" && -f "$SRC/.maestro/08-caching.yaml" && -f "$SRC/.maestro/99-crash.yaml" ]] || exit 73
mkdir -p "$ROOT"
rsync -a --exclude .grantiva "$SRC/" "$A/"
cp "$0" "$ROOT/harness.sh"
cleanup(){ (cd "$A" && "$GRANTIVA" runner stop --json) >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err" || true; }
trap cleanup EXIT
snapshot_ps(){ ps -axo pid=,ppid=,state=,command= >"$ROOT/$1-processes.txt"; }
run_case(){
  local name=$1; shift
  (cd "$A" && "$GRANTIVA" run --no-build --simulator "$U" "$@") >"$ROOT/$name.out" 2>"$ROOT/$name.err"
  print -r -- $? >"$ROOT/$name.exit"
  snapshot_ps "$name-after"
}
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
snapshot_ps before
run_case success-verbose --flow .maestro/08-caching.yaml --logs --verbose
run_case success-plain --flow .maestro/08-caching.yaml --logs
run_case failure-verbose --flow .maestro/99-crash.yaml --logs --verbose
(cd "$A" && exec "$GRANTIVA" run --no-build --simulator "$U" --flow .maestro/11-slow.yaml --logs --verbose) >"$ROOT/sigint.out" 2>"$ROOT/sigint.err" &
P=$!
print -r -- "$P" >"$ROOT/sigint.pid"
seen=0
for n in {1..100}; do
  snapshot_ps "sigint-poll-$n"
  if kill -0 "$P" 2>/dev/null && rg -qi "simctl.*log stream.*($U|Landmarks|com\.kylebrowning)" "$ROOT/sigint-poll-$n-processes.txt"; then seen=1; break; fi
  sleep 0.1
done
print -r -- "$seen" >"$ROOT/sigint-active-observed"
[[ $seen == 1 ]] || { kill -INT "$P" 2>/dev/null || true; wait "$P" 2>/dev/null || true; exit 74; }
kill -INT "$P"
wait "$P"; rc=$?
print -r -- "$rc" >"$ROOT/sigint.exit"
snapshot_ps sigint-after
sleep 2
snapshot_ps sigint-after-2s
python3 - "$ROOT" "$U" <<'PY' || exit 75
import pathlib,re,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2]
assert int((r/'success-verbose.exit').read_text())==0
assert int((r/'success-plain.exit').read_text())==0
assert int((r/'failure-verbose.exit').read_text())==1
assert int((r/'sigint.exit').read_text())==130
for name in ('success-verbose-after','success-plain-after','failure-verbose-after','sigint-after','sigint-after-2s'):
 lines=(r/f'{name}-processes.txt').read_text().splitlines()
 bad=[x for x in lines if re.search(r'log\s+stream',x,re.I) and (u in x or 'Landmarks' in x or 'com.kylebrowning' in x)]
 assert not bad,(name,bad)
PY
cp "$A/grantiva.yml" "$ROOT/grantiva.yml"
cp "$A/.maestro/08-caching.yaml" "$ROOT/08-caching.yaml"
cp "$A/.maestro/99-crash.yaml" "$ROOT/99-crash.yaml"
cp "$A/.maestro/11-slow.yaml" "$ROOT/11-slow.yaml"
sed -n '1,240p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/ChildProcessTests.swift >"$ROOT/ChildProcessTests.swift.excerpt"
sed -n '1,260p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/LogStreamerTests.swift >"$ROOT/LogStreamerTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
