import json,sys
for ln in open(sys.argv[1]):
    ln=ln.strip()
    if not ln: continue
    try: m=json.loads(ln)
    except Exception as e: print("NONJSON:",ln[:200]); continue
    i=m.get("id")
    if "error" in m: print(f"id={i} JSONRPC-ERROR {json.dumps(m['error'])[:300]}"); continue
    r=m.get("result",{})
    if "tools" in r: print(f"id={i} tools/list {len(r['tools'])} tools"); continue
    if "serverInfo" in r: print(f"id={i} initialize {r['serverInfo']}"); continue
    txt=" | ".join(c.get("text","<%s>"%c.get("type")) for c in r.get("content",[]))
    print(f"id={i} isError={r.get('isError',False)} :: {txt[:600]}")
