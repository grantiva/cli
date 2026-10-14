#!/usr/bin/env python3
"""Build, promote, upgrade, and freeze completion candidate4. Prepared only; not executed."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, time

ROOT = Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression')
OUT = ROOT / 'findings/evidence/completion-candidate4'
EXPECTED_SOURCE = Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4')
QA = Path.home() / '.grantiva-qa/bin'

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save_exclusive(path, value):
    with Path(path).open('x') as f: json.dump(value, f, indent=2); f.write('\n')
def file_manifest(root):
    root=Path(root); return [{'path':str(p.relative_to(root)),'sha256':sha(p)} for p in sorted(root.rglob('*')) if p.is_file()]
def tree_record(root):
    rows=file_manifest(root); digest=hashlib.sha256(json.dumps(rows,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return {'path':str(root),'files':rows,'manifestSHA256':digest}
def git(source, *args): return subprocess.check_output(['git','-C',str(source),*args],text=True).strip()
def run(label, argv, cwd, runner_home, session, timeout=1200):
    target=OUT/label; target.mkdir(parents=True,exist_ok=False)
    env=os.environ.copy(); env.pop('GRANTIVA_API_KEY',None)
    env.update(GRANTIVA_RUNNER_HOME=str(runner_home),MAESTRO_RUNNER_HOME=str(runner_home),GRANTIVA_SESSION_ID=session)
    start={'argv':list(map(str,argv)),'cwd':str(cwd),'environment':{'GRANTIVA_RUNNER_HOME':str(runner_home),'MAESTRO_RUNNER_HOME':str(runner_home),'GRANTIVA_SESSION_ID':session,'GRANTIVA_API_KEY':'<unset>'},'startEpoch':time.time()}
    save_exclusive(target/'start.json',start)
    with (target/'stdout.log').open('xb') as stdout,(target/'stderr.log').open('xb') as stderr:
        proc=subprocess.run(start['argv'],cwd=cwd,env=env,stdout=stdout,stderr=stderr,timeout=timeout)
    result={**start,'exit':proc.returncode,'endEpoch':time.time()}; save_exclusive(target/'result.json',result)
    if proc.returncode: raise RuntimeError(f'{label} exit {proc.returncode}')
    return (target/'stdout.log').read_text().strip()
def verify_reference(entry):
    path=Path(entry['path']); assert path.is_file() and sha(path)==entry['sha256'], path

parser=argparse.ArgumentParser()
parser.add_argument('--merged-sha',required=True)
parser.add_argument('--source',required=True)
args=parser.parse_args()
state=json.loads((OUT/'initial-state.json').read_text())
assert args.merged_sha!='PENDING' and state['cliMergeSHA']!='PENDING'
assert args.source!='PENDING' and state['source']!='PENDING'
source=Path(args.source).resolve(); assert source==EXPECTED_SOURCE.resolve()==Path(state['source']).resolve()
assert args.merged_sha==state['cliMergeSHA'] and len(args.merged_sha)==40
scratch=Path(state['scratch']); home=Path(state['runnerHome']); build_home=Path(state['buildHome']); session=state['session']
assert scratch==Path('/private/tmp/grantiva-completion-candidate4-x_i_t3pq') and home==scratch/'runner-home'
assert session=='completion-candidate4' and OUT.resolve().is_relative_to(ROOT.resolve())
assert git(source,'rev-parse','HEAD')==args.merged_sha and git(source,'status','--porcelain')==''
previous_path=Path(state['previousManifest']); previous=json.loads(previous_path.read_text())
assert previous_path==ROOT/'findings/evidence/round4-coverage/candidate.json'
assert state['runnerSHA']==previous['runner']['sourceSHA']=='ba9008f4b2cd2c7320a9c46e04faed612b0958a2'
assert state['demoSHA']==previous['demo']['sourceSHA']=='84af7581b75134b0e417b254e4317d565f7b73c6'
equivalence=json.loads((OUT/'clone-equivalence.json').read_text()); before=json.loads((OUT/'clone-before-upgrade.json').read_text()); source_before=json.loads((OUT/'source-before-upgrade.json').read_text())
assert equivalence=={'captureStarted':equivalence['captureStarted'],'captureEnded':equivalence['captureEnded'],'entries':8593,'identical':True,'scope':'after clone, before install; source was read only'}
assert len(before)==len(source_before)==8593 and before==source_before
for row in before:
    target=home/row['path']; assert row['type'] in ('file','symlink')
    if row['type']=='symlink': assert target.is_symlink() and os.readlink(target)==row['target']
    else: assert target.is_file() and target.stat().st_size==row['bytes'] and sha(target)==row['sha256']

assert not (OUT/'candidate.json').exists() and not (OUT/'candidate.sha256').exists()
assert build_home.is_dir() and not list(build_home.iterdir())
build_scratch=scratch/'swift-build-scratch'; build_scratch.mkdir(exist_ok=False)
save_exclusive(OUT/'cli-source-before.json',{'repoPath':str(source),'head':args.merged_sha,'status':''})
run('release-build',['swift','build','-c','release','--scratch-path',build_scratch],source,build_home,session)
products=Path(run('release-path',['swift','build','-c','release','--scratch-path',build_scratch,'--show-bin-path'],source,build_home,session))
assert products.is_relative_to(build_scratch)
binary=products/'grantiva'; bundle=products/'grantiva_GrantivaCore.bundle'; assert binary.is_file() and bundle.is_dir()
assert git(source,'rev-parse','HEAD')==args.merged_sha and git(source,'status','--porcelain')=='' and not list(build_home.iterdir())
save_exclusive(OUT/'cli-source-after.json',{'repoPath':str(source),'head':args.merged_sha,'status':'','binarySHA256':sha(binary),'bundle':tree_record(bundle),'buildHomeAfter':[],'productsPath':str(products)})

# Promotion is allowed only while QA still equals the frozen candidate3 manifest.
assert sha(QA/'grantiva')==previous['cli']['binary']['sha256']
assert tree_record(QA/'grantiva_GrantivaCore.bundle')['files']==previous['cli']['bundle']['files']
backup=scratch/'previous-qa-candidate3'; backup.mkdir(exist_ok=False)
shutil.copy2(QA/'grantiva',backup/'grantiva'); shutil.copytree(QA/'grantiva_GrantivaCore.bundle',backup/'grantiva_GrantivaCore.bundle'); shutil.copy2(previous_path,backup/'candidate.json')
assert sha(backup/'grantiva')==previous['cli']['binary']['sha256'] and tree_record(backup/'grantiva_GrantivaCore.bundle')['files']==previous['cli']['bundle']['files']
shutil.copy2(binary,QA/'grantiva'); shutil.rmtree(QA/'grantiva_GrantivaCore.bundle'); shutil.copytree(bundle,QA/'grantiva_GrantivaCore.bundle')
assert sha(binary)==sha(QA/'grantiva') and file_manifest(bundle)==file_manifest(QA/'grantiva_GrantivaCore.bundle')
version=run('qa-version',[QA/'grantiva','--version'],scratch,home,session)
save_exclusive(OUT/'qa-promotion.json',{'source':str(products),'destination':str(QA),'previousCandidateBackup':str(backup),'sha256':sha(binary),'version':version,'sourceSHA':args.merged_sha})

native=scratch/'packaged-native'; native.mkdir(exist_ok=False)
archive=QA/'grantiva_GrantivaCore.bundle/Contents/Resources/grantiva-runner-arm64.tar.gz'
run('native-extract',['tar','-xzf',archive,'-C',native],scratch,home,session)
runner=native/'grantiva-runner'; runner_version=run('packaged-version',[runner,'--version'],scratch,home,session)
assert sha(runner)==previous['runner']['packaged']['sha256'] and runner_version==previous['runner']['packaged']['version']
run('upgrade-install',[QA/'grantiva','runner','install','--json'],scratch,home,session)
stamp=previous['runner']['installed']['installStamp']; installed=home/'versions'/stamp/'grantiva-runner'
installed_version=run('installed-version',[installed,'--version'],scratch,home,session)
assert sha(installed)==sha(runner)==previous['runner']['installed']['sha256'] and installed_version==runner_version
preserved_cache_entries=0
for row in before:
    if not row['path'].startswith('cache/'):
        continue
    target=home/row['path']
    if row['type']=='symlink': assert target.is_symlink() and os.readlink(target)==row['target']
    else: assert target.is_file() and sha(target)==row['sha256']
    preserved_cache_entries+=1
upgrade_dir=OUT/'upgrade'; upgrade_dir.mkdir(exist_ok=False)
save_exclusive(upgrade_dir/'acceptance.json',{
    'passed':True,
    'cloneEquivalenceEntries':8593,
    'preInstallCloneEquivalent':True,
    'preservedCacheEntries':preserved_cache_entries,
    'installedRunner':str(installed),
    'installStamp':stamp,
    'packagedRunnerSHA256':sha(runner),
    'installedRunnerSHA256':sha(installed),
    'runnerSourceSHA':state['runnerSHA'],
    'runnerTestProofDisposition':'unchanged-dependency provenance; not candidate4 execution'
})

# Reuse unchanged-dependency runner proof and demo/build proof only by verifying every referenced byte.
# These references are provenance, not fresh candidate4 test/build execution.
runner_repo=Path(previous['runner']['repoPath']); assert git(runner_repo,'rev-parse','HEAD')==state['runnerSHA'] and git(runner_repo,'status','--porcelain')==''
for entry in previous['runner']['uncachedTestProof'].values(): verify_reference(entry)
demo=previous['demo']; demo_repo=Path(demo['repoPath']); assert git(demo_repo,'rev-parse','HEAD')==state['demoSHA'] and git(demo_repo,'status','--porcelain')==''
for platform in ('ios','android'):
    for entry in demo['buildProof'][platform].values(): verify_reference(entry)
assert sha(demo['androidAPK']['path'])==demo['androidAPK']['sha256']
assert tree_record(Path(demo['iosApp']['path']))['files']==demo['iosApp']['files']

candidate={'schema':'grantiva.task8.candidate.v1','cli':{'repoPath':str(source),'mergedSHA':args.merged_sha,'binary':{'path':str(QA/'grantiva'),'sha256':sha(QA/'grantiva'),'version':version},'bundle':tree_record(QA/'grantiva_GrantivaCore.bundle')},'runner':{'repoPath':str(runner_repo),'sourceSHA':state['runnerSHA'],'runnerHome':str(home),'uncachedTestProof':previous['runner']['uncachedTestProof'],'packaged':{'path':str(runner),'sha256':sha(runner),'version':runner_version},'installed':{'path':str(installed),'sha256':sha(installed),'version':installed_version,'installStamp':stamp}},'demo':demo}
candidate_path=OUT/'candidate.json'; save_exclusive(candidate_path,candidate)
digest=sha(candidate_path); save_exclusive(OUT/'candidate.sha256',{'path':str(candidate_path),'sha256':digest,'createdEpoch':time.time()})
candidate_path.chmod(0o444); (OUT/'candidate.sha256').chmod(0o444)
print(json.dumps({'candidate':str(candidate_path),'sha256':digest,'source':str(source),'mergedSHA':args.merged_sha},indent=2))
