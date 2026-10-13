#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L41-variant-module-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l41-variant-module-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
run_case(){ name="$1"; shift; d="$base/runs/$name"; mkdir -p "$d"; load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"; printf '%s\n' "$load" > "$d/load1-before.txt"; python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<20 else 1)' "$load" || return 99; printf '# cwd=%s\n$' "$P" > "$d/command.txt"; printf ' %q' "$@" >> "$d/command.txt"; printf '\n' >> "$d/command.txt"; (cd "$P" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; printf '%s\n' "$?" > "$d/exit.txt"; }
run_case invalid-variant-text "$GRANTIVA" build build --platform android --variant noSuchVariant || exit 3
run_case invalid-variant-json "$GRANTIVA" build build --platform android --variant noSuchVariant --json || exit 4
run_case invalid-module "$GRANTIVA" build build --platform android --module nosuch || exit 5
run_case gradle-tasks ./gradlew :app:tasks --all --console=plain || exit 6
python3 -I - "$base" <<'PY'
import json,pathlib,re,sys
b=pathlib.Path(sys.argv[1]); t=(b/'runs/invalid-variant-text/stderr.txt').read_text()+(b/'runs/invalid-variant-text/stdout.txt').read_text(); j=json.loads((b/'runs/invalid-variant-json/stdout.txt').read_text()); m=(b/'runs/invalid-module/stderr.txt').read_text()+(b/'runs/invalid-module/stdout.txt').read_text(); g=(b/'runs/gradle-tasks/stdout.txt').read_text(); assembled=sorted(set(re.findall(r'^assemble([A-Z][A-Za-z0-9]*)\b',g,re.M)))
checks={'invalidsNonzero':all(int((b/'runs'/n/'exit.txt').read_text())!=0 for n in ['invalid-variant-text','invalid-variant-json','invalid-module']),'textListsVariants':'Variants of :app:' in t,'jsonListsVariants':any('Variants of :app:' in str(x) for x in j.get('errors',[])),'moduleListsApp':'Modules: app' in m,'gradleAssembleVariants':len(assembled)>0}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'assembleSuffixes':assembled,'json':j},indent=2)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
