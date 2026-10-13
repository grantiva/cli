#!/bin/bash
set +e
source "$(dirname "$0")/lib3.sh"

# B3-L15.1: unique ids preserve tool-to-response association.
d=$(fd B3-L15.1-rerun2); mkdir -p "$E/B3-L15.1-rerun2"
printf '{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n' | mcpq B3-L15.1-rerun2 list "$d" -
jq -r 'select(.id==1).result.tools[].name' "$E/B3-L15.1-rerun2/list.out" > "$E/B3-L15.1-rerun2/names.txt"
i=100; while read n; do call "$i" "$n" '{}'; i=$((i+1)); done < "$E/B3-L15.1-rerun2/names.txt" | mcpq B3-L15.1-rerun2 all "$d" -

# B3-L26-b: all five commands in an empty directory.
d=$(fd B3-L26-b-rerun)
for c in 'record --duration 2' run 'diff capture' 'build install' 'runner start'; do n=$(echo "$c"|tr ' ' _); (cd "$d" && ev B3-L26-b-rerun "$n" "$GRANTIVA $c --device a --emulator b"); done

# B3-L27: absolute-home install first/no-op/JSON comparison in scratch.
d=$(fd B3-L27-rerun); abs="$d/rh"
(cd "$d" && ev B3-L27-rerun absolute1 "GRANTIVA_RUNNER_HOME=$abs $GRANTIVA runner install"; ev B3-L27-rerun absolute2 "GRANTIVA_RUNNER_HOME=$abs $GRANTIVA runner install"; ev B3-L27-rerun absolute_json "GRANTIVA_RUNNER_HOME=$abs $GRANTIVA runner install --json")

# B-C02.4 semantic source evidence for both named criteria.
(cd "$R" && ev B-C02.4-rerun source "sed -n '150,176p' Tests/GrantivaCoreTests/EmulatorManagerTests.swift; sed -n '898,930p' Tests/GrantivaCoreTests/EmulatorManagerTests.swift")

# B3-L25 valid production-source path plus the named tests.
(cd "$R" && ev B3-L25-rerun source "grep -n -E 'ExtraTrak|NoVideo|Unreadable|mdia|hdlr|held' Tests/GrantivaCoreTests/MP4LastFrameHoldTests.swift Sources/GrantivaCore/Android/MP4LastFrameHold.swift | head -160")
