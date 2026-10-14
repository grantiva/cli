from pathlib import Path
import json,re
E=Path('findings/evidence/cov6-cli');batch=json.load(open(E/'direct-row-batches.json'))['batches'][1]['rows'];L=json.load(open(E/'results-ledger.json'))
def dirs(k):return sorted([p for p in E.glob(k+'*') if p.is_dir()])
def streams(k,suf):return '\n'.join(p.read_text(errors='replace') for d in dirs(k) for p in d.glob('*'+suf))
def commands(k):
 out=[]
 for d in dirs(k):
  for p in d.glob('*.command.json'):out.append((d,p,json.load(open(p))))
 return out
def contains(k,*xs):
 s=streams(k,'.stdout')+'\n'+streams(k,'.stderr');return all(x in s for x in xs)
checks={
'CLI-024':[contains('CLI-024','Android SDK','grantiva-android.yml')],
'CLI-025':[contains('CLI-025','Found both an Xcode project and Gradle settings','Advisory')],
'CLI-026':[contains('CLI-026','Xcode','Android SDK','grantiva.yml','grantiva-android.yml')],
'CLI-027':[contains('CLI-027','screens=1','Simulator not found')],
'CLI-028':[streams('CLI-028','.stderr').count('No flow files found')==2],
'CLI-029':[contains('CLI-029','Simulator not found')],
'CLI-030':[contains('CLI-030','Both grantiva.yml and grantiva-android.yml exist')],
'CLI-031':[contains('CLI-031','No screens or flows configured in grantiva-android.yml','No .xcworkspace or .xcodeproj found','Android SDK','Xcode')],
'CLI-032':[contains('CLI-032','Xcode')],
'CLI-033':[streams('CLI-033','.stderr').count('GRANTIVA_PLATFORM is "windows"; expected ios or android.')==3,contains('CLI-033','grantiva.yml','grantiva-android.yml')],
'CLI-034':[contains('CLI-034','--platform android was given but grantiva-android.yml does not exist here','Found grantiva.yml')],
'CLI-035':[contains('CLI-035',"value 'macos' is invalid",'ios','android')],
'CLI-127':[streams('CLI-127','.stdout').count('Android SDK')>=2],
'CLI-128':[contains('CLI-128',"value 'windows' is invalid",'ios','android')],
'CLI-036':[contains('CLI-036','grantiva.yml could not be parsed','5:1')],
'CLI-037':[contains('CLI-037','grantiva-android.yml could not be parsed','6:1')],
'CLI-038':[contains('CLI-038','No scheme specified','Found: Landmarks')],
'CLI-039':[contains('CLI-039','unknown key "schem"','did you mean "scheme"','screens:')],
'CLI-040':[contains('CLI-040','declares `platform: android`','iOS config file')],
'CLI-041':[contains('CLI-041','--scheme is an iOS option','Android project')],
'CLI-042':[contains('CLI-042','--module is an Android option','iOS project')],
'CLI-043':[contains('CLI-043','--logs-predicate is an iOS option','Android project','--logs-tag is an Android option','iOS project')],
'CLI-044':[contains('CLI-044','No screens or flows configured in grantiva.yml')],
'CLI-045':[contains('CLI-045','--device and --emulator are mutually exclusive')],
'CLI-046':[contains('CLI-046-rerun-2','Simulator not found')],
}
# resolve helper for exact dir key
def expected(k):return next(x['expected'] for x in batch if x['key']==k)
new=[]
for off,row in enumerate(batch,26):
 k=row['key'];ok=all(checks[k]);d=E/(k+'-assessment')
 if d.exists(): d=E/(k+'-assessment-2')
 d.mkdir(); refs=[str(p.relative_to(E)) for _,p,_ in commands(k)]
 note='Current raw reaches the expected parser/platform/config outcome before any compile or live target action.'
 if k=='CLI-046': refs += [str(p.relative_to(E)) for _,p,_ in commands('CLI-046-rerun-2')]; note='The first action fixture incorrectly placed `launch` inside a step list and is preserved. The adjacent corrected fixture uses a launch screen plus a second screen containing every listed action; it parses to explicit proven-absent simulator resolution.'
 (d/'verdict.md').write_text(f'# {k} candidate5 clause assessment\n\nVerdict: **{"PASS" if ok else "FAIL"}**.\n\nExpected: {expected(k)}\n\n{note} Clause checks: {checks[k]}. Evidence: '+', '.join(f'`{r}`' for r in refs)+'.\n')
 new.append({'directOrdinal':off,'key':k,'grade':'PASS' if ok else 'FAIL','evidence':str((d/'verdict.md').relative_to(E)),'checks':checks[k]})
L['rows'].extend(new);(E/'results-ledger.json').write_text(json.dumps(L,indent=2)+'\n')
summary={'throughDirectOrdinal':50,'batchCounts':{'PASS':sum(x['grade']=='PASS' for x in new),'FAIL':sum(x['grade']=='FAIL' for x in new),'PENDING':0,'NA':0},'cumulativeCounts':{'PASS':sum(x['grade']=='PASS' for x in L['rows']),'FAIL':sum(x['grade']=='FAIL' for x in L['rows'])},'ledger':'results-ledger.json','fails':[x['key'] for x in new if x['grade']=='FAIL']}
(E/'batch-02-verdict.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary))
