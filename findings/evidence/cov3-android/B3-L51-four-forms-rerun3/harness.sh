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
[[ ! -e $root && -d $source_project && -x $grantiva && $serial == emulator-* ]] || exit 73

mkdir -p "$root/project/.maestro/coverage"
rsync -a --exclude .gradle --exclude build --exclude .grantiva "$source_project/" "$root/project/"
cp "$0" "$root/harness.sh"
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
- wait: 15
- swipe:
    direction: UP
- wait: 1
YAML
cat > "$root/project/.maestro/coverage/l51-coordinates.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15
- swipe:
    start: "50%,70%"
    end: "50%,30%"
- wait: 1
YAML
cat > "$root/project/.maestro/coverage/l51-element.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15
- swipe:
    direction: UP
    from:
      text: "Landmark 5"
- wait: 1
YAML
cat > "$root/project/.maestro/coverage/l51-engine-adb.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp:
    clearState: true
- wait: 15
- scroll:
    direction: DOWN
    engine: adb
- wait: 1
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
  mkdir -p "$out/hierarchy-after-polls"
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

  before_ok=0
  for poll in {1..40}; do
    if "$grantiva" runner dump-hierarchy --udid "$serial" --format xml \
        > "$out/hierarchy-before.xml" 2> "$out/hierarchy-before.err" \
        && rg -q 'Landmark [0-9]+' "$out/hierarchy-before.xml"; then
      before_ok=1
      break
    fi
    sleep 0.2
  done
  (( before_ok == 1 )) || exit 75

  # The flow's 15-second wait makes the pre-gesture hierarchy unambiguous.
  # Poll after it for a stable post-gesture hierarchy and retain every sample.
  sleep 15
  python3 -c 'import time; print(time.time_ns())' > "$out/settle-poll-start-ns.txt"
  previous_hash=''
  stable=0
  settled_poll=0
  for poll in {1..40}; do
    sample="$out/hierarchy-after-polls/$poll.xml"
    python3 -c 'import time; print(time.time_ns())' > "$out/hierarchy-after-polls/$poll-start-ns.txt"
    if "$grantiva" runner dump-hierarchy --udid "$serial" --format xml \
        > "$sample" 2> "$out/hierarchy-after-polls/$poll.err"; then
      python3 -c 'import time; print(time.time_ns())' > "$out/hierarchy-after-polls/$poll-end-ns.txt"
      current_hash=$(shasum -a 256 "$sample" | awk '{print $1}')
      if [[ $current_hash == $previous_hash ]]; then
        (( stable += 1 ))
      else
        stable=0
      fi
      previous_hash=$current_hash
      if (( stable >= 2 )); then
        cp "$sample" "$out/hierarchy-after.xml"
        settled_poll=$poll
        break
      fi
    fi
    sleep 0.1
  done
  echo "$settled_poll" > "$out/settled-poll.txt"
  (( settled_poll > 0 )) || exit 76

  "$grantiva" runner stop --json > "$out/stop.json" 2> "$out/stop.err"
  wait "$run_job"
  run_job=''
  kill "$logcat_pid" 2>/dev/null || true
  wait "$logcat_pid" 2>/dev/null || true
  logcat_pid=''
done
trap - EXIT

python3 - "$root" <<'PY'
import json, pathlib, re, statistics, sys
root = pathlib.Path(sys.argv[1])
rows = []
pat = re.compile(r'text="Landmark (\d+)"[^>]*bounds="\[[^,]+,(-?\d+)\]')
for form in ('direction','coordinates','element','engine-adb'):
    d = root/form
    def positions(name):
        return {int(n): int(y) for n,y in pat.findall((d/name).read_text())}
    before, after = positions('hierarchy-before.xml'), positions('hierarchy-after.xml')
    common = sorted(before.keys() & after.keys())
    deltas = [after[n]-before[n] for n in common]
    maestro = (d/'report/maestro-runner.log').read_text(errors='replace')
    client = (d/'report/client.log').read_text(errors='replace')
    logcat = (d/'logcat.txt').read_text(errors='replace')
    rows.append({
        'form': form,
        'commonLandmarks': common,
        'medianRowPixelDelta': statistics.median(deltas) if deltas else None,
        'beforeRange': [min(before),max(before)] if before else None,
        'afterRange': [min(after),max(after)] if after else None,
        'settledPoll': int((d/'settled-poll.txt').read_text()),
        'settlePollElapsedMs': (
            int((d/'hierarchy-after-polls'/f"{int((d/'settled-poll.txt').read_text())}-end-ns.txt").read_text())
            - int((d/'settle-poll-start-ns.txt').read_text())
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
