#!/usr/bin/env python3
import hashlib, json
from pathlib import Path

OUT = Path(__file__).resolve().parent
PROTECTED = ('B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C', 'FE441EE5-BBFC-4981-B68A-59C0DBCE26D6')
stable = ('udid', 'name', 'state', 'deviceTypeIdentifier', 'isAvailable', 'dataPath', 'logPath')
before_raw = json.loads((OUT / 'simulators-before.stdout').read_text())
after_raw = json.loads((OUT / 'simulators-after.stdout').read_text())
flatten = lambda doc: [item for items in doc['devices'].values() for item in items]
before = flatten(before_raw); after = flatten(after_raw)
project = lambda rows: {item['udid']: {key: item.get(key) for key in stable} for item in rows if item['udid'] in PROTECTED}
protected_before = project(before); protected_after = project(after)
if protected_before != protected_after or set(protected_before) != set(PROTECTED):
    raise RuntimeError('stable protected identity/state changed')
ownership = json.loads((OUT / 'ownership.json').read_text())
for item in ownership['devices'].values():
    matches = [device for device in after if device['udid'] == item['udid']]
    if len(matches) != 1 or matches[0]['name'] != item['name'] or matches[0]['state'] != 'Booted':
        raise RuntimeError(f'fixture identity mismatch: {item}')
    source = json.loads((OUT / 'frozen-app-verification.json').read_text())
    installed = Path(item['installedApp'])
    checks = []
    for expected in source['files']:
        path = installed / Path(expected['path']).name
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        checks.append({'path': str(path), 'expectedSHA256': expected['expectedSHA256'], 'actualSHA256': actual, 'matched': actual == expected['expectedSHA256']})
    if not all(check['matched'] for check in checks):
        raise RuntimeError(f'installed app mismatch: {item["udid"]}')
    item['installedFileChecks'] = checks
ownership['status'] = 'paused-booted-ready-for-binding'
(OUT / 'ownership.json').write_text(json.dumps(ownership, indent=2, sort_keys=True) + '\n')
record = {'passed': True, 'fixtureOnly': True, 'candidateRuntimeGrade': False, 'protectedStableIdentityAndStateUnchanged': True, 'devices': ownership['devices']}
record['ownershipSHA256'] = hashlib.sha256((OUT / 'ownership.json').read_bytes()).hexdigest()
(OUT / 'acceptance.json').write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
