#!/usr/bin/env python3
import hashlib, json, subprocess, time
from pathlib import Path

OUT = Path(__file__).resolve().parent
APP = Path('/private/tmp/grantiva-round4-candidate3-demo.9jkg9hna/Build/Products/UITesting-iphonesimulator/Landmarks.app')
MANIFEST = Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-candidate4/candidate.json')
PROTECTED = ('B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C', 'FE441EE5-BBFC-4981-B68A-59C0DBCE26D6')
SPECS = (
    ('ios26', 'candidate5-early-ios26', 'com.apple.CoreSimulator.SimRuntime.iOS-26-0'),
    ('ios27', 'candidate5-early-ios27', 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'),
)
DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-17'

def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')

def run(label, argv, timeout=180):
    start = time.time()
    write(OUT / f'{label}.start.json', {'argv': argv, 'cwd': str(OUT), 'startedEpoch': start, 'timeoutSeconds': timeout})
    done = subprocess.run(argv, cwd=OUT, stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout)
    (OUT / f'{label}.stdout').write_bytes(done.stdout)
    (OUT / f'{label}.stderr').write_bytes(done.stderr)
    write(OUT / f'{label}.result.json', {'exit': done.returncode, 'startedEpoch': start, 'endedEpoch': time.time(), 'timedOut': False})
    if done.returncode:
        raise RuntimeError(f'{label} exited {done.returncode}')
    return done.stdout.decode().strip()

def inventory(label):
    return json.loads(run(label, ['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))

def flattened(doc):
    return [item for items in doc['devices'].values() for item in items]

candidate = json.loads(MANIFEST.read_text())
checks = []
for entry in candidate['demo']['iosApp']['files']:
    path = APP / entry['path']
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    checks.append({'path': str(path), 'expectedSHA256': entry['sha256'], 'actualSHA256': actual, 'matched': actual == entry['sha256']})
if not checks or not all(item['matched'] for item in checks):
    raise RuntimeError('frozen app identity mismatch')
write(OUT / 'frozen-app-verification.json', {'sourceManifest': str(MANIFEST), 'sourceManifestSHA256': hashlib.sha256(MANIFEST.read_bytes()).hexdigest(), 'appPath': str(APP), 'files': checks, 'allMatched': True})

before = inventory('simulators-before')
devices = flattened(before)
if any(item['name'] in {spec[1] for spec in SPECS} for item in devices):
    raise RuntimeError('reserved candidate5 early name already exists')
stable_protected_keys = ('udid', 'name', 'state', 'deviceTypeIdentifier', 'isAvailable', 'dataPath', 'logPath')
protected_before = {item['udid']: {key: item.get(key) for key in stable_protected_keys} for item in devices if item['udid'] in PROTECTED}
if set(protected_before) != set(PROTECTED):
    raise RuntimeError('protected simulator missing before provisioning')
write(OUT / 'protected-before.json', protected_before)

ownership = {'schema': 'grantiva.candidate5.early-ios-provision.v1', 'status': 'provisioning', 'fixtureOnly': True, 'devices': {}}
for key, name, runtime in SPECS:
    create_argv = ['xcrun', 'simctl', 'create', name, DEVICE_TYPE, runtime]
    udid = run(f'{key}-create', create_argv)
    if not udid or udid in PROTECTED or any(item['udid'] == udid for item in devices):
        raise RuntimeError(f'unexpected created UUID for {key}: {udid}')
    ownership['devices'][key] = {'name': name, 'udid': udid, 'deviceType': DEVICE_TYPE, 'runtime': runtime, 'createdByThisScript': True, 'createArgv': create_argv, 'state': 'Shutdown'}
    write(OUT / 'ownership.json', ownership)
    run(f'{key}-boot', ['xcrun', 'simctl', 'boot', udid])
    ownership['devices'][key]['state'] = 'Booting'; write(OUT / 'ownership.json', ownership)
    run(f'{key}-bootstatus', ['xcrun', 'simctl', 'bootstatus', udid, '-b'])
    ownership['devices'][key]['state'] = 'Booted'; write(OUT / 'ownership.json', ownership)
    run(f'{key}-install', ['xcrun', 'simctl', 'install', udid, str(APP)])
    installed = run(f'{key}-installed-container', ['xcrun', 'simctl', 'get_app_container', udid, 'com.kylebrowning.Landmarks', 'app'])
    ownership['devices'][key]['installedApp'] = installed
    ownership['devices'][key]['installed'] = True
    write(OUT / 'ownership.json', ownership)

after = inventory('simulators-after')
after_devices = flattened(after)
for item in ownership['devices'].values():
    matches = [device for device in after_devices if device['udid'] == item['udid']]
    if len(matches) != 1 or matches[0]['name'] != item['name'] or matches[0]['state'] != 'Booted':
        raise RuntimeError(f'post-provision identity mismatch: {item}')
protected_after = {item['udid']: {key: item.get(key) for key in stable_protected_keys} for item in after_devices if item['udid'] in PROTECTED}
write(OUT / 'protected-after.json', protected_after)
if protected_after != protected_before:
    raise RuntimeError('protected simulator inventory changed')
ownership['status'] = 'paused-booted-ready-for-binding'
ownership['completedEpoch'] = time.time()
write(OUT / 'ownership.json', ownership)
write(OUT / 'acceptance.json', {'passed': True, 'fixtureOnly': True, 'candidateRuntimeGrade': False, 'ownershipSHA256': hashlib.sha256((OUT / 'ownership.json').read_bytes()).hexdigest(), 'protectedUnchanged': True, 'devices': ownership['devices']})
