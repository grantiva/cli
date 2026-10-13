#!/bin/bash
# show.sh ID... : matrix row text, round-2 result line and round-2 commands
SC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-cli
O=/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings
for id in "$@"; do
python3 - "$id" <<PY
import json,sys
for r in json.load(open('$SC/cli_rows.json')):
    if r['id'].split(' ')[0]==sys.argv[1]:
        print('##',r['id'],'| L%d'%r['line'],'|',r['cmd'],'|',r['inp'],'|',r['exp'])
PY
grep "^| $id |" $O/cov2-cli-results.md | cut -d'|' -f3,5 | cut -c1-700 | sed 's/^/  R2:/'
[ -f $O/evidence/cov2-cli/$id/commands.txt ] && grep -v '^# cwd' $O/evidence/cov2-cli/$id/commands.txt | sed 's#/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad#$SP#g' | cut -c1-400 | head -${N:-25} | sed 's/^/  C:/'
echo
done
