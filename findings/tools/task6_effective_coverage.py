#!/usr/bin/env python3
"""Derive Round-3 effective coverage from matrix IDs and result rows; never edits ledgers."""
from __future__ import annotations
import argparse, collections, hashlib, json, re
from pathlib import Path

VERDICTS=('pass','fail','blocked','n/a')
RANK={'fail':3,'blocked':2,'pass':1,'n/a':0}
PLATFORM_RE=re.compile(r'\|\s*(cli|ios|android|both)\s*\|\s*(CLI|iOS|Android|iOS\+Android)\s*\|')
FOOTERS={
 'cli':re.compile(r'384 unique matrix IDs.*?pass (\d+), fail (\d+).*?blocked (\d+), n/a (\d+)',re.S),
 'ios':re.compile(r'Matrix base rows recorded:\s*(\d+) of (\d+) \(pass (\d+), fail (\d+), blocked (\d+), n/a (\d+)\)'),
 'android':re.compile(r'(\d+) of (\d+) slice rows recorded:\s*(\d+) pass, (\d+) fail, (\d+) blocked, (\d+) n/a')}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def cells(line): return [x.strip() for x in line.strip().strip('|').split('|')]
def verdict(s):
 for v in VERDICTS:
  if s==v or s.startswith(v+' ') or s.startswith(v+' ('): return v
 return None

def read_matrix(path):
 rows={}; by_platform=collections.Counter(); by_slice=collections.Counter()
 for no,line in enumerate(path.read_text().splitlines(),1):
  m=PLATFORM_RE.search(line)
  if not m: continue
  c=cells(line); rid=c[0].removesuffix(' (changed)')
  if rid in rows: raise SystemExit(f'duplicate matrix ID {rid}')
  rows[rid]={'id':rid,'declared_platform':m.group(1),'slice':m.group(2),'line':no}
  by_platform[m.group(1)]+=1; by_slice[m.group(2)]+=1
 if len(rows)!=1170: raise SystemExit(f'matrix has {len(rows)} rows')
 return rows,dict(by_platform),dict(by_slice)

def canonicalize(label, ids):
 # Longest prefix prevents B2-K1 from capturing B2-K10; suffixes preserve rerun/platform variants.
 for rid in ids:
  if label==rid or (label.startswith(rid) and label[len(rid):len(rid)+1] in (' ','[' ,'(')):
   return rid
 return None

def platform_variant(label):
 m=re.search(r'\[(ios|android)(?:[^]]*)\]',label,re.I)
 return m.group(1).lower() if m else 'generic'

def expected_ids(matrix, platform):
 if platform=='cli': return {r for r,x in matrix.items() if x['slice']=='CLI'}
 own='iOS' if platform=='ios' else 'Android'
 return {r for r,x in matrix.items() if x['slice'] in (own,'iOS+Android')}

def derive(path, matrix, platform, mode="final"):
 expected=expected_ids(matrix,platform); sorted_ids=sorted(matrix,key=len,reverse=True)
 latest={}; raw=0; excluded=[]
 for no,line in enumerate(path.read_text().splitlines(),1):
  c=cells(line)
  if len(c)<2 or not verdict(c[1]): continue
  raw+=1
  is_repeat='@27.0' in c[0]
  is_task6=('rerun corrected round 4' in c[0] or 'rerun task6 completion' in c[0])
  if is_repeat or (mode=='original' and is_task6):
   excluded.append({'line':no,'label':c[0],'reason':'iOS 27 repeat' if is_repeat else 'Task 6 appended adjudication'})
   continue
  rid=canonicalize(c[0],sorted_ids)
  if rid not in expected:
   excluded.append({'line':no,'label':c[0],'reason':'side/repeat/handoff or another execution slice'})
   continue
  key=(rid,platform_variant(c[0])); latest[key]={'line':no,'label':c[0],'verdict':verdict(c[1]),'evidence':c[2] if len(c)>2 else '', 'reason':c[3] if len(c)>3 else ''}
 derived={}; sources={}
 for rid in sorted(expected):
  variants=[x for (r,_),x in latest.items() if r==rid]
  if not variants: continue
  winner=max(variants,key=lambda x:RANK[x['verdict']])
  derived[rid]=winner['verdict']; sources[rid]=variants
 counts=collections.Counter(derived.values())
 return {'expected_ids':expected,'derived':derived,'sources':sources,'counts':{v:counts[v] for v in VERDICTS},
         'recorded':len(derived),'expected':len(expected),'missing':sorted(expected-set(derived)),'raw_result_lines':raw,'excluded':excluded}

def footer(path,platform):
 text=path.read_text(); m=FOOTERS[platform].search(text)
 if not m: return None
 n=list(map(int,m.groups()))
 if platform=='cli': p,f,b,na=n; return {'recorded':384,'expected':384,'pass':p,'fail':f,'blocked':b,'n/a':na}
 rec,exp,p,f,b,na=n; return {'recorded':rec,'expected':exp,'pass':p,'fail':f,'blocked':b,'n/a':na}

