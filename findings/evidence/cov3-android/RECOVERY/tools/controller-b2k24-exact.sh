#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
src="$P/.maestro/coverage/cfg/maestro-format.grantiva-android.yml"
base="$E/B2-K24-exact-rerun1"
if [ -e "$base" ]; then
  echo "refusing to overwrite existing evidence: $base" >&2
  exit 2
fi
mkdir -p "$base/source" "$base/default" "$base/explicit-platform"
cp "$0" "$base/source/controller-script.sh"
cp "$src" "$base/source/maestro-format.grantiva-android.yml"
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/candidate-head.txt"
sed -n '30,44p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/android.md > "$base/source/docs-android-30-44.txt"
sed -n '136,185p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md > "$base/source/README-native-and-maestro-config.txt"
sed -n '200,255p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/FlowStagingTests.swift > "$base/source/FlowStagingTests-K24.txt"
rg -n 'testAMaestroFormatAndroidConfigLoadsWithAndroidDefaults|testAnAndroidFlagStillWinsOverTheMaestroAppId' /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli/B3-L31/ci-run-38227743323.log > "$base/source/exact-head-ci-k24-tests.txt"
run_one() {
  local name="$1" extra="$2"
  local d="$base/$name"
  cp "$src" "$d/grantiva-android.yml"
  printf '# cwd=%s\n$ %s diff capture --device emulator-5554 --no-build --verbose --json %s\n' "$d" "$GRANTIVA" "$extra" > "$d/commands.txt"
  cd "$d"
  # shellcheck disable=SC2086
  "$GRANTIVA" diff capture --device emulator-5554 --no-build --verbose --json $extra > stdout.json 2> stderr.log; rc=$?
  printf 'rc=%s\n' "$rc" >> commands.txt
  find .grantiva/captures/android -maxdepth 1 -type f -print | sort > captures.txt
  return "$rc"
}
run_one default ""
run_one explicit-platform "--platform android"
