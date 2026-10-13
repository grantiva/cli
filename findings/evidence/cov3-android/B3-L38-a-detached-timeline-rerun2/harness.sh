#!/bin/zsh
# Parent-executed detached timeline probe; protected primary, no lifecycle.
set -euo pipefail
if (( $# != 5 )); then echo "usage: $0 OUTPUT_ROOT PROJECT_SOURCE SERIAL GRANTIVA_BINARY CLIENT" >&2; exit 64; fi
root=$1; source_project=$2; serial=$3; grantiva=$4; client=$5
[[ ! -e $root && -d $source_project && -x $grantiva && -f $client && $serial == emulator-* ]] || exit 73
mkdir -p "$root/project"; rsync -a --exclude .grantiva --exclude .gradle --exclude build "$source_project/" "$root/project/"
cp "$0" "$root/harness.sh"; cp "$client" "$root/client.py"
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY
cleanup(){ (cd "$root/project" && "$grantiva" runner stop --json > "$root/trap-stop.json" 2> "$root/trap-stop.err") || true; }
trap cleanup EXIT
[[ ! -e $root/project/.grantiva/session.json ]] || exit 74
python3 -I "$root/client.py" "$root/run" "$root/project" "$grantiva" "$serial"
trap - EXIT
find "$root" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$root/all-files.sha256"
