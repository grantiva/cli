#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-027-065diff-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/AND-027" "$base/AND-065-diff"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and027-and065diff.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
apk="$E/B2-K25-full-exact-rerun1/input/app-free-debug.apk"; test -s "$apk" || exit 3
cp "$apk" "$base/input/app-free-debug.apk"; apk="$base/input/app-free-debug.apk"
serial=""
while read -r s; do
  [ -z "$s" ] && continue
  avd=$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)
  [ "$avd" = cov3-android ] || exit 4
  [ -z "$serial" ] || exit 5
  serial="$s"
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
[ -n "$serial" ] || exit 6
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"
cd "$P"

# AND-027: explicit target differs from the APK's own ID.
adb -s "$serial" uninstall com.kylebrowning.landmarks > "$base/AND-027/uninstall-base.out" 2> "$base/AND-027/uninstall-base.err" || true
adb -s "$serial" uninstall com.kylebrowning.landmarks.debug > "$base/AND-027/uninstall-debug.out" 2> "$base/AND-027/uninstall-debug.err" || true
{ printf '# cwd=%s\n$ %q run --no-build --app-file %q --device %q --application-id com.kylebrowning.landmarks.debug --flow .maestro/01-browse.yaml --report-dir %q\n' "$PWD" "$GRANTIVA" "$apk" "$serial" "$base/AND-027/report"; } > "$base/AND-027/commands.txt"
"$GRANTIVA" run --no-build --app-file "$apk" --device "$serial" --application-id com.kylebrowning.landmarks.debug --flow .maestro/01-browse.yaml --report-dir "$base/AND-027/report" > "$base/AND-027/stdout.log" 2> "$base/AND-027/stderr.log"
rc027=$?
printf 'rc=%s expected=criterion-dependent\n' "$rc027" >> "$base/AND-027/commands.txt"
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/AND-027/pm-base-after.txt" 2> "$base/AND-027/pm-base-after.err" || true
adb -s "$serial" shell pm path com.kylebrowning.landmarks.debug > "$base/AND-027/pm-debug-after.txt" 2> "$base/AND-027/pm-debug-after.err" || true

# AND-065 diff half: observe default capture settings while diff capture is live.
state="$P/.grantiva/android-settings-$serial.json"
[ ! -e "$state" ] || { cp "$state" "$base/AND-065-diff/stale-before.json"; exit 7; }
for key in sysui_demo_allowed window_animation_scale transition_animation_scale animator_duration_scale; do adb -s "$serial" shell settings get global "$key" > "$base/AND-065-diff/before-$key.txt"; done
{ printf '# cwd=%s\n$ %q diff capture --no-build --app-file %q --device %q\n' "$PWD" "$GRANTIVA" "$apk" "$serial"; } > "$base/AND-065-diff/commands.txt"
"$GRANTIVA" diff capture --no-build --app-file "$apk" --device "$serial" > "$base/AND-065-diff/stdout.log" 2> "$base/AND-065-diff/stderr.log" &
pid=$!; printf 'owned-shell-pid=%s\n' "$pid" >> "$base/AND-065-diff/commands.txt"
observed=0
for attempt in $(seq 1 100); do
  if [ -s "$state" ]; then
    w=$(adb -s "$serial" shell settings get global window_animation_scale 2>/dev/null | tr -d '\r'); t=$(adb -s "$serial" shell settings get global transition_animation_scale 2>/dev/null | tr -d '\r'); a=$(adb -s "$serial" shell settings get global animator_duration_scale 2>/dev/null | tr -d '\r'); demo=$(adb -s "$serial" shell settings get global sysui_demo_allowed 2>/dev/null | tr -d '\r')
    if [ "$w" = 0 ] && [ "$t" = 0 ] && [ "$a" = 0 ] && [ "$demo" = 1 ]; then
      cp "$state" "$base/AND-065-diff/settings-state-during.json"
      for key in sysui_demo_allowed window_animation_scale transition_animation_scale animator_duration_scale; do adb -s "$serial" shell settings get global "$key" > "$base/AND-065-diff/during-$key.txt"; done
      adb -s "$serial" shell dumpsys input > "$base/AND-065-diff/during-dumpsys-input.txt"
      adb -s "$serial" shell dumpsys battery > "$base/AND-065-diff/during-dumpsys-battery.txt"
      adb -s "$serial" exec-out screencap -p > "$base/AND-065-diff/during-screen.png"
      observed=1; break
    fi
  fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
done
wait "$pid"; rcdiff=$?
printf 'rc=%s observed=%s\n' "$rcdiff" "$observed" >> "$base/AND-065-diff/commands.txt"
for key in sysui_demo_allowed window_animation_scale transition_animation_scale animator_duration_scale; do adb -s "$serial" shell settings get global "$key" > "$base/AND-065-diff/after-$key.txt"; done
[ ! -e "$state" ] || cp "$state" "$base/AND-065-diff/unexpected-state-after.json"
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-065-diff/captures"; fi
printf 'AND027-rc=%s diff-rc=%s diff-observed=%s\n' "$rc027" "$rcdiff" "$observed" > "$base/summary.txt"
exit 0
