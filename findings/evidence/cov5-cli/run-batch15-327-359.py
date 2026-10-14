from pathlib import Path
import subprocess,json,base64,shutil
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch15';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);p=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,p.returncode)
empty=base/'empty';empty.mkdir()
for t in ['grantiva_vrt_capture','grantiva_vrt_compare','grantiva_vrt_approve']:run('B2-K59',t,root,['python3',str(ev/'mcp-call-client.py'),str(ev/f'B2-K59-run-1/{t}.json'),str(empty),'ios',t,'{}'])
p=base/'k60';p.mkdir();marker=p/'pwned';(p/'grantiva.yml').write_text('platform: ios\nscheme: X\nbundle_id: x\nscreens: []\n')
run('B2-K60','metachar',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B2-K60-run-1/result.json'),str(p),'ios','grantiva_vrt_approve',json.dumps({'screens':[f'Home; touch {marker}']})]);run('B2-K60','marker',p,['/bin/bash','-c',f'test ! -e {marker}'])
for c in [('runner',[cli,'runner','--help']),('start',[cli,'runner','start','--help']),('dump',[cli,'runner','dump-hierarchy','--help']),('hierarchy',[cli,'hierarchy','--help']),('run',[cli,'run','--help']),('install',[cli,'build','install','--help']),('capture',[cli,'diff','capture','--help']),('ci',[cli,'ci','run','--help'])]:run('B2-K61',c[0],src,c[1])
for row,q in [('B2-K62','status == "fail"|status == "error"|ok.*warning.*error'),('B2-K63','runner version>/|versions/<stamp>|android-drivers'),('B2-K64','1\\.6\\.[0-9]|SIMULATOR-LIFECYCLE'),('B2-K65','26\\.0|26\\.2|26\\.4|27\\.0|wda-builds'),('B2-K66','From source|GrantivaCore.bundle|cp -R'),('B2-K107-b','TestHygiene|fresh.*home|leaseDirectory|runnerHome')]:run(row,'docs-source',src,['rg','-n',q,'README.md','docs','Sources','Tests','.github'])
run('B2-K63','version-dir',root,['/bin/bash','-c','/Users/kyle/.grantiva-qa/bin/grantiva runner version; find /private/tmp/grantiva-cov5-cli-gtwQZB/runner-home/versions -maxdepth 1 -mindepth 1 -type d -print'])
run('B2-K65','wda-cache',root,['find','/private/tmp/grantiva-cov5-cli-gtwQZB/runner-home/cache/wda-builds','-maxdepth','1','-mindepth','1','-print'])
for filt in ['booted','all'] : run('B2-K96',filt,root,['python3',str(ev/'mcp-call-client.py'),str(ev/f'B2-K96-run-1/{filt}.json'),str(empty),'ios','grantiva_sim_list',json.dumps({'filter':filt})])
run('B2-K100.1','resources',root,['python3',str(ev/'mcp-sequence-client.py'),str(ev/'B2-K100.1-run-1/result.json'),str(empty),'ios','resources'])
run('B2-K101','malformed',root,['python3',str(ev/'mcp-sequence-client.py'),str(ev/'B2-K101-run-1/result.json'),str(empty),'ios','malformed'])
for lab,args in [('group-json',[cli,'runner','--json']),('status',[cli,'runner','status']),('version',[cli,'runner','version']),('version-json',[cli,'runner','version','--json']),('help',[cli,'runner','--help'])]:run('N2-02',lab,src,args)
# N2-10 joins init and fresh schemas/source
run('N2-10','schemas',root,['python3',str(ev/'mcp-devicefree-client.py'),str(ev/'N2-10-run-1/tools.json'),str(empty),'ios'])
run('N2-10','source',src,['rg','-n','iPhone 1[0-9]|DefaultSimulator|timeout.*5|5.*timeout','Sources','Tests'])
# negative MCP calls
for t,a in [('grantiva_sim_boot',{'name':'no-such-sim'}),('grantiva_sim_delete',{'name':'no-such-sim'}),('grantiva_sim_ensure',{}),('grantiva_emulator_boot',{'name':'no-such-avd'}),('grantiva_emulator_delete',{'name':'no-such-avd'}),('grantiva_emulator_ensure',{}),('grantiva_script',{}),('grantiva_swipe',{}),('grantiva_type',{})]:run('N2-19',t,root,['python3',str(ev/'mcp-call-client.py'),str(ev/f'N2-19-run-1/{t}.json'),str(empty),'ios',t,json.dumps(a)])
run('N2-20','source',src,['rg','-n','malformed|mdia|hdlr|extra track|MP4LastFrameHold','Sources/GrantivaCore/Record','Tests/GrantivaCoreTests'])
# duplicate current candidate checks
run('D2-15','json-current',root,[cli,'runner','install','--json'])
run('D2-16','doctor-json',empty,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',cli,'doctor','--json'])
run('D2-17','aliases',src,['rg','-n','LegacyJSONKeys|platformTwins|snake_case|camelCase','README.md','Sources'])
for cmd in [['build','install'],['ci','run'],['diff','capture'],['diff','compare'],['run'],['emulator','ensure']]:run('D2-27','-'.join(cmd),src,[cli,*cmd,'--help'])
run('D2-32','wda-cache',root,['find','/private/tmp/grantiva-cov5-cli-gtwQZB/runner-home/cache/wda-builds','-maxdepth','1','-mindepth','1','-print'])
