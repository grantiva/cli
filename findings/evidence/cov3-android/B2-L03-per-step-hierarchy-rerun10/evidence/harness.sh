#!/bin/zsh
# Parent-executed complement for B2-L03. Both serials must already be owned;
# this script performs no emulator lifecycle operations.
set -euo pipefail
if (( $# != 5 )); then
  echo "usage: $0 OUTPUT_ROOT PROJECT_SOURCE SOFTWARE_SERIAL GPU_SERIAL GRANTIVA_BINARY" >&2
  exit 64
fi
root=$1; source_project=$2; software_serial=$3; gpu_serial=$4; grantiva=$5
script_dir=${0:A:h}; source_reader=$script_dir/uia2-source-snapshot-v2.py; semantic_compare=$script_dir/compare-uia2-cli-app-semantics.py
[[ ! -e $root && -d $source_project && -x $grantiva ]] || exit 73
[[ $software_serial == emulator-* && $gpu_serial == emulator-* && $software_serial != $gpu_serial ]] || exit 74
mkdir -p "$root/project/.maestro/coverage"
rsync -a --exclude .gradle --exclude build --exclude .grantiva "$source_project/" "$root/project/"
cp "$0" "$root/harness.sh"
cp "$source_reader" "$root/uia2-source-snapshot-v2.py"
cp "$semantic_compare" "$root/compare-uia2-cli-app-semantics.py"
project=$root/project
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY
cat > "$project/.maestro/coverage/l03-step-hierarchy.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 10000
- scroll
- wait: 5000
- scroll
- wait: 5000
- scroll
- wait: 5000
- scroll
- wait: 5000
YAML

run_job=''
logcat_pid=''
cleanup() {
  (cd "$project" && "$grantiva" runner stop --json > "$root/trap-stop.json" 2> "$root/trap-stop.err") || true
  [[ -z $run_job ]] || wait "$run_job" 2>/dev/null || true
  if [[ -n $logcat_pid ]]; then
    kill "$logcat_pid" 2>/dev/null || true
    wait "$logcat_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
cd "$project"
for renderer in software gpu; do
  serial=$software_serial; [[ $renderer == gpu ]] && serial=$gpu_serial
  out=$root/$renderer; mkdir -p "$out"
  adb -s "$serial" shell pm clear com.kylebrowning.landmarks > "$out/pm-clear.out" 2> "$out/pm-clear.err"
  adb -s "$serial" logcat -c
  adb -s "$serial" logcat -v epoch > "$out/logcat.txt" 2> "$out/logcat.err" &
  logcat_pid=$!
  (
    set +e
    "$grantiva" run --platform android --device "$serial" --no-build --keep-alive --verbose \
      --flow .maestro/coverage/l03-step-hierarchy.yaml --report-dir "$out/report" \
      > "$out/stdout.txt" 2> "$out/stderr.txt"
    task_rc=$?; echo "$task_rc" > "$out/exit.txt"; exit "$task_rc"
  ) &
  run_job=$!
  # Wait until launchApp has completed and the seed-many app frame is live.
  launch_done=0
  for poll in {1..300}; do
    if rg -q 'Step 0 completed successfully.*launchApp' "$out/report/maestro-runner.log" 2>/dev/null; then launch_done=1; break; fi
    sleep .1
  done
  (( launch_done == 1 )) || exit 78
  # Before terminal publication, read the same UIA2 /source endpoint directly
  # through the row's existing adb forward. The helper preserves the actual
  # session ID, URL, HTTP response and timestamps.
  baseline=0
  for poll in {1..100}; do
    attempt="$out/source-0-attempt-$poll"
    python3 -I "$root/uia2-source-snapshot-v2.py" "$serial" "$out/report/client.log" "$attempt"
    if rg -q 'Golden Gate Bridge' "$attempt/hierarchy.xml" && rg -q 'All Landmarks' "$attempt/hierarchy.xml" && ! rg -q 'scroll down: dragged .*measured=true' "$out/report/maestro-runner.log"; then
      cp -R "$attempt" "$out/source-0"
      cp "$attempt/hierarchy.xml" "$out/hierarchy-0.xml"
      echo "$poll" > "$out/baseline-poll.txt"
      date +%s.%N > "$out/baseline-accepted-epoch.txt"
      cp "$out/report/maestro-runner.log" "$out/baseline-runner-log.txt"
      ! rg -q 'scroll down: dragged .*measured=true' "$out/baseline-runner-log.txt" || exit 79
      baseline=1
      break
    fi
    sleep .1
  done
  (( baseline == 1 )) || exit 75
  # The runner log writes this measured-content line only after a bare scroll
  # and its settle/top-up work complete. It is live, unlike buffered CLI stdout.
  for step in 1 2 3 4; do
    seen=0
    for poll in {1..300}; do
      seen=$(rg -c 'scroll down: dragged .*content moved .*measured=true' "$out/report/maestro-runner.log" 2>/dev/null || true)
      (( seen >= step )) && break
      sleep 0.1
    done
    (( seen >= step )) || exit 76
    python3 -I "$root/uia2-source-snapshot-v2.py" "$serial" "$out/report/client.log" "$out/source-$step"
    cp "$out/source-$step/hierarchy.xml" "$out/hierarchy-$step.xml"
  done
  # Let the last deliberate wait and the flow finish. Stop only after the
  # terminal report says passed, so the fourth hierarchy isn't bought with an
  # interrupted/130 flow.
  terminal=0
  for poll in {1..300}; do
    if [[ -f $out/report/report.json ]] && jq -e '.status == "passed"' "$out/report/report.json" >/dev/null 2>&1; then
      terminal=1; break
    fi
    sleep 0.1
  done
  (( terminal == 1 )) || exit 77
  "$grantiva" runner dump-hierarchy --udid "$serial" --format xml > "$out/cli-final.xml" 2> "$out/cli-final.err"
  adb -s "$serial" shell wm density > "$out/wm-density.txt" 2> "$out/wm-density.err"
  density=$(sed -nE 's/^(Override|Physical) density: ([0-9]+)$/\2/p' "$out/wm-density.txt" | tail -1)
  [[ $density == <-> ]] || exit 80
  python3 -I "$root/compare-uia2-cli-app-semantics.py" "$out/hierarchy-4.xml" "$out/cli-final.xml" --package com.kylebrowning.landmarks --density-dpi "$density" --output "$out/semantic-comparison.json"
  "$grantiva" runner stop --json > "$out/stop.json" 2> "$out/stop.err"
  wait "$run_job"; run_job=''
  kill "$logcat_pid" 2>/dev/null || true
  wait "$logcat_pid" 2>/dev/null || true
  logcat_pid=''
done
trap - EXIT

python3 - "$root" <<'PY'
import hashlib,json,pathlib,re,statistics,sys,xml.etree.ElementTree as ET
r=pathlib.Path(sys.argv[1])
contract=['Golden Gate Bridge','Lake Tahoe','Half Dome','Yosemite Valley','Bixby Creek Bridge','Mono Lake','Mount Shasta','Crater Lake','Brooklyn Bridge','Mount \"Denali\"']
index_by_title={title:i+1 for i,title in enumerate(contract)}
index_by_title.update({f'Landmark {i}':i for i in range(11,71)})
bounds_re=re.compile(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
def indexed_rows(path):
 root=ET.parse(path).getroot(); found={}
 for e in root.iter():
  title=e.attrib.get('text',''); idx=index_by_title.get(title); m=bounds_re.fullmatch(e.attrib.get('bounds',''))
  if idx is not None and m:
   y=int(m.group(2)); found[idx]=max(y,found.get(idx,-10**9)) # list copy is below Featured copy
 assert found, {'missing':'indexed app rows','path':str(path)}
 return found
def intercept(rows,row_height=189): return statistics.median(y-index*row_height for index,y in rows.items())
summary={}
for renderer in ('software','gpu'):
 d=r/renderer
 client=(d/'report/client.log').read_text(errors='replace')
 assert 'launch_app' in client and '"LANDMARKS_SEED":"many"' in client, {'renderer':renderer,'missing':'seed launch request'}
 logcat=(d/'logcat.txt').read_text(errors='replace')
 assert 'extras=[LANDMARKS_SEED=many]' in logcat, {'renderer':renderer,'missing':'app-observed seed launch extra'}
 maps=[]
 for n in range(5): maps.append(indexed_rows(d/f'hierarchy-{n}.xml'))
 steps=[]
 for n in range(1,5):
  common=sorted(maps[n-1].keys() & maps[n].keys()); delta=[maps[n][k]-maps[n-1][k] for k in common]
  before_intercept=intercept(maps[n-1]); after_intercept=intercept(maps[n])
  measured=statistics.median(delta) if delta else after_intercept-before_intercept
  steps.append({'step':n,'common':common,'measurementMethod':'commonRows' if delta else 'indexedRowIntercept',
                'medianPixelDelta':measured,'beforeIntercept':before_intercept,'afterIntercept':after_intercept,
                'beforeRange':[min(maps[n-1]),max(maps[n-1])],'afterRange':[min(maps[n]),max(maps[n])]})
 assert all(x['medianPixelDelta'] not in (None,0) for x in steps), steps
 comparison=json.loads((d/'semantic-comparison.json').read_text())
 assert comparison['passed'] and comparison['matchedCount'] > 0, comparison
 summary[renderer]={'steps':steps,'finalCLIMatchesLastDirectSemantics':True,'semanticNodeCount':comparison['matchedCount'],
                    'densityDpi':comparison['densityDpi'],'pixelsPerDp':comparison['pixelsPerDp'],
                    'toleranceDp':comparison['toleranceDp'],
                    'semanticFramesSHA256':hashlib.sha256(json.dumps(comparison['matches'],separators=(',',':')).encode()).hexdigest()}
(r/'decoded.json').write_text(json.dumps(summary,indent=2)+'\n')
PY
find "$root" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$root/all-files.sha256"
