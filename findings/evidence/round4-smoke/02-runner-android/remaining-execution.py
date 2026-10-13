#!/usr/bin/env python3
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, subprocess, time, xml.etree.ElementTree as ET
from candidate_identity import validate as validate_identity

APK_SHA='5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a'
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def report_status(path):
    doc=json.loads((path/'report.json').read_text()); return doc,doc.get('status')

ap=argparse.ArgumentParser(); ap.add_argument('--candidate-manifest',required=True); ap.add_argument('--ownership-manifest',required=True); ap.add_argument('--binary',required=True); ap.add_argument('--bundle',required=True); ap.add_argument('--runner',required=True); ap.add_argument('--runner-home',required=True); ap.add_argument('--source-root',required=True); ap.add_argument('--project',required=True)
ap.add_argument('--serial',required=True); ap.add_argument('--avd',required=True); ap.add_argument('--apk',required=True); ap.add_argument('--adb',required=True); ap.add_argument('--uia2-sampler',required=True); ap.add_argument('--movement-analyzer',required=True); ap.add_argument('--runner-inputs',required=True); ap.add_argument('--optional-inputs',required=True); ap.add_argument('--crash-flow',required=True); ap.add_argument('--healthy-flow',required=True); ap.add_argument('--cycle-project',required=True); ap.add_argument('--cycle-flow',required=True); ap.add_argument('--evidence',required=True)
a=ap.parse_args(); root=pathlib.Path(a.evidence).resolve(); inputs=pathlib.Path(a.runner_inputs).resolve(); optional_inputs=pathlib.Path(a.optional_inputs).resolve()
for p in (a.binary,a.runner,a.runner_home,a.source_root,a.project,a.apk,a.adb,a.uia2_sampler,a.movement_analyzer,inputs,optional_inputs,a.crash_flow,a.healthy_flow,a.cycle_project,pathlib.Path(a.cycle_project)/a.cycle_flow):
    if not pathlib.Path(p).exists(): raise SystemExit(f'missing {p}')
if a.avd!='smoke4-android': raise SystemExit('expected newly owned smoke4-android AVD')
if sha(a.apk)!=APK_SHA: raise SystemExit('retained Task 3 APK hash mismatch')
required=['l51-direction.yaml','l51-element.yaml','l51-coordinates.yaml','l51-engine-adb.yaml','02-favorite.yaml','stop-bare-clearstate.yaml']
for name in required:
    if not (inputs/name).is_file(): raise SystemExit(f'missing input {inputs/name}')
for name in ('optional-miss.yaml','required-miss.yaml'):
    if not (optional_inputs/name).is_file(): raise SystemExit(f'missing input {optional_inputs/name}')
if os.environ.get('GRANTIVA_API_KEY'): raise SystemExit('GRANTIVA_API_KEY must be unset')
root.mkdir(parents=True,exist_ok=False)
identity=validate_identity(a.candidate_manifest,a.ownership_manifest,source_root=a.source_root,binary=a.binary,bundle=a.bundle,runner=a.runner,runner_home=a.runner_home,platform='android',device=a.serial,android_avd=a.avd,apk=a.apk)
# Direct runner invocations need the installed drivers; the CLI keeps the clone root.
candidate_path=pathlib.Path(identity['candidateManifest']); candidate_bytes=candidate_path.read_bytes()
if hashlib.sha256(candidate_bytes).hexdigest()!=identity['candidateManifestSHA256']: raise SystemExit('candidate manifest changed after validation')
runner_record=json.loads(candidate_bytes)['runner']; installed=pathlib.Path(runner_record['installed']['path']).resolve()
runner_home=pathlib.Path(a.runner_home).resolve(); installed_home=installed.parent
if installed_home!=(runner_home/'versions'/identity['runnerInstallStamp']).resolve(): raise SystemExit('installed runner version directory mismatch')
if not (sha(installed)==identity['installedRunnerSHA256']==identity['runnerSHA256']==sha(a.runner)): raise SystemExit('installed and packaged runner hash mismatch')
if not (installed_home/'drivers/android').is_dir(): raise SystemExit('installed Android drivers missing')
adb_parent=str(pathlib.Path(a.adb).resolve().parent)
env=os.environ.copy(); env.pop('GRANTIVA_API_KEY',None); env.update(GRANTIVA_RUNNER_HOME=str(runner_home),MAESTRO_RUNNER_HOME=str(installed_home),GRANTIVA_SESSION_ID='fix4-8',PATH=adb_parent+os.pathsep+env.get('PATH',os.defpath))
(root/'provenance.json').write_text(json.dumps({**identity,'binary':str(pathlib.Path(a.binary).resolve()),'runner':str(pathlib.Path(a.runner).resolve()),'runnerHome':str(pathlib.Path(a.runner_home).resolve()),'sourceRoot':str(pathlib.Path(a.source_root).resolve()),'project':str(pathlib.Path(a.project).resolve()),'serial':a.serial,'avd':a.avd,'apk':str(pathlib.Path(a.apk).resolve()),'apkSHA256':sha(a.apk),'apiKey':'unset','maestroRunnerHome':str(installed_home),'adbParent':adb_parent},indent=2)+'\n')

