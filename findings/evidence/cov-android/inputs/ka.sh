#!/bin/bash
# ka.sh <outprefix> <flow>: start run --keep-alive in background, wait for ready, print pid
out=$1; flow=$2; rm -f $out.ready
nohup $GRANTIVA run --device emulator-5554 --no-build --flow $flow --keep-alive --ready-file $out.ready > $out.out 2> $out.err &
echo $! > $out.pid
for i in $(seq 1 120); do [ -f $out.ready ] && break; sleep 1; done
echo "keep-alive pid $(cat $out.pid): $(python3 -c "import json;print(json.load(open('$out.ready'))['status'])")"
