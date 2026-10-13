#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock; D="--device emulator-5554 --no-build"
cp $CF/a.yaml $CF/b.yaml $CF/sub.yaml $CF/sub2.yaml $P/
W(){ echo "cp $1 grantiva-android.yml; $2; rc=\$?; cp $STOCK grantiva-android.yml; exit \$rc"; }
rec AND-128 "$(W .maestro/coverage/cfg/screens-steps.grantiva-android.yml "rm -rf .grantiva/captures/android; $GRANTIVA diff capture $D --verbose; echo exit=\$?; ls .grantiva/captures/android")"
rec B2-K24 "$(W $CF/mf.yml "rm -rf .grantiva/captures/android; $GRANTIVA diff capture $D --verbose; echo exit=\$?; ls .grantiva/captures/android; $GRANTIVA diff capture $D --platform android; echo exit=\$?")"
rec B2-K109 "$(W $CF/mf-2s.yml "$GRANTIVA diff capture $D --verbose; echo exit=\$?")"
rec B-C08.2 "$(W $CF/native-id.yml "$GRANTIVA diff capture $D; echo exit=\$?")"
rec B2-K83 "$(W $CF/k83.yml "rm -rf .grantiva/captures/android; $GRANTIVA diff capture $D; echo exit=\$?; ls .grantiva/captures/android")"
rec B2-K83 "$(W $CF/k83file.yml "rm -rf .grantiva/captures/android; $GRANTIVA diff capture $D; echo exit=\$?; ls .grantiva/captures/android")"
rec D2-05 "$(W $CF/mf-full.yml "rm -rf .grantiva/captures/android; $GRANTIVA diff capture $D --verbose; echo exit=\$?; ls .grantiva/captures/android")"
rec B2-K90-b "$(W $CF/k90b.yml "$GRANTIVA diff capture $D --timeout 120; echo exit=\$?")"
# stock VRT
rec B2-K89 "rm -rf .grantiva/baselines/android .grantiva/captures/android; $GRANTIVA diff capture $D; echo exit=\$?; $GRANTIVA diff compare; echo exit=\$?; $GRANTIVA diff compare --json; echo exit=\$?"
rec B2-K89 "$GRANTIVA diff approve --screen Home; echo exit=\$?; $GRANTIVA diff compare; echo exit=\$?; $GRANTIVA diff compare --json | head -5; echo exit=\${PIPESTATUS[0]}"
rec AND-086 "find .grantiva/baselines -type f | sort; $GRANTIVA diff approve --json; echo exit=\$?; find .grantiva/baselines -type f | sort; ls ../ios 2>/dev/null | head -1"
rec AND-087 "$GRANTIVA diff compare; echo exit=\$?; $GRANTIVA diff compare --json > $E/AND-087/unchanged.json; echo exit=\$?"
rec AND-087 "python3 -I -c \"
from PIL import Image\" 2>/dev/null && echo pil || echo nopil; cp '.grantiva/captures/android/Deep Links.png' $S/dl-orig.png; python3 -I $S/tools/perturb.py '.grantiva/captures/android/Deep Links.png' 0; python3 -I $S/tools/perturb.py .grantiva/captures/android/Lakes.png 1; $GRANTIVA diff compare; echo exit=\$?; $GRANTIVA diff compare --json > $E/AND-087/changed.json; echo exit=\$?; find .grantiva -name '*_diff.png'"
rec AND-138 "$GRANTIVA diff capture $D --json > $E/AND-138/plain.json 2> $E/AND-138/plain.err; $GRANTIVA diff capture $D --json --quiet > $E/AND-138/quiet.json 2> $E/AND-138/quiet.err; $GRANTIVA diff capture $D --json --verbose > $E/AND-138/verbose.json 2> $E/AND-138/verbose.err; wc -l $E/AND-138/*.err; python3 -I -c \"
import json
for m in ['plain','quiet','verbose']:
  d=json.load(open('$E/AND-138/'+m+'.json')); [s.pop('timestamp',None) for s in d['screens']]; d.pop('duration',None)
  for s in d['screens']:
    for st in s['steps']: st.pop('duration',None)
  print(m, json.dumps(d,sort_keys=True)[:0], hash(json.dumps(d,sort_keys=True)))
\""
echo G7-DONE
