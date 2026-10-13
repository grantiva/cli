#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt124"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt124/project
B=/private/tmp/cov3-ios-attempt124/other-cwd
U=563907E1-703D-4322-AE5F-FC3B06D03143
GLOBAL=/tmp/grantiva-sessions
[[ ! -e "$ROOT" && ! -e /private/tmp/cov3-ios-attempt124 ]] || exit 73
mkdir -p "$ROOT" "$A" "$B"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
cleanup(){ (cd "$B" && "$GRANTIVA" simulator teardown --udid "$U" --force --json) >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err" || true; }
trap cleanup EXIT
find_owner(){ python3 - "$GLOBAL" "$A" "$U" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); project=str(pathlib.Path(sys.argv[2]).resolve()); u=sys.argv[3]
for p in root.glob('*.owner.json'):
 try:d=json.load(open(p))
 except:continue
 if d.get('projectDirectory')==project and d.get('udid')==u: print(p); raise SystemExit
raise SystemExit(1)
PY
}
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
for i in 1 2 3; do
 (cd "$A" && exec "$GRANTIVA" runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U" --platform ios) >"$ROOT/$i-start.out" 2>"$ROOT/$i-start.err" &
 P=$!; print -r -- "$P" >"$ROOT/$i-parent.pid"
 OWNER=''
 for n in {1..300}; do OWNER=$(find_owner 2>/dev/null || true); [[ -n "$OWNER" ]] && break; kill -0 "$P" 2>/dev/null || break; sleep 0.1; done
 [[ -n "$OWNER" ]] || { kill -INT "$P" 2>/dev/null || true; wait "$P" 2>/dev/null || true; exit 74; }
 cp "$OWNER" "$ROOT/$i-owner.json"; RPID=${OWNER:t:r:r}; print -r -- "$RPID" >"$ROOT/$i-runner.pid"
 (cd "$B" && "$GRANTIVA" simulator teardown --udid "$U" --force --json) >"$ROOT/$i-teardown.out" 2>"$ROOT/$i-teardown.err"; print -r -- $? >"$ROOT/$i-teardown.exit"
 wait "$P"; print -r -- $? >"$ROOT/$i-start.exit"
 clean=0
 for n in {1..100}; do
   ps -axo pid=,ppid=,state=,command= >"$ROOT/$i-ps-$n.txt"
   files=("$GLOBAL"/$RPID*(N)); bad=$(rg -i "$U.*(grantiva-runner|xcodebuild|simctl +diagnose)|(grantiva-runner|xcodebuild|simctl +diagnose).*$U" "$ROOT/$i-ps-$n.txt" || true)
   [[ ${#files} == 0 && -z "$bad" ]] && { clean=1; break; }
   sleep 0.1
 done
 print -r -- "$clean" >"$ROOT/$i-clean"
done
python3 - "$ROOT" <<'PY' || exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
for i in range(1,4):
 assert int((r/f'{i}-teardown.exit').read_text())==0
 assert int((r/f'{i}-start.exit').read_text())==0
 assert (r/f'{i}-clean').read_text().strip()=='1'
 text=(r/f'{i}-start.out').read_text()+(r/f'{i}-start.err').read_text()
 assert 'Runner stopped by teardown' in text and 'session has ended' in text
 d=json.load(open(r/f'{i}-teardown.out')); assert d and d[0]['udid']=='563907E1-703D-4322-AE5F-FC3B06D03143'
PY
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
