#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-A08-log-levels-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-ba08-log-levels-v1.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/08-caching.yaml" "$base/input/08-caching.yaml"
cp "$base/input/08-caching.yaml" "$base/project/.maestro/08-caching.yaml"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
run_case() {
  name="$1"; shift; d="$base/$name"; mkdir -p "$d/report"
  printf '# cwd=%s\n$' "$base/project" > "$d/command.txt"; printf ' %q' "$@" >> "$d/command.txt"; printf '\n' >> "$d/command.txt"
  (cd "$base/project" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; printf '%s\n' "$?" > "$d/exit.txt"
}
common=("$GRANTIVA" run --platform android --device "$serial" --no-build --logs --verbose --flow .maestro/08-caching.yaml)
run_case implicit-default "${common[@]}" --report-dir "$base/implicit-default/report"
run_case explicit-default "${common[@]}" --logs-level default --report-dir "$base/explicit-default/report"
run_case info "${common[@]}" --logs-level info --report-dir "$base/info/report"
run_case debug "${common[@]}" --logs-level debug --report-dir "$base/debug/report"
run_case invalid-warning "${common[@]}" --logs-level warning --report-dir "$base/invalid-warning/report"
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/source/candidate-head.txt"
sed -n '135,188p;270,290p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/AndroidPlatformTests.swift > "$base/source/android-platform-tests.txt"
sed -n '215,238p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunCommandTests.swift > "$base/source/run-command-test-excerpt.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1])
def rc(n): return int((b/n/'exit.txt').read_text())
def err(n): return (b/n/'stderr.txt').read_text()
lines={n:[x for x in err(n).splitlines() if ' logcat ' in x and 'stopped by' not in x] for n in ['implicit-default','explicit-default','info','debug']}
checks={
 'validExits0':all(rc(n)==0 for n in lines),
 'invalidExit64':rc('invalid-warning')==64,
 'invalidNamesValues':all(x in (err('invalid-warning')+(b/'invalid-warning/stdout.txt').read_text()) for x in ['default','info','debug']),
 'oneStartCommandEach':all(len(v)==1 for v in lines.values()),
 'implicitDefaultInfo':len(lines['implicit-default'])==1 and "*:I" in lines['implicit-default'][0],
 'explicitDefaultInfo':len(lines['explicit-default'])==1 and "*:I" in lines['explicit-default'][0],
 'infoInfo':len(lines['info'])==1 and "*:I" in lines['info'][0],
 'debugDebug':len(lines['debug'])==1 and "*:D" in lines['debug'][0],
 'allUseTimestamp':all('-T ' in v[0] for v in lines.values() if v),
 'noneClearLogcat':all('logcat -c' not in err(n) for n in lines),
}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'startCommands':lines},indent=2,sort_keys=True)+'\n')
print(json.dumps(checks,indent=2,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
