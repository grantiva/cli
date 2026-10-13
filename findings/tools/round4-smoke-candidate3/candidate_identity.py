#!/usr/bin/env python3
"""Validate one frozen Task 8 candidate and controller ownership manifest."""
import argparse, hashlib, json, pathlib, re, subprocess

EXPECTED_RUNNER_SHA='ba9008f4b2cd2c7320a9c46e04faed612b0958a2'

def file_sha(path): return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
def tree_sha(path):
    root=pathlib.Path(path); h=hashlib.sha256()
    for item in sorted(p for p in root.rglob('*') if p.is_file()):
        h.update(str(item.relative_to(root)).encode()+b'\0'); h.update(bytes.fromhex(file_sha(item)))
    return h.hexdigest()
def manifest_sha(files): return hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def verify_files(root,record,label):
    files=record.get('files'); require(isinstance(files,list) and files,label+' file manifest missing')
    actual=[]
    for item in sorted(p for p in pathlib.Path(root).rglob('*') if p.is_file()): actual.append({'path':str(item.relative_to(root)),'sha256':file_sha(item)})
    require(actual==files,label+' file manifest mismatch'); require(manifest_sha(files)==record['manifestSHA256'],label+' manifest hash mismatch')
def verify_runner_proof(rr):
    require(rr.get('sourceSHA')==EXPECTED_RUNNER_SHA,'runner source SHA is not the frozen Task 8 runner')
    repo=pathlib.Path(rr['repoPath']).resolve(); require(command(['git','-C',str(repo),'rev-parse','HEAD'])==EXPECTED_RUNNER_SHA,'runner source HEAD mismatch'); require(command(['git','-C',str(repo),'status','--porcelain=v1'])=='','runner source checkout is dirty')
    proof=rr['uncachedTestProof']; docs={}
    keys=('start','result','argv','head','unitRoot','stdout','stderr','exit','statusBefore','statusAfter','grantivaHomeBefore','grantivaHomeAfter','maestroHomeBefore','maestroHomeAfter')
    expected_names={'start':'start.json','result':'result.json','argv':'argv.txt','head':'head.txt','unitRoot':'unit-root.txt','stdout':'stdout.log','stderr':'stderr.log','exit':'exit.txt','statusBefore':'status-before.txt','statusAfter':'status-after.txt','grantivaHomeBefore':'grantiva-home-before.txt','grantivaHomeAfter':'grantiva-home-after.txt','maestroHomeBefore':'maestro-home-before.txt','maestroHomeAfter':'maestro-home-after.txt'}
    for key in keys:
        entry=proof[key]; path=pathlib.Path(entry['path']).resolve(); require(file_sha(path)==entry['sha256'],f'runner proof {key} hash mismatch'); docs[key]=path
    parents={path.parent for path in docs.values()}; require(len(parents)==1 and next(iter(parents)).name=='go-test-uncached-metadata-complete','runner proof is not the governing metadata-complete capture')
    require(all(docs[key].name==name for key,name in expected_names.items()),'runner proof artifact name mismatch')
    start=json.loads(docs['start'].read_text()); result=json.loads(docs['result'].read_text())
    common=('startedAt','head','argvFile','session','apiKey','count','homeRoot')
    require(all(start.get(key)==result.get(key) for key in common),'uncached runner start/result metadata mismatch')
    require(start.get('head')==result.get('head')==EXPECTED_RUNNER_SHA and docs['head'].read_text().strip()==EXPECTED_RUNNER_SHA,'uncached runner proof source mismatch')
    require(start.get('argvFile')=='argv.txt' and start.get('session')=='fix4-7b' and start.get('apiKey')=='unset' and start.get('count')==1,'uncached runner proof metadata mismatch')
    require(result.get('exit')==0 and result.get('endedAt') and docs['exit'].read_text().strip()=='0','uncached runner test did not pass cleanly')
    require(docs['unitRoot'].read_text().strip()==start.get('homeRoot'),'uncached runner proof home root mismatch')
    expected_argv='env -u GRANTIVA_API_KEY GRANTIVA_SESSION_ID=fix4-7b GRANTIVA_RUNNER_HOME=<fresh>/grantiva-home MAESTRO_RUNNER_HOME=<fresh>/maestro-home GOCACHE=<fresh>/go-cache TMPDIR=<fresh>/tmp go test -count=1 . ./pkg/device/... ./pkg/executor/... ./pkg/report/... ./pkg/cli/... ./pkg/driver/uiautomator2/...'
    require(docs['argv'].read_text().strip()==expected_argv,'uncached runner proof command mismatch')
    empty=('stderr','statusBefore','statusAfter','grantivaHomeBefore','grantivaHomeAfter','maestroHomeBefore','maestroHomeAfter')
    require(all(docs[key].read_bytes()==b'' for key in empty),'uncached runner source status, stderr, or homes not clean and empty')
    lines=[line for line in docs['stdout'].read_text().splitlines() if line.strip()]
    packages=['github.com/devicelab-dev/maestro-runner/pkg/device','github.com/devicelab-dev/maestro-runner/pkg/executor','github.com/devicelab-dev/maestro-runner/pkg/report','github.com/devicelab-dev/maestro-runner/pkg/cli','github.com/devicelab-dev/maestro-runner/pkg/driver/uiautomator2']
    require(len(lines)==6 and lines[0].split('\t')==['?   ','github.com/devicelab-dev/maestro-runner','[no test files]'],'uncached runner root no-tests proof mismatch')
    require(all(line.split('\t')[0]=='ok  ' and line.split('\t')[1]==pkg and len(line.split('\t'))==3 and re.fullmatch(r'(?:0|[1-9]\d*)(?:\.\d+)?s',line.split('\t')[2]) for line,pkg in zip(lines[1:],packages)),'uncached runner package proof mismatch')
