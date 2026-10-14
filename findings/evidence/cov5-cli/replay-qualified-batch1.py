#!/usr/bin/env python3
from pathlib import Path
import json, os, shutil, subprocess
new=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli')
old=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov4-cli')
ev=new/'findings/evidence/cov5-cli'; cap=ev/'capture-one.rb'
old_ev=old/'findings/evidence/cov4-cli'
scratch=Path((ev/'scratch-root.txt').read_text().strip())
source=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4')
demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2')
rows=['CLI-002','CLI-003','CLI-004','CLI-005','CLI-009','CLI-011']
# Exact fresh fixtures.
for name in ['doctor-empty','CLI-005-empty','CLI-019-empty','CLI-020-normal','CLI-020-quiet']:(scratch/name).mkdir(exist_ok=True)
fixture=scratch/'CLI-023'
for n in ['grantiva.yml','grantiva.yaml']:
 p=fixture/n
 if p.exists(): p.unlink()
# Qualified helper input, not prior output.
old_reg=old_ev/'CLI-003-rerun-3/regenerate-help.sh'; reg=ev/'CLI-003-rerun-2/regenerate-help.sh'; reg.parent.mkdir(); shutil.copy2(old_reg,reg)
source_dirs={
 'CLI-003':old_ev/'CLI-003-rerun-3',
 **{r:next(iter(sorted(old_ev.glob(r+'-rerun-*'),reverse=True)),None) for r in rows if r!='CLI-003'}
}
def rw(v):
 v=v.replace(str(old),str(new)).replace('findings/evidence/cov4-cli','findings/evidence/cov5-cli').replace('/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3',str(source))
 v=v.replace('/private/tmp/grantiva-cov4-cli/doctor-empty',str(scratch/'doctor-empty')).replace('/private/tmp/grantiva-cov4-cli/CLI-005-empty',str(scratch/'CLI-005-empty')).replace('/private/tmp/grantiva-cov4-cli/CLI-019-empty',str(scratch/'CLI-019-empty')).replace('/private/tmp/grantiva-cov4-cli/CLI-020-normal',str(scratch/'CLI-020-normal')).replace('/private/tmp/grantiva-cov4-cli/CLI-020-quiet',str(scratch/'CLI-020-quiet')).replace('/private/tmp/grantiva-cov4-cli/fixtures-023-026/CLI-023',str(fixture)).replace('/private/tmp/grantiva-cov4-cli/CLI-003-rerun-3-pages',str(scratch/'CLI-003-rerun-2-pages')).replace('CLI-003-rerun-3/regenerate-help.sh','CLI-003-rerun-2/regenerate-help.sh').replace('-rerun-1/','-rerun-2/')
 return v
summary=[]
for row in rows:
 src=source_dirs[row]; dest=ev/(row+'-rerun-2'); dest.mkdir(exist_ok=True)
 files=[]
 for p in src.glob('*.command.json'):
  d=json.loads(p.read_text()); files.append((d.get('startedAt',''),p,d))
 for _,p,d in sorted(files):
  label=p.name[:-13]; argv=[rw(str(x)) for x in d['argv']]; cwd=rw(d['cwd'])
  cmd=['ruby',str(cap),str(dest),label,cwd,'--timeout',str(d.get('timeoutSeconds',1200)),'--',*argv]
  cp=subprocess.run(cmd,cwd=new)
  summary.append({'row':row,'label':label,'collectorExit':cp.returncode,'argv':argv,'cwd':cwd})
(ev/'batch1-rerun2-execution.json').write_text(json.dumps(summary,indent=2)+'\n')
