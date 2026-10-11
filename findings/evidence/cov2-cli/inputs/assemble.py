import json,sys,collections
base=sys.argv[1]; out=sys.argv[2]; final=len(sys.argv)>3
rows=json.load(open(base+'/cli_rows.json'))
res={}
extra=[]
for ln in open(base+'/results.tsv'):
    ln=ln.rstrip('\n')
    if not ln: continue
    i,r,e,n=ln.split('\t')
    if i.startswith('EXTRA-'): extra.append((i,r,e,n)); continue
    res[i]=(r,e,n)
def key(rid): return rid.split(' ')[0]
H=open(base+'/header.md').read()
L=[H,'| ID | result | evidence | note |','|---|---|---|---|']
cnt=collections.Counter(); missing=[]
ids=set()
for r in rows:
    k=key(r['id'])
    if k in res:
        rr,e,n=res[k]; ids.add(k)
        L.append(f'| {k} | {rr} | {e} | {n.replace("|","\\|")} |')
        c=rr.split(' ')[0]; cnt['fail' if c.startswith('fail') else c]+=1
    else: missing.append(k)
unknown=set(res)-ids
if extra:
    L+=['','## Findings outside the matrix rows (recorded as fail for triage)','','| ID | result | evidence | note |','|---|---|---|---|']
    for i,r,e,n in extra: L.append(f'| {i} | {r} | {e} | {n.replace("|","\\|")} |')
L+=['',f'## Counts','',f'{len(rows)} rows in the CLI slice; {len(ids)} graded: pass {cnt["pass"]}, fail {cnt["fail"]} (of which matrix/brief error {sum(1 for k in ids if "matrix/brief" in res[k][0])}), blocked {cnt["blocked"]}, n/a {cnt["n/a"]}.' + (f' Not yet run: {len(missing)}.' if missing else '') + (f' Findings outside the matrix: {len(extra)}.' if extra else '')]
open(out,'w').write('\n'.join(L)+'\n')
print('graded',len(ids),'missing',len(missing),'unknown',unknown, dict(cnt))
