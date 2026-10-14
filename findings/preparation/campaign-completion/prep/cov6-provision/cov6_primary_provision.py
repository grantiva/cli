#!/usr/bin/env python3
"""Provision only the three controller-owned Task 9 primary devices after a recorded zero gate."""
from pathlib import Path
import argparse, hashlib, json, os, socket, subprocess, time

IOS = (
    ("ios26", "cov6-ios-26", "com.apple.CoreSimulator.SimDeviceType.iPhone-17", "com.apple.CoreSimulator.SimRuntime.iOS-26-0"),
    ("ios27", "cov6-ios-27", "com.apple.CoreSimulator.SimDeviceType.iPhone-17", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"),
)
AVD = "cov6-android"
EXTRA_IOS = ("cov6-ios-3", "cov6-ios-4")
EXTRA_ANDROID = "cov6-android-2"
PROTECTED_IOS = {"B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C", "FE441EE5-BBFC-4981-B68A-59C0DBCE26D6"}
JAVA21 = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, value): path.write_text(json.dumps(value, indent=2) + "\n")
def require(value, message):
    if not value: raise RuntimeError(message)
def manifest(root):
    return [{"path": str(p.relative_to(root)), "sha256": sha(p)} for p in sorted(root.rglob("*")) if p.is_file()]
def protected_sims(doc):
    return {d["udid"]: {k: v for k, v in d.items() if k not in ("dataPathSize", "logPathSize")}
            for devices in doc["devices"].values() for d in devices if d.get("udid") in PROTECTED_IOS}
def normalized_forwards(raw): return sorted(" ".join(line.split()) for line in raw.decode().splitlines() if line.strip())
def ports_unused():
    sockets=[]
    try:
        for candidate_port in (port, port + 1):
            sock=socket.socket(); sock.bind(("127.0.0.1", candidate_port)); sockets.append(sock)
        return True
    except OSError:
        return False
    finally:
        for sock in sockets: sock.close()

ap=argparse.ArgumentParser()
ap.add_argument("--candidate", required=True, type=Path)
ap.add_argument("--gate-evidence", required=True, type=Path)
ap.add_argument("--output", required=True, type=Path)
ap.add_argument("--ios-runner-home", required=True, type=Path)
ap.add_argument("--android-runner-home", required=True, type=Path)
ap.add_argument("--android-serial", required=True, help="final root-selected serial after live inventory, e.g. emulator-5584")
a=ap.parse_args(); candidate_path=a.candidate.resolve(); gate_path=a.gate_evidence.resolve(); output=a.output.resolve(); ios_home=a.ios_runner_home.resolve(); android_home=a.android_runner_home.resolve(); SERIAL=a.android_serial; require(SERIAL.startswith("emulator-") and SERIAL[9:].isdigit(), "invalid final Android serial choice"); port=int(SERIAL[9:]); require(port % 2 == 0, "Android console port must be even")
require(candidate_path.is_file(), "candidate manifest missing"); require(gate_path.is_file(), "Task 8 zero gate missing")
candidate=json.loads(candidate_path.read_text()); gate=json.loads(gate_path.read_text()); candidate_sha=sha(candidate_path)
require(candidate.get("schema")=="grantiva.task8.candidate.v1", "completion-candidate5 schema mismatch")
require(gate.get("passed") is True, "completion-candidate5 smoke gate is not approved")
require(gate.get("candidateManifestSHA256")==candidate_sha, "zero gate candidate mismatch")
for key in ("review", "cleanup"):
    ref=gate.get(key,{}); path=Path(ref.get("path","")).resolve()
    require(path.is_file() and ref.get("sha256")==sha(path), f"smoke gate {key} hash mismatch")
cleanup_path=Path(gate["cleanup"]["path"]).resolve()
require(json.loads(cleanup_path.read_text()).get("passed") is True, "smoke cleanup evidence is not passing JSON")
require(gate.get("cleanupComplete") is True, "smoke cleanup is not complete")

