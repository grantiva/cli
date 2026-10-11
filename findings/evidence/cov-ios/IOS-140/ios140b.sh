grantiva() { $GRANTIVA "$@"; }
grantiva runner start --bundle-id com.kylebrowning.Landmarks
echo "start exit=$?"
grantiva runner dump-hierarchy --format json | head -c 120; echo; echo "dump exit=${PIPESTATUS[0]}"
grantiva runner stop
echo "stop exit=$?"
