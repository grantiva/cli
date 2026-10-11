#!/bin/bash
# cflow.sh <tag> <flow path> [extra run args]: run one flow on $SER with --report-dir $S/cf/<tag>; evidence in $E/CF-<tag>/
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
tag=$1; flow=$2; shift 2; d=$E/CF-$tag; mkdir -p $d; rm -rf $S/cf/$tag; mkdir -p $S/cf
cd $P; up=$(uptime | sed 's/.*load averages*: //'); t0=$(python3 -I -c 'import time;print(time.time())')
$GRANTIVA run --device ${SER:-emulator-5554} --no-build --flow $flow --report-dir $S/cf/$tag "$@" > $d/run.out 2> $d/run.err; rc=$?
dt=$(python3 -I -c "import time;print(round(time.time()-$t0,1))")
printf '# cwd=%s load=%s\n$ $GRANTIVA run --device %s --no-build --flow %s --report-dir $S/cf/%s %s\nrc=%s elapsed=%ss (run.out, run.err; report copies under report/)\n\n' "$PWD" "$up" "${SER:-emulator-5554}" "$flow" "$tag" "$*" "$rc" "$dt" >> $d/commands.txt
mkdir -p $d/report; cp $S/cf/$tag/report.json $S/cf/$tag/client.log $S/cf/$tag/maestro-runner.log $d/report/ 2>/dev/null; cp $S/cf/$tag/flows/*.json $d/report/ 2>/dev/null
echo "== CF-$tag rc=$rc ${dt}s"; awk '/ - Device:/{p=1} p' $d/run.err | grep -E '^\s+[✓✗⚠-] |^\s+╰' ; grep -E '^Error|^Warning' $d/run.err
