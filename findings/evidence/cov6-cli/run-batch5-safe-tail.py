from pathlib import Path
import subprocess,shutil,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');E=root/'findings/evidence/cov6-cli';cap=E/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path('/private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-scratch/batch5-safe');s.mkdir(parents=True,exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2')
def new(n,src=None):
 p=s/n
 if not p.exists(): shutil.copytree(src,p) if src else p.mkdir()
 return p
def run(row,label,cwd,argv,t='180'):
 d=E/f'{row}-run-2';d.mkdir(exist_ok=True);return subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout',t,'--',*argv],cwd=root).returncode
# relocation install with current artifact, not preserved interrupted old-candidate attempt
p=new('142');shutil.copy2(b,p/'grantiva');manifest=json.load(open('/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-candidate5/candidate.json'));shutil.copytree(manifest['cli']['bundle']['path'],p/'grantiva_GrantivaCore.bundle');run('CLI-142','install-current',p,[str(p/'grantiva'),'runner','install'],'300')
ios=new('ios',demo/'ios');android=new('android',demo/'android');empty=new('empty')
run('CLI-101','duration-cap',android,[b,'record','--platform','android','--duration','200'])
run('CLI-102','frames',ios,[b,'record','--duration','2','--frames-at','a,b'])
run('CLI-103','required',ios,[b,'record']);run('CLI-143','zero',ios,[b,'record','--duration','0'])
for label,args,cwd in [('ios-emulator',['--duration','2','--emulator','X'],ios),('ios-device',['--duration','2','--device','X'],ios),('android-simulator',['--platform','android','--duration','2','--simulator','X'],android),('android-mutual',['--platform','android','--duration','2','--device','a','--emulator','b'],android)]:run('CLI-145',label,cwd,[b,'record',*args])
run('CLI-104','missing-selector',empty,[b,'emulator','teardown']);run('CLI-147','mutual',empty,[b,'emulator','teardown','--serial','emulator-5598','--all']);run('CLI-147','ios-uuid',empty,[b,'emulator','teardown','--serial','00000000-0000-0000-0000-000000000527'])
run('CLI-149','emulator-missing',empty,[b,'emulator','delete']);run('CLI-149','simulator-missing',empty,[b,'simulator','delete'])
diff=new('diff');run('CLI-106','approve',diff,[b,'diff','approve']);run('CLI-106','compare',diff,[b,'diff','compare'])
p=new('150');(p/'.grantiva/captures').mkdir(parents=True);(p/'.grantiva/captures/Home.png').write_bytes(b'fake');run('CLI-150','approve',p,[b,'diff','approve','NoSuchScreen'])
p=new('151');(p/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: 00000000-0000-0000-0000-000000000527\n');run('CLI-151','capture',p,[b,'diff','capture','--no-build'])
run('CLI-107','wrong-platform-flag',android,[b,'build','build','--platform','android','--derived-data-path','x'])
