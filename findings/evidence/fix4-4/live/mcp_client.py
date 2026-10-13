import json, os, pathlib, subprocess, threading, time

class Client:
    def __init__(self, binary, project, platform, directory):
        self.directory=pathlib.Path(directory); self.directory.mkdir(parents=True,exist_ok=True)
        self.raw=(self.directory/'stdout.raw').open('wb'); self.stderr=(self.directory/'stderr.raw').open('wb')
        self.requests=(self.directory/'requests.jsonl').open('w'); self.cv=threading.Condition()
        self.messages=[]; self.invalid=[]; self.nextid=1
        self.process=subprocess.Popen([binary,'mcp','--project-dir',project,'--platform',platform],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.stderr)
        (self.directory/'pid').write_text(str(self.process.pid)+'\n')
        self.thread=threading.Thread(target=self.read,daemon=True);self.thread.start()
        self.call('initialize',{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'fix4-4','version':'1'}})
        self.send('notifications/initialized',{},notification=True)
    def read(self):
        for line in self.process.stdout:
            self.raw.write(line);self.raw.flush()
            with self.cv:
                try:self.messages.append((json.loads(line),len(line)))
                except Exception as error:self.invalid.append({'bytes':len(line),'error':str(error)})
                self.cv.notify_all()
    def send(self,method,params,notification=False):
        obj={'jsonrpc':'2.0','method':method,'params':params}
        if not notification:obj['id']=self.nextid;self.nextid+=1
        text=json.dumps(obj);self.requests.write(text+'\n');self.requests.flush()
        self.process.stdin.write((text+'\n').encode());self.process.stdin.flush()
        return obj.get('id')
    def wait(self,id,timeout=45):
        end=time.monotonic()+timeout
        with self.cv:
            while True:
                matches=[obj for obj,size in self.messages if obj.get('id')==id]
                if matches:
                    assert len(matches)==1,(id,'duplicate response')
                    return matches[0]
                assert not self.invalid,self.invalid
                remaining=end-time.monotonic()
                if remaining<=0:raise TimeoutError(f'ID {id}, process={self.process.poll()}')
                self.cv.wait(min(remaining,1))
    def call(self,method,params):return self.wait(self.send(method,params))
    def tool(self,name,args):return self.call('tools/call',{'name':name,'arguments':args})
    @staticmethod
    def text(response):return '\n'.join(c.get('text','') for c in response.get('result',{}).get('content',[]))
    def close(self):
        self.process.stdin.close()
        try:self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:self.process.terminate();self.process.wait(timeout=10)
        self.thread.join(timeout=3)
        self.raw.close();self.requests.close();self.stderr.close()
        summary={'exit':self.process.returncode,'pid':self.process.pid,'invalid':self.invalid,'records':[{'id':m.get('id'),'method':m.get('method'),'bytes':n} for m,n in self.messages]}
        (self.directory/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        assert not self.invalid,self.invalid
