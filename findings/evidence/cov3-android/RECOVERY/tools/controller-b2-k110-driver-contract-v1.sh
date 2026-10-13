#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K110-driver-contract-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/default" "$base/explicit" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2-k110-driver-contract-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
cp "$P/.maestro/02-favorite.yaml" "$base/input/02-favorite.yaml"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
run_case() {
  name="$1"
  explicit="$2"
  d="$base/$name"
  printf '# cwd=%s\n' "$PWD" > "$d/commands.txt"
  if [ "$explicit" = yes ]; then
    printf '$ %q run --platform android --device %q --driver uiautomator2 --no-build --flow .maestro/02-favorite.yaml --report-dir %q\n' "$GRANTIVA" "$serial" "$d/report" >> "$d/commands.txt"
    "$GRANTIVA" run --platform android --device "$serial" --driver uiautomator2 --no-build --flow .maestro/02-favorite.yaml --report-dir "$d/report" > "$d/stdout.log" 2> "$d/stderr.log"
  else
    printf '$ %q run --platform android --device %q --no-build --flow .maestro/02-favorite.yaml --report-dir %q\n' "$GRANTIVA" "$serial" "$d/report" >> "$d/commands.txt"
    "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/02-favorite.yaml --report-dir "$d/report" > "$d/stdout.log" 2> "$d/stderr.log"
  fi
  rc=$?
  printf '%s\n' "$rc" > "$d/exit.txt"
  grep -n '^.*\[INFO\] Driver:' "$d/report/maestro-runner.log" > "$d/driver-line.txt"
  jq '{status,device,.maestroRunner}' "$d/report/report.json" > "$d/report-driver.json"
  [ "$rc" -eq 0 ] && grep -q 'Driver: uiautomator2' "$d/report/maestro-runner.log" && [ "$(jq -r '.maestroRunner.driver' "$d/report/report.json")" = uiautomator2 ]
}
run_case default no || exit 7
run_case explicit yes || exit 8
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
git -C /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b rev-parse HEAD > "$base/source/runner-head.txt"
rg -n 'resolveDriverName|TestRunLogsResolvedDriverName|Driver:' /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/cli > "$base/source/runner-driver-source-tests.txt" || true
rg -n 'uiautomator2|Driver:' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs > "$base/source/docs.txt" || true
printf 'default=%s explicit=%s serial=%s\n' "$(jq -r '.maestroRunner.driver' "$base/default/report/report.json")" "$(jq -r '.maestroRunner.driver' "$base/explicit/report/report.json")" "$serial" > "$base/summary.txt"
