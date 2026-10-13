#!/bin/bash
set +e
source "$(dirname "$0")/lib3.sh"

# B-I19.3 / L25 / L30 / L31 / N3-16: source and documentation contracts.
(cd "$R" && ev B-I19.3 source "grep -rn -E 'ImageDifferTests|perceptual_threshold|threshold' Tests/GrantivaCoreTests Sources/GrantivaCore/ImageDiff* README.md | head -80")
(cd "$R" && ev B3-L25 source "grep -n -E 'ExtraTrak|NoVideo|Unreadable|mdia|hdlr|held' Tests/GrantivaCoreTests/MP4LastFrameHoldTests.swift Sources/GrantivaCore/Record/MP4LastFrameHold.swift | head -120")
(cd "$R" && ev B3-L30 docs "test ! -d docs/plans; echo docs_plans_absent=$?; grep -rn -E '1\\.[0-9]+\\.[0-9]+|grantiva/(runner|main)' README.md docs --include='*.md' --exclude-dir=superpowers | head -100; grep -rn -E 'docs/plans|lineage' Tests | head -60")
(cd "$R" && ev B3-L31 ci "grep -n -A18 -B5 -E 'fresh empty runner home|test-fresh-home' .github/workflows/ci.yml; sed -n '1,220p' scripts/test-fresh-home.sh; grep -rn 'testTheDefaultLockDirectoryWasNotCreatedByTests' Tests")
(cd "$R" && ev N3-16 docs "grep -rn -E 'GRANTIVA_DRIVER_START_TIMEOUT|starting|stop.json|Emulator reused|Variants of|trimmed=' README.md docs --include='*.md' --exclude-dir=superpowers; grep -rn -E 'grantiva/(runner|main)' README.md docs --include='*.md' --exclude-dir=superpowers || true")

# L09: read-only AVD provenance plus init in a disposable copy.
d=$(and_copy B3-L09); rm -f "$d/grantiva-android.yml"; (cd "$d" && ev B3-L09 init "$GRANTIVA init"); sed -i '' 's/^emulator: .*/emulator: cov-missing/' "$d/grantiva-android.yml"
(cd "$d" && ev B3-L09 provenance "avdmanager list avd -c; cat $GRANTIVA_RUNNER_HOME/emulator-created.json 2>/dev/null || true; cat grantiva-android.yml")
tg B3-L09 tests 'test.*(AVD|Emulator).*Warning|not.*created by Grantiva' Tests

# L14 cancellation variants. The immediate case was also captured by D2-34.
d=$(ios_copy B3-L14.1); sed -i '' 's/^scheme:.*/scheme: NoSuchScheme/' "$d/grantiva.yml"
cat > "$S/B3-L14.1-requests.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized"},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_timeout":0.2},
 {"method":"notifications/cancelled","params":{"requestId":2,"reason":"test"}},
 {"method":"tools/list"},
 {"method":"notifications/cancelled","params":{"requestId":99,"reason":"unknown"}},
 {"method":"tools/list"}
]
JSON
mkdir -p "$E/B3-L14.1"; cp "$S/B3-L14.1-requests.json" "$E/B3-L14.1/requests.json"
ev B3-L14.1 cancel "python3 $T/client.py $E/B3-L14.1/requests.json $E/B3-L14.1/client $d -- $GRANTIVA mcp --project-dir $d --platform ios"
tg B3-L14.1 tests 'cancel|Cancelled|cancellation' Tests

# L15 full empty-argument tool contract.
d=$(fd B3-L15.1)
python3 "$T/mcp_names.py" > "$E/B3-L15.1/names.txt"
{ call 10 grantiva_sim_ensure '{}'; call 11 grantiva_emulator_ensure '{}'; call 12 grantiva_bogus_tool '{}'; call 13 grantiva_script '{}'; call 14 grantiva_swipe '{}'; call 15 grantiva_type '{}'; while read n; do call 20 "$n" '{}'; done < "$E/B3-L15.1/names.txt"; } | mcpq B3-L15.1 all "$d" -
tg B3-L15.1 tests 'ToolErrorContractTests|required.*name|Unknown tool' Tests

# L16 atomic approve and MCP parity.
d=$(ios_copy B3-L16); mkdir -p "$d/.grantiva/captures" "$d/.grantiva/baselines"; cp "$E/CLI-150/Home.png" "$d/.grantiva/captures/Home.png" 2>/dev/null || cp "$E/N2-04/A.png" "$d/.grantiva/captures/Home.png"
(cd "$d" && ev B3-L16 three "$GRANTIVA diff approve Missing1 Missing2 Missing3"; ev B3-L16 mixed "$GRANTIVA diff approve Home Missing1"; ev B3-L16 baseline_ls "find .grantiva/baselines -type f -print"; ev B3-L16 one "$GRANTIVA diff approve Missing1")
call 30 grantiva_vrt_approve '{"screens":["Missing1","Missing2","Missing3"]}' | mcpq B3-L16 mcp "$d" ios

# L17 context lookup spellings.
base=$(ios_copy B3-L17-base); empty=$(fd B3-L17-empty)
call 31 grantiva_context '{}' | mcpq B3-L17 auto "$empty" -
call 32 grantiva_context '{}' | mcpq B3-L17 ios "$empty" ios
(cd "$empty" && call 33 grantiva_context '{}' | mcpq B3-L17 cwd "$empty" -)

