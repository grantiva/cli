#!/usr/bin/env python3
"""Execute the single reviewed AND-111 compile-only command and retain evidence."""
import argparse, hashlib, json, os, signal, subprocess, time
from pathlib import Path

ROOT = Path("/Users/kyle/Developer/grantiva-cli/.worktrees/regression")
CANDIDATE = ROOT / "findings/evidence/round4-coverage/candidate.json"
PROVISION = ROOT / "findings/evidence/round4-coverage/primary-provision/acceptance.json"
SHUTDOWN = ROOT / "findings/evidence/round4-coverage/android-shutdown-transition/acceptance.json"
INPUTS = ROOT / "findings/evidence/round4-coverage/and111-inputs/manifest.json"
INPUT_REVIEW = ROOT / ".superpowers/sdd/2026-10-13-round4-fix-wave/task9-and111-input-review.md"
EXPECTED = {"candidate":"d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e",
            "provision":"d6e638bc6ff4710c95c6e3794e43b431384cfd4bcd163992956de16e99eb7a9a",
            "shutdown":"03b5b8fdf03ac0d00cd618223cb9fd1676b9a16ef6d5d292fbce2890d54a31b3",
            "inputs":"99ffb154834385c0be096d5022ee468bc0db8cc78801e68e7c31751c58375e27"}
CLI = Path("/Users/kyle/.grantiva-qa/bin/grantiva")
SCRATCH = Path("/private/tmp/grantiva-round4-and111-v87ic72y/android")
RUNNER_HOME = Path("/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home")
SDK = Path("/Users/kyle/Library/Android/sdk")
JAVA21 = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
SERIAL, AVD, PID = "emulator-5584", "cov4-android", 82484
IOS_IDS = {"B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C", "FE441EE5-BBFC-4981-B68A-59C0DBCE26D6",
           "3B3BBFDB-D435-454F-9DDC-E0CC5EE99E42", "989B2045-96AE-46BF-8E13-C76B563FC6F5"}

def require(value, message):
    if not value: raise RuntimeError(message)
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def load(path):
    value=json.loads(Path(path).read_text()); require(isinstance(value,dict),f"JSON object required: {path}"); return value
