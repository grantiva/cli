export SC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli
export GRANTIVA=$HOME/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=$HOME/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-cli
unset GRANTIVA_API_KEY
export W=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli
export E=$W/findings/evidence/cov3-cli
export S=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli/rows
export T=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli/tools
export LM=/Users/kyle/Developer/landmarks-demo
# ev ROW LABEL CMD  -- runs CMD with bash -c in the current dir; saves LABEL.out/.err, appends to commands.txt; echoes all
ev() {
  local row=$1 lab=$2 cmd=$3 d=$E/$1
  mkdir -p "$d"
  { echo "# cwd: $PWD"; echo "\$ $cmd"; } >> "$d/commands.txt"
  local t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  bash -c "$cmd" > "$d/$lab.out" 2> "$d/$lab.err" < /dev/null
  local rc=$?
  local t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  local el=$(echo "$t1 - $t0" | bc)
  echo "# exit=$rc elapsed=${el}s -> $lab.out / $lab.err" >> "$d/commands.txt"
  echo "=== [$row/$lab] rc=$rc ${el}s :: $cmd"
  if [ -s "$d/$lab.out" ]; then echo "--- stdout:"; head -c ${MAXOUT:-1500} "$d/$lab.out"; echo; fi
  if [ -s "$d/$lab.err" ]; then echo "--- stderr:"; head -c ${MAXOUT:-1500} "$d/$lab.err"; echo; fi
}
# note ROW text -- append a note line to commands.txt
note() { mkdir -p "$E/$1"; echo "# $2" >> "$E/$1/commands.txt"; }
# res ROW result evidence note
res() { echo "| $1 | $2 | $3 | $4 |" >> $W/findings/cov3-cli-results.md; }
# fresh dir
fd() { rm -rf "$S/$1"; mkdir -p "$S/$1"; echo "$S/$1"; }
ios_copy() { local d=$(fd "$1"); cp -c -R $LM/ios/. "$d/"; echo "$d"; }
and_copy() { local d=$(fd "$1"); cp -c -R $LM/android/. "$d/"; echo "$d"; }
ios_copy() { local d=$(fd "$1"); cp -c -R $LM/ios/. "$d/"; rm -rf "$d/build" "$d/.grantiva"; echo "$d"; }
and_copy() { local d=$(fd "$1"); cp -c -R $LM/android/. "$d/"; rm -rf "$d/build" "$d/.grantiva" "$d/.gradle" "$d/.kotlin" "$d/app/build"; echo "$d"; }
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
# mcp ROW LABEL DIR PLAT  (requests on stdin as jsonl)
mcpq() {
  local row=$1 lab=$2 dir=$3 plat=$4 d=$E/$1; mkdir -p $d
  cat > $d/$lab.requests.jsonl
  { echo "# cwd: $PWD"; echo "\$ MCP_STDERR=$d/$lab.err bash findings/evidence/cov3-cli/inputs/send.sh $dir $plat $d/$lab.requests.jsonl > $d/$lab.out"; } >> $d/commands.txt
  MCP_STDERR=$d/$lab.err bash $T/send.sh "$dir" "$plat" $d/$lab.requests.jsonl > $d/$lab.out 2> $d/$lab.exit
  echo "# $(cat $d/$lab.exit)" >> $d/commands.txt
  echo "=== [$row/$lab] $(cat $d/$lab.exit) stderr-bytes=$(wc -c < $d/$lab.err)"
  python3 $T/summ.py $d/$lab.out
}
call() { printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "${3:-{\}}"; }
# override: results staged as TSV, assembled in matrix order later
res() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> $SC/results.tsv; }
ev2() { ev "$@"; }
export R=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli/tree
# device-safe copies: the stock configs name owner devices (qa-ios-1, Pixel_8_API_35); point them at fake names
ios_copy() { local d=$(fd "$1"); cp -c -R $LM/ios/. "$d/"; rm -rf "$d/build" "$d/.grantiva"; [ -f "$d/grantiva.yml" ] && sed -i '' 's/^simulator: .*/simulator: cov-missing/' "$d/grantiva.yml"; echo "$d"; }
and_copy() { local d=$(fd "$1"); cp -c -R $LM/android/. "$d/"; rm -rf "$d/build" "$d/.grantiva" "$d/.gradle" "$d/.kotlin" "$d/app/build"; [ -f "$d/grantiva-android.yml" ] && sed -i '' 's/^emulator: .*/emulator: cov-missing/' "$d/grantiva-android.yml"; echo "$d"; }
# tg ROW LABEL PATTERN [SUBPATH] -- grep the 8f2cff67 tree (read-only export at $R) and record it as evidence
tg() { local row=$1 lab=$2 pat=$3 sub=${4:-Tests}; (cd $R && ev "$row" "$lab" "grep -rn -E '$pat' $sub | sed 's#^#8f2cff67:#' | cut -c1-400"); }
export RR=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli/runner-src/grantiva-runner-fd9d8e8d1cb109eda6116f4221da10257b9838e3
# rg ROW LABEL PATTERN [SUBPATH] -- grep the runner source at fd9d8e8 (bundled as 1.1.28-grantiva.13)
rgr() { local row=$1 lab=$2 pat=$3 sub=${4:-.}; (cd $RR && ev "$row" "$lab" "grep -rn -E '$pat' $sub --include=*.go | sed 's#^#runner@fd9d8e8:#' | cut -c1-300"); }
# rawq ROW LABEL DIR PLAT -- send raw stdin lines (after initialize) to grantiva mcp; saves LABEL.requests.txt/.out/.err
rawq() { local row=$1 lab=$2 dir=$3 plat=$4 d=$E/$1; mkdir -p $d; cat > $d/$lab.requests.txt
  { echo "# cwd: $PWD"; echo "\$ MCP_STDERR=$d/$lab.err bash findings/evidence/cov3-cli/inputs/send.sh $dir $plat $d/$lab.requests.txt > $d/$lab.out"; } >> $d/commands.txt
  MCP_STDERR=$d/$lab.err bash $T/send.sh "$dir" "$plat" $d/$lab.requests.txt > $d/$lab.out 2> $d/$lab.exit; echo "# $(cat $d/$lab.exit)" >> $d/commands.txt; cat $d/$lab.out | cut -c1-260; }
