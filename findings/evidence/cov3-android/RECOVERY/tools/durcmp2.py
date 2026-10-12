import re,sys,json,os
# durcmp2.py <stderr> <reportdir>: per flow, compare step durations: live block, summary block, report.json commands (incl. nested)
txt=open(sys.argv[1]).read().split('\n'); rd=sys.argv[2]
def ms(s):
    m=re.match(r'(?:(\d+)m )?([\d.]+)(ms|s)$',s); v=float(m.group(2)); v= v if m.group(3)=='ms' else v*1000
    return v+(int(m.group(1))*60000 if m.group(1) else 0)
def fmt_match(s,r):
    if s.endswith('ms'): return abs(ms(s)-r)<=1
    return abs(ms(s)-r)<=50
blocks={}; cur=None
for l in txt:
    m=re.match(r'\s*\[\d+/\d+\] (\S+) \((.*?)\)( - Device.*)?$',l)
    if m: cur=(m.group(1),'summary' if m.group(3) else 'live'); blocks.setdefault(cur,[]); continue
    m=re.match(r'\s+[✓✗⚠] (.*) \(([\d.]+m?s)(, slow)?\)$',l)
    if m and cur: blocks[cur].append((m.group(1),m.group(2)))
rep=json.load(open(os.path.join(rd,'report.json')))
def flat(cmds):
    for c in cmds:
        yield c
        for k in ('subCommands','children','commands','subFlow'):
            if isinstance(c.get(k),list): yield from flat(c[k])
bad=0
for f in rep['flows']:
    d=json.load(open(os.path.join(rd,f['dataFile'])))
    R=[c.get('duration') for c in flat(d['commands']) if c.get('status') not in ('skipped','pending')]
    L=blocks.get((f['name'],'live'),[]); S=blocks.get((f['name'],'summary'),[])
    ls=sorted(ms(x[1]) for x in L); ss=sorted(ms(x[1]) for x in S)
    print(f['name'],'live',len(L),'summary',len(S),'report',len(R),'live==summary',[x[1] for x in L]==[x[1] for x in S])
    Rs=list(R)
    for name,dur in L:
        hit=[r for r in Rs if r is not None and fmt_match(dur,r)]
        if not hit: print('  no report match for live',name,dur); bad+=1
        else: Rs.remove(hit[0])
    print('  flow: report',f.get('duration'),'ms')
print('mismatches',bad)
