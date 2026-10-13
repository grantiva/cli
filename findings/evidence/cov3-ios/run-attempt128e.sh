#!/bin/zsh
set -euo pipefail
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
SOURCEHOME=/Users/kyle/.grantiva-qa/runner
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt128e"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt128e
CLONE=/private/tmp/cov3-ios-attempt128e-runner-home
U=563907E1-703D-4322-AE5F-FC3B06D03143
export GRANTIVA_RUNNER_HOME="$CLONE" GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
[[ ! -e "$ROOT" && ! -e "$A" && ! -e "$CLONE" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
cp -cR "$SOURCEHOME" "$CLONE"
V=$("$GRANTIVA" runner version --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')
VDIR=$(find "$CLONE/versions" -mindepth 1 -maxdepth 1 -type d -name "$V+android-drivers-*" | head -1)
[[ -n "$VDIR" && -x "$VDIR/grantiva-runner" ]] || exit 74
# Remove only cloned volatile U1 state before proving the run creates its own lease.
rm -f "$CLONE/locks/$U.lock"
print -r -- marker-lock >"$CLONE/locks/cov3-c01-marker.lock"
mkdir -p "$CLONE/reports" "$VDIR/reports"
print -r -- marker-report >"$CLONE/reports/cov3-c01-marker.txt"
print -r -- marker-version-report >"$VDIR/reports/cov3-c01-marker.txt"
RUNPID=''
cleanup(){ if [[ -n "$RUNPID" ]] && kill -0 "$RUNPID" 2>/dev/null; then kill -INT "$RUNPID" 2>/dev/null || true; wait "$RUNPID" 2>/dev/null || true; fi; }
trap cleanup EXIT
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
(cd "$A" && exec "$GRANTIVA" run --no-build --simulator "$U" --flow .maestro/11-slow.yaml) >"$ROOT/slow.out" 2>"$ROOT/slow.err" & RUNPID=$!
for n in {1..300}; do
  if [[ -e "$CLONE/locks/$U.lock" ]] && kill -0 "$RUNPID" 2>/dev/null && rg -q '✓ launchApp' "$ROOT/slow.err"; then
    ps -axo pid=,ppid=,state=,command= >"$ROOT/processes-poll.txt"
    RPID=$(python3 - "$CLONE/locks/$U.lock" "$ROOT/processes-poll.txt" "$RUNPID" <<'PY1' 2>/dev/null || true
import json,sys
claim=json.load(open(sys.argv[1])); parent=int(sys.argv[3])
assert claim.get('pid')==parent,claim
rows=[]
for line in open(sys.argv[2],errors='replace'):
 p=line.strip().split(None,3)
 if len(p)==4:
  try: rows.append((int(p[0]),int(p[1]),p[2],p[3]))
  except ValueError: pass
children={}
for pid,ppid,state,cmd in rows: children.setdefault(ppid,[]).append(pid)
desc=set(); todo=[parent]
while todo:
 x=todo.pop()
 for c in children.get(x,[]):
  if c not in desc: desc.add(c); todo.append(c)
hits=[pid for pid,ppid,state,cmd in rows if pid in desc and 'grantiva-runner' in cmd]
if len(hits)==1: print(hits[0])
PY1
)
    if [[ -n "$RPID" ]] && kill -0 "$RPID" 2>/dev/null; then
      print -r -- "$n" >"$ROOT/active-flow-observed-poll.txt"; break
    fi
  fi
  sleep 0.1
done
[[ -e "$CLONE/locks/$U.lock" && -n "${RPID:-}" ]] && kill -0 "$RUNPID" && kill -0 "$RPID" || exit 75
cp "$CLONE/locks/$U.lock" "$ROOT/active-lease-before.json"
stat -f '%i %N' "$CLONE/locks/$U.lock" >"$ROOT/active-lease-before.inode"
ps -p "$RUNPID,$RPID" -o pid=,ppid=,state=,command= >"$ROOT/active-processes-before.txt"
{
 shasum -a 256 "$CLONE/locks/cov3-c01-marker.lock"
 shasum -a 256 "$CLONE/reports/cov3-c01-marker.txt" "$VDIR/reports/cov3-c01-marker.txt"
 shasum -a 256 "$CLONE/grantiva-wda.xcconfig" "$VDIR/grantiva-wda.xcconfig"
} >"$ROOT/preserved-before.sha256"
shasum -a 256 "$VDIR/grantiva-runner" "$VDIR/version" >"$ROOT/replaced-before.sha256"
rm "$VDIR/version"
"$GRANTIVA" runner install --json >"$ROOT/reextract-during-lease.out" 2>"$ROOT/reextract-during-lease.err"
kill -0 "$RUNPID" && kill -0 "$RPID"; print -r -- $? >"$ROOT/run-alive-after-install.exit"
cp "$CLONE/locks/$U.lock" "$ROOT/active-lease-after.json"
stat -f '%i %N' "$CLONE/locks/$U.lock" >"$ROOT/active-lease-after.inode"
ps -p "$RUNPID,$RPID" -o pid=,ppid=,state=,command= >"$ROOT/active-processes-after.txt"
{
 shasum -a 256 "$CLONE/locks/cov3-c01-marker.lock"
 shasum -a 256 "$CLONE/reports/cov3-c01-marker.txt" "$VDIR/reports/cov3-c01-marker.txt"
 shasum -a 256 "$CLONE/grantiva-wda.xcconfig" "$VDIR/grantiva-wda.xcconfig"
} >"$ROOT/preserved-after.sha256"
shasum -a 256 "$VDIR/grantiva-runner" "$VDIR/version" >"$ROOT/replaced-after.sha256"
cmp "$ROOT/preserved-before.sha256" "$ROOT/preserved-after.sha256" >"$ROOT/preserved.cmp"
wait "$RUNPID"; print -r -- $? >"$ROOT/slow.exit"; RUNPID=''
python3 - "$ROOT" "$VDIR" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); v=pathlib.Path(sys.argv[2])
assert int((r/'run-alive-after-install.exit').read_text()) == 0
assert int((r/'slow.exit').read_text()) == 0
x=json.load(open(r/'reextract-during-lease.out')); assert x.get('extracted') is True,x
assert (v/'version').is_file() and (v/'drivers').is_dir()
assert (r/'preserved.cmp').read_text()==''
assert (r/'active-lease-before.inode').read_text()==(r/'active-lease-after.inode').read_text()
b=json.load(open(r/'active-lease-before.json')); a=json.load(open(r/'active-lease-after.json'))
assert b.get('pid')==a.get('pid') and isinstance(a.get('pid'),int),(b,a)
PY
sed -n '1,300p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/RunnerManagerTests.swift >"$ROOT/RunnerManagerTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
