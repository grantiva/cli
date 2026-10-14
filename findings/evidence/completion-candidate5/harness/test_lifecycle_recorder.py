"""Deterministic recorder-only tests; no CLI, subprocess or device operations."""
import errno
import json
import os
from pathlib import Path
import shutil
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import lifecycle_smoke as recorder


class RecorderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'authenticated-report'
        self.source.mkdir()
        (self.source / 'flows').mkdir()
        self.target = self.root / 'retained'
        self.flow = self.root / 'session-flow.yaml'
        self.flow.write_text('appId: fixture\n---\n- launchApp\n')
        self.report = {'status': 'passed', 'endTime': 'done', 'summary': {
            'total': 1, 'passed': 1, 'failed': 0, 'skipped': 0, 'running': 0, 'pending': 0},
            'flows': [{'id': 'flow-000', 'dataFile': 'flows/flow-000.json',
                       'status': 'passed', 'endTime': 'done', 'commands': {
                           'total': 1, 'passed': 1, 'failed': 0, 'skipped': 0, 'running': 0, 'pending': 0}}]}
        self.detail = {'id': 'flow-000', 'endTime': 'done', 'commands': [
            {'status': 'passed', 'endTime': 'done'}]}
        recorder.write_json(self.source / 'report.json', self.report)
        recorder.write_json(self.source / 'flows/flow-000.json', self.detail)

    def snapshot_bytes(self):
        return {str(p.relative_to(self.target)): p.read_bytes() for p in self.target.rglob('*') if p.is_file()}

    def test_partial_source_races_preserve_complete_snapshot(self):
        self.assertTrue(recorder.copy_report_snapshot(self.source, self.target))
        before = self.snapshot_bytes()
        for subtree in ('', 'flows/flow-000.json'):
            for wrapped in (False, True):
                missing = self.source / subtree
                def copy(_source, destination, **_kwargs):
                    destination.mkdir()
                    (destination / 'report.json').write_text('{"status":"running"}')
                    failure = FileNotFoundError(errno.ENOENT, 'No such file or directory', str(missing))
                    if wrapped:
                        raise shutil.Error([(missing, destination, str(failure))])
                    raise failure
                with self.subTest(subtree=subtree, wrapped=wrapped), patch.object(recorder.shutil, 'copytree', side_effect=copy):
                    self.assertFalse(recorder.copy_report_snapshot(self.source, self.target))
                self.assertEqual(before, self.snapshot_bytes())
                recorder.validate_retained_report(self.target / 'report.json')
        # Even a successful but incomplete later copy cannot damage complete bytes.
        (self.source / 'report.json').write_text('{"status":"running"}')
        self.assertTrue(recorder.copy_report_snapshot(self.source, self.target))
        self.assertEqual(before, self.snapshot_bytes())

    def test_unrelated_copy_errors_propagate(self):
        recorder.copy_report_snapshot(self.source, self.target)
        before = self.snapshot_bytes()
        errors = [PermissionError(errno.EACCES, 'Permission denied', str(self.source)),
                  FileNotFoundError(errno.ENOENT, 'No such file or directory', str(self.target / 'missing')),
                  OSError(errno.EIO, 'Input/output error', str(self.source))]
        for error in errors:
            for wrapped in (False, True):
                thrown = shutil.Error([(self.source, self.target, str(error))]) if wrapped else error
                with self.subTest(error=str(error), wrapped=wrapped), patch.object(recorder.shutil, 'copytree', side_effect=thrown):
                    with self.assertRaises(type(thrown)):
                        recorder.copy_report_snapshot(self.source, self.target)
                self.assertEqual(before, self.snapshot_bytes())
        mixed = shutil.Error([(self.source, self.target, str(FileNotFoundError(errno.ENOENT, 'missing', str(self.source)))),
                              (self.source, self.target, str(errors[0]))])
        with patch.object(recorder.shutil, 'copytree', side_effect=mixed), self.assertRaises(shutil.Error):
            recorder.copy_report_snapshot(self.source, self.target)

    def test_direntry_source_race_is_transient_but_destination_is_not(self):
        with os.scandir(self.source) as entries:
            source_entry = next(entry for entry in entries if entry.name == 'flows')
            missing = FileNotFoundError(errno.ENOENT, 'No such file or directory', source_entry.path)
            wrapped = shutil.Error([(source_entry, self.target / 'flows', str(missing))])
            with patch.object(recorder.shutil, 'copytree', side_effect=wrapped):
                self.assertFalse(recorder.copy_report_snapshot(self.source, self.target))
        self.assertFalse(self.target.exists())

        destination = self.target / 'flows'
        missing = FileNotFoundError(errno.ENOENT, 'No such file or directory', str(destination))
        wrapped = shutil.Error([(destination, destination, str(missing))])
        with patch.object(recorder.shutil, 'copytree', side_effect=wrapped), self.assertRaises(shutil.Error):
            recorder.copy_report_snapshot(self.source, self.target)
        self.assertFalse(self.target.exists())

    def test_destination_promotion_failure_propagates(self):
        with patch.object(Path, 'rename', side_effect=PermissionError('destination denied')), self.assertRaises(PermissionError):
            recorder.copy_report_snapshot(self.source, self.target)

    def run_worker(self, complete):
        smoke = recorder.Smoke.__new__(recorder.Smoke)
        smoke.output = self.root
        smoke.session = self.root / 'session.json'
        recorder.write_json(smoke.session, {'pid': 123})
        smoke.ns = SimpleNamespace(ios_udid='fake-device')
        smoke.active_runners = {}
        smoke.owned_pids = {}
        smoke.record_ownership = lambda: None
        smoke.bound_argv_if_running = lambda *_: ['fake-runner', '--output', str(self.source), str(self.flow)]
        (self.root / 'phase').mkdir()
        self.target = self.root / 'phase' / 'fake-runner-report'
        if not complete:
            (self.source / 'flows/flow-000.json').write_text('{"commands":[]}')
        calls = 0
        # Set the real worker stop event on its second iteration via ownership;
        # its terminal third copy exercises the same source-root race.
        def ownership():
            if calls >= 2:
                state['stop'].set()
        smoke.record_ownership = ownership
        def copy(source, destination, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 1:
                return real_copy(source, destination, **kwargs)
            destination.mkdir()
            (destination / 'report.json').write_text('partial')
            error = FileNotFoundError(errno.ENOENT, 'No such file or directory', str(source))
            raise shutil.Error([(source, destination, str(error))])
        state = {'stop': threading.Event(), 'authenticated': threading.Event(),
                 'authenticatedPID': None, 'reportRequired': True, 'reportWasPresent': False,
                 'reportSnapshotCaptured': False, 'terminalReportCopied': False,
                 'terminalReportAbsent': False, 'sourceDisappearanceObserved': False,
                 'retainedReport': self.target / 'report.json', 'error': None}
        thread = threading.Thread(target=smoke.preserve_runner_report, args=('phase', 'fake', None, 'fake-device', state))
        with patch.object(recorder.shutil, 'copytree', side_effect=copy):
            # Install fixture bytes explicitly; later copies fail deterministically.
            def initial_copy(source, destination, **kwargs):
                destination.mkdir()
                (destination / 'flows').mkdir()
                for relative in ('report.json', 'flows/flow-000.json'):
                    (destination / relative).write_bytes((source / relative).read_bytes())
            real_copy = initial_copy
            thread.start()
            thread.join(2)
            self.assertFalse(thread.is_alive())
        return state, thread

    def test_worker_joins_records_terminal_and_validates_retained_bytes(self):
        snapshot = self.run_worker(True)
        recorder.Smoke.stop_report_snapshot(snapshot)
        recorder.Smoke.stop_report_snapshot(snapshot)
        self.assertTrue(snapshot[0]['retainedReportValidated'])
        terminal = json.loads((self.root / 'phase/fake-snapshot-terminal.json').read_text())
        self.assertTrue(terminal['terminalReportAbsent'])
        self.assertTrue(terminal['sourceDisappearanceObserved'])
        self.assertTrue(terminal['generatedFlowRetained'])

    def test_worker_incomplete_retained_flow_fails(self):
        snapshot = self.run_worker(False)
        with self.assertRaises(AssertionError):
            recorder.Smoke.stop_report_snapshot(snapshot)
        self.assertNotIn('retainedReportValidated', snapshot[0])

    def test_source_race_without_retained_report_fails_required_stop(self):
        error = FileNotFoundError(errno.ENOENT, 'No such file or directory', str(self.source))
        with patch.object(recorder.shutil, 'copytree', side_effect=error):
            self.assertFalse(recorder.copy_report_snapshot(self.source, self.target))
        thread = threading.Thread(target=lambda: None)
        thread.start()
        thread.join()
        state = {'stop': threading.Event(), 'terminalReportAbsent': True,
                 'reportRequired': True, 'retainedReport': self.target / 'report.json'}
        with self.assertRaises(FileNotFoundError):
            recorder.Smoke.stop_report_snapshot((state, thread))
        self.assertNotIn('retainedReportValidated', state)

    def test_missing_malformed_and_incomplete_reports_fail(self):
        recorder.copy_report_snapshot(self.source, self.target)
        for content in ('{', '{"status":"running"}', json.dumps(dict(self.report, summary={}))):
            (self.target / 'report.json').write_text(content)
            with self.assertRaises((AssertionError, json.JSONDecodeError)):
                recorder.validate_retained_report(self.target / 'report.json')
        recorder.write_json(self.target / 'report.json', self.report)
        (self.target / 'flows/flow-000.json').unlink()
        with self.assertRaises(FileNotFoundError):
            recorder.validate_retained_report(self.target / 'report.json')


if __name__ == '__main__':
    unittest.main(verbosity=2)
