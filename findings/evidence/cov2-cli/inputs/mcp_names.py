# compare tool names in docs/mcp.md table rows with a tools/list response: mcp_names.py <mcp.md> <tools-list stdout>
import json,re,sys
doc=open(sys.argv[1]).read()
rows=[l for l in doc.split('\n') if l.startswith('| `grantiva_')]
dn=[re.match(r'\| `(grantiva_[a-z0-9_]+)`',l).group(1) for l in rows]
tl=None
for l in open(sys.argv[2]):
    m=json.loads(l)
    if 'result' in m and 'tools' in m['result']: tl=m['result']['tools']
names=[t['name'] for t in tl]
print('doc rows',len(dn),'unique',len(set(dn)),'tools/list',len(names))
print('only in doc',sorted(set(dn)-set(names)),'only in tools/list',sorted(set(names)-set(dn)))
for l in rows: print(l[:220])
for t in tl:
    d=t.get('description','')
    if 'iOS' in d or 'Android' in d: print('DESC',t['name'],'::',d[:200])
