#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt80c"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt80c-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
CLIENT="$WT/findings/evidence/cov3-ios/attempt16-client.py"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt80c'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/client.py"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/.maestro/coverage/23-missing-first.yaml" <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "No Such"
YAML
cp "$A/.maestro/coverage/23-missing-first.yaml" "$ROOT/"
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo "owned_device_udid=$U1"; } > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
for i in 1 2 3 4 5; do
  cat > "$ROOT/requests-$i.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach --json"},
 {"_shell":"xcrun simctl terminate $U1 com.kylebrowning.Landmarks >/dev/null 2>&1 || true; xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such"}}},
 {"_shell":"for n in 1 2 3 4 5 6 7 8 9 10 11 12; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-$i-\$n.json 2> $ROOT/readiness-$i-\$n.err && grep -q '\"label\" : \"Landmarks\"' $ROOT/readiness-$i-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such"}}},
 {"method":"tools/list","params":{}},
 {"_shell":"$GRANTIVA runner stop --json"}
]
JSON
  python3 -I "$CLIENT" "$ROOT/requests-$i.json" "$ROOT/mcp-$i" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios > "$ROOT/client-$i.out" 2> "$ROOT/client-$i.err"
  print -r -- "$?" > "$ROOT/client-$i.exit.txt"
done
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
python3 - "$ROOT" <<'PY'
import json,sys
from pathlib import Path
r=Path(sys.argv[1])
for i in range(1,6):
    assert (r/f'client-{i}.exit.txt').read_text().strip()=='0'
    raw=(r/f'mcp-{i}/stdout.raw').read_text()
    assert raw.count('Element not found')>=1 and 'Network error (400)' not in raw
PY
