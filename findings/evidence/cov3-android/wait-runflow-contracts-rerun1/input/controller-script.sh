#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/wait-runflow-contracts-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/screens/.maestro/coverage/cfg" "$base/runflow/.maestro/coverage" "$base/configless/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-wait-runflow-contracts-v1.sh" "$base/input/controller-script.sh"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 4

cp "$P/.maestro/coverage/cfg/screens-steps.grantiva-android.yml" "$base/input/screens-steps.original.yml"
cp "$P/.maestro/coverage/cfg/relaunch.yaml" "$base/screens/.maestro/coverage/cfg/relaunch.yaml"
cp "$P/.maestro/coverage/14-runflow.yaml" "$P/.maestro/coverage/14-runflow-sub.yaml" "$base/input/"
cp "$base/input/screens-steps.original.yml" "$base/screens/grantiva-android.yml"
python3 -I - "$base/screens/grantiva-android.yml" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
needle = '      - wait: 3\n      - assert_visible: "Cache Policy"'
assert s.count(needle) == 1
p.write_text(s.replace(needle, '      - wait: 3\n      - wait: 1.5\n      - assert_visible: "Cache Policy"'))
PY
cp "$base/screens/grantiva-android.yml" "$base/input/screens-steps-with-1.5.yml"
cp "$base/input/14-runflow.yaml" "$base/input/14-runflow-sub.yaml" "$base/runflow/.maestro/coverage/"
cp "$P/grantiva-android.yml" "$base/runflow/grantiva-android.yml"
cp "$base/input/14-runflow.yaml" "$base/configless/.maestro/14-runflow.yaml"
cp "$base/input/14-runflow-sub.yaml" "$base/configless/.maestro/14-runflow-sub.yaml"

run_case() {
  name="$1"; cwd="$2"; shift 2
  d="$base/$name"; mkdir -p "$d"
  printf '# cwd=%s\n$' "$cwd" > "$d/command.txt"; printf ' %q' "$@" >> "$d/command.txt"; printf '\n' >> "$d/command.txt"
  t0="$(python3 -I -c 'import time; print(time.monotonic())')"
  (cd "$cwd" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
  t1="$(python3 -I -c 'import time; print(time.monotonic())')"
  python3 -I - "$t0" "$t1" "$rc" > "$d/result.json" <<'PY'
import json, sys
print(json.dumps({'elapsedSeconds': float(sys.argv[2])-float(sys.argv[1]), 'exitCode': int(sys.argv[3])}, indent=2))
PY
  return 0
}

run_case screens-plain "$base/screens" "$GRANTIVA" diff capture --platform android --device "$serial" --no-build
mkdir -p "$base/screens-plain/captures"; cp -R "$base/screens/.grantiva/captures/android/." "$base/screens-plain/captures/" 2>/dev/null || true
run_case screens-json "$base/screens" "$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json
mkdir -p "$base/screens-json/captures"; cp -R "$base/screens/.grantiva/captures/android/." "$base/screens-json/captures/" 2>/dev/null || true

run_case runflow-plain "$base/runflow" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow.yaml
run_case runflow-report "$base/runflow" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow.yaml --report-dir "$base/runflow-report/report"
run_case runflow-json "$base/runflow" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow.yaml --json --report-dir "$base/runflow-json/report"

cat > "$base/runflow/.maestro/coverage/14-runflow-sub-fail.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- tapOn: "Deep Links"
- assertVisible: "Definitely Missing RunFlow Target"
YAML
sed 's/14-runflow-sub.yaml/14-runflow-sub-fail.yaml/g' "$base/input/14-runflow.yaml" > "$base/runflow/.maestro/coverage/14-runflow-fail.yaml"
cp "$base/runflow/.maestro/coverage/14-runflow-fail.yaml" "$base/runflow/.maestro/coverage/14-runflow-sub-fail.yaml" "$base/input/"
run_case runflow-fail-plain "$base/runflow" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow-fail.yaml
run_case runflow-fail-json "$base/runflow" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow-fail.yaml --json --report-dir "$base/runflow-fail-json/report"

run_case configless-header "$base/configless" "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/14-runflow.yaml --report-dir "$base/configless-header/report"

python3 -I - "$base" <<'PY'
import json, pathlib, sys
b=pathlib.Path(sys.argv[1])
def rc(n): return json.loads((b/n/'result.json').read_text())['exitCode']
plain=(b/'screens-plain/stdout.txt').read_text()
sj=(b/'screens-json/stdout.txt').read_text()
rp=(b/'runflow-plain/stdout.txt').read_text()
rr=(b/'runflow-report/stdout.txt').read_text()
rj=(b/'runflow-json/stdout.txt').read_text()
fp=(b/'runflow-fail-plain/stdout.txt').read_text()+(b/'runflow-fail-plain/stderr.txt').read_text()
fj=(b/'runflow-fail-json/stdout.txt').read_text()+(b/'runflow-fail-json/stderr.txt').read_text()
checks={
 'screensPlainExit0':rc('screens-plain')==0,
 'screensJsonExit0':rc('screens-json')==0,
 'wait3Plain':('Wait 3s' in plain and 'evalScript' not in plain),
 'wait15Plain':('Wait 1.5s' in plain and 'evalScript' not in plain),
 'waitElapsedAtLeast3':json.loads((b/'screens-plain/result.json').read_text())['elapsedSeconds']>=3,
 'wait3Json':('Wait 3s' in sj and 'evalScript' not in sj),
 'wait15Json':('Wait 1.5s' in sj and 'evalScript' not in sj),
 'runflowSuccessExits':all(rc(n)==0 for n in ['runflow-plain','runflow-report','runflow-json']),
 'relativeSuccessPlain':all('runFlow: 14-runflow-sub.yaml' in x for x in [rp,rr]),
 'relativeSuccessJson':'14-runflow-sub.yaml' in rj,
 'noStagedSuccess':all('grantiva-flows-' not in x for x in [rp,rr,rj]),
 'runflowFailureExits':all(rc(n)==1 for n in ['runflow-fail-plain','runflow-fail-json']),
 'relativeFailurePlain':'14-runflow-sub-fail.yaml' in fp,
 'relativeFailureJson':'14-runflow-sub-fail.yaml' in fj,
 'noStagedFailure':all('grantiva-flows-' not in x for x in [fp,fj]),
 'configlessHeaderExit0':rc('configless-header')==0,
}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
print(json.dumps(checks,indent=2,sort_keys=True))
raise SystemExit(0 if all(checks.values()) else 1)
PY
