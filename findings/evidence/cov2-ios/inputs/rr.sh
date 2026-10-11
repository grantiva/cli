# rr <ROW> <label> <command string>   -- runs in $PWD via bash -c, saves out/err, appends commands.txt (with uptime)
rr() {
  local row=$1 label=$2; shift 2; local cmd="$*"
  local d=$E/$row; mkdir -p "$d"
  echo "# uptime: $(uptime)" >> "$d/commands.txt"
  local t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  bash -c "$cmd" > "$d/$label.out" 2> "$d/$label.err"; local rc=$?
  local t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  local el=$(echo "$t1 - $t0" | bc)
  { echo "# cwd: $PWD  (U1=$U1 cov2-ios-1 26.0; U2=$U2 cov2-ios-2 27.0)"; echo "\$ $cmd"; echo "# exit=$rc elapsed=${el}s -> $label.out / $label.err"; } >> "$d/commands.txt"
  echo "[$row/$label] exit=$rc ${el}s"; return 0
}
note() { local row=$1; shift; mkdir -p $E/$row; echo "# $*" >> $E/$row/commands.txt; }
res() { printf "| %s | %s | %s | %s |\n" "$1" "$2" "$3" "$4" >> $S/res.lines; }
# ka <ROW> <label> <udid> <flow> [extra args]: background keep-alive run; waits for ready file; sets KAPID
ka() {
  local row=$1 label=$2 udid=$3 flow=$4; shift 4
  local d=$E/$row; mkdir -p $d; rm -f $S/$label.ready
  { echo "# uptime: $(uptime)"; echo "# cwd: $PWD (background)"; echo "\$ \$GRANTIVA run --no-build --simulator $udid --flow $flow --keep-alive --ready-file \$S/$label.ready $* > $label.out 2> $label.err &"; } >> $d/commands.txt
  $GRANTIVA run --no-build --simulator $udid --flow $flow --keep-alive --ready-file $S/$label.ready "$@" > $d/$label.out 2> $d/$label.err &
  KAPID=$!
  local n=0; until [ -f $S/$label.ready ] || ! kill -0 $KAPID 2>/dev/null || [ $n -ge 300 ]; do sleep 1; n=$((n+1)); done
  echo "# ready after ${n}s pid=$KAPID: $(cat $S/$label.ready 2>/dev/null)" >> $d/commands.txt
  echo "ka pid=$KAPID ready=$(cat $S/$label.ready 2>/dev/null)"
}
kastop() { # kastop <ROW> : SIGINT the keep-alive run started by ka and wait
  kill -INT $KAPID 2>/dev/null; local n=0; while kill -0 $KAPID 2>/dev/null && [ $n -lt 60 ]; do sleep 1; n=$((n+1)); done
  wait $KAPID 2>/dev/null; local rc=$?; echo "# kill -INT $KAPID; exited rc=$rc after ${n}s" >> $E/$1/commands.txt; echo "stopped rc=$rc"
}
procs() { ps -axo pid,ppid,command | grep -E "$1" | grep -v grep; }
mcp() {
  local row=$1 label=$2 req=$3 proj=$4; shift 4
  local d=$E/$row/$label; mkdir -p $d; cp $req $d/requests.json
  echo "# uptime: $(uptime)" >> $E/$row/commands.txt
  local t0=$(date +%s)
  python3 -I $S/mcp/client.py $req $d $proj -- $GRANTIVA mcp --project-dir $proj "$@"
  { echo "# cwd: $proj"; echo "\$ python3 -I \$S/mcp/client.py $label/requests.json $label/ $proj -- \$GRANTIVA mcp --project-dir $proj $*"; echo "# elapsed=$(( $(date +%s)-t0 ))s -> $label/transcript.txt, stdout.raw, server.stderr"; } >> $E/$row/commands.txt
  echo "[$row/$label] done"
}
INIT='{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"cov2","version":"1"}}},{"jsonrpc":"2.0","method":"notifications/initialized"}'
mkreq() { echo "[$INIT,$1]" > $2; }
