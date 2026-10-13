#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L45-mcp-boot-text-rerun1"; name=cov3-android-mcpboot-r3
if [ -e "$base" ] || avdmanager list avd -c | grep -Fxq "$name"; then echo refusing-existing >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l45-mcp-boot-text-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/B2-K56-X011-MCP076-context-resources-rerun4/input/client.py" "$base/input/client.py"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
owned=0; serial=''
cleanup(){ if [ "$owned" -eq 1 ]; then if [ -n "$serial" ] && [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]; then "$GRANTIVA" emulator teardown --serial "$serial" --force > "$base/trap-teardown.out" 2> "$base/trap-teardown.err" || true; fi; "$GRANTIVA" emulator delete --name "$name" --force --json > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true; fi; }
trap cleanup EXIT INT TERM
cat > "$base/primary-requests.json" <<'JSON'
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-l45","version":"1"}}},{"method":"notifications/initialized","params":{}},{"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"cov3-android"}},"_save":"explicit.json"},{"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{}},"_save":"configured.json"}]
JSON
python3 -I "$base/input/client.py" "$base/primary-requests.json" "$base/primary" "$P" -- "$GRANTIVA" mcp --project-dir "$P"
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err"; crc=$?; [ "$crc" -eq 0 ] || exit 3; owned=1
cat > "$base/secondary-requests.json" <<JSON
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-l45","version":"1"}}},{"method":"notifications/initialized","params":{}},{"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"$name"}},"_save":"boot.json"}]
JSON
python3 -I "$base/input/client.py" "$base/secondary-requests.json" "$base/secondary" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project"
for attempt in $(seq 1 90); do while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] && break; sleep 1; done
[ -n "$serial" ] || exit 4
python3 -I - "$base" "$name" "$serial" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name=sys.argv[2]; serial=sys.argv[3]
def text(p):
 d=json.loads(p.read_text()); return '\n'.join(x.get('text','') for x in d.get('result',{}).get('content',[]))
e=text(b/'primary/explicit.json'); c=text(b/'primary/configured.json'); s=text(b/'secondary/boot.json')
checks={'explicitReuse':f'Emulator reused: cov3-android (emulator-5554), already running' in e,'configuredReuse':f'Emulator reused: cov3-android (emulator-5554), already running' in c,'secondaryBooted':f'Emulator booted: {name} ({serial})' in s}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?; cleanup; owned=0; trap - EXIT INT TERM; exit "$rc"
