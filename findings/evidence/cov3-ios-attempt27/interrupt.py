import json,os,signal,subprocess,sys,time
root,scratch,grantiva,udid=sys.argv[1:]
cmd=[grantiva,'run','--no-build','--simulator',udid,'--flow','.maestro/coverage/18-long-wait.yaml','--ready-file',root+'/interrupted.ready','--report-dir',root+'/interrupted-report']
open(root+'/interrupt.command.json','w').write(json.dumps(cmd)+'\n')
t0=time.monotonic(); p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/interrupt.out','w'),stderr=open(root+'/interrupt.err','w'),start_new_session=True)
open(root+'/interrupt.pid','w').write(str(p.pid)+'\n')
# Allow the owned flow to enter its long wait, preserving snapshots before signalling only this process group.
for i in range(12):
 time.sleep(1)
 subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],stdout=open(root+f'/interrupt-ps-{i+1:02d}.txt','w'))
 if p.poll() is not None: break
if p.poll() is None:
 open(root+'/signal-timing.json','w').write(json.dumps({'signal':'SIGINT','elapsedSeconds':time.monotonic()-t0,'pid':p.pid})+'\n')
 os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 open(root+'/harness-timeout.txt','w').write('owned process group did not exit within 30s after SIGINT; terminating only that recorded group\n')
 os.killpg(p.pid,signal.SIGTERM)
 try: p.wait(timeout=5)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGKILL); p.wait(timeout=5)
 rc=124
open(root+'/interrupt.exit.txt','w').write(str(rc)+'\n')
open(root+'/interrupt.elapsed-seconds.txt','w').write(str(time.monotonic()-t0)+'\n')
