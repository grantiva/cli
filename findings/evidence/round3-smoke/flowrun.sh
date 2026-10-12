#!/bin/zsh
# flowrun.sh <plat ios|android> <flow> <evdir> <name> [extra args...]
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
plat=$1 flow=$2 ev=$3 name=$4; shift 4
rd=$S/reports/$name; rm -rf $rd
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); else cd $S/demo/ios; tgt=(--simulator $UDID); fi
rec $ev/$name.txt $GRANTIVA run $tgt --no-build --flow $flow --report-dir $rd "$@"
rc=$?
mkdir -p $ev; for f in $(find $rd -name 'maestro-runner.log' -o -name 'client.log' -o -name 'flow-000.json' 2>/dev/null); do b=$(basename $f); cp $f $ev/$name-$b; done
exit $rc
