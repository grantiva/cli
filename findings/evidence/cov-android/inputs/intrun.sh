#!/bin/bash
# intrun.sh <outprefix> <seconds> <grantiva run args...>: start run in background, SIGINT after N s, wait, print exit
out=$1; t=$2; shift 2
$GRANTIVA run "$@" > $out.out 2> $out.err & pid=$!
sleep $t; kill -INT $pid; wait $pid; echo "exit $?"
