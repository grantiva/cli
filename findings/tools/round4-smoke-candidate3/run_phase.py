#!/usr/bin/env python3
"""Bounded Task 8 smoke phase executor. Preparation is inert unless --execute is passed."""
import argparse, datetime, hashlib, json, os, pathlib, shutil, subprocess, sys, time
from candidate_identity import validate as validate_identity

PROTECTED = {
    "B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C",
    "FE441EE5-BBFC-4981-B68A-59C0DBCE26D6",
    "AVD:Pixel_8_API_35",
}
FORBIDDEN = ("pkill", "killall", "launchctl kill", "adb kill-server", "xcrun simctl shutdown all")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""): h.update(block)
    return h.hexdigest()

def fail(message): raise SystemExit(f"task-8 harness: {message}")

def subst(value, values):
    if isinstance(value, str):
        for key, replacement in values.items(): value = value.replace("${" + key + "}", str(replacement))
        if "${" in value: fail(f"unresolved parameter in {value!r}")
    return value

def validate(config, phase):
    required = ("candidate_manifest", "ownership_manifest", "candidate_binary", "candidate_bundle", "runner_binary", "runner_home", "evidence_root",
                "controller_root", "ios_udid", "android_serial", "android_avd")
    missing = [k for k in required if not config.get(k)]
    if missing: fail("missing configuration: " + ", ".join(missing))
    for key in ("candidate_binary", "candidate_bundle", "runner_home"):
        p = pathlib.Path(config[key]).resolve()
        if not p.exists(): fail(f"{key} does not exist: {p}")
        config[key] = str(p)
    if pathlib.Path(config["candidate_binary"]).is_dir(): fail("candidate_binary must be a file")
    if config["ios_udid"] in PROTECTED: fail("owned iOS target is a protected device")
    if config["android_avd"] == "Pixel_8_API_35": fail("owned Android AVD is protected")
    if not config["ios_udid"] or not config["android_serial"] or not config["android_avd"].startswith("smoke4-"):
        fail("explicit smoke4 device ownership is required")
    if os.environ.get("GRANTIVA_API_KEY"): fail("GRANTIVA_API_KEY must be unset")
    commands = phase.get("commands", [])
    if not commands: fail("phase has no commands")
    for command in commands:
        if not isinstance(command.get("argv"), list) or not command["argv"]: fail("every argv must be a nonempty array")
        joined = " ".join(map(str, command["argv"]))
        if any(word in joined for word in FORBIDDEN): fail(f"forbidden broad cleanup command: {joined}")
        if any(token in joined for token in PROTECTED): fail(f"protected device referenced: {joined}")
        if command.get("cleanup_pid_file") and not command.get("owned_pid_file"):
            fail("cleanup_pid_file requires an owned_pid_file")
    return config

def assert_one(spec, directory, values):
    spec={k:subst(v,values) if isinstance(v,str) else v for k,v in spec.items()}
    path = directory / spec["path"]
    if spec["type"] == "exists": ok = path.exists()
    elif spec["type"] == "contains": ok = path.exists() and spec["value"] in path.read_text(errors="replace")
    elif spec["type"] == "not_contains": ok = path.exists() and spec["value"] not in path.read_text(errors="replace")
    elif spec["type"] == "json_equals":
        value = json.loads(path.read_text())
        for part in spec["pointer"].strip("/").split("/") if spec["pointer"] != "/" else []: value = value[int(part)] if isinstance(value, list) else value[part]
        ok = value == spec["value"]
    else: fail(f"unknown assertion type {spec['type']}")
    return {**spec, "passed": bool(ok)}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True); ap.add_argument("--phase", required=True)
    ap.add_argument("--execute", action="store_true", help="required to run commands; otherwise validate only")
    args = ap.parse_args(); manifest_path = pathlib.Path(args.manifest).resolve()
    doc = json.loads(manifest_path.read_text()); config = doc["configuration"]
    try: phase = next(p for p in doc["phases"] if p["id"] == args.phase)
    except StopIteration: fail(f"unknown phase {args.phase}")
    validate(config, phase)
    if not args.execute:
        print(json.dumps({"status":"validated-only", "phase":args.phase, "commands":len(phase["commands"]), "criteria":phase["criteria"]}, indent=2)); return
    identity=validate_identity(config['candidate_manifest'],config['ownership_manifest'],source_root=config['controller_root'],binary=config['candidate_binary'],bundle=config['candidate_bundle'],runner=config['runner_binary'],runner_home=config['runner_home'])
    root = pathlib.Path(config["evidence_root"]).resolve(); out = root / args.phase
    if out.exists(): fail(f"refusing to overwrite evidence: {out}")
    out.mkdir(parents=True)
    provenance = {"manifest":str(manifest_path), "manifestSHA256":sha256(manifest_path), **identity,
      "candidateBinary":config["candidate_binary"], "candidateBinarySHA256":sha256(pathlib.Path(config["candidate_binary"])),
      "candidateBundle":config["candidate_bundle"], "runnerHome":config["runner_home"], "iosUDID":config["ios_udid"],
      "androidSerial":config["android_serial"], "androidAVD":config["android_avd"], "apiKey":"unset", "started":datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (out / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    env = os.environ.copy(); env.pop("GRANTIVA_API_KEY", None); env.update(GRANTIVA_RUNNER_HOME=config["runner_home"], MAESTRO_RUNNER_HOME=config["runner_home"], GRANTIVA_SESSION_ID=config["session_id"])
    results=[]
    for index, command in enumerate(phase["commands"], 1):
        label=command["id"]; d=out/f"{index:02d}-{label}"; d.mkdir(); argv=[subst(x,config) for x in command["argv"]]
        (d/"command.json").write_text(json.dumps({"argv":argv,"cwd":subst(command.get("cwd",config["controller_root"]),config),"environment":{k:env.get(k) for k in ("GRANTIVA_RUNNER_HOME","MAESTRO_RUNNER_HOME","GRANTIVA_SESSION_ID","GRANTIVA_API_KEY")}},indent=2)+"\n")
        started=time.time()
        with (d/"stdout.raw").open("wb") as stdout,(d/"stderr.raw").open("wb") as stderr:
            proc=subprocess.run(argv,cwd=subst(command.get("cwd",config["controller_root"]),config),env=env,stdout=stdout,stderr=stderr,timeout=command.get("timeout",600))
        assertions=[assert_one(x,d,config) for x in command.get("assertions",[])]
        result={"id":label,"startedEpoch":started,"endedEpoch":time.time(),"exit":proc.returncode,"expectedExit":command.get("expected_exit",0),"assertions":assertions}
        (d/"result.json").write_text(json.dumps(result,indent=2)+"\n")
        for source in command.get("raw_reports",[]):
            src=pathlib.Path(subst(source,config)); destination=d/"raw-report"/src.name; destination.parent.mkdir(exist_ok=True); shutil.copytree(src,destination) if src.is_dir() else shutil.copy2(src,destination)
        results.append(result)
        if proc.returncode != command.get("expected_exit",0) or not all(x["passed"] for x in assertions): fail(f"{label} failed; inspect {d}")
    (out/"phase-result.json").write_text(json.dumps({"phase":args.phase,"criteria":phase["criteria"],"results":results},indent=2)+"\n")

if __name__ == "__main__": main()
