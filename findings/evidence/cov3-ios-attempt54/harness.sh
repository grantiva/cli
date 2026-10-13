#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt54"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt54-a"; B="$BASE/attempt54-b"
U1=563907E1-703D-4322-AE5F-FC3B06D03143; U2=1B1102EC-224B-4EF7-937E-370A0DC317DA
if [[ -e "$ROOT" || -e "$A" || -e "$B" ]]; then print -u2 'refusing overwrite attempt54'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"; rsync -a --exclude '.grantiva' "$SRC/" "$B/"
cp "$A/.maestro/01-browse.yaml" "$B/.maestro/05-category.yaml" "$ROOT/"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"
 echo "owned_u1=$U1"; echo "owned_u2=$U2"
} > "$ROOT/commands.txt"
find "$GRANTIVA_RUNNER_HOME/versions" -path '*/devices/*' -maxdepth 5 -print > "$ROOT/device-homes-before.txt" 2> "$ROOT/device-homes-before.err"
integer failures=0
for i in {1..5}; do
  mkdir -p "$ROOT/pair-$i"
  print -r -- "cwd=$A $GRANTIVA run --no-build --simulator $U1 --flow .maestro/01-browse.yaml --report-dir $ROOT/pair-$i/u1-report" > "$ROOT/pair-$i/u1.command.txt"
  print -r -- "cwd=$B $GRANTIVA run --no-build --simulator $U2 --flow .maestro/05-category.yaml --report-dir $ROOT/pair-$i/u2-report" > "$ROOT/pair-$i/u2.command.txt"
  (cd "$A" && "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir "$ROOT/pair-$i/u1-report") > "$ROOT/pair-$i/u1.out" 2> "$ROOT/pair-$i/u1.err" &
  local_p1=$!
  (cd "$B" && "$GRANTIVA" run --no-build --simulator "$U2" --flow .maestro/05-category.yaml --report-dir "$ROOT/pair-$i/u2-report") > "$ROOT/pair-$i/u2.out" 2> "$ROOT/pair-$i/u2.err" &
  local_p2=$!
  wait "$local_p1"; rc1=$?; wait "$local_p2"; rc2=$?
  print -r -- "$rc1" > "$ROOT/pair-$i/u1.exit.txt"; print -r -- "$rc2" > "$ROOT/pair-$i/u2.exit.txt"
  (( rc1 == 0 && rc2 == 0 )) || failures=$((failures+1))
done
find "$GRANTIVA_RUNNER_HOME/versions" -path '*/devices/*' -maxdepth 5 -print > "$ROOT/device-homes-after.txt" 2> "$ROOT/device-homes-after.err"
print -r -- "$failures" > "$ROOT/failed-pairs.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit $(( failures == 0 ? 0 : 1 ))
