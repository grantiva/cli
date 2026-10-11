import subprocess,sys,time,signal,os
# fg.py <mode int|stop> <grantiva> <udid> [extra args...]
mode,g,u=sys.argv[1:4]; extra=sys.argv[4:]
p=subprocess.Popen([g,'runner','start','--bundle-id','com.kylebrowning.Landmarks','--simulator',u]+extra,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
time.sleep(15)
d=subprocess.run([g,'runner','dump-hierarchy'],capture_output=True,text=True)
print('dump-from-other-shell exit=%d first=%r'%(d.returncode,(d.stdout.splitlines() or [''])[0]))
print('sessions during:',sorted(os.listdir('/tmp/grantiva-sessions')))
if mode=='int': p.send_signal(signal.SIGINT)
else:
    s=subprocess.run([g,'runner','stop'],capture_output=True,text=True); print('runner stop:',s.returncode,s.stdout.strip(),s.stderr.strip())
out,err=p.communicate(timeout=60)
print('runner start exit=%d'%p.returncode)
print('--- start stdout:\n'+out); print('--- start stderr (last 8 lines):\n'+'\n'.join(err.splitlines()[-8:])); print('stderr lines', len(err.splitlines()))
time.sleep(1)
print('sessions after:',sorted(os.listdir('/tmp/grantiva-sessions')),'session.json exists:',os.path.exists('.grantiva/session.json'))
