import glob, json, os, subprocess, sys, time

root, project, grantiva, primary, secondary = sys.argv[1:]
os.makedirs(root, exist_ok=True)
procs=[]
def spawn(serial, stem):
    out=open(os.path.join(root,stem+'.out'),'w'); err=open(os.path.join(root,stem+'.err'),'w')
    cmd=[grantiva,'run','--platform','android','--device',serial,'--no-build','--keep-alive','--flow','.maestro/01-browse.yaml','--report-dir',os.path.join(root,stem+'-report')]
    json.dump(cmd,open(os.path.join(root,stem+'.command.json'),'w'))
    p=subprocess.Popen(cmd,cwd=project,stdout=out,stderr=err,start_new_session=True)
    procs.append((p,out,err,stem)); return p
p1=spawn(primary,'primary'); p2=spawn(secondary,'secondary')
observations=[]; ready=False
for poll in range(180):
    owners=[]
    for path in glob.glob('/tmp/grantiva-sessions/*.owner.json')+glob.glob('/private/tmp/grantiva-sessions/*.owner.json'):
        try:
            d=json.load(open(path))
            if os.path.realpath(d.get('projectDirectory',''))==os.path.realpath(project): owners.append({'path':path,'data':d})
        except Exception: pass
    observations.append({'poll':poll,'elapsedSeconds':poll*.25,'owners':owners,'primaryReturn':p1.poll(),'secondaryReturn':p2.poll()})
    serials={x['data'].get('udid') for x in owners}
    streams=[]
    for stem in ['primary','secondary']:
        text=''
        for suffix in ['.out','.err']:
            try: text+=open(os.path.join(root,stem+suffix)).read()
            except Exception: pass
        streams.append('[1/1]' in text and 'launchApp' in text)
    if {primary,secondary}<=serials and all(streams): ready=True; break
    if p1.poll() is not None or p2.poll() is not None: break
    time.sleep(.25)
json.dump({'ready':ready,'observations':observations},open(os.path.join(root,'active-observations.json'),'w'),indent=2)
stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=project,capture_output=True,text=True,timeout=60)
open(os.path.join(root,'stop.out'),'w').write(stop.stdout); open(os.path.join(root,'stop.err'),'w').write(stop.stderr); open(os.path.join(root,'stop.exit.txt'),'w').write(str(stop.returncode)+'\n')
exits={}
for p,out,err,stem in procs:
    try: rc=p.wait(timeout=45)
    except subprocess.TimeoutExpired: p.terminate(); rc=p.wait(timeout=10)
    out.close(); err.close(); exits[stem]=rc; open(os.path.join(root,stem+'.exit.txt'),'w').write(str(rc)+'\n')
json.dump(exits,open(os.path.join(root,'run-exits.json'),'w'),indent=2)
try: doc=json.loads(stop.stdout)
except Exception: doc={}
sessions=doc.get('sessions',[])
checks={
 'bothObservedActive':ready,
 'stopExit0':stop.returncode==0,
 'bothRunsExit0':exits=={'primary':0,'secondary':0},
 'twoSessions':len(sessions)==2,
 'bothSerials':{x.get('serial') for x in sessions}=={primary,secondary},
 'everyShape':all(isinstance(x.get('runnerPid'),int) and isinstance(x.get('pid'),int) and isinstance(x.get('killed'),bool) and isinstance(x.get('reaped'),list) and 'port' in x and x.get('applicationId')=='com.kylebrowning.landmarks' for x in sessions),
}
json.dump(checks,open(os.path.join(root,'assertions.json'),'w'),indent=2,sort_keys=True)
raise SystemExit(0 if all(checks.values()) else 1)
