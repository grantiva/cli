#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/flow-wait-selector-contracts-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-flow-wait-selector-batch-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
for f in 01-selectors 02-exact-negative 04-point-taps 05-swipe-forms 09-waits; do cp "$P/.maestro/coverage/$f.yaml" "$base/input/$f.yaml"; done
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
run_flow() {
  name="$1"
  flow="$2"
  expected="$3"
  d="$base/$name"
  mkdir -p "$d"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q --snapshot full\n' "$PWD" "$GRANTIVA" "$serial" "$flow" "$d/report" > "$d/commands.txt"
  "$GRANTIVA" run --platform android --device "$serial" --no-build --flow "$flow" --report-dir "$d/report" --snapshot full > "$d/stdout.log" 2> "$d/stderr.log"
  rc=$?
  printf '%s\n' "$rc" > "$d/exit.txt"
  cp "$d/report/report.json" "$d/report-visible.json"
  cp "$d/report/maestro-runner.log" "$d/runner-visible.log"
  flowjson="$(find "$d/report/flows" -maxdepth 1 -name '*.json' -type f | head -1)"
  [ -n "$flowjson" ] || return 90
  cp "$flowjson" "$d/flow-visible.json"
  [ "$rc" -eq "$expected" ]
}
failures=0
run_flow K01-selectors .maestro/coverage/01-selectors.yaml 0 || failures=$((failures+1))
run_flow K02-exact-negative .maestro/coverage/02-exact-negative.yaml 1 || failures=$((failures+1))
run_flow K01-point-taps .maestro/coverage/04-point-taps.yaml 0 || failures=$((failures+1))
run_flow K01-swipe-forms .maestro/coverage/05-swipe-forms.yaml 0 || failures=$((failures+1))
for i in $(seq 1 10); do run_flow "K08-wait-$i" .maestro/coverage/09-waits.yaml 0 || failures=$((failures+1)); done
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/cli-head.txt"
git -C /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b rev-parse HEAD > "$base/source/runner-head.txt"
rg -n -C 3 'Describe|SwipeCoords|notVisible|zero bounds|displayed|skipped|pending' /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/flow /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/driver/uiautomator2 /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/cli > "$base/source/runner-tests.txt" || true
python3 -I - "$base" <<'PY'
import json,glob,os,re,sys
b=sys.argv[1]
summary={'failures':int(open(os.path.join(b,'source','cli-head.txt')).read()==''), 'waits':[]}
for d in sorted(glob.glob(os.path.join(b,'K08-wait-*'))):
 x=json.load(open(os.path.join(d,'flow-visible.json')))
 # Preserve every matching wait command and its millisecond duration for exact <4s adjudication.
 found=[]
 def walk(v):
  if isinstance(v,dict):
   text=json.dumps(v,separators=(',',':'))
   if 'extendedWaitUntil' in text and 'notVisible' in text: found.append(v)
   for z in v.values(): walk(z)
  elif isinstance(v,list):
   for z in v: walk(z)
 walk(x)
 summary['waits'].append({'case':os.path.basename(d),'matches':found})
json.dump(summary,open(os.path.join(b,'wait-command-summary.json'),'w'),indent=2)
PY
printf 'failures=%s serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
[ "$failures" -eq 0 ]
