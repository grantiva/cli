"""Round-5 source-disappearance fixtures plus all round-4 coverage, no live actions."""
import importlib.util
import json
import shutil
import threading
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('round4_fixtures', BASE / 'task8-candidate3-lifecycle-fix-round4-fixtures.py')
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

class CaptureTests(previous.CaptureTests):
    def source_removed_before_first_join(self, report):
        if report is not None:
            report = json.loads(json.dumps(report))
            report['device'] = {'id': 'fixture-ios'}
            for flow in report.get('flows', []):
                flow['sourceFile'] = str(self.flow)
                flow['device'] = {'id': 'fixture-ios'}
            (self.source / 'report.json').write_text(json.dumps(report))
        gate = threading.Event()
        release = threading.Event()
        original_bind = self.smoke.bound_argv_if_running
        calls = 0
        def bind(pid, device):
            nonlocal calls
            calls += 1
            if calls > 1:
                gate.set()
                if not release.wait(2):
                    raise TimeoutError('fixture release timed out')
            return original_bind(pid, device)
        self.smoke.bound_argv_if_running = bind
        snapshot = self.start()
        try:
            self.assertTrue(gate.wait(2))
            # Normal detached command completion removes launch files, but the
            # authenticated runner and its project session remain available.
            shutil.rmtree(self.source)
            self.flow.unlink()
            self.assertTrue(self.smoke.session.is_file())
            snapshot[0]['stop'].set()
        finally:
            release.set()
        self.smoke.stop_report_snapshot(snapshot)
        self.assertFalse(snapshot[1].is_alive())
        terminal = json.loads((self.smoke.output / 'phase/case-snapshot-terminal.json').read_text())
        self.assertTrue(terminal['reportRequired'])
        self.assertTrue(terminal['terminalReportAbsent'])
        self.assertFalse(terminal['terminalReportCopied'])
        self.assertTrue(snapshot[0]['retainedReportValidated'])
        self.assertEqual(snapshot[0]['authenticatedPID'], 12345)
        self.assertEqual(snapshot[0]['report'], self.source)
        self.assertEqual(snapshot[0]['flow'], self.flow)
        owned = self.smoke.owned_pids[12345]
        self.assertEqual(owned['device'], report['device']['id'])
        self.assertEqual(owned['argv'][-1], report['flows'][0]['sourceFile'])
        self.assertEqual(owned['argv'][owned['argv'].index('--output') + 1], str(self.source))
        self.assertEqual(json.loads(snapshot[0]['retainedReport'].read_text()), report)
        self.smoke.stop_report_snapshot(snapshot)

    def test_required_passed_source_removed_before_first_join(self):
        self.source_removed_before_first_join(previous.PASSED)

    def test_required_missing_source_removed_before_first_join(self):
        with self.assertRaisesRegex(FileNotFoundError, r"case-runner-report/report\.json"):
            self.source_removed_before_first_join(None)

    def test_required_incomplete_source_removed_before_first_join(self):
        with self.assertRaisesRegex(AssertionError, "incompleteOrFailedReport"):
            self.source_removed_before_first_join({'status': 'running', 'flows': []})

    def test_required_failed_source_removed_before_first_join(self):
        with self.assertRaisesRegex(AssertionError, "incompleteOrFailedReport"):
            self.source_removed_before_first_join({'status': 'failed', 'endTime': 'finished', 'flows': previous.PASSED['flows']})

    def test_actual_attempt2_report_with_source_removed_before_first_join(self):
        evidence = BASE.parents[2] / 'findings/evidence/round4-smoke-candidate3/03-lifecycle-attempt2/helper/detach-ready/ios-runner-report/report.json'
        self.source_removed_before_first_join(json.loads(evidence.read_text()))

if __name__ == '__main__':
    unittest.main(verbosity=2)
