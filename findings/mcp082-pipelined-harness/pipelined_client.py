#!/usr/bin/env python3
"""MCP-082: queue tools/list while grantiva_context owns a platform child."""
import json, os, queue, subprocess, sys, threading, time
from pathlib import Path

out = Path(sys.argv[1]); project = sys.argv[2]; platform = sys.argv[3]; binary = sys.argv[4]
out.mkdir(parents=True, exist_ok=False)
stderr_file = open(out / "server.stderr", "wb")
env = os.environ.copy(); env["GRANTIVA_LOG_LEVEL"] = "debug"
p = subprocess.Popen([binary, "mcp", "--project-dir", project, "--platform", platform],
                     cwd=project, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=stderr_file, bufsize=0)
(out / "server.pid").write_text(f"{p.pid}\n")
raw = open(out / "stdout.raw", "wb"); events = open(out / "events.jsonl", "w")
q = queue.Queue()
def read_stdout():
    for line in p.stdout:
        raw.write(line); raw.flush(); q.put(line)
    q.put(None)
threading.Thread(target=read_stdout, daemon=True).start()

def emit(kind, **fields):
    fields.update(kind=kind, wall=time.time(), monotonic=time.monotonic())
    events.write(json.dumps(fields, sort_keys=True) + "\n"); events.flush()
def write_many(objects, label):
    payload = b"".join((json.dumps(o, separators=(",", ":")) + "\n").encode() for o in objects)
    p.stdin.write(payload); p.stdin.flush(); emit("write", label=label, bytes=len(payload), ids=[o.get("id") for o in objects])
def wait_ids(wanted, timeout):
    found = {}; deadline = time.monotonic() + timeout
    while wanted - found.keys() and time.monotonic() < deadline:
        try: line = q.get(timeout=max(.001, min(.1, deadline-time.monotonic())))
        except queue.Empty: continue
        if line is None: break
        try: obj = json.loads(line)
        except Exception as exc: emit("nonjson", text=line.decode(errors="replace"), error=str(exc)); continue
        emit("response", id=obj.get("id"), response=obj)
        if obj.get("id") in wanted: found[obj["id"]] = obj
    return found

initialize = {"jsonrpc":"2.0","id":"mcp082-init","method":"initialize","params":{}}
write_many([initialize], "initialize")
responses = wait_ids({"mcp082-init"}, 30)
if "mcp082-init" not in responses: raise SystemExit("initialize response missing")

sampling = True
def sample_descendants():
    seen = set(); target = out / "subprocess-poll.txt"
    while sampling:
        cp = subprocess.run(["ps", "-axo", "pid=,ppid=,etime=,command="],
                            stdin=subprocess.DEVNULL, capture_output=True, text=True)
        rows = []
        for line in cp.stdout.splitlines():
            parts = line.strip().split(None, 3)
            if len(parts) == 4 and parts[0].isdigit() and parts[1].isdigit():
                rows.append((int(parts[0]), int(parts[1]), parts[2], parts[3]))
        descendants = {p.pid}; changed = True
        while changed:
            changed = False
            for pid, ppid, _, _ in rows:
                if ppid in descendants and pid not in descendants:
                    descendants.add(pid); changed = True
        for row in rows:
            if row[0] in descendants and row[0] != p.pid:
                rendered = "%d %d %s %s" % row
                if rendered not in seen:
                    seen.add(rendered); target.open("a").write(rendered + "\n")
        time.sleep(.002)
sampler = threading.Thread(target=sample_descendants, daemon=True); sampler.start()

# One write and one flush are the essential proof: tools/list is already queued
# on MCP stdin before the server can finish grantiva_context's simctl/adb child.
context = {"jsonrpc":"2.0","id":f"mcp082-{platform}-context","method":"tools/call",
           "params":{"name":"grantiva_context","arguments":{}}}
listed = {"jsonrpc":"2.0","id":f"mcp082-{platform}-list","method":"tools/list","params":{}}
write_many([context, listed], "pipelined-context-then-list")
responses.update(wait_ids({context["id"], listed["id"]}, 120))
sampling = False; sampler.join(timeout=2)
json.dump(responses, open(out / "responses.json", "w"), indent=2, sort_keys=True)
missing = [x for x in (context["id"], listed["id"]) if x not in responses]
emit("final", missing=missing, server_alive=p.poll() is None)
p.stdin.close()
try: p.wait(timeout=10)
except subprocess.TimeoutExpired: p.terminate(); p.wait(timeout=10)
stderr_file.close(); raw.close(); events.close()
if missing: raise SystemExit("missing responses: " + ",".join(missing))
