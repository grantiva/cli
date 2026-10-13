#!/bin/zsh
# Parent-executed B3-L51 evidence harness. This uses one already-owned Android
# emulator; it does not create, boot, shut down, or delete any device.
set -euo pipefail

if (( $# != 4 )); then
  echo "usage: $0 OUTPUT_ROOT PROJECT_SOURCE OWNED_SERIAL GRANTIVA_BINARY" >&2
  exit 64
fi
root=$1
source_project=$2
serial=$3
grantiva=$4
script_dir=${0:A:h}; source_reader=$script_dir/uia2-source-snapshot-v2.py; semantic_compare=$script_dir/compare-uia2-cli-app-semantics.py
[[ ! -e $root && -d $source_project && -x $grantiva && $serial == emulator-* ]] || exit 73

mkdir -p "$root/project/.maestro/coverage"
rsync -a --exclude .gradle --exclude build --exclude .grantiva "$source_project/" "$root/project/"
cp "$0" "$root/harness.sh"
cp "$source_reader" "$root/uia2-source-snapshot-v2.py"
cp "$semantic_compare" "$root/compare-uia2-cli-app-semantics.py"
project=$root/project
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-android
unset GRANTIVA_API_KEY

cat > "$root/project/.maestro/coverage/l51-direction.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15000
- swipe:
    direction: UP
- wait: 10000
YAML
cat > "$root/project/.maestro/coverage/l51-coordinates.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15000
- swipe:
    start: "50%,70%"
    end: "50%,30%"
- wait: 10000
YAML
cat > "$root/project/.maestro/coverage/l51-element.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15000
- swipe:
    direction: UP
    from:
      text: "All Landmarks"
- wait: 10000
YAML
cat > "$root/project/.maestro/coverage/l51-engine-adb.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15000
- scroll:
    direction: DOWN
    engine: adb
- wait: 10000
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

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "candidate_sha256=$(shasum -a 256 "$grantiva" | awk '{print $1}')"
  echo "serial=$serial"
  echo "project_source=$source_project"
} > "$root/provenance.txt"

cd "$project"
for form in direction coordinates element engine-adb; do
  out=$root/$form
  mkdir -p "$out"
  adb -s "$serial" shell pm clear com.kylebrowning.landmarks > "$out/pm-clear.out" 2> "$out/pm-clear.err"
  adb -s "$serial" logcat -c
  adb -s "$serial" logcat -v epoch > "$out/logcat.txt" 2> "$out/logcat.err" &
  logcat_pid=$!

  # The subshell remains the command's parent and reaps it concurrently with
  # `runner stop`; this avoids stop mistaking an exited-but-unreaped child for
  # a live runner and waiting its zombie timeout.
  (
    set +e
    "$grantiva" run --platform android --device "$serial" --no-build --keep-alive --verbose \
      --flow ".maestro/coverage/l51-$form.yaml" --report-dir "$out/report" \
      > "$out/stdout.txt" 2> "$out/stderr.txt"
    task_rc=$?
    echo "$task_rc" > "$out/exit.txt"
    exit "$task_rc"
  ) &
  run_job=$!
  echo "$run_job" > "$out/run-job.pid"

  launch_done=0
  for poll in {1..300}; do
    if rg -q 'Step 0 completed successfully.*launchApp' "$out/report/maestro-runner.log" 2>/dev/null; then launch_done=1; break; fi
    sleep .1
  done
  (( launch_done == 1 )) || exit 75
  # launchApp completion can precede the first fully drawn app frame. Preserve
  # each read and accept the first hierarchy that contains seeded landmarks.
  baseline=0
  for poll in {1..100}; do
    attempt="$out/source-before-attempt-$poll"
    python3 -I "$root/uia2-source-snapshot-v2.py" "$serial" "$out/report/client.log" "$attempt"
    if rg -q 'Golden Gate Bridge' "$attempt/hierarchy.xml" && rg -q 'All Landmarks' "$attempt/hierarchy.xml" && ! rg -q 'Step 1 completed successfully' "$out/report/maestro-runner.log"; then
      cp -R "$attempt" "$out/source-before"
      cp "$attempt/hierarchy.xml" "$out/hierarchy-before.xml"
      echo "$poll" > "$out/baseline-poll.txt"
      date +%s.%N > "$out/baseline-accepted-epoch.txt"
      cp "$out/report/maestro-runner.log" "$out/baseline-runner-log.txt"
      ! rg -q 'Step 1 completed successfully' "$out/baseline-runner-log.txt" || exit 80
      baseline=1
      break
    fi
    sleep .1
  done
  (( baseline == 1 )) || exit 79

  # Wait for the runner's live completion record, then sample until three
  # consecutive UIA2 source documents are byte-identical. Their timestamps
  # measure settle time without guessing from sleeps.
  completed=0
  for poll in {1..300}; do
    if rg -q 'Step 2 completed successfully' "$out/report/maestro-runner.log" 2>/dev/null; then completed=1; break; fi
    sleep .1
  done
  (( completed == 1 )) || exit 76
  python3 -c 'import time; print(time.time_ns())' > "$out/settle-start-ns.txt"
  stable=0; previous=''; settled=0
  for poll in {1..20}; do
    python3 -I "$root/uia2-source-snapshot-v2.py" "$serial" "$out/report/client.log" "$out/source-after-$poll"
    current=$(shasum -a 256 "$out/source-after-$poll/hierarchy.xml" | awk '{print $1}')
    [[ $current == $previous ]] && (( stable += 1 )) || stable=0
    previous=$current
    if (( stable >= 2 )); then cp "$out/source-after-$poll/hierarchy.xml" "$out/hierarchy-after.xml"; settled=$poll; break; fi
    sleep .1
  done
  echo "$settled" > "$out/settled-poll.txt"; (( settled > 0 )) || exit 77
  terminal=0
  for poll in {1..300}; do
    if [[ -f $out/report/report.json ]] && jq -e '.status == "passed"' "$out/report/report.json" >/dev/null 2>&1; then terminal=1; break; fi
    sleep .1
  done
  (( terminal == 1 )) || exit 78
  "$grantiva" runner dump-hierarchy --udid "$serial" --format xml > "$out/cli-final.xml" 2> "$out/cli-final.err"
  adb -s "$serial" shell wm density > "$out/wm-density.txt" 2> "$out/wm-density.err"
  density=$(sed -nE 's/^(Override|Physical) density: ([0-9]+)$/\2/p' "$out/wm-density.txt" | tail -1)
  [[ $density == <-> ]] || exit 81
  python3 -I "$root/compare-uia2-cli-app-semantics.py" "$out/hierarchy-after.xml" "$out/cli-final.xml" --package com.kylebrowning.landmarks --density-dpi "$density" --output "$out/semantic-comparison.json"
  "$grantiva" runner stop --json > "$out/stop.json" 2> "$out/stop.err"
  wait "$run_job"
  run_job=''
  kill "$logcat_pid" 2>/dev/null || true
  wait "$logcat_pid" 2>/dev/null || true
  logcat_pid=''
done
trap - EXIT

python3 - "$root" <<'PY'
import hashlib, json, pathlib, re, statistics, sys, xml.etree.ElementTree as ET
root = pathlib.Path(sys.argv[1])
rows = []
contract=['Golden Gate Bridge','Lake Tahoe','Half Dome','Yosemite Valley','Bixby Creek Bridge','Mono Lake','Mount Shasta','Crater Lake','Brooklyn Bridge','Mount \"Denali\"']
index_by_title={title:i+1 for i,title in enumerate(contract)}
index_by_title.update({f'Landmark {i}':i for i in range(11,71)})
bounds_re=re.compile(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
def positions(path):
    found={}
    for e in ET.parse(path).getroot().iter():
        idx=index_by_title.get(e.attrib.get('text','')); m=bounds_re.fullmatch(e.attrib.get('bounds',''))
        if idx is not None and m: found[idx]=max(int(m.group(2)),found.get(idx,-10**9))
    assert found, {'missing':'indexed app rows','path':str(path)}
    return found
def intercept(rows,row_height=189): return statistics.median(y-index*row_height for index,y in rows.items())
for form in ('direction','coordinates','element','engine-adb'):
    d = root/form
    before, after = positions(d/'hierarchy-before.xml'), positions(d/'hierarchy-after.xml')
    common = sorted(before.keys() & after.keys())
    deltas = [after[n]-before[n] for n in common]
    maestro = (d/'report/maestro-runner.log').read_text(errors='replace')
    client = (d/'report/client.log').read_text(errors='replace')
    assert 'launch_app' in client and '"LANDMARKS_SEED":"many"' in client, {'form':form,'missing':'seed launch request'}
    logcat = (d/'logcat.txt').read_text(errors='replace')
    assert 'extras=[LANDMARKS_SEED=many]' in logcat, {'form':form,'missing':'app-observed seed launch extra'}
    comparison=json.loads((d/'semantic-comparison.json').read_text())
    assert comparison['passed'] and comparison['matchedCount'] > 0, comparison
    semantic_digest = hashlib.sha256(json.dumps(comparison['matches'],separators=(',',':')).encode()).hexdigest()
    rows.append({
        'form': form,
        'commonLandmarks': common,
        'measurementMethod': 'commonRows' if deltas else 'indexedRowIntercept',
        'medianRowPixelDelta': statistics.median(deltas) if deltas else intercept(after)-intercept(before),
        'beforeRange': [min(before),max(before)] if before else None,
        'afterRange': [min(after),max(after)] if after else None,
        'finalCLIMatchesSettledDirectSemantics': True,
        'semanticNodeCount': comparison['matchedCount'],
        'densityDpi': comparison['densityDpi'],
        'toleranceDp': comparison['toleranceDp'],
        'semanticFramesSHA256': semantic_digest,
        'sourceBeforeElapsedMs': json.loads((d/'source-before/metadata.json').read_text())['sourceRequest']['elapsedMs'],
        'settledPoll': int((d/'settled-poll.txt').read_text()),
        'settleElapsedMs': (
            json.loads((d/f"source-after-{int((d/'settled-poll.txt').read_text())}/metadata.json").read_text())['sourceRequest']['endedNs']
            - int((d/'settle-start-ns.txt').read_text())
        ) / 1_000_000,
        'runnerMentionsInputSwipe': 'input swipe' in maestro,
        'clientActionsRequests': client.count('POST /session/') and client.count('/actions'),
        'logcatMentionsInputSwipe': 'input swipe' in logcat,
    })
assert all(r['medianRowPixelDelta'] not in (None, 0) for r in rows), rows
(root/'decoded.json').write_text(json.dumps({'rows':rows},indent=2)+'\n')
PY

echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$root/provenance.txt"
find "$root" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$root/all-files.sha256"
