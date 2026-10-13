#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L14.2-cancel-gradle-rerun1"
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/project" "$base/runtime"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l142-cancel-gradle-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/b3l142-cancel-client-v1.py" "$base/input/client.py"
rsync -a --exclude .gradle --exclude build --exclude '*/build' --exclude '*.iml' "$P/" "$base/project/"
cat >"$base/project/grantiva-android.yml" <<'YAML'
platform: android
application_id: com.kylebrowning.landmarks
module: app
variant: freeDebug
YAML
find "$base/project" -maxdepth 3 -type d -name build -print >"$base/input/build-dirs-before.txt"
[ ! -s "$base/input/build-dirs-before.txt" ] || exit 3
load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"
echo "$load" >"$base/load1-immediately-before.txt"
python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<20 else 1)' "$load" || { echo "load1 $load is not below 20" >&2; exit 4; }
printf '# cwd=%s\n# load1 immediately before real build=%s\n$ python3 -I client.py runtime project %s\n' "$base/project" "$load" "$GRANTIVA" >"$base/commands.txt"
python3 -I "$base/input/client.py" "$base/runtime" "$base/project" "$GRANTIVA"; rc=$?
echo "$rc" >"$base/client.exit"
[ "$rc" -eq 0 ] || exit 5
ps -axo pid=,ppid=,state=,etime=,command= >"$base/processes-final.txt"
if grep -F "$base/project" "$base/processes-final.txt" | grep -Ei 'gradle|java'; then echo project-build-process-remains >&2; exit 6; fi
sed -n '1,225p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaMCPTests/MCPTransportTests.swift >"$base/input/MCPTransportTests.swift.excerpt"
sed -n '1,190p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaMCP/RequestCancellation.swift >"$base/input/RequestCancellation.swift.excerpt"
find "$base" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$base/all-files.sha256"
