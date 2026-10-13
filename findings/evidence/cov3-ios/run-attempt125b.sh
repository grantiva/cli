#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt125b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt125b
U=563907E1-703D-4322-AE5F-FC3B06D03143
RPID=''; STOPPED=0
[[ ! -e "$ROOT" && ! -e "$A" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
cleanup(){ [[ $STOPPED == 1 && -n "$RPID" ]] && kill -CONT "$RPID" 2>/dev/null || true; (cd "$A" && "$GRANTIVA" runner stop --json) >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err" || true; }
trap cleanup EXIT
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
(cd "$A" && "$GRANTIVA" runner start --detach --json --bundle-id com.kylebrowning.Landmarks --simulator "$U" --platform ios) >"$ROOT/start.out" 2>"$ROOT/start.err"; print -r -- $? >"$ROOT/start.exit"
READY=0
for n in {1..60}; do (cd "$A" && "$GRANTIVA" hierarchy --format json) >"$ROOT/ready-$n.out" 2>"$ROOT/ready-$n.err" && rg -q Landmarks "$ROOT/ready-$n.out" && { READY=1; break; }; sleep 0.5; done
[[ $READY == 1 ]] || exit 73
python3 - "$ROOT/start.out" <<'PY' >"$ROOT/runner.pid" || exit 74
import json,sys
d=json.load(open(sys.argv[1])); p=d.get('runnerPid',d.get('runner_pid',d.get('pid'))); assert isinstance(p,int) and p>1; print(p)
PY
RPID=$(cat "$ROOT/runner.pid"); kill -0 "$RPID" || exit 75
xcrun simctl listapps "$U" >"$ROOT/listapps-openstep.plist" 2>"$ROOT/listapps.err" || exit 76
plutil -convert xml1 -o "$ROOT/listapps.xml" "$ROOT/listapps-openstep.plist" || exit 76
python3 - "$ROOT/listapps.xml" <<'PY' >"$ROOT/wda-bundle-id.txt" || exit 77
import plistlib,sys
d=plistlib.load(open(sys.argv[1],'rb'))
m=[k for k,v in d.items() if 'WebDriverAgentRunner' in k or 'WebDriverAgentRunner' in str(v)]
assert len(m)==1,m
print(m[0])
PY
WDA=$(cat "$ROOT/wda-bundle-id.txt")
kill -STOP "$RPID"; STOPPED=1
xcrun simctl terminate "$U" "$WDA" >"$ROOT/terminate.out" 2>"$ROOT/terminate.err"; print -r -- $? >"$ROOT/terminate.exit"
kill -0 "$RPID"; print -r -- $? >"$ROOT/runner-alive-stopped.exit"
(cd "$A" && "$GRANTIVA" hierarchy --format json) >"$ROOT/dead-agent.out" 2>"$ROOT/dead-agent.err"; print -r -- $? >"$ROOT/dead-agent.exit"
kill -CONT "$RPID"; STOPPED=0
(cd "$A" && "$GRANTIVA" runner stop --json) >"$ROOT/stop.out" 2>"$ROOT/stop.err"; print -r -- $? >"$ROOT/stop.exit"
python3 - "$ROOT" <<'PY' || exit 78
import pathlib,sys
r=pathlib.Path(sys.argv[1])
assert int((r/'start.exit').read_text())==0
assert int((r/'terminate.exit').read_text())==0
assert int((r/'runner-alive-stopped.exit').read_text())==0
assert int((r/'dead-agent.exit').read_text())==1
text=(r/'dead-agent.err').read_text()+(r/'dead-agent.out').read_text()
assert ('did not answer' in text or 'connect' in text.lower()) and 'port' in text.lower(),text
assert int((r/'stop.exit').read_text())==0
PY
sed -n '1,260p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/HierarchyCommandTests.swift >"$ROOT/HierarchyCommandTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