def save_new(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("x") as f: json.dump(value,f,indent=2,sort_keys=True); f.write("\n")
def write_new(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as f: f.write(value)
def files(root):
    return [{"path":str(p.relative_to(root)),"sha256":sha(p),"bytes":p.stat().st_size}
            for p in sorted(root.rglob("*")) if p.is_file() and not p.is_symlink()]
def identity_files(root):
    return [{"path":str(p.relative_to(root)),"sha256":sha(p)} for p in sorted(root.rglob("*")) if p.is_file()]
def tree_hash(root):
    listing=files(root); digest=hashlib.sha256()
    for item in listing: digest.update(item["path"].encode()+b"\0"+item["sha256"].encode()+b"\0")
    return {"path":str(root.resolve()),"fileCount":len(listing),"treeSHA256":digest.hexdigest()}

def run(out,label,argv,cwd,env,timeout=120,expected=(0,)):
    destination=out/label; destination.mkdir(parents=True,exist_ok=False); started=time.time()
    proc=subprocess.Popen(list(map(str,argv)),cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    timed_out=False
    try: stdout,stderr=proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out=True; os.killpg(proc.pid,signal.SIGKILL); stdout,stderr=proc.communicate()
    write_new(destination/"stdout.bin",stdout); write_new(destination/"stderr.bin",stderr)
    meta={"argv":list(map(str,argv)),"cwd":str(Path(cwd).resolve()),"startedEpoch":started,"endedEpoch":time.time(),
          "timeoutSeconds":timeout,"timedOut":timed_out,"exit":None if timed_out else proc.returncode,
          "expectedExits":list(expected),"stdoutSHA256":sha(destination/"stdout.bin"),"stderrSHA256":sha(destination/"stderr.bin")}
    save_new(destination/"result.json",meta)
    require(not timed_out and proc.returncode in expected,f"{label} failed")
    return stdout,meta

def git_proof(out,label,repo,expected,env):
    head=run(out,label+"-head",["git","rev-parse","HEAD"],repo,env)[0].decode().strip()
    status=run(out,label+"-status",["git","status","--porcelain=v1","--untracked-files=all"],repo,env)[0]
    require(head==expected and status==b"",f"source proof failed: {repo}")
    return {"repo":str(repo.resolve()),"head":head,"status":""}

def normalized_ios(raw):
    doc=json.loads(raw); found={}
    for devices in doc["devices"].values():
        for device in devices:
            if device.get("udid") in IOS_IDS:
                found[device["udid"]]={k:v for k,v in device.items() if k not in ("dataPathSize","logPathSize")}
    require(set(found)==IOS_IDS,"protected/owned iOS inventory incomplete"); return found

def scratch_state(inputs):
    expected={item["path"].removeprefix("android/"):item["sourceSHA256"] for item in inputs["trackedInputs"]}
    expected["grantiva-android.yml"]=inputs["config"]["scratchSHA256"]
    actual={}
    for rel,want in expected.items():
        path=SCRATCH/rel; require(path.is_file() and not path.is_symlink() and sha(path)==want,f"scratch input changed: {rel}")
        actual[rel]=want
    generated=[]
    for path in sorted(SCRATCH.rglob("*")):
        if not path.is_file() or path.is_symlink(): continue
        rel=str(path.relative_to(SCRATCH))
        if rel not in expected: generated.append({"path":rel,"sha256":sha(path),"bytes":path.stat().st_size})
    return {"trackedCount":len(actual),"tracked":actual,"generated":generated}

def frozen_state(candidate):
    require(sha(CLI)==candidate["cli"]["binary"]["sha256"],"frozen CLI changed")
    require(sha(candidate["demo"]["androidAPK"]["path"])==candidate["demo"]["androidAPK"]["sha256"],"frozen APK changed")
    require(identity_files(Path(candidate["cli"]["bundle"]["path"]))==candidate["cli"]["bundle"]["files"],"CLI bundle changed")
    require(identity_files(Path(candidate["demo"]["iosApp"]["path"]))==candidate["demo"]["iosApp"]["files"],"frozen app changed")
    require(RUNNER_HOME.resolve()==Path(candidate["runner"]["runnerHome"]).resolve(),"runner home binding changed")
    return {"cliSHA256":sha(CLI),"bundle":tree_hash(Path(candidate["cli"]["bundle"]["path"])),
            "apkSHA256":sha(candidate["demo"]["androidAPK"]["path"]),
            "iosApp":tree_hash(Path(candidate["demo"]["iosApp"]["path"])),"runnerHome":tree_hash(RUNNER_HOME)}

def snapshot(out,label,env,candidate,inputs):
    adb=SDK/"platform-tools/adb"; emulator=SDK/"emulator/emulator"
    adb_devices=run(out,label+"-adb-devices",[adb,"devices","-l"],out,env)[0]
    forwards=run(out,label+"-forwards",[adb,"forward","--list"],out,env)[0]
    avds=run(out,label+"-avds",[emulator,"-list-avds"],out,env)[0].decode().splitlines()
    pid_stdout=run(out,label+"-owned-pid",["ps","-p",str(PID),"-o","pid=","-o","command="],out,env,expected=(1,))[0]
    sims=run(out,label+"-simulators",["xcrun","simctl","list","devices","--json"],out,env)[0]
    require(SERIAL.encode() not in adb_devices and AVD in avds and pid_stdout==b"","AND-111 shutdown precondition failed")
    cov_registration=Path.home()/f".android/avd/{AVD}.ini"; cov_config=Path.home()/f".android/avd/{AVD}.avd/config.ini"
    pixel=Path.home()/".android/avd/Pixel_8_API_35.avd/config.ini"
    state={"adbDevicesSHA256":hashlib.sha256(adb_devices).hexdigest(),"adbDevicesBytes":adb_devices.decode(errors="replace"),
           "forwardsSHA256":hashlib.sha256(forwards).hexdigest(),"forwardsBytes":forwards.decode(errors="replace"),
           "avds":avds,"ownedPIDAbsent":True,"ownedSerialAbsent":True,
           "covRegistrationSHA256":sha(cov_registration),"covConfigSHA256":sha(cov_config),
           "protectedPixelSHA256":sha(pixel),"ios":normalized_ios(sims),
           "scratch":scratch_state(inputs),"frozen":frozen_state(candidate)}
    save_new(out/(label+"-snapshot.json"),state); return state

def validate_transition(before,after):
    for key in ("adbDevicesSHA256","forwardsSHA256","avds","ownedPIDAbsent","ownedSerialAbsent","covRegistrationSHA256","covConfigSHA256","protectedPixelSHA256","ios","frozen"):
        require(before[key]==after[key],f"post-compile state changed: {key}")
    require(before["scratch"]["tracked"]==after["scratch"]["tracked"],"tracked scratch input changed")
    require(before["scratch"]["generated"]==[],"scratch had output before compile")
    require(all(item["path"].startswith(("app/build/","build/")) for item in after["scratch"]["generated"]),"unexpected scratch output")
    apks=[item for item in after["scratch"]["generated"] if item["path"].endswith(".apk")]
    require(apks,"compile produced no APK")
    return apks

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--output",required=True,type=Path); ap.add_argument("--timeout",type=float,default=1800); a=ap.parse_args()
    output=a.output.resolve(); require(not output.exists(),"output must be absent")
    for name,path in (("candidate",CANDIDATE),("provision",PROVISION),("shutdown",SHUTDOWN),("inputs",INPUTS)):
        require(sha(path)==EXPECTED[name],f"{name} hash mismatch")
    candidate,provision,shutdown,inputs=map(load,(CANDIDATE,PROVISION,SHUTDOWN,INPUTS))
    require(sha(INPUT_REVIEW)=="31205f9a4eefc21a076673e77ff42d59b8d64b007e672272c702d9562072a296", "input review hash mismatch")
    require(provision["passed"] is True and shutdown["passed"] is True and shutdown["state"]=="created-shutdown","gates not passing")
    require(shutdown["candidateManifestSHA256"]==EXPECTED["candidate"] and shutdown["allocation"]=={"avd":AVD,"serial":SERIAL,"pid":PID},"shutdown binding mismatch")
    require(inputs["schema"]=="grantiva.task9.and111-inputs.v1" and inputs["candidateManifestSHA256"]==EXPECTED["candidate"] and
            Path(inputs["cwd"]).resolve()==SCRATCH and len(inputs["trackedInputs"])==75,"input binding mismatch")
    output.mkdir(parents=True,exist_ok=False)
    env=os.environ.copy(); env.pop("GRANTIVA_API_KEY",None); env.update(GRANTIVA_RUNNER_HOME=str(RUNNER_HOME),MAESTRO_RUNNER_HOME=str(RUNNER_HOME),
        JAVA_HOME=JAVA21,ANDROID_HOME=str(SDK),ANDROID_SDK_ROOT=str(SDK),GRADLE_USER_HOME=str(output/"gradle-home"))
    demo=Path(candidate["demo"]["repoPath"]); cli_repo=Path(candidate["cli"]["repoPath"])
    before_source={"demo":git_proof(output,"before-demo-source",demo,candidate["demo"]["sourceSHA"],env),
                   "cli":git_proof(output,"before-cli-source",cli_repo,candidate["cli"]["mergedSHA"],env)}
    before=snapshot(output,"before",env,candidate,inputs)
    require(before["protectedPixelSHA256"]==shutdown["protectedPixelConfigSHA256"] and
            before["covRegistrationSHA256"]==shutdown["registrationSHA256"],"shutdown protected/registration binding changed")
    save_new(output/"command-start.json",{"argv":[str(CLI),"build","build"],"cwd":str(SCRATCH),"apiKey":"unset",
        "environment":{k:env[k] for k in ("GRANTIVA_RUNNER_HOME","MAESTRO_RUNNER_HOME","JAVA_HOME","ANDROID_HOME","ANDROID_SDK_ROOT","GRADLE_USER_HOME")},
        "candidateManifestSHA256":EXPECTED["candidate"],"provisionSHA256":EXPECTED["provision"],"shutdownTransitionSHA256":EXPECTED["shutdown"],"inputsSHA256":EXPECTED["inputs"]})
    run(output,"compile",[CLI,"build","build"],SCRATCH,env,a.timeout)
    after=snapshot(output,"after",env,candidate,inputs)
    after_source={"demo":git_proof(output,"after-demo-source",demo,candidate["demo"]["sourceSHA"],env),
                  "cli":git_proof(output,"after-cli-source",cli_repo,candidate["cli"]["mergedSHA"],env)}
    require(before_source==after_source,"frozen demo source drift")
    apks=validate_transition(before,after)
    save_new(output/"generated-apks.json",apks)
    result={"schema":"grantiva.task9.and111.v1","passed":True,"candidateManifestSHA256":EXPECTED["candidate"],
            "shutdownTransitionSHA256":EXPECTED["shutdown"],"primaryProvisionSHA256":EXPECTED["provision"],
            "inputsSHA256":EXPECTED["inputs"],"sourceUnchanged":True,"scratchTrackedCount":75,"generatedAPKs":apks,
            "deviceStateUnchanged":True,"noInstallBootLaunch":True}
    save_new(output/"acceptance.json",result)

if __name__=="__main__": main()
