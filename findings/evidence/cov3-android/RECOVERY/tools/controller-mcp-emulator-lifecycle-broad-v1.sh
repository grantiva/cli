#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/MCP059-062-D235-emulator-lifecycle-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
cfg_created=cov3-mcp-life-cfg-created
cfg_handmade=cov3-mcp-life-cfg-handmade
empty_created=cov3-mcp-life-empty-created
empty_handmade=cov3-mcp-life-empty-handmade
names=("$cfg_created" "$cfg_handmade" "$empty_created" "$empty_handmade")
mkdir -p "$base/input" "$base/configured" "$base/empty"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-emulator-lifecycle-broad-v1.sh" "$base/input/controller-script.sh"
cp "$S/tools/client.py" "$base/input/client.py"
cp "$P/grantiva-android.yml" "$base/configured/grantiva-android.yml"
for name in "${names[@]}"; do
  avdmanager list avd -c | grep -Fxq "$name" && { echo "refusing existing $name" >&2; exit 3; }
  if [ -f "$HOME/.grantiva/android/created-avds.json" ] && grep -Fq "$name" "$HOME/.grantiva/android/created-avds.json"; then echo "refusing ledger name $name" >&2; exit 4; fi
done
adb devices -l > "$base/adb-before.txt"
avdmanager list avd -c > "$base/avds-before.txt"
[ "$(adb devices | awk 'NR>1&&$2=="device"{print $1}' | paste -sd, -)" = emulator-5554 ] || exit 5
[ "$(adb -s emulator-5554 emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 6
image='system-images;android-35;google_apis;arm64-v8a'
test -f "$ANDROID_HOME/system-images/android-35/google_apis/arm64-v8a/package.xml" || exit 7

call() {
  stem="$1"; cwd="$2"; req="$3"; d="$base/$stem"; mkdir -p "$d"
  cp "$req" "$d/requests.json"
  printf '# cwd=%s\n$ python3 -I input/client.py %q %q %q -- grantiva mcp --project-dir %q --platform android\n' "$cwd" "$req" "$d" "$cwd" "$cwd" > "$d/commands.txt"
  python3 -I "$base/input/client.py" "$req" "$d" "$cwd" -- "$GRANTIVA" mcp --project-dir "$cwd" --platform android
  printf '%s\n' "$?" > "$d/exit.txt"
}

cat > "$base/input/config-created.json" <<JSON
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_ensure","arguments":{"name":"$cfg_created"}},"_save":"ensure.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$cfg_created"}},"_save":"delete.json"}
]
JSON
call config-created "$base/configured" "$base/input/config-created.json"

cat > "$base/input/empty-created.json" <<JSON
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_ensure","arguments":{"name":"$empty_created"}},"_save":"ensure.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$empty_created"}},"_save":"delete.json"}
]
JSON
call empty-created "$base/empty" "$base/input/empty-created.json"

create_handmade() {
  name="$1"; d="$2"; mkdir -p "$d"
  printf 'no\n' | avdmanager create avd -n "$name" -k "$image" --force > "$d/create.out" 2> "$d/create.err"; rc=$?
  printf '%s\n' "$rc" > "$d/create.exit.txt"; test "$rc" -eq 0 && avdmanager list avd -c | grep -Fxq "$name"
}
create_handmade "$cfg_handmade" "$base/config-handmade-create" || exit 8
create_handmade "$empty_handmade" "$base/empty-handmade-create" || exit 9
touch "$base/handmade-ownership-established"

cat > "$base/input/config-handmade.json" <<JSON
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$cfg_handmade"}},"_save":"refuse.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$cfg_handmade","force":true}},"_save":"force.json"}
]
JSON
call config-handmade "$base/configured" "$base/input/config-handmade.json"

cat > "$base/input/empty-handmade.json" <<JSON
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$empty_handmade"}},"_save":"refuse.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"$empty_handmade","force":true}},"_save":"force.json"}
]
JSON
call empty-handmade "$base/empty" "$base/input/empty-handmade.json"

cat > "$base/input/running-missing.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"cov3-android"}},"_save":"running-delete.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"cov3-round3-definitely-missing-avd"}},"_save":"missing-boot.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_list","arguments":{}},"_save":"list-after.json"}
]
JSON
call running-missing "$base/configured" "$base/input/running-missing.json"

avdmanager list avd -c > "$base/avds-after.txt"
adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "${names[@]}" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); names=sys.argv[2:]
def saved(group,name): return json.loads((b/group/name).read_text())
def text(o): return o.get('result',{}).get('content',[{}])[0].get('text','')
def ok(o): return 'error' not in o and not o.get('result',{}).get('isError',False)
def err(o): return 'error' not in o and o.get('result',{}).get('isError') is True and text(o).startswith('Error:')
checks={}
for group in ['config-created','empty-created']:
 checks[group+'Ensure']=ok(saved(group,'ensure.json')); checks[group+'Delete']=ok(saved(group,'delete.json'))
for group in ['config-handmade','empty-handmade']:
 checks[group+'Refuse']=err(saved(group,'refuse.json')); checks[group+'Force']=ok(saved(group,'force.json'))
checks['runningDeleteRefused']=err(saved('running-missing','running-delete.json')) and 'running as emulator-5554' in text(saved('running-missing','running-delete.json'))
checks['missingBootError']=err(saved('running-missing','missing-boot.json'))
checks['primarySurvives']='cov3-android' in text(saved('running-missing','list-after.json')) and 'emulator-5554' in text(saved('running-missing','list-after.json'))
after=(b/'avds-after.txt').read_text().splitlines(); checks['allOwnedNamesAbsent']=all(n not in after for n in names)
checks['adbUnchanged']=(b/'adb-before.txt').read_bytes()==(b/'adb-after.txt').read_bytes()
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,indent=2,sort_keys=True))
raise SystemExit(0 if all(checks.values()) else 1)
PY
