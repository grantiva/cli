import json,os,signal,subprocess,sys,time
root,scratch,g,u,home=sys.argv[1:]
ready=root+'/interrupt.ready'; cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--logs','--ready-file',ready]
def snapshot(stage):
 lock=home+'/locks/'+u+'.lock'
 open(root+'/'+stage+'-lock-path.txt','w').write(lock+'\nexists='+str(os.path.exists(lock))+'\n')
 if os.path.exists(lock): open(root+'/'+stage+'-lock-content.txt','wb').write(open(lock,'rb').read())
 sessions='/tmp/grantiva-sessions'; matches=[]
 if os.path.isdir(sessions):
  for name in os.listdir(sessions):
   path=os.path.join(sessions,name)
   if os.path.isfile(path):
    try: data=open(path,'rb').read()
    except OSError: continue
    if u.encode() in data: matches.append((path,data))
 open(root+'/'+stage+'-matching-global-sessions.txt','w').write('\n'.join(x[0] for x in matches)+'\n')
 for i,(path,data) in enumerate(matches): open(root+'/'+stage+f'-global-session-{i}.bin','wb').write(data)
snapshot('before')
open(root+'/interrupt.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/interrupt.out','w'),stderr=open(root+'/interrupt.err','w'),start_new_session=True)
open(root+'/interrupt.pid','w').write(str(p.pid)+'\n')
rows=[]
for n in range(20):
 time.sleep(1)
 if p.poll() is not None: break
 ps=subprocess.run(['ps','-axo','pid=,ppid=,pgid=,state=,etime=,command='],capture_output=True,text=True).stdout
 rows=[x for x in ps.splitlines() if len(x.split())>=3 and x.split()[2].isdigit() and int(x.split()[2])==p.pid]
 if os.path.exists(ready) and any('log stream' in x for x in rows): break
open(root+'/during-process-group.txt','w').write('\n'.join(rows)+'\n'); snapshot('during')
for label,path in [('project',scratch+'/.grantiva')]:
 cp=subprocess.run(['find',path,'-maxdepth','4','-type','f','-print'],capture_output=True,text=True)
 open(root+'/during-'+label+'-files.txt','w').write(cp.stdout)
open(root+'/signal.json','w').write(json.dumps({'pid':p.pid,'elapsed':n+1,'sawLogStream':any('log stream' in x for x in rows)})+'\n')
if p.poll() is None: os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 os.killpg(p.pid,signal.SIGTERM); p.wait(timeout=5); rc=124
open(root+'/interrupt.exit.txt','w').write(str(rc)+'\n')
ps2=subprocess.run(['ps','-axo','pid=,ppid=,pgid=,state=,etime=,command='],capture_output=True,text=True).stdout
open(root+'/after-original-group.txt','w').write('\n'.join(x for x in ps2.splitlines() if len(x.split())>=3 and x.split()[2].isdigit() and int(x.split()[2])==p.pid)+'\n'); snapshot('after')
for label,path in [('project',scratch+'/.grantiva')]:
 cp=subprocess.run(['find',path,'-maxdepth','4','-type','f','-print'],capture_output=True,text=True)
 open(root+'/after-'+label+'-files.txt','w').write(cp.stdout)