def run(label,argv,expected,report=None,timeout=180):
    d=root/label; d.mkdir(); started=time.time(); load_start=os.getloadavg(); (d/'command.json').write_text(json.dumps({'argv':list(map(str,argv)),'cwd':str(pathlib.Path(a.project).resolve()),'startedEpoch':started,'hostLoadStart':load_start},indent=2)+'\n')
    with (d/'stdout.raw').open('wb') as out,(d/'stderr.raw').open('wb') as err: p=subprocess.run(list(map(str,argv)),cwd=a.project,env=env,stdout=out,stderr=err,timeout=timeout)
    result={'startedEpoch':started,'endedEpoch':time.time(),'hostLoadStart':load_start,'hostLoadEnd':os.getloadavg(),'exit':p.returncode,'expectedExit':expected}; (d/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if p.returncode!=expected: raise AssertionError((label,p.returncode,expected))
    if report:
        src=pathlib.Path(report); shutil.copytree(src,d/'raw-report'); doc,status=report_status(src); result['reportStatus']=status; result['reportFlows']=doc.get('flows'); (d/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    return d,result

checks=[]
def cli_case(label,flow,json_mode,expected,expected_status):
    report=root/(label+'-report'); ready=root/(label+'-ready.json'); argv=[a.binary,'run']+(['--json'] if json_mode else [])+['--platform','android','--device',a.serial,'--no-build','--flow',flow,'--report-dir',report,'--ready-file',ready]
    d,result=run(label,argv,expected,report,240); ready_doc=json.loads(ready.read_text()); assert ready_doc['status']==expected_status and ready_doc['flows'][0]['status']==expected_status
    result['ready']=ready_doc; (d/'ready.json').write_bytes(ready.read_bytes()); return d,json.loads((d/'raw-report/report.json').read_text())
surface=[]
for mode in ('text','json'):
  for repetition in range(1,4):
    label=f'optional-{mode}-{repetition}'; d,doc=cli_case(label,optional_inputs/'optional-miss.yaml',mode=='json',0,'passed'); flow=doc['flows'][0]; assert doc['status']=='passed' and flow['commands']['warned']==1 and flow['commands']['failed']==0
    detail=json.loads((d/'raw-report'/flow['dataFile']).read_text()); assert [x['status'] for x in detail['commands']]==['passed','warned','passed']; warned=detail['commands'][1]; assert warned['error']['type']=='element_not_found' and 'No Such Element fix4-3' in warned['error']['message']
    junit=(d/'raw-report/junit-report.xml').read_text(); assert 'failures="0"' in junit and 'skipped="0"' in junit and 'warning: tapOn: Element not found' in junit
    output=(d/'stdout.raw').read_text(errors='replace'); assert 'Element not found' in output and 'No Such Element fix4-3' in output
    if mode=='json': assert json.loads(output)['allPassed'] is True
    surface.append({'kind':'optional','mode':mode,'repetition':repetition,'joined':True})
  d,doc=cli_case('required-'+mode,optional_inputs/'required-miss.yaml',mode=='json',1,'failed'); flow=doc['flows'][0]; assert doc['status']=='failed' and flow['commands']['failed']==1
  detail=json.loads((d/'raw-report'/flow['dataFile']).read_text()); assert [x['status'] for x in detail['commands']]==['passed','failed','skipped']; failed=detail['commands'][1]; assert failed['error']['type']=='element_not_found'
  junit=(d/'raw-report/junit-report.xml').read_text(); assert 'failures="1"' in junit and 'Element not found' in junit
  output=(d/'stdout.raw').read_text(errors='replace'); assert 'Element not found' in output and 'No Such Element fix4-3' in output
  if mode=='json': assert json.loads(output)['allPassed'] is False
  surface.append({'kind':'required','mode':mode,'joined':True})
checks.append({'optionalRequired':{'optionalTextRuns':3,'optionalJSONRuns':3,'requiredTextControl':1,'requiredJSONControl':1,'surfaceJoins':surface}})
cycle_dir=root/'cycle'; cycle_dir.mkdir(); argv=[a.binary,'run','--platform','android','--device',a.serial,'--no-build','--flow',a.cycle_flow]; cycle_started=time.time(); cycle_load=os.getloadavg()
(cycle_dir/'command.json').write_text(json.dumps({'argv':argv,'cwd':str(pathlib.Path(a.cycle_project).resolve()),'startedEpoch':cycle_started,'hostLoadStart':cycle_load},indent=2)+'\n')
with (cycle_dir/'stdout.raw').open('wb') as out,(cycle_dir/'stderr.raw').open('wb') as err: cycle=subprocess.run(argv,cwd=a.cycle_project,env=env,stdout=out,stderr=err,timeout=30)
cycle_text=(cycle_dir/'stdout.raw').read_text(errors='replace')+(cycle_dir/'stderr.raw').read_text(errors='replace'); (cycle_dir/'result.json').write_text(json.dumps({'exit':cycle.returncode,'startedEpoch':cycle_started,'endedEpoch':time.time(),'hostLoadStart':cycle_load,'hostLoadEnd':os.getloadavg()},indent=2)+'\n')
assert cycle.returncode==1 and 'circular dependency detected:' in cycle_text and pathlib.Path(a.cycle_flow).name in cycle_text
checks.append({'subdirectoryCycle':True})
(root/'acceptance.json').write_text(json.dumps({'passed':True,'checks':checks},indent=2)+'\n')
