#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/wait-screens-complement-rerun2"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro/coverage/cfg"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-wait-screens-complement-v2.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/coverage/cfg/screens-steps.grantiva-android.yml" "$base/input/screens-steps.original.yml"
cp "$P/.maestro/coverage/cfg/relaunch.yaml" "$base/project/.maestro/coverage/cfg/relaunch.yaml"
cp "$P/.maestro/coverage/14-runflow-sub.yaml" "$base/project/.maestro/coverage/14-runflow-sub.yaml"
cp "$base/input/screens-steps.original.yml" "$base/project/grantiva-android.yml"
python3 -I - "$base/project/grantiva-android.yml" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
n='      - wait: 3\n      - assert_visible: "Cache Policy"'; assert s.count(n)==1
p.write_text(s.replace(n,'      - wait: 3\n      - wait: 1.5\n      - assert_visible: "Cache Policy"'))
PY
cp "$base/project/grantiva-android.yml" "$base/input/screens-steps-with-1.5.yml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
run_case() {
  name="$1"; shift; d="$base/$name"; mkdir -p "$d"
  printf '# cwd=%s\n$' "$base/project" > "$d/command.txt"; printf ' %q' "$@" >> "$d/command.txt"; printf '\n' >> "$d/command.txt"
  t0="$(python3 -I -c 'import time;print(time.monotonic())')"
  (cd "$base/project" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
  t1="$(python3 -I -c 'import time;print(time.monotonic())')"
  python3 -I - "$t0" "$t1" "$rc" > "$d/result.json" <<'PY'
import json,sys
print(json.dumps({'elapsedSeconds':float(sys.argv[2])-float(sys.argv[1]),'exitCode':int(sys.argv[3])},indent=2))
PY
  mkdir -p "$d/captures"; cp -R "$base/project/.grantiva/captures/android/." "$d/captures/" 2>/dev/null || true
}
run_case plain "$GRANTIVA" diff capture --platform android --device "$serial" --no-build
run_case json "$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); plain=(b/'plain/stdout.txt').read_text(); js=(b/'json/stdout.txt').read_text(); doc=json.loads(js)
def result(n): return json.loads((b/n/'result.json').read_text())
steps=[s for screen in doc['screens'] for s in screen['steps']]
wait3=[s for s in steps if s.get('action')=='Wait 3s']
wait15=[s for s in steps if s.get('action')=='Wait 1.5s']
checks={
 'plainExit0':result('plain')['exitCode']==0,
 'jsonExit0':result('json')['exitCode']==0,
 'plainWait3':('Wait 3s' in plain and 'evalScript' not in plain),
 'plainWait15':('Wait 1.5s' in plain and 'evalScript' not in plain),
 'jsonWait3':('Wait 3s' in js and 'evalScript' not in js),
 'jsonWait15':('Wait 1.5s' in js and 'evalScript' not in js),
 'jsonWait3DurationAtLeast3':len(wait3)==1 and wait3[0].get('duration',0)>=3,
 'jsonWait15DurationAtLeast15':len(wait15)==1 and wait15[0].get('duration',0)>=1.5,
}
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
print(json.dumps(checks,indent=2,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
