#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/output-contracts-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/projects"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-output-contracts-group.sh"
cp "$script_path" "$base/input/controller-script.sh"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
cp "$P/.maestro/coverage/02-exact-negative.yaml" "$base/input/02-exact-negative.yaml"

make_project() {
  local name="$1"
  mkdir -p "$base/projects/$name/.maestro/coverage"
  cp "$base/input/01-browse.yaml" "$base/projects/$name/.maestro/01-browse.yaml"
  cp "$base/input/02-exact-negative.yaml" "$base/projects/$name/.maestro/coverage/02-exact-negative.yaml"
}

for p in combined flows screens empty; do make_project "$p"; done
cat > "$base/projects/combined/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
screens:
  - name: Home
    path: launch
flows:
  - .maestro/01-browse.yaml
YAML
cat > "$base/projects/flows/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
flows:
  - .maestro/01-browse.yaml
YAML
cat > "$base/projects/screens/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
screens:
  - name: Home
    path: launch
YAML
cat > "$base/projects/empty/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
screens: []
flows: []
YAML
for p in combined flows screens empty; do cp "$base/projects/$p/grantiva-android.yml" "$base/input/$p.grantiva-android.yml"; done

run_case() {
  local name="$1"
  local project="$2"
  local expect="$3"
  shift 3
  local d="$base/$name"
  mkdir -p "$d/report"
  cd "$base/projects/$project"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$d/commands.txt"
  "$@" > "$d/stdout.log" 2> "$d/stderr.log"
  local rc=$?
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$d/commands.txt"
  if [ "$expect" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}

failures=0
adb devices -l > "$base/adb-before.txt"

# Four distinct narration shapes for B2-K13.
run_case B2-K13-combined combined zero "$GRANTIVA" run --device emulator-5554 --no-build --report-dir "$base/B2-K13-combined/report" || failures=$((failures + 1))
run_case B2-K13-flows flows zero "$GRANTIVA" run --device emulator-5554 --no-build --report-dir "$base/B2-K13-flows/report" || failures=$((failures + 1))
run_case B2-K13-screens screens zero "$GRANTIVA" run --device emulator-5554 --no-build --report-dir "$base/B2-K13-screens/report" || failures=$((failures + 1))
run_case B2-K13-flow-flag flows zero "$GRANTIVA" run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml --report-dir "$base/B2-K13-flow-flag/report" || failures=$((failures + 1))

# Empty work fails before device work and publishes a terminal ready file.
run_case AND-031 empty nonzero "$GRANTIVA" run --no-build --report-dir "$base/AND-031/report" --ready-file "$base/AND-031/ready.json" || failures=$((failures + 1))

# Passing/failing JSON, quiet precedence, structural failure, and report artifacts.
run_case JSON-pass flows zero "$GRANTIVA" run --device emulator-5554 --no-build --json --report-dir "$base/JSON-pass/report" || failures=$((failures + 1))
run_case JSON-fail flows nonzero "$GRANTIVA" run --device emulator-5554 --no-build --json --quiet --verbose --flow .maestro/coverage/02-exact-negative.yaml --report-dir "$base/JSON-fail/report" || failures=$((failures + 1))

# Exact plain/quiet/verbose stdout comparison inputs, plus a quiet text failure.
run_case AND-137-plain flows zero "$GRANTIVA" run --device emulator-5554 --no-build --json --flow .maestro/01-browse.yaml --report-dir "$base/AND-137-plain/report" || failures=$((failures + 1))
run_case AND-137-quiet flows zero "$GRANTIVA" run --device emulator-5554 --no-build --json --quiet --flow .maestro/01-browse.yaml --report-dir "$base/AND-137-quiet/report" || failures=$((failures + 1))
run_case AND-137-verbose flows zero "$GRANTIVA" run --device emulator-5554 --no-build --json --verbose --flow .maestro/01-browse.yaml --report-dir "$base/AND-137-verbose/report" || failures=$((failures + 1))
run_case AND-137-quiet-fail flows nonzero "$GRANTIVA" run --device emulator-5554 --no-build --quiet --flow .maestro/coverage/02-exact-negative.yaml --report-dir "$base/AND-137-quiet-fail/report" || failures=$((failures + 1))

# Diff capture plain/quiet/verbose JSON modes use the same one-screen config.
run_case AND-138-plain screens zero "$GRANTIVA" diff capture --device emulator-5554 --no-build --json || failures=$((failures + 1))
if [ -d "$base/projects/screens/.grantiva/captures" ]; then cp -R "$base/projects/screens/.grantiva/captures" "$base/AND-138-plain/captures"; else failures=$((failures + 1)); fi
run_case AND-138-quiet screens zero "$GRANTIVA" diff capture --device emulator-5554 --no-build --json --quiet || failures=$((failures + 1))
if [ -d "$base/projects/screens/.grantiva/captures" ]; then cp -R "$base/projects/screens/.grantiva/captures" "$base/AND-138-quiet/captures"; else failures=$((failures + 1)); fi
run_case AND-138-verbose screens zero "$GRANTIVA" diff capture --device emulator-5554 --no-build --json --verbose || failures=$((failures + 1))
if [ -d "$base/projects/screens/.grantiva/captures" ]; then cp -R "$base/projects/screens/.grantiva/captures" "$base/AND-138-verbose/captures"; else failures=$((failures + 1)); fi

adb devices -l > "$base/adb-after.txt"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
