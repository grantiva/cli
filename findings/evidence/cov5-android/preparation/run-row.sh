#!/bin/zsh
set -u
if (( $# < 2 )); then
  print -u2 'usage: run-row.sh ROW command [args...]'
  exit 64
fi
required=(COV5_ANDROID_HOME COV5_ANDROID_PRIMARY_AVD COV5_ANDROID_PRIMARY_SERIAL COV5_ANDROID_PRIMARY_PID COV5_ANDROID_EXTRA_AVD)
for name in $required; do
  value=${(P)name:-}
  if [[ -z $value || $value == UNKNOWN_* ]]; then
    print -u2 -- "refusing unresolved allocation: $name=${value:-<unset>}"
    exit 78
  fi
done
row=$1
shift
root=/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-android/findings/evidence/cov5-android
dir=$root/$row
mkdir -p "$dir"
start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  print -r -- "cwd=$PWD"
  print -r -- "start=$start"
  print -r -- 'GRANTIVA_SESSION_ID=cov5-android'
  print -r -- 'GRANTIVA_RUNNER_HOME=/private/tmp/grantiva-completion-candidate4-x_i_t3pq/runner-home'
  print -r -- "HOME=$COV5_ANDROID_HOME"
  print -r -- 'GRANTIVA_API_KEY=<unset>'
  print -r -- 'JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
  print -r -- 'ANDROID_HOME=/Users/kyle/Library/Android/sdk'
  print -r -- 'ANDROID_SDK_ROOT=/Users/kyle/Library/Android/sdk'
  print -r -- "primary_avd=$COV5_ANDROID_PRIMARY_AVD"
  print -r -- "primary_serial=$COV5_ANDROID_PRIMARY_SERIAL"
  print -r -- "primary_pid=$COV5_ANDROID_PRIMARY_PID"
  print -r -- "extra_avd=$COV5_ANDROID_EXTRA_AVD"
  printf 'argv='
  printf '%q ' "$@"
  printf '\n'
} > "$dir/commands.txt"
env -u GRANTIVA_API_KEY \
  HOME="$COV5_ANDROID_HOME" \
  GRANTIVA_SESSION_ID=cov5-android \
  GRANTIVA_RUNNER_HOME=/private/tmp/grantiva-completion-candidate4-x_i_t3pq/runner-home \
  JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  ANDROID_HOME=/Users/kyle/Library/Android/sdk \
  ANDROID_SDK_ROOT=/Users/kyle/Library/Android/sdk \
  "$@" > "$dir/stdout.txt" 2> "$dir/stderr.txt"
exit_code=$?
end=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  print -r -- "end=$end"
  print -r -- "exit=$exit_code"
} >> "$dir/commands.txt"
print -r -- "$exit_code" > "$dir/exit.txt"
exit $exit_code
