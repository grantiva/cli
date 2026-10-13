#!/usr/bin/env python3
"""Device-free fixtures: no helper constructor or real subprocess operation."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent / 'task8-candidate3-harness'))
import foreground_force as ff


class Fixtures(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.smoke = ff.ForegroundForce.__new__(ff.ForegroundForce)
        s = self.smoke
        s.output = self.root / 'output'
        (s.output / ff.PHASE).mkdir(parents=True)
        s.project = self.root
        s.binary = self.root / 'grantiva'
        s.home = self.root / 'home'
        s.session = self.root / 'session.json'
        s.ns = SimpleNamespace(ios_udid='owned-device', ios_bundle_id='test.app')
        s.checks = []
        s.active_runners = {}
        self.proc = SimpleNamespace(pid=101, returncode=None, poll=lambda: None)
        self.ready = dict(state='ready', platform='ios', udid='owned-device', bundleId='test.app', pid=102, port=8274)
        s.session.write_text(json.dumps(self.ready))
        self.flow = self.root / 'flow.yaml'
        self.flow.write_text('appId: test.app\n---\n- launchApp\n')
        self.report = self.root / 'report'
        (self.report / 'flows').mkdir(parents=True)
        self.entry = dict(status='passed', endTime='done', device={'id': 'owned-device'}, sourceFile=str(self.flow), dataFile='flows/one.json')
        self.doc = dict(status='passed', endTime='done', device={'id': 'owned-device'}, flows=[self.entry])
        self.detail = dict(self.entry, commands=[dict(status='passed', endTime='done')])
        self.write_reports()
        self.lease = self.root / 'lease.lock'
        self.force_doc = dict(udid='owned-device', reclaimed=True, runnerSessionStopped=True, processes=[], reapedProcesses=[])

    def write_reports(self):
        (self.report / 'report.json').write_text(json.dumps(self.doc))
        (self.report / 'flows/one.json').write_text(json.dumps(self.detail))

    def run_force(self, *, copy_error=False, hierarchy=b'Landmarks', exit_code=0, alive=True, notice=True):
        events = []
        def command(phase, label, argv, **kwargs):
            events.append(label)
            if label == 'live-force':
                self.assertNotIn('--detach', self.start_argv)
                self.assertTrue((self.smoke.output / phase / 'pre-force.json').exists())
                self.assertEqual(argv, [str(self.smoke.binary), 'simulator', 'teardown', '--udid', 'owned-device', '--force', '--json'])
                self.assertTrue((self.smoke.output / phase / 'retained-report/flows/one.json').exists())
                return SimpleNamespace(stdout=json.dumps(self.force_doc).encode())
            return SimpleNamespace(stdout=hierarchy)
        def spawn(phase, label, argv):
            self.start_argv = argv
            path = self.smoke.output / phase
            (path / f'{label}.stdout').write_text('')
            (path / f'{label}.stderr').write_text('Runner stopped by teardown (pid 102); the session has ended.' if notice else 'Runner exited unexpectedly')
            return self.proc
        if not alive:
            self.proc.poll = lambda: 1
            self.proc.returncode = 1
        patches = dict(spawn=spawn, authenticate=lambda *a: (102, self.report, self.flow, self.lease), wait_state=lambda *a, **k: self.ready,
                       command=command, finish=lambda *a: exit_code, assert_pid_bound=lambda *a: [], assert_pid_gone=lambda p: events.append(f'gone-{p}'), assert_session_cleanup=lambda p: events.append('session-clean'))
        with patch.multiple(self.smoke, **patches):
            # A pre-existing session must still be rejected; mock only that preflight
            # to model the session created by our fake spawn.
            with patch.object(self.smoke, 'stop_stale'):
                if copy_error:
                    with patch.object(ff.shutil, 'copytree', side_effect=OSError('stable copy failed')):
                        self.smoke.force_teardown()
                else:
                    self.smoke.force_teardown()
        return events

    def test_foreground_order_and_exact_force(self):
        events = self.run_force()
        self.assertLess(events.index('live-hierarchy'), events.index('live-force'))
        self.assertIn('gone-101', events)
        self.assertIn('gone-102', events)
        result = json.loads((self.smoke.output / 'IOS-FORCE-RECLAIMED.json').read_text())
        self.assertFalse(result['physicalDeviceDeleted'])
        self.assertEqual(result['foregroundExit'], 0)

    def test_incomplete_failed_missing_and_wrong_identity_reports(self):
        for change in ('failed', 'incomplete', 'device', 'flow', 'detail', 'missing'):
            with self.subTest(change=change):
                original = copy.deepcopy((self.doc, self.detail))
                if change == 'failed': self.doc['status'] = 'failed'
                if change == 'incomplete': self.doc.pop('endTime')
                if change == 'device': self.doc['device']['id'] = 'foreign'
                if change == 'flow': self.doc['flows'][0]['sourceFile'] = '/foreign'
                if change == 'detail': self.detail['commands'][0]['status'] = 'running'
                self.write_reports()
                if change == 'missing': (self.report / 'flows/one.json').unlink()
                with self.assertRaises((AssertionError, FileNotFoundError)):
                    ff.validate_report(self.report, 'owned-device', self.flow)
                self.doc, self.detail = original
        self.write_reports()

    def test_copy_error_is_not_suppressed(self):
        with self.assertRaisesRegex(OSError, 'stable copy failed'): self.run_force(copy_error=True)
        self.assertFalse((self.smoke.output / ff.PHASE / 'pre-force.json').exists())

    def test_cli_must_remain_alive_before_force(self):
        with self.assertRaisesRegex(AssertionError, 'exited before force'): self.run_force(alive=False)

    def test_hierarchy_must_contain_landmarks(self):
        with self.assertRaisesRegex(AssertionError, 'lacks Landmarks'): self.run_force(hierarchy=b'Other')

    def test_force_response_must_bind_device_and_fields(self):
        self.force_doc['udid'] = 'foreign'
        with self.assertRaisesRegex(AssertionError, 'invalidForceResult'): self.run_force()

    def test_foreground_nonzero_is_failure(self):
        with self.assertRaisesRegex(AssertionError, 'foregroundExit'): self.run_force(exit_code=130)

    def test_foreground_notice_is_required(self):
        with self.assertRaisesRegex(AssertionError, 'foregroundExit'): self.run_force(notice=False)

    def test_force_arrays_and_stopped_flag_required(self):
        self.force_doc['runnerSessionStopped'] = False
        with self.assertRaisesRegex(AssertionError, 'invalidForceResult'): self.run_force()

    def test_lease_remaining_is_failure(self):
        self.lease.write_text('still-owned')
        with self.assertRaisesRegex(AssertionError, 'lease remains'): self.run_force()

    def test_authentication_rejects_foreign_session(self):
        self.ready['udid'] = 'foreign'
        with self.assertRaisesRegex(AssertionError, 'invalidReadySession'):
            self.smoke.authenticate(self.proc, self.ready)

    def test_authentication_parent_executable_and_lease(self):
        s = self.smoke
        s.installed_runner = (self.root / 'runner').resolve()
        s.installed_runner.write_bytes(b'frozen')
        s.installed_runner_sha256 = ff.base.file_sha256(s.installed_runner)
        argv = [str(s.installed_runner), '--device', 'owned-device', '--output', str(self.report), str(self.flow)]
        lease = s.home / 'locks/owned-device.lock'
        lease.parent.mkdir(parents=True)
        claim = dict(pid=101, runnerPID=102, udid='owned-device', keepAlive=True)
        lease.write_text(json.dumps(claim))
        with patch.object(s, 'assert_pid_bound', return_value=argv), patch.object(s, 'register_runner'), patch.object(s, 'command', return_value=SimpleNamespace(stdout=b'101')):
            self.assertEqual(s.authenticate(self.proc, self.ready)[0], 102)
            claim['runnerPID'] = 999
            lease.write_text(json.dumps(claim))
            with self.assertRaisesRegex(AssertionError, 'invalidForegroundLease'): s.authenticate(self.proc, self.ready)
        with patch.object(s, 'assert_pid_bound', return_value=argv), patch.object(s, 'command', return_value=SimpleNamespace(stdout=b'999')):
            with self.assertRaisesRegex(AssertionError, 'parent'): s.authenticate(self.proc, self.ready)

    def test_command_timeout_retains_streams(self):
        exc = subprocess.TimeoutExpired(['fake'], 1, output=b'partial out', stderr=b'partial err')
        with patch.object(ff.subprocess, 'run', side_effect=exc):
            with self.assertRaises(subprocess.TimeoutExpired): self.smoke.command(ff.PHASE, 'fake', ['fake'], timeout=1)
        target = self.smoke.output / ff.PHASE
        self.assertEqual((target / 'fake.stdout').read_bytes(), b'partial out')
        self.assertEqual((target / 'fake.stderr').read_bytes(), b'partial err')
        self.assertTrue(json.loads((target / 'fake.result.json').read_text())['timedOut'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
