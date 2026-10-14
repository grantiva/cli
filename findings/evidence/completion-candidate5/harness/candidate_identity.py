#!/usr/bin/env python3
"""Validate one frozen Task 8 candidate and controller ownership manifest."""
import argparse, hashlib, json, pathlib, re, subprocess

EXPECTED_RUNNER_SHA='d98b08898f45b94bad607f76e19089bb0e15d5c0'
EXPECTED_REVIEWED_RUNNER_SHA='9c18b962a0d85bcbb76fb8141fdd4aae97d28389'
EXPECTED_RUNNER_TREE='060236c478bceba52bb7e54081dd06a44d6aa299'

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
    require(rr.get('sourceSHA')==EXPECTED_RUNNER_SHA,'runner source SHA is not the frozen candidate5 runner')
    require(rr.get('reviewedSourceSHA')==EXPECTED_REVIEWED_RUNNER_SHA,'reviewed runner SHA mismatch')
    require(rr.get('reviewedTreeSHA')==rr.get('mergedTreeSHA')==EXPECTED_RUNNER_TREE,'reviewed/merged runner tree binding mismatch')
    repo=pathlib.Path(rr['repoPath']).resolve()
    require(command(['git','-C',str(repo),'rev-parse','HEAD'])==EXPECTED_RUNNER_SHA,'runner source HEAD mismatch')
    require(command(['git','-C',str(repo),'status','--porcelain=v1'])=='','runner source checkout is dirty')
    reviewed_tree=command(['git','-C',str(repo),'rev-parse',EXPECTED_REVIEWED_RUNNER_SHA+'^{tree}'])
    merged_tree=command(['git','-C',str(repo),'rev-parse',EXPECTED_RUNNER_SHA+'^{tree}'])
    require(reviewed_tree==merged_tree==EXPECTED_RUNNER_TREE,'actual reviewed/merged runner trees differ')
    proof=rr.get('uncachedTestProof'); require(isinstance(proof,dict) and set(proof)=={'focused','full','vet'},'runner proof groups mismatch')
    docs={}
    for group,entries in proof.items():
        require(isinstance(entries,dict) and entries,f'runner proof {group} missing')
        docs[group]={}
        for key,entry in entries.items():
            path=pathlib.Path(entry['path']).resolve(); require(path.is_file(),f'runner proof {group}/{key} missing')
            require(file_sha(path)==entry['sha256'],f'runner proof {group}/{key} hash mismatch'); docs[group][key]=path
    focused=docs['focused']; require(set(focused)=={'command.txt','stdout.txt','stderr.txt','exit.txt'},'focused runner proof shape mismatch')
    fcmd=focused['command.txt'].read_text()
    require('commit='+EXPECTED_REVIEWED_RUNNER_SHA in fcmd,'focused proof reviewed SHA mismatch')
    require("go test ./pkg/driver/wda -run 'Tap.*(Back|Explicit)' -count=1" in fcmd,'focused WDA command mismatch')
    require(focused['exit.txt'].read_text().strip()=='0' and focused['stderr.txt'].read_bytes()==b'','focused WDA proof failed')
    require(re.search(r'^ok\s+github.com/devicelab-dev/maestro-runner/pkg/driver/wda\s+',focused['stdout.txt'].read_text(),re.M),'focused WDA package execution missing')
    full=docs['full']; require(set(full)=={'test.command.txt','test.stdout.txt','test.stderr.txt','test.exit.txt','test.timing.txt','provenance.txt'},'full runner proof shape mismatch')
    cmd=full['test.command.txt'].read_text().strip(); provenance=full['provenance.txt'].read_text()
    require('GRANTIVA_API_KEY=<unset>' in cmd and cmd.endswith('go test ./... -count=1'),'full runner command/API/count mismatch')
    home=re.search(r'GRANTIVA_RUNNER_HOME=(\S+)',cmd); maestro=re.search(r'MAESTRO_RUNNER_HOME=(\S+)',cmd); cache=re.search(r'GOCACHE=(\S+)',cmd); tmp=re.search(r'GOTMPDIR=(\S+)',cmd)
    require(all((home,maestro,cache,tmp)) and home.group(1)==maestro.group(1),'full runner homes missing or unequal')
    roots=[pathlib.Path(x.group(1)).resolve() for x in (home,cache,tmp)]
    require(all(str(x).startswith('/private/tmp/l87-full-go.') for x in roots) and len(set(map(str,roots)))==3,'full proof homes/cache/tmp not fresh and isolated')
    require('commit='+EXPECTED_REVIEWED_RUNNER_SHA in provenance and 'GRANTIVA_API_KEY=unset' in provenance,'full provenance source/API mismatch')
    require(f'GRANTIVA_RUNNER_HOME={home.group(1)}' in provenance and f'MAESTRO_RUNNER_HOME={home.group(1)}' in provenance,'full provenance homes mismatch')
    require(f'GOCACHE={cache.group(1)}' in provenance and f'GOTMPDIR={tmp.group(1)}' in provenance,'full provenance cache/tmp mismatch')
    require('tracked_status_begin\ntracked_status_end' in provenance,'reviewed runner source was not clean')
    require(full['test.exit.txt'].read_text().strip()=='0' and full['test.stderr.txt'].read_bytes()==b'','full Go proof failed')
    lines=[x for x in full['test.stdout.txt'].read_text().splitlines() if x.strip()]
    require(len(lines)==26 and any(re.match(r'^ok\s+github.com/devicelab-dev/maestro-runner/pkg/driver/wda\s+',x) for x in lines),'full ./... package/WDA execution mismatch')
    vet=docs['vet']; require(set(vet)=={'vet.command.txt','vet.stdout.txt','vet.stderr.txt','vet.exit.txt','vet.timing.txt'},'vet proof shape mismatch')
    vcmd=vet['vet.command.txt'].read_text().strip()
    require('GRANTIVA_API_KEY=<unset>' in vcmd and vcmd.endswith('go vet ./...'),'vet command/API mismatch')
    require(f'GRANTIVA_RUNNER_HOME={home.group(1)}' in vcmd and f'MAESTRO_RUNNER_HOME={home.group(1)}' in vcmd and f'GOCACHE={cache.group(1)}' in vcmd and f'GOTMPDIR={tmp.group(1)}' in vcmd,'vet isolation differs from full proof')
    require(vet['vet.exit.txt'].read_text().strip()=='0' and vet['vet.stdout.txt'].read_bytes()==b'' and vet['vet.stderr.txt'].read_bytes()==b'','go vet proof failed')

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
        require(own.get('sessionId')=='completion-candidate5','ownership session mismatch'); entry=own['devices'][platform]; require(entry['platform']==platform and entry['id']==device and entry.get('owned') is True and entry.get('createdEpoch') and entry.get('provision'), 'device not controller-owned'); require(entry.get('name') and entry.get('runtime'),'device identity incomplete')
        if platform=='android': require(entry['avd']==android_avd,'owned Android AVD mismatch')
    return {'candidateManifest':str(cm_path),'candidateManifestSHA256':file_sha(cm_path),'ownershipManifest':str(own_path),'ownershipManifestSHA256':file_sha(own_path),'sourceHEAD':cli['mergedSHA'],'binarySHA256':cli['binary']['sha256'],'bundleManifestSHA256':cli['bundle']['manifestSHA256'],'runnerSourceSHA':rr['sourceSHA'],'runnerSHA256':packaged['sha256'],'installedRunnerSHA256':rr['installed']['sha256'],'runnerInstallStamp':rr['installed']['installStamp'],'demoSourceSHA':cm['demo']['sourceSHA'],'iosAppManifestSHA256':ios_app['manifestSHA256']}

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--candidate-manifest',required=True); p.add_argument('--ownership-manifest',required=True); p.add_argument('--source-root',required=True); p.add_argument('--binary',required=True); p.add_argument('--bundle',required=True); p.add_argument('--runner',required=True); p.add_argument('--runner-home',required=True); p.add_argument('--platform'); p.add_argument('--device'); p.add_argument('--android-avd'); p.add_argument('--apk'); a=p.parse_args()
    print(json.dumps(validate(a.candidate_manifest,a.ownership_manifest,source_root=a.source_root,binary=a.binary,bundle=a.bundle,runner=a.runner,runner_home=a.runner_home,platform=a.platform,device=a.device,android_avd=a.android_avd,apk=a.apk),indent=2))
