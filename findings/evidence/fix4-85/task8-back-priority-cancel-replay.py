#!/usr/bin/env python3
"""One bounded iOS 26 replay of the post-Cancel WDA source timeout."""
import argparse, hashlib, json, os, subprocess, sys, time, urllib.error, urllib.request
from pathlib import Path

APP_ID = "com.kylebrowning.Landmarks"
SESSION_ID = "fix4-85"
EXPECTED_CLI = "6cad3f2b4081f0862cd0e93140eda11c2816b9ba"
EXPECTED_DEVICE = "DE2663B5-C24E-42DA-998D-20F7A80054B3"
EXPECTED_BINARY_SHA256 = "f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78"

def require(value, message):
    if not value: raise AssertionError(message)
def load(path): return json.loads(Path(path).read_text())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def git(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
def file_manifest(root):
    root=Path(root).resolve()
    return [{"path":p.relative_to(root).as_posix(),"sha256":sha(p)}
            for p in sorted((x for x in root.rglob("*") if x.is_file()),key=lambda x:x.relative_to(root).as_posix())]

p = argparse.ArgumentParser()
p.add_argument("--source-manifest", required=True)
p.add_argument("--ownership", required=True)
p.add_argument("--project", required=True)
p.add_argument("--output", required=True)
p.add_argument("--http-timeout", type=float, default=15.0)
ns = p.parse_args()
manifest_path, ownership_path = Path(ns.source_manifest).resolve(), Path(ns.ownership).resolve()
project, output = Path(ns.project).resolve(), Path(ns.output).resolve()
require(manifest_path.is_file() and ownership_path.is_file(), "manifest missing")
require(project.is_dir() and not (project / ".grantiva/session.json").exists(), "project must be fresh")
require(not output.exists(), "output must be fresh")
require(0 < ns.http_timeout <= 30, "HTTP timeout must be in (0, 30]")
output.mkdir(parents=True)

source, ownership = load(manifest_path), load(ownership_path)
require(source.get("schema") == "grantiva.fix4-85.source.v1", "wrong source schema")
require(source.get("finalMergedCandidate") is False and source.get("task8Passed") is False, "source claims acceptance")
require(ownership.get("schema") == "grantiva.fix4-85.ownership.v1", "wrong ownership schema")
device = ownership["device"]
require(device.get("owned") is True and device.get("platform") == "ios", "device is not explicitly owned iOS")
require(device.get("id") == EXPECTED_DEVICE and device.get("name") == "fix4-back-26", "not the exact owned iOS 26 device")
require(device.get("runtime") == "com.apple.CoreSimulator.SimRuntime.iOS-26-0", "wrong runtime")
require(source["runtimeOwner"].get("deviceId") == EXPECTED_DEVICE, "source/ownership device mismatch")
require(source["runtimeOwner"].get("sessionId") == SESSION_ID, "wrong session owner")
require(Path(source["runtimeOwner"]["ownershipManifest"]).resolve() == ownership_path, "ownership path mismatch")

cli, runner, demo = source["cli"], source["runner"], source["demo"]
binary, runner_home, app = Path(cli["releaseBinary"]["path"]).resolve(), Path(runner["home"]).resolve(), Path(demo["app"]["path"]).resolve()
require(cli.get("head") == EXPECTED_CLI and git(cli["repo"], "rev-parse", "HEAD") == EXPECTED_CLI, "CLI HEAD changed")
require(cli.get("cleanStatus") == "" and git(cli["repo"], "status", "--porcelain") == "", "CLI checkout dirty")
require(cli["releaseBinary"].get("sha256") == EXPECTED_BINARY_SHA256, "manifest declares an unreviewed source binary")
require(binary.is_file() and sha(binary) == EXPECTED_BINARY_SHA256, "source binary bytes changed")
runner_binary=Path(runner["installed"]["path"]).resolve()
require(runner.get("sourceHead")=="ba9008f4b2cd2c7320a9c46e04faed612b0958a2","runner source changed")
require(runner_home.is_dir() and runner_binary.is_file() and sha(runner_binary)==runner["installed"]["sha256"], "runner installation changed")
require(demo.get("sourceHead") == "84af7581b75134b0e417b254e4317d565f7b73c6" and app.is_dir(), "demo changed")
app_manifest=file_manifest(app)
require(app_manifest==sorted(demo["app"]["files"],key=lambda x:x["path"]),"frozen app manifest changed")

env = os.environ.copy()
env.pop("GRANTIVA_API_KEY", None)
env.update(GRANTIVA_RUNNER_HOME=str(runner_home), MAESTRO_RUNNER_HOME=str(runner_home), GRANTIVA_SESSION_ID=SESSION_ID)
os.environ.pop("GRANTIVA_API_KEY", None)
os.environ.update(GRANTIVA_RUNNER_HOME=str(runner_home), MAESTRO_RUNNER_HOME=str(runner_home), GRANTIVA_SESSION_ID=SESSION_ID)
run_record = {"schema":"grantiva.fix4-85.cancel-replay.v1", "argv":sys.argv, "cwd":os.getcwd(),
              "startEpoch":time.time(), "apiKeyUnset":True, "httpTimeoutSeconds":ns.http_timeout,
              "sourceManifest":str(manifest_path), "sourceManifestSHA256":sha(manifest_path),
              "ownership":str(ownership_path), "ownershipSHA256":sha(ownership_path),
              "cliHead":EXPECTED_CLI, "binary":str(binary), "binarySHA256":sha(binary),
              "device":device, "project":str(project), "output":str(output)}
(output/"run.json").write_text(json.dumps(run_record, indent=2)+"\n")

def command(label, argv, timeout=120):
    d=output/label; d.mkdir(); argv=[str(x) for x in argv]
    meta={"argv":argv,"cwd":str(project),"startEpoch":time.time()}
    (d/"start.json").write_text(json.dumps(meta,indent=2)+"\n")
    try:
        with (d/"stdout.raw").open("wb") as out, (d/"stderr.raw").open("wb") as err:
            r=subprocess.run(argv,cwd=project,env=env,stdout=out,stderr=err,timeout=timeout)
        meta.update(endEpoch=time.time(),exit=r.returncode,timedOut=False)
    except subprocess.TimeoutExpired:
        meta.update(endEpoch=time.time(),exit=None,timedOut=True)
        (d/"result.json").write_text(json.dumps(meta,indent=2)+"\n"); raise
    (d/"result.json").write_text(json.dumps(meta,indent=2)+"\n")
    require(r.returncode==0, f"{label} failed")
    return d

def http(label, method, url, body=None):
    d=output/label; d.mkdir()
    payload=None if body is None else json.dumps(body,separators=(",",":")).encode()
    headers={} if payload is None else {"Content-Type":"application/json"}
    req=urllib.request.Request(url,data=payload,headers=headers,method=method)
    meta={"method":method,"url":url,"body":body,"timeoutSeconds":ns.http_timeout,"startEpoch":time.time()}
    (d/"request.json").write_text(json.dumps(meta,indent=2)+"\n")
    try:
        with urllib.request.urlopen(req,timeout=ns.http_timeout) as response:
            data=response.read(); status=response.status
        (d/"response.raw").write_bytes(data)
        meta.update(endEpoch=time.time(),status=status,timedOut=False,responseBytes=len(data))
    except Exception as error:
        data=b""
        if isinstance(error, urllib.error.HTTPError):
            data=error.read(); (d/"response.raw").write_bytes(data)
        meta.update(endEpoch=time.time(),status=getattr(error,"code",None),timedOut=isinstance(error,TimeoutError),
                    error=f"{type(error).__name__}: {error}",responseBytes=len(data))
    (d/"result.json").write_text(json.dumps(meta,indent=2)+"\n")
    return meta, data

session_path=project/".grantiva/session.json"; client=None; owned_pid=None; primary=None
try:
    inventory=command("simulator-identity",["/usr/bin/xcrun","simctl","list","devices","--json"],60)
    listed=load(inventory/"stdout.raw")
    matches=[(runtime,d) for runtime,devices in listed["devices"].items() for d in devices if d.get("udid")==EXPECTED_DEVICE]
    require(len(matches)==1 and matches[0][0]==device["runtime"] and matches[0][1].get("name")==device["name"], "live device identity mismatch")
    installed=command("installed-app-container",["/usr/bin/xcrun","simctl","get_app_container",EXPECTED_DEVICE,APP_ID,"app"],60)
    installed_app=Path((installed/"stdout.raw").read_text().strip()).resolve()
    require(installed_app.is_dir() and file_manifest(installed_app)==app_manifest, "installed app differs from frozen source app")
    command("runner-start",[binary,"runner","start","--platform","ios","--simulator",EXPECTED_DEVICE,
                            "--bundle-id",APP_ID,"--detach","--json"],240)
    session=load(session_path); owned_pid=session.get("pid") or session.get("runnerPid")
    require(session.get("platform")=="ios" and EXPECTED_DEVICE in (session.get("udid"),session.get("device"),session.get("deviceId")), "session identity mismatch")
    require(isinstance(owned_pid,int) and owned_pid>0, "runner PID missing")
    port=session.get("port") or session.get("wdaPort")
    require(isinstance(port,int) and port>0, "WDA port missing")

    sys.path.insert(0,str(Path(__file__).resolve().parents[3]/"findings/tools/round4-smoke-candidate2"))
    from mcp_client import Client
    client=Client(binary,project,"ios",output/"mcp")
    ready=None
    for _ in range(30):
        ready=client.tool("grantiva_a11y_tree",{})
        if not ready.get("error") and not ready.get("result",{}).get("isError"): break
        time.sleep(1)
    require(ready and not ready.get("result",{}).get("isError"), "MCP never ready")
    for label in ("Deep Links","Edit Landmark"):
        reply=client.tool("grantiva_tap",{"label":label}); require(not reply["result"].get("isError"),f"{label} failed")
    name=client.tool("grantiva_tap",{"label":"Name"})
    require(not name["result"].get("isError") and client.text(name).startswith('Tapped on "Name" (matched by placeholder).'),"Name setup failed")

    base=f"http://localhost:{port}"
    status_meta,status_data=http("wda-status","GET",f"{base}/status")
    require(status_meta.get("status")==200,"WDA status failed")
    status_json=json.loads(status_data); sid=status_json.get("sessionId")
    require(isinstance(sid,str) and sid,"actual WDA session ID missing")
    (output/"wda-session.json").write_text(json.dumps({"port":port,"sessionId":sid},indent=2)+"\n")
    endpoint=f"{base}/session/{sid}"
    preferred={"using":"predicate string","value":'label == "Cancel" AND identifier == "BackButton" AND type == "XCUIElementTypeButton"'}
    broad={"using":"predicate string","value":'label == "Cancel" AND type != "XCUIElementTypeApplication"'}
    pm,pd=http("wda-preferred-cancel","POST",f"{endpoint}/elements",preferred)
    require(pm.get("status")==200,"preferred lookup failed")
    bm,bd=http("wda-broad-cancel","POST",f"{endpoint}/elements",broad)
    require(bm.get("status")==200,"broad lookup failed")
    elements=json.loads(bd).get("value",[]); require(elements,"broad lookup returned no Cancel")
    first=elements[0]; eid=first.get("ELEMENT") or first.get("element-6066-11e4-a52e-4f735466cecf")
    require(isinstance(eid,str) and eid,"first Cancel ID missing")
    (output/"selected-cancel.json").write_text(json.dumps({"index":0,"element":first,"elementId":eid},indent=2)+"\n")
    cm,_=http("wda-click-first-cancel","POST",f"{endpoint}/element/{eid}/click",{})
    require(cm.get("status")==200,"Cancel click failed")
    command("screenshot-immediately-after-click",["/usr/bin/xcrun","simctl","io",EXPECTED_DEVICE,"screenshot",output/"immediately-after-click.png"],60)
    time.sleep(0.5)
    http("wda-source-first","GET",f"{endpoint}/source")
    http("wda-source-retry","GET",f"{endpoint}/source")
    command("screenshot-after-source",["/usr/bin/xcrun","simctl","io",EXPECTED_DEVICE,"screenshot",output/"after-source.png"],60)
except Exception as error:
    primary=error
    raise
finally:
    cleanup_errors=[]
    if client:
        try: client.close()
        except Exception as e: cleanup_errors.append(f"MCP close: {e}")
    if session_path.exists():
        try:
            current=load(session_path)
            require(current.get("platform")=="ios" and EXPECTED_DEVICE in (current.get("udid"),current.get("device"),current.get("deviceId")), "refusing foreign stop")
            command("runner-stop",[binary,"runner","stop","--json"],120)
        except Exception as e: cleanup_errors.append(f"runner stop: {e}")
    pid_absent=False
    if isinstance(owned_pid,int) and owned_pid>0:
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            try: os.kill(owned_pid,0)
            except ProcessLookupError: pid_absent=True; break
            except PermissionError: pass
            time.sleep(.2)
    cleanup={"projectSessionAbsent":not session_path.exists(),"ownedRunnerPid":owned_pid,
             "ownedRunnerPidAbsent":pid_absent,"deviceDeleted":False,
             "simulatorCreationOrDeletionAttempted":False,
             "primaryError":None if primary is None else f"{type(primary).__name__}: {primary}",
             "cleanupErrors":cleanup_errors}
    (output/"cleanup.json").write_text(json.dumps(cleanup,indent=2)+"\n")
    run_record.update(endEpoch=time.time(),cleanup=cleanup)
    (output/"run.json").write_text(json.dumps(run_record,indent=2)+"\n")
    if primary is None:
        require(cleanup["projectSessionAbsent"] and pid_absent and not cleanup_errors,"cleanup incomplete")

(output/"replay-result.json").write_text(json.dumps({"completed":True,"acceptanceRegraded":False,
    "originalFailurePreserved":True,"sourceFirst":load(output/"wda-source-first"/"result.json"),
    "sourceRetry":load(output/"wda-source-retry"/"result.json")},indent=2)+"\n")
