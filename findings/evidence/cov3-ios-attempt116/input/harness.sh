#!/bin/zsh
set -euo pipefail

GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
SOURCE=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/mcp082-pipelined-harness/pipelined_client.py
PROJECT=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
ROOT="$WT/findings/evidence/cov3-ios-attempt116"
[[ -x "$GRANTIVA" && -f "$SOURCE" && -f "$PROJECT/grantiva.yml" && ! -e "$ROOT" ]] || exit 73
mkdir -p "$ROOT/input"
cp "$SOURCE" "$ROOT/input/pipelined_client.py"
cp "$0" "$ROOT/input/harness.sh"
cp "$PROJECT/grantiva.yml" "$ROOT/input/grantiva.yml"
{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  print -r -- "platform=ios"
  print -r -- "project=$PROJECT"
  shasum -a 256 "$GRANTIVA" "$ROOT/input/pipelined_client.py" "$PROJECT/grantiva.yml"
  "$GRANTIVA" --version
  git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD
} >"$ROOT/provenance.txt"
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-116
unset GRANTIVA_API_KEY
python3 -I "$ROOT/input/pipelined_client.py" "$ROOT/run" "$PROJECT" ios "$GRANTIVA"
rg -n '\$ (xcrun simctl list devices|xcodebuild -version)' "$ROOT/run/server.stderr" >"$ROOT/subprocess-debug-lines.txt"
sed -n '1,180p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaMCP/Tools/ContextTool.swift >"$ROOT/input/ContextTool.swift.excerpt"
sed -n '1,125p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Shell.swift >"$ROOT/input/Shell.swift.excerpt"
sed -n '1,40p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/ShellQuotingTests.swift >"$ROOT/input/ShellQuotingTests.swift.excerpt"
jq -e '
  has("mcp082-init") and has("mcp082-ios-context") and has("mcp082-ios-list")
' "$ROOT/run/responses.json" >"$ROOT/id-audit.txt"
python3 - "$ROOT/run/events.jsonl" <<'PY'
import json,sys
events=[json.loads(x) for x in open(sys.argv[1])]
w=next(i for i,x in enumerate(events) if x.get('label')=='pipelined-context-then-list')
ids={'mcp082-ios-context','mcp082-ios-list'}
r=[i for i,x in enumerate(events) if x.get('kind')=='response' and x.get('id') in ids]
assert len(r)==2 and all(i>w for i in r)
PY
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/provenance.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
