import json, subprocess, sys, threading, queue, time, os
# usage: client.py <requests.json> <outdir> [cwd] -- grantiva mcp args...
reqs = json.load(open(sys.argv[1])); outdir = sys.argv[2]; cwd = sys.argv[3]
cmd = sys.argv[sys.argv.index('--')+1:]
os.makedirs(outdir, exist_ok=True)
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(outdir,'server.stderr'),'w'), cwd=cwd)
open(os.path.join(outdir, 'server.pid'), 'w').write(str(p.pid) + '\n')
q = queue.Queue()
raw = open(os.path.join(outdir,'stdout.raw'),'w')
def reader():
    for line in p.stdout:
        line=line.decode(errors='replace'); raw.write(line); raw.flush(); q.put(line)
    q.put(None)
threading.Thread(target=reader, daemon=True).start()
send_lock = threading.Lock()
def send(obj):
    with send_lock:
        p.stdin.write((json.dumps(obj)+"\n").encode()); p.stdin.flush()
log = open(os.path.join(outdir,'transcript.txt'),'w')
nonjson = 0
def trunc(o):
    s = json.dumps(o)
    import re
    s = re.sub(r'"data": "([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]*"', lambda m: '"data": "%s...<b64 len>"'%m.group(1)[:40], s)
    s = re.sub(r'"blob": "([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]*"', lambda m: '"blob": "%s...<b64>"'%m.group(1)[:40], s)
    return s[:4000]
