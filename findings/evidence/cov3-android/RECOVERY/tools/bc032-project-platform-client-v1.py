import json, os, pathlib, subprocess, sys, threading, time

root, owner, other, grantiva, serial, mcp_client, request = sys.argv[1:]
R = pathlib.Path(root); R.mkdir(parents=True, exist_ok=True)
ready = R / "ready.json"
report = R / "report"
argv = [grantiva, "run", "--platform", "android", "--device", serial, "--no-build",
        "--keep-alive", "--flow", ".maestro/01-browse.yaml", "--ready-file", str(ready),
        "--report-dir", str(report)]
(R / "owner-command.json").write_text(json.dumps(argv, indent=2) + "\n")
so = open(R / "owner.out", "w"); se = open(R / "owner.err", "w")
p = subprocess.Popen(argv, cwd=owner, stdout=so, stderr=se, text=True)
result = {}
def reap(): result["rc"] = p.wait()
waiter = threading.Thread(target=reap); waiter.start()
try:
    deadline = time.monotonic() + 120
    doc = None
    while time.monotonic() < deadline:
        try:
            candidate = json.loads(ready.read_text())
            if candidate.get("status") == "passed" and p.poll() is None:
                doc = candidate; break
        except (FileNotFoundError, json.JSONDecodeError): pass
        if p.poll() is not None: break
        time.sleep(.1)
    if doc is None: raise RuntimeError("keep-alive did not reach passed hold")
    (R / "ready-before-probes.json").write_text(json.dumps(doc, indent=2) + "\n")
    wrong = subprocess.run([grantiva, "runner", "dump-hierarchy", "--format", "tree"],
                           cwd=other, capture_output=True, text=True, timeout=20)
    (R / "wrong-project.out").write_text(wrong.stdout)
    (R / "wrong-project.err").write_text(wrong.stderr)
    (R / "wrong-project.exit.txt").write_text(f"{wrong.returncode}\n")
    calls = []
    for name, cwd, platform in [("other-android", other, "android"),
                                ("owner-ios", owner, "ios")]:
        out = R / name; out.mkdir()
        call = subprocess.run(["python3", "-I", mcp_client, request, str(out), cwd, "--",
                               grantiva, "mcp", "--project-dir", cwd, "--platform", platform],
                              capture_output=True, text=True, timeout=40)
        (out / "client.out").write_text(call.stdout); (out / "client.err").write_text(call.stderr)
        calls.append((name, call.returncode))
    owner_session = json.loads((pathlib.Path(owner)/".grantiva/session.json").read_text())
    (R / "owner-session-after-probes.json").write_text(json.dumps(owner_session, indent=2)+"\n")
    stop = subprocess.run([grantiva, "runner", "stop", "--json"], cwd=owner,
                          capture_output=True, text=True, timeout=30)
    (R / "stop.json").write_text(stop.stdout); (R / "stop.err").write_text(stop.stderr)
    waiter.join(timeout=30)
    if waiter.is_alive(): raise RuntimeError("owner command was not reaped")
    so.close(); se.close()
    # Context responses must not expose the Android owner's pid outside its project/platform tuple.
    summaries = {}
    for name, _ in calls:
        raw = json.loads((R/name/"context.json").read_text())
        text = raw.get("result",{}).get("content",[{}])[0].get("text","")
        try: decoded = json.loads(text)
        except json.JSONDecodeError: decoded = {"raw": text}
        summaries[name] = decoded
    (R / "decoded-contexts.json").write_text(json.dumps(summaries, indent=2)+"\n")
    owner_pid = owner_session.get("pid")
    checks = {
      "wrongProjectCLIRejected": wrong.returncode != 0 and "session" in (wrong.stdout+wrong.stderr).lower(),
      "mcpCallsSucceeded": all(rc == 0 for _,rc in calls),
      "wrongProjectDoesNotReusePid": str(owner_pid) not in json.dumps(summaries["other-android"]),
      "wrongPlatformDoesNotReusePid": str(owner_pid) not in json.dumps(summaries["owner-ios"]),
      "ownerUnaffectedByProbes": owner_session.get("platform") == "android" and owner_session.get("serial") == serial,
      "stop0": stop.returncode == 0,
      "ownerRunEarned0": result.get("rc") == 0,
      "sessionRemoved": not (pathlib.Path(owner)/".grantiva/session.json").exists(),
    }
    (R / "decoded.json").write_text(json.dumps({"checks":checks,"ownerPid":owner_pid},indent=2)+"\n")
    print(json.dumps(checks,sort_keys=True)); sys.exit(0 if all(checks.values()) else 1)
finally:
    if p.poll() is None:
        subprocess.run([grantiva,"runner","stop","--json"],cwd=owner,capture_output=True,text=True)
    waiter.join(timeout=20)
    so.close(); se.close()
