# replay.py <ROW>: print a bash script that re-runs round-2 commands of ROW against the round-3 tree/binary (labels kept)
import shlex
def q(s): return shlex.quote(s)
import re,sys,os
SP='/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad'
O='/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings/evidence/cov2-cli'
RR2='runner-1be68db/grantiva-runner-1be68db61557806ebad29784b86f7c36123d84ce'
RR3='runner-src/grantiva-runner-fd9d8e8d1cb109eda6116f4221da10257b9838e3'
def m(s):
    s=s.replace(SP+'/cov2-cli/'+RR2, SP+'/cov3-cli/'+RR3)
    s=s.replace(SP+'/cov2-cli/src-c65fc17', SP+'/cov3-cli/tree')
    s=s.replace('/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings/evidence/cov2-cli/inputs/testnames.py', SP+'/cov3-cli/tools/testnames3.py')
    s=s.replace('/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings/evidence/cov2-cli/inputs/', '/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli/inputs/')
    s=s.replace('/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/findings/evidence/cov2-cli/', '/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli/')
    s=s.replace('/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-cli/', '/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/')
    s=s.replace(SP+'/cov2-cli/', SP+'/cov3-cli/')
    s=s.replace("sed 's#^#c65fc17:#'", "sed 's#^#8f2cff67:#'").replace("runner@1be68db","runner@fd9d8e8")
    s=s.replace('src-c65fc17','tree')
    return s
row=sys.argv[1]
t=open(os.path.join(O,row,'commands.txt')).read().split('\n')
cwd=None; cmd=None
for l in t:
    if l.startswith('# cwd: '): cwd=m(l[7:]); continue
    if l.startswith('$ '): cmd=m(l[2:]); continue
    mm=re.match(r'# exit=\S+ elapsed=\S+ -> (\S+)\.out / ',l)
    if mm and cmd is not None:
        lab=mm.group(1)
        print('mkdir -p %s 2>/dev/null; cd %s && ev %s %s %s' % (q(cwd),q(cwd),row,q(lab),q(cmd)))
        cmd=None
