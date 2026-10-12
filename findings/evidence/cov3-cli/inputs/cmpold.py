# cmpold.py <ROW>: compare each round-2 <label>.out/.err with the round-3 one (normalised: ids, paths, line numbers)
import re,sys,os,difflib
O='/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings/evidence/cov2-cli'
N='/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli'
def norm(s,lines=True):
    s=s.replace('c65fc17','8f2cff67').replace('1be68db','fd9d8e8').replace('cov2-cli','cov3-cli').replace('src-8f2cff67','tree').replace('1.1.28-grantiva.11','1.1.28-grantiva.13')
    s=re.sub(r'grantiva-runner-fd9d8e8[0-9a-f]+','RUNNER',s)
    if lines: s=re.sub(r':\d+:',':N:',s); s=re.sub(r'^\d+[:-]','N:',s,flags=re.M)
    return s
row=sys.argv[1]; res=[]
for f in sorted(os.listdir(os.path.join(O,row))):
    if not (f.endswith('.out') or f.endswith('.err')): continue
    a=os.path.join(O,row,f); b=os.path.join(N,row,f)
    if not os.path.exists(b): res.append((f,'MISSING')); continue
    A=open(a,errors='replace').read(); B=open(b,errors='replace').read()
    if norm(A,False)==norm(B,False): st='IDENT'
    elif norm(A)==norm(B): st='SAME-modulo-lineno'
    else:
        st='DIFF'
        d=list(difflib.unified_diff(norm(A).split('\n'),norm(B).split('\n'),lineterm='',n=0))
        st+='\n'+'\n'.join(x[:250] for x in d[2:40])
    res.append((f,st))
for f,st in res: print(f'  {f}: {st}')
