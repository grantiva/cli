export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA=$HOME/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=$HOME/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov2-android; unset GRANTIVA_API_KEY
export S=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android
export W=/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android
export E=$W/findings/evidence/cov2-android
export P=$S/android
export SER=$(cat $S/serial 2>/dev/null)
# rec ROW 'shell command' -> runs in $PWD via bash -c, saves NN.out/NN.err, appends commands.txt (cwd, command, rc, elapsed, uptime)
rec() { local id=$1; shift; local d=$E/$id; mkdir -p "$d"; local n=$(printf %02d $(( $(ls "$d" | grep -c '\.cmd$') + 1 )));
  echo "$*" > "$d/$n.cmd"; local up=$(uptime | sed 's/.*load averages*: //'); local t0=$(python3 -I -c 'import time;print(time.time())')
  bash -c "$*" > "$d/$n.out" 2> "$d/$n.err"; local rc=$?; local t1=$(python3 -I -c 'import time;print(time.time())')
  local dt=$(python3 -I -c "print(round($t1-$t0,1))")
  printf '# [%s] cwd=%s load=%s\n$ %s\nrc=%s elapsed=%ss  (stdout %s.out, stderr %s.err)\n\n' "$n" "$PWD" "$up" "$*" "$rc" "$dt" "$n" "$n" >> "$d/commands.txt"
  echo "== $id/$n rc=$rc ${dt}s"; echo "-- stdout:"; tail -c ${TAILN:-2000} "$d/$n.out"; echo "-- stderr:"; tail -c ${TAILN:-2000} "$d/$n.err"; return 0; }
note() { local id=$1; shift; mkdir -p $E/$id; echo "# note: $*" >> $E/$id/commands.txt; }
ref() { mkdir -p $E/$1; echo "# shared evidence: see ../$2/ ($3)" >> $E/$1/commands.txt; }
res() { echo "| $1 | $2 | findings/evidence/cov2-android/$1/ | $3 |" >> $S/results.rows; }
mcpc() { local id=$1 req=$2 cwd=$3; shift 3; local d=$E/$id; mkdir -p $d; local n=$(printf %02d $(( $(find $d -maxdepth 1 -name "mcp-*" | wc -l) + 1 ))); mkdir -p $d/mcp-$n; cp $req $d/mcp-$n/requests.json
  echo "# cwd=$cwd load=$(uptime | sed 's/.*load averages*: //')"$'\n'"\$ python3 -I inputs/client.py $req $d/mcp-$n $cwd -- $GRANTIVA mcp $*" >> $d/commands.txt
  python3 -I $S/tools/client.py $d/mcp-$n/requests.json $d/mcp-$n $cwd -- $GRANTIVA mcp "$@"; echo "== $id/mcp-$n"; cut -c1-${MCPCUT:-1500} $d/mcp-$n/transcript.txt; }
ui() { adb -s ${1:-$SER} shell uiautomator dump /sdcard/u.xml >/dev/null 2>&1; adb -s ${1:-$SER} shell cat /sdcard/u.xml | grep -oE '(text|content-desc)="[^"]+"' | tr '\n' ' '; echo; }
# rr ROW verdict 'note' : re-run line (fix round 1); evidence dir ROW/rerun/
rr() { echo "| $1 rerun | $2 | findings/evidence/cov2-android/$1/rerun/ | $3 |" >> $S/results.rows; }
rref() { mkdir -p $E/$1/rerun; echo "# shared evidence: see ../../$2/ ($3)" >> $E/$1/rerun/commands.txt; }
