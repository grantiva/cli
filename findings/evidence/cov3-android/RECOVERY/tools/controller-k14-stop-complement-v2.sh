#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K14-stop-complement-rerun2"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/other-dir"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k14-stop-complement-v2.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/coverage/18-long-wait.yaml" "$base/input/18-long-wait.yaml"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 5
cd "$P" || exit 6
rp=""
cleanup() {
  cd "$P" 2>/dev/null || true
  if [ -n "$rp" ] && kill -0 "$rp" 2>/dev/null; then "$GRANTIVA" runner stop --json > "$base/trap-stop.out" 2> "$base/trap-stop.err" || true; wait "$rp" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
# Baseline no-session behavior in both forms.
"$GRANTIVA" runner stop > "$base/no-session-plain.out" 2> "$base/no-session-plain.err"; nprc=$?
"$GRANTIVA" runner stop --json > "$base/no-session-json.out" 2> "$base/no-session-json.err"; njrc=$?
ready="$base/active-ready.json"
printf '# cwd=%s\n$ %q run --device %q --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml --ready-file %q --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$ready" "$base/report" > "$base/commands.txt"
"$GRANTIVA" run --device "$serial" --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml --ready-file "$ready" --report-dir "$base/report" > "$base/run.out" 2> "$base/run.err" & rp=$!; echo "owned-run-pid=$rp" >> "$base/commands.txt"
seen=0
for attempt in $(seq 1 30); do
  owner=""
  for candidate in /tmp/grantiva-sessions/*.owner.json; do
    [ -f "$candidate" ] || continue
    project="$(jq -r '.projectDirectory // empty' "$candidate" 2>/dev/null || true)"
    command="$(jq -r '.command // empty' "$candidate" 2>/dev/null || true)"
    if [ "$project" = "$P" ] && printf '%s' "$command" | grep -q '18-long-wait'; then owner="$candidate"; break; fi
  done
  if [ -n "$owner" ] && kill -0 "$rp" 2>/dev/null && grep -q '18-long-wait' "$base/run.err"; then seen=1; cp "$owner" "$base/owner-active.json"; break; fi
  sleep 1
done
[ "$seen" -eq 1 ] || { kill -INT "$rp" 2>/dev/null || true; wait "$rp" 2>/dev/null || true; exit 7; }
# A different project directory must observe no local session and leave this owner alive.
cd "$base/other-dir" || exit 8
"$GRANTIVA" runner stop > "$base/other-plain.out" 2> "$base/other-plain.err"; oprc=$?
kill -0 "$rp" 2>/dev/null || exit 9
"$GRANTIVA" runner stop --json > "$base/other-json.out" 2> "$base/other-json.err"; ojrc=$?
kill -0 "$rp" 2>/dev/null || exit 10
# Plain stop in the owning directory lands during the flow and must interrupt it.
cd "$P" || exit 11
"$GRANTIVA" runner stop > "$base/owner-plain.out" 2> "$base/owner-plain.err"; sprc=$?
wait "$rp"; rrc=$?
cp "$ready" "$base/ready-after-stop.json"
find .grantiva -maxdepth 2 -type f -print | LC_ALL=C sort > "$base/grantiva-after.txt"
adb forward --list > "$base/forwards-after.txt"
rp=""
printf 'no-plain=%s no-json=%s other-plain=%s other-json=%s owner-stop=%s run=%s ready=%s\n' "$nprc" "$njrc" "$oprc" "$ojrc" "$sprc" "$rrc" "$(jq -r '.status' "$ready")" > "$base/summary.txt"
[ "$nprc" -eq 0 ] && [ "$njrc" -eq 0 ] && [ "$oprc" -eq 0 ] && [ "$ojrc" -eq 0 ] && [ "$sprc" -eq 0 ] && [ "$(jq -r '.status' "$ready")" = interrupted ] && test ! -e .grantiva/session.json
