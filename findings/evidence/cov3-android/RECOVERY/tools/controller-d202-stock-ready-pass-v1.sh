#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/D2-02-stock-ready-pass-rerun1"
serial=emulator-5554
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-d202-stock-ready-pass-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
find "$P/.maestro" -maxdepth 1 -type f -name '*.yaml' -print | sort | xargs shasum -a 256 > "$base/input/maestro-yaml.sha256"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
ready="$base/ready.json"; report="$base/report"
{ printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --ready-file %q --report-dir %q\n' "$P" "$GRANTIVA" "$serial" "$ready" "$report"; } > "$base/command.txt"
(cd "$P" && "$GRANTIVA" run --platform android --device "$serial" --no-build --ready-file "$ready" --report-dir "$report") > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?
echo "$rc" > "$base/exit.txt"
$adb_bin -s "$serial" get-state > "$base/adb-after.txt" 2> "$base/adb-after.err"; arc=$?
python3 -I - "$base" "$report" "$rc" "$arc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); expected=str(pathlib.Path(sys.argv[2]).resolve()); ready=json.loads((b/'ready.json').read_text()); report=json.loads((b/'report/report.json').read_text())
flows=ready.get('flows',[]); names=[x.get('name') for x in flows]
checks={'exit0':int(sys.argv[3])==0,'deviceStillAlive':int(sys.argv[4])==0,'readyPassed':ready.get('status')=='passed','reportPassed':report.get('status')=='passed','reportDirExact':ready.get('reportDir')==expected,'screensFirst':bool(names) and names[0]=='screens','flowsFollow':names[1:]==['01-browse','02-favorite','03-edit','04-discard','05-category','06-visit','07-deeplink','08-caching','09-seed-empty','10-seed-many','11-slow','12-quote-label']}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'readyFlowNames':names,'ready':ready},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
