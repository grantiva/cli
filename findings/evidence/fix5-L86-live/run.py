import pathlib,subprocess,json,os,time,tempfile,hashlib,concurrent.futures
ROOT=pathlib.Path(__file__).resolve().parent
WT=pathlib.Path('/Users/kyle/Developer/grantiva-cli/.worktrees/fix5-twin-ownership')
CLI=str(WT/'.build/debug/grantiva'); HOME=pathlib.Path(tempfile.mkdtemp(prefix='grantiva-fix5-live-'))/'runner-home'
ENV=os.environ.copy();ENV.pop('GRANTIVA_API_KEY',None);ENV.update(GRANTIVA_RUNNER_HOME=str(HOME),MAESTRO_RUNNER_HOME=str(HOME),GRANTIVA_SESSION_ID='fix5-L86-live')
CWD=tempfile.mkdtemp(prefix='grantiva-fix5-live-cwd-')
EXPECTED='77aa2a63064afc3a68d9ea71232f46e1937ba2ff'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=WT,text=True).strip()==EXPECTED
assert not subprocess.check_output(['git','diff','HEAD','--','Sources','Tests'],cwd=WT)
SHA=hashlib.sha256(pathlib.Path(CLI).read_bytes()).hexdigest()
(ROOT/'provenance.json').write_text(json.dumps({'source':EXPECTED,'binary':CLI,'binarySHA256':SHA,'runnerHome':str(HOME),'session':'fix5-L86-live','cwd':CWD,'names':['fix5-L86-owned','fix5-L86-manual'],'ownedIterations':5,'maxLiveExtras':2,'apiKey':'unset'},indent=2))
def run(label,args,timeout=120):
 d=ROOT/label;d.mkdir();start={'argv':args,'cwd':CWD,'started':time.time(),'environment':{k:ENV.get(k) for k in ['GRANTIVA_RUNNER_HOME','MAESTRO_RUNNER_HOME','GRANTIVA_SESSION_ID','GRANTIVA_API_KEY']}}
 (d/'start.json').write_text(json.dumps(start,indent=2))
 timed=False
 with (d/'stdout.raw').open('wb') as so,(d/'stderr.raw').open('wb') as se:
  p=subprocess.Popen(args,cwd=CWD,env=ENV,stdin=subprocess.DEVNULL,stdout=so,stderr=se)
  (d/'pid.json').write_text(json.dumps({'pid':p.pid,'argv':args,'started':start['started']}))
  try:code=p.wait(timeout)
  except subprocess.TimeoutExpired:
   timed=True;p.terminate()
   try:code=p.wait(5)
   except subprocess.TimeoutExpired:p.kill();code=p.wait(5)
 (d/'result.json').write_text(json.dumps({'exit':code,'timedOut':timed,'ended':time.time()},indent=2))
 assert code==0 and not timed,(label,code,timed)
 return (d/'stdout.raw').read_text()
def inventory(label):
 doc=json.loads(run(label,['xcrun','simctl','list','devices','--json']))
 return {d['udid']:{'runtime':rt,**d} for rt,ds in doc['devices'].items() for d in ds}
before=inventory('before');protected=['B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6'];assert not any(d['name'] in ['fix5-L86-owned','fix5-L86-manual'] for d in before.values())
owned=[];results=[]
for i in range(5):
 uid=run(f'{i}-create',[CLI,'simulator','ensure','--name','fix5-L86-owned','--device-type','iPhone 17','--runtime','26.0','--no-boot']).strip();assert uid not in before
 owned.append(uid);(ROOT/f'{i}-ownership.json').write_text(json.dumps({'uuid':uid,'name':'fix5-L86-owned','createdBy':'exact no-boot command','session':'fix5-L86-live'}))
 args=[CLI,'simulator','ensure','--name','fix5-L86-owned','--runtime','26.0','--json']
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  jobs=[pool.submit(run,f'{i}-ensure-{j}',args,180) for j in range(2)]
  responses=[json.loads(j.result()) for j in jobs]
 assert all(r['udid']==uid and r['state']=='Booted' for r in responses)
 state=inventory(f'{i}-booted');assert state[uid]['state']=='Booted'
 ledger=HOME/'simulator-capacity/sessions.json';raw=ledger.read_bytes();(ROOT/f'{i}-sessions.json').write_bytes(raw)
 records=json.loads(raw);match=[r for r in records if r['udid']==uid];assert len(match)==1 and match[0]['bootedByGrantiva'] is True
 run(f'{i}-teardown',[CLI,'simulator','teardown','--udid',uid,'--json'])
 assert uid not in inventory(f'{i}-after')
 results.append({'iteration':i,'uuid':uid,'bothEnsuresBooted':True,'ownedBootFlag':True,'absentAfterTeardown':True});print('owned iteration',i+1,'passed',flush=True)
manual=run('manual-create',['xcrun','simctl','create','fix5-L86-manual','com.apple.CoreSimulator.SimDeviceType.iPhone-17','com.apple.CoreSimulator.SimRuntime.iOS-26-0']).strip();assert manual not in before
(ROOT/'manual-ownership.json').write_text(json.dumps({'uuid':manual,'createdBy':'root simctl','purpose':'manual-origin control'}))
run('manual-boot',['xcrun','simctl','boot',manual]);run('manual-bootstatus',['xcrun','simctl','bootstatus',manual,'-b'],180)
run('manual-ensure',[CLI,'simulator','ensure','--name','fix5-L86-manual','--json'])
run('manual-teardown',[CLI,'simulator','teardown','--udid',manual,'--json']);assert inventory('manual-after-teardown')[manual]['state']=='Booted'
run('manual-owned-cleanup-shutdown',['xcrun','simctl','shutdown',manual]);run('manual-owned-cleanup-delete',[CLI,'simulator','delete','--name',manual])
after=inventory('final');assert all(u not in after for u in owned+[manual])
for u in protected:assert all(before[u][k]==after[u][k] for k in ['name','runtime','state','deviceTypeIdentifier'])
assert hashlib.sha256(pathlib.Path(CLI).read_bytes()).hexdigest()==SHA
(ROOT/'acceptance.json').write_text(json.dumps({'status':'PASS','ownedIterations':results,'manualOriginKeptBootedByTeardown':True,'manualRootCleanupComplete':True,'protectedStatePreserved':True,'binaryUnchanged':True},indent=2))
print('all live acceptance and owned cleanup passed',flush=True)
