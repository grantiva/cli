import http.server,json,os,subprocess,threading,time,urllib.request,urllib.error
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5')
session=Path(s['project'])/'.grantiva/session.json';original=session.read_bytes();data=json.loads(original);upstream=data['wdaPort'];records=[]
class Proxy(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):self.forward()
 def do_POST(self):self.forward()
 def forward(self):
  body=self.rfile.read(int(self.headers.get('Content-Length',0)))
  req=urllib.request.Request('http://127.0.0.1:'+str(upstream)+self.path,data=body or None,method=self.command,headers={'Content-Type':'application/json'})
  started=time.monotonic()
  try:
   with urllib.request.urlopen(req,timeout=20) as result:status=result.status;response=result.read()
  except urllib.error.HTTPError as e:status=e.code;response=e.read()
  records.append({'method':self.command,'path':self.path,'body':body.decode(),'status':status,'response':response.decode(),'monotonic':started})
  self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(response)));self.end_headers();self.wfile.write(response)
proxy=http.server.ThreadingHTTPServer(('127.0.0.1',0),Proxy);thread=threading.Thread(target=proxy.serve_forever,daemon=True);thread.start();c=None
try:
 data['wdaPort']=proxy.server_port;data['port']=proxy.server_port;session.write_text(json.dumps(data))
 c=Client(s['binary'],s['project'],'ios',r/'ios-retry')
 response=c.tool('grantiva_a11y_tree',{});assert not response['result'].get('isError'),response
 subprocess.run(['xcrun','simctl','terminate',s['udid'],'com.kylebrowning.Landmarks'],check=True,capture_output=True)
 start=len(records);began=time.monotonic();response=c.tool('grantiva_tap',{'label':'Favorites'});elapsed=time.monotonic()-began
 text=c.text(response);assert response['result'].get('isError') and 'is not running' in text,response
 finds=[v for v in records[start:] if v['path'].endswith('/elements')]
 assert len(finds)==2 and all(v['status']==400 for v in finds),finds
 assert finds[1]['monotonic']-finds[0]['monotonic']>=1,(finds,elapsed)
 print(json.dumps({'passed':True,'lookups':len(finds),'elapsed':elapsed,'text':text}),flush=True)
 (r/'ios-retry-checks.json').write_text(json.dumps({'passed':True,'lookups':len(finds),'elapsed':elapsed,'text':text,'proxyPort':proxy.server_port},indent=2)+'\n')
finally:
 session.write_bytes(original)
 if c:c.close()
 proxy.shutdown();proxy.server_close();thread.join()
 (r/'ios-retry-http.json').write_text(json.dumps(records,indent=2)+'\n')
