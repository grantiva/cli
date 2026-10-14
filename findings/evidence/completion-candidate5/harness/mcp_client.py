import json, pathlib, subprocess, threading, time

class Client:
    def __init__(self, binary, project, platform, evidence):
        self.root=pathlib.Path(evidence); self.root.mkdir(parents=True,exist_ok=False)
        self.raw=(self.root/'stdout.raw').open('wb'); self.err=(self.root/'stderr.raw').open('wb'); self.requests=(self.root/'requests.jsonl').open('w')
        self.cv=threading.Condition(); self.messages=[]; self.invalid=[]; self.next_id=1
        argv=[str(binary),'mcp','--project-dir',str(project),'--platform',platform]
        (self.root/'command.json').write_text(json.dumps({'argv':argv,'startedEpoch':time.time()},indent=2)+'\n')
        self.process=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err)
        (self.root/'pid.txt').write_text(str(self.process.pid)+'\n'); self.thread=threading.Thread(target=self._read,daemon=True); self.thread.start()
        self.call('initialize',{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'round4-task8','version':'1'}})
        self.send('notifications/initialized',{},True)
    def _read(self):
        for line in self.process.stdout:
            self.raw.write(line); self.raw.flush()
            with self.cv:
                try:self.messages.append((json.loads(line),len(line)))
                except Exception as exc:self.invalid.append({'bytes':len(line),'error':str(exc)})
                self.cv.notify_all()
    def send(self,method,params,notification=False):
        obj={'jsonrpc':'2.0','method':method,'params':params}
        if not notification: obj['id']=self.next_id; self.next_id+=1
        wire=json.dumps(obj); self.requests.write(wire+'\n'); self.requests.flush(); self.process.stdin.write((wire+'\n').encode()); self.process.stdin.flush(); return obj.get('id')
    def wait(self,request_id,timeout=90):
        deadline=time.monotonic()+timeout
        with self.cv:
            while True:
                found=[m for m,n in self.messages if m.get('id')==request_id]
                if found:
                    if len(found)!=1: raise AssertionError(f'duplicate response {request_id}')
                    return found[0]
                if self.invalid: raise AssertionError(self.invalid)
                left=deadline-time.monotonic()
                if left<=0: raise TimeoutError(request_id)
                self.cv.wait(min(left,1))
    def call(self,method,params): return self.wait(self.send(method,params))
    def tool(self,name,args): return self.call('tools/call',{'name':name,'arguments':args})
    @staticmethod
    def text(reply): return '\n'.join(x.get('text','') for x in reply.get('result',{}).get('content',[]))
    def close(self):
        self.process.stdin.close()
        try:self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:self.process.terminate(); self.process.wait(timeout=10)
        self.thread.join(timeout=3); self.raw.close(); self.err.close(); self.requests.close()
        result={'exit':self.process.returncode,'endedEpoch':time.time(),'invalid':self.invalid,'messages':[{'id':m.get('id'),'method':m.get('method'),'bytes':n} for m,n in self.messages]}
        (self.root/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        if self.invalid: raise AssertionError(self.invalid)
