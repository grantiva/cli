import json, subprocess, sys, threading, queue, time, os
# usage: client.py <requests.json> <outdir> [cwd] -- grantiva mcp args...
reqs = json.load(open(sys.argv[1])); outdir = sys.argv[2]; cwd = sys.argv[3]
cmd = sys.argv[sys.argv.index('--')+1:]
os.makedirs(outdir, exist_ok=True)
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(outdir,'server.stderr'),'w'), cwd=cwd)
q = queue.Queue()
raw = open(os.path.join(outdir,'stdout.raw'),'w')
def reader():
    for line in p.stdout:
        line=line.decode(errors='replace'); raw.write(line); raw.flush(); q.put(line)
    q.put(None)
threading.Thread(target=reader, daemon=True).start()
def send(obj): p.stdin.write((json.dumps(obj)+"\n").encode()); p.stdin.flush()
log = open(os.path.join(outdir,'transcript.txt'),'w')
nonjson = 0
def trunc(o):
    s = json.dumps(o)
    import re
    s = re.sub(r'"data": "([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]*"', lambda m: '"data": "%s...<b64 len>"'%m.group(1)[:40], s)
    s = re.sub(r'"blob": "([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]*"', lambda m: '"blob": "%s...<b64>"'%m.group(1)[:40], s)
    return s[:4000]
i = 0
for r in reqs:
    tmo = r.pop('_timeout', 120); save = r.pop('_save', None)
    if 'id' not in r and r.get('method','').startswith('notifications'):
        send(r); log.write(">> "+json.dumps(r)+"\n"); continue
    i += 1; r['id'] = i; r['jsonrpc'] = '2.0'
    t0=time.time(); send(r); log.write(">> "+json.dumps(r)+"\n"); log.flush()
    got=None
    while time.time()-t0 < tmo:
        try: line = q.get(timeout=1)
        except queue.Empty:
            if p.poll() is not None: break
            continue
        if line is None: break
        try: obj=json.loads(line)
        except Exception: nonjson+=1; log.write("!! NON-JSON STDOUT: "+line[:300]+"\n"); continue
        if obj.get('id')==i: got=obj; break
        log.write("<< (other) "+trunc(obj)+"\n")
    dt=time.time()-t0
    log.write("<< [%.1fs] %s\n" % (dt, trunc(got) if got else "NO RESPONSE (server alive=%s)" % (p.poll() is None)))
    log.flush()
    if save and got: json.dump(got, open(os.path.join(outdir, save),'w'))
log.write("nonjson_lines=%d server_alive=%s\n" % (nonjson, p.poll() is None))
p.stdin.close()
try: p.wait(timeout=10)
except Exception: p.kill()
log.write("exit=%s\n" % p.returncode)
