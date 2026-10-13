#!/bin/zsh
# Creates one uniquely named row-owned GPU AVD, installs the retained APK,
# runs the L03 v2 evidence harness with the protected software primary, then
# tears down/deletes only the row-owned AVD.
set -euo pipefail
if (( $# != 6 )); then
  echo "usage: $0 OUTPUT_ROOT PROJECT_SOURCE PRIMARY_SERIAL GRANTIVA_BINARY APP_APK GPU_AVD_NAME" >&2
  exit 64
fi
root=$1; source_project=$2; primary=$3; grantiva=$4; apk=$5; gpu_name=$6
script_dir=${0:A:h}; inner=$script_dir/run-android-l03-per-step-hierarchy-v10.sh
[[ ! -e $root && -d $source_project && -x $grantiva && -f $apk && -f $inner ]] || exit 73
[[ $primary == emulator-* && $gpu_name == cov3-* ]] || exit 74
mkdir -p "$root/control-project"
rsync -a --exclude .gradle --exclude build --exclude .grantiva "$source_project/" "$root/control-project/"
cp "$0" "$root/wrapper.sh"; cp "$inner" "$root/inner.sh"
project=$root/control-project
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY
cat > "$project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $gpu_name
YAML
cleanup() {
  if [[ -n ${gpu_serial:-} ]]; then
    (cd "$project" && "$grantiva" emulator teardown --serial "$gpu_serial" --force --json > "$root/trap-teardown.json" 2> "$root/trap-teardown.err") || true
  fi
  (cd "$project" && "$grantiva" emulator delete --name "$gpu_name" --force --json > "$root/trap-delete.json" 2> "$root/trap-delete.err") || true
}
trap cleanup EXIT
avdmanager list avd -c | grep -Fxq "$gpu_name" && exit 75
(cd "$project" && "$grantiva" emulator ensure --name "$gpu_name" --no-boot) > "$root/create.out" 2> "$root/create.err"
gpu_path=$(avdmanager list avd | awk -v n="$gpu_name" '$0 ~ "Name: "n {f=1} f && /Path:/ {sub(/^.*Path: /,""); print; exit}')
[[ -f $gpu_path/config.ini ]] || exit 76
sed -i '' '/^hw.gpu.enabled=/d;/^hw.gpu.mode=/d' "$gpu_path/config.ini"
printf 'hw.gpu.enabled=yes\nhw.gpu.mode=host\n' >> "$gpu_path/config.ini"
cp "$gpu_path/config.ini" "$root/gpu-config-used.ini"
gpu_serial=$(cd "$project" && "$grantiva" emulator ensure --name "$gpu_name" | tail -1 | tr -d '[:space:]')
[[ $gpu_serial == emulator-* ]] || exit 77
(cd "$project" && "$grantiva" build install --platform android --device "$gpu_serial" \
  --application-id com.kylebrowning.landmarks --no-build --app-file "$apk") > "$root/install.out" 2> "$root/install.err"
zsh "$inner" "$root/evidence" "$source_project" "$primary" "$gpu_serial" "$grantiva"
trap - EXIT; cleanup
adb devices -l > "$root/adb-after.txt"; avdmanager list avd -c > "$root/avds-after.txt"
! rg -q "$gpu_name" "$root/avds-after.txt"
rg -q "^$primary[[:space:]]+device" "$root/adb-after.txt"
find "$root" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$root/all-files.sha256"