cli=candidate["cli"]; runner=candidate["runner"]; demo=candidate["demo"]
source_home=Path(runner["runnerHome"]).resolve(); ios_app=Path(demo["iosApp"]["path"]).resolve(); apk=Path(demo["androidAPK"]["path"]).resolve()
require(source_home.is_dir(), "frozen candidate5 runner home missing")
require(not ios_home.exists() and not android_home.exists(), "fresh actor runner-home destination already exists")
require(sha(cli["binary"]["path"])==cli["binary"]["sha256"], "frozen CLI hash mismatch")
require(manifest(Path(cli["bundle"]["path"]).resolve())==cli["bundle"]["files"], "frozen bundle manifest mismatch")
require(manifest(ios_app)==demo["iosApp"]["files"], "frozen iOS app manifest mismatch")
require(sha(apk)==demo["androidAPK"]["sha256"], "frozen Android APK hash mismatch")
output.mkdir(parents=True, exist_ok=False)
for label,dest in (("ios-home-clone",ios_home),("android-home-clone",android_home)):
    p=subprocess.run(["cp","-cR",str(source_home),str(dest)],capture_output=True)
    (output/(label+".stdout")).write_bytes(p.stdout); (output/(label+".stderr")).write_bytes(p.stderr)
    save(output/(label+".json"),{"argv":["cp","-cR",str(source_home),str(dest)],"exit":p.returncode})
    require(p.returncode==0 and dest.is_dir(),f"{label} failed")
home=ios_home

