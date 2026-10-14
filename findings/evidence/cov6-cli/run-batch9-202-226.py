from pathlib import Path
import subprocess,json,shutil,os
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');cli='/Users/kyle/.grantiva-qa/bin/grantiva';client=ev/'mcp-call-client.py';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch9';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,q.returncode)
queries={'B-C03.3':'loadActiveSession|another project|projectDirectory','B-C04.3':'reportDir|timeoutSeconds|failFast','B-C04.4':'supplied report|reportDir|RunnerSessionCleanup','B-C05.2':'executablePath|CommandLine.arguments|Process','B-C05.3':'captureCommand|compareCommand|approveCommand|executable','B-C06.3':'ContextToolTests|session.*udid|booted','B-C07.4':'extendedWaitUntil|waitForAnimationToEnd|unsupported Maestro','B-C08.3':'tapOn.*id|id selector|Selector.id','B-C09.3':'3000|sleep|waitForAnimationToEnd','B-C10.3':'setPermissions|direction.*DOWN|bare scroll','B-C11.4':'MCPServerTests|tools/list|grantiva_tap','B-C12.2':'DoctorSelectionTests|invalid.*platform|both.*config','B-C12.3':'InitAndroidTests|application-id|--scheme','B-C13.2':'standardOutput|recordVideo','B-C13.3':'OutputStreamContractTests|not_running|stdout','B-C13.4':'recordVideo|standardOutput'}
for row,q in queries.items():run(row,'source-inspection',src,['rg','-n','-i',q,'Sources','Tests'])
run('B-C03.4','docs',src,['sed','-n','148,165p','docs/android.md'])
run('B-C07.2','docs',src,['sed','-n','176,187p','README.md'])
run('B-C11.5','docs',src,['/bin/bash','-c',f"{cli} mcp --help; sed -n '148,165p' docs/android.md"])
# C05 own executable despite PATH stub
p=base/'c05';p.mkdir();(p/'grantiva.yml').write_text('scheme: Landmarks\nscreens:\n  - name: Home\n    path: launch\n');stub=base/'stub';stub.mkdir();marker=base/'stub-invoked';(stub/'grantiva').write_text('#!/bin/sh\necho invoked >> '+str(marker)+'\nexit 97\n');(stub/'grantiva').chmod(0o755)
run('B-C05.1','vrt-compare',p,['/usr/bin/env',f'PATH={stub}:/usr/bin:/bin:/usr/sbin:/sbin','python3',str(client),str(ev/'B-C05.1-run-1/vrt.transcript.json'),str(p),'ios','grantiva_vrt_compare','{}'])
(ev/'B-C05.1-run-1'/'stub-marker-state.txt').write_text('absent\n' if not marker.exists() else marker.read_text())
# C07 exact rejected command at line4
p=base/'c07';p.mkdir();(p/'grantiva.yml').write_text('appId: com.example\n---\n- launchApp\n- back\n');run('B-C07.3','reject',p,[cli,'diff','capture','--no-build','--simulator','00000000-0000-0000-0000-000000000527'])
# C11 two empty servers initialize/list
p=base/'empty';p.mkdir();
for plat in ('ios','android'):run('B-C11.1',plat,p,['python3',str(ev/'mcp-devicefree-client.py'),str(ev/'B-C11.1-run-1'/f'{plat}.transcript.json'),str(p),'--platform',plat])
# C12 public selection/validation
p=base/'both';p.mkdir();(p/'grantiva.yml').write_text('screens: []\n');(p/'grantiva-android.yml').write_text('screens: []\n')
for label,args,env in [('doctor-both',['doctor'],[]),('doctor-env-windows',['doctor'],['GRANTIVA_PLATFORM=windows']),('run-env-windows',['run','--no-build'],['GRANTIVA_PLATFORM=windows'])]:run('B-C12.1',label,p,['/usr/bin/env',*env,cli,*args])
for label,args in [('init-android-scheme',['init','--platform','android','--scheme','X']),('init-ios-appid',['init','--platform','ios','--application-id','x'])]:
 q=base/label;q.mkdir();run('B-C12.1',label,q,[cli,*args]);(ev/'B-C12.1-run-1'/f'{label}-files.txt').write_text('\n'.join(x.name for x in q.iterdir())+'\n')
# C14 parser validation, explicit absent target supplied but must not reach it
p=base/'c14';p.mkdir();
run('B-C14.1','bad-frames',p,[cli,'record','--duration','1','--frames-at','a,b','--simulator','00000000-0000-0000-0000-000000000527'])
run('B-C14.1','extensionless',p,[cli,'record','--duration','1','--output',str(p/'video'),'--simulator','00000000-0000-0000-0000-000000000527'])
