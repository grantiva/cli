import re,sys,json,glob,os
# usage: durcmp.py <stderr> <reportdir>
txt=open(sys.argv[1]).read().split('\n'); rd=sys.argv[2]
def ms(s):
    m=re.match(r'([\d.]+)(ms|s)$',s); v=float(m.group(1)); return v if m.group(2)=='ms' else v*1000
blocks={}; cur=None; kind=None
for l in txt:
    m=re.match(r'\s*\[\d+/\d+\] (\S+) \((.*?)\)( - Device.*)?$',l)
    if m: cur=m.group(1); kind='summary' if m.group(3) else 'live'; blocks.setdefault((cur,kind),[]); continue
    m=re.match(r'\s+[✓✗] (.*) \(([\d.]+m?s)\)$',l)
    if m and cur: blocks[(cur,kind)].append((m.group(1),m.group(2)))
rep=json.load(open(os.path.join(rd,'report.json')))
worst=0
for f in rep['flows']:
    d=json.load(open(os.path.join(rd,f['dataFile'])))
    R=[c.get('duration') for c in d['commands']]
    L=blocks.get((f['name'],'live'),[]); S=blocks.get((f['name'],'summary'),[])
    for i,r in enumerate(R):
        lv=L[i][1] if i<len(L) else None; sv=S[i][1] if i<len(S) else None
        if lv!=sv or (lv and r is not None and abs(ms(lv)-r)>(1 if lv.endswith('ms') else 50)):
            print(f['name'],i,(L[i][0] if i<len(L) else ''),'live',lv,'summary',sv,'report',r)
