import re,sys,os
W=sys.argv[1]; H=W+'/findings/help'
lines=open(W+'/README.md').read().split('\n')
start=next(i for i,l in enumerate(lines) if l.startswith('## Commands'))
blk=[]; inb=False
for i,l in enumerate(lines[start:],start+1):
    if l.startswith('```'):
        if inb: break
        inb=True; continue
    if inb: blk.append((i,l))
def ov(f):
    t=open(f).read()
    m=re.search(r'OVERVIEW: (.*?)(\n\n|\nUSAGE)',t,re.S)
    return ' '.join(m.group(1).split())
listed=set()
for i,l in blk:
    m=re.match(r'grantiva ((?:[a-z-]+ ?){1,2}?)\s{2,}(.*)',l)
    if not m: print(i,'UNPARSED',l); continue
    cmd=m.group(1).strip(); desc=m.group(2).strip()
    f=H+'/'+cmd.replace(' ','_')+'.txt'
    listed.add(cmd.replace(' ','_'))
    h=ov(f) if os.path.exists(f) else 'NO HELP PAGE'
    norm=lambda s: re.sub(r'[^a-z0-9]','',s.lower())
    status='EXACT' if norm(desc)==norm(h) else ('PREFIX' if norm(desc).startswith(norm(h).rstrip()) or norm(h).startswith(norm(desc)) else 'DIFF')
    print(f'README:{i} [{status}] {cmd}\n   README: {desc}\n   help:   {h}')
leaves=[f[:-4] for f in os.listdir(H) if f.endswith('.txt')]
groups={x.rsplit('_',1)[0] for x in leaves if '_' in x}
unl=[x for x in sorted(leaves) if x not in groups and x!='grantiva' and not x.startswith('console_') and x not in listed]
print('LEAVES NOT LISTED (excluding console subgroups):',unl)
