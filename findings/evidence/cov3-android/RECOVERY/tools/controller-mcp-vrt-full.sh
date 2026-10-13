#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-103-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/readiness" "$d/mcp" "$d/artifacts"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-vrt-full.sh"; cp "$script_path" "$d/input/controller-script.sh"
cp .maestro/01-browse.yaml "$d/input/"
cat > "$d/input/requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"vrt-capture.json"},
  {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{}},"_save":"vrt-approve.json"},
  {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}},"_save":"vrt-compare.json"}
]
JSON
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --keep-alive --flow .maestro/01-browse.yaml --report-dir %s\n' "$P" "$GRANTIVA" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --keep-alive --flow .maestro/01-browse.yaml --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" & kp=$!
ready=0
for i in $(seq 1 30); do
  "$GRANTIVA" runner dump-hierarchy --format tree > "$d/readiness/$i.out" 2> "$d/readiness/$i.err"; rc=$?
  printf 'poll=%s rc=%s landmarks=%s\n' "$i" "$rc" "$(grep -c Landmarks "$d/readiness/$i.out")" >> "$d/readiness/summary.txt"
  if [ "$rc" -eq 0 ] && grep -q Landmarks "$d/readiness/$i.out"; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$d/early-stop.json"; wait "$kp"; exit 1; fi
python3 -I "$S/tools/client.py" "$d/input/requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
find .grantiva/captures/android .grantiva/baselines/android -maxdepth 1 -type f -print | sort > "$d/artifacts/files.txt"
cp .grantiva/captures/android/*.png "$d/artifacts/"
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; src=$?
wait "$kp"; krc=$?
printf '$ MCP vrt capture, approve, compare\n$ grantiva runner stop --json\nstop-rc=%s keepalive-rc=%s\n' "$src" "$krc" >> "$d/commands.txt"
test ! -e .grantiva/session.json
