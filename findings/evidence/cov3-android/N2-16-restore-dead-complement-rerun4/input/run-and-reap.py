import json,pathlib,subprocess,sys
out,cwd,g,serial,apk=sys.argv[1:];o=pathlib.Path(out);o.mkdir(parents=True,exist_ok=True)
cmd=[g,'run','--platform','android','--device',serial,'--no-build','--app-file',apk,'--flow','.maestro/11-slow.yaml','--report-dir',str(o/'report')]
(o/'command.json').write_text(json.dumps(cmd)+'\n');so=open(o/'run.out','w');se=open(o/'run.err','w')
p=subprocess.Popen(cmd,cwd=cwd,stdout=so,stderr=se);(o/'cli.pid').write_text(str(p.pid)+'\n');rc=p.wait();so.close();se.close();(o/'run.exit').write_text(str(rc)+'\n')
