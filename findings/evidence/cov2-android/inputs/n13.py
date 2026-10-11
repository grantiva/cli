import json, subprocess, sys, time, os, threading, queue
# n13.py <projdir> <outdir>: MCP server first; no-session calls; runner start --detach; immediately poll the 7 session tools;
# then replace the session (stop + start) and poll again.
proj, out = sys.argv[1], sys.argv[2]; G = os.environ['GRANTIVA']; os.makedirs(out, exist_ok=True)
log = open(os.path.join(out, 'transcript.txt'), 'w')
p = subprocess.Popen([G, 'mcp', '--project-dir', proj], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(out, 'server.stderr'), 'w'), cwd=proj)
q = queue.Queue()
threading.Thread(target=lambda: [q.put(l) for l in p.stdout], daemon=True).start()
nid = [0]
def call(method, params=None, tmo=60):
    nid[0] += 1; i = nid[0]; m = {"jsonrpc": "2.0", "id": i, "method": method}
    if params is not None: m["params"] = params
    p.stdin.write((json.dumps(m) + "\n").encode()); p.stdin.flush(); t0 = time.time()
    while time.time() - t0 < tmo:
        try: l = q.get(timeout=1)
        except queue.Empty: continue
        o = json.loads(l)
        if o.get("id") == i:
            s = json.dumps(o); 
            import re; s = re.sub(r'"data": "[^"]{60}[^"]*"', '"data": "<b64>"', s)
            log.write("[%.2f] >> %s %s\n<< %s\n" % (time.time() - T0, method, json.dumps(params)[:80], s[:400])); log.flush(); return o
    log.write("NO RESPONSE %s\n" % method); return None
def sh(cmd):
    r = subprocess.run(cmd, shell=True, cwd=proj, capture_output=True, text=True)
    log.write("[%.2f] $ %s -> rc=%d\n%s%s\n" % (time.time() - T0, cmd, r.returncode, r.stdout[-500:], r.stderr[-500:])); log.flush()
T0 = time.time()
call("initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "qa", "version": "1"}})
p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n'); p.stdin.flush()
tools = [("grantiva_screenshot", {}), ("grantiva_tap", {"label": "Landmarks"}), ("grantiva_swipe", {"direction": "up"}), ("grantiva_type", {"text": "x"}), ("grantiva_a11y_tree", {}), ("grantiva_a11y_check", {}), ("grantiva_script", {"steps": [{"wait": 0.1}]})]
def poll(tag):
    log.write("--- %s\n" % tag)
    for rnd in range(30):
        res = [call("tools/call", {"name": n, "arguments": a}) for n, a in tools]
        ok = [r is not None and "error" not in r and not r["result"].get("isError") for r in res]
        rpc = [r is not None and "error" in r for r in res]
        log.write("round %d ok=%s rpc_error=%s\n" % (rnd, ok, rpc)); log.flush()
        if all(ok): return rnd
    return -1
poll("no session (expect isError, never rpc error)") if False else None
for n, a in tools: call("tools/call", {"name": n, "arguments": a})
sh("$GRANTIVA runner start --detach")
r1 = poll("after runner start")
sh("$GRANTIVA runner stop"); sh("$GRANTIVA runner start --detach")
r2 = poll("after replacement")
log.write("rounds_until_all_ok first=%d replaced=%d\n" % (r1, r2))
p.stdin.close(); p.wait(timeout=20); log.write("server exit %s\n" % p.returncode)
