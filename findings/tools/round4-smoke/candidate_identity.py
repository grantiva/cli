#!/usr/bin/env python3
"""Validate one frozen Task 8 candidate and controller ownership manifest."""
import argparse, hashlib, json, pathlib, subprocess

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
    repo=pathlib.Path(rr['repoPath']).resolve(); require(command(['git','-C',str(repo),'rev-parse','HEAD'])==rr['sourceSHA'],'runner source HEAD mismatch')
    proof=rr['uncachedTestProof']; docs={}
    for key in ('start','result','stdout','stderr','grantivaHomeBefore','grantivaHomeAfter','maestroHomeBefore','maestroHomeAfter'):
        entry=proof[key]; path=pathlib.Path(entry['path']).resolve(); require(file_sha(path)==entry['sha256'],f'runner proof {key} hash mismatch'); docs[key]=path
    start=json.loads(docs['start'].read_text()); result=json.loads(docs['result'].read_text()); expected=['go','test','-count=1','./pkg/driver/uiautomator2/...','./pkg/executor/...','./pkg/report/...','./pkg/cli/...']
    require(start['head']==rr['sourceSHA'] and result['head']==rr['sourceSHA'] and start['argv']==expected,'uncached runner proof command/head mismatch')
    require(result['exitCode']==0 and start['apiEnvironmentUnset'] is True and result['apiEnvironmentUnset'] is True,'uncached runner test did not pass cleanly')
    require(start['grantivaRunnerHome']!=start['maestroRunnerHome'] and all(docs[k].read_text()=='' for k in ('grantivaHomeBefore','grantivaHomeAfter','maestroHomeBefore','maestroHomeAfter')),'uncached runner test homes not fresh/empty')
    lines=[x for x in docs['stdout'].read_text().splitlines() if x.strip()]; packages=['github.com/devicelab-dev/maestro-runner/pkg/driver/uiautomator2','github.com/devicelab-dev/maestro-runner/pkg/executor','github.com/devicelab-dev/maestro-runner/pkg/report','github.com/devicelab-dev/maestro-runner/pkg/cli']; require(len(lines)==4 and all(line.startswith('ok  \t'+pkg+'\t') for line,pkg in zip(lines,packages)) and docs['stderr'].read_text()=='','uncached runner package proof mismatch')
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
    if apk:
        demo=cm['demo']; require(demo['sourceSHA']=='1552ae983a27528eff4c1f8145aa075698b47f71','demo source mismatch'); require(str(pathlib.Path(apk).resolve())==str(pathlib.Path(demo['androidAPK']['path']).resolve()) and file_sha(apk)==demo['androidAPK']['sha256'],'demo APK mismatch')
    ios_app=cm['demo']['iosApp']; require(pathlib.Path(ios_app['path']).is_dir(),'iOS app missing'); verify_files(ios_app['path'],ios_app,'iOS app')
    if platform and device:
        require(own.get('sessionId')=='fix4-8','ownership session mismatch'); entry=own['devices'][platform]; require(entry['platform']==platform and entry['id']==device and entry.get('owned') is True and entry.get('createdEpoch') and entry.get('provision'), 'device not controller-owned'); require(entry.get('name') and entry.get('runtime'),'device identity incomplete')
        if platform=='android': require(entry['avd']==android_avd,'owned Android AVD mismatch')
    return {'candidateManifest':str(cm_path),'candidateManifestSHA256':file_sha(cm_path),'ownershipManifest':str(own_path),'ownershipManifestSHA256':file_sha(own_path),'sourceHEAD':cli['mergedSHA'],'binarySHA256':cli['binary']['sha256'],'bundleManifestSHA256':cli['bundle']['manifestSHA256'],'runnerSourceSHA':rr['sourceSHA'],'runnerSHA256':packaged['sha256'],'installedRunnerSHA256':rr['installed']['sha256'],'runnerInstallStamp':rr['installed']['installStamp'],'demoSourceSHA':cm['demo']['sourceSHA'],'iosAppManifestSHA256':ios_app['manifestSHA256']}

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--candidate-manifest',required=True); p.add_argument('--ownership-manifest',required=True); p.add_argument('--source-root',required=True); p.add_argument('--binary',required=True); p.add_argument('--bundle',required=True); p.add_argument('--runner',required=True); p.add_argument('--runner-home',required=True); p.add_argument('--platform'); p.add_argument('--device'); p.add_argument('--android-avd'); p.add_argument('--apk'); a=p.parse_args()
    print(json.dumps(validate(a.candidate_manifest,a.ownership_manifest,source_root=a.source_root,binary=a.binary,bundle=a.bundle,runner=a.runner,runner_home=a.runner_home,platform=a.platform,device=a.device,android_avd=a.android_avd,apk=a.apk),indent=2))
