import os,json,subprocess,time
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5');checks={}
def cmd(args,stem):
 p=subprocess.run(args,cwd=s['project'],capture_output=True);(r/(stem+'.out')).write_bytes(p.stdout);(r/(stem+'.err')).write_bytes(p.stderr);assert p.returncode==0,(args,p.stderr);return p.stdout
before=json.loads(cmd(['xcrun','simctl','list','devices','--json'],'ios-cleanup-before-devices'));cmd(['ps','-axo','pid,ppid,command'],'ios-cleanup-before-processes')
cmd([s['binary'],'runner','stop','--json'],'ios-final-runner-stop');checks['runnerStopExit']=0
c=Client(s['binary'],s['project'],'ios',r/'ios-final-no-session')
try:
 q=c.tool('grantiva_script',{});assert q['result']['isError'] and c.text(q).startswith('Error: No active runner session at '),q;checks['finalNoSessionPrecedence']=True
finally:c.close()
cmd(['xcrun','simctl','shutdown',s['udid']],'ios-owned-shutdown');checks['shutdownExit']=0
cmd(['xcrun','simctl','delete',s['udid']],'ios-owned-delete');checks['deleteExit']=0
after=json.loads(cmd(['xcrun','simctl','list','devices','--json'],'ios-cleanup-after-devices'));cmd(['ps','-axo','pid,ppid,command'],'ios-cleanup-after-processes')
baseline=json.loads((r/'devices-before.txt').read_text());baseids={d['udid'] for ds in baseline['devices'].values() for d in ds};afterids={d['udid'] for ds in after['devices'].values() for d in ds};checks['ownedUDIDAbsent']=s['udid'] not in afterids;checks['allPreexistingSimulatorIDsPreserved']=baseids<=afterids
pids=[8270,16138,18867,21826];checks['runnerPIDsAbsent']={str(pid):subprocess.run(['ps','-p',str(pid)],capture_output=True).returncode!=0 for pid in pids};assert all(checks['runnerPIDsAbsent'].values());assert checks['ownedUDIDAbsent'] and checks['allPreexistingSimulatorIDsPreserved']
(r/'ios-cleanup.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks))
