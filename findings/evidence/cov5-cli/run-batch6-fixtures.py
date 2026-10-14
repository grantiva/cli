from pathlib import Path
import subprocess,shutil
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli'); ev=root/'findings/evidence/cov5-cli'; cap=ev/'capture-one.rb'; src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4'); demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2'); cli='/Users/kyle/.grantiva-qa/bin/grantiva'; s=Path((ev/'scratch-root.txt').read_text().strip())/'batch6-fixtures'; s.mkdir(exist_ok=True)
def caprun(row,label,cwd,argv):
 d=ev/row; d.mkdir(exist_ok=True); q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root); print(row,label,q.returncode)
def cp(srcp,dst):
 if dst.exists(): shutil.rmtree(dst)
 shutil.copytree(srcp,dst,ignore=shutil.ignore_patterns('.git','grantiva.yml','grantiva-android.yml','.grantiva'))
# 153
p=s/'153'; cp(demo/'ios',p)
caprun('CLI-153-run-1','doctor',p,[cli,'doctor']); caprun('CLI-153-run-1','init',p,[cli,'init']); caprun('CLI-153-run-1','runner-install',p,[cli,'runner','install']); caprun('CLI-153-run-1','ci-run',p,[cli,'ci','run'])
# 154 exact example without inline explanatory comment
p=s/'154'; cp(demo/'ios',p); (p/'grantiva.yml').write_text('''scheme: MyApp\nsimulator: iPhone 17 Pro\nbundle_id: com.example.myapp\n\nscreens:\n  - name: Home\n    path: launch\n  - name: Settings\n    path:\n      - tap: "Profile"\n      - tap: "Settings"\n\ndiff:\n  threshold: 0.02\n  perceptual_threshold: 5.0\n'''); caprun('CLI-154-run-1','doctor',p,[cli,'doctor'])
# 155 Maestro config; explicit absent UUID prevents device fallback
p=s/'155'; cp(demo/'ios',p); (p/'grantiva.yml').write_text('''appId: com.example.myapp\n---\n- launchApp\n- tapOn: "Sign In"\n- inputText: "user@example.com"\n'''); caprun('CLI-155-run-1','capture',p,[cli,'diff','capture','--no-build','--simulator','00000000-0000-0000-0000-000000000527'])
# 156 config and frozen app path; auth unset, commands stop at auth
p=s/'156'; cp(demo/'ios',p); shutil.copy(demo/'ios'/'grantiva.yml',p/'grantiva.yml') if (demo/'ios'/'grantiva.yml').exists() else (p/'grantiva.yml').write_text('scheme: Landmarks\nscreens: []\n')
for n,args in [('app',['ci','run','--app-file','./build/MyApp.app']),('ipa',['ci','run','--app-file','./artifacts/MyApp.ipa']),('no-build',['ci','run','--no-build']),('artifact',['ci','run','--app-file','./app/MyApp.app'])]: caprun('CLI-156-run-1',n,p,[cli,*args])
# 159 Gradle copy
p=s/'159'; cp(demo/'android',p); caprun('CLI-159-run-1','init',p,[cli,'init','--platform','android']); caprun('CLI-159-run-1','doctor',p,[cli,'doctor'])
# 109 exact run example + no-build safety, explicit absent UUID
p=s/'109'; cp(demo/'ios',p); (p/'grantiva.yml').write_text('scheme: Landmarks\nbundle_id: com.example.Landmarks\nflows: [flows/login.yaml]\n'); (p/'flows').mkdir(); (p/'flows/login.yaml').write_text('appId: com.example.Landmarks\n---\n- launchApp\n'); caprun('CLI-109-run-1','run',p,[cli,'run','--simulator','00000000-0000-0000-0000-000000000527','--flow','flows/login.yaml','--no-build'])
# 111 complete listed leaf help corpus
leaves=['run','record','hierarchy','build build','build install','ci run','diff capture','diff compare','diff approve','simulator ensure','simulator delete','simulator sessions','simulator teardown','simulator cleanup','emulator ensure','emulator delete','emulator sessions','emulator teardown','console','auth login','auth status','auth logout','doctor','runner install','runner version','runner start','runner stop','runner dump-hierarchy','mcp','init']
script='sed -n "337,370p" README.md; '+ '; '.join(f'{cli} {x} --help' for x in leaves)
caprun('CLI-111-run-2','all-help',src,['/bin/bash','-c',script])
