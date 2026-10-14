from pathlib import Path
import subprocess,json,hashlib
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5')
queries={
'B-A01.4':'FlowEnvironmentTests|arguments:|launchApp','B-A02.3':'swipe.*from|from.*swipe|Swipe','B-A03.3':'resolveAndroid|application.?id|built.*variant','B-A04.3':'waitForAnimationToEnd|takeScreenshot|settle','B-A05.3':'requestedMilliseconds|one frame|1000','B-A06.3':'interrupted|reportDir|SIGINT','B-A07.2':'LogStreamer|onTermination','B-A07.3':'LogStreamerTests|SignalRelayTests|termination','B-A08.4':'logStream|logs-level|logcat -c','B-A09.3':'What went wrong|What-went-wrong|GradleBuildRunner','B-A10.3':'commandFailed|messageOnly','B-A10.4':'SimulatorLeaseTests|InstallCommandTests|TableFormatterTests','B-A11.3':'ImageButton|missing_label','B-A11.4':'ImageButton|Deep Links|missing_label','B-A12.3':'DoctorTests|is-inside-work-tree|Git Repository','B-A13.3':'exact.*true|Selector|FlowGenerator','B-C01.3':'RunnerManagerTests|installIfNeeded|locks','B-C02.4':'EmulatorManagerTests|boot_completed|dead.*pid'}
def run(row,q):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);argv=['ruby',str(cap),str(d),'source-inspection',str(src),'--timeout','120','--','rg','-n','-i',q,'Sources','Tests'];z=subprocess.run(argv,cwd=root);print(row,z.returncode)
for a,b in queries.items():run(a,b)
# correction docs captures adjacent labels in existing dirs
for row,script in [('B-A01.2',"sed -n '88,97p' docs/android.md; sed -n '92,99p' README.md"),('B-A04.2',"sed -n '156,162p' README.md")]:
 d=ev/f'{row}-run-1';subprocess.run(['ruby',str(cap),str(d),'inspect-corrected',str(src),'--timeout','120','--','/bin/bash','-c',script],cwd=root)
