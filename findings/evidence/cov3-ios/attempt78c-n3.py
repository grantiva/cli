import json, os, subprocess, sys, threading, time
from pathlib import Path

root, project, other = map(Path, sys.argv[1:])
grantiva = "/Users/kyle/.grantiva-qa/bin/grantiva"
udid = "563907E1-703D-4322-AE5F-FC3B06D03143"
argv = [grantiva, "runner", "start", "--bundle-id", "com.kylebrowning.Landmarks", "--simulator", udid, "--platform", "ios"]
(root / "foreground-command.json").write_text(json.dumps(argv, indent=2))
out = open(root / "foreground.out", "wb")
err = open(root / "foreground.err", "wb")
p = subprocess.Popen(argv, cwd=project, stdout=out, stderr=err, start_new_session=True)
(root / "foreground.pid").write_text(f"{p.pid}\n")
session = project / ".grantiva/session.json"
deadline = time.monotonic() + 90
ready = None
while time.monotonic() < deadline and p.poll() is None:
    try:
        doc = json.loads(session.read_text())
        if doc.get("state") == "ready" and doc.get("udid") == udid and doc.get("port"):
            h = subprocess.run([grantiva, "hierarchy", "--udid", udid, "--format", "json"], cwd=project, capture_output=True)
            (root / "foreground-hierarchy.out").write_bytes(h.stdout)
            (root / "foreground-hierarchy.err").write_bytes(h.stderr)
            (root / "foreground-hierarchy.exit.txt").write_text(f"{h.returncode}\n")
            if h.returncode == 0 and b"Landmarks" in h.stdout:
                ready = doc
                break
    except Exception:
        pass
    time.sleep(.05)
if ready is None:
    if p.poll() is None:
        os.killpg(p.pid, 2)
    raise SystemExit("foreground did not become ready")
(root / "foreground-session-ready.json").write_text(json.dumps(ready, indent=2, sort_keys=True))
runner_pid = int(ready["pid"])
(root / "runner.pid").write_text(f"{runner_pid}\n")

samples = []
sample_log = open(root / "sidecar-samples.jsonl", "w")
done = threading.Event()
def watch():
    while not done.is_set():
        files = {}
        for x in sorted(Path("/tmp/grantiva-sessions").glob(f"{runner_pid}.*")):
            try: files[str(x)] = x.read_text(errors="replace")
            except Exception as e: files[str(x)] = f"<read-error:{e}>"
        sample = {"monotonic": time.monotonic(), "files": files}
        samples.append(sample)
        sample_log.write(json.dumps(sample) + "\n"); sample_log.flush()
        time.sleep(.01)
t = threading.Thread(target=watch, daemon=True)
t.start()
time.sleep(.15)
cmd = [grantiva, "simulator", "teardown", "--udid", udid, "--force", "--json"]
(root / "teardown-command.json").write_text(json.dumps(cmd, indent=2))
with open(root / "teardown.out", "wb") as tout, open(root / "teardown.err", "wb") as terr:
    teardown = subprocess.run(cmd, cwd=other, stdout=tout, stderr=terr)
(root / "teardown.exit.txt").write_text(f"{teardown.returncode}\n")
try:
    rc = p.wait(timeout=30)
except subprocess.TimeoutExpired:
    (root / "foreground-timeout.txt").write_text("not killed; manual review required\n")
    raise
finally:
    done.set(); t.join(); sample_log.close(); out.close(); err.close()
(root / "foreground.exit.txt").write_text(f"{rc}\n")
(root / "sidecar-samples.json").write_text(json.dumps(samples, indent=2))
(root / "sidecars-final.txt").write_text("\n".join(str(x) for x in sorted(Path("/tmp/grantiva-sessions").glob(f"{runner_pid}.*"))) + "\n")
observed_owner = any(any(k.endswith(f"/{runner_pid}.owner.json") for k in x["files"]) for x in samples)
observed_stop = any(any(k.endswith(f"/{runner_pid}.stop.json") for k in x["files"]) for x in samples)
(root / "sidecar-observation.json").write_text(json.dumps({"owner": observed_owner, "stop": observed_stop, "final": sorted(str(x) for x in Path("/tmp/grantiva-sessions").glob(f"{runner_pid}.*"))}, indent=2))
if not observed_owner or not observed_stop or any(Path("/tmp/grantiva-sessions").glob(f"{runner_pid}.*")):
    raise SystemExit("required owner/stop sidecar lifecycle not observed")
if teardown.returncode != 0 or rc != 0:
    raise SystemExit(f"teardown={teardown.returncode} foreground={rc}")
