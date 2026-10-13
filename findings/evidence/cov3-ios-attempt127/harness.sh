#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt127"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt127
U=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
cat >"$A/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
YAML
{
  date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
  shasum -a 256 "$GRANTIVA"
  print -r -- "owned_udid=$U"
  print -r -- 'GRANTIVA_API_KEY explicitly unset'
} >"$ROOT/commands.txt"
(cd "$A" && "$GRANTIVA" diff capture --no-build --simulator "$U" --quiet) >"$ROOT/diff-quiet.out" 2>"$ROOT/diff-quiet.err"; print -r -- $? >"$ROOT/diff-quiet.exit"
(cd "$A" && "$GRANTIVA" ci run --no-build --simulator "$U" --quiet) >"$ROOT/ci-quiet.out" 2>"$ROOT/ci-quiet.err"; print -r -- $? >"$ROOT/ci-quiet.exit"
(cd "$A" && "$GRANTIVA" ci run --no-build --simulator "$U" --json) >"$ROOT/ci-json.out" 2>"$ROOT/ci-json.err"; print -r -- $? >"$ROOT/ci-json.exit"
python3 - "$ROOT" <<'PY' || exit 74
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
assert int((r/'diff-quiet.exit').read_text()) == 0
assert (r/'diff-quiet.out').read_text().strip()
assert int((r/'ci-quiet.exit').read_text()) == 1
assert int((r/'ci-json.exit').read_text()) == 1
t='\n'.join((r/n).read_text() for n in ('ci-quiet.out','ci-quiet.err','ci-json.out','ci-json.err')).lower()
assert 'auth' in t or 'api key' in t, t
j=json.loads((r/'ci-json.out').read_text())
assert isinstance(j,dict) and (j.get('error') or j.get('message')),j
PY
sed -n '186,330p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/CICommand.swift >"$ROOT/CICommand.swift.excerpt"
sed -n '380,450p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/OutputStreamContractTests.swift >"$ROOT/OutputStreamContractTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
