#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/output-contracts-exact-rerun2"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro/coverage/cfg" "$base/common-run-report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-output-contracts-correction.sh" "$base/input/controller-script.sh"
cp -R "$P/.maestro/." "$base/project/.maestro/"
cp "$P/grantiva-android.yml" "$base/input/stock.grantiva-android.yml"
cp "$P/.maestro/coverage/cfg/screens-fail.grantiva-android.yml" "$base/input/screens-fail.grantiva-android.yml"
SER=""
while read -r candidate; do
  [ -z "$candidate" ] && continue
  avd=$(adb -s "$candidate" emu avd name 2>/dev/null | tr -d '\r' | head -1)
  if [ "$avd" = "cov3-android" ]; then
    if [ -n "$SER" ]; then echo 'multiple owned cov3-android serials attached' >&2; exit 3; fi
    SER="$candidate"
  else
    echo "unexpected attached Android target $candidate ($avd)" >&2
    exit 4
  fi
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
[ -n "$SER" ] || { echo 'owned cov3-android is not attached' >&2; exit 5; }
printf '%s\n' "$SER" > "$base/input/owned-serial.txt"
python3 -I - "$base/input/stock.grantiva-android.yml" "$base/input/flows-only.grantiva-android.yml" "$base/input/screens-only.grantiva-android.yml" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
prefix, rest = text.split("screens:\n", 1)
screens, rest = rest.split("flows:\n", 1)
flows, diff = rest.split("diff:\n", 1)
pathlib.Path(sys.argv[2]).write_text(prefix + "flows:\n" + flows + "diff:\n" + diff)
pathlib.Path(sys.argv[3]).write_text(prefix + "screens:\n" + screens + "diff:\n" + diff)
PY

run_case() {
  local name="$1" expect="$2"
  shift 2
  local d="$base/$name"
  mkdir -p "$d"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$d/commands.txt"
  "$@" > "$d/stdout.log" 2> "$d/stderr.log"
  local rc=$?
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$d/commands.txt"
  if [ "$expect" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}

cd "$base/project"
failures=0

# Exact 12-flow and five-screen focused shapes; combined 5+12 comes from retained AND-106.
cp "$base/input/flows-only.grantiva-android.yml" grantiva-android.yml
run_case B2-K13-flows12 zero "$GRANTIVA" run --device "$SER" --no-build --report-dir "$base/B2-K13-flows12/report" || failures=$((failures + 1))
cp "$base/input/screens-only.grantiva-android.yml" grantiva-android.yml
run_case B2-K13-screens5 zero "$GRANTIVA" run --device "$SER" --no-build --report-dir "$base/B2-K13-screens5/report" || failures=$((failures + 1))

# Exact combined failed-screens + passed-flow ready document and separated totals.
cp "$base/input/screens-fail.grantiva-android.yml" grantiva-android.yml
run_case B2-K20-ready nonzero "$GRANTIVA" run --device "$SER" --no-build --continue-on-failure --ready-file "$base/B2-K20-ready/ready.json" --report-dir "$base/B2-K20-ready/report" || failures=$((failures + 1))

# Keep the command, cwd, input and absolute report path identical across output modes.
cp "$base/input/flows-only.grantiva-android.yml" grantiva-android.yml
for mode in plain quiet verbose; do
  case "$mode" in
    plain) args=() ;;
    quiet) args=(--quiet) ;;
    verbose) args=(--verbose) ;;
  esac
  run_case "AND-137-$mode" zero "$GRANTIVA" run --device "$SER" --no-build --json "${args[@]}" --flow .maestro/01-browse.yaml --report-dir "$base/common-run-report" || failures=$((failures + 1))
  cp -R "$base/common-run-report" "$base/AND-137-$mode/report-preserved"
done

# Diff modes likewise share cwd/config/capture directory; preserve each resulting capture.
cp "$base/input/screens-only.grantiva-android.yml" grantiva-android.yml
for mode in plain quiet verbose; do
  case "$mode" in
    plain) args=() ;;
    quiet) args=(--quiet) ;;
    verbose) args=(--verbose) ;;
  esac
  run_case "AND-138-$mode" zero "$GRANTIVA" diff capture --device "$SER" --no-build --json "${args[@]}" || failures=$((failures + 1))
  if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-138-$mode/captures"; else failures=$((failures + 1)); fi
done

printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
