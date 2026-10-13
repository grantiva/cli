import os,re,shlex,sys
root, helpdir = sys.argv[1:3]
pages={f[:-4] for f in os.listdir(helpdir) if f.endswith('.txt')}
files=[os.path.join(root,'README.md')]
excluded=[]
for base,dirs,names in os.walk(os.path.join(root,'docs')):
    if os.path.relpath(base,root).startswith('docs/superpowers'):
        excluded.extend(os.path.join(base,n) for n in names if n.endswith('.md'))
        dirs[:]=[]; continue
    files += [os.path.join(base,n) for n in names if n.endswith('.md')]
def flags(page):
    return set(re.findall(r'(?<![\w-])(--[a-z][a-z0-9-]*|-[a-z])\b',open(os.path.join(helpdir,page+'.txt')).read()))
count=bad=0
for fp in sorted(files):
  rel=os.path.relpath(fp,root); fenced=False
  for num,line in enumerate(open(fp),1):
    if line.strip().startswith('```'): fenced=not fenced; continue
    cands=re.findall(r'`(grantiva [^`]+)`',line)
    s=line.strip().lstrip('$ ').strip()
    if fenced and ('grantiva ' in s): cands += re.findall(r'(grantiva\s+[^#|;&]+)',s)
    for command in cands:
      command=command.strip().rstrip('.,:')
      # Command-summary blocks align a command and prose with 2+ spaces.
      command=re.split(r'\s{2,}',command,maxsplit=1)[0]
      try: toks=shlex.split(command)
      except ValueError: toks=command.split()
      if not toks or toks[0] != 'grantiva': continue
      rest=toks[1:]; path=[]
      for tok in rest:
        if tok.startswith('-') or not re.match(r'^[a-z][a-z-]*$',tok): break
        cand='_'.join(path+[tok])
        if cand in pages: path.append(tok)
        else: break
      page='_'.join(path) if path else 'grantiva'
      if len(rest)>len(path) and re.match(r'^[A-Z]',rest[len(path)]):
        rest=rest[:len(path)]; command='grantiva '+ ' '.join(rest)
      fs=[x.split('=')[0] for x in rest if x.startswith('-') and not re.match(r'^-[0-9]',x)]
      unknown=[x for x in fs if x not in flags(page)|{'--help','-h','--version'}]
      sensitive=bool(re.search(r'\b(auth login|teardown --all|simulator cleanup|delete|run|record|build|diff capture|ci run)\b',command))
      status='EXCLUDED_EXECUTION' if sensitive else ('CHECK' if unknown else 'CORPUS_OK')
      reason='device/auth/destructive/build example; syntax checked only' if sensitive else ('unknown flags '+','.join(unknown) if unknown else 'command and flags present in current 172-page corpus')
      print(f'{status}\t{rel}:{num}\t{page}\t{command}\t{reason}')
      count+=1; bad+=bool(unknown)
print(f'SUMMARY\texamples={count}\tunknown_flag_examples={bad}\thelp_pages={len(pages)}\texcluded_internal_docs={len(excluded)}')
print('SCOPE\tdocs/superpowers recursively excluded as internal campaign documents, not user-facing shipped docs')
