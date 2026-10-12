import sys,re,json
M=sys.argv[1]
rows=[];sec=None
for ln,l in enumerate(open(M),1):
    if l.startswith('## '): sec=l[3:].strip()
    if not l.startswith('| ') or l.startswith('| ID') : continue
    # split on | not inside backticks
    cells=[];cur='';bt=False
    s=l.strip()[1:]
    i=0
    while i<len(s):
        c=s[i]
        if c=='`': bt=not bt
        if c=='\\' and i+1<len(s) and s[i+1]=='|': cur+='|'; i+=2; continue
        if c=='|' and not bt: cells.append(cur.strip()); cur=''
        else: cur+=c
        i+=1
    if len(cells)<8: continue
    if not re.match(r'^[A-Z]',cells[0]) or cells[0] in ('ID',): continue
    if cells[0].startswith('---'): continue
    slice_=cells[-3]
    rows.append(dict(ln=ln,sec=sec,id=cells[0],cmd=cells[1],inp=cells[2],exp=cells[3],plat=cells[4],slice=slice_,flow=cells[5] if len(cells)==8 else cells[-2]))
json.dump(rows,open('allrows.json','w'),indent=0)
from collections import Counter
print(len(rows),Counter(r['slice'] for r in rows))
mine=[r for r in rows if r['slice'] in('iOS','iOS+Android')]
print(len(mine),Counter(r['sec'] for r in mine))
json.dump(mine,open('mine.json','w'),indent=0)
