#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/N3-06-ten-recordings-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-record-ten-reps-v1.sh" "$d/input/controller-script.sh"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; ffprobe_bin="/opt/homebrew/bin/ffprobe"
[ -x "$adb_bin" ] && [ -x "$ffprobe_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
: > "$d/commands.txt"; : > "$d/measurements.tsv"; failures=0
for i in $(seq 1 10); do
 r="$d/runs/$i"; mkdir -p "$r"; video="$r/recording.mp4"
 printf '# run %s cwd=%s\n$ %s record --platform android --device %s --duration 3 --output %s --json\n$ %s -v error -show_entries format=duration -of default=nw=1:nk=1 %s\n' "$i" "$P" "$GRANTIVA" "$serial" "$video" "$ffprobe_bin" "$video" >> "$d/commands.txt"
 (cd "$P" && "$GRANTIVA" record --platform android --device "$serial" --duration 3 --output "$video" --json) > "$r/record.json" 2> "$r/record.err"; rc=$?
 printf '%s\n' "$rc" > "$r/record.exit.txt"
 if [ "$rc" -ne 0 ] || [ ! -s "$video" ] || ! jq -e '.recordedMilliseconds > 0 and .duration == 3' "$r/record.json" >/dev/null; then failures=$((failures+1)); continue; fi
 "$ffprobe_bin" -v error -show_entries format=duration -of default=nw=1:nk=1 "$video" > "$r/ffprobe-duration.txt" 2> "$r/ffprobe.err"; frc=$?
 ms="$(jq -r '.recordedMilliseconds' "$r/record.json")"; sec="$(cat "$r/ffprobe-duration.txt")"
 printf '%s\t%s\t%s\t%s\t%s\n' "$i" "$rc" "$frc" "$ms" "$sec" >> "$d/measurements.tsv"
 [ "$frc" -eq 0 ] || failures=$((failures+1))
done
count="$(wc -l < "$d/measurements.tsv" | tr -d ' ')"
printf 'runs=%s measurements=%s failures=%s\n' 10 "$count" "$failures" > "$d/summary.txt"
test "$count" -eq 10 && test "$failures" -eq 0
