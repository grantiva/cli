#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K110-explicit-runner-rerun4"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/report" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2-k110-explicit-runner-v4.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/02-favorite.yaml" "$base/input/02-favorite.yaml"
runner=/Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.13+android-drivers-2/grantiva-runner
[ "$($runner --version 2>/dev/null | head -1 | awk '{print $2}')" = 1.1.28-grantiva.13 ] || exit 3
runner_home="$(dirname "$runner")"
[ "$runner_home" = /Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.13+android-drivers-2 ] || exit 9
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 4
  [ -z "$serial" ] || exit 5
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 6
printf '# cwd=%s\n$ %q --platform android --device %q --driver uiautomator2 --no-ansi --no-app-install test --output %q --flatten --artifacts failure %q\n' "$P" "$runner" "$serial" "$base/report" "$P/.maestro/02-favorite.yaml" > "$base/commands.txt"
cd "$P" || exit 7
MAESTRO_RUNNER_HOME="$runner_home" "$runner" --platform android --device "$serial" --driver uiautomator2 --no-ansi --no-app-install test --output "$base/report" --flatten --artifacts failure "$P/.maestro/02-favorite.yaml" > "$base/stdout.log" 2> "$base/stderr.log"
rc=$?
printf '%s\n' "$rc" > "$base/exit.txt"
grep -n '^.*\[INFO\] Driver:' "$base/report/maestro-runner.log" > "$base/driver-line.txt"
jq '{status,device,maestroRunner}' "$base/report/report.json" > "$base/report-driver.json"
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
git -C /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b rev-parse HEAD > "$base/source/runner-head.txt"
rg -n 'resolveDriverName|TestRunLogsResolvedDriverName|Driver:' /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/cli > "$base/source/runner-driver-source-tests.txt" || true
printf 'rc=%s driver=%s serial=%s\n' "$rc" "$(jq -r '.maestroRunner.driver' "$base/report/report.json")" "$serial" > "$base/summary.txt"
[ "$rc" -eq 0 ] && grep -q 'Driver: uiautomator2' "$base/report/maestro-runner.log" && [ "$(jq -r '.maestroRunner.driver' "$base/report/report.json")" = uiautomator2 ]
