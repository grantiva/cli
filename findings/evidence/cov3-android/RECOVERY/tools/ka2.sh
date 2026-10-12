#!/bin/bash
# ka2.sh <outprefix> <serial> <flow>: start run --keep-alive on a serial in background, wait for ready, print pid
out=$1; ser=$2; flow=$3; rm -f $out.ready
nohup $GRANTIVA run --device $ser --no-build --flow $flow --keep-alive --ready-file $out.ready > $out.out 2> $out.err &
echo $! > $out.pid
for i in $(seq 1 180); do [ -f $out.ready ] && break; sleep 1; done
echo "keep-alive on $ser pid $(cat $out.pid): $(python3 -I -c "import json;print(json.load(open('$out.ready'))['status'])" 2>/dev/null)"
