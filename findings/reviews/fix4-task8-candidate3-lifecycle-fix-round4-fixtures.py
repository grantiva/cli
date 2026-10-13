"""Bounded filesystem/thread fixtures; never invoke helper main or live commands."""
import ast
import importlib.util
import json
import shutil
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

BASE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(BASE / 'task8-candidate3-harness'))
spec = importlib.util.spec_from_file_location('lifecycle_fixture', BASE / 'task8-candidate3-harness/lifecycle_smoke.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
PASSED = {'status': 'passed', 'endTime': 'finished', 'flows': [{'status': 'passed', 'endTime': 'finished'}]}

class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='capture-round4-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.smoke = object.__new__(m.Smoke)
        self.smoke.output = self.root / 'evidence'
        (self.smoke.output / 'phase').mkdir(parents=True)
        self.smoke.session = self.root / 'session.json'
        self.smoke.session.write_text(json.dumps({'pid': 12345}))
        self.smoke.ns = SimpleNamespace(ios_udid='fixture-ios')
        self.smoke.active_runners = {}
        self.smoke.owned_pids = {}
        self.source = self.root / 'report'
        self.source.mkdir()
        self.flow = self.root / 'flow.yaml'
        self.flow.write_text('fixture flow bytes\n')
        self.smoke.bound_argv_if_running = lambda pid, device: ['fixture-runner', '--udid', device, '--output', str(self.source), str(self.flow)]
        self.smoke.record_ownership = lambda: None
        self.snapshot = None
        self.addCleanup(self.join_worker)

    def join_worker(self):
        if self.snapshot:
            state, thread = self.snapshot
            state['stop'].set()
            thread.join(2)
            self.assertFalse(thread.is_alive())

    def start(self, required=True):
        self.snapshot = self.smoke.start_report_snapshot('phase', 'case', None, 'fixture-ios', report_required=required)
        self.assertEqual(self.smoke.wait_report_snapshot_authenticated(self.snapshot, 12345), 12345)
        return self.snapshot

    def test_passed_capture_then_removed_source_and_repeated_stop(self):
        (self.source / 'report.json').write_text(json.dumps(PASSED))
        snapshot = self.start()
        self.smoke.stop_report_snapshot(snapshot)
        self.assertTrue(snapshot[0]['retainedReportValidated'])
        self.assertFalse(snapshot[1].is_alive())
        shutil.rmtree(self.source)
        self.flow.unlink()
        self.smoke.session.unlink()
        with patch.object(m, 'copy_report_snapshot', side_effect=AssertionError('must not recopy')):
            self.smoke.stop_report_snapshot(snapshot)
        self.assertEqual(json.loads(snapshot[0]['retainedReport'].read_text()), PASSED)

    def test_missing_required_report(self):
        with self.assertRaises(FileNotFoundError):
            self.smoke.stop_report_snapshot(self.start())

    def test_incomplete_and_failed_reports(self):
        for report in ({'status': 'running'}, {'status': 'passed', 'flows': PASSED['flows']},
                       {'status': 'passed', 'endTime': 'finished', 'flows': []},
                       {'status': 'passed', 'endTime': 'finished', 'flows': [{'status': 'running'}]},
                       {'status': 'failed', 'endTime': 'finished', 'flows': PASSED['flows']}):
            with self.subTest(report=report):
                (self.source / 'report.json').write_text(json.dumps(report))
                with self.assertRaises(AssertionError):
                    self.smoke.stop_report_snapshot(self.start())

    def test_optional_startup_retains_raw_bytes_and_terminal_absence(self):
        raw = b'partial startup log\x00\xff\n'
        (self.source / 'maestro-runner.log').write_bytes(raw)
        gate = threading.Event()
        release = threading.Event()
        original_bind = self.smoke.bound_argv_if_running
        calls = 0
        def bind(pid, device):
            nonlocal calls
            calls += 1
            if calls == 1:
                return original_bind(pid, device)
            gate.set()
            if not release.wait(2):
                raise TimeoutError('fixture release timed out')
            return None
        self.smoke.bound_argv_if_running = bind
        snapshot = self.start(required=False)
        try:
            self.assertTrue(gate.wait(2))
            shutil.rmtree(self.source)
            self.smoke.session.unlink()
            snapshot[0]['stop'].set()
        finally:
            release.set()
        self.smoke.stop_report_snapshot(snapshot)
        state = snapshot[0]
        self.assertEqual((self.smoke.output / 'phase/case-runner-report/maestro-runner.log').read_bytes(), raw)
        terminal = json.loads((self.smoke.output / 'phase/case-snapshot-terminal.json').read_text())
        self.assertTrue(terminal['terminalReportAbsent'])
        self.assertTrue(terminal['snapshotCaptured'])
        self.assertFalse(terminal['reportRequired'])
        self.assertNotIn('retainedReportValidated', state)

    def test_stable_copy_error_propagates(self):
        with patch.object(m, 'copy_report_snapshot', side_effect=PermissionError('stable file denied')):
            self.snapshot = self.smoke.start_report_snapshot('phase', 'case', None, 'fixture-ios')
            with self.assertRaisesRegex(PermissionError, 'stable file denied'):
                self.smoke.wait_report_snapshot_authenticated(self.snapshot)
            with self.assertRaisesRegex(PermissionError, 'stable file denied'):
                self.smoke.stop_report_snapshot(self.snapshot)

    def test_ownership_error_propagates(self):
        def fail():
            raise KeyError('ownership failure')
        self.smoke.record_ownership = fail
        self.snapshot = self.smoke.start_report_snapshot('phase', 'case', None, 'fixture-ios')
        with self.assertRaisesRegex(KeyError, 'ownership failure'):
            self.smoke.wait_report_snapshot_authenticated(self.snapshot)
        with self.assertRaisesRegex(KeyError, 'ownership failure'):
            self.smoke.stop_report_snapshot(self.snapshot)

    def test_terminal_copy_error_propagates(self):
        (self.source / 'report.json').write_text(json.dumps(PASSED))
        snapshot = self.start()
        with patch.object(m, 'copy_report_snapshot', side_effect=OSError('terminal stable file failure')):
            with self.assertRaisesRegex(OSError, 'terminal stable file failure'):
                self.smoke.stop_report_snapshot(snapshot)

    def test_ast_cleanup_order_and_unchanged_startup_timing(self):
        tree = ast.parse(Path(spec.origin).read_text())
        methods = {n.name: n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}
        ready_loop = methods['detach_ready'].body[-1]
        calls = sorted((n.lineno, ast.unparse(n.func)) for n in ast.walk(ready_loop) if isinstance(n, ast.Call))
        stop = next(line for line, name in calls if name == 'self.stop_report_snapshot')
        kill = next(line for line, name in calls if name == 'os.kill')
        self.assertLess(stop, kill)
        force = ast.unparse(methods['force_teardown'])
        self.assertLess(force.index('self.stop_report_snapshot(snapshot)'), force.index("'live-force'"))
        startup = ast.unparse(methods['startup_interrupt'])
        self.assertIn("self.wait_state(proc, 'starting')", startup)
        self.assertNotIn("self.wait_state(proc, 'ready')", startup)
        self.assertIn('report_required=False', startup)

if __name__ == '__main__':
    unittest.main(verbosity=2)
