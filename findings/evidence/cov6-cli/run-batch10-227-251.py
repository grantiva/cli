from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch10';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,q.returncode)
queries={'B-C14.3':'frames-at|recordVideo|extensionless','B-C15.3':'diagonal|swipe.*Up|swipe direction','B-C16.1':'testUnknownWebhookEventsAreLeftToTheServer|testWebhookEventsIsNotASubcommand','B-C16.2':'webhook.*event|not.an.event','B-C16.3':'testUnknownWebhookEventsAreLeftToTheServer|testWebhookEventsIsNotASubcommand','B-C17.2':'ScriptToolsTests|bogus|isError','B-C18.2':'grantiva-android.yml not found|No screens or flows configured','B-C19.3':'unknown key|did you mean|lineNumber','B-C20.3':'could not be parsed|5:3|malformed','B-C21.3':'Run: grantiva|command tree|subcommand path','B-C22.3':'1970-01-01T00:00:00Z|JSONOutputTests','B-C23.2':'ANDROID_HOME=/nonexistent|AndroidSDKTests|valid home SDK','B-C24.3':'placeholder warning|No Xcode project found|pass --scheme'}
for row,q in queries.items():run(row,'source-inspection',src,['rg','-n','-i',q,'Sources','Tests'])
run('B-C14.5','help',src,[cli,'record','--help'])
# invalid swipe config
p=base/'c15';p.mkdir();(p/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: 00000000-0000-0000-0000-000000000527\nscreens:\n  - name: Diag\n    path:\n      - swipe: diagonal\n');run('B-C15.1','capture',p,[cli,'diff','capture','--no-build'])
# C16 corrected public no-subcommand behavior and source tests for server validation
run('B-C16.1','events-help',src,[cli,'console','webhooks','events','--help']);run('B-C16.4','webhooks-help',src,[cli,'console','webhooks','--help'])
# C18 missing configs and empty configs
for plat,name in [('ios','ios-missing'),('android','android-missing')]:
 p=base/name;p.mkdir();run('B-C18.1',name,p,[cli,'run','--platform',plat,'--no-build'])
for plat,name,file in [('ios','ios-empty','grantiva.yml'),('android','android-empty','grantiva-android.yml')]:
 p=base/name;p.mkdir();(p/file).write_text('');run('B-C18.1',name,p,[cli,'run','--platform',plat,'--no-build'])
# C19 typo warnings; parser proceeds to missing scheme/device after warnings
p=base/'c19';p.mkdir();(p/'grantiva.yml').write_text('schem: Landmarks\nbundle_id: com.example\n\nscreen:\n  - name: Home\n    path: launch\n');run('B-C19.1','run',p,[cli,'run','--no-build','--simulator','00000000-0000-0000-0000-000000000527']);run('B-C19.1','doctor',p,[cli,'doctor'])
# C20 malformed at 5:3 for run and doctor
p=base/'c20';p.mkdir();(p/'grantiva.yml').write_text('scheme: Landmarks\nscreens:\n  - name: Home\n    path:\n  bad: [\n');run('B-C20.1','doctor',p,[cli,'doctor']);run('B-C20.2','run',p,[cli,'run','--no-build']);run('B-C20.2','doctor',p,[cli,'doctor'])
# C23 stale env with valid default SDK
p=base/'c23';p.mkdir();(p/'grantiva-android.yml').write_text('module: app\nscreens: []\n');run('B-C23.1','doctor-home',['/tmp'] if False else p,['/usr/bin/env','ANDROID_HOME=/nonexistent','ANDROID_SDK_ROOT=/nonexistent',cli,'doctor','--platform','android'])
# C24 init placeholder in empty directory
p=base/'c24';p.mkdir();run('B-C24.1','init',p,[cli,'init']);
# C25 isolated HOME
p=base/'c25';p.mkdir();home=p/'home';home.mkdir();run('B-C25.1','logout-text',p,['/usr/bin/env',f'HOME={home}',cli,'auth','logout']);run('B-C25.1','logout-json',p,['/usr/bin/env',f'HOME={home}',cli,'auth','logout','--json'])
