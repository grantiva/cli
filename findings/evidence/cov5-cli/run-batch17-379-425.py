from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4');runner=Path('/Users/kyle/Developer/maestro-runner/.worktrees/package-round4-repair');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch17';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);p=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,p.returncode)
for row in ['B4-L53.E','B4-L53.F','B4-L53.P1','B4-L53.P2','B4-L53.P3','B4-L53.P4','B4-L53.P5']:
 run(row,'source',src,['rg','-n','must not be empty|TargetFlags|SimulatorUDID|RunnerInvocation|serial|udid','Sources','Tests'])
for row in ['B4-L67.1','B4-L67.2','B4-L67.3','B4-L67.4']:
 run(row,'source',src,['rg','-n','ambiguous|Advisory|Platform|platform ios|platform android','Sources/GrantivaCore/Doctor','Tests/GrantivaCoreTests','Tests/GrantivaCLITests'])
for row in ['B4-L70.1','B4-L70.2','B4-L70.3']:
 run(row,'docs-source',src,['rg','-n','percent-encoded|literal filename|legacy baseline|migrat|baseline.*filename','README.md','docs','Sources','Tests'])
for row in ['B4-L74.1','B4-L74.2','B4-L74.3','B4-L74.4']:
 run(row,'docs-source',src,['rg','-n','ISO-8601|ISO 8601|iso8601|acquiredAt|1970-01-01','README.md','docs','Sources','Tests'])
# L75 exact parse-time cycles, no target action
p=base/'l75';(p/'flows').mkdir(parents=True);(p/'shared').mkdir();(p/'flows/a.yaml').write_text('appId: x\n---\n- runFlow: ../shared/b.yaml\n');(p/'shared/b.yaml').write_text('appId: x\n---\n- runFlow: ../flows/a.yaml\n')
for row in ['B4-L75.1','B4-L75.3','B4-L75.5']:run(row,'nested-cycle',p,[cli,'run','--no-build','--flow','flows/a.yaml'])
q=base/'l75-root';q.mkdir();(q/'a.yaml').write_text('appId: x\n---\n- runFlow: b.yaml\n');(q/'b.yaml').write_text('appId: x\n---\n- runFlow: a.yaml\n')
run('B4-L75.2','root-cycle',q,[cli,'run','--no-build','--flow','a.yaml'])
for row in ['B4-L75.4','B4-L75.5']:run(row,'source',src,['rg','-n','reachableFlowDisplayMap|private/tmp|RunnerSessionOutputTests|circular dependency','Sources','Tests'])
for row in ['B4-L81.1','B4-L81.2','B4-L81.3','B4-L81.4','B4-L81.5','B4-L81.6','B4-L81.7']:
 run(row,'source',src,['rg','-n','checkBootedSimulator|was not created by Grantiva|Could not list simulators|Booted Simulator','Sources','Tests'])
for row in ['B4-L82.1','B4-L82.2','B4-L82.5']:
 run(row,'source',src,['rg','-n','attachment|detach|foreground|SIGINT|exit.*130|forward','Sources','Tests'])
for row in ['B4-L83.1','B4-L83.2','B4-L83.4']:
 run(row,'runner-source',runner,['rg','-n','forward|allocated.*port|remove.*forward|DeviceLab|UIAutomator2','pkg'])
for row in ['B4-L84.1','B4-L84.2','B4-L84.4']:
 run(row,'source',src,['rg','-n','orphan|forward|owned.*port|remove.*forward|cleanup','Sources','Tests'])
for row in ['B4-L85.2','B4-L85.3']:
 run(row,'source',src,['rg','-n','back button|navigation.*back|placeholder|application-root|quoted|selector','Sources','Tests'])
for row in ['B4-PC.9','B4-PC.10','B4-PC.11','B4-PC.12','B4-PC.13']:
 run(row,'runner-source',runner,['rg','-n','deadline|cancel|stable|Rect|long press|force-stop|foreground|stepScope','pkg'])
