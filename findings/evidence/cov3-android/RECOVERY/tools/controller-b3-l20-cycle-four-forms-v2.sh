#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B3-L20-cycle-four-forms-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input/flows" "$d/input/shared" "$d/project/flows" "$d/project/shared"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3-l20-cycle-four-forms-v2.sh" "$d/input/controller-script.sh"
header='appId: com.kylebrowning.landmarks'
printf '%s\n---\n- runFlow: b.yaml\n' "$header" > "$d/input/a.yaml"
printf '%s\n---\n- runFlow: a.yaml\n' "$header" > "$d/input/b.yaml"
printf '%s\n---\n- runFlow: ../shared/b.yaml\n' "$header" > "$d/input/flows/a.yaml"
printf '%s\n---\n- runFlow: ../flows/a.yaml\n' "$header" > "$d/input/shared/b.yaml"
cat > "$d/input/grantiva-android.yml" <<'YAML'
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
screens:
  - name: S
    path:
      - run_flow: a.yaml
YAML
cp "$d/input/a.yaml" "$d/input/b.yaml" "$d/input/grantiva-android.yml" "$d/project/"
cp "$d/input/flows/a.yaml" "$d/project/flows/a.yaml"
cp "$d/input/shared/b.yaml" "$d/project/shared/b.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
[ ! -e "$d/project/.grantiva/session.json" ] || exit 6
: > "$d/commands.txt"; failures=0
run_case() {
  name="$1"; shift
  printf '# cwd=%s\n$' "$d/project" >> "$d/commands.txt"; printf ' %q' "$@" >> "$d/commands.txt"; printf '\n' >> "$d/commands.txt"
  start="$(python3 -I -c 'import time; print(time.monotonic())')"
  (cd "$d/project" && "$@") > "$d/$name.out" 2> "$d/$name.err"; rc=$?
  elapsed="$(python3 -I -c 'import sys,time; print(round(time.monotonic()-float(sys.argv[1]),3))' "$start")"
  printf '%s\n' "$rc" > "$d/$name.exit.txt"; printf 'rc=%s elapsed=%s\n\n' "$rc" "$elapsed" >> "$d/commands.txt"
  [ "$rc" -ne 0 ] || failures=$((failures+1))
  grep -Ei 'cycle|cyclic|circular|recursive' "$d/$name.err" > "$d/$name.cycle-lines.txt" || failures=$((failures+1))
}
run_case root-cycle "$GRANTIVA" run --platform android --device "$serial" --no-build --flow a.yaml
run_case subdirectory-cycle "$GRANTIVA" run --platform android --device "$serial" --no-build --flow flows/a.yaml
run_case screens-cycle-run "$GRANTIVA" run --platform android --device "$serial" --no-build
run_case screens-cycle-diff "$GRANTIVA" diff capture --platform android --device "$serial" --no-build
printf 'cases=4 failures=%s\n' "$failures" > "$d/summary.txt"
test "$failures" -eq 0
