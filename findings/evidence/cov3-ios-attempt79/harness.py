import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

wt = Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios')
root = wt / 'findings/evidence/cov3-ios-attempt79'
scratch = Path('/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt79-ios')
if root.exists() or scratch.exists():
    raise SystemExit('refusing overwrite attempt79')
root.mkdir(); scratch.mkdir()
(root / 'harness.py').write_bytes(Path(__file__).read_bytes())
g = '/Users/kyle/.grantiva-qa/bin/grantiva'
u = '563907E1-703D-4322-AE5F-FC3B06D03143'
env = dict(os.environ, GRANTIVA_RUNNER_HOME='/Users/kyle/.grantiva-qa/runner', GRANTIVA_SESSION_ID='cov3-ios')
env.pop('GRANTIVA_API_KEY', None)
header = 'appId: com.kylebrowning.Landmarks\n---\n'
config = 'scheme: "Landmarks (UI Testing)"\nsimulator: cov3-ios-26\nbundle_id: com.kylebrowning.Landmarks\n'
(scratch / 'a.yaml').write_text(header + '- runFlow: b.yaml\n')
(scratch / 'b.yaml').write_text(header + '- runFlow: a.yaml\n')
(scratch / 'flows').mkdir(); (scratch / 'shared').mkdir()
(scratch / 'flows/a.yaml').write_text(header + '- runFlow: ../shared/b.yaml\n')
(scratch / 'shared/b.yaml').write_text(header + '- runFlow: ../flows/a.yaml\n')
records = []
def run(name, args):
    cmd = [g] + args
    (root / (name + '.command.json')).write_text(json.dumps({'argv': cmd, 'cwd': str(scratch)}, indent=2) + '\n')
    started = time.monotonic()
    p = subprocess.run(cmd, cwd=scratch, env=env, capture_output=True, timeout=60)
    elapsed = time.monotonic() - started
    (root / (name + '.out')).write_bytes(p.stdout)
    (root / (name + '.err')).write_bytes(p.stderr)
    (root / (name + '.exit.txt')).write_text(str(p.returncode) + '\n')
    records.append({'name': name, 'exit': p.returncode, 'elapsedSeconds': elapsed})

(scratch / 'grantiva.yml').write_text(config)
run('root-cycle', ['run', '--no-build', '--simulator', u, '--flow', 'a.yaml'])
run('subdirectory-cycle', ['run', '--no-build', '--simulator', u, '--flow', 'flows/a.yaml'])
(scratch / 'grantiva.yml').write_text(config + 'screens:\n  - name: S\n    path:\n      - run_flow: a.yaml\n')
run('screens-cycle-run', ['run', '--no-build', '--simulator', u])
run('screens-cycle-diff', ['diff', 'capture', '--no-build', '--simulator', u])
(root / 'summary.json').write_text(json.dumps(records, indent=2) + '\n')
for src in scratch.rglob('*'):
    if src.is_file() and '.grantiva' not in src.parts:
        dst = root / 'inputs' / src.relative_to(scratch)
        dst.parent.mkdir(parents=True, exist_ok=True); dst.write_bytes(src.read_bytes())
(root / 'all-files.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + str(p) + '\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name != 'all-files.sha256'))
print(json.dumps(records))