sdk=Path.home()/"Library/Android/sdk"; adb=sdk/"platform-tools/adb"; emulator=sdk/"emulator/emulator"; avdmanager=sdk/"cmdline-tools/latest/bin/avdmanager"
env=os.environ.copy(); env.pop("GRANTIVA_API_KEY",None); env.update(JAVA_HOME=JAVA21,ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(home),GRANTIVA_SESSION_ID="candidate5-controller")
ownership={"schema":"grantiva.task9.primary-ownership.v1","sessionId":"candidate5-controller","candidateManifest":str(candidate_path),"candidateManifestSHA256":candidate_sha,"gateEvidence":str(gate_path),"runnerHomes":{"ios":str(ios_home),"android":str(android_home)},"devices":{},"reservations":{"iosExtraNames":list(EXTRA_IOS),"androidPrimaryAbsentName":AVD,"androidExtraName":EXTRA_ANDROID,"androidSerialChoice":SERIAL}}
save(output/"ownership.json",ownership)
def run(label, argv, input_bytes=None, timeout=240):
    argv=list(map(str,argv)); start=time.time(); meta={"argv":argv,"cwd":str(output),"startedEpoch":start,"sessionId":"candidate5-controller","runnerHome":str(home),"javaHome":JAVA21,"apiKey":"unset"}; save(output/(label+"-start.json"),meta)
    try: p=subprocess.run(argv,cwd=output,env=env,input=input_bytes,capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        stdout=exc.stdout or b""; stderr=exc.stderr or b""; stdout=stdout.encode() if isinstance(stdout,str) else stdout; stderr=stderr.encode() if isinstance(stderr,str) else stderr
        (output/(label+".stdout")).write_bytes(stdout); (output/(label+".stderr")).write_bytes(stderr); meta.update(exit=None,endedEpoch=time.time(),timedOut=True,configuredTimeoutSeconds=timeout,outcome="timeout"); save(output/(label+"-result.json"),meta); raise
    (output/(label+".stdout")).write_bytes(p.stdout); (output/(label+".stderr")).write_bytes(p.stderr); meta.update(exit=p.returncode,endedEpoch=time.time()); save(output/(label+"-result.json"),meta); return p,meta
def successful(label, argv, input_bytes=None, timeout=240):
    p,meta=run(label,argv,input_bytes,timeout); require(p.returncode==0,f"{label} failed: {p.stderr.decode(errors='replace')}"); return p,meta

# All name/serial/port and protected baselines precede the first mutation.
sims_p,_=successful("simulators-before",["xcrun","simctl","list","devices","--json"]); sims=json.loads(sims_p.stdout)
avds_p,_=successful("avds-before",[emulator,"-list-avds"]); adb_p,_=successful("adb-before",[adb,"devices","-l"])
forwards_before_p,_=successful("forwards-before",[adb,"forward","--list"])
all_sims=[d for devices in sims["devices"].values() for d in devices]
require(not any(d.get("name") in ({x[1] for x in IOS} | set(EXTRA_IOS)) for d in all_sims), "cov5 iOS primary or reserved-extra name already exists")
require(not ({AVD, EXTRA_ANDROID} & set(avds_p.stdout.decode().splitlines())), "cov5 Android primary or reserved-extra name already exists")
require(SERIAL not in adb_p.stdout.decode(), "Task 9 Android serial already connected")
require(ports_unused(), "selected Android console/adb port pair is in use")
require(set(protected_sims(sims))==PROTECTED_IOS, "protected iOS baseline incomplete")
protected_config=Path.home()/".android/avd/Pixel_8_API_35.avd/config.ini"; require(protected_config.is_file(),"protected Pixel config missing")
save(output/"baseline.json",{"protectedSimulators":protected_sims(sims),"protectedPixelConfig":{"path":str(protected_config),"sha256":sha(protected_config)},"task9NamesAbsent":True,"task9SerialAbsent":True,"selectedAndroidPortsUnused":True})

for key,name,device_type,runtime in IOS:
    argv=["xcrun","simctl","create",name,device_type,runtime]; entry={"platform":"ios","name":name,"runtime":runtime,"deviceType":device_type,"owned":False,"createdEpoch":None,"provision":{"command":argv,"state":"starting"},"ownedPIDs":[]}; ownership["devices"][key]=entry; save(output/"ownership.json",ownership)
    p,meta=run(key+"-create",argv); entry["provision"].update(state="completed",exit=p.returncode,startedEpoch=meta["startedEpoch"],endedEpoch=meta["endedEpoch"])
    if p.returncode==0:
        entry.update(id=p.stdout.decode().strip(),owned=True,createdEpoch=meta["startedEpoch"])
    save(output/"ownership.json",ownership); require(p.returncode==0 and entry.get("id"),f"{key} create failed")
    udid=entry["id"]; successful(key+"-boot",["xcrun","simctl","boot",udid]); successful(key+"-ready",["xcrun","simctl","bootstatus",udid,"-b"],timeout=300); successful(key+"-install",["xcrun","simctl","install",udid,ios_app])
    container_p,_=successful(key+"-container",["xcrun","simctl","get_app_container",udid,"com.kylebrowning.Landmarks","app"]); container=Path(container_p.stdout.decode().strip())
    installed=manifest(container); require(installed==demo["iosApp"]["files"],f"{key} installed app manifest mismatch"); save(output/(key+"-installed-manifest.json"),{"sourcePath":str(ios_app),"sourceManifestSHA256":demo["iosApp"]["manifestSHA256"],"installedPath":str(container),"files":installed})

# Android primary intentionally remains absent for literal AND-001; extras are reservations only.
ownership["devices"]["android"]={"platform":"android","name":AVD,"id":None,"serialChoice":SERIAL,"owned":False,"state":"absent-reserved-for-AND-001","runnerHome":str(android_home)}
ownership["devices"]["iosExtras"]={"platform":"ios","names":list(EXTRA_IOS),"ids":[],"owned":False,"state":"names-reserved-not-created"}
ownership["devices"]["androidExtra"]={"platform":"android","name":EXTRA_ANDROID,"id":None,"owned":False,"state":"name-reserved-not-created"}
save(output/"ownership.json",ownership)
sims_after_p,_=successful("simulators-after",["xcrun","simctl","list","devices","--json"]); sims_after=json.loads(sims_after_p.stdout)
avds_after_p,_=successful("avds-after",[emulator,"-list-avds"]); adb_after_p,_=successful("adb-after",[adb,"devices","-l"]); forwards_after_p,_=successful("forwards-after",[adb,"forward","--list"])
sim_ids=lambda doc:{d["udid"] for devices in doc["devices"].values() for d in devices}
adb_ids=lambda raw:{line.split()[0] for line in raw.decode().splitlines()[1:] if line.strip()}
before_sim_ids=sim_ids(sims); after_sim_ids=sim_ids(sims_after); expected_ios_ids={ownership["devices"][key]["id"] for key,_,_,_ in IOS}
before_avds=set(avds_p.stdout.decode().splitlines()); after_avds=set(avds_after_p.stdout.decode().splitlines()); before_adb=adb_ids(adb_p.stdout); after_adb=adb_ids(adb_after_p.stdout)
comparisons={"protectedSimulatorsUnchanged":protected_sims(sims_after)==protected_sims(sims),"protectedPixelConfigUnchanged":protected_config.is_file() and sha(protected_config)==json.loads((output/"baseline.json").read_text())["protectedPixelConfig"]["sha256"],"simulatorAdditions":sorted(after_sim_ids-before_sim_ids),"simulatorRemovals":sorted(before_sim_ids-after_sim_ids),"expectedSimulatorAdditions":sorted(expected_ios_ids),"avdAdditions":sorted(after_avds-before_avds),"avdRemovals":sorted(before_avds-after_avds),"adbAdditions":sorted(after_adb-before_adb),"adbRemovals":sorted(before_adb-after_adb),"forwardsBefore":str(output/"forwards-before.stdout"),"forwardsAfter":str(output/"forwards-after.stdout"),"normalizedForwardsBefore":normalized_forwards(forwards_before_p.stdout),"normalizedForwardsAfter":normalized_forwards(forwards_after_p.stdout)}
comparisons["forwardsUnchanged"]=comparisons["normalizedForwardsBefore"]==comparisons["normalizedForwardsAfter"]
comparisons["onlyExpectedAdditions"]=set(comparisons["simulatorAdditions"])==expected_ios_ids and not comparisons["simulatorRemovals"] and not comparisons["avdAdditions"] and not comparisons["avdRemovals"] and not comparisons["adbAdditions"] and not comparisons["adbRemovals"]
save(output/"post-provision-comparison.json",comparisons)
require(comparisons["protectedSimulatorsUnchanged"],"protected simulator metadata changed"); require(comparisons["protectedPixelConfigUnchanged"],"protected Pixel config changed"); require(comparisons["onlyExpectedAdditions"],"post-provision device additions/removals differ from exact ownership"); require(comparisons["forwardsUnchanged"],"adb forward table changed during provisioning")
reservations=output/"reservations"; reservations.mkdir()
save(reservations/"ios-primary-and-extra-names.json",{"actor":"ios","sessionId":"candidate5-ios","candidateManifestSHA256":candidate_sha,"runnerHome":str(ios_home),"primaryDevices":[ownership["devices"]["ios26"],ownership["devices"]["ios27"]],"reservedExtraNames":list(EXTRA_IOS),"extraDevicesCreated":False,"protectedSimulatorInventory":str(output/"simulators-before.stdout")})
save(reservations/"android-absent-primary-and-extra-name.json",{"actor":"android","sessionId":"candidate5-android","candidateManifestSHA256":candidate_sha,"runnerHome":str(android_home),"primaryName":AVD,"primaryState":"absent-reserved-for-literal-AND-001","serialChoice":SERIAL,"extraName":EXTRA_ANDROID,"devicesCreated":False,"protectedAndroidInventory":str(output/"avds-before.stdout"),"protectedPixelConfig":json.loads((output/"baseline.json").read_text())["protectedPixelConfig"]})
save(output/"acceptance.json",{"schema":"grantiva.task9.primary-provision.v1","passed":True,"candidateManifestSHA256":candidate_sha,"gateEvidenceSHA256":sha(gate_path),"ownership":ownership,"protectedBaseline":str(output/"baseline.json"),"postProvisionComparison":str(output/"post-provision-comparison.json")})
print(json.dumps(ownership,indent=2))
