import json,os,pathlib,signal,subprocess,sys,time
out,cwd,g,serial,apk,home,mode,report=sys.argv[1:]
o=pathlib.Path(out);cmd=[g,'run','--platform','android','--device',serial,'--no-build','--app-file',apk,'--flow','.maestro/01-browse.yaml']
if mode=='keepalive':cmd.append('--keep-alive')
if report!='-':cmd += ['--report-dir',report]
(o/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');stdout=open(o/'run.out','wb');stderr=open(o/'run.err','wb')
p=subprocess.Popen(cmd,cwd=cwd,stdout=stdout,stderr=stderr,start_new_session=True);(o/'parent.pid').write_text(str(p.pid)+'\n')
lock=pathlib.Path(home)/'locks'/(serial+'.lock');deadline=time.monotonic()+45;claim=None
while time.monotonic()<deadline and p.poll() is None:
 try:
  claim=json.loads(lock.read_text())
  if claim.get('pid')==p.pid and len(claim.get('temporaryDirectories',[])) >= (2 if report=='-' else 1):break
 except Exception:pass
 time.sleep(.05)
else:
 try: os.kill(p.pid,signal.SIGINT)
 except ProcessLookupError: pass
 try: p.wait(timeout=15)
 except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=10)
 stdout.close(); stderr.close()
 raise SystemExit('owned live claim with two temp directories not observed')
(o/'lease-path.txt').write_text(str(lock)+'\n');(o/'claim-before-kill.json').write_text(json.dumps(claim,indent=2)+'\n')
for x in claim['temporaryDirectories']:
 if not pathlib.Path(x).exists():raise SystemExit('claimed directory absent '+x)
os.kill(p.pid,signal.SIGKILL);rc=p.wait(timeout=20);stdout.close();stderr.close();(o/'run.exit').write_text(str(rc)+'\n')
