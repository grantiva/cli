# For each row: take the Class.testName pairs the round-1 result note cites and look them up in Tests/ of a source tree.
# usage: testnames.py <round1-results.md> <src-root> <ROW-ID>
import re,sys,os,subprocess
res,root,rid=sys.argv[1:4]
note=next(l for l in open(res) if l.startswith(f'| {rid} |')).split('|')[4]
pairs=re.findall(r'\b([A-Z][A-Za-z0-9]+Tests)\.(test[A-Za-z0-9_]+)',note)
print(f'{rid}: {len(pairs)} test names cited by round 1')
ok=True
for cls,fn in pairs:
    out=subprocess.run(['grep','-rn',f'func {fn}(',os.path.join(root,'Tests')],capture_output=True,text=True).stdout.strip()
    hits=[l.replace(root+'/','c65fc17:') for l in out.split('\n') if l]
    if hits: print(f'PRESENT {cls}.{fn} -> {hits[0][:200]}')
    else: ok=False; print(f'MISSING {cls}.{fn}')
print('ALL PRESENT' if ok and pairs else 'CHECK')
