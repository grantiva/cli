#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-123b
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt123b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt44-ios/round3\ derived\ data/Build/Products/UITesting-iphonesimulator/Landmarks.app
A=/private/tmp/cov3-ios-attempt123b
NAME='cov3-ios-123b iPhone 17'; U=''; U2=''; HOME1=''; HOME2=''
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
xcrun simctl list devices -j >"$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('name')==sys.argv[2] for a in d['devices'].values() for x in a)
PY
cleanup(){
 for h in "$HOME1" "$HOME2"; do [[ -n "$h" && -e "$h" ]] && chflags -R nouchg "$h" 2>/dev/null || true; done
 "$GRANTIVA" simulator teardown --session-id cov3-ios-123b --force --json >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err" || true
 for u in "$U" "$U2"; do [[ -n "$u" ]] && xcrun simctl delete "$u" 2>/dev/null || true; done
}
trap cleanup EXIT
ensure(){ "$GRANTIVA" simulator ensure --name "$NAME" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json; }
validate_ensure(){ python3 - "$1" "$NAME" <<'PY'
import json,re,sys
d=json.load(open(sys.argv[1])); assert d['name']==sys.argv[2] and d['created'] is True
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',d['udid'])
PY
}
prepare(){ local u=$1; xcrun simctl install "$u" "$APP" || return; (cd "$A" && "$GRANTIVA" run --no-build --simulator "$u" --flow .maestro/01-browse.yaml); }
find_home(){ python3 - "$GRANTIVA_RUNNER_HOME" "$1" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); u=sys.argv[2]
paths=[p for p in root.rglob(u) if p.is_dir() and p.parent.name=='devices' and '/cache/' not in str(p)]
assert len(paths)==1,paths
print(paths[0])
PY
}
ensure >"$ROOT/ensure1.out" 2>"$ROOT/ensure1.err" || exit 75; validate_ensure "$ROOT/ensure1.out" || exit 75; U=$(jq -r .udid "$ROOT/ensure1.out")
prepare "$U" >"$ROOT/prepare1.out" 2>"$ROOT/prepare1.err" || exit 76
HOME1=$(find_home "$U") || exit 77; print -r -- "$HOME1" >"$ROOT/home1-path.txt"
[[ -d "$HOME1" ]] || exit 77
touch "$HOME1/locked"; chflags uchg "$HOME1/locked"; ls -lO "$HOME1/locked" >"$ROOT/locked1.txt"
"$GRANTIVA" simulator teardown --udid "$U" >"$ROOT/teardown-text.out" 2>"$ROOT/teardown-text.err"; print -r -- $? >"$ROOT/teardown-text.exit"
"$GRANTIVA" simulator teardown --udid "$U" --json >"$ROOT/teardown-json.out" 2>"$ROOT/teardown-json.err"; print -r -- $? >"$ROOT/teardown-json.exit"
chflags nouchg "$HOME1/locked"
"$GRANTIVA" simulator teardown --udid "$U" --json >"$ROOT/teardown-clean.out" 2>"$ROOT/teardown-clean.err"; print -r -- $? >"$ROOT/teardown-clean.exit"
ensure >"$ROOT/ensure2.out" 2>"$ROOT/ensure2.err" || exit 78; validate_ensure "$ROOT/ensure2.out" || exit 78; U2=$(jq -r .udid "$ROOT/ensure2.out")
prepare "$U2" >"$ROOT/prepare2.out" 2>"$ROOT/prepare2.err" || exit 79
HOME2=$(find_home "$U2") || exit 80; print -r -- "$HOME2" >"$ROOT/home2-path.txt"
[[ -d "$HOME2" ]] || exit 80
touch "$HOME2/locked"; chflags uchg "$HOME2/locked"; ls -lO "$HOME2/locked" >"$ROOT/locked2.txt"
"$GRANTIVA" simulator delete --name "$NAME" >"$ROOT/delete.out" 2>"$ROOT/delete.err"; print -r -- $? >"$ROOT/delete.exit"
chflags nouchg "$HOME2/locked"; rm -rf "$HOME2"
xcrun simctl list devices -j >"$ROOT/after.json"
python3 - "$ROOT" "$U" "$U2" <<'PY' || exit 81
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); uu=sys.argv[2:]
assert int((r/'teardown-text.exit').read_text())==1
assert int((r/'teardown-json.exit').read_text())==1
assert int((r/'teardown-clean.exit').read_text())==0
assert int((r/'delete.exit').read_text())==0
text=(r/'teardown-text.err').read_text(); assert 'could not be removed:' in text and '. Delete it by hand.' in text and '.. Delete' not in text
d=json.loads((r/'teardown-json.out').read_text()); assert d and d[0]['deviceHomeFailures']
warn=(r/'delete.err').read_text(); assert 'Could not remove the runner home' in warn and '. Delete it by hand.' in warn and '.. Delete' not in warn
devices=json.load(open(r/'after.json')); assert not any(x.get('udid') in uu for a in devices['devices'].values() for x in a)
PY
sed -n '235,270p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/SimulatorCommandTests.swift >"$ROOT/SimulatorCommandTests.swift.excerpt"
sed -n '190,215p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/WDADeviceHomeTests.swift >"$ROOT/WDADeviceHomeTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
