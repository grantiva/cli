import glob, json, os, pathlib, pty, signal, subprocess, sys, threading, time

root, project, grantiva, serial = sys.argv[1:]
R = pathlib.Path(root)
R.mkdir(parents=True, exist_ok=True)
master, slave = pty.openpty()
argv = [grantiva, "runner", "start", "--platform", "android", "--device", serial,
        "--application-id", "com.kylebrowning.landmarks"]
(R / "command.json").write_text(json.dumps(argv, indent=2) + "\n")
started = time.monotonic()
p = subprocess.Popen(argv, cwd=project, stdin=slave, stdout=slave, stderr=slave,
                     start_new_session=True, close_fds=True)
os.close(slave)
(R / "grantiva-pid.txt").write_text(f"{p.pid}\n")
data = bytearray()

def drain():
    while True:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        data.extend(chunk)

reader = threading.Thread(target=drain, daemon=True)
reader.start()
session_path = pathlib.Path(project) / ".grantiva" / "session.json"
session = None
deadline = started + 120
while time.monotonic() < deadline:
    if p.poll() is not None:
        raise RuntimeError(f"foreground runner start exited early: {p.returncode}")
    try:
        candidate = json.loads(session_path.read_text())
        if (candidate.get("state") == "ready" and candidate.get("platform") == "android"
                and candidate.get("serial") == serial and isinstance(candidate.get("pid"), int)):
            session = candidate
            break
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    time.sleep(.1)
if session is None:
    raise RuntimeError("runner session did not become ready")
(R / "session-ready.json").write_text(json.dumps(session, indent=2) + "\n")
runner_pid = session["pid"]
ps = subprocess.run(["ps", "-o", "pid=,ppid=,command=", "-p", str(runner_pid)],
                    capture_output=True, text=True)
(R / "runner-ps.txt").write_text(ps.stdout)
parts = ps.stdout.strip().split(None, 2)
if (ps.returncode != 0 or len(parts) != 3 or int(parts[0]) != runner_pid
        or int(parts[1]) != p.pid or "grantiva-runner" not in parts[2]
        or "--platform android" not in parts[2] or f"--device {serial}" not in parts[2]):
    raise RuntimeError("runner PID identity guard failed: " + ps.stdout)

def session_inventory(name):
    records = []
    for path in sorted(glob.glob("/tmp/grantiva-sessions/*")):
        try:
            raw = pathlib.Path(path).read_text()
        except (OSError, UnicodeDecodeError):
            continue
        if str(runner_pid) in raw or str(p.pid) in raw or project in raw:
            records.append({"path": path, "raw": raw})
    (R / name).write_text(json.dumps(records, indent=2) + "\n")
    return records

during_records = session_inventory("session-files-during.json")
h_started = time.monotonic()
h = subprocess.run([grantiva, "runner", "dump-hierarchy", "--udid", serial,
                   "--format", "tree"], cwd=project, capture_output=True, text=True,
                   timeout=30)
h_elapsed = time.monotonic() - h_started
(R / "hierarchy.out").write_text(h.stdout)
(R / "hierarchy.err").write_text(h.stderr)
(R / "hierarchy.exit.txt").write_text(f"{h.returncode}\n")
(R / "hierarchy.elapsed.txt").write_text(f"{h_elapsed:.6f}\n")
if h.returncode != 0 or "[hierarchy]" not in h.stdout:
    raise RuntimeError("concurrent hierarchy failed")

# Match the literal 30-second foreground repro and deliver terminal Ctrl-C semantics.
remaining = started + 30.0 - time.monotonic()
if remaining > 0:
    time.sleep(remaining)
(R / "elapsed-before-sigint.txt").write_text(f"{time.monotonic()-started:.6f}\n")
(R / "transcript-before-sigint.txt").write_bytes(data)
os.killpg(p.pid, signal.SIGINT)
try:
    rc = p.wait(timeout=45)
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGTERM)
    rc = p.wait(timeout=10)
reader.join(timeout=3)
try:
    os.close(master)
except OSError:
    pass
(R / "transcript.txt").write_bytes(data)
(R / "exit.txt").write_text(f"{rc}\n")
time.sleep(.5)
after_records = session_inventory("session-files-after.json")
runner_dead = subprocess.run(["kill", "-0", str(runner_pid)], capture_output=True).returncode != 0
post = subprocess.run([grantiva, "runner", "stop"], cwd=project,
                      capture_output=True, text=True, timeout=20)
(R / "post-stop.out").write_text(post.stdout)
(R / "post-stop.err").write_text(post.stderr)
(R / "post-stop.exit.txt").write_text(f"{post.returncode}\n")
text = data.decode(errors="replace")
post_text = (post.stdout + post.stderr).lower()
checks = {
    "foregroundHeld30Seconds": float((R / "elapsed-before-sigint.txt").read_text()) >= 29.9,
    "hierarchyAnsweredMeanwhile": h.returncode == 0 and "[hierarchy]" in h.stdout,
    "terminalOutputStreamed": "grantiva-runner" in text or "UIAutomator2" in text or "Runner" in text,
    "documentedInterruptExit": rc in (0, 130),
    "runnerDead": runner_dead,
    "projectSessionRemoved": not session_path.exists(),
    "ownedGlobalFilesExisted": len(during_records) >= 1,
    "ownedGlobalFilesRemoved": len(after_records) == 0,
    "postStopReportsNoSession": post.returncode == 0 and "no" in post_text
                                and "runner" in post_text and "session" in post_text,
}
(R / "decoded.json").write_text(json.dumps({"checks": checks, "runnerPid": runner_pid,
                                              "foregroundPid": p.pid}, indent=2) + "\n")
print(json.dumps(checks, sort_keys=True))
sys.exit(0 if all(checks.values()) else 1)
