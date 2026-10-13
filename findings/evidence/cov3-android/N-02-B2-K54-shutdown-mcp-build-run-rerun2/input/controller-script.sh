#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N-02-B2-K54-shutdown-mcp-build-run-rerun2"; name=cov3-android-n02-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project" "$base/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n02-k54-build-run-v2.sh" "$base/input/controller-script.sh"; cp "$S/tools/client.py" "$base/input/client.py"
for item in app gradle build.gradle.kts gradle.properties gradlew settings.gradle.kts; do ln -s "$P/$item" "$base/project/$item"; done
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
cat > "$base/input/request.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-n02","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"build.json"}
]
JSON
avdmanager list avd -c | grep -Fxq "$name" && exit 3
cleanup(){ for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done; avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true; }
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 4
adb devices -l > "$base/adb-before.txt"; for s in $(adb devices|awk '$2=="device"{print $1}'); do printf '%s %s\n' "$s" "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; done > "$base/names-before.txt"; grep -q " $name$" "$base/names-before.txt" && exit 5
python3 -I -c 'import os,sys,json;x=os.getloadavg()[0];print(json.dumps({"load1":x}));sys.exit(0 if x<20 else 1)' > "$base/load-before.json" || exit 6
python3 -I "$base/input/client.py" "$base/input/request.json" "$base/mcp" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project" --platform android
mrc=$?; echo "$mrc" > "$base/mcp-client.exit.txt"; adb devices -l > "$base/adb-after-build.txt"; for s in $(adb devices|awk '$2=="device"{print $1}'); do printf '%s %s\n' "$s" "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; done > "$base/names-after-build.txt"
sed 's/grantiva_build/grantiva_run/; s/build.json/run.json/; s/round3-n02/round3-k54-run/' "$base/input/request.json" > "$base/input/run-request.json"
python3 -I -c 'import os,sys,json;x=os.getloadavg()[0];print(json.dumps({"load1":x}));sys.exit(0 if x<20 else 1)' > "$base/load-before-run.json" || exit 7
mkdir -p "$base/mcp-run"; python3 -I "$base/input/client.py" "$base/input/run-request.json" "$base/mcp-run" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project" --platform android
rrc=$?; echo "$rrc" > "$base/mcp-run-client.exit.txt"; adb devices -l > "$base/adb-after-run.txt"; for s in $(adb devices|awk '$2=="device"{print $1}'); do printf '%s %s\n' "$s" "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; done > "$base/names-after-run.txt"
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,sys,re
b=pathlib.Path(sys.argv[1]); raw=json.load(open(b/'mcp/build.json')); text=' '.join(x.get('text','') for x in raw.get('result',{}).get('content',[])); products=re.findall(r'Product:\s*(\S+\.apk)',text); run=json.load(open(b/'mcp-run/run.json')); runtext=' '.join(x.get('text','') for x in run.get('result',{}).get('content',[])); checks={'client0':(b/'mcp-client.exit.txt').read_text().strip()=='0','notError':raw.get('result',{}).get('isError') is not True,'productAPK':bool(products) and all(pathlib.Path(x).is_file() for x in products),'configuredModuleVariant':'app' in text and 'freeDebug' in text,'adbUnchanged':(b/'adb-before.txt').read_bytes()==(b/'adb-after-build.txt').read_bytes(),'avdNeverBootedByBuild':' cov3-android-n02-r3' not in (b/'names-after-build.txt').read_text(),'runClient0':(b/'mcp-run-client.exit.txt').read_text().strip()=='0','runBootedConfiguredAVD':' cov3-android-n02-r3' in (b/'names-after-run.txt').read_text(),'runLaunchedApp':'App built and launched' in runtext and 'com.kylebrowning.landmarks' in runtext,'avdRemoved':'cov3-android-n02-r3' not in (b/'avds-after.txt').read_text()}; (b/'decoded.json').write_text(json.dumps({'checks':checks,'products':products,'buildText':text,'runText':runtext},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
