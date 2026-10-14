from pathlib import Path
import subprocess,json,shutil,os
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch16';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);p=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,p.returncode)
# L09 Android init, no device action
p=base/'l09';p.mkdir();(p/'settings.gradle.kts').write_text('rootProject.name="X"\n')
run('B3-L09','init',p,[cli,'init']);run('B3-L09','config',p,['cat','grantiva-android.yml'])
# L14 source contract (accepted current exact tree)
run('B3-L14.1','source',src,['rg','-n','notifications/cancelled|cancel.*unknown|cancelled.*request|no response','Tests/GrantivaMCPTests','Sources/GrantivaMCP'])
# L15 exact calls including unknown
empty=base/'empty';empty.mkdir()
for t in ['grantiva_sim_ensure','grantiva_emulator_ensure','grantiva_bogus_tool','grantiva_script','grantiva_swipe','grantiva_type']:
 run('B3-L15.1',t,root,['python3',str(ev/'mcp-call-client.py'),str(ev/f'B3-L15.1-run-1/{t}.json'),str(empty),'ios',t,'{}'])
# L16 capture fixture
p=base/'l16';p.mkdir();(p/'grantiva.yml').write_text('platform: ios\nscheme: X\nbundle_id: x\nscreens:\n  - name: Home\n    path: []\n');d=p/'.grantiva/captures';d.mkdir(parents=True);d.joinpath('Home.png').write_bytes(b'home')
for lab,args in [('three',[cli,'diff','approve','Missing1','Missing2','Missing3']),('mixed',[cli,'diff','approve','Home','Missing1']),('one',[cli,'diff','approve','Missing1'])]:run('B3-L16',lab,p,args)
run('B3-L16','mcp',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B3-L16-run-1/mcp.json'),str(p),'ios','grantiva_vrt_approve','{"screens":["Missing1","Missing2","Missing3"]}']);run('B3-L16','baseline-list',p,['/bin/bash','-c','find .grantiva/baselines -type f -print 2>/dev/null || true'])
# L17 exact project-dir context forced and auto
for lab,platform in [('forced','ios'),('auto','auto')]:
 argv=['python3',str(ev/'mcp-call-client.py'),str(ev/f'B3-L17-run-1/{lab}.json'),str(empty),platform,'grantiva_context','{}'];run('B3-L17',lab,root,argv)
# L25 source
run('B3-L25','source',src,['sed','-n','250,290p','Tests/GrantivaCoreTests/MP4LastFrameHoldTests.swift'])
# platform dirs and usage rows
ios=base/'ios';ios.mkdir();(ios/'App.xcodeproj').mkdir();android=base/'android';android.mkdir();(android/'settings.gradle.kts').write_text('')
for lab,cwd,args in [('ios-ext',ios,[cli,'record','--duration','2','--output','a.mp4']),('android-ext',android,[cli,'record','--duration','2','--output','a.mov']),('duration',ios,[cli,'record','--duration','0'])]:run('B3-L26-a',lab,cwd,args)
for lab,cwd,args in [('record',android,[cli,'record','--duration','2','--device','a','--emulator','b']),('run',empty,[cli,'run','--device','a','--emulator','b']),('capture',empty,[cli,'diff','capture','--device','a','--emulator','b']),('install',empty,[cli,'build','install','--device','a','--emulator','b']),('start',empty,[cli,'runner','start','--device','a','--emulator','b'])]:run('B3-L26-b',lab,cwd,args)
# L27/L28 isolated current install then binary-alone copy
l28=base/'l28';l28.mkdir();home=l28/'home';binp=l28/'bin';binp.mkdir();shutil.copy2(cli,binp/'grantiva')
run('B3-L28','seed-current',l28,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={home}',f'MAESTRO_RUNNER_HOME={home}',cli,'runner','install'])
for lab,args in [('copy-current',[str(binp/'grantiva'),'runner','install']),('copy-current-json',[str(binp/'grantiva'),'runner','install','--json'])]:run('B3-L28',lab,l28,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={home}',f'MAESTRO_RUNNER_HOME={home}',*args])
fresh=l28/'fresh';run('B3-L28','copy-fresh',l28,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={fresh}',f'MAESTRO_RUNNER_HOME={fresh}',str(binp/'grantiva'),'runner','install'])
# L27 relative/absolute paths using independent home
l27=base/'l27';l27.mkdir()
for lab,envhome,args in [('relative-first','rh',['runner','install']),('relative-second','rh',['runner','install']),('relative-json','rh',['runner','install','--json']),('absolute-version',str(l27/'rh'),['runner','version','--json'])]:run('B3-L27',lab,l27,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={envhome}',f'MAESTRO_RUNNER_HOME={envhome}',cli,*args])
# L29 docs/help; do not execute hidden accepted flags because that would compile
for lab,args in [('build',[cli,'build','build','--help']),('install',[cli,'build','install','--help']),('run',[cli,'run','--help']),('ci',[cli,'ci','run','--help']),('capture',[cli,'diff','capture','--help']),('compare',[cli,'diff','compare','--help']),('ensure',[cli,'emulator','ensure','--help'])]:run('B3-L29',lab,src,args)
run('B3-L29','docs-source',src,['rg','-n','headless|allow-device-settings|build build','docs/android.md','findings/help/build_build.txt','Tests'])
run('B3-L30','docs',src,['/bin/bash','-c','test ! -d docs/plans; rg -n "[0-9]+\\.[0-9]+\\.[0-9]+|Maestro" README.md docs/*.md || true; rg -n "docs/plans|lineage" Tests'])
run('B3-L31','ci-source',src,['rg','-n','fresh.*home|GRANTIVA_RUNNER_HOME|DefaultLockDirectory|mktemp',' .github/workflows/ci.yml','scripts','Tests'])
# malformed configs
for plat,cwd,name,device in [('ios',ios,'grantiva.yml','simulator: cov-missing'),('android',android,'grantiva-android.yml','emulator: cov-missing')]:
 q=base/f'l42-{plat}';q.mkdir();((q/'App.xcodeproj').mkdir() if plat=='ios' else (q/'settings.gradle.kts').write_text(''));(q/name).write_text(f'{device}\nscreens:\n  - name: Bad\n    path:\n      - tap: {{}}\n      - wait: soon\n')
 for cmd in [('run',[cli,'run','--no-build']),('capture',[cli,'diff','capture','--no-build'])]:run('B3-L42-b',f'{plat}-{cmd[0]}',q,cmd[1])
# L53 direct packaged runner and CLI empty flags
runner=next((home/'versions').glob('*/grantiva-runner'));flow=base/'flow.yaml';flow.write_text('appId: x\n---\n- launchApp\n')
for lab,flag in [('device','--device'),('udid','--udid'),('serial','--serial')]:run('B3-L53',lab,base,[str(runner),'--platform','ios',flag,'','test',str(flow)])
for lab,flag in [('cli-udid','--udid'),('cli-serial','--serial')]:run('B3-L53',lab,ios,[cli,'runner','start',flag,'','--verbose'])
# N3-08 joins usage plus teardown reference
for lab,cwd,args in [('ios-ext',ios,[cli,'record','--output','a.mp4']),('android-ext',android,[cli,'record','--output','a.mov']),('duration',ios,[cli,'record','--duration','0']),('mutual',empty,[cli,'record','--device','a','--emulator','b']),('teardown',empty,[cli,'emulator','teardown','--serial','emulator-9999','--all'])]:run('N3-08',lab,cwd,args)
# N3-11 same isolated copy/current home
for lab,args in [('install',['runner','install']),('version',['runner','version']),('start',['runner','start','--simulator','cov-missing']),('hierarchy',['hierarchy'])]:run('N3-11',lab,ios,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={home}',f'MAESTRO_RUNNER_HOME={home}',str(binp/'grantiva'),*args])
run('N3-15','doctor',src,[cli,'doctor']);run('N3-15','doctor-json',src,[cli,'doctor','--json'])
run('N3-16','docs-source',src,['rg','-n','GRANTIVA_DRIVER_START_TIMEOUT|starting|stop.json|Emulator reused|Variants of|trimmed=|Maestro','README.md','docs','findings/help'])
