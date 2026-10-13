#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/selector-failure-complements-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project/.maestro/coverage" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-selector-failure-complements-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/coverage/K01-point-multitaps.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- assertVisible: "Double taps: 0"
- doubleTapOn: {point: "50%,50%"}
- assertVisible: "Double taps: 1"
- assertVisible: "Long presses: 0"
- longPressOn: {point: "50%,50%"}
- assertVisible: "Long presses: 1"
YAML
cat > "$base/project/.maestro/coverage/K02-tap-missing.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "No Such Element"
YAML
cat > "$base/project/.maestro/coverage/K03-fail-early.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "No Such Element"
- assertVisible: "This must be skipped"
- tapOn: "This also must be skipped"
- takeScreenshot: "Must Not Run"
YAML
cp "$base/project/.maestro/coverage/"*.yaml "$base/input/"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
run_flow() {
 name="$1"; flow="$2"; expected="$3"; d="$base/$name"; mkdir -p "$d"; cd "$base/project" || return 90
 printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q --snapshot full\n' "$PWD" "$GRANTIVA" "$serial" "$flow" "$d/report" > "$d/commands.txt"
 "$GRANTIVA" run --platform android --device "$serial" --no-build --flow "$flow" --report-dir "$d/report" --snapshot full > "$d/stdout.log" 2> "$d/stderr.log"; rc=$?; printf '%s\n' "$rc" > "$d/exit.txt"
 cp "$d/report/report.json" "$d/report-visible.json"; cp "$d/report/maestro-runner.log" "$d/runner-visible.log"
 f="$(find "$d/report/flows" -maxdepth 1 -name '*.json' -type f | head -1)"; [ -n "$f" ] || return 91; cp "$f" "$d/flow-visible.json"
 [ "$rc" -eq "$expected" ]
}
failures=0
run_flow K01 .maestro/coverage/K01-point-multitaps.yaml 0 || failures=$((failures+1))
run_flow K02 .maestro/coverage/K02-tap-missing.yaml 1 || failures=$((failures+1))
run_flow K03 .maestro/coverage/K03-fail-early.yaml 1 || failures=$((failures+1))
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
git -C /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b rev-parse HEAD > "$base/source/runner-head.txt"
rg -n -C 4 'Describe|describeTapTarget|skipped|pending|closest on-screen|does not repeat' /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/flow /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/cli /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/driver/uiautomator2 > "$base/source/runner-tests.txt" || true
printf 'failures=%s serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
[ "$failures" -eq 0 ]
