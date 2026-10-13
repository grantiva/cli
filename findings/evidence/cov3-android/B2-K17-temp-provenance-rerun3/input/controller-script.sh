#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K17-temp-provenance-rerun3"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/K17"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k17-temp-provenance-v3.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
printf '# cwd=%s\n$ %q diff capture --device %q --no-build --json --verbose\n' "$PWD" "$GRANTIVA" "$serial" > "$base/K17/commands.txt"
"$GRANTIVA" diff capture --device "$serial" --no-build --json --verbose > "$base/K17/stdout.log" 2> "$base/K17/stderr.log" &
pid=$!
echo "owned-shell-pid=$pid" >> "$base/K17/commands.txt"
report_path=""
copies=0
while kill -0 "$pid" 2>/dev/null; do
  if [ -z "$report_path" ]; then
    runner_line="$(grep -m1 '\$ .*grantiva-runner --platform android .* --output ' "$base/K17/stderr.log" 2>/dev/null || true)"
    case "$runner_line" in
      *" --device $serial "*) ;;
      "") ;;
      *) echo 'runner device mismatch' > "$base/K17/provenance-error.txt"; kill -INT "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; exit 7 ;;
    esac
    if [ -n "$runner_line" ]; then
      printf '%s\n' "$runner_line" > "$base/K17/runner-command-line.txt"
      report_path="$(printf '%s\n' "$runner_line" | awk '{for(i=1;i<=NF;i++)if($i=="--output"){print $(i+1);exit}}')"
      case "$report_path" in /var/folders/*/T/grantiva-report-*) ;; *) echo "$report_path" > "$base/K17/provenance-error.txt"; kill -INT "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; exit 8 ;; esac
      printf '%s\n' "$report_path" > "$base/K17/report-path.txt"
    fi
  fi
  if [ -n "$report_path" ] && [ -d "$report_path" ]; then
    copies=$((copies+1))
    [ -f "$report_path/report.json" ] && cp "$report_path/report.json" "$base/K17/latest-report.json"
    [ -f "$report_path/flows/flow-000.json" ] && cp "$report_path/flows/flow-000.json" "$base/K17/latest-flow-000.json"
  fi
  sleep 0.02
done
wait "$pid"
rc=$?
echo "rc=$rc" >> "$base/K17/commands.txt"
if [ -n "$report_path" ] && [ -d "$report_path" ]; then
  copies=$((copies+1))
  [ -f "$report_path/report.json" ] && cp "$report_path/report.json" "$base/K17/latest-report.json"
  [ -f "$report_path/flows/flow-000.json" ] && cp "$report_path/flows/flow-000.json" "$base/K17/latest-flow-000.json"
fi
printf 'rc=%s copies=%s report=%s flow=%s\n' "$rc" "$copies" "$([ -s "$base/K17/latest-report.json" ] && echo yes || echo no)" "$([ -s "$base/K17/latest-flow-000.json" ] && echo yes || echo no)" > "$base/summary.txt"
[ "$rc" -eq 0 ] && [ -s "$base/K17/latest-report.json" ] && [ -s "$base/K17/latest-flow-000.json" ]