i = 0
shell_i = 0
tracked_pids = set()
def pstree_text():
    cp = subprocess.run(['ps','-axo','pid=,ppid=,etime=,command='], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    rows=[]
    for line in cp.stdout.splitlines():
        parts=line.strip().split(None,3)
        if len(parts) >= 4:
            try: rows.append((int(parts[0]), int(parts[1]), parts[2], parts[3]))
            except ValueError: pass
    keep={p.pid}
    changed=True
    while changed:
        changed=False
        for pid,ppid,elapsed,command in rows:
            if ppid in keep and pid not in keep:
                keep.add(pid); changed=True
    return '\n'.join('%d %d %s %s' % row for row in rows if row[0] in keep)+'\n'
for r in reqs:
    if '_sleep' in r:
        time.sleep(r['_sleep']); log.write("## sleep %s\n" % r['_sleep']); continue
    if '_shell' in r:
        shell_i += 1
        t0=time.time(); cp=subprocess.run(r['_shell'], shell=True, capture_output=True, text=True, stdin=subprocess.DEVNULL, cwd=cwd)
        stem='shell-%02d' % shell_i
        open(os.path.join(outdir,stem+'.command.txt'),'w').write(r['_shell']+'\n')
        open(os.path.join(outdir,stem+'.out'),'w').write(cp.stdout)
        open(os.path.join(outdir,stem+'.err'),'w').write(cp.stderr)
        open(os.path.join(outdir,stem+'.exit.txt'),'w').write(str(cp.returncode)+'\n')
        log.write("## shell %s [%.1fs] exit=%d: %s\n## stdout-tail: %s\n## stderr-tail: %s\n" % (stem,time.time()-t0,cp.returncode,r['_shell'],cp.stdout[-1500:],cp.stderr[-1500:])); log.flush(); continue
    if '_pstree' in r:
        name='pstree-%s.txt' % r['_pstree']
        tree=pstree_text(); open(os.path.join(outdir,name),'w').write(tree)
        log.write('## pstree %s server_pid=%d -> %s\n' % (r['_pstree'],p.pid,name)); log.flush(); continue
    if '_tracked_ps' in r:
        cp=subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True,stdin=subprocess.DEVNULL)
        selected=[]
        for line in cp.stdout.splitlines():
            parts=line.strip().split(None,4)
            if parts and parts[0].isdigit() and int(parts[0]) in tracked_pids: selected.append(line.strip())
        name='tracked-ps-%s.txt' % r['_tracked_ps']
        open(os.path.join(outdir,name),'w').write('\n'.join(selected)+'\n')
        log.write('## tracked ps %s original_pids=%s survivors=%d -> %s\n' % (r['_tracked_ps'],sorted(tracked_pids),len(selected),name)); log.flush(); continue
    tmo = r.pop('_timeout', 120); save = r.pop('_save', None)
    cancel_after = r.pop('_cancel_after', None)
    if 'id' not in r and r.get('method','').startswith('notifications'):
        send(r); log.write(">> "+json.dumps(r)+"\n"); continue
    i += 1; r['id'] = i; r['jsonrpc'] = '2.0'
    wall0=time.time(); mono0=time.monotonic(); send(r); log.write(">> "+json.dumps(r)+"\n"); log.flush()
    timer=None
    if cancel_after is not None:
        def delayed_cancel(request_id=i, delay=float(cancel_after), started=mono0):
            # Sample the real MCP-server process tree shortly before cancellation,
            # then send cancellation at the monotonic 200 ms deadline. The event
            # log records observed timing instead of asserting scheduler precision.
            pre_deadline = started + max(0.0, delay - 0.05)
            time.sleep(max(0.0, pre_deadline-time.monotonic()))
            pre_elapsed=time.monotonic()-started
            tree=pstree_text(); open(os.path.join(outdir,'pstree-before-cancel.txt'),'w').write(tree)
            for line in tree.splitlines():
                parts=line.strip().split(None,1)
                if parts and parts[0].isdigit() and int(parts[0]) != p.pid: tracked_pids.add(int(parts[0]))
            json.dump(sorted(tracked_pids),open(os.path.join(outdir,'tracked-pids.json'),'w'))
            deadline=started+delay
            time.sleep(max(0.0, deadline-time.monotonic()))
            sent_wall=time.time(); sent_elapsed=time.monotonic()-started
            send({'jsonrpc':'2.0','method':'notifications/cancelled','params':{'requestId':request_id,'reason':'round3 delayed build cancellation'}})
            post_elapsed=time.monotonic()-started
            open(os.path.join(outdir,'pstree-immediately-after-cancel.txt'),'w').write(pstree_text())
            # Take the cleanup snapshot on this monotonic schedule, independent
            # of the deliberately suppressed JSON-RPC response.
            cleanup_deadline=started+delay+5.0
            time.sleep(max(0.0,cleanup_deadline-time.monotonic()))
            cleanup_elapsed=time.monotonic()-started
            cp=subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True,stdin=subprocess.DEVNULL)
            selected=[]
            for line in cp.stdout.splitlines():
                parts=line.strip().split(None,4)
                if parts and parts[0].isdigit() and int(parts[0]) in tracked_pids: selected.append(line.strip())
            open(os.path.join(outdir,'tracked-ps-five-seconds-after-cancel.txt'),'w').write('\n'.join(selected)+'\n')
            json.dump({'requestId':request_id,'requestedDelaySeconds':delay,'preSnapshotElapsedSeconds':pre_elapsed,'cancelSentElapsedSeconds':sent_elapsed,'postSnapshotStartedElapsedSeconds':post_elapsed,'fiveSecondSnapshotElapsedSeconds':cleanup_elapsed,'trackedPids':sorted(tracked_pids),'trackedSurvivorsAtFiveSeconds':len(selected),'cancelSentWallTime':sent_wall},open(os.path.join(outdir,'cancel-timing.json'),'w'),indent=2)
        timer=threading.Thread(target=delayed_cancel,daemon=True); timer.start()
    got=None
    deadline=mono0+tmo
    while time.monotonic() < deadline:
        try: line = q.get(timeout=min(0.05,max(0.001,deadline-time.monotonic())))
        except queue.Empty:
            if p.poll() is not None: break
            continue
        if line is None: break
        try: obj=json.loads(line)
        except Exception: nonjson+=1; log.write("!! NON-JSON STDOUT: "+line[:300]+"\n"); continue
        if obj.get('id')==i: got=obj; break
        log.write("<< (other) "+trunc(obj)+"\n")
    dt=time.monotonic()-mono0
    if timer: timer.join(timeout=8)
    log.write("<< [%.1fs @%s] %s\n" % (dt, time.strftime("%H:%M:%S"), trunc(got) if got else "NO RESPONSE (server alive=%s)" % (p.poll() is None)))
    log.flush()
    if save and got: json.dump(got, open(os.path.join(outdir, save),'w'))
log.write("nonjson_lines=%d server_alive=%s\n" % (nonjson, p.poll() is None))
p.stdin.close()
try: p.wait(timeout=10)
except Exception: p.kill()
log.write("exit=%s\n" % p.returncode)
