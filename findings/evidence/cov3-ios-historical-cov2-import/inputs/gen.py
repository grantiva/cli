import json,re,sys,collections
S=sys.argv[1]; out=sys.argv[2]
mine=json.load(open(S+'/mine.json'))
order={r['id']:i for i,r in enumerate(mine)}
lines={}
for l in open(S+'/res.lines'):
    if not l.startswith('| '): continue
    rid=l.split('|')[1].strip()
    lines[rid]=l.rstrip('\n')   # last write wins
def key(rid):
    base=rid.split('@')[0]
    if rid in('STEP1',): return (-1,0)
    if rid.startswith('TEARDOWN'): return (10**6,0)
    return (order.get(base,10**5), 1 if '@' in rid else 0)
ids=sorted(lines,key=key)
hdr=open(S+'/header.md').read()
c26=collections.Counter(); c27=collections.Counter(); cx=collections.Counter()
for rid in ids:
    raw=lines[rid].split('|')[2].strip(); v='fail-matrix' if raw.startswith('fail (matrix') else raw.split(' ')[0]
    if rid=='STEP1' or rid.startswith('TEARDOWN'): continue
    (c27 if '@27.0' in rid else (c26 if rid.split('@')[0] in order else cx))[v]+=1
missing=[r['id'] for r in mine if r['id'] not in lines]
def fmt(c): return ', '.join(f'{k} {c.get(k,0)}' for k in ('pass','fail','fail-matrix','blocked','n/a'))+f' (total {sum(c.values())})'.replace('fail-matrix','fail (matrix/brief error — triage)')
with open(out,'w') as f:
    f.write(hdr)
    f.write('\n| ID | result | evidence | note |\n|---|---|---|---|\n')
    for rid in ids: f.write(lines[rid]+'\n')
    f.write(f'\n## Counts\n\nMatrix rows of the iOS slice ({len(mine)}): {fmt(c26)}; not yet recorded: {len(missing)}. STEP1 and TEARDOWN: pass.\n\n27.0 repeats: {fmt(c27)}.\n\nCLI rows handed over by the CLI slice (CLI-048, CLI-049, CLI-061, CLI-064, CLI-066): {fmt(cx)}.\n')
print('recorded',len(c26),'missing',len(missing), 'c26',dict(c26),'c27',dict(c27),'cx',dict(cx))
if '-m' in sys.argv: print(missing)
