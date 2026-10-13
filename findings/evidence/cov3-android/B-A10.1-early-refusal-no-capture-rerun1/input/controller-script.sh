#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-A10.1-early-refusal-no-capture-rerun1"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/owner/.maestro" "$base/competitor/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-ba10-early-refusal-no-capture-v1.sh" "$base/input/controller-script.sh"
for p in owner competitor; do cp "$P/grantiva-android.yml" "$base/$p/grantiva-android.yml"; cp "$P/.maestro/01-browse.yaml" "$base/$p/.maestro/01-browse.yaml"; done
cp "$P/.maestro/coverage/18-long-wait.yaml" "$base/owner/.maestro/18-long-wait.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
cleanup(){ (cd "$base/owner" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.json" 2> "$base/trap-stop.err" || true; [ -n "${op:-}" ] && kill -INT "$op" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
(cd "$base/owner" && exec "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/18-long-wait.yaml) > "$base/owner.out" 2> "$base/owner.err" & op=$!
active=0
for i in $(seq 1 120); do if grep -q '\[1/1\].*18-long-wait' "$base/owner.err" 2>/dev/null; then active=1; break; fi; kill -0 "$op" 2>/dev/null || exit 4; sleep 1; done
[ "$active" -eq 1 ] || exit 5
captures="$base/competitor/.grantiva/run-captures/android"
snapshot(){ local out="$1"; if [ -d "$captures" ]; then find "$captures" -type f -print | sort | while read -r f; do shasum -a 256 "$f"; done > "$out"; else : > "$out"; fi; }
snapshot "$base/captures-before.sha256"
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/01-browse.yaml\n' "$base/competitor" "$GRANTIVA" "$serial" > "$base/competitor.command.txt"
(cd "$base/competitor" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml) > "$base/competitor.out" 2> "$base/competitor.err"; rrc=$?
snapshot "$base/captures-after.sha256"; cmp -s "$base/captures-before.sha256" "$base/captures-after.sha256"; same=$?
owner_pid="$op"; kill -0 "$owner_pid" 2>/dev/null; alive=$?
(cd "$base/owner" && "$GRANTIVA" runner stop --json) > "$base/stop.json" 2> "$base/stop.err"; stc=$?
wait "$op"; orc=$?; echo "$orc" > "$base/owner-exit.txt"
python3 -I - "$base" "$rrc" "$same" "$alive" "$stc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); msg=(b/'competitor.out').read_text()+(b/'competitor.err').read_text(); low=msg.lower()
checks={'refused':int(sys.argv[2])!=0,'namesDevice':'emulator emulator-5554' in low,'teardownRemedy':'emulator teardown --serial emulator-5554 --force' in msg,'ensureRemedy':'emulator ensure --name <unique-name>' in msg,'noGenericChildSuffix':' exited with code 1' not in low,'capturesByteIdentical':int(sys.argv[3])==0,'ownerStillAlive':int(sys.argv[4])==0,'stop0':int(sys.argv[5])==0}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'message':msg},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?; trap - EXIT INT TERM; exit "$rc"
