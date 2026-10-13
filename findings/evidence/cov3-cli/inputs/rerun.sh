#!/bin/bash
set +e
source "$(dirname "$0")/lib3.sh"

# Correct harness setup for L15: derive every tool from an actual tools/list.
d=$(fd B3-L15.1-rerun); mkdir -p "$E/B3-L15.1-rerun"
printf '{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n' | mcpq B3-L15.1-rerun list "$d" -
jq -r 'select(.id==1).result.tools[].name' "$E/B3-L15.1-rerun/list.out" > "$E/B3-L15.1-rerun/names.txt"
{ call 10 grantiva_sim_ensure '{}'; call 11 grantiva_emulator_ensure '{}'; call 12 grantiva_bogus_tool '{}'; while read n; do call 20 "$n" '{}'; done < "$E/B3-L15.1-rerun/names.txt"; } | mcpq B3-L15.1-rerun all "$d" -

# Correct harness setup for L16: generate a real capture PNG.
d=$(ios_copy B3-L16-rerun); mkdir -p "$d/.grantiva/captures" "$d/.grantiva/baselines"; python3 "$T/mkpng2.py" "$d/.grantiva/captures/Home.png" 10 10 0
(cd "$d" && ev B3-L16-rerun three "$GRANTIVA diff approve Missing1 Missing2 Missing3"; ev B3-L16-rerun mixed "$GRANTIVA diff approve Home Missing1"; ev B3-L16-rerun baseline_ls "find .grantiva/baselines -type f -print"; ev B3-L16-rerun one "$GRANTIVA diff approve Missing1")
call 30 grantiva_vrt_approve '{"screens":["Missing1","Missing2","Missing3"]}' | mcpq B3-L16-rerun mcp "$d" ios

# Correct harness setup for D2-42: configured A/B screens, two captures and a stray.
d=$(fd D2-42-rerun); mkdir -p "$d/.grantiva/captures" "$d/.grantiva/baselines"
cat > "$d/grantiva.yml" <<'YAML'
bundle_id: com.example.app
simulator: cov-missing
screens:
  - name: A
    path: launch
  - name: B
    path: launch
diff:
  threshold: 0.02
  perceptual_threshold: 5
YAML
python3 "$T/mkpng2.py" "$d/.grantiva/captures/A.png" 10 10 0
python3 "$T/mkpng2.py" "$d/.grantiva/captures/B.png" 10 10 0
python3 "$T/mkpng2.py" "$d/.grantiva/captures/failure-123.png" 10 10 0
{ call 41 grantiva_vrt_compare '{}'; call 42 grantiva_vrt_approve '{}'; } | mcpq D2-42-rerun configured "$d" ios

# Correct L42-b config shape: malformed steps live under screen.path.
di=$(fd B3-L42-b-rerun-ios); da=$(fd B3-L42-b-rerun-and)
cat > "$di/grantiva.yml" <<'YAML'
bundle_id: com.example.app
simulator: cov-missing
screens:
  - name: Bad
    path:
      - tap: {txt: X}
      - wait: soon
YAML
cat > "$da/grantiva-android.yml" <<'YAML'
platform: android
application_id: com.example.app
emulator: cov-missing
screens:
  - name: Bad
    path:
      - tap: {txt: X}
      - wait: soon
YAML
(cd "$di" && ev B3-L42-b-rerun ios_run "$GRANTIVA run --no-build --simulator cov-missing"; ev B3-L42-b-rerun ios_diff "$GRANTIVA diff capture --no-build --simulator cov-missing")
(cd "$da" && ev B3-L42-b-rerun and_run "$GRANTIVA run --no-build --emulator cov-missing"; ev B3-L42-b-rerun and_diff "$GRANTIVA diff capture --no-build --emulator cov-missing")
