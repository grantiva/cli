import sys,re,collections
S=sys.argv[1]; out=sys.argv[2]
order=[l.split('\t')[1].split(' ')[0] for l in open(S+'/myrows.tsv') if l.split('\t')[1]!='section']
rows={}
for l in open(S+'/results.rows'):
    i=l.split('|')[1].strip(); rows[i]=l.rstrip('\n')   # last write wins
hdr=open(S+'/header.md').read()
body=[]
for i in order:
    if i in rows: body.append(rows[i])
    if i+' rerun' in rows: body.append(rows[i+' rerun'])
extra=[i for i in rows if i not in order and not i.endswith(' rerun')]
missing=[i for i in order if i not in rows]
cnt=collections.Counter()
for i in order:
    if i in rows:
        v=rows[i].split('|')[2].strip()
        k='pass' if v=='pass' else 'fail' if v.startswith('fail') else 'blocked' if v.startswith('blocked') else 'n/a' if v.startswith('n/a') else v
        cnt[k]+=1
with open(out,'w') as f:
    f.write(hdr); f.write('| ID | result | evidence | note |\n|---|---|---|---|\n'); f.write('\n'.join(body)+'\n')
    f.write('\n## Counts\n\n%d of %d slice rows recorded: %d pass, %d fail, %d blocked, %d n/a.\n' % (len([i for i in order if i in rows]),len(order),cnt['pass'],cnt['fail'],cnt['blocked'],cnt['n/a']))
    if missing: f.write('\nNot yet recorded (%d): %s\n' % (len(missing),', '.join(missing)))
    import os
    if os.path.exists(S+'/obs.rows'):
        obs=[l.rstrip('\n') for l in open(S+'/obs.rows')]
        f.write('\n## Findings outside the rows\n\nInconsistencies met while running the rows that no row covers (all `fail`; not counted above).\n\n| ID | result | evidence | note |\n|---|---|---|---|\n'+'\n'.join(obs)+'\n')
print('recorded',len([i for i in order if i in rows]),'of',len(order),dict(cnt),'extra',extra)
