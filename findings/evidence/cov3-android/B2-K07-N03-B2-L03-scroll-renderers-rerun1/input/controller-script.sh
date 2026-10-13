#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K07-N03-B2-L03-scroll-renderers-rerun1"; swname=cov3-android-scroll-sw-r3; gpuname=cov3-android-scroll-gpu-r3; primary=emulator-5554
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project/.maestro" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k07-n03-l03-scroll-renderers-v1.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/10-seed-many.yaml" "$base/project/.maestro/10-seed-many.yaml"; cp "$base/project/.maestro/10-seed-many.yaml" "$base/input/10-seed-many.yaml"
cp "$W/findings/evidence/cov3-android/D2-09-shutdown-appfile-capture-rerun1/input/app.apk" "$base/input/app.apk"; shasum -a 256 "$base/input/app.apk" > "$base/input/app.sha256"
for n in "$swname" "$gpuname"; do avdmanager list avd -c | grep -Fxq "$n" && exit 3; done
[ "$(adb -s "$primary" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
primary_cfg="$(avdmanager list avd | awk '$0 ~ "Name: cov3-android" {f=1} f && /Path:/ {sub(/^.*Path: /,""); print; exit}')/config.ini"; [ -f "$primary_cfg" ] || exit 5; cp "$primary_cfg" "$base/primary-config.ini"
cleanup(){
 for s in $(adb devices|awk '$2=="device"{print $1}'); do n="$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; { [ "$n" = "$swname" ] || [ "$n" = "$gpuname" ]; } && (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$s" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; done
 for n in "$swname" "$gpuname"; do avdmanager list avd -c | grep -Fxq "$n" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$n" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true; done
}
trap cleanup EXIT
write_config(){ cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $1
YAML
}
avd_path(){ avdmanager list avd | awk -v n="$1" '$0 ~ "Name: "n {f=1} f && /Path:/ {sub(/^.*Path: /,""); print; exit}'; }
boot_owned(){
 n="$1"; renderer="$2"; write_config "$n"; (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$n" --no-boot) > "$base/$n-create.out" 2> "$base/$n-create.err" || return 10
 cfg="$(avd_path "$n")/config.ini"; [ -f "$cfg" ] || return 11; cp "$cfg" "$base/$n-config-before.ini"
 if [ "$renderer" = gpu ]; then sed -i '' '/^hw.gpu.enabled=/d;/^hw.gpu.mode=/d' "$cfg"; printf 'hw.gpu.enabled=yes\nhw.gpu.mode=host\n' >> "$cfg"; else sed -i '' '/^hw.gpu.enabled=/d;/^hw.gpu.mode=/d' "$cfg"; printf 'hw.gpu.enabled=no\nhw.gpu.mode=auto\n' >> "$cfg"; fi
 cp "$cfg" "$base/$n-config-used.ini"; (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$n") > "$base/$n-ensure.out" 2> "$base/$n-ensure.err" || return 12
 tail -1 "$base/$n-ensure.out" | tr -d '[:space:]'
}
install_app(){ s="$1"; (cd "$base/project" && "$GRANTIVA" build install --platform android --device "$s" --application-id com.kylebrowning.landmarks --no-build --app-file "$base/input/app.apk") > "$base/install-$s.out" 2> "$base/install-$s.err"; }
run_one(){
 label="$1"; serial="$2"; snapshot="$3"; renderer="$4"; d="$base/runs/$label"; mkdir -p "$d/report"
 uptime > "$d/uptime-before.txt"; adb -s "$serial" shell pm clear com.kylebrowning.landmarks > "$d/pm-clear.out" 2> "$d/pm-clear.err" || return 20
 extra=(); [ "$snapshot" = full ] && extra=(--snapshot full)
 printf 'serial=%s renderer=%s snapshot=%s\n' "$serial" "$renderer" "$snapshot" > "$d/input.txt"
 (cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/10-seed-many.yaml --report-dir "$d/report" "${extra[@]}") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"
 adb -s "$serial" shell uiautomator dump /sdcard/cov3-scroll.xml > "$d/dump.out" 2> "$d/dump.err" || true; adb -s "$serial" pull /sdcard/cov3-scroll.xml "$d/hierarchy.xml" > "$d/pull.out" 2> "$d/pull.err" || true
 uptime > "$d/uptime-after.txt"; return "$rc"
}
failures=0
swserial="$(boot_owned "$swname" software)" || exit $?; [ "$(adb -s "$swserial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$swname" ] || exit 13; install_app "$swserial" || exit 14
for i in 1 2 3 4 5; do run_one "fresh-default-$i" "$swserial" none software || failures=$((failures+1)); done
for i in 1 2; do run_one "fresh-full-$i" "$swserial" full software || failures=$((failures+1)); done
run_one software-full-3 "$swserial" full software || failures=$((failures+1))
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$swserial" --force --json) > "$base/sw-teardown.json" 2> "$base/sw-teardown.err" || failures=$((failures+1)); (cd "$base/project" && "$GRANTIVA" emulator delete --name "$swname" --force --json) > "$base/sw-delete.json" 2> "$base/sw-delete.err" || failures=$((failures+1))
write_config cov3-android
for i in 1 2 3; do run_one "warm-default-$i" "$primary" none software || failures=$((failures+1)); done
gpuserial="$(boot_owned "$gpuname" gpu)" || exit $?; [ "$(adb -s "$gpuserial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$gpuname" ] || exit 15; install_app "$gpuserial" || exit 16
for i in 1 2 3; do run_one "gpu-full-$i" "$gpuserial" full gpu || failures=$((failures+1)); done
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); rows=[]
for d in sorted((b/'runs').iterdir()):
 r=json.loads((d/'report/report.json').read_text()) if (d/'report/report.json').exists() else {}; h=(d/'hierarchy.xml').read_text(errors='replace') if (d/'hierarchy.xml').exists() else ''; nums=[int(x) for x in re.findall(r'(?:text|content-desc)="Landmark (\d+)"',h)]
 log=(d/'report/client.log').read_text(errors='replace') if (d/'report/client.log').exists() else ''
 rows.append({'label':d.name,'exitCode':int((d/'exit.txt').read_text()),'status':r.get('status'),'lastVisibleLandmark':max(nums) if nums else None,'hasPointerActions':'/actions' in log,'input':(d/'input.txt').read_text().strip()})
fresh=[x for x in rows if x['label'].startswith('fresh-default-')]; full=[x for x in rows if x['label'].startswith('fresh-full-')]; warm=[x for x in rows if x['label'].startswith('warm-default-')]; swfull=[x for x in rows if x['label'].startswith('software-full-') or x['label'].startswith('fresh-full-')][:3]; gpu=[x for x in rows if x['label'].startswith('gpu-full-')]
checks={'fiveFreshDefault':len(fresh)==5,'twoFreshFull':len(full)==2,'threeWarmDefault':len(warm)==3,'threeSoftwareFull':len(swfull)==3,'threeGPUFull':len(gpu)==3,'allPass':all(x['exitCode']==0 and x['status']=='passed' for x in rows),'allHaveLanding':all(x['lastVisibleLandmark'] is not None for x in rows),'allHavePointerActions':all(x['hasPointerActions'] for x in swfull+gpu),'softwareConfig':'hw.gpu.enabled=no' in (b/'cov3-android-scroll-sw-r3-config-used.ini').read_text() and 'hw.gpu.mode=auto' in (b/'cov3-android-scroll-sw-r3-config-used.ini').read_text(),'primarySoftwareConfig':'hw.gpu.enabled=no' in (b/'primary-config.ini').read_text(),'gpuConfig':'hw.gpu.enabled=yes' in (b/'cov3-android-scroll-gpu-r3-config-used.ini').read_text() and 'hw.gpu.mode=host' in (b/'cov3-android-scroll-gpu-r3-config-used.ini').read_text(),'ownedAVDsRemoved':all(n not in (b/'avds-after.txt').read_text() for n in ['cov3-android-scroll-sw-r3','cov3-android-scroll-gpu-r3']),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'rows':rows},indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
dec=$?; [ "$dec" -eq 0 ] || failures=$((failures+1)); echo "$failures" > "$base/failures.txt"; exit "$failures"
