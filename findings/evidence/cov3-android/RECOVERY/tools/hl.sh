#!/bin/bash
# hl.sh <label> <env assignments...>: boot cov3-android-2 with the given env (stdout captured), print the emulator args, tear it down
label=$1; shift
t0=$(date +%s); serial=$(env "$@" $GRANTIVA emulator ensure --name cov3-android-2 2>$S/hl.err); rc=$?
pid=$(python3 -I -c "import json,os;print([r['pid'] for r in json.load(open(os.path.expanduser('~/.grantiva/android/started.json'))) if r['serial']=='$serial'][0])" 2>/dev/null)
args=$(ps -o args= -p "$pid" 2>/dev/null)
echo "$label: rc=$rc serial=$serial boot=$(( $(date +%s)-t0 ))s pid=$pid no-window=$(echo "$args" | grep -c -- '-no-window') headless-binary=$(echo "$args" | grep -c headless)"
echo "  args: $args"; cat $S/hl.err | sed 's/^/  stderr: /'; rm -f $S/hl.err
[ -n "$serial" ] && $GRANTIVA emulator teardown --serial $serial >/dev/null 2>&1; sleep 3
