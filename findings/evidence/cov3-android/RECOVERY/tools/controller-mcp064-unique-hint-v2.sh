#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/MCP064-unique-hint-rerun2"; hint='MCP064 Unique Hint'
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/project" "$base/mcp" "$base/readiness"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp064-unique-hint-v2.sh" "$base/input/controller-script.sh"
cp "$S/tools/client.py" "$base/input/client.py"
rsync -a --exclude .gradle --exclude build --exclude '*/build' --exclude '*.iml' "$P/" "$base/project/"

src="$base/project/app/src/main/java/com/kylebrowning/landmarks/ui/EditLandmarkScreen.kt"
cp "$src" "$base/input/EditLandmarkScreen.before.kt"
python3 -I - "$src" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text()
needle="""@Composable
private fun LabeledField(label: String, value: TextFieldValue, onChange: (TextFieldValue) -> Unit) {
    OutlinedTextField("""
replacement="""@Composable
private fun LabeledField(label: String, value: TextFieldValue, onChange: (TextFieldValue) -> Unit) {
    if (label == "Name") {
        androidx.compose.ui.viewinterop.AndroidView(
            factory = { context -> android.widget.EditText(context).apply {
                hint = "MCP064 Unique Hint"
                contentDescription = "Name"
                setText("")
                isSingleLine = true
            } },
            modifier = Modifier.fillMaxWidth(),
        )
        return
    }
    OutlinedTextField("""
assert s.count(needle)==1
# A real Android EditText exposes independent hint/text/content-desc attributes.
p.write_text(s.replace(needle,replacement))
PY
cp "$src" "$base/input/EditLandmarkScreen.after.kt"
diff -u "$base/input/EditLandmarkScreen.before.kt" "$base/input/EditLandmarkScreen.after.kt" >"$base/input/scratch-fixture.patch" || true
cat >"$base/project/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
screens:
  - name: Unique Hint
    path:
      - tap: "Deep Links"
      - tap: "Edit Landmark"
      - tap: "MCP064 Unique Hint"
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
cat >"$base/input/capture.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"mcp064-unique-hint","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"capture.json"}
]
JSON

adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
stock_apk="$P/app/build/outputs/apk/free/debug/app-free-debug.apk"
[ -f "$stock_apk" ] || { echo missing-stock-restore-apk >&2; exit 5; }
shasum -a 256 "$stock_apk" >"$base/input/stock-restore-apk.sha256"
session_started=0; fixture_installed=0
cleanup() {
 if [ "$session_started" -eq 1 ]; then (cd "$base/project" && "$GRANTIVA" runner stop --json) >>"$base/trap-stop.json" 2>>"$base/trap-stop.err" || true; fi
 if [ "$fixture_installed" -eq 1 ]; then "$adb_bin" -s "$serial" install -r "$stock_apk" >>"$base/restore-stock.out" 2>>"$base/restore-stock.err" || true; fi
}
trap cleanup EXIT

load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"; echo "$load" >"$base/load1-immediately-before-build.txt"
python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<20 else 1)' "$load" || exit 6
printf '# scratch-demo-only source fixture; candidate/runner source unchanged\n# load1 immediately before build=%s\n' "$load" >"$base/commands.txt"
(cd "$base/project" && "$GRANTIVA" build install --emulator cov3-android --module app --variant freeDebug --no-launch --json) >"$base/build-install.json" 2>"$base/build-install.err" || exit 7
fixture_installed=1
(cd "$base/project" && "$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json) >"$base/start.json" 2>"$base/start.err" || exit 8
session_started=1
ready=0
for poll in $(seq 1 40); do
 (cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json) >"$base/readiness/$poll.json" 2>"$base/readiness/$poll.err"
 if [ $? -eq 0 ] && grep -q 'Golden Gate Bridge' "$base/readiness/$poll.json"; then ready=1;break;fi
 sleep .25
done
[ "$ready" -eq 1 ] || exit 9
python3 -I "$base/input/client.py" "$base/input/capture.json" "$base/mcp" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project" --platform android; mrc=$?
echo "$mrc" >"$base/mcp.exit"; [ "$mrc" -eq 0 ] || exit 10
cp -R "$base/project/.grantiva/captures/android" "$base/mcp/captures"

(cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json) >"$base/hierarchy-after.json" 2>"$base/hierarchy-after-json.err" || exit 11
# This XML comes from the live UIAutomator2 session and is the exact source the
# selector engine uses, so its hint/text/content-desc attributes are decisive.
(cd "$base/project" && "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format xml) >"$base/hierarchy-after.xml" 2>"$base/hierarchy-after-xml.err" || exit 12
# Preserve the platform uiautomator dump as a secondary diagnostic only.
"$adb_bin" -s "$serial" shell uiautomator dump /sdcard/mcp064-hint.xml >"$base/uiautomator-dump.out" 2>"$base/uiautomator-dump.err" || true
"$adb_bin" -s "$serial" pull /sdcard/mcp064-hint.xml "$base/hierarchy-adb.xml" >"$base/uiautomator-pull.out" 2>"$base/uiautomator-pull.err" || true
"$adb_bin" -s "$serial" shell rm /sdcard/mcp064-hint.xml >/dev/null 2>&1 || true

python3 -I - "$base" "$hint" <<'PY' || exit 14
import json,pathlib,sys,xml.etree.ElementTree as ET
b=pathlib.Path(sys.argv[1]);hint=sys.argv[2];root=ET.parse(b/'hierarchy-after.xml').getroot()
nodes=[n.attrib for n in root.iter() if n.attrib.get('hint')==hint]
assert len(nodes)==1,nodes
node=nodes[0];assert node.get('text','')!=hint and node.get('content-desc','')!=hint,node
doc=json.load(open(b/'mcp'/'capture.json'));assert doc.get('result',{}).get('isError') is not True,doc
text=' '.join(x.get('text','') for x in doc.get('result',{}).get('content',[]));parsed=json.loads(text)
screens=parsed.get('screens',[]);assert len(screens)==1 and screens[0].get('screenName')=='Unique Hint',screens
steps=screens[0].get('steps',[]);assert any(hint in json.dumps(x) and x.get('status')=='passed' for x in steps),steps
png=b/'mcp'/'captures'/'Unique Hint.png';assert png.is_file() and png.stat().st_size>0,png
(b/'decoded.json').write_text(json.dumps({'uniqueHintNode':node,'screen':screens[0],'pngBytes':png.stat().st_size},indent=2)+'\n')
PY

(cd "$base/project" && "$GRANTIVA" runner stop --json) >"$base/stop.json" 2>"$base/stop.err" || exit 15
session_started=0
"$adb_bin" -s "$serial" install -r "$stock_apk" >"$base/restore-stock.out" 2>"$base/restore-stock.err" || exit 16
fixture_installed=0
"$adb_bin" -s "$serial" shell pm path com.kylebrowning.landmarks >"$base/restored-package-path.txt" || exit 17
trap - EXIT
find "$base" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$base/all-files.sha256"
