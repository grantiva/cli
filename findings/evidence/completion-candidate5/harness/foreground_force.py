#!/usr/bin/env python3
"""Isolated completion-candidate5 foreground final-force proof; controller owns invocation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

import lifecycle_smoke as base

APPROVED_BASE_SHA = 'c9a98c1d354893fe9a6dfdced4cdd53e17c7e192e9bfc1cde656de7b61a19737'
PHASE = 'force-teardown'


def require_live(proc):
    if proc.poll() is not None:
        raise AssertionError(f'foreground CLI {proc.pid} exited before force: {proc.returncode}')


def validate_report(root, device, flow):
    report = json.loads((root / 'report.json').read_text())
    flows = report.get('flows', [])
    if (report.get('status') != 'passed' or not report.get('endTime') or not flows
            or report.get('device', {}).get('id') != device):
        raise AssertionError({'incompleteOrUnboundReport': report})
    for entry in flows:
        if (entry.get('status') != 'passed' or not entry.get('endTime')
                or entry.get('device', {}).get('id') != device
                or Path(entry.get('sourceFile', '')).resolve() != flow.resolve()):
            raise AssertionError({'incompleteOrUnboundFlow': entry})
        data = (root / entry['dataFile']).resolve()
        if not data.is_relative_to(root.resolve()):
            raise AssertionError('report dataFile escapes retained report')
        detail = json.loads(data.read_text())
        commands = detail.get('commands', [])
        if (detail.get('device', {}).get('id') != device or not detail.get('endTime')
                or Path(detail.get('sourceFile', '')).resolve() != flow.resolve()
                or not commands or any(c.get('status') != 'passed' or not c.get('endTime') for c in commands)):
            raise AssertionError({'incompleteOrUnboundFlowData': detail})
    return report


class ForegroundForce(base.Smoke):
    def command(self, phase, label, argv, expected=0, timeout=180, cwd=None):
        """Keep timeout streams as well as normal command metadata."""
        target = self.output / phase
        target.mkdir(exist_ok=True)
        started = time.time()
        base.write_json(target / f'{label}.command.json', {'argv': argv, 'cwd': str(cwd or self.project), 'started': started, 'timeoutSeconds': timeout})
        try:
            result = subprocess.run(argv, cwd=cwd or self.project, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            (target / f'{label}.stdout').write_bytes(exc.stdout or b'')
            (target / f'{label}.stderr').write_bytes(exc.stderr or b'')
            base.write_json(target / f'{label}.result.json', {'exit': None, 'timedOut': True, 'started': started, 'ended': time.time(), 'timeoutSeconds': timeout})
            raise
        (target / f'{label}.stdout').write_bytes(result.stdout)
        (target / f'{label}.stderr').write_bytes(result.stderr)
        base.write_json(target / f'{label}.result.json', {'exit': result.returncode, 'timedOut': False, 'started': started, 'ended': time.time()})
        if expected is not None and result.returncode != expected:
            raise AssertionError(f'{phase}/{label}: exit {result.returncode}, expected {expected}')
        return result

    def finish(self, phase, label, proc, timeout):
        try:
            return super().finish(phase, label, proc, timeout)
        except subprocess.TimeoutExpired:
            base.write_json(self.output / phase / f'{label}.result.json', {'exit': None, 'timedOut': True, 'pid': proc.pid, 'ended': time.time(), 'timeoutSeconds': timeout})
            raise

    def authenticate(self, proc, ready):
        device = self.ns.ios_udid
        if (ready.get('state') != 'ready' or ready.get('platform') != 'ios'
                or ready.get('udid') != device or ready.get('bundleId') != self.ns.ios_bundle_id
                or type(ready.get('pid')) is not int or ready['pid'] <= 0
                or type(ready.get('port')) is not int or ready['port'] <= 0):
            raise AssertionError({'invalidReadySession': ready})
        require_live(proc)
        pid = ready['pid']
        argv = self.assert_pid_bound(pid, device)
        parent = self.command(PHASE, 'runner-parent', ['/bin/ps', '-p', str(pid), '-o', 'ppid=']).stdout
        if (int(parent.strip()) != proc.pid or Path(argv[0]).resolve() != self.installed_runner
                or base.file_sha256(self.installed_runner) != self.installed_runner_sha256
                or argv[argv.index('--device') + 1] != device):
            raise AssertionError('runner executable, parent, or device identity mismatch')
        self.register_runner(pid, 'ios', device, PHASE)
        report = Path(argv[argv.index('--output') + 1]).resolve()
        flow = Path(argv[-1]).resolve()
        lease = self.home / 'locks' / f'{device}.lock'
        claim = json.loads(lease.read_text())
        if (claim.get('pid') != proc.pid or claim.get('runnerPID') != pid
                or claim.get('udid') != device or claim.get('keepAlive') is not True):
            raise AssertionError({'invalidForegroundLease': claim})
        base.write_json(self.output / PHASE / 'authenticated-ready.json', {'ready': ready, 'argv': argv, 'cliPID': proc.pid, 'leasePath': str(lease), 'lease': claim, 'report': str(report), 'flow': str(flow)})
        return pid, report, flow, lease

    def force_teardown(self):
        self.stop_stale('foreground-force')
        proc = self.spawn(PHASE, 'foreground-start', self.start_args('ios'))
        self.foreground_proc = proc
        ready = self.wait_state(proc, 'ready', timeout=600)
        pid, report, flow, lease = self.authenticate(proc, ready)
        target = self.output / PHASE
        require_live(proc)
        # Foreground lifetime holds these files until teardown. Any copy error fails.
        shutil.copytree(report, target / 'retained-report')
        shutil.copy2(flow, target / 'generated-flow.yaml')
        retained = validate_report(target / 'retained-report', self.ns.ios_udid, flow)
        require_live(proc)
        hierarchy = self.command(PHASE, 'live-hierarchy', [str(self.binary), 'runner', 'dump-hierarchy', '--udid', self.ns.ios_udid, '--format', 'tree'])
        if b'Landmarks' not in hierarchy.stdout:
            raise AssertionError('ready hierarchy lacks Landmarks')
        if json.loads(self.session.read_text()) != ready:
            raise AssertionError('ready session changed before force')
        self.assert_pid_bound(pid, self.ns.ios_udid)
        require_live(proc)
        base.write_json(target / 'pre-force.json', {'cliAlive': True, 'cliPID': proc.pid, 'runnerPID': pid, 'ready': ready, 'reportPassed': True, 'reportSHA256': base.file_sha256(target / 'retained-report/report.json'), 'reportEndTime': retained['endTime'], 'hierarchyLandmarks': True, 'validatedAt': time.time()})
        raw = self.command(PHASE, 'live-force', [str(self.binary), 'simulator', 'teardown', '--udid', self.ns.ios_udid, '--force', '--json'], timeout=240)
        doc = json.loads(raw.stdout)
        if isinstance(doc, list):
            if len(doc) != 1:
                raise AssertionError({'unexpectedForceTargets': doc})
            doc = doc[0]
        if (doc.get('udid') != self.ns.ios_udid or doc.get('runnerSessionStopped') is not True
                or doc.get('reclaimed') is not True or not isinstance(doc.get('processes'), list)
                or not isinstance(doc.get('reapedProcesses'), list)):
            raise AssertionError({'invalidForceResult': doc})
        code = self.finish(PHASE, 'foreground-start', proc, 45)
        notice = f'Runner stopped by teardown (pid {pid}); the session has ended.'
        streams = (target / 'foreground-start.stdout').read_text() + (target / 'foreground-start.stderr').read_text()
        if code != 0 or notice not in streams:
            raise AssertionError({'foregroundExit': code, 'expectedExit': 0, 'expectedNotice': notice})
        self.assert_pid_gone(pid)
        self.assert_pid_gone(proc.pid)
        self.assert_session_cleanup(pid)
        if lease.exists():
            raise AssertionError(f'owned simulator lease remains: {lease}')
        self.command(PHASE, 'processes-after', ['/bin/ps', '-ww', '-axo', 'pid=,ppid=,pgid=,command='])
        check = {'phase': PHASE, 'runnerPID': pid, 'foregroundPID': proc.pid, 'foregroundExit': code, 'foregroundNotice': notice, 'result': doc, 'exactPIDSessionLeaseCleanup': True, 'resourcesReclaimed': True, 'physicalDeviceDeleted': False, 'finalCleanupRequired': True}
        self.checks.append(check)
        base.write_json(self.output / 'IOS-FORCE-RECLAIMED.json', {'ownedUDID': self.ns.ios_udid, **check})

    def cleanup_owned(self):
        # Signal only the exact Popen child we launched. Its normal SIGINT path
        # owns runner/session/lease cleanup; never delete evidence or foreign state.
        actions = []
        proc = getattr(self, 'foreground_proc', None)
        if proc is not None and proc.poll() is None:
            try:
                proc.send_signal(signal.SIGINT)
                code = self.finish(PHASE, 'failure-cleanup-foreground', proc, 45)
                actions.append({'action': 'owned-foreground-SIGINT', 'pid': proc.pid, 'exit': code})
            except Exception as exc:
                actions.append({'action': 'owned-foreground-SIGINT', 'pid': proc.pid, 'error': str(exc)})
        for pid in self.active_runners:
            try:
                self.assert_pid_gone(pid)
                self.assert_session_cleanup(pid)
                actions.append({'runnerPID': pid, 'goneAndSessionClean': True})
            except Exception as exc:
                actions.append({'runnerPID': pid, 'cleanupUnconfirmed': str(exc)})
        base.write_json(self.output / 'cleanup.json', {'bounded': True, 'actions': actions})


def main():
    ns = base.parser().parse_args()
    errors = base.validate(ns)
    if ns.phase != [PHASE] or not ns.allow_force_reclaim_owned_ios:
        errors.append('foreground fixture requires --phase force-teardown --allow-force-reclaim-owned-ios')
    if base.file_sha256(Path(base.__file__)) != APPROVED_BASE_SHA:
        errors.append('approved lifecycle dependency hash changed')
    if errors:
        print(json.dumps({'valid': False, 'errors': errors}), file=sys.stderr)
        return 2
    if ns.validate_only:
        print(json.dumps({'valid': True, 'phase': PHASE, 'foreground': True}))
        return 0
    smoke = None
    try:
        smoke = ForegroundForce(ns)
        base.write_json(smoke.output / 'fixture-identity.json', {'fixtureSHA256': base.file_sha256(Path(__file__)), 'approvedLifecycleSHA256': APPROVED_BASE_SHA, 'timeoutsSeconds': {'ready': 600, 'force': 240, 'foregroundExit': 45}})
        smoke.record_ownership()
        smoke.force_teardown()
        smoke.record_ownership('force-resources-reclaimed')
        base.write_json(smoke.output / 'acceptance.json', {'status': 'passed', 'phases': [PHASE], 'checks': smoke.checks})
        return 0
    except Exception as exc:
        output = smoke.output if smoke else ns.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        base.write_json(output / 'failure.json', {'status': 'failed', 'errorType': type(exc).__name__, 'error': str(exc), 'checks': smoke.checks if smoke else []})
        if smoke:
            smoke.cleanup_owned()
            smoke.record_ownership('failed')
        raise


if __name__ == '__main__':
    raise SystemExit(main())
