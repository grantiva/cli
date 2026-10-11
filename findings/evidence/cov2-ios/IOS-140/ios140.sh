# docs/dump-hierarchy.md:46-48 as written (bundle ID substituted; simulator from grantiva.yml). Line 46 holds in the
# foreground until stopped, so it runs as "terminal 1" (background job); :47 and :48 run as "terminal 2".
$GRANTIVA runner start --bundle-id com.kylebrowning.Landmarks > $E/IOS-140/start.out 2> $E/IOS-140/start.err &
P=$!
n=0; until [ -f .grantiva/session.json ] || [ $n -ge 120 ]; do sleep 1; n=$((n+1)); done; sleep 3
echo "session.json after ${n}s; start alive=$(kill -0 $P 2>/dev/null && echo yes || echo no)"
$GRANTIVA runner dump-hierarchy --format json | head -c 200; echo; echo "dump exit=${PIPESTATUS[0]}"
$GRANTIVA runner stop; echo "stop exit=$?"
wait $P; echo "start exit=$?"