def verify_source(record,label):
    repo=pathlib.Path(record['repoPath']).resolve()
    require(command(['git','-C',str(repo),'rev-parse','HEAD'])==record['sourceSHA'],label+' source HEAD mismatch')
def command(argv): return subprocess.run(argv,capture_output=True,text=True,check=True,timeout=20).stdout.strip()
def require(value,message):
    if not value: raise ValueError(message)

def validate(candidate_manifest,ownership_manifest,*,source_root,binary,bundle,runner,runner_home,platform=None,device=None,android_avd=None,apk=None):
    cm_path=pathlib.Path(candidate_manifest).resolve(); own_path=pathlib.Path(ownership_manifest).resolve(); cm=json.loads(cm_path.read_text()); own=json.loads(own_path.read_text())
    require(cm.get('schema')=='grantiva.task8.candidate.v1','candidate schema')
    require(own.get('schema')=='grantiva.task8.ownership.v1','ownership schema')
    source=pathlib.Path(source_root).resolve(); binary=pathlib.Path(binary).resolve(); bundle=pathlib.Path(bundle).resolve(); runner=pathlib.Path(runner).resolve(); home=pathlib.Path(runner_home).resolve(); cli=cm['cli']; rr=cm['runner']
    require(str(source)==str(pathlib.Path(cli['repoPath']).resolve()),'CLI repository path mismatch'); require(command(['git','-C',str(source),'rev-parse','HEAD'])==cli['mergedSHA'],'merged source HEAD mismatch')
    require(str(binary)==str(pathlib.Path(cli['binary']['path']).resolve()) and file_sha(binary)==cli['binary']['sha256'],'candidate binary mismatch'); require(command([str(binary),'--version'])==cli['binary']['version'],'candidate version mismatch')
    require(str(bundle)==str(pathlib.Path(cli['bundle']['path']).resolve()),'resource bundle path mismatch'); verify_files(bundle,cli['bundle'],'resource bundle')
    verify_runner_proof(rr); packaged=rr['packaged']; require(str(runner)==str(pathlib.Path(packaged['path']).resolve()) and file_sha(runner)==packaged['sha256'],'packaged runner mismatch'); require(command([str(runner),'--version'])==packaged['version'],'packaged runner version mismatch')
    installed=pathlib.Path(rr['installed']['path']).resolve(); require(installed.is_relative_to(home),'installed runner outside runner home'); require(rr['installed'].get('installStamp'),'installed runner stamp missing')
    require(file_sha(installed)==rr['installed']['sha256'] and command([str(installed),'--version'])==rr['installed']['version'],'upgraded runner mismatch'); require(rr['runnerHome']==str(home),'runner home mismatch')
    demo=cm['demo']; verify_source(demo,'demo')
    if apk:
        require(str(pathlib.Path(apk).resolve())==str(pathlib.Path(demo['androidAPK']['path']).resolve()) and file_sha(apk)==demo['androidAPK']['sha256'],'demo APK mismatch')
    ios_app=demo['iosApp']; require(pathlib.Path(ios_app['path']).is_dir(),'iOS app missing'); verify_files(ios_app['path'],ios_app,'iOS app')
    if platform and device:
        require(own.get('sessionId')=='fix4-8-c3','ownership session mismatch'); entry=own['devices'][platform]; require(entry['platform']==platform and entry['id']==device and entry.get('owned') is True and entry.get('createdEpoch') and entry.get('provision'), 'device not controller-owned'); require(entry.get('name') and entry.get('runtime'),'device identity incomplete')
        if platform=='android': require(entry['avd']==android_avd,'owned Android AVD mismatch')
    return {'candidateManifest':str(cm_path),'candidateManifestSHA256':file_sha(cm_path),'ownershipManifest':str(own_path),'ownershipManifestSHA256':file_sha(own_path),'sourceHEAD':cli['mergedSHA'],'binarySHA256':cli['binary']['sha256'],'bundleManifestSHA256':cli['bundle']['manifestSHA256'],'runnerSourceSHA':rr['sourceSHA'],'runnerSHA256':packaged['sha256'],'installedRunnerSHA256':rr['installed']['sha256'],'runnerInstallStamp':rr['installed']['installStamp'],'demoSourceSHA':cm['demo']['sourceSHA'],'iosAppManifestSHA256':ios_app['manifestSHA256']}

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--candidate-manifest',required=True); p.add_argument('--ownership-manifest',required=True); p.add_argument('--source-root',required=True); p.add_argument('--binary',required=True); p.add_argument('--bundle',required=True); p.add_argument('--runner',required=True); p.add_argument('--runner-home',required=True); p.add_argument('--platform'); p.add_argument('--device'); p.add_argument('--android-avd'); p.add_argument('--apk'); a=p.parse_args()
    print(json.dumps(validate(a.candidate_manifest,a.ownership_manifest,source_root=a.source_root,binary=a.binary,bundle=a.bundle,runner=a.runner,runner_home=a.runner_home,platform=a.platform,device=a.device,android_avd=a.android_avd,apk=a.apk),indent=2))
