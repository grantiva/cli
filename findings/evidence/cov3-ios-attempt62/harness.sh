#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt62"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt62-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt62'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
 echo 'X-013 exact text start/stop, JSON start/stop, then no-session JSON stop.'
 echo 'X-017 exact doctor --platform ios/android in text and JSON, without quiet.'
 echo 'X-024 exact flow 08 with --logs on explicit owned U1.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
run() {
 local name="$1"; shift
 print -r -- "$GRANTIVA $*" > "$ROOT/$name.command.txt"
 (cd "$A" && "$GRANTIVA" "$@" > "$ROOT/$name.out" 2> "$ROOT/$name.err"); print -r -- "$?" > "$ROOT/$name.exit.txt"
}
run start-text runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach
run stop-text runner stop
run start-json runner start --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach --json
run stop-json runner stop --json
run stop-no-session-json runner stop --json
run doctor-ios-text doctor --platform ios
run doctor-ios-json doctor --platform ios --json
run doctor-android-text doctor --platform android
run doctor-android-json doctor --platform android --json
run logs-flow08 run --no-build --flow .maestro/08-caching.yaml --simulator "$U1" --logs --report-dir "$ROOT/logs-report"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1])
expected={'start-text':0,'stop-text':0,'start-json':0,'stop-json':0,'stop-no-session-json':0,'doctor-ios-text':0,'doctor-ios-json':0,'doctor-android-text':0,'doctor-android-json':0,'logs-flow08':0}
bad=[]
for n,want in expected.items():
    got=int((r/f'{n}.exit.txt').read_text())
    if got != want: bad.append({'case':n,'want':want,'got':got})
print(bad)
raise SystemExit(bool(bad))
PY
