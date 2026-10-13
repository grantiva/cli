#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K82b-artifact-separation-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/state"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k82b-artifact-separation-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
cp "$P/.maestro/coverage/02-exact-negative.yaml" "$base/input/02-exact-negative.yaml"

serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"

cd "$P" || exit 6
stash="$base/state/original-grantiva"
if [ -d .grantiva ]; then cp -R .grantiva "$stash"; else : > "$base/state/originally-absent"; fi
restore() {
  rm -rf .grantiva
  if [ -d "$stash" ]; then cp -R "$stash" .grantiva; fi
}
trap restore EXIT INT TERM

# Begin from a clean campaign-local artifact workspace while retaining a frozen
# copy above, so every inventory below belongs to these exact commands.
rm -rf .grantiva
mkdir -p .grantiva/baselines/android
printf 'retained stray baseline\n' > .grantiva/baselines/android/failure-legacy.png
printf 'retained stray baseline\n' > '.grantiva/baselines/android/01-browse-cmd-003-Home.png'
find .grantiva -type f -print | LC_ALL=C sort > "$base/state/initial-files.txt"

run_case() {
  name="$1"
  expected="$2"
  shift 2
  mkdir -p "$base/$name"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$name/commands.txt"
  "$@" > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  rc=$?
  echo "rc=$rc" >> "$base/$name/commands.txt"
  find .grantiva -type f -print | LC_ALL=C sort > "$base/$name/grantiva-files.txt"
  if [ "$expected" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}

failures=0
run_case capture zero "$GRANTIVA" diff capture --device "$serial" --no-build --json || failures=$((failures+1))
cp -R .grantiva/captures "$base/capture/captures-visible"
run_case run-pass zero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/01-browse.yaml --snapshot trailing || failures=$((failures+1))
run_case run-fail nonzero "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing || failures=$((failures+1))
cp -R .grantiva/run-captures "$base/run-fail/run-captures-visible"
find .grantiva/captures/android -maxdepth 1 -type f -print | LC_ALL=C sort > "$base/state/configured-captures-before-approve.txt"
run_case approve zero "$GRANTIVA" diff approve --json || failures=$((failures+1))
cp -R .grantiva/baselines "$base/approve/baselines-visible"
run_case compare zero "$GRANTIVA" diff compare --json || failures=$((failures+1))
cp -R .grantiva/baselines "$base/compare/baselines-visible"
cp -R .grantiva/captures "$base/compare/captures-visible"

test -f .grantiva/baselines/android/failure-legacy.png || failures=$((failures+1))
test -f '.grantiva/baselines/android/01-browse-cmd-003-Home.png' || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
