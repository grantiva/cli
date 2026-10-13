#!/bin/bash
# Supersedes v2 only by extending the frozen campaign-name inventory. The
# execution and safety logic remains byte-for-byte inherited below.
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/FINAL-primary-delete-rerun4"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/actions"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-final-primary-cleanup-v4.sh" "$base/input/controller-script.sh"
uptime > "$base/uptime-before.txt"
adb devices -l > "$base/adb-before.txt"
avdmanager list avd -c > "$base/avds-before.txt"
cp "$HOME/.grantiva/android/started.json" "$base/started-before.json" 2>/dev/null || printf '[]\n' > "$base/started-before.json"
cp "$HOME/.grantiva/android/created-avds.json" "$base/created-before.json" 2>/dev/null || printf '[]\n' > "$base/created-before.json"

known_names='cov3-android cov3-android-timeout-r3 cov3-android-external-r3 cov3-android-reuse-r3 cov3-android-port-r3 cov3-android-scroll-sw-r3 cov3-android-scroll-gpu-r3 cov3-android-scroll-default-r4 cov3-android-offline-r3 cov3-android-n02-r3 cov3-android-k32-r4 cov3-android-k27-pty-r2 cov3-android-l03-hierarchy-r3 cov3-android-l03-gpu-r3 cov3-android-k106-r3 cov3-android-k106-r4 cov3-android-k106-r5 cov3-android-k106-r6 cov3-android-k106-l35-r1 cov3-android-n216-r1 cov3-android-n216-r2 cov3-android-n216-r3 cov3-android-n216-r4'
printf '%s\n' $known_names > "$base/input/known-campaign-names.txt"

adb devices | awk 'NR>1 && $2=="device" {print $1}' > "$base/attached-serials.txt"
while IFS= read -r serial; do
  [ -n "$serial" ] || continue
  name="$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
  printf '%s\t%s\n' "$serial" "$name" >> "$base/attached-name-map.tsv"
  case "$name" in
    cov3-android*) (cd "$P" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) > "$base/actions/$serial-teardown.json" 2> "$base/actions/$serial-teardown.err" || exit 3 ;;
  esac
done < "$base/attached-serials.txt"

avdmanager list avd -c > "$base/avds-predelete.txt"
while IFS= read -r name; do
  case "$name" in
    cov3-android*) (cd "$P" && "$GRANTIVA" emulator delete --name "$name" --force --json) > "$base/actions/$name-delete.json" 2> "$base/actions/$name-delete.err" || exit 4 ;;
  esac
done < "$base/avds-predelete.txt"

(cd "$P" && "$GRANTIVA" emulator sessions --json) > "$base/sessions-pruned.json" 2> "$base/sessions-pruned.err" || exit 5
uptime > "$base/uptime-after.txt"
adb devices -l > "$base/adb-after.txt"
avdmanager list avd -c > "$base/avds-after.txt"
cp "$HOME/.grantiva/android/started.json" "$base/started-after.json" 2>/dev/null || printf '[]\n' > "$base/started-after.json"
cp "$HOME/.grantiva/android/created-avds.json" "$base/created-after.json" 2>/dev/null || printf '[]\n' > "$base/created-after.json"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print > "$base/global-session-files-after.txt" 2>/dev/null || true

python3 -I - "$base" "$P" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]);project=str(pathlib.Path(sys.argv[2]).resolve())
adb=(b/'adb-after.txt').read_text();avds=(b/'avds-after.txt').read_text().splitlines();started=(b/'started-after.json').read_text();created=(b/'created-after.json').read_text()
attached=[x.split()[0] for x in adb.splitlines()[1:] if len(x.split())>1 and x.split()[1]=='device'];name_map={}
if (b/'attached-name-map.tsv').exists():
 for line in (b/'attached-name-map.tsv').read_text().splitlines():
  serial,name=line.split('\t',1);name_map[serial]=name
unowned=[s for s in attached if not name_map.get(s,'').startswith('cov3-android')]
session_files=[]
for p in pathlib.Path('/tmp/grantiva-sessions').glob('*'):
 if not p.is_file():continue
 try:body=p.read_text(errors='replace')
 except OSError:body=''
 if 'cov3-android' in p.name or 'cov3-android' in body or project in body:session_files.append(str(p))
checks={'noCampaignDeviceAttached':all(not name_map.get(s,'').startswith('cov3-android') for s in attached),'onlyUnownedDevicesMayRemain':attached==unowned,'noCampaignAVDInstalled':not any(n.startswith('cov3-android') for n in avds),'noCampaignStartedRecord':'cov3-android' not in started,'noCampaignCreatedRecord':'cov3-android' not in created,'noCampaignGlobalSessionFile':not session_files,'primaryDeleted':'cov3-android' not in avds}
out={'checks':checks,'attached':attached,'unownedAttached':unowned,'avds':avds,'campaignSessionFiles':session_files};(b/'decoded.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(checks,sort_keys=True));raise SystemExit(0 if all(checks.values()) else 1)
PY
