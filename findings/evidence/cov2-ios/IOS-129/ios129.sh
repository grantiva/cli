grantiva() { $GRANTIVA "$@"; }
grantiva run --flow .maestro/01-browse.yaml --keep-alive --logs > $E/IOS-129/ka129.out 2> $E/IOS-129/ka129.err &
P=$!
until grep -q "Press Ctrl-C to release" $E/IOS-129/ka129.out $E/IOS-129/ka129.err 2>/dev/null || ! kill -0 $P 2>/dev/null; do sleep 1; done
grantiva hierarchy > state.xml
echo "hierarchy exit=$? bytes=$(wc -c < state.xml)"; head -c 150 state.xml; echo
grantiva hierarchy > state2.xml; echo "dump-hierarchy.md:16 exit=$? bytes=$(wc -c < state2.xml)"
grantiva hierarchy --format json > state.json; echo "dump-hierarchy.md:18 exit=$? bytes=$(wc -c < state.json)"
python3 -I -c "import json,sys; json.load(open(sys.argv[1])); print('json ok')" state.json
cp state.xml state2.xml state.json $E/IOS-131/; rm -f state.xml state2.xml state.json
kill -INT $P; wait $P; echo "run exit=$?"
