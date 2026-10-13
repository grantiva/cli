#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L58-first-tap-parent-rerun1"; serial=emulator-5554; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l58-first-tap-parent-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/03-edit.yaml" "$base/project/.maestro/03-edit.yaml"
cat > "$base/project/.maestro/l58-parent.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- assertVisible: "Edit Landmark"
- tapOn: "Name"
- inputText: " Renamed"
- tapOn: "Done"
- assertVisible: "Golden Gate Bridge Renamed"
- takeScreenshot: "L58 Parent Tap"
YAML
cp "$base/project/.maestro/03-edit.yaml" "$base/input/03-edit.yaml"; cp "$base/project/.maestro/l58-parent.yaml" "$base/input/l58-parent.yaml"
$adb_bin -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
failures=0
run_one(){
  local name="$1" flow="$2" d="$base/runs/$1"; mkdir -p "$d"; uptime > "$d/uptime-before.txt"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow %q --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$flow" "$d/report" > "$d/command.txt"
  (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow "$flow" --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; uptime > "$d/uptime-after.txt"
  [ "$rc" -eq 0 ] || failures=$((failures+1))
}
run_one edit-1 .maestro/03-edit.yaml
run_one edit-2 .maestro/03-edit.yaml
run_one edit-3 .maestro/03-edit.yaml
run_one parent-scratch .maestro/l58-parent.yaml
python3 -I - "$base" <<'PY'
import datetime as dt,json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); results=[]
def tod(s):
 return dt.datetime.strptime(s,'%H:%M:%S.%f')
for d in sorted((b/'runs').iterdir()):
 log=(d/'report/maestro-runner.log').read_text(); client=(d/'report/client.log').read_text(); rc=int((d/'exit.txt').read_text())
 m=re.search(r'(?m)^(\d\d:\d\d:\d\d\.\d+) \[DEBUG\] Executing step 1: tapOn: text="Deep Links"',log)
 q=re.search(r'(?m)^(\d\d:\d\d:\d\d\.\d+) POST .*?/(?:element|elements) \[([0-9.]+)(ms|s)\].*?body=\{"strategy":"-android uiautomator","selector":"new UiSelector\(\)\.text\(\\"Deep Links\\"\)"',client)
 request_ms=(float(q.group(2))*1000 if q and q.group(3)=='s' else float(q.group(2))) if q else None
 overhead=(tod(q.group(1))-tod(m.group(1))).total_seconds()*1000-request_ms if m and q else None
 prior=client[:q.start()] if q else client
 name_plain='new UiSelector().text(\\"Name\\")' in client
 name_clickable=bool(re.search(r'Name.*\n.*?/attribute/clickable',client,re.S))
 page_source_after_name=bool(re.search(r'text\(\\"Name\\"\).*?attribute/clickable.*?GET .*?/source',client,re.S))
 results.append({'run':d.name,'exitCode':rc,'deepLinksOverheadMs':overhead,'plainDeepLinksFirst':q is not None and 'Deep Links' not in prior,'namePlainQuery':name_plain,'nameClickableChecked':name_clickable,'pageSourceAfterName':page_source_after_name})
checks={'allPass':all(x['exitCode']==0 for x in results),'threeEdits':sum(x['run'].startswith('edit-') and x['exitCode']==0 for x in results)==3,'allFirstTapOverheadUnder300':all(x['deepLinksOverheadMs'] is not None and 0<=x['deepLinksOverheadMs']<300 for x in results),'plainQueryFirst':all(x['plainDeepLinksFirst'] for x in results),'scratchParentLands':next(x for x in results if x['run']=='parent-scratch')['exitCode']==0,'scratchPlainName':next(x for x in results if x['run']=='parent-scratch')['namePlainQuery']}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'runs':results},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
decoded=$?; [ "$decoded" -eq 0 ] || failures=$((failures+1))
$adb_bin -s "$serial" get-state > "$base/adb-after.txt" 2> "$base/adb-after.err" || failures=$((failures+1))
echo "$failures" > "$base/failures.txt"; exit "$failures"
