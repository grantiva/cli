#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K17-temp-provenance-rerun2"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/K17"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k17-temp-provenance-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
tmp_root="$(getconf DARWIN_USER_TEMP_DIR)"
find "$tmp_root" -maxdepth 1 -type d -name 'grantiva-report-*' -print | LC_ALL=C sort > "$base/K17/preexisting.txt"
[ ! -s "$base/K17/preexisting.txt" ] || exit 6
cd "$P" || exit 7
printf '# cwd=%s\n# temp-root=%s\n$ %q diff capture --device %q --no-build --json --verbose\n' "$PWD" "$tmp_root" "$GRANTIVA" "$serial" > "$base/K17/commands.txt"
"$GRANTIVA" diff capture --device "$serial" --no-build --json --verbose > "$base/K17/stdout.log" 2> "$base/K17/stderr.log" &
pid=$!
echo "owned-shell-pid=$pid" >> "$base/K17/commands.txt"
i=0
while kill -0 "$pid" 2>/dev/null; do
  for d in "$tmp_root"/grantiva-report-*; do
    [ -d "$d" ] || continue
    i=$((i+1))
    printf '%s\t%s\n' "$i" "$d" >> "$base/K17/discoveries.txt"
    [ -f "$d/report.json" ] && cp "$d/report.json" "$base/K17/latest-report.json"
    [ -f "$d/flows/flow-000.json" ] && cp "$d/flows/flow-000.json" "$base/K17/latest-flow-000.json"
  done
  sleep 0.02
done
wait "$pid"
rc=$?
echo "rc=$rc" >> "$base/K17/commands.txt"
for d in "$tmp_root"/grantiva-report-*; do
  [ -d "$d" ] || continue
  i=$((i+1))
  printf '%s\t%s\n' "$i" "$d" >> "$base/K17/discoveries.txt"
  [ -f "$d/report.json" ] && cp "$d/report.json" "$base/K17/latest-report.json"
  [ -f "$d/flows/flow-000.json" ] && cp "$d/flows/flow-000.json" "$base/K17/latest-flow-000.json"
done
printf 'rc=%s discoveries=%s report=%s flow=%s\n' "$rc" "$i" "$([ -s "$base/K17/latest-report.json" ] && echo yes || echo no)" "$([ -s "$base/K17/latest-flow-000.json" ] && echo yes || echo no)" > "$base/summary.txt"
[ "$rc" -eq 0 ] && [ -s "$base/K17/latest-report.json" ] && [ -s "$base/K17/latest-flow-000.json" ]
