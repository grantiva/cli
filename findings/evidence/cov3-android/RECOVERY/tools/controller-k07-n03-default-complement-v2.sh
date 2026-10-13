#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K07-N03-default-complement-rerun2"; name=cov3-android-scroll-default-r4; primary=emulator-5554
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k07-n03-default-complement-v2.sh" "$base/input/controller-script.sh"; cp "$P/.maestro/10-seed-many.yaml" "$base/project/.maestro/10-seed-many.yaml"; cp "$base/project/.maestro/10-seed-many.yaml" "$base/input/10-seed-many.yaml"; cp "$W/findings/evidence/cov3-android/D2-09-shutdown-appfile-capture-rerun1/input/app.apk" "$base/input/app.apk"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3; [ "$(adb -s "$primary" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
cleanup(){ for s in $(adb devices|awk '$2=="device"{print $1}'); do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done; avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true; }
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 5
cfg="$(avdmanager list avd | awk -v n="$name" '$0 ~ "Name: "n {f=1} f && /Path:/ {sub(/^.*Path: /,""); print; exit}')/config.ini"; [ -f "$cfg" ] || exit 6; sed -i '' '/^hw.gpu.enabled=/d;/^hw.gpu.mode=/d' "$cfg"; printf 'hw.gpu.enabled=no\nhw.gpu.mode=auto\n' >> "$cfg"; cp "$cfg" "$base/software-config.ini"
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name") > "$base/ensure.out" 2> "$base/ensure.err" || exit 7
serial="$(tail -1 "$base/ensure.out"|tr -d '[:space:]')"; [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 8
(cd "$base/project" && "$GRANTIVA" build install --platform android --device "$serial" --application-id com.kylebrowning.landmarks --no-build --app-file "$base/input/app.apk") > "$base/install.out" 2> "$base/install.err" || exit 9
run_one(){ label="$1"; s="$2"; d="$base/runs/$label"; mkdir -p "$d/report"; uptime > "$d/uptime-before.txt"; adb -s "$s" shell pm clear com.kylebrowning.landmarks > "$d/pm-clear.out" 2> "$d/pm-clear.err" || return 10; (cd "$base/project" && "$GRANTIVA" run --platform android --device "$s" --no-build --flow .maestro/10-seed-many.yaml --report-dir "$d/report") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; adb -s "$s" shell uiautomator dump /sdcard/cov3-default.xml > "$d/dump.out" 2> "$d/dump.err" || true; adb -s "$s" pull /sdcard/cov3-default.xml "$d/hierarchy.xml" > "$d/pull.out" 2> "$d/pull.err" || true; uptime > "$d/uptime-after.txt"; return "$rc"; }
failures=0; for i in 1 2 3 4 5; do run_one "fresh-$i" "$serial" || failures=$((failures+1)); done
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) > "$base/teardown.json" 2> "$base/teardown.err" || failures=$((failures+1)); (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) > "$base/delete.json" 2> "$base/delete.err" || failures=$((failures+1))
for i in 1 2 3; do run_one "warm-$i" "$primary" || failures=$((failures+1)); done
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir()):
 r=json.loads((d/'report/report.json').read_text()) if (d/'report/report.json').exists() else {}; h=(d/'hierarchy.xml').read_text(errors='replace') if (d/'hierarchy.xml').exists() else ''; nums=[int(x) for x in re.findall(r'(?:text|content-desc)="Landmark (\d+)"',h)]
 rows.append({'label':d.name,'exitCode':int((d/'exit.txt').read_text()),'status':r.get('status'),'lastVisibleLandmark':max(nums) if nums else None})
fresh=[x for x in rows if x['label'].startswith('fresh-')]; warm=[x for x in rows if x['label'].startswith('warm-')]; land=[x['lastVisibleLandmark'] for x in rows if x['lastVisibleLandmark'] is not None]
checks={'fiveFresh':len(fresh)==5,'threeWarm':len(warm)==3,'allPass':all(x['exitCode']==0 and x['status']=='passed' for x in rows),'allHaveLanding':len(land)==8,'landingSpreadAtMostOne':bool(land) and max(land)-min(land)<=1,'softwareConfig':'hw.gpu.enabled=no' in (b/'software-config.ini').read_text() and 'hw.gpu.mode=auto' in (b/'software-config.ini').read_text(),'ownedAVDRemoved':'cov3-android-scroll-default-r4' not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'rows':rows},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
dec=$?; [ "$dec" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
