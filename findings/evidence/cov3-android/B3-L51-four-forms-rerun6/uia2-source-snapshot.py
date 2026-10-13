#!/usr/bin/env python3
"""Read one UIAutomator2 hierarchy through the row's existing adb forward."""
import json, pathlib, re, subprocess, sys, time, urllib.request

serial, client_log, out = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=False)
deadline=time.monotonic()+30; sid=None; host_port=None; forwards=""
while time.monotonic()<deadline:
    text=client_log.read_text(errors="replace") if client_log.exists() else ""
    ids=re.findall(r"/session/([0-9A-Za-z-]+)(?:/|\b)",text)
    sid=ids[-1] if ids else None
    forwards=subprocess.run(["adb","forward","--list"],text=True,capture_output=True,check=True).stdout
    for line in forwards.splitlines():
        p=line.split()
        if len(p)>=3 and p[0]==serial and p[2]=="tcp:6790" and p[1].startswith("tcp:"):
            host_port=p[1][4:]
    if sid and host_port: break
    time.sleep(.1)
if not sid or not host_port: raise SystemExit(75)
url=f"http://127.0.0.1:{host_port}/session/{sid}/source"
started=time.time_ns()
with urllib.request.urlopen(url,timeout=20) as response:
    body=response.read(); status=response.status; headers=dict(response.headers.items())
ended=time.time_ns()
(out/"adb-forward-list.txt").write_text(forwards)
(out/"url.txt").write_text(url+"\n")
(out/"response.raw").write_bytes(body)
doc=json.loads(body); value=doc.get("value")
if not isinstance(value,str) or "<hierarchy" not in value: raise SystemExit(76)
(out/"hierarchy.xml").write_text(value)
(out/"metadata.json").write_text(json.dumps({"serial":serial,"sessionId":sid,"hostPort":int(host_port),"url":url,"httpStatus":status,"headers":headers,"startedNs":started,"endedNs":ended,"elapsedMs":(ended-started)/1e6},indent=2)+"\n")
