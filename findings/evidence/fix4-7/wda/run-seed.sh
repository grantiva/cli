#!/bin/zsh
set -e

evidence=$1
version=$2
udid=$3
expected=$4
expected_count=$5
runner_home=$(<"$evidence/inputs/runner-home.txt")
flow=$(<"$evidence/inputs/flow-path.txt")
app=$(<"$evidence/inputs/app-path.txt")
binary=$(<"$evidence/inputs/final-source/seed-cli-binary-path.txt")
build_dir="$evidence/builds/$version"
mkdir -p "$build_dir"

jq -n --arg session fix4-7 --arg cliHead 138c34136d544026a0b249c81af4129aa71b1297 \
  --arg version "$version" --arg udid "$udid" --arg home "$runner_home" --arg flow "$flow" \
  --arg app "$app" --arg binary "$binary" --arg expected "$expected" \
  --arg startedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session:$session,cliHead:$cliHead,version:$version,udid:$udid,startedAt:$startedAt,apiEnvironmentUnset:true,grantivaRunnerHome:$home,seedApp:$app,expectedConfig:$expected,commands:[["xcrun","simctl","boot",$udid],["xcrun","simctl","bootstatus",$udid,"-b"],["xcrun","simctl","install",$udid,$app],[$binary,"run","--platform","ios","--simulator",$udid,"--bundle-id","com.kylebrowning.Landmarks","--no-build","--flow",$flow]]}' \
  > "$build_dir/start.json"

set +e
xcrun simctl boot "$udid" > "$build_dir/boot.stdout.log" 2> "$build_dir/boot.stderr.log"
boot_exit=$?; print -r -- "$boot_exit" > "$build_dir/boot.exit"
xcrun simctl bootstatus "$udid" -b > "$build_dir/bootstatus.stdout.log" 2> "$build_dir/bootstatus.stderr.log"
bootstatus_exit=$?; print -r -- "$bootstatus_exit" > "$build_dir/bootstatus.exit"
xcrun simctl install "$udid" "$app" > "$build_dir/install.stdout.log" 2> "$build_dir/install.stderr.log"
install_exit=$?; print -r -- "$install_exit" > "$build_dir/install.exit"
ps -axo pid=,ppid=,pgid=,command= | rg "$udid" > "$build_dir/processes-before-run.txt"
env -u GRANTIVA_API_KEY -u GRANTIVA_TOKEN GRANTIVA_SESSION_ID=fix4-7 GRANTIVA_RUNNER_HOME="$runner_home" \
  "$binary" run --platform ios --simulator "$udid" --bundle-id com.kylebrowning.Landmarks \
  --no-build --flow "$flow" > "$build_dir/run.stdout.log" 2> "$build_dir/run.stderr.log"
run_exit=$?; print -r -- "$run_exit" > "$build_dir/run.exit"
ps -axo pid=,ppid=,pgid=,command= | rg "$udid" > "$build_dir/processes-after-run.txt"
set -e

test "$boot_exit" -eq 0
test "$bootstatus_exit" -eq 0
test "$install_exit" -eq 0
test "$run_exit" -eq 0
rg 'GrantivaAgent built' "$build_dir/run.stderr.log" > "$build_dir/build-marker.txt"
! rg 'Using cached GrantivaAgent build' "$build_dir/run.stdout.log" "$build_dir/run.stderr.log"
find "$runner_home/cache/wda-builds" -mindepth 1 -maxdepth 1 -type d -print | sort > "$build_dir/shared-configs-after.txt"
test "$(wc -l < "$build_dir/shared-configs-after.txt" | tr -d ' ')" -eq "$expected_count"
test -d "$runner_home/cache/wda-builds/$expected"
find "$runner_home/cache/wda-builds/$expected/DerivedData/Build/Products" -type f -name '*.xctestrun' -print | sort > "$build_dir/xctestrun.txt"
test -s "$build_dir/xctestrun.txt"
find "$runner_home/cache/wda-builds/$expected/DerivedData/Build/Products" -type d -name 'WebDriverAgentRunner-Runner.app' -print | sort > "$build_dir/wda-runner-products.txt"
test -s "$build_dir/wda-runner-products.txt"

jq -n --arg session fix4-7 --arg version "$version" --arg udid "$udid" --arg config "$expected" \
  --arg finishedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson bootExit "$boot_exit" \
  --argjson bootstatusExit "$bootstatus_exit" --argjson installExit "$install_exit" --argjson runExit "$run_exit" \
  '{session:$session,version:$version,udid:$udid,config:$config,finishedAt:$finishedAt,bootExit:$bootExit,bootstatusExit:$bootstatusExit,installExit:$installExit,runExit:$runExit,builtMarkerOnStderr:true,cachedMarkerAbsent:true,xctestrunComplete:true,runnerProductComplete:true}' \
  > "$build_dir/result.json"
