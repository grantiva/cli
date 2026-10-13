#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt75"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt75-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt75'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$A/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path:
      - launchApp
YAML
cd "$A"
runone() { local n=$1; shift; print -r -- "$@" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
runone pass-no-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml
find .grantiva -print | sort > "$ROOT/after-pass-files.txt"
runone fail-no-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml
find .grantiva -print | sort > "$ROOT/after-fail-files.txt"
rsync -a .grantiva/ "$ROOT/no-report-grantiva/"
runone approve "$GRANTIVA" diff approve --json
runone compare "$GRANTIVA" diff compare --json
find .grantiva -print | sort > "$ROOT/after-vrt-files.txt"
runone pass-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --report-dir "$ROOT/pass-report"
runone fail-report "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/02-exact-negative.yaml --report-dir "$ROOT/fail-report"
find .grantiva -print | sort > "$ROOT/after-report-runs-files.txt"
rsync -a .grantiva/ "$ROOT/final-grantiva/"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/completed.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ $(<"$ROOT/pass-no-report.exit.txt") == 0 && $(<"$ROOT/fail-no-report.exit.txt") != 0 && $(<"$ROOT/pass-report.exit.txt") == 0 && $(<"$ROOT/fail-report.exit.txt") != 0 ]]
