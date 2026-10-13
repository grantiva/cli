#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/AND-105-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/project" "$d/mcp" "$d/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-both-configs-android.sh"; cp "$script_path" "$d/input/controller-script.sh"
cat > "$d/project/grantiva.yml" <<'YAML'
scheme: DeliberatelyIOS
bundle_id: com.example.ios
simulator: DeliberatelyIOS
YAML
cat > "$d/project/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
YAML
cat > "$d/input/requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/list","params":{},"_save":"tools-list.json"},
  {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"}
]
JSON
printf '# cwd=%s\n$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$d/project" "$S/tools/client.py" "$d/input/requests.json" "$d/mcp" "$d/project" "$GRANTIVA" "$d/project" > "$d/commands.txt"
python3 -I "$S/tools/client.py" "$d/input/requests.json" "$d/mcp" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
