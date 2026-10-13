from pathlib import Path
import os,json,subprocess,time
r=Path(__file__).parent;s=json.loads((r/'state-fix3.json').read_text());i=json.loads((r/'ios-state.json').read_text());d=r/'ios-install-attempt1';d.mkdir();binary=s['binary'];udid=i['udid'];project=Path(i['project']);app=i['app'];bundle='com.kylebrowning.Landmarks';checks=[]
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
def cmd(label,args,expected=0):
 t=time.monotonic();(d/(label+'.command.json')).write_text(json.dumps(args)+'\n');p=subprocess.run(args,cwd=project,capture_output=True,timeout=120);(d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.result.json')).write_text(json.dumps({'exit':p.returncode,'duration':time.monotonic()-t})+'\n')
 if expected is not None:assert p.returncode==expected,(label,p.returncode,p.stderr.decode())
 return p
base=[binary,'build','install','--platform','ios','--simulator',udid,'--no-build']
absent=cmd('absent-before',['/usr/bin/xcrun','simctl','get_app_container',udid,bundle,'app'],None);assert absent.returncode!=0
plain=cmd('absent-plain',base+['--no-launch']);assert b'(install skipped, not launched)' in plain.stdout
j=json.loads(cmd('absent-json',base+['--no-launch','--json']).stdout);assert j['status']=='skipped' and j['appPath'] is None and j['dataContainer'] is None,j
assert cmd('absent-after',['/usr/bin/xcrun','simctl','get_app_container',udid,bundle,'app'],None).returncode!=0
refusal=cmd('absent-launch-refusal',base,1);assert b'not installed' in refusal.stderr
checks.append({'L71 absent':'plain and JSON skipped, null optional paths, still absent; launch refused','json':j})
installed=json.loads(cmd('appfile-no-launch',base+['--app-file',app,'--no-launch','--json']).stdout);assert installed['status']=='installed' and installed['appPath']==app,installed
before=cmd('installed-container-before',['/usr/bin/xcrun','simctl','get_app_container',udid,bundle,'data']).stdout
plain=cmd('installed-skipped-plain',base+['--no-launch']);assert b'(install skipped, not launched)' in plain.stdout
j=json.loads(cmd('installed-skipped-json',base+['--no-launch','--json']).stdout);assert j['status']=='skipped' and j['dataContainer']==before.decode().strip(),j
assert cmd('installed-container-after',['/usr/bin/xcrun','simctl','get_app_container',udid,bundle,'data']).stdout==before
checks.append({'D2-08':'app-file installed exact appPath; installed skipped retains container','installed':installed,'skipped':j})
launched=json.loads(cmd('installed-launch',base+['--json']).stdout);assert launched['status']=='launched',launched
checks.append({'launch control':launched})
(d/'checks.json').write_text(json.dumps(checks,indent=2)+'\n');print(json.dumps(checks,indent=2))
