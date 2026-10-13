#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L42-a-both-selector-negative-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l42a-both-selector-negative-v1.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
screens:
  - name: Invalid Both Selector Keys
    path:
      - tap: {id: "clock", text: "Clock"}
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
printf '# cwd=%s\n$ %q diff capture --platform android --device emulator-5554 --no-build\n' "$base/project" "$GRANTIVA" > "$base/command.txt"
(cd "$base/project" && "$GRANTIVA" diff capture --platform android --device emulator-5554 --no-build) > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?
echo "$rc" > "$base/exit.txt"
python3 -I - "$base" "$rc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); msg=(b/'stdout.txt').read_text()+(b/'stderr.txt').read_text(); low=msg.lower()
checks={'nonzero':int(sys.argv[2])!=0,'namesConfig':'grantiva-android.yml' in msg,'namesStep':'tap' in low,'namesBothKeys':'id' in low and 'text' in low,'explainsExclusive':any(x in low for x in ['not both','exactly one','either','mutually exclusive']),'noCapture':not (b/'project/.grantiva/run-captures').exists()}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'message':msg},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
