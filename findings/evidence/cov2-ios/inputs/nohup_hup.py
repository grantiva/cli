import subprocess,sys,time,signal,os,json,glob
g,u,ready=sys.argv[1:4]
p=subprocess.Popen(['nohup',g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',ready],stdout=open(os.devnull,'w'),stderr=open(os.devnull,'w'))
for i in range(120):
    if os.path.exists(ready): break
    time.sleep(1)
print('ready', open(ready).read().replace('\n',' ')[:120])
owners=[json.load(open(f)) for f in glob.glob('/tmp/grantiva-sessions/*.owner.json')]
mine=[o for o in owners if o.get('udid')==u]
rp=mine[0]['runnerPid']; gp=mine[0]['grantivaPid']; print('grantiva pid',gp,'(nohup child of',p.pid,') runner pid',rp)
os.kill(rp,signal.SIGHUP); time.sleep(3)
alive=lambda x: subprocess.run(['kill','-0',str(x)],capture_output=True).returncode==0
print('after SIGHUP to runner: runner alive',alive(rp),'grantiva alive',alive(gp))
os.kill(gp,signal.SIGHUP); time.sleep(3)
print('after SIGHUP to grantiva: runner alive',alive(rp),'grantiva alive',alive(gp))
if alive(gp): os.kill(gp,signal.SIGINT)
p.wait(timeout=60); print('nohup exit',p.returncode)
time.sleep(1); print('runner alive at end',alive(rp))
