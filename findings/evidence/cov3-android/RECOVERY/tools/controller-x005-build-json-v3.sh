#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/X005-android-build-json-rerun3"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/build"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-x005-build-json-v3.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main rev-parse HEAD > "$base/input/cli-head.txt"
"$GRANTIVA" --version > "$base/input/version.txt" 2>&1
adb devices -l > "$base/input/adb-before.txt"
load="$(python3 -c 'import os; print(os.getloadavg()[0])')"
printf '%s\n' "$load" > "$base/input/one-minute-load.txt"
awk -v n="$load" 'BEGIN{exit !(n < 20)}' || exit 3
cd "$P" || exit 4
{ printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$GRANTIVA" build build --platform android --json; echo; } > "$base/build/commands.txt"
"$GRANTIVA" build build --platform android --json > "$base/build/stdout.log" 2> "$base/build/stderr.log"
rc=$?
echo "rc=$rc" >> "$base/build/commands.txt"
adb devices -l > "$base/build/adb-after.txt"
[ "$rc" -eq 0 ] || exit 5
product="$(jq -r '.product // .productPath // .product_path // empty' "$base/build/stdout.log")"
[ -n "$product" ] || exit 6
case "$product" in /*) resolved="$product" ;; *) resolved="$P/$product" ;; esac
[ -f "$resolved" ] || exit 7
printf '%s\n' "$resolved" > "$base/build/resolved-product.txt"
shasum -a 256 "$resolved" > "$base/build/product.sha256"
cmp -s "$base/input/adb-before.txt" "$base/build/adb-after.txt" || exit 8
printf 'rc=0 product-exists=yes adb-unchanged=yes\n' > "$base/summary.txt"
