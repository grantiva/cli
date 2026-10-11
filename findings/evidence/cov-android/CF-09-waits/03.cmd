for i in 1 2 3; do $S/tools/cflow.sh 09-waits | grep -E "extendedWait|exit"; done
