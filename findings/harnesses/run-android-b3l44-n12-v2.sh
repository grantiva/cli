#!/bin/zsh
# Parent-executed immutable harness. It uses an already-owned Android device
# and performs captures only; it never creates, boots, shuts down, or deletes a device.
set -euo pipefail

if (( $# != 4 )); then
  echo "usage: $0 OUTPUT_ROOT PROJECT_SOURCE OWNED_SERIAL GRANTIVA_BINARY" >&2
  exit 64
fi

root=$1
source_project=$2
serial=$3
grantiva=$4
script_dir=${0:A:h}

[[ ! -e $root && -d $source_project && -x $grantiva ]] || exit 73
[[ $serial == emulator-* ]] || exit 74
mkdir -p "$root"
cp "$0" "$root/harness.sh"
cp "$script_dir/mcp-vrt-capture-client-v2.py" "$root/mcp-vrt-capture-client-v2.py"
mkdir "$root/project"
rsync -a --exclude .gradle --exclude build --exclude .grantiva "$source_project/" "$root/project/"
project=$root/project

export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "candidate_sha256=$(shasum -a 256 "$grantiva" | awk '{print $1}')"
  echo "owned_serial=$serial"
  echo "project_source=$source_project"
} > "$root/provenance.txt"

cleanup() {
  (cd "$project" && "$grantiva" runner stop --json > "$root/trap-stop.json" 2> "$root/trap-stop.err") || true
}
trap cleanup EXIT

cd "$project"
"$grantiva" runner start --platform android --device "$serial" \
  --application-id com.kylebrowning.landmarks --detach --json \
  > "$root/start.json" 2> "$root/start.err"

ready=0
mkdir "$root/readiness"
for poll in {1..30}; do
  if "$grantiva" runner dump-hierarchy --udid "$serial" --format json \
      > "$root/readiness/$poll.json" 2> "$root/readiness/$poll.err" \
      && rg -q 'Golden Gate Bridge' "$root/readiness/$poll.json"; then
    ready=1
    break
  fi
  sleep 0.25
done
(( ready == 1 )) || exit 75

python3 -I "$root/mcp-vrt-capture-client-v2.py" "$root/mcp" "$project" "$grantiva"
mkdir -p "$root/mcp-images"
cp -p "$project"/.grantiva/captures/android/*.png "$root/mcp-images/"
mkdir -p "$project/.grantiva/baselines/android"
cp -p "$root/mcp-images/"*.png "$project/.grantiva/baselines/android/"

for run in 1 2 3; do
  mkdir "$root/cli-$run"
  start_ns=$(python3 -c 'import time; print(time.time_ns())')
  "$grantiva" diff capture --no-build --platform android --device "$serial" --json \
    > "$root/cli-$run/capture.json" 2> "$root/cli-$run/capture.err"
  end_ns=$(python3 -c 'import time; print(time.time_ns())')
  echo $(( end_ns - start_ns )) > "$root/cli-$run/wall-nanoseconds.txt"
  mkdir "$root/cli-$run/images"
  cp -p "$project"/.grantiva/captures/android/*.png "$root/cli-$run/images/"
  "$grantiva" diff compare --platform android --json \
    > "$root/cli-$run/compare.json" 2> "$root/cli-$run/compare.err"
done

"$grantiva" runner stop --json > "$root/stop.json" 2> "$root/stop.err"
trap - EXIT

python3 - "$root" "$serial" <<'PY'
import json, pathlib, sys
r = pathlib.Path(sys.argv[1]); serial = sys.argv[2]
mcp = json.load(open(r / "mcp" / "capture.json"))
assert mcp["emulator"]["udid"] == serial
mcp_home = next(x for x in mcp["screens"] if x["screenName"] == "Home")
rows = []
for n in range(1, 4):
    capture = json.load(open(r / f"cli-{n}" / "capture.json"))
    compare = json.load(open(r / f"cli-{n}" / "compare.json"))
    assert capture["emulator"]["udid"] == serial
    assert len(capture["screens"]) == 5 and len(compare["screens"]) == 5
    assert all(x["passed"] for x in compare["screens"])
    home = next(x for x in capture["screens"] if x["screenName"] == "Home")
    delta = abs(home["sizeBytes"] - mcp_home["sizeBytes"]) / mcp_home["sizeBytes"]
    assert delta <= 0.10
    rows.append({
        "run": n,
        "mcpHomeBytes": mcp_home["sizeBytes"],
        "cliHomeBytes": home["sizeBytes"],
        "homeSizeDeltaFraction": delta,
        "homeSteps": home["steps"],
        "allFiveComparePassed": True,
    })
(r / "decoded.json").write_text(json.dumps({"rows": rows}, indent=2) + "\n")
PY

echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$root/provenance.txt"
find "$root" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$root/all-files.sha256"
