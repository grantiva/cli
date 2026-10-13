from pathlib import Path
import os,json,subprocess,time,shutil,re
r=Path(__file__).parent;s=json.loads((r/'state-fix4.json').read_text());devices=[json.loads((r/x).read_text()) for x in ['ios-state.json','ios-control-state.json']];d=r/'ios-cleanup';d.mkdir();os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
def run(label,args,expected=0):
 p=subprocess.run(args,capture_output=True,timeout=120,cwd=devices[0]['project']);(d/(label+'.command.json')).write_text(json.dumps(args));(d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.exit')).write_text(str(p.returncode));assert p.returncode==expected,(label,p.returncode,p.stderr.decode());return p.stdout.decode()
# Retain referenced daemon logs before scratch cleanup.
logs=d/'daemon-logs';logs.mkdir()
for path in r.rglob('*.err'):
 for filename in re.findall(r'/[^\s]+grantiva-runner-[0-9]+\.log',path.read_text(errors='replace')):
  source=Path(filename)
  if source.exists() and not (logs/source.name).exists():shutil.copyfile(source,logs/source.name)
run('devices-before',['/usr/bin/xcrun','simctl','list','devices','-j'])
for device in devices:
 label=device['name'];udid=device['udid'];assert label.startswith('fix4-4-ios-');run(label+'-force',[s['binary'],'simulator','teardown','--udid',udid,'--force','--json']);assert not (Path(device['project'])/'.grantiva/session.json').exists();run(label+'-shutdown',['/usr/bin/xcrun','simctl','shutdown',udid]);run(label+'-delete',['/usr/bin/xcrun','simctl','delete',udid])
inventory=run('devices-after',['/usr/bin/xcrun','simctl','list','devices','-j']);ps=run('processes-after',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']);ownedIDs=[x['udid'] for x in devices];assert all(u not in inventory for u in ownedIDs);assert not any(u in line for u in ownedIDs for line in ps.splitlines());assert 'grantiva-log-' not in ps
shared=[]
for path in Path('/tmp/grantiva-sessions').glob('*'):
 if path.is_file():
  text=path.read_text(errors='replace')
  if any(u in text for u in ownedIDs) or s['scratch'] in text:shared.append(str(path))
(d/'owned-shared-files.json').write_text(json.dumps(shared));assert not shared,shared
before=json.loads((r/'ios-devices-before.json').read_text());after=json.loads(inventory)
for owner in ['B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6']:
 find=lambda data:next(x for xs in data['devices'].values() for x in xs if x['udid']==owner)
 assert find(before)['state']==find(after)['state']=='Booted'
(d/'checks.json').write_text(json.dumps({'ownedDevicesAbsent':ownedIDs,'ownedProcessesAbsent':True,'ownedSharedSessionFiles':shared,'ownerSimulatorStatesUnchanged':True,'runnerHome':s['runnerHome'],'scratchRetainedForEvidence':s['scratch']},indent=2));print('both owned iOS devices deleted; owned PIDs/logs/shared files absent; owner states unchanged')
