#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K109-BC08-config-forms-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/source" "$base/happy/project" "$base/missing/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k109-c08-config-forms-v1.sh" "$base/input/controller-script.sh"
cat > "$base/happy/project/grantiva-android.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- swipe:
    direction: UP
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- extendedWaitUntil:
    notVisible:
      id: "definitely-missing-id"
    timeout: 2000
- extendedWaitUntil:
    visible:
      text: "Cache Policy"
      exact: true
    timeout: 5000
- extendedWaitUntil:
    visible:
      id: "clock"
    timeout: 5000
- extendedWaitUntil:
    visible: "Cache Policy"
- tapOn:
    id: "clock"
- assertVisible:
    id: "clock"
- assertNotVisible:
    id: "definitely-missing-id"
- scrollUntilVisible:
    element:
      id: "clock"
    direction: DOWN
    timeout: 5000
- takeScreenshot: "K109 Forms"
YAML
cat > "$base/missing/project/grantiva-android.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- extendedWaitUntil:
    visible: "No Such Element"
    timeout: 2000
- takeScreenshot: "Must Not Exist"
YAML
cp "$base/happy/project/grantiva-android.yml" "$base/input/happy.grantiva-android.yml"
cp "$base/missing/project/grantiva-android.yml" "$base/input/missing.grantiva-android.yml"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
run_case() {
  name="$1"
  expected="$2"
  d="$base/$name"
  cd "$d/project" || return 90
  printf '# cwd=%s\n$ %q diff capture --platform android --device %q --no-build --verbose\n' "$PWD" "$GRANTIVA" "$serial" > "$d/commands.txt"
  "$GRANTIVA" diff capture --platform android --device "$serial" --no-build --verbose > "$d/stdout.log" 2> "$d/stderr.log" &
  pid=$!
  report=""
  copies=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ -z "$report" ]; then
      line="$(grep -m1 '\$ .*grantiva-runner --platform android .* --output ' "$d/stderr.log" 2>/dev/null || true)"
      if [ -n "$line" ]; then
        printf '%s\n' "$line" > "$d/runner-command-line.txt"
        report="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i=="--output"){print $(i+1);exit}}')"
        case "$report" in /var/folders/*/T/grantiva-report-*) ;; *) kill -INT "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; return 91 ;; esac
        printf '%s\n' "$report" > "$d/report-path.txt"
      fi
    fi
    if [ -n "$report" ] && [ -d "$report" ]; then
      copies=$((copies+1))
      [ -f "$report/report.json" ] && cp "$report/report.json" "$d/report-visible.json"
      f="$(find "$report/flows" -maxdepth 1 -name '*.json' -type f 2>/dev/null | head -1)"
      [ -n "$f" ] && cp "$f" "$d/flow-visible.json"
      [ -f "$report/maestro-runner.log" ] && cp "$report/maestro-runner.log" "$d/runner-visible.log"
    fi
    sleep 0.02
  done
  wait "$pid"
  rc=$?
  printf '%s\n' "$rc" > "$d/exit.txt"
  printf 'rc=%s copies=%s report=%s flow=%s\n' "$rc" "$copies" "$([ -s "$d/report-visible.json" ] && echo yes || echo no)" "$([ -s "$d/flow-visible.json" ] && echo yes || echo no)" > "$d/summary.txt"
  [ "$rc" -eq "$expected" ] && [ -s "$d/flow-visible.json" ]
}
failures=0
run_case happy 0 || failures=$((failures+1))
run_case missing 1 || failures=$((failures+1))
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
sed -n '90,190p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/MaestroStandardFormsTests.swift > "$base/source/maestro-standard-tests.txt"
sed -n '130,230p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/FlowStagingTests.swift > "$base/source/flow-staging-tests.txt"
rg -n -C 3 'tapByID|assertVisibleByID|assertNotVisibleByID|scrollUntilVisible|extendedWaitUntil' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests > "$base/source/id-production-tests.txt" || true
printf 'failures=%s serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
[ "$failures" -eq 0 ]
