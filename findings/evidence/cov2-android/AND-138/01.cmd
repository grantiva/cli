/Users/kyle/.grantiva-qa/bin/grantiva diff capture --device emulator-5554 --no-build --json > /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/plain.json 2> /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/plain.err; /Users/kyle/.grantiva-qa/bin/grantiva diff capture --device emulator-5554 --no-build --json --quiet > /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/quiet.json 2> /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/quiet.err; /Users/kyle/.grantiva-qa/bin/grantiva diff capture --device emulator-5554 --no-build --json --verbose > /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/verbose.json 2> /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/verbose.err; wc -l /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/*.err; python3 -I -c "
import json
for m in ['plain','quiet','verbose']:
  d=json.load(open('/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/AND-138/'+m+'.json')); [s.pop('timestamp',None) for s in d['screens']]; d.pop('duration',None)
  for s in d['screens']:
    for st in s['steps']: st.pop('duration',None)
  print(m, json.dumps(d,sort_keys=True)[:0], hash(json.dumps(d,sort_keys=True)))
"
