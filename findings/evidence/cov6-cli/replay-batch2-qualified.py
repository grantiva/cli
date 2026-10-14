#!/usr/bin/env python3
from pathlib import Path
import json,subprocess
new=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli'); old=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov4-cli'); ev=new/'findings/evidence/cov6-cli'; oe=old/'findings/evidence/cov4-cli'; cap=ev/'capture-one.rb'; scratch=Path((ev/'scratch-root.txt').read_text().strip())/'batch2-fixtures'
if not (scratch/'fixtures-023-026').exists():
 scratch.mkdir(exist_ok=True)
 subprocess.run(['cp','-cR','/private/tmp/grantiva-cov4-cli/fixtures-023-026',str(scratch/'fixtures-023-026')],check=True); subprocess.run(['cp','-cR','/private/tmp/grantiva-cov4-cli/fixtures-030-035',str(scratch/'fixtures-030-035')],check=True); subprocess.run(['cp','-cR','/private/tmp/grantiva-cov4-cli/fixtures-036-043',str(scratch/'fixtures-036-043')],check=True)
for n in ('grantiva.yml','grantiva.yaml','grantiva-android.yml'):
 p=scratch/'fixtures-023-026/CLI-024'/n
 if p.exists():p.unlink()
rows=['CLI-024','CLI-025','CLI-026','CLI-030','CLI-032','CLI-033','CLI-034','CLI-035','CLI-128','CLI-036','CLI-037','CLI-040','CLI-041','CLI-042','CLI-043']
def srcdir(r):
 ds=[p for p in oe.glob(r+'-rerun-*') if p.is_dir()]
 return sorted(ds)[-1] if ds else oe/r
def rw(v):
 return v.replace(str(old),str(new)).replace('/private/tmp/grantiva-cov4-cli/fixtures-023-026',str(scratch/'fixtures-023-026')).replace('/private/tmp/grantiva-cov4-cli/fixtures-030-035',str(scratch/'fixtures-030-035')).replace('/private/tmp/grantiva-cov4-cli/fixtures-036-043',str(scratch/'fixtures-036-043'))
summary=[]
for row in rows:
 dest=ev/(row+'-rerun-1');dest.mkdir(exist_ok=False); seq=[]
 for p in srcdir(row).glob('*.command.json'):
  d=json.loads(p.read_text());seq.append((d.get('startedAt',''),p,d))
 for _,p,d in sorted(seq):
  label=p.name[:-13];argv=[rw(str(x)) for x in d['argv']];cwd=rw(d['cwd']);cp=subprocess.run(['ruby',str(cap),str(dest),label,cwd,'--timeout',str(d.get('timeoutSeconds',1200)),'--',*argv],cwd=new);summary.append({'row':row,'label':label,'exit':cp.returncode,'argv':argv,'cwd':cwd})
(ev/'batch2-part1-execution.json').write_text(json.dumps(summary,indent=2)+'\n')
