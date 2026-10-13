"""Controller-only merged build, QA promotion, upgrade, and candidate freeze."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, time
p=argparse.ArgumentParser();p.add_argument('--merged-sha',required=True);a=p.parse_args()
r=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression')
e=r/'findings/evidence/round4-smoke-candidate3'; state=json.loads((e/'initial-state.json').read_text())
s=Path(state['scratch']);src=Path(state['source']);home=Path(state['runnerHome']);out=e/'01-candidate'
assert state['demoSHA']=='84af7581b75134b0e417b254e4317d565f7b73c6'
EXPECTED_RUNNER_SHA='ba9008f4b2cd2c7320a9c46e04faed612b0958a2'
assert state['runnerSHA']==EXPECTED_RUNNER_SHA
def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def files(path):return [{'path':str(x.relative_to(path)),'sha256':sha(x)} for x in sorted(path.rglob('*')) if x.is_file()]
def record(path):
 f=files(path);return {'path':str(path),'files':f,'manifestSHA256':hashlib.sha256(json.dumps(f,sort_keys=True,separators=(',',':')).encode()).hexdigest()}
def git(*args):return subprocess.check_output(['git','-C',str(src),*args],text=True).strip()
def run(label,argv,cwd,runnerhome,timeout=1200):
 d=out/label;d.mkdir(parents=True,exist_ok=False);env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(GRANTIVA_RUNNER_HOME=str(runnerhome),MAESTRO_RUNNER_HOME=str(runnerhome),GRANTIVA_SESSION_ID='fix4-8-c3')
 m={'argv':list(map(str,argv)),'cwd':str(cwd),'runnerHome':str(runnerhome),'apiEnvironmentUnset':True,'session':'fix4-8-c3','startEpoch':time.time()};save(d/'start.json',m)
 with (d/'stdout.log').open('wb') as so,(d/'stderr.log').open('wb') as se:q=subprocess.run(m['argv'],cwd=cwd,env=env,stdout=so,stderr=se,timeout=timeout)
 m.update(exit=q.returncode,endEpoch=time.time());save(d/'result.json',m);assert q.returncode==0,(label,q.returncode);return (d/'stdout.log').read_text().strip()
assert not (e/'candidate.json').exists()
assert git('rev-parse','HEAD')==a.merged_sha and git('status','--porcelain')==''
save(out/'cli-source-before.json',{'head':a.merged_sha,'status':'','repoPath':str(src)})
buildhome=Path(state['buildHome']);assert not list(buildhome.iterdir())
buildscratch=s/'swift-build-scratch';assert buildscratch!=buildhome;buildscratch.mkdir();assert not list(buildscratch.iterdir())
run('release-build',['swift','build','-c','release','--scratch-path',buildscratch],src,buildhome)
assert git('rev-parse','HEAD')==a.merged_sha and git('status','--porcelain')=='' and not list(buildhome.iterdir())
products=Path(run('release-path',['swift','build','-c','release','--scratch-path',buildscratch,'--show-bin-path'],src,buildhome));assert products.is_relative_to(buildscratch)
binary=products/'grantiva';bundle=products/'grantiva_GrantivaCore.bundle';assert binary.is_file() and bundle.is_dir()
save(out/'cli-source-after.json',{'head':git('rev-parse','HEAD'),'status':git('status','--porcelain'),'binarySHA256':sha(binary),'bundle':record(bundle),'buildRunnerHomeAfter':[],'buildScratchPath':str(buildscratch),'buildScratchAfter':sorted(x.name for x in buildscratch.iterdir()),'productsPath':str(products)})
qa=Path.home()/'.grantiva-qa/bin';old_manifest=r/'findings/evidence/round4-smoke-candidate2/candidate.json';old=json.loads(old_manifest.read_text());assert sha(qa/'grantiva')==old['cli']['binary']['sha256']
assert record(qa/'grantiva_GrantivaCore.bundle')['files']==old['cli']['bundle']['files']
backup=s/'previous-qa-candidate2';backup.mkdir();shutil.copy2(qa/'grantiva',backup/'grantiva');shutil.copytree(qa/'grantiva_GrantivaCore.bundle',backup/'grantiva_GrantivaCore.bundle');shutil.copy2(old_manifest,backup/'candidate.json')
assert sha(backup/'grantiva')==old['cli']['binary']['sha256'] and record(backup/'grantiva_GrantivaCore.bundle')['files']==old['cli']['bundle']['files']
shutil.copy2(binary,qa/'grantiva');shutil.rmtree(qa/'grantiva_GrantivaCore.bundle');shutil.copytree(bundle,qa/'grantiva_GrantivaCore.bundle')
assert sha(binary)==sha(qa/'grantiva') and files(bundle)==files(qa/'grantiva_GrantivaCore.bundle')
version=run('qa-version',[qa/'grantiva','--version'],s,home)
save(out/'qa-promotion.json',{'source':str(products),'destination':str(qa),'previousCandidateBackup':str(backup),'sha256':sha(binary),'version':version,'sourceSHA':a.merged_sha})
native=s/'packaged-native';native.mkdir();archive=qa/'grantiva_GrantivaCore.bundle/Contents/Resources/grantiva-runner-arm64.tar.gz'
run('native-extract',['tar','-xzf',archive,'-C',native],s,home)
runner=native/'grantiva-runner';assert runner.is_file();runner_version=run('packaged-version',[runner,'--version'],s,home)
assert runner_version.splitlines()[0]=='grantiva-runner 1.1.28-grantiva.15'
clone=json.loads((out/'upgrade/clone.json').read_text());source_before=json.loads((out/'upgrade/source-before.json').read_text());before=json.loads((out/'upgrade/clone-before-upgrade.json').read_text())
assert home==s/'runner-home' and clone['argv']==['cp','-cR',str(Path.home()/'.grantiva/runner'),str(home)] and clone['exitCode']==0
assert len(source_before)==len(before)==8593 and source_before==before
for row in before:
 target=home/row['path']
 assert row['type'] in ('file','symlink')
 if row['type']=='symlink':assert target.is_symlink() and os.readlink(target)==row['target']
 else:assert target.is_file() and target.stat().st_size==row['bytes'] and sha(target)==row['sha256']
run('upgrade/install',[qa/'grantiva','runner','install','--json'],s,home)
installed=home/'versions/1.1.28-grantiva.15+android-drivers-2/grantiva-runner';assert sha(installed)==sha(runner)
installed_version=run('installed-version',[installed,'--version'],s,home);assert installed_version==runner_version
preserved=0
for row in before:
 if not row['path'].startswith('cache/'):continue
 target=home/row['path']
 if row['type']=='symlink':assert target.is_symlink() and os.readlink(target)==row['target']
 else:assert target.is_file() and sha(target)==row['sha256']
 preserved+=1
approved=r/'findings/evidence/fix4-7/wda/manifests-final/wda-cache.sha256';assert sha(approved)=='48c95fede130e55ad3ec7cb018dfa487807a319dfe8274f5cf75ef6ca9390c5c'
configs={}
for line in approved.read_text().splitlines():
 digest,rel=line.split('  ',1);rel=rel.removeprefix('./');assert sha(native/'cache/wda-builds'/rel)==digest
 config=rel.split('/')[0];configs.setdefault(config,[]).append((rel,digest))
assert len(configs)==4 and all(len(v)==200 for v in configs.values());checks=[]
for config,entries in configs.items():
 existing=any(x['path'].startswith('cache/wda-builds/'+config+'/') for x in before)
 if not existing:
  for rel,digest in entries:assert sha(home/'cache/wda-builds'/rel)==digest
 tree=home/'cache/wda-builds'/config;assert list(tree.rglob('*.xctestrun')) and list(tree.rglob('*.app'))
 checks.append({'config':config,'provenance':'preservedExisting' if existing else 'bundleAdded','files':len(entries),'complete':True,'bundleBytesMatch':not existing})
save(out/'upgrade/acceptance.json',{'passed':True,'existingCacheEntriesPreserved':preserved,'configs':checks,'task7ManifestSHA256':sha(approved),'installedRunner':str(installed),'packagedRunner':str(runner),'runnerSHA256':sha(runner)})
proofroot=r/'findings/evidence/fix4-7b/runner-build/go-test-uncached-metadata-complete';mapping={'start':'start.json','result':'result.json','argv':'argv.txt','head':'head.txt','unitRoot':'unit-root.txt','stdout':'stdout.log','stderr':'stderr.log','exit':'exit.txt','statusBefore':'status-before.txt','statusAfter':'status-after.txt','grantivaHomeBefore':'grantiva-home-before.txt','grantivaHomeAfter':'grantiva-home-after.txt','maestroHomeBefore':'maestro-home-before.txt','maestroHomeAfter':'maestro-home-after.txt'}
proof={k:{'path':str(proofroot/v),'sha256':sha(proofroot/v)} for k,v in mapping.items()}
runner_repo=Path('/Users/kyle/Developer/maestro-runner/.worktrees/package-round4-repair')
runner_head=subprocess.check_output(['git','-C',str(runner_repo),'rev-parse','HEAD'],text=True).strip();runner_status=subprocess.check_output(['git','-C',str(runner_repo),'status','--porcelain=v1'],text=True)
assert runner_head==EXPECTED_RUNNER_SHA and runner_status==''
proof_start=json.loads((proofroot/'start.json').read_text());proof_result=json.loads((proofroot/'result.json').read_text())
assert proof_start['head']==proof_result['head']==EXPECTED_RUNNER_SHA and (proofroot/'head.txt').read_text().strip()==EXPECTED_RUNNER_SHA
demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2');demo_head=subprocess.check_output(['git','-C',str(demo),'rev-parse','HEAD'],text=True).strip();demo_status=subprocess.check_output(['git','-C',str(demo),'status','--porcelain=v1'],text=True);assert demo_head==state['demoSHA'] and demo_status==''
iosroot=e/'build-inputs/ios';androidroot=e/'build-inputs/android';ios=json.loads((iosroot/'artifact.json').read_text());android=json.loads((androidroot/'artifact.json').read_text());ios_start=json.loads((iosroot/'start.json').read_text());ios_result=json.loads((iosroot/'result.json').read_text());ios_qualification=json.loads((iosroot/'post-build-qualification.json').read_text());android_start=json.loads((androidroot/'start.json').read_text());android_result=json.loads((androidroot/'result.json').read_text())
ios_record=record(Path(ios['path']));assert ios['sourceSHA']==android['sourceSHA']==state['demoSHA'];assert ios_record['files']==ios['files'] and ios_record['manifestSHA256']==ios['manifestSHA256'] and sha(Path(android['path']))==android['sha256']
for start,result in ((ios_start,ios_result),(android_start,android_result)):
 assert start['sourceSHA']==result['sourceSHA']==result['headAfter']==state['demoSHA'];assert start['repoPath']==result['repoPath']==str(demo);assert start['argv']==result['argv'] and start['cwd']==result['cwd'] and start['start']==result['start'];assert start['homeBefore']==result['homeBefore']==result['homeAfter']==[];assert start['apiEnvironmentUnset'] is result['apiEnvironmentUnset'] is True and start['session']==result['session']=='fix4-8-c3';assert result['exit']==0 and result['end']>=result['start']
ios_derived=Path(ios['path']).parents[3];assert ios_start['argv']==['xcodebuild','clean','build','-project','ios/Landmarks.xcodeproj','-scheme','Landmarks (UI Testing)','-configuration','UITesting','-destination','generic/platform=iOS Simulator','-derivedDataPath',str(ios_derived),'CODE_SIGNING_ALLOWED=NO'] and ios_start['cwd']==str(demo)
assert android_start['argv']==['./gradlew','clean','assembleFreeDebug','--no-daemon'] and android_start['cwd']==str(demo/'android') and Path(android['path']).resolve()==(demo/'android/app/build/outputs/apk/free/debug/app-free-debug.apk').resolve()
assert ios_result['statusAfter']==ios_qualification['originalStatusAfter'];assert ios_qualification['head']==state['demoSHA'] and ios_qualification['statusAfterBothBuilds']=='' and ios_qualification['buildExit']==ios_result['exit']==0 and ios_qualification['artifactManifestSHA256']==ios['manifestSHA256'];assert '** BUILD SUCCEEDED **' in (iosroot/'stdout.log').read_text()
assert android_result['statusAfter']=='' and 'BUILD SUCCESSFUL' in (androidroot/'stdout.log').read_text()
demo_build_proof={'sourceHEAD':demo_head,'sourceStatus':demo_status,'ios':{name:{'path':str(iosroot/name),'sha256':sha(iosroot/name)} for name in ('start.json','result.json','artifact.json','post-build-qualification.json','stdout.log','stderr.log')},'android':{name:{'path':str(androidroot/name),'sha256':sha(androidroot/name)} for name in ('start.json','result.json','artifact.json','stdout.log','stderr.log')}};save(out/'demo-build-validation.json',demo_build_proof)
candidate={'schema':'grantiva.task8.candidate.v1','cli':{'repoPath':str(src),'mergedSHA':a.merged_sha,'binary':{'path':str(qa/'grantiva'),'sha256':sha(qa/'grantiva'),'version':version},'bundle':record(qa/'grantiva_GrantivaCore.bundle')},'runner':{'repoPath':str(runner_repo),'sourceSHA':EXPECTED_RUNNER_SHA,'runnerHome':str(home),'uncachedTestProof':proof,'packaged':{'path':str(runner),'sha256':sha(runner),'version':runner_version},'installed':{'path':str(installed),'sha256':sha(installed),'version':installed_version,'installStamp':'1.1.28-grantiva.15+android-drivers-2'}},'demo':{'repoPath':str(demo),'sourceSHA':state['demoSHA'],'buildProof':demo_build_proof,'androidAPK':{'path':android['path'],'sha256':android['sha256']},'iosApp':record(Path(ios['path']))}}
save(e/'candidate.json',candidate);print(json.dumps({'candidate':str(e/'candidate.json'),'sha256':sha(e/'candidate.json'),'cacheEntriesPreserved':preserved},indent=2))
