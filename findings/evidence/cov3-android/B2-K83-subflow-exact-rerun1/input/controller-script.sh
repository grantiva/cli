#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K83-subflow-exact-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/projects"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k83-subflow-v1.sh" "$base/input/controller-script.sh"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5

make_project() {
  name="$1"; form="$2"; subshot="$3"; duplicate="$4"
  d="$base/projects/$name"; mkdir -p "$d"
  {
    echo 'appId: com.kylebrowning.landmarks'; echo '---'; echo '- tapOn: "Landmarks"'
    [ "$subshot" = yes ] && echo '- takeScreenshot: "FromSub"'
    [ "$duplicate" = yes ] && echo '- takeScreenshot: "Main"'
  } > "$d/sub.yaml"
  {
    echo 'appId: com.kylebrowning.landmarks'; echo '---'; echo '- launchApp'
    if [ "$form" = scalar ]; then echo '- runFlow: sub.yaml'; else printf '%s\n' '- runFlow:' '    file: sub.yaml'; fi
    echo '- takeScreenshot: "Main"'
  } > "$d/grantiva-android.yml"
}
make_project scalar scalar yes no
make_project mapping mapping yes no
make_project no-shot scalar no no
make_project duplicate scalar yes yes
mkdir -p "$base/projects/missing"
cat > "$base/projects/missing/grantiva-android.yml" <<'EOF'
appId: com.kylebrowning.landmarks
---
- launchApp
- runFlow: missing.yaml
- takeScreenshot: "Main"
EOF
cp -R "$base/projects" "$base/input/projects"

run_case() {
  name="$1"; expected="$2"; d="$base/projects/$name"; mkdir -p "$base/$name"; cd "$d" || return 1
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json; echo; } > "$base/$name/commands.txt"
  "$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  rc=$?; echo "rc=$rc" >> "$base/$name/commands.txt"
  find .grantiva -type f -print 2>/dev/null | LC_ALL=C sort > "$base/$name/grantiva-files.txt"
  [ ! -d .grantiva/captures ] || cp -R .grantiva/captures "$base/$name/captures-visible"
  if [ "$expected" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}
failures=0
run_case scalar zero || failures=$((failures+1))
run_case mapping zero || failures=$((failures+1))
run_case no-shot zero || failures=$((failures+1))
run_case duplicate nonzero || failures=$((failures+1))
run_case missing nonzero || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
