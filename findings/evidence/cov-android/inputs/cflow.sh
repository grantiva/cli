#!/bin/bash
# cflow.sh <flow-name> [extra run args]: run a coverage flow with --report-dir $S/out-cf-<name>; print step lines + verdict
f=$1; shift; rm -rf $S/out-cf-$f
$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/$f.yaml --report-dir $S/out-cf-$f "$@" > $S/out-cf-$f.stdout 2> $S/out-cf-$f.stderr; rc=$?
awk '/^  \[1\/1\] .* \(.*\.yaml\)$/{p=1} p&&/^[✓✗] /{print; exit} p' $S/out-cf-$f.stderr
grep -E '^Error|^Warning' $S/out-cf-$f.stderr; echo "exit $rc"
