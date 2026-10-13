from pathlib import Path
import json,os,subprocess,time,shlex,shutil
r=Path(__file__).parent;s=json.loads((r/'state-fix6.json').read_text());d=r/'ios-detached-failure-fix6';d.mkdir();i=s['ios'];project=Path(i['project']);session=project/'.grantiva/session.json';os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4');a=[s['binary'],'runner','start','--simulator',i['udid'],'--bundle-id','com.grantiva.fix4.definitely-missing','--detach','--json'];(d/'command.json').write_text(json.dumps(a));p=subprocess.Popen(a,cwd=project,stdout=(d/'out').open('wb'),stderr=(d/'err').open('wb'));t=time.monotonic();seen=None
try:
 while p.poll() is None and time.monotonic()-t<120:
  if session.exists():
   try:
    seen=json.loads(session.read_text());assert seen['state']=='starting';(d/'last-session.json').write_text(json.dumps(seen));argv=shlex.split(subprocess.check_output(['/bin/ps','-ww','-p',str(seen['pid']),'-o','command='],text=True));(d/'runner-argv.json').write_text(json.dumps(argv))
    if '--output' in argv:
     report=Path(argv[argv.index('--output')+1]);
     if report.exists():shutil.copytree(report,d/'generated-report',dirs_exist_ok=True)
     if Path(argv[-1]).exists():shutil.copy2(argv[-1],d/'generated-flow.yaml')
   except (FileNotFoundError,json.JSONDecodeError,subprocess.CalledProcessError):pass
  time.sleep(.02)
 code=p.wait(timeout=5);err=(d/'err').read_text();record={'exit':code,'duration':time.monotonic()-t,'session':seen,'sessionAbsent':not session.exists()};(d/'result.json').write_text(json.dumps(record,indent=2));assert code==1 and 'The iOS app launch flow failed.' in err,err;assert seen and not session.exists();assert json.loads((d/'generated-report/report.json').read_text())['status']=='failed';ps=subprocess.check_output(['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='],text=True);(d/'processes-after.out').write_text(ps);assert not any(x.split()[0]==str(seen['pid']) for x in ps.splitlines());left=list(Path('/tmp/grantiva-sessions').glob(str(seen['pid'])+'*'));(d/'shared-after.json').write_text(json.dumps([str(x) for x in left]));assert not left;print('detached failure clean',code,record['duration'],flush=True)
finally:
 if p.poll() is None:
  subprocess.run([s['binary'],'runner','stop','--json'],cwd=project,capture_output=True,timeout=30);p.wait(timeout=15)
