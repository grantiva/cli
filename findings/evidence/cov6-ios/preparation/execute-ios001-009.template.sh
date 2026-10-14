#!/bin/bash
# TEMPLATE ONLY: root must bind runner home and primary name; do not execute with PENDING tokens.
set -u
ROOT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-ios
E="$ROOT/findings/evidence/cov6-ios"
REC="$ROOT/findings/tools/cov6-ios/capture-one.rb"
CLI=/Users/kyle/.grantiva-qa/bin/grantiva
EMPTY=/private/tmp/grantiva-candidate5-ios-empty
if grep -q PENDING_CANDIDATE5_IOS_RUNNER_HOME "$REC"; then
  echo "candidate5 iOS bindings are unresolved" >&2
  exit 64
fi
mkdir -p "$EMPTY" "$E"

cap() {
  local row="$1" label="$2" timeout="$3"; shift 3
  ruby "$REC" "$E/$row" "$label" "$EMPTY" --timeout "$timeout" -- "$@"
}
inv() {
  local row="$1" label="$2"
  cap "$row" "$label" 30 xcrun simctl list devices available -j
}

inv IOS-001 inventory-before
cap IOS-001 ensure-name-only 120 "$CLI" simulator ensure --name "cov6-ios-3 iPhone 17"
inv IOS-001 inventory-after-create

inv IOS-002 inventory-before
cap IOS-002 ensure-reuse 120 "$CLI" simulator ensure --name "cov6-ios-3 iPhone 17"
inv IOS-002 inventory-after-reuse
cap IOS-002 delete-owned 60 "$CLI" simulator delete --name "cov6-ios-3 iPhone 17"
inv IOS-002 inventory-after-delete

inv IOS-003 inventory-before
cap IOS-003 ensure-pin 120 "$CLI" simulator ensure --name "cov6-ios-4 Pin" --device-type "iPhone 17" --runtime latest
inv IOS-003 inventory-after-create

inv IOS-004 inventory-before
cap IOS-004 ensure-runtime26 120 "$CLI" simulator ensure --name "cov6-ios-3 iPhone 17" --runtime 26.0
inv IOS-004 inventory-after-26-before-delete
cap IOS-004 ensure-runtime99 30 "$CLI" simulator ensure --name cov6-ios-4 --device-type "iPhone 17" --runtime 99.9 || true
inv IOS-004 inventory-after-99
cap IOS-004 delete-owned26 60 "$CLI" simulator delete --name "cov6-ios-3 iPhone 17"
inv IOS-004 inventory-after-delete

inv IOS-005 inventory-before
cap IOS-005 ensure-no-boot 60 "$CLI" simulator ensure --name cov6-ios-3 --device-type "iPhone 17" --runtime 26.0 --no-boot
inv IOS-005 inventory-after-create-before-delete
cap IOS-005 delete-owned 60 "$CLI" simulator delete --name cov6-ios-3
inv IOS-005 inventory-after-delete

inv IOS-006 inventory-before
cap IOS-006 ensure-json-new 120 "$CLI" simulator ensure --name cov6-ios-3 --device-type "iPhone 17" --runtime 26.0 --json
inv IOS-006 inventory-after-new
cap IOS-006 ensure-json-primary-reuse 120 "$CLI" simulator ensure --name cov6-ios-26 --json
inv IOS-006 inventory-after-primary-reuse
cap IOS-006 delete-owned 60 "$CLI" simulator delete --name cov6-ios-3
inv IOS-006 inventory-after-delete

inv IOS-007 inventory-before
cap IOS-007 ensure-negative 30 "$CLI" simulator ensure --name cov-thing || true
inv IOS-007 inventory-after

inv IOS-008 inventory-before
ruby "$REC" "$E/IOS-008" concurrent-a "$EMPTY" --timeout 180 -- "$CLI" simulator ensure --name cov6-ios-3 --device-type "iPhone 17" --runtime 26.0 &
ra=$!
ruby "$REC" "$E/IOS-008" concurrent-b "$EMPTY" --timeout 180 -- "$CLI" simulator ensure --name cov6-ios-3 --device-type "iPhone 17" --runtime 26.0 &
rb=$!
wait "$ra"; ea=$?
wait "$rb"; eb=$?
printf '%s\n' "$ea" > "$E/IOS-008/concurrent-a.collector-exit"
printf '%s\n' "$eb" > "$E/IOS-008/concurrent-b.collector-exit"
inv IOS-008 inventory-after

cap IOS-009 ledger 30 /bin/cat /private/tmp/grantiva-candidate5-coverage-qjr26z3g/ios-runner-home/simulator-capacity/created.json
inv IOS-009 inventory-current
