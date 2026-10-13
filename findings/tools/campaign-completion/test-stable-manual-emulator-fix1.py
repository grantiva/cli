#!/usr/bin/env python3
"""Inert fake-process checks; never invokes emulator or adb."""
import importlib.util, json, subprocess, tempfile, time
from pathlib import Path

HERE=Path(__file__).parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'stable-manual-emulator.py'); fixture=importlib.util.module_from_spec(spec); spec.loader.exec_module(fixture)

def identity(ppid):
    return {'pid':42,'ppid':ppid,'pgid':42,'sessionId':42,'start':'Tue Oct 13 00:00:00 2026','executable':'qemu-system-aarch64','command':'qemu-system-aarch64 -avd cov4-android-2 -port 5556'}

assert fixture.stable_identity(identity(100))==fixture.stable_identity(identity(1))
assert fixture.expected_process(identity(1))

with tempfile.TemporaryDirectory() as temporary:
    sleeper=Path(temporary)/'sleep.sh'; sleeper.write_text('#!/bin/sh\nsleep 2\n'); sleeper.chmod(0o700)
    try: fixture.probe(time.monotonic()+0.05,[str(sleeper)])
    except fixture.ProbeFailure as error: assert error.record['timedOut'] is True
    else: raise AssertionError('hung probe did not time out')

originals=(fixture.preflight,fixture.process_identity,fixture.subprocess.Popen)
class ImmediateExit:
    pid=42; returncode=23
    def __init__(self,*args,**kwargs): pass
    def poll(self): return self.returncode
try:
    fixture.preflight=lambda deadline:{'passed':True}
    fixture.process_identity=lambda pid,deadline:(identity(100),[])
    fixture.subprocess.Popen=ImmediateExit
    with tempfile.TemporaryDirectory() as temporary:
        evidence=Path(temporary)/'attempt'; assert fixture.launch(evidence,2)==1
        assert json.loads((evidence/'launch-pid.json').read_text())['pid']==42
        assert json.loads((evidence/'launch-terminal.json').read_text())['exit']==23
finally: fixture.preflight,fixture.process_identity,fixture.subprocess.Popen=originals

originals=(fixture.process_identity,fixture.device_state)
try:
    fixture.process_identity=lambda pid,deadline:(identity(1),[])
    fixture.device_state=lambda deadline:({'state':'device','avd':'cov4-android-2','bootCompleted':'1'},[])
    with tempfile.TemporaryDirectory() as temporary:
        evidence=Path(temporary); launched=identity(100)
        (evidence/'ownership.json').write_text(json.dumps({'identity':launched,'stableIdentity':fixture.stable_identity(launched),'port':5556,'serial':'emulator-5556'}))
        assert fixture.verify(evidence,2)==0
        first=(evidence/'verification-001-terminal.json').read_bytes()
        assert fixture.verify(evidence,2)==0
        assert first==(evidence/'verification-001-terminal.json').read_bytes()
        assert (evidence/'verification-002-terminal.json').read_bytes()
finally: fixture.process_identity,fixture.device_state=originals

print('PASS reparenting hung-probe immediate-exit immutable-duplicate-verification')
