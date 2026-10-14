from pathlib import Path
import json,subprocess,shutil
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch14';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv,timeout='120'):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);p=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout',timeout,'--',*argv],cwd=root);print(row,label,p.returncode)
# K35/K37/K38 source and current-candidate joins
run('B2-K35','source',src,['rg','-n','Toolchain.*optional|Advisory|Booted Simulator|runAllChecks','Sources','Tests/GrantivaCoreTests','Tests/GrantivaCLITests'])
run('B2-K37.1','source',src,['rg','-n','iPhone 1[0-9]|defaultSimulator|Grantiva iPhone|shared default','Sources','Tests'])
run('B2-K38','source',src,['rg','-n','Several schemes found|one shared scheme|scheme detection|iosTemplate','Sources','Tests'])
# K39
p=base/'k39';p.mkdir();(p/'grantiva.yml').write_text('platform: ios\nscheme: X\nbundle_id: x\n')
run('B2-K39','report-ready',p,[cli,'run','--report-dir','out','--ready-file','out.ready'])
run('B2-K39','timeout-ready',p,[cli,'run','--timeout','5','--ready-file','out2.ready'])
run('B2-K39','ready-files',p,['/bin/bash','-c','for f in out.ready out2.ready; do echo ===$f; cat "$f"; done; find . -maxdepth 2 -type d -print | sort'])
# parser rows
for lab,args in [('snapshot',[cli,'run','--snapshot','bogus']),('hierarchy',[cli,'hierarchy','--format','bogus']),('platform',[cli,'run','--platform','bogus'])]: run('B2-K40',lab,base,args)
for lab,args in [('space',[cli,'run','--timeout','-1']),('equals',[cli,'run','--timeout=-1']),('ready',[cli,'run','--timeout','5','--ready-file',str(base/'bad.ready')]),('hierarchy',[cli,'hierarchy','--timeout','-1']),('record',[cli,'record','--duration','-1'])]: run('B2-K41',lab,base,args)
for lab,args in [('empty-udid',[cli,'simulator','teardown','--udid','','--force']),('bad-udid',[cli,'simulator','teardown','--udid','not-a-udid-at-all','--force']),('empty-session',[cli,'simulator','teardown','--session-id','']),('both',[cli,'simulator','teardown','--udid','00000000-0000-0000-0000-000000000527','--session-id','x']),('hierarchy',[cli,'hierarchy','--udid','']),('dump',[cli,'runner','dump-hierarchy','--udid',''])]: run('B2-K42',lab,base,args)
# K43 exact platform fixtures
ios=base/'k43-ios';ios.mkdir();(ios/'App.xcodeproj').mkdir();android=base/'k43-android';android.mkdir();(android/'settings.gradle.kts').write_text('')
for lab,cwd,args in [('ios-build',ios,[cli,'build','build','--variant','x']),('ios-runner',ios,[cli,'runner','start','--application-id','a.b']),('ios-record',ios,[cli,'record','--duration','1','--emulator','x']),('android-capture',android,[cli,'diff','capture','--scheme','X']),('android-runner',android,[cli,'runner','start','--simulator','X']),('android-record',android,[cli,'record','--duration','1','--simulator','X'])]:run('B2-K43',lab,cwd,args)
run('B2-K43','source',src,['rg','-n','option, but this is an|otherPlatformFlagError','Sources/GrantivaCLI','Tests/GrantivaCLITests'])
# K45 isolated runner home
home=base/'k45-home'
for lab in ['first','second']:run('B2-K45',lab,base,['/usr/bin/env',f'GRANTIVA_RUNNER_HOME={home}',f'MAESTRO_RUNNER_HOME={home}','GRANTIVA_SESSION_ID=cov5-cli-k45',cli,'runner','install'])
# K46/K47
for lab,args in [('dump',[cli,'runner','dump-hierarchy']),('hierarchy',[cli,'hierarchy'])]:run('B2-K46',lab,base,args)
run('B2-K46','mcp',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B2-K46-run-1/mcp.json'),str(base),'ios','grantiva_screenshot','{}'])
for lab,args in [('bogus',[cli,'runner','dump-hierarchy','--format','bogus']),('xml-case',[cli,'runner','dump-hierarchy','--format','XML']),('tree-json',[cli,'runner','dump-hierarchy','--json','--format','tree'])]:run('B2-K47',lab,base,args)
# K49
p=base/'k49';p.mkdir();(p/'grantiva.yml').write_text('platform: ios\nscheme: X\nbundle_id: x\nscreens:\n  - name: Home\n    path: []\n'); capdir=p/'.grantiva/captures';capdir.mkdir(parents=True);(capdir/'Home.png').write_bytes(b'unchanged-home')
run('B2-K49','before',p,['shasum','-a','256','.grantiva/captures/Home.png']);run('B2-K49','cli',p,[cli,'diff','approve','NoSuchScreen']);run('B2-K49','mcp',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B2-K49-run-1/mcp.json'),str(p),'ios','grantiva_vrt_approve','{"screens":["NoSuchScreen"]}']);run('B2-K49','after',p,['/bin/bash','-c','shasum -a 256 .grantiva/captures/Home.png; find .grantiva -type f -print | sort'])
# K50
for lab,args in [('help',[cli,'console','releases','update','--help']),('version',[cli,'console','releases','update','--version']),('release-version',[cli,'console','releases','update','NOTE-ID','--release-version','2.2.0'])]:run('B2-K50',lab,base,args)
# K51
p=base/'k51';p.mkdir()
for lab,args in [('compare-ios',[cli,'diff','compare','--platform','ios']),('compare-android',[cli,'diff','compare','--platform','android']),('approve',[cli,'diff','approve','--platform','ios'])]:run('B2-K51',lab,p,args)
run('B2-K51','find',p,['/bin/bash','-c','find .grantiva -print 2>&1 || true'])
# K52
p=base/'k52';p.mkdir();(p/'App.xcodeproj').mkdir()
for lab,args in [('run',[cli,'run']),('run-no-build',[cli,'run','--no-build']),('capture',[cli,'diff','capture'])]:run('B2-K52',lab,p,args)
q=base/'k52-maestro';q.mkdir();(q/'.maestro').mkdir()
for lab,args in [('run-empty-maestro',[cli,'run']),('capture-empty-maestro',[cli,'diff','capture'])]:run('B2-K52',lab,q,args)
# K58 context: Android-only and iOS Maestro-only
a=base/'k58-android';a.mkdir();(a/'settings.gradle.kts').write_text('');(a/'.maestro').mkdir();(a/'.maestro/f.yaml').write_text('appId: com.android.only\n---\n- launchApp\n')
i=base/'k58-ios';i.mkdir();(i/'.maestro').mkdir();(i/'.maestro/f.yaml').write_text('appId: com.ios.only\n---\n- launchApp\n')
run('B2-K58','android-as-ios',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B2-K58-run-1/android.json'),str(a),'ios','grantiva_context','{}'])
run('B2-K58','ios-maestro',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B2-K58-run-1/ios.json'),str(i),'ios','grantiva_context','{}'])
run('B2-K58','source',src,['rg','-n','source:.*maestro|no grantiva.yml|maestro.*source','Sources','Tests'])
