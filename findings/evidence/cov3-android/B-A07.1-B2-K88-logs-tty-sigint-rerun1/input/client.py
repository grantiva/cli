import json,os,pathlib,pty,select,signal,subprocess,sys,time
root,cwd,grantiva,serial=sys.argv[1:]; R=pathlib.Path(root); R.mkdir(parents=True,exist_ok=True)
def ps(name):
 r=subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],capture_output=True,text=True); (R/name).write_text(r.stdout); return r.stdout
def matching(s): return [x for x in s.splitlines() if 'adb' in x and 'logcat' in x and serial in x]
before=ps('processes-before.txt'); master,slave=pty.openpty(); argv=[grantiva,'run','--platform','android','--device',serial,'--no-build','--logs','--flow','.maestro/11-slow.yaml','--report-dir',str(R/'report')]; json.dump(argv,open(R/'command.json','w'))
p=subprocess.Popen(argv,cwd=cwd,stdin=slave,stdout=slave,stderr=slave,start_new_session=True,close_fds=True); os.close(slave); (R/'grantiva.pid').write_text(str(p.pid)+'\n'); data=bytearray(); active=False; streamed=False; deadline=time.monotonic()+90
while time.monotonic()<deadline and p.poll() is None:
 r,_,_=select.select([master],[],[],.1)
 if r:
  try: chunk=os.read(master,65536)
  except OSError: chunk=b''
  data.extend(chunk); text=data.decode(errors='replace'); streamed=streamed or ('Running' in text and ('launchApp' in text or 'Flow' in text)); active=active or ('Slow Screen' in text or 'extendedWaitUntil' in text or '[1/1]' in text)
 during=ps('processes-during.txt')
 if active and matching(during): break
(R/'transcript-before-sigint.txt').write_bytes(data); (R/'active-detected.txt').write_text(str(active).lower()+'\n'); (R/'streamed-detected.txt').write_text(str(streamed).lower()+'\n'); time.sleep(.3); os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=45)
except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGTERM); rc=p.wait(timeout=10)
end=time.monotonic()+2
while time.monotonic()<end:
 r,_,_=select.select([master],[],[],.1)
 if not r: continue
 try: chunk=os.read(master,65536)
 except OSError: break
 if not chunk: break
 data.extend(chunk)
os.close(master); (R/'transcript.txt').write_bytes(data); (R/'exit.txt').write_text(str(rc)+'\n'); time.sleep(1); after=ps('processes-after.txt')
checks={'ptyIsTerminal':True,'activeFlowDetected':active,'runnerOutputStreamed':streamed,'logcatPresentDuring':len(matching(during))>=1,'exit130':rc==130,'sigintNarration':'received SIGINT' in data.decode(errors='replace'),'noNewLogcatAfter':not [x for x in matching(after) if x not in matching(before)]}
json.dump({'checks':checks,'matchingBefore':matching(before),'matchingDuring':matching(during),'matchingAfter':matching(after)},open(R/'decoded.json','w'),indent=2); print(json.dumps(checks,sort_keys=True)); sys.exit(0 if all(checks.values()) else 1)
