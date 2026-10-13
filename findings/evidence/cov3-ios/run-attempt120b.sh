#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt120b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
A=/private/tmp/cov3-ios-attempt120b
U=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" && -f "$SRC/.maestro/coverage/02-exact-negative.yaml" ]] || exit 73
mkdir -p "$ROOT"
rsync -a --exclude .grantiva "$SRC/" "$A/"
cp "$0" "$ROOT/harness.sh"
run(){ local name=$1; shift; (cd "$A" && "$@") >"$ROOT/$name.out" 2>"$ROOT/$name.err"; print -r -- $? >"$ROOT/$name.exit"; }
inventory(){ local name=$1; (cd "$A" && find .grantiva -type f -print | sort) >"$ROOT/$name-files.txt"; }
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_udid=$U"
} >"$ROOT/commands.txt"
run pass-run "$GRANTIVA" run --no-build --simulator "$U" --flow .maestro/01-browse.yaml
inventory after-pass-run
run fail-run "$GRANTIVA" run --no-build --simulator "$U" --flow .maestro/coverage/02-exact-negative.yaml
inventory after-fail-run
mkdir -p "$ROOT/run-artifacts"
[[ -d "$A/.grantiva/run-captures" ]] && cp -pR "$A/.grantiva/run-captures/." "$ROOT/run-artifacts/"
run capture "$GRANTIVA" diff capture --no-build --simulator "$U" --json
inventory after-diff-capture
mkdir -p "$A/.grantiva/baselines"
cp "$A/.grantiva/captures/Home.png" "$A/.grantiva/baselines/01-browse-cmd-003-Home.png"
shasum -a 256 "$A/.grantiva/baselines/01-browse-cmd-003-Home.png" >"$ROOT/legacy-before.sha256"
run approve "$GRANTIVA" diff approve
inventory after-approve
shasum -a 256 "$A/.grantiva/baselines/01-browse-cmd-003-Home.png" >"$ROOT/legacy-after.sha256"
run compare "$GRANTIVA" diff compare --json
inventory after-compare
cp -pR "$A/.grantiva" "$ROOT/final-grantiva"
python3 - "$ROOT" <<'PY' || exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
assert int((r/'pass-run.exit').read_text())==0
assert int((r/'fail-run.exit').read_text())==1
assert int((r/'capture.exit').read_text())==0
assert int((r/'approve.exit').read_text())==0
assert int((r/'compare.exit').read_text())==0
assert (r/'legacy-before.sha256').read_text().split()[0]==(r/'legacy-after.sha256').read_text().split()[0]
d=json.loads((r/'compare.out').read_text())
names={x.get('screenName',x.get('screen_name')) for x in d['screens']}
assert names=={'Home','Favorites','Deep Links','Lakes','Detail'},names
assert all('failure-' not in str(x) and 'cmd-' not in str(x) for x in d['screens'])
PY
cp "$A/grantiva.yml" "$ROOT/grantiva.yml"
cp "$A/.maestro/01-browse.yaml" "$ROOT/01-browse.yaml"
cp "$A/.maestro/coverage/02-exact-negative.yaml" "$ROOT/02-exact-negative.yaml"
sed -n '430,500p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md >"$ROOT/README-diff.excerpt"
sed -n '1,320p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/DiffCommandTests.swift >"$ROOT/DiffCommandTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
