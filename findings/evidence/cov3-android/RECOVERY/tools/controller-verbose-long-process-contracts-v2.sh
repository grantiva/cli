#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K33-X024-verbose-processes-rerun2"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-verbose-long-process-contracts-v2.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/08-caching.yaml" "$base/input/08-caching.yaml"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
run_case() {
 name="$1"; verbose="$2"; d="$base/$name"; mkdir -p "$d"
 args=(run --platform android --device "$serial" --no-build --flow .maestro/08-caching.yaml --logs --report-dir "$d/report")
 [ "$verbose" = yes ] && args+=(--verbose)
 printf '# cwd=%s\n$ %q' "$PWD" "$GRANTIVA" > "$d/commands.txt"; printf ' %q' "${args[@]}" >> "$d/commands.txt"; printf '\n' >> "$d/commands.txt"
 "$GRANTIVA" "${args[@]}" > "$d/stdout.log" 2> "$d/stderr.log"; rc=$?; printf '%s\n' "$rc" > "$d/exit.txt"
 cp "$d/report/report.json" "$d/report-visible.json"; cp "$d/report/maestro-runner.log" "$d/runner-visible.log"
 [ "$rc" -eq 0 ]
}
record_case() {
 name="$1"; verbose="$2"; d="$base/$name"; mkdir -p "$d"; out="$d/recording.mp4"
 args=(record --platform android --device "$serial" --duration 2 --output "$out" --json)
 [ "$verbose" = yes ] && args+=(--verbose)
 printf '# cwd=%s\n$ %q' "$PWD" "$GRANTIVA" > "$d/commands.txt"; printf ' %q' "${args[@]}" >> "$d/commands.txt"; printf '\n' >> "$d/commands.txt"
 "$GRANTIVA" "${args[@]}" > "$d/stdout.json" 2> "$d/stderr.log"; rc=$?; printf '%s\n' "$rc" > "$d/exit.txt"
 jq . "$d/stdout.json" > "$d/stdout-pretty.json"
 [ "$rc" -eq 0 ] && [ -s "$out" ]
}
failures=0
run_case run-plain no || failures=$((failures+1))
run_case run-verbose yes || failures=$((failures+1))
record_case record-plain no || failures=$((failures+1))
record_case record-verbose yes || failures=$((failures+1))
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
rg -n -C 4 'started by|stopped by SIGINT|exit .*executable|LogStreamer|ChildProcess' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests > "$base/source/subprocess-source-tests.txt" || true
printf 'failures=%s serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
[ "$failures" -eq 0 ]
