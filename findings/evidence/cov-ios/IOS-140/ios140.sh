grantiva() { $GRANTIVA "$@"; }
grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator $U1 --detach
echo "start exit=$?"
sleep 12
grantiva runner dump-hierarchy --format json | head -c 200; echo; echo "dump exit=${PIPESTATUS[0]}"
grantiva runner stop
echo "stop exit=$?"
