#!/bin/zsh
set -euo pipefail
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
SOURCEHOME=/Users/kyle/.grantiva-qa/runner
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt128b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt128b
CLONE=/private/tmp/cov3-ios-attempt128b-runner-home
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
for n in {1..120}; do
  if [[ -e "$CLONE/locks/$U.lock" ]] && kill -0 "$RUNPID" 2>/dev/null; then print -r -- "$n" >"$ROOT/lease-observed-poll.txt"; break; fi
  sleep 0.1
done
[[ -e "$CLONE/locks/$U.lock" ]] && kill -0 "$RUNPID" || exit 75
cp "$CLONE/locks/$U.lock" "$ROOT/active-lease-before.json"
{
 shasum -a 256 "$CLONE/locks/$U.lock" "$CLONE/locks/cov3-c01-marker.lock"
 shasum -a 256 "$CLONE/reports/cov3-c01-marker.txt" "$VDIR/reports/cov3-c01-marker.txt"
 shasum -a 256 "$CLONE/grantiva-wda.xcconfig" "$VDIR/grantiva-wda.xcconfig"
} >"$ROOT/preserved-before.sha256"
shasum -a 256 "$VDIR/grantiva-runner" "$VDIR/version" >"$ROOT/replaced-before.sha256"
rm "$VDIR/version"
"$GRANTIVA" runner install --json >"$ROOT/reextract-during-lease.out" 2>"$ROOT/reextract-during-lease.err"
kill -0 "$RUNPID"; print -r -- $? >"$ROOT/run-alive-after-install.exit"
{
 shasum -a 256 "$CLONE/locks/$U.lock" "$CLONE/locks/cov3-c01-marker.lock"
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
PY
sed -n '1,300p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/RunnerManagerTests.swift >"$ROOT/RunnerManagerTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