def main():
 ap=argparse.ArgumentParser();
 for x in ('controller','cli','ios','android','output','table'): ap.add_argument('--'+x,type=Path,required=True)
 a=ap.parse_args(); matrix_path=a.controller/'docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md'
 matrix,declared,slices=read_matrix(matrix_path)
 paths={'cli':a.cli/'findings/cov3-cli-results.md','ios':a.ios/'findings/cov3-ios-results.md','android':a.android/'findings/cov3-android-results.md'}
 audits={}; footer_checks={}; original_maps={}; final_maps={}; original_detail={}; final_detail={}
 for p,path in paths.items():
  od=derive(path,matrix,p,'original'); fd=derive(path,matrix,p,'final')
  original_maps[p]=od['derived']; final_maps[p]=fd['derived']; original_detail[p]=od; final_detail[p]=fd
  f=footer(path,p)
  osummary={'recorded':od['recorded'],'expected':od['expected'],**od['counts']}
  fsummary={'recorded':fd['recorded'],'expected':fd['expected'],**fd['counts']}
  audits[p]={'original':{**osummary,'missing':od['missing'],'excluded_result_lines':len(od['excluded'])},
             'final':{**fsummary,'missing':fd['missing'],'excluded_result_lines':len(fd['excluded'])},
             'raw_result_lines':od['raw_result_lines'],'path':str(path),'sha256':sha(path)}
  footer_checks[p]={'original_footer':f,'derived_original':osummary,'matches_original':f==osummary}
 review_map_path=a.controller/'findings/task6-corrected-criterion-review-map.json'
 review_map=json.loads(review_map_path.read_text()) if review_map_path.exists() else []
 actual_task6={(p,rid) for p,d in final_detail.items() for rid,items in d['sources'].items() for x in items if 'rerun corrected round 4' in x['label'] or 'rerun task6 completion' in x['label']}
 mapped={(x['slice'],x['id']) for x in review_map}
 map_validation={'path':str(review_map_path),'entries':len(review_map),'actual_task6_rows':len(actual_task6),
                 'mapped_without_actual_row':sorted(f'{p}:{r}' for p,r in mapped-actual_task6),
                 'actual_rows_without_mapping':sorted(f'{p}:{r}' for p,r in actual_task6-mapped)}
 def totals(mapping):
  c=collections.Counter(v for x in mapping.values() for v in x.values()); return {**{v:c[v] for v in VERDICTS},'total':sum(c.values())}
 report={'matrix':{'path':str(matrix_path),'sha256':sha(matrix_path),'logical_rows':len(matrix),
          'by_declared_platform':declared,'by_execution_slice':slices,
          'effective_by_slice':{p:len(expected_ids(matrix,p)) for p in paths},
          'effective_total':sum(len(expected_ids(matrix,p)) for p in paths)},
         'derived_slices':audits,'original_footer_validation':footer_checks,
         'original_effective_totals':totals(original_maps),'task6_review_map_validation':map_validation,
         'final_effective_totals':totals(final_maps),'side_findings':'excluded because their IDs are absent from the 1170-row matrix',
         'remaining_fail_blocked':[{'platform':p,'id':rid,'verdict':v,'sources':final_detail[p]['sources'][rid]} for p in paths for rid,v in sorted(final_maps[p].items()) if v in ('fail','blocked')],
         'ready':all(not x['original']['missing'] and not x['final']['missing'] for x in audits.values()),
         'note':'Original excludes @27.0 repeats and Task 6 appended rows. Final excludes @27.0 repeats and includes actual Task 6 appended rows. Latest observation wins per ID/platform variant; variants collapse fail > blocked > pass > n/a.'}
 a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(report,indent=2)+'\n')
 lines=['# Task 6 B2/B3 effective row audit','','Derived from result rows; no ledger edits.','','| ID | Platform | Original | Final | Source line(s) |','|---|---|---|---|---|']
 for rid in sorted((r for r in matrix if r.startswith(('B2-','B3-')))):
  for p in paths:
   if rid not in expected_ids(matrix,p): continue
   original=original_maps[p].get(rid,'missing'); fin=final_maps[p].get(rid,'missing')
   src=final_detail[p]['sources'].get(rid,[])
   refs='<br>'.join(f"{paths[p]}:{x['line']} ({x['label']}); evidence: {x['evidence']}; reason: {x['reason']}" for x in src)
   lines.append(f'| {rid} | {p} | {original} | {fin} | {refs} |')
 a.table.write_text('\n'.join(lines)+'\n')
 print(json.dumps({'output':str(a.output),'table':str(a.table),'ready':report['ready'],'original_footer_validation':footer_checks,'original':report['original_effective_totals'],'final':report['final_effective_totals'],'review_map':map_validation},indent=2))
if __name__=='__main__': main()
