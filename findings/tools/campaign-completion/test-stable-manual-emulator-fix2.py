#!/usr/bin/env python3
"""Focused inert checks for fix round 2; never invokes adb or an emulator."""
import base64, importlib.util, json, tempfile, time
from pathlib import Path

HERE=Path(__file__).parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'stable-manual-emulator.py'); fixture=importlib.util.module_from_spec(spec); spec.loader.exec_module(fixture)

def identity(command,ppid=100):
    return {'pid':42,'ppid':ppid,'pgid':42,'sessionId':42,'start':'Tue Oct 13 00:00:00 2026','executable':command.split()[0],'command':command}
WRAPPER=identity('/Users/kyle/Library/Android/sdk/emulator/emulator -avd cov4-android-2 -port 5556')
QEMU=identity('qemu-system-aarch64 -avd cov4-android-2 -port 5556',1)

class Alive:
    pid=42; returncode=None
    def __init__(self,*args,**kwargs): pass
    def poll(self): return None

# A normal nonzero/offline adb observation remains evidence and polling reaches ready.
originals=(fixture.preflight,fixture.process_identity,fixture.device_state,fixture.subprocess.Popen)
identities=iter([(WRAPPER,[]),(WRAPPER,[]),(QEMU,[])])
not_ready_records=[{'argv':['fake-adb'],'exit':1,'stdout':'','stderr':'device offline'}]*3
ready_records=[{'argv':['fake-adb'],'exit':0,'stdout':'ok','stderr':''}]*3
states=iter([({'state':'','avd':'','bootCompleted':''},not_ready_records),({'state':'device','avd':'cov4-android-2','bootCompleted':'1'},ready_records)])
try:
    fixture.preflight=lambda deadline:{'passed':True}
    fixture.process_identity=lambda pid,deadline:next(identities)
    fixture.device_state=lambda deadline:next(states)
    fixture.subprocess.Popen=Alive
    with tempfile.TemporaryDirectory() as temporary:
        evidence=Path(temporary)/'attempt'; assert fixture.launch(evidence,2)==0
        ownership=json.loads((evidence/'ownership.json').read_text())
        terminal=json.loads((evidence/'launch-terminal.json').read_text())
        assert ownership['identity']['command'].startswith('qemu-system')
        assert terminal['observations'][0]['probes'][0]['exit']==1 and len(terminal['observations'])==2
finally: fixture.preflight,fixture.process_identity,fixture.device_state,fixture.subprocess.Popen=originals

# Timeout bytes from both streams survive losslessly through the launch terminal record.
with tempfile.TemporaryDirectory() as temporary:
    emitter=Path(temporary)/'emit.sh'; emitter.write_text('#!/bin/sh\nprintf out-part\nprintf err-part >&2\nsleep 2\n'); emitter.chmod(0o700)
    try: fixture.probe(time.monotonic()+0.5,[str(emitter)])
    except fixture.ProbeFailure as error: timeout_failure=error
    else: raise AssertionError('emitting probe did not time out')
    assert base64.b64decode(timeout_failure.record['stdout']['data'])==b'out-part'
    assert base64.b64decode(timeout_failure.record['stderr']['data'])==b'err-part'
    originals=(fixture.preflight,fixture.process_identity,fixture.device_state,fixture.subprocess.Popen)
    try:
        fixture.preflight=lambda deadline:{'passed':True}
        fixture.process_identity=lambda pid,deadline:(QEMU,[])
        fixture.device_state=lambda deadline:(_ for _ in ()).throw(timeout_failure)
        fixture.subprocess.Popen=Alive
        evidence=Path(temporary)/'attempt'; assert fixture.launch(evidence,2)==1
        terminal=json.loads((evidence/'launch-terminal.json').read_text())
        assert base64.b64decode(terminal['stdout']['data'])==b'out-part'
        assert base64.b64decode(terminal['stderr']['data'])==b'err-part'
    finally: fixture.preflight,fixture.process_identity,fixture.device_state,fixture.subprocess.Popen=originals

    # The numbered verify terminal path also serializes the same lossless failure.
    verify_evidence=Path(temporary)/'verify'; verify_evidence.mkdir()
    (verify_evidence/'ownership.json').write_text(json.dumps({'identity':QEMU,'stableIdentity':fixture.stable_identity(QEMU),'port':5556,'serial':'emulator-5556'}))
    original_identity=fixture.process_identity
    try:
        fixture.process_identity=lambda pid,deadline:(_ for _ in ()).throw(timeout_failure)
        assert fixture.verify(verify_evidence,2)==1
        verification=json.loads((verify_evidence/'verification-001-terminal.json').read_text())
        assert base64.b64decode(verification['failure']['stdout']['data'])==b'out-part'
        assert base64.b64decode(verification['failure']['stderr']['data'])==b'err-part'
    finally: fixture.process_identity=original_identity

print('PASS adb-nonzero-polls wrapper-qemu-handoff timeout-stream-terminal')
