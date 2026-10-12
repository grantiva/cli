import sys,re,collections
M=sys.argv[1]; out=sys.argv[2]
sec=None; rows=[]; c=collections.Counter()
for l in open(M):
    if l.startswith('## '): sec=l[3:].strip(); continue
    if not l.startswith('| ') or l.startswith('| ID') or l.startswith('|---'): continue
    cells=[x.strip() for x in re.split(r'(?<!\\)\|',l.strip())[1:-1]]
    if len(cells)<7: continue
    slice_=cells[-3]; c[slice_]+=1
    if slice_ in ('Android','iOS+Android'):
        rows.append((sec,cells))
with open(out,'w') as f:
    for s,cells in rows: f.write(s+'\t'+'\t'.join(cells)+'\n')
print(c); print(len(rows)); print(collections.Counter(s for s,_ in rows))
