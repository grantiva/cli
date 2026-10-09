"""Minimal MCP stdio client: one server per request, reports response, latency, hang.
usage: python3 -I client.py <grantiva> <project-dir> <platform> <calls.jsonl> <timeout-s> <out.jsonl>"""
import json, subprocess, sys, time, select, os
g, d, plat, calls, tmo, outp = sys.argv[1:7]; tmo = float(tmo)
out = open(outp, "w")
for line in open(calls):
    req = json.loads(line)
    args = [g, "mcp", "--project-dir", d] + ([] if plat == "-" else ["--platform", plat])
    p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    def send(m): p.stdin.write((json.dumps(m) + "\n").encode()); p.stdin.flush()
    buf = b""; got = {}
    def wait_for(i, limit):
        global buf
        end = time.time() + limit
        while time.time() < end and i not in got:
            r, _, _ = select.select([p.stdout], [], [], 0.2)
            if r:
                chunk = os.read(p.stdout.fileno(), 1 << 20)
                if not chunk: break
                buf += chunk
                while b"\n" in buf:
                    l, buf = buf.split(b"\n", 1)
                    try:
                        m = json.loads(l)
                        if "id" in m: got[m["id"]] = m
                    except Exception:
                        got.setdefault("garbage", []).append(l[:200].decode(errors="replace"))
        return got.get(i)
    t0 = time.time()
    try:
        send({"jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "qa", "version": "1"}}})
        init = wait_for(0, 20)
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        t1 = time.time(); send(req); resp = wait_for(req["id"], tmo); dt = time.time() - t1
    except BrokenPipeError:
        init = None; resp = None; dt = 0
    try: p.stdin.close()
    except Exception: pass
    try: p.wait(10)
    except subprocess.TimeoutExpired: p.kill(); p.wait()
    err = p.stderr.read().decode(errors="replace")[-400:]
    rec = {"id": req["id"], "tool": req["params"].get("name"), "args": req["params"].get("arguments"),
           "init_ok": init is not None, "seconds": round(dt, 2), "hang": resp is None and init is not None,
           "response": resp, "exit": p.returncode, "stderr_tail": err, "garbage": got.get("garbage")}
    out.write(json.dumps(rec) + "\n"); out.flush()
    r = resp or {}
    res = r.get("result", {})
    txt = (res.get("content") or [{}])[0].get("text", "") if isinstance(res, dict) else ""
    kind = "rpc-error" if "error" in r else ("isError" if res.get("isError") else ("ok" if r else "NO-RESPONSE"))
    print(f'{req["id"]}\t{req["params"].get("name")}\t{kind}\t{rec["seconds"]}s\t{(r.get("error",{}).get("message") or txt)[:150]!r}', flush=True)
