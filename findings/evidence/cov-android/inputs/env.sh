export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA=$HOME/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=$HOME/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov-android; unset GRANTIVA_API_KEY
export S=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov-android
export W=/Users/kyle/Developer/grantiva-cli/.worktrees/cov-android
export E=$W/findings/evidence/cov-android
export P=$S/android
# rec ROW 'shell command'  -> runs in $PWD via bash -c, saves NN.out/NN.err, appends commands.txt
rec() { local id=$1; shift; local d=$E/$id; mkdir -p "$d"; local n=$(printf %02d $(( $(ls "$d" | grep -c '\.cmd$') + 1 ))); 
  echo "$*" > "$d/$n.cmd"; local t0=$(date +%s.%N 2>/dev/null || python3 -c 'import time;print(time.time())'); t0=$(python3 -c 'import time;print(time.time())')
  bash -c "$*" > "$d/$n.out" 2> "$d/$n.err"; local rc=$?; local t1=$(python3 -c 'import time;print(time.time())')
  local dt=$(python3 -c "print(round($t1-$t0,1))")
  printf '# [%s] cwd=%s\n$ %s\nrc=%s elapsed=%ss  (stdout %s.out, stderr %s.err)\n\n' "$n" "$PWD" "$*" "$rc" "$dt" "$n" "$n" >> "$d/commands.txt"
  echo "== $id/$n rc=$rc ${dt}s"; echo "-- stdout:"; tail -c ${TAILN:-2500} "$d/$n.out"; echo "-- stderr:"; tail -c ${TAILN:-2500} "$d/$n.err"; return 0; }
note() { local id=$1; shift; mkdir -p $E/$id; echo "# note: $*" >> $E/$id/commands.txt; }
res () {
	echo "| $1 | $2 | findings/evidence/cov-android/$1/ | $3 |" >> $W/findings/cov-android-results.md
}
ref() { mkdir -p $E/$1; echo "# shared evidence: see ../$2/ ($3)" >> $E/$1/commands.txt; }
export P2=$S/android2
export PB=$S/both
export PN=$S/noemu
# mcp ROW reqfile cwd [mcp args...]  -> transcript in $E/ROW/mcp-NN/
mcpc() { local id=$1 req=$2 cwd=$3; shift 3; local d=$E/$id; mkdir -p $d; local n=$(printf %02d $(( $(find $d -maxdepth 1 -name "mcp-*" | wc -l) + 1 ))); mkdir -p $d/mcp-$n; cp $req $d/mcp-$n/requests.json
  echo "\$ python3 client.py $req $d/mcp-$n $cwd -- $GRANTIVA mcp $*   # (client.py = scratch tools/client.py, copied from the regression iOS evidence)" >> $d/commands.txt
  python3 $S/tools/client.py $req $d/mcp-$n $cwd -- $GRANTIVA mcp "$@"; echo "== $id/mcp-$n"; cut -c1-${MCPCUT:-1500} $d/mcp-$n/transcript.txt; }
down() { adb -s emulator-5554 shell sync >/dev/null 2>&1; sleep 2; $GRANTIVA emulator teardown --serial emulator-5554; sleep 3; adb devices; }
export PNC=$S/nocfg
