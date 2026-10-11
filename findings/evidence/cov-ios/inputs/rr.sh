# rr <ROW> <label> <command string>   -- runs in $PWD via bash -c, saves out/err, appends commands.txt
rr() {
  local row=$1 label=$2; shift 2; local cmd="$*"
  local d=$E/$row; mkdir -p "$d"
  local t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  bash -c "$cmd" > "$d/$label.out" 2> "$d/$label.err"; local rc=$?
  local t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  local el=$(echo "$t1 - $t0" | bc)
  { echo "# cwd: $PWD  (U1=$U1 cov-ios-1 26.0; U2=$U2 cov-ios-2 27.0)"; echo "\$ $cmd"; echo "# exit=$rc elapsed=${el}s -> $label.out / $label.err"; } >> "$d/commands.txt"
  echo "[$row/$label] exit=$rc ${el}s"; return 0
}
note() { local row=$1; shift; mkdir -p $E/$row; echo "# $*" >> $E/$row/commands.txt; }
res() { # res ID result evidence note
  echo "| $1 | $2 | $3 | $4 |" >> $W/findings/cov-ios-results.md; }
# ka <ROW> <label> <udid> <flow> [extra args] : start keep-alive run in background, wait for ready file; sets KAPID
ka() {
  local row=$1 label=$2 udid=$3 flow=$4; shift 4
  local d=$E/$row; mkdir -p $d; rm -f $S/$label.ready
  echo "# cwd: $PWD"; 
  { echo "# cwd: $PWD (background)"; echo "\$ \$GRANTIVA run --no-build --simulator $udid --flow $flow --keep-alive --ready-file \$S/$label.ready $* > $label.out 2> $label.err &"; } >> $d/commands.txt
  $GRANTIVA run --no-build --simulator $udid --flow $flow --keep-alive --ready-file $S/$label.ready "$@" > $d/$label.out 2> $d/$label.err &
  KAPID=$!
  local n=0; until [ -f $S/$label.ready ] || ! kill -0 $KAPID 2>/dev/null || [ $n -ge 300 ]; do sleep 1; n=$((n+1)); done
  echo "# ready after ${n}s pid=$KAPID: $(cat $S/$label.ready 2>/dev/null)" >> $d/commands.txt
  echo "ka pid=$KAPID ready=$(cat $S/$label.ready 2>/dev/null)"
}
procs() { ps -axo pid,ppid,command | grep -E "$1" | grep -v grep; }
# mcp <ROW> <label> <requests.json> <projdir> [extra grantiva mcp args]  -- runs client.py; outputs under $E/ROW/label/
mcp() {
  local row=$1 label=$2 req=$3 proj=$4; shift 4
  local d=$E/$row/$label; mkdir -p $d; cp $req $d/requests.json
  local t0=$(date +%s)
  python3 -I $S/mcp/client.py $req $d $proj -- $GRANTIVA mcp --project-dir $proj "$@"
  { echo "# cwd: $proj"; echo "\$ python3 -I \$S/mcp/client.py $label/requests.json $label/ $proj -- \$GRANTIVA mcp --project-dir $proj $*"; echo "# elapsed=$(( $(date +%s)-t0 ))s -> $label/transcript.txt, stdout.raw, server.stderr"; } >> $E/$row/commands.txt
  echo "[$row/$label] done"
}
INIT='{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"cov","version":"1"}}},{"jsonrpc":"2.0","method":"notifications/initialized"}'
mkreq() { echo "[$INIT,$1]" > $2; }
