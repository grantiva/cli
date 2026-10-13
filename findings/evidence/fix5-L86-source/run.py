import os, sys, json, subprocess, tempfile, time, hashlib
from pathlib import Path
label=sys.argv[1]; argv=sys.argv[2:]; out=Path(__file__).parent/label; out.mkdir()
home=Path(tempfile.mkdtemp(prefix="grantiva-fix5-L86-")); env=os.environ.copy(); env.pop("GRANTIVA_API_KEY",None)
env["GRANTIVA_RUNNER_HOME"]=str(home/"grantiva");env["MAESTRO_RUNNER_HOME"]=str(home/"maestro")
meta={"argv":argv,"cwd":os.getcwd(),"head":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),"api_key_unset":"GRANTIVA_API_KEY" not in env,"homes":[env["GRANTIVA_RUNNER_HOME"],env["MAESTRO_RUNNER_HOME"]]}
(out/"source.patch").write_bytes(subprocess.check_output(["git","diff","--","Sources","Tests"]))
(out/"start.json").write_text(json.dumps(meta,indent=2)); start=time.time()
with (out/"stdout.raw").open("wb") as stdout,(out/"stderr.raw").open("wb") as stderr:
 result=subprocess.run(argv,env=env,stdout=stdout,stderr=stderr)
meta={"exit":result.returncode,"elapsed_seconds":time.time()-start,"homes_exist":{p:Path(p).exists() for p in meta["homes"]},"sha256":{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in ["source.patch","stdout.raw","stderr.raw"]}}
(out/"result.json").write_text(json.dumps(meta,indent=2));print(json.dumps(meta));sys.exit(result.returncode)
