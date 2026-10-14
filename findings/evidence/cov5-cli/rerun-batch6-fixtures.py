from pathlib import Path
import subprocess,shutil,zipfile
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';cli='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch6-fixtures'; frozen=Path('/private/tmp/grantiva-round4-candidate3-demo.9jkg9hna/Build/Products/UITesting-iphonesimulator/Landmarks.app')
def run(row,label,cwd,args):
 d=ev/row;d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*args],cwd=root);print(row,label,q.returncode)
# CLI153 resolve init's multiple-scheme warning and keep its guarded default simulator line
p=s/'153'; t=(p/'grantiva.yml').read_text(); (p/'grantiva.yml').write_text(t.replace('# scheme: MyApp','scheme: Landmarks') if '# scheme: MyApp' in t else t.replace('scheme:','scheme: Landmarks #'))
run('CLI-153-run-2','ci-run',p,[cli,'ci','run'])
# CLI155 exact full Maestro example
p=s/'155';(p/'grantiva.yml').write_text('''appId: com.example.myapp\n---\n- launchApp\n- tapOn: "Sign In"\n- inputText: "user@example.com"\n- takeScreenshot: "Login"\n- tapOn: "Submit"\n- assertVisible: "Welcome"\n- takeScreenshot: "Welcome"\n''');run('CLI-155-run-2','capture',p,[cli,'diff','capture','--no-build','--simulator','00000000-0000-0000-0000-000000000527'])
# CLI156 create real frozen app fixtures and ipa archive
p=s/'156';
for rel in ['build/MyApp.app','app/MyApp.app']:
 dst=p/rel; dst.parent.mkdir(exist_ok=True); shutil.copytree(frozen,dst,dirs_exist_ok=True)
payload=p/'ipa-stage/Payload/MyApp.app';payload.parent.mkdir(parents=True,exist_ok=True);shutil.copytree(frozen,payload,dirs_exist_ok=True);(p/'artifacts').mkdir(exist_ok=True)
with zipfile.ZipFile(p/'artifacts/MyApp.ipa','w') as z:
 for x in (p/'ipa-stage').rglob('*'):
  if x.is_file(): z.write(x,x.relative_to(p/'ipa-stage'))
for n,args in [('app',['ci','run','--app-file','./build/MyApp.app']),('ipa',['ci','run','--app-file','./artifacts/MyApp.ipa']),('no-build',['ci','run','--no-build']),('artifact',['ci','run','--app-file','./app/MyApp.app'])]:run('CLI-156-run-2',n,p,[cli,*args])
