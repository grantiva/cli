grantiva() { $GRANTIVA "$@"; }
grantiva run --flow .maestro/01-browse.yaml --keep-alive --logs > $S/ka129.out 2> $S/ka129.err &
P=$!
until grep -q "Press Ctrl-C to release" $S/ka129.err 2>/dev/null; do sleep 1; done
grantiva hierarchy > state.xml
echo "hierarchy exit=$? bytes=$(wc -c < state.xml)"; head -c 150 state.xml; echo
grantiva hierarchy > state2.xml; echo "dump-hierarchy.md:16 exit=$?"
grantiva hierarchy --format json > state.json; echo "dump-hierarchy.md:18 exit=$? bytes=$(wc -c < state.json)"
kill -INT $P; wait $P; echo "run exit=$?"
