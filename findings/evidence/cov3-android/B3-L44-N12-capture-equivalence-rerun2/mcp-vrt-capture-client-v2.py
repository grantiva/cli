#!/usr/bin/env python3
"""Interactive MCP capture: keep stdin open until the matching response."""
import json, pathlib, queue, subprocess, sys, threading, time

out, project, grantiva = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
out.mkdir(parents=True, exist_ok=False)
p = subprocess.Popen([grantiva,"mcp","--project-dir",str(project),"--platform","android"],
    cwd=project, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    text=True, bufsize=1)
stderr=[]
def drain():
    for line in p.stderr: stderr.append(line)
threading.Thread(target=drain,daemon=True).start()
sent=[]; received=[]
def send(x):
    line=json.dumps(x,separators=(",",":")); sent.append(line); p.stdin.write(line+"\n"); p.stdin.flush()
def read_id(want, timeout=180):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        line=p.stdout.readline()
        if not line:
            if p.poll() is not None: break
            continue
        received.append(line)
        try: doc=json.loads(line)
        except json.JSONDecodeError: continue
        if doc.get("id")==want: return doc
    raise RuntimeError(f"no response for {want}; exit={p.poll()}")

send({"jsonrpc":"2.0","id":"init-l44-n12-v2","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-l44-n12-v2","version":"1"}}})
read_id("init-l44-n12-v2",30)
send({"jsonrpc":"2.0","method":"notifications/initialized","params":{}})
send({"jsonrpc":"2.0","id":"capture-l44-n12-v2","method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}})
capture=read_id("capture-l44-n12-v2",180)
(out/"stdin.raw").write_text("\n".join(sent)+"\n")
(out/"stdout.raw").write_text("".join(received))
(out/"responses.json").write_text(json.dumps([json.loads(x) for x in received if x.lstrip().startswith("{")],indent=2)+"\n")
content=capture.get("result",{}).get("content",[])
text=next((x.get("text") for x in content if x.get("type")=="text"),None)
if not text: raise SystemExit(2)
decoded=json.loads(text); (out/"capture.json").write_text(json.dumps(decoded,indent=2)+"\n")
if len(decoded.get("screens",[]))!=5: raise SystemExit(3)
p.stdin.close()
try: code=p.wait(timeout=10)
except subprocess.TimeoutExpired:
    p.terminate(); code=p.wait(timeout=10)
(out/"stderr.raw").write_text("".join(stderr)); (out/"server.exit").write_text(f"{code}\n")
