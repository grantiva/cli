#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/output-modes-exact-rerun3"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/common-run-report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-output-modes-rerun3.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
cat > "$base/project/grantiva-android.yml" <<'YAML'
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
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
SER=""
while read -r candidate; do
  [ -z "$candidate" ] && continue
  avd=$(adb -s "$candidate" emu avd name 2>/dev/null | tr -d '\r' | head -1)
  if [ "$avd" = "cov3-android" ]; then
    [ -z "$SER" ] || { echo 'multiple owned serials' >&2; exit 3; }
    SER="$candidate"
  else
    echo "unexpected Android target $candidate ($avd)" >&2; exit 4
  fi
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
[ -n "$SER" ] || exit 5
printf '%s\n' "$SER" > "$base/input/owned-serial.txt"

run_case() {
  local name="$1"
  shift
  mkdir -p "$base/$name"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$base/$name/commands.txt"
  "$@" > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  local rc=$?
  printf 'rc=%s\n' "$rc" >> "$base/$name/commands.txt"
  [ "$rc" -eq 0 ]
}

cd "$base/project"
failures=0
run_case AND-137-plain "$GRANTIVA" run --device "$SER" --no-build --json --flow .maestro/01-browse.yaml --report-dir "$base/common-run-report" || failures=$((failures + 1))
cp -R "$base/common-run-report" "$base/AND-137-plain/report-preserved"
run_case AND-137-quiet "$GRANTIVA" run --device "$SER" --no-build --json --quiet --flow .maestro/01-browse.yaml --report-dir "$base/common-run-report" || failures=$((failures + 1))
cp -R "$base/common-run-report" "$base/AND-137-quiet/report-preserved"
run_case AND-137-verbose "$GRANTIVA" run --device "$SER" --no-build --json --verbose --flow .maestro/01-browse.yaml --report-dir "$base/common-run-report" || failures=$((failures + 1))
cp -R "$base/common-run-report" "$base/AND-137-verbose/report-preserved"

run_case AND-138-plain "$GRANTIVA" diff capture --device "$SER" --no-build --json || failures=$((failures + 1))
[ -d .grantiva/captures ] && cp -R .grantiva/captures "$base/AND-138-plain/captures"
run_case AND-138-quiet "$GRANTIVA" diff capture --device "$SER" --no-build --json --quiet || failures=$((failures + 1))
[ -d .grantiva/captures ] && cp -R .grantiva/captures "$base/AND-138-quiet/captures"
run_case AND-138-verbose "$GRANTIVA" diff capture --device "$SER" --no-build --json --verbose || failures=$((failures + 1))
[ -d .grantiva/captures ] && cp -R .grantiva/captures "$base/AND-138-verbose/captures"

printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
