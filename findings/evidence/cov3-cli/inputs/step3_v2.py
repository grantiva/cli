import os,re,shlex,sys
root,helpdir=sys.argv[1:3]
pages={f[:-4] for f in os.listdir(helpdir) if f.endswith('.txt')}
def page_flags(page):
    return set(re.findall(r'(?<![\w-])(--[a-z][a-z0-9-]*|-[a-z])\b',open(os.path.join(helpdir,page+'.txt')).read()))
files=[os.path.join(root,'README.md')]
for base,dirs,names in os.walk(os.path.join(root,'docs')):
    rel=os.path.relpath(base,root)
    if rel=='docs/superpowers' or rel.startswith('docs/superpowers/'):
        dirs[:]=[]; continue
    files += [os.path.join(base,n) for n in names if n.endswith('.md')]
def command_from_line(s):
    s=s.strip()
    s=re.sub(r'^\$\s*','',s)
    if s.startswith('run: '): s=s[5:].strip()
    # Only a command position counts; never find grantiva inside cp/echo/prose operands.
    m=re.match(r'(?:(?:[A-Z_][A-Z0-9_]*=(?:"[^"]*"|\S+)\s+)*)((?:grantiva)(?:\s+.*)?)$',s)
    return m.group(1).strip() if m else None
examples=[]
def trim_summary(cmd):
    try: toks=shlex.split(cmd,posix=True)
    except ValueError: return cmd
    try: gi=toks.index('grantiva')
    except ValueError: return cmd
    path=[]
    for tok in toks[gi+1:]:
        if tok.startswith('-') or not re.match(r'^[a-z][a-z-]*$',tok): break
        cand='_'.join(path+[tok])
        if cand in pages: path.append(tok)
        else: break
    nxt=gi+1+len(path)
    if nxt<len(toks) and re.match(r'^[A-Z]',toks[nxt]):
        return 'grantiva '+ ' '.join(path)
    return cmd
for fp in sorted(files):
    rel=os.path.relpath(fp,root); lines=open(fp).read().splitlines(); fenced=False; i=0
    while i<len(lines):
        raw=lines[i]; stripped=raw.strip(); line_no=i+1
        if stripped.startswith('```'): fenced=not fenced; i+=1; continue
        candidates=[]
        # Exact inline code spans beginning with grantiva are examples; mentions elsewhere are ignored.
        if not fenced:
          for span in re.findall(r'`([^`]+)`',raw):
            if re.match(r'^(?:[A-Z_][A-Z0-9_]*=\S+\s+)*grantiva(?:\s|$)',span.strip()): candidates.append(('inline',span.strip()))
        is_indented=(raw.startswith('    ') or raw.startswith('\t')) and not fenced
        if fenced or is_indented:
            logical=raw.strip()
            while logical.rstrip().endswith('\\') and i+1<len(lines):
                logical=logical.rstrip()[:-1].rstrip()+' '+lines[i+1].strip(); i+=1
            # Aligned command-summary blocks have prose after 2+ spaces.
            logical=re.split(r'\s{2,}',logical,maxsplit=1)[0]
            cmd=command_from_line(logical)
            if not cmd:
                sub=re.search(r'\$\((grantiva\s+.*?)(?:\)"?|$)',logical)
                cmd=sub.group(1).strip() if sub else None
            if cmd:
                candidates.append(('fenced' if fenced else 'indented',cmd))
        for kind,cmd in candidates: examples.append((rel,line_no,kind,trim_summary(cmd)))
        i+=1

def classify(cmd):
    try: toks=shlex.split(cmd,posix=True)
    except ValueError as e: return ('MALFORMED', '-', '-', f'shell parse error: {e}')
    try: gi=toks.index('grantiva')
    except ValueError: return ('MENTION','-','-','not a grantiva command position')
    rest=toks[gi+1:]; path=[]
    for tok in rest:
        if tok.startswith('-') or not re.match(r'^[a-z][a-z-]*$',tok): break
        cand='_'.join(path+[tok])
        if cand in pages: path.append(tok)
        else: break
    page='_'.join(path) if path else 'grantiva'
    fs=[x.split('=')[0].rstrip('.,;)') for x in rest if x.startswith('-') and not re.match(r'^-[0-9]',x)]
    unknown=[x for x in fs if x not in page_flags(page)|{'--help','-h','--version'}]
    if unknown: return ('CHECK',page,'-',f'unknown flags {unknown}')
    # Existing device-free executions with concrete evidence.
    # Link only exact or semantically identical command variants. Related but
    # different variants remain syntax-only and say so below.
    if re.match(r'^grantiva init --platform android(?:\s|$)',cmd):
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-159/','exact Android init variant executed')
    if cmd=='grantiva init':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-069/','exact device-free init variant executed')
    if cmd=='grantiva doctor':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-153/','exact plain doctor command executed; row is blocked only on its separate smoke prerequisite')
    if cmd.startswith("grantiva doctor --json | jq '.[] | select(.status == \"error\")'"):
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-157/','exact doctor JSON filter pipeline executed')
    if cmd=='grantiva diff compare':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-106/','exact device-free compare variant executed')
    if cmd=='grantiva diff approve':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-106/','exact device-free approve variant executed')
    if cmd=='grantiva diff compare --json':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/D2-23/','exact compare --json variant executed')
    if cmd=='grantiva runner install':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-084/','exact scratch-home install variant executed')
    if cmd=='grantiva runner version':
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-085/','exact version variant executed')
    if re.search(r'--help\b',cmd):
        return ('EXECUTED_EXISTING',page,'findings/evidence/cov3-cli/CLI-003/','current candidate help page executed in the complete regeneration; old corpus delta separately failed')
    reason='static syntax check only; '
    if re.search(r'\bauth\b|\bconsole\b',cmd): reason+='authentication/remote-service example excluded from execution'
    elif re.search(r'\b(teardown|cleanup|delete)\b',cmd): reason+='destructive lifecycle example excluded from execution'
    elif re.search(r'\b(build|install|run|record|capture|test|simulator|emulator|hierarchy)\b',cmd): reason+='build/device example excluded from execution'
    else: reason+='not independently executed; corpus compatibility only (related evidence, if any, is a different variant)'
    return ('EXCLUDED_EXECUTION',page,'-',reason)

bad=mal=0
for n,(rel,line,kind,cmd) in enumerate(examples,1):
    status,page,evidence,note=classify(cmd); bad+=status=='CHECK'; mal+=status=='MALFORMED'
    print('\t'.join(map(str,[n,status,rel+':'+str(line),kind,page,cmd,evidence,note])))
print(f'SUMMARY\texamples={len(examples)}\tunknown_flag_examples={bad}\tmalformed_examples={mal}\thelp_pages={len(pages)}')
print('SCOPE\tsource='+root+'\tcorpus='+helpdir+'\texcluded=docs/superpowers/** (internal campaign documents)')
