import sys,re
# noflows.py <src> <dst>: copy a grantiva config without its top-level flows: block; point the device line at cov-missing
L=open(sys.argv[1]).read().split('\n'); out=[]; skip=False
for l in L:
    if re.match(r'^flows:',l): skip=True; continue
    if skip and (l.startswith(' ') or l.startswith('-') or l==''): 
        if l=='' : skip=False
        continue
    skip=False
    l=re.sub(r'^(simulator|emulator): .*', r'\1: cov-missing', l)
    out.append(l)
open(sys.argv[2],'w').write('\n'.join(out))