# L26 and N3-08 usage shapes.
di=$(ios_copy B3-L26-a-ios); da=$(and_copy B3-L26-a-and)
(cd "$di" && ev B3-L26-a ios "$GRANTIVA record --duration 2 --output a.mp4"; ev N3-08 ios "$GRANTIVA record --duration 2 --output a.mp4"; ev N3-08 zero "$GRANTIVA record --duration 0")
(cd "$da" && ev B3-L26-a android "$GRANTIVA record --duration 2 --output a.mov"; ev N3-08 android "$GRANTIVA record --duration 2 --output a.mov"; ev N3-08 both "$GRANTIVA record --duration 2 --device a --emulator b"; ev N3-08 teardown "$GRANTIVA emulator teardown --serial emulator-9999 --all")
for c in 'record --duration 2' run 'diff capture' 'build install' 'runner start'; do n=$(echo "$c"|tr ' ' _); (cd "$da" && ev B3-L26-b "$n" "$GRANTIVA $c --device a --emulator b"); done
de=$(fd B3-L26-b-empty); (cd "$de" && ev B3-L26-b empty "$GRANTIVA run --device a --emulator b")

# L27/L28/N3-11 runner home and missing-bundle behaviour.
d=$(fd B3-L27); mkdir -p "$d/bin"; cp "$GRANTIVA" "$d/bin/grantiva"
(cd "$d" && ev B3-L27 relative1 "GRANTIVA_RUNNER_HOME=rh $GRANTIVA runner install"; ev B3-L27 relative2 "GRANTIVA_RUNNER_HOME=rh $GRANTIVA runner install"; ev B3-L27 json "GRANTIVA_RUNNER_HOME=rh $GRANTIVA runner install --json"; ev B3-L27 doctor "GRANTIVA_RUNNER_HOME=$d/rh $GRANTIVA doctor --platform ios"; ev B3-L27 version "GRANTIVA_RUNNER_HOME=$d/rh $GRANTIVA runner version --json"; ev B3-L27 warning "GRANTIVA_RUNNER_HOME=rh ./bin/grantiva runner install")
d=$(fd B3-L28); mkdir -p "$d/bin"; cp "$GRANTIVA" "$d/bin/grantiva"; GRANTIVA_RUNNER_HOME="$d/home" "$GRANTIVA" runner install >/dev/null 2>&1
(cd "$d" && ev B3-L28 install "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner install"; ev B3-L28 json "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner install --json"; ev B3-L28 fresh "GRANTIVA_RUNNER_HOME=$d/fresh ./bin/grantiva runner install")
cp -R "$E/B3-L28" "$E/N3-11" 2>/dev/null || true
(cd "$d" && ev N3-11 install "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner install"; ev N3-11 version "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner version"; ev N3-11 start "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner start --simulator cov-missing"; ev N3-11 hierarchy "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva hierarchy")

# L29 help/hidden compatibility.
d=$(and_copy B3-L29)
(cd "$d" && ev B3-L29 helps "for p in 'build build' 'build install' run 'ci run' 'diff capture' 'diff compare' 'emulator ensure'; do echo ==\$p; $GRANTIVA \$p --help | grep -E -- '--headless|--emulator|--allow-device-settings|--device'; done"; ev B3-L29 headless "$GRANTIVA build build --headless --module NoSuchModule"; ev B3-L29 emulator "$GRANTIVA build build --emulator cov-missing --module NoSuchModule")

# L42-b config decoder errors.
di=$(ios_copy B3-L42-b-ios); da=$(and_copy B3-L42-b-and)
printf '\nscreens:\n  - name: BadTap\n    steps:\n      - tap: {}\n' > "$di/grantiva.yml"; printf '\nscreens:\n  - name: BadWait\n    steps:\n      - wait: soon\n' > "$da/grantiva-android.yml"
(cd "$di" && ev B3-L42-b ios_run "$GRANTIVA run --no-build --simulator cov-missing"; ev B3-L42-b ios_diff "$GRANTIVA diff capture --no-build --simulator cov-missing")
(cd "$da" && ev B3-L42-b and_run "$GRANTIVA run --no-build --emulator cov-missing"; ev B3-L42-b and_diff "$GRANTIVA diff capture --no-build --emulator cov-missing")

# L53 current direct-runner empty target behaviour and CLI forwarding.
runner="$GRANTIVA_RUNNER_HOME/versions/1.1.28-grantiva.13+android-drivers-2/grantiva-runner"; d=$(fd B3-L53); printf 'appId: com.example\n---\n- launchApp\n' > "$d/flow.yaml"
(cd "$d" && ev B3-L53 device "$runner --platform ios --device '' test flow.yaml"; ev B3-L53 udid "$runner --platform ios --udid '' test flow.yaml"; ev B3-L53 serial "$runner --platform ios --serial '' test flow.yaml"; ev B3-L53 cli_udid "$GRANTIVA runner start --platform ios --udid '' --verbose"; ev B3-L53 cli_serial "$GRANTIVA runner start --platform android --serial '' --verbose")

# N3-15 is read-only doctor output; no device action.
d=$(fd N3-15); (cd "$d" && ev N3-15 text "$GRANTIVA doctor"; ev N3-15 json "$GRANTIVA doctor --json")

# D2-42 MCP configured-screen filtering.
d=$(ios_copy D2-42); mkdir -p "$d/.grantiva/captures" "$d/.grantiva/baselines"; cp "$E/N2-04/A.png" "$d/.grantiva/captures/A.png" 2>/dev/null; cp "$E/N2-04/B.png" "$d/.grantiva/captures/B.png" 2>/dev/null; cp "$E/N2-04/failure-123.png" "$d/.grantiva/captures/failure-123.png" 2>/dev/null
{ call 41 grantiva_vrt_compare '{}'; call 42 grantiva_vrt_approve '{}'; } | mcpq D2-42 configured "$d" ios
