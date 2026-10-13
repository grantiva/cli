#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L40-same-screen-stability-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/readiness" "$base/mcp" "$base/report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l40-stability-v1.sh" "$base/input/controller-script.sh"
cp "$S/tools/client.py" "$base/input/client.py"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/input/park-landmarks.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Featured"
YAML
cp "$base/input/park-landmarks.yaml" "$base/project/.maestro/park-landmarks.yaml"
cat > "$base/input/requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-before.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_save":"check.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-after.json"}
]
JSON
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 4
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/park-landmarks.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$base/report" > "$base/commands.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/park-landmarks.yaml --report-dir "$base/report") > "$base/keepalive.out" 2> "$base/keepalive.err" & kp=$!
ready=0
for attempt in $(seq 1 40); do
  "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format tree > "$base/readiness/$attempt.out" 2> "$base/readiness/$attempt.err"; rc=$?
  printf 'attempt=%s rc=%s\n' "$attempt" "$rc" >> "$base/readiness/attempts.txt"
  if [ "$rc" -eq 0 ] && grep -q Featured "$base/readiness/$attempt.out"; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/early-stop.out" 2> "$base/early-stop.err"
  wait "$kp"; exit 5
fi
printf '$ python3 -I input/client.py input/requests.json mcp project -- grantiva mcp --project-dir project --platform android\n' >> "$base/commands.txt"
python3 -I "$base/input/client.py" "$base/input/requests.json" "$base/mcp" "$base/project" -- "$GRANTIVA" mcp --project-dir "$base/project" --platform android
mrc=$?
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/stop.out" 2> "$base/stop.err"; src=$?
wait "$kp"; krc=$?
printf 'mcp=%s stop=%s keepalive=%s\n' "$mrc" "$src" "$krc" > "$base/exit.txt"
python3 -I - "$base" <<'PY'
import hashlib,json,pathlib,sys
b=pathlib.Path(sys.argv[1]); m=b/'mcp'
def content(name):
    outer=json.loads((m/name).read_text())
    assert 'error' not in outer
    return outer['result']['content'][0]['text']
before=content('tree-before.json'); after=content('tree-after.json'); check=content('check.json')
bt=json.loads(before); at=json.loads(after)
def appnodes(root):
    out=[]
    def walk(x):
        if isinstance(x,dict):
            if x.get('package')=='com.kylebrowning.landmarks': out.append(x)
            for v in x.values(): walk(v)
        elif isinstance(x,list):
            for v in x: walk(v)
    walk(root); return out
bn=appnodes(bt); an=appnodes(at)
summary={
 'treeBytesIdentical':before==after,
 'treeBeforeSha256':hashlib.sha256(before.encode()).hexdigest(),
 'treeAfterSha256':hashlib.sha256(after.encode()).hexdigest(),
 'appNodeCountBefore':len(bn),'appNodeCountAfter':len(an),
 'appFramesIdentical':[x.get('frame') for x in bn]==[x.get('frame') for x in an],
 'appClickableFramesBefore':[x.get('frame') for x in bn if x.get('clickable')],
 'appClickableFramesAfter':[x.get('frame') for x in an if x.get('clickable')],
 'a11yCheckText':check,
}
(b/'decoded-summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps(summary,indent=2,sort_keys=True))
assert summary['appNodeCountBefore']==summary['appNodeCountAfter'] and summary['appFramesIdentical']
PY
drc=$?
test "$mrc" -eq 0 && test "$src" -eq 0 && test "$krc" -eq 0 && test "$drc" -eq 0
