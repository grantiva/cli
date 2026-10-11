import re,os,sys,shlex
RD=sys.argv[1]; H=sys.argv[2]; W=RD
pages={f[:-4] for f in os.listdir(H) if f.endswith('.txt')}
files=[W+'/README.md']+sorted(W+'/docs/'+f for f in os.listdir(W+'/docs') if f.endswith('.md'))
def flags_of(page):
    t=open(f'{H}/{page}.txt').read()
    return set(re.findall(r'(?<![\w-])(--[a-z][a-z0-9-]*|-[a-z])\b',t))
n=0; bad=0
for fp in files:
    rel=fp[len(W)+1:]
    for i,line in enumerate(open(fp),1):
        # candidate command strings: code spans and code-block lines containing 'grantiva '
        cands=re.findall(r'`(grantiva [^`]+)`',line)
        s=line.strip()
        if s.startswith('grantiva ') or re.match(r'^(\$ )?(\w+=\S+ )*grantiva ',s) or re.search(r'\$\(grantiva [^)]*\)',s) or s.startswith('run: grantiva') or s.startswith('PATH='):
            cands += re.findall(r'(grantiva [^`#|&;)]+)',s)
        for c in cands:
            c=c.strip().rstrip('.,:')
            try: toks=shlex.split(c)
            except ValueError: toks=c.split()
            toks=toks[1:]
            path=[]
            for t in toks:
                if t.startswith('-') or '<' in t or not re.match(r'^[a-z][a-z-]*$',t): break
                cand='_'.join(path+[t])
                if cand in pages: path.append(t)
                else: break
            page='_'.join(path) if path else 'grantiva'
            fl=[t.split('=')[0] for t in toks if t.startswith('-')]
            known=flags_of(page)|{'--help','-h','--version'}
            missing=[f for f in fl if f not in known and not re.match(r'^-[0-9]',f)]
            # a following word that is not a known subcommand while page has subcommands
            nxt=toks[len(path)] if len(toks)>len(path) else None
            subcmd_issue = nxt and re.match(r'^[a-z][a-z-]*$',nxt) and any(p.startswith(page+'_') for p in pages) and page!='grantiva' and f'{page}_{nxt}' not in pages and page not in ('build',)
            n+=1
            st='OK'
            if missing or (path==[] and toks and re.match(r'^[a-z]',toks[0]) and toks[0] not in ('help',)) or subcmd_issue:
                st='CHECK'; bad+=1
            print(f'{st} {rel}:{i} [{page}] {c}' + (f'  unknown flags {missing}' if missing else '') + (f'  unknown subcommand {nxt!r}' if subcmd_issue else ''))
print(f'# {n} examples, {bad} to check')
