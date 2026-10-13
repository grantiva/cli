import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt82')
name = 'cov3-ios-82-reaper-control iPhone 17'
g = '/Users/kyle/.grantiva-qa/bin/grantiva'
if root.exists():
    raise SystemExit('refusing overwrite attempt82')
root.mkdir()
(root / 'harness.py').write_bytes(Path(__file__).read_bytes())
env = dict(os.environ, GRANTIVA_RUNNER_HOME='/Users/kyle/.grantiva-qa/runner', GRANTIVA_SESSION_ID='cov3-ios-a82')
env.pop('GRANTIVA_API_KEY', None)

def inventory(filename):
    p = subprocess.run(['xcrun', 'simctl', 'list', 'devices', '-j'], capture_output=True, check=True)
    (root / filename).write_bytes(p.stdout)
    return [d for ds in json.loads(p.stdout)['devices'].values() for d in ds]

assert not any(d['name'] == name for d in inventory('before.json'))
u = subprocess.check_output(['xcrun', 'simctl', 'create', name, 'iPhone 17', 'iOS 26.0'], text=True).strip()
(root / 'owned.udid').write_text(u + '\n')
sleeper = None
try:
    assert any(d['name'] == name and d['udid'] == u and d['state'] == 'Shutdown' for d in inventory('created.json'))
    # This process does not invoke Grantiva or access the simulator. Its trailing
    # arguments are inert data, deliberately resembling a wrapper's parameters.
    cmd = [sys.executable, '-I', '-c', 'import time; time.sleep(120)', g, u]
    (root / 'sleeper-command.json').write_text(json.dumps(cmd, indent=2) + '\n')
    with (root / 'sleeper.out').open('wb') as out, (root / 'sleeper.err').open('wb') as err:
        sleeper = subprocess.Popen(cmd, stdout=out, stderr=err, start_new_session=True)
        (root / 'sleeper.pid').write_text(str(sleeper.pid) + '\n')
        time.sleep(.2)
        assert sleeper.poll() is None
        before = subprocess.check_output(['ps', '-axo', 'pid=,pgid=,command='])
        (root / 'ps-before.txt').write_bytes(before)
        command = [g, 'simulator', 'teardown', '--udid', u, '--force', '--json']
        (root / 'teardown-command.json').write_text(json.dumps(command, indent=2) + '\n')
        started = time.monotonic()
        with (root / 'teardown.out').open('wb') as tout, (root / 'teardown.err').open('wb') as terr:
            result = subprocess.run(command, env=env, stdout=tout, stderr=terr, timeout=60)
        time.sleep(.2)
        (root / 'summary.json').write_text(json.dumps({'teardownExit': result.returncode, 'elapsedSeconds': time.monotonic()-started, 'inertSleeperPid': sleeper.pid, 'inertSleeperExit': sleeper.poll()}, indent=2) + '\n')
        (root / 'ps-after.txt').write_bytes(subprocess.check_output(['ps', '-axo', 'pid=,pgid=,command=']))
finally:
    if sleeper is not None and sleeper.poll() is None:
        sleeper.terminate(); sleeper.wait(timeout=10)
    hits = [d for d in inventory('cleanup-before.json') if d['udid'] == u]
    assert len(hits) == 1 and hits[0]['name'] == name
    subprocess.run(['xcrun', 'simctl', 'delete', u], check=True)
    assert not any(d['udid'] == u for d in inventory('cleanup-after.json'))
    (root / 'all-files.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + str(p) + '\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name != 'all-files.sha256'))
