#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/D2-28-invalid-system-image-rerun1"; name=cov3-android-invalid99-r1; package='system-images;android-99;bogus;arm64-v8a'
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-d228-invalid-system-image-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
avdmanager list avd -c > "$base/avds-before.txt"; adb devices -l > "$base/adb-before.txt"
! avdmanager list avd -c | grep -Fxq "$name" || exit 3
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-before.json"; done
printf '$ %q emulator ensure --name %q --system-image %q --no-boot\n' "$GRANTIVA" "$name" "$package" > "$base/command.txt"
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --system-image "$package" --no-boot) > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?; echo "$rc" > "$base/exit.txt"
avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-after.json"; done
# Safety cleanup only if the invalid request unexpectedly created the exact row-owned name.
if avdmanager list avd -c | grep -Fxq "$name"; then avdmanager delete avd -n "$name" > "$base/unexpected-cleanup.out" 2> "$base/unexpected-cleanup.err"; fi
python3 -I - "$base" "$name" "$package" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,pkg=sys.argv[2:]; rc=int((b/'exit.txt').read_text()); text=(b/'stdout.txt').read_text()+(b/'stderr.txt').read_text(); low=text.lower(); after=(b/'avds-after.txt').read_text(); created=(b/'created-avds-after.json').read_text() if (b/'created-avds-after.json').exists() else '[]'
checks={'nonzero':rc!=0,'namesPackage':pkg in text,'sdkmanagerReason':'sdkmanager' in low and any(x in low for x in ['failed','not found','failed to find','package path is not valid','could not find']),'listsInstalledImages':'system-images;android-' in text and ('installed' in low or 'available' in low),'createsNoAVD':name not in after,'createsNoLedgerRecord':name not in created,'adbUnchanged':(b/'adb-before.txt').read_bytes()==(b/'adb-after.txt').read_bytes()}
(b/'decoded.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
