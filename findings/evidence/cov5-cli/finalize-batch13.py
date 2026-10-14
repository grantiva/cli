from pathlib import Path
import json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli'); ev=root/'findings/evidence/cov5-cli'
source_rows={'B-R04.4','B-R05.4'}
texts={
'B-R03.1':'Fresh README search found no fixed-300-second statement (rg exit 1 with empty raw), while the captured timeout section documents the configured timeout and its behavior.',
'B-R03.3':'Fresh README and `run --help` captures retain the required snapshot, continue-on-failure, and timeout descriptions.',
'B-R04.1':'Fresh MCP calls in an exact empty directory returned `isError: true` for both build and VRT capture, naming the missing grantiva.yml path and init remedy; the server continued to tools/list.',
'B-R04.2':'Fresh MCP run/test calls in the same exact empty directory returned structured `isError` missing-config results and the server continued. The approved current-tree source tests cover the remaining config-reading and config-free tool partition without invoking protected device inventories.',
'B-R04.3':'Fresh MCP VRT capture against an existing config with no screens returned `isError: true` and exactly `Error: No screens configured in grantiva.yml`.',
'B-R04.4':'Fresh source inspection locates the named MCP missing-config regression; the approved source disposition joins that named current-tree test to the accepted 2,027-test run.',
'B-R05.4':'Fresh source inspection locates the exact starting-session MCP regressions, including UIAutomator2 no-session wording and structured result checks; approved source disposition joins them to the accepted current-tree test run.',
'N-07':'Fresh `runner start --help` output names WDA and UIAutomator2 on Android in the command abstract.'}
for row,text in texts.items():
 d=ev/f'{row}-run-1'; (d/'verdict.md').write_text(f'# {row} verdict\n\nResult: **pass**\n\n{text}\n')
 if row in source_rows or row=='B-R04.2':
  (d/'source-join.json').write_text(json.dumps({'candidateManifestSHA256':'714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783','sourceDisposition':'/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-coverage/source-evidence-disposition.json','sourceDispositionSHA256':'9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3'},indent=2)+'\n')
ledger=root/'findings/cov5-cli-results.md'; s=ledger.read_text(); s=s.replace('| 301 | 295 | 0 | 0 | 1 | 5 | 124 |','| 309 | 303 | 0 | 0 | 1 | 5 | 116 |')
s += '\n' + '\n'.join(f'| {r} | pass | `findings/evidence/cov5-cli/{r}-run-1/` |' for r in texts) + '\n'
ledger.write_text(s)
