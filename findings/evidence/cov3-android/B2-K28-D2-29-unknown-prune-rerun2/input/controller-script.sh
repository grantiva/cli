#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K28-D2-29-unknown-prune-rerun2"; name=cov3-k28-prune-r2; unknown=emulator-5598
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k28-d229-unknown-prune-v2.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
avdmanager list avd -c > "$base/avds-before.txt"; adb devices -l > "$base/adb-before.txt"
! avdmanager list avd -c | grep -Fxq "$name" || exit 3
! adb devices | awk 'NR>1{print $1}' | grep -Fxq "$unknown" || exit 4
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-before.json"; done
[ ! -f "$HOME/.grantiva/android/started.json" ] || ! grep -Fq "$unknown" "$HOME/.grantiva/android/started.json" || exit 4
cleanup(){ avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force) > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true; }
trap cleanup EXIT INT TERM
run(){ stem="$1"; shift; d="$base/$stem"; mkdir -p "$d"; { printf '# cwd=%s\n$' "$base/project"; printf ' %q' "$@"; printf '\n'; } > "$d/command.txt"; (cd "$base/project" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; }
run ensure-no-boot "$GRANTIVA" emulator ensure --name "$name" --no-boot
[ "$(cat "$base/ensure-no-boot/exit.txt")" -eq 0 ] || exit 5
avdmanager list avd -c | grep -Fxq "$name" || exit 6
cp "$HOME/.grantiva/android/created-avds.json" "$base/ensure-no-boot/created-avds.json"
grep -Fq "$name" "$base/ensure-no-boot/created-avds.json" || exit 7
adb devices -l > "$base/ensure-no-boot/adb.txt"
mkdir -p "$base/out-of-band-delete"
printf '$ avdmanager delete avd -n %q\n' "$name" > "$base/out-of-band-delete/command.txt"
avdmanager delete avd -n "$name" > "$base/out-of-band-delete/stdout.txt" 2> "$base/out-of-band-delete/stderr.txt"; odrc=$?; echo "$odrc" > "$base/out-of-band-delete/exit.txt"
[ "$odrc" -eq 0 ] || exit 8
! avdmanager list avd -c | grep -Fxq "$name" || exit 9
cp "$HOME/.grantiva/android/created-avds.json" "$base/out-of-band-delete/created-avds-stale.json"
grep -Fq "$name" "$base/out-of-band-delete/created-avds-stale.json" || exit 10
run refuse-unknown "$GRANTIVA" emulator teardown --serial "$unknown"
cp "$HOME/.grantiva/android/created-avds.json" "$base/refuse-unknown/created-avds-after.json"
run force-unknown-text "$GRANTIVA" emulator teardown --serial "$unknown" --force
run force-unknown-json "$GRANTIVA" emulator teardown --serial "$unknown" --force --json
# Recreate through Grantiva so a normal JSON delete exercises the owned pretty-result branch.
run recreate-no-boot "$GRANTIVA" emulator ensure --name "$name" --no-boot
[ "$(cat "$base/recreate-no-boot/exit.txt")" -eq 0 ] || exit 11
run delete-json "$GRANTIVA" emulator delete --name "$name" --json
# If refused ownership was pruned, exact normal delete may reject; force cleans the row-owned AVD.
if avdmanager list avd -c | grep -Fxq "$name"; then run delete-force-cleanup "$GRANTIVA" emulator delete --name "$name" --force --json; fi
avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-after.json"; done
trap - EXIT INT TERM
python3 -I - "$base" "$name" "$unknown" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,unknown=sys.argv[2:]
def rc(n): return int((b/n/'exit.txt').read_text())
def text(n): return (b/n/'stdout.txt').read_text()+(b/n/'stderr.txt').read_text()
created=json.loads((b/'refuse-unknown/created-avds-after.json').read_text())
j=json.loads((b/'force-unknown-json/stdout.txt').read_text())
dj=json.loads((b/'delete-json/stdout.txt').read_text()) if rc('delete-json')==0 else {}
checks={'ensureNoBoot':rc('ensure-no-boot')==0,'outOfBandDeleteLeavesStaleRecord':int((b/'out-of-band-delete/exit.txt').read_text())==0 and name in json.loads((b/'out-of-band-delete/created-avds-stale.json').read_text()),'refusalNonzero':rc('refuse-unknown')!=0,'refusalNamesUnknown':unknown in text('refuse-unknown'),'refusalPrunesCreatedRecord':name not in created,'forceUnknownText0':rc('force-unknown-text')==0 and unknown in text('force-unknown-text') and ('no record' in text('force-unknown-text').lower() or 'nothing to do' in text('force-unknown-text').lower()),'forceUnknownJSON0':rc('force-unknown-json')==0 and j.get('recorded') is False and j.get('killed') is False,'prettyOwnedDeleteJSON':rc('delete-json')==0 and dj.get('deleted') is True and dj.get('name')==name and '\n  "deleted"' in (b/'delete-json/stdout.txt').read_text(),'ownedAVDAbsent':name not in (b/'avds-after.txt').read_text(),'adbUnchanged':(b/'adb-before.txt').read_bytes()==(b/'adb-after.txt').read_bytes()}
(b/'decoded.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
