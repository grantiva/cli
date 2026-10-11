#!/bin/bash
# usage: reap-cycle.sh <udid> <cycle> ; run from ios/
U=$1; i=$2
echo "## cycle $i"; echo '$ uptime'; uptime
echo "\$ \$GRANTIVA runner start --detach --json --simulator $U --bundle-id com.kylebrowning.Landmarks"
"$GRANTIVA" runner start --detach --json --simulator "$U" --bundle-id com.kylebrowning.Landmarks; echo "exit=$?"
echo '$ $GRANTIVA runner stop --json'
"$GRANTIVA" runner stop --json; echo "exit=$?"
echo "\$ ps -Ao pid,ppid,etime,args | grep $U | grep -v grep   (+0 s)"
ps -Ao pid,ppid,etime,args | grep "$U" | grep -v grep | cut -c1-300
sleep 60
echo "\$ ps -Ao pid,ppid,etime,args | grep $U | grep -v grep   (+60 s)"
ps -Ao pid,ppid,etime,args | grep "$U" | grep -v grep | cut -c1-300
echo '$ ls -la /tmp/grantiva-sessions'; ls -la /tmp/grantiva-sessions
