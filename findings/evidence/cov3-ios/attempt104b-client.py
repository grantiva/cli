import glob,json,os,subprocess,sys,time
root,cwd,g,u=sys.argv[1:]
out=open(root+'/start.out','w');err=open(root+'/start.err','w')
p=subprocess.Popen([g,'runner','start','--detach','--json','--bundle-id','com.kylebrowning.Landmarks','--simulator',u,'--platform','ios'],cwd=cwd,stdout=out,stderr=err,start_new_session=True)
obs=[];owner=None;ready=False;deadline=time.monotonic()+45
while time.monotonic()<deadline:
 d=None
 try:d=json.load(open(cwd+'/.grantiva/session.json'))
 except:pass
 matches=[]
 for x in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
  try:o=json.load(open(x))
  except:continue
  if o.get('grantivaPid')==p.pid and o.get('udid')==u and os.path.realpath(o.get('projectDirectory',''))==os.path.realpath(cwd):matches.append((x,o))
 if len(matches)==1:owner=matches[0]
 obs.append({'elapsed':time.monotonic()-(deadline-45),'session':d,'ownerPaths':[x[0] for x in matches],'starterExit':p.poll()})
 if d and d.get('state')=='ready' and isinstance(d.get('port'),int) and owner:ready=True;break
 time.sleep(.1)
json.dump({'ready':ready,'ownerPath':owner[0] if owner else None,'owner':owner[1] if owner else None,'observations':obs},open(root+'/timeline.json','w'),indent=2)
rc=p.wait(timeout=15);out.close();err.close();open(root+'/start.exit','w').write(str(rc)+'\n')
if not ready:raise SystemExit(2)
open(root+'/owner-before-stop.json','w').write(json.dumps(owner[1],indent=2)+'\n')
