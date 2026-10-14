from pathlib import Path
import subprocess,shutil,json,hashlib
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');cli='/Users/kyle/.grantiva-qa/bin/grantiva';demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2');scratch=Path((ev/'scratch-root.txt').read_text().strip())/'batch8';scratch.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,q.returncode)
# documentation/source behavior excerpts
run('B-A01.2','inspect',src,['sed','-n','55,70p','docs/android.md'])
run('B-A04.2','inspect',src,['sed','-n','140,155p','README.md'])
run('B-A08.2','inspect',src,['/bin/bash','-c',f"{cli} run --help; sed -n '84,100p' docs/android.md"])
# doctor from nested directory of actual worktree: .git file at worktree root
run('B-A12.1','doctor',demo/'android',[cli,'doctor','--platform','android'])
run('B-A12.2','doctor',demo/'android',[cli,'doctor','--platform','android'])
# missing bundle isolated copy, separate fresh runner home
p=scratch/'c01';p.mkdir();shutil.copy2(cli,p/'grantiva');home=scratch/'c01-home';home.mkdir();
run('B-C01.1','missing-bundle',p,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={home}',f'MAESTRO_RUNNER_HOME={home}',str(p/'grantiva'),'runner','install'])
