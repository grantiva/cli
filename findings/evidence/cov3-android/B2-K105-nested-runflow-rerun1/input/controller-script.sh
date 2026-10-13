#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K105-nested-runflow-rerun1"; serial=emulator-5554
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro/coverage"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k105-nested-runflow-v1.sh" "$base/input/controller-script.sh"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/coverage/14-runflow-sub.yaml" <<'YAML'
- tapOn: "Favorites"
- assertVisible: "Landmarks you favorite will appear here."
YAML
cat > "$base/project/.maestro/coverage/14-runflow-nested.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp:
    clearState: true
- repeat:
    times: 1
    commands:
      - runFlow: 14-runflow-sub.yaml
YAML
cp "$base/project/.maestro/coverage/14-runflow-sub.yaml" "$base/input/14-runflow-sub.yaml"; cp "$base/project/.maestro/coverage/14-runflow-nested.yaml" "$base/input/14-runflow-nested.yaml"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
printf '$ %q run --platform android --device %q --no-build --flow .maestro/coverage/14-runflow-nested.yaml --report-dir %q --verbose\n' "$GRANTIVA" "$serial" "$base/report" > "$base/command.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/coverage/14-runflow-nested.yaml --report-dir "$base/report" --verbose) > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?; echo "$rc" > "$base/exit.txt"
python3 -I - "$base" "$rc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); rc=int(sys.argv[2]); err=(b/'stderr.txt').read_text(); report=json.loads((b/'report/report.json').read_text()); flow=json.loads(next((b/'report').glob('flows/*.json')).read_text()) if list((b/'report').glob('flows/*.json')) else json.loads((b/'report/flow-000.json').read_text()); combined=json.dumps(flow)
checks={'exit0':rc==0 and report.get('status')=='passed','asWrittenStep':'runFlow: 14-runflow-sub.yaml' in err,'asWrittenHeader':'Run 14-runflow-sub.yaml' in err,'noAbsoluteStep':str(b/'project/.maestro/coverage/14-runflow-sub.yaml') not in err,'reportNestedRunFlow':'runFlow' in combined and 'repeat' in combined,'subcommandsPass':'tapOn' in combined and 'assertVisible' in combined}
(b/'decoded.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
