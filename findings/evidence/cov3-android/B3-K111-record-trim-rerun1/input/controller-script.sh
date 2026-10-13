#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B3-K111-record-trim-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/runs" "$d/frame-check"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3-k111-record-trim-v1.sh" "$d/input/controller-script.sh"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; ffprobe_bin="/opt/homebrew/bin/ffprobe"
[ -x "$adb_bin" ] && [ -x "$ffprobe_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
: > "$d/commands.txt"; : > "$d/measurements.tsv"; failures=0
for i in $(seq 1 5); do
 r="$d/runs/$i"; mkdir -p "$r"; video="$r/r$i.mp4"
 printf '# run %s cwd=%s\n$ %s record --platform android --device %s --duration 4 --output %s --json --verbose\n' "$i" "$P" "$GRANTIVA" "$serial" "$video" >> "$d/commands.txt"
 (cd "$P" && "$GRANTIVA" record --platform android --device "$serial" --duration 4 --output "$video" --json --verbose) > "$r/record.json" 2> "$r/record.err"; rc=$?
 printf '%s\n' "$rc" > "$r/record.exit.txt"
 "$ffprobe_bin" -v error -show_entries format=duration -of default=nw=1:nk=1 "$video" > "$r/ffprobe-duration.txt" 2> "$r/ffprobe.err"; frc=$?
 ms="$(jq -r '.recordedMilliseconds' "$r/record.json" 2>/dev/null)"; sec="$(cat "$r/ffprobe-duration.txt")"
 grep -F 'Held frame:' "$r/record.err" > "$r/held-frame-line.txt"; hrc=$?
 printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$i" "$rc" "$frc" "$ms" "$sec" "$hrc" >> "$d/measurements.tsv"
 if [ "$rc" -ne 0 ] || [ "$frc" -ne 0 ] || [ "$hrc" -ne 0 ] || [ ! -s "$video" ]; then failures=$((failures+1)); fi
done
fv="$d/frame-check/recording.mp4"
printf '\n# frame-at-end control\n$ %s record --platform android --device %s --duration 4 --output %s --frames-at 4000 --json --verbose\n' "$GRANTIVA" "$serial" "$fv" >> "$d/commands.txt"
(cd "$P" && "$GRANTIVA" record --platform android --device "$serial" --duration 4 --output "$fv" --frames-at 4000 --json --verbose) > "$d/frame-check/record.json" 2> "$d/frame-check/record.err"; frame_rc=$?
find "$d/frame-check" -maxdepth 1 -type f -print | sort > "$d/frame-check/files.txt"
frame_count="$(find "$d/frame-check" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) | wc -l | tr -d ' ')"
[ "$frame_rc" -eq 0 ] && [ "$frame_count" -ge 1 ] || failures=$((failures+1))
printf 'runs=5 failures=%s frameControlRc=%s frameImages=%s\n' "$failures" "$frame_rc" "$frame_count" > "$d/summary.txt"
test "$failures" -eq 0
