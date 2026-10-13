#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
bk="$S/round3-k89-mixed-backup"; rm -rf "$bk"; mkdir -p "$bk"
if [ -d .grantiva/baselines/android ]; then cp -R .grantiva/baselines/android "$bk/baselines.android.before"; fi
if [ -d .grantiva/captures/android ]; then cp -R .grantiva/captures/android "$bk/captures.android.before"; fi
restore() {
  rm -rf .grantiva/baselines/android .grantiva/captures/android
  if [ -d "$bk/baselines.android.before" ]; then mkdir -p .grantiva/baselines; cp -R "$bk/baselines.android.before" .grantiva/baselines/android; fi
  if [ -d "$bk/captures.android.before" ]; then mkdir -p .grantiva/captures; cp -R "$bk/captures.android.before" .grantiva/captures/android; fi
}
trap restore EXIT
rm -rf .grantiva/baselines/android .grantiva/captures/android
mkdir -p .grantiva/captures/android
cp -R "$E/AND-085-exact/captures/." .grantiva/captures/android/
rec B2-K89-mixed-retry "$GRANTIVA diff approve Home --json; echo approve-home-exit=\$?; find .grantiva/baselines/android -maxdepth 1 -type f -print; $GRANTIVA diff compare; echo mixed-text-exit=\$?; $GRANTIVA diff compare --json; echo mixed-json-exit=\$?"
R="$E/B2-K89-mixed-retry/mcp-requests.json"
cat > "$R" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}},"_save":"vrt-compare.json"}
]
JSON
printf '# cwd=%s\n$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$P" "$S/tools/client.py" "$R" "$E/B2-K89-mixed-retry/mcp" "$P" "$GRANTIVA" "$P" >> "$E/B2-K89-mixed-retry/commands.txt"
python3 -I "$S/tools/client.py" "$R" "$E/B2-K89-mixed-retry/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
