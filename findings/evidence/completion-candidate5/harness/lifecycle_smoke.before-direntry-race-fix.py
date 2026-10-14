#!/usr/bin/env python3
"""Task 8 lifecycle smoke, rebound to one final candidate and owned devices."""

from __future__ import annotations

import argparse
import ast
import errno
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import tempfile
import time
from pathlib import Path

from candidate_identity import validate as validate_candidate_identity


PROTECTED_UDIDS = {
    "B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C",
    "FE441EE5-BBFC-4981-B68A-59C0DBCE26D6",
}
PROTECTED_AVDS = {"Pixel_8_API_35"}
INTERRUPT_NOTICES = {
    "ios": "[grantiva] received SIGINT — releasing simulator and reaping child processes",
    "android": "[grantiva] received SIGINT — releasing emulator and reaping child processes",
}
RUBY_YAML_DOCUMENTS = "content = File.read(ARGV[0]); docs = content.split(/^---[ \\t]*$\\n?/).map { |doc| YAML.safe_load(doc, [], [], false) }; puts JSON.generate(docs)"
PHASES = (
    "startup-interrupt",
    "detach-ready",
    "absent-app",
    "log-cleanup",
    "cycle-controls",
    "force-teardown",
)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def identity_token(value: object) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value).lower())


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def yaml_documents(path: Path) -> object:
    result = subprocess.run(
        ["/usr/bin/ruby", "-rjson", "-ryaml", "-e", RUBY_YAML_DOCUMENTS, str(path)],
        capture_output=True, text=True, check=True, timeout=10,
    )
    return json.loads(result.stdout)


def validate_retained_report(path: Path) -> None:
    report = json.loads(path.read_text())
    flows = report.get("flows", [])
    if (report.get("status") != "passed" or not report.get("endTime") or not flows
            or any(flow.get("status") != "passed" or not flow.get("endTime") for flow in flows)):
        raise AssertionError({"incompleteOrFailedReport": report})
    summary = report.get("summary", {})
    if any(summary.get(key) != value for key, value in
           {"total": len(flows), "passed": len(flows), "failed": 0, "skipped": 0, "running": 0, "pending": 0}.items()):
        raise AssertionError("incomplete retained report summary")
    for flow in flows:
        relative = Path(flow.get("dataFile", ""))
        if not relative.parts or relative.is_absolute() or ".." in relative.parts:
            raise AssertionError("invalid retained flow dataFile")
        detail = json.loads((path.parent / relative).read_text())
        commands = detail.get("commands", [])
        if (detail.get("id") != flow.get("id") or not detail.get("endTime") or not commands
                or any(command.get("status") != "passed" or not command.get("endTime") for command in commands)):
            raise AssertionError("incomplete retained flow commands")
        counts = flow.get("commands", {})
        if any(counts.get(key) != value for key, value in
               {"total": len(commands), "passed": len(commands), "failed": 0, "skipped": 0, "running": 0, "pending": 0}.items()):
            raise AssertionError("incomplete retained flow summary")


def copy_report_snapshot(source: Path, target: Path) -> bool:
    """Discard interrupted source copies; never overwrite a complete snapshot."""
    def ignore_transient(_directory: str, names: list[str]) -> set[str]:
        return {name for name in names if name.endswith(".tmp")}

    def source_path(path: object) -> bool:
        return isinstance(path, (str, Path)) and Path(path).is_relative_to(source)

    def source_error(entry: object) -> bool:
        if not isinstance(entry, (list, tuple)) or len(entry) != 3 or not source_path(entry[0]):
            return False
        match = re.fullmatch(r"\[Errno 2\] [^:]+: (.+)", str(entry[2]))
        if not match:
            return False
        try:
            # shutil flattens OSError into text: inspect its filename as well
            # as the tuple's source, so destination ENOENT is never accepted.
            return source_path(ast.literal_eval(match[1]))
        except (ValueError, SyntaxError):
            return False

    with tempfile.TemporaryDirectory(prefix=f".{target.name}-copy-", dir=target.parent) as staging:
        staged = Path(staging) / "report"
        try:
            shutil.copytree(source, staged, ignore=ignore_transient)
        except FileNotFoundError as exc:
            if exc.errno == errno.ENOENT and source_path(exc.filename):
                return False
            raise
        except shutil.Error as exc:
            errors = exc.args[0]
            if isinstance(errors, list) and errors and all(source_error(entry) for entry in errors):
                return False
            raise
        try:
            validate_retained_report(target / "report.json")
        except (FileNotFoundError, json.JSONDecodeError, AssertionError):
            if target.exists():
                shutil.rmtree(target)
            staged.rename(target)
        return True


class Smoke:
    def __init__(self, ns: argparse.Namespace) -> None:
        self.ns = ns
        self.binary = ns.binary.resolve()
        self.source = ns.source.resolve()
        self.project = ns.project.resolve()
        self.home = ns.runner_home.resolve()
        self.bundle = ns.bundle.resolve()
        self.runner = ns.runner.resolve()
        self.output = ns.output.resolve()
        self.session = self.project / ".grantiva" / "session.json"
        self.adb = Path(ns.adb).resolve()
        self.checks: list[dict[str, object]] = []
        self.owned_pids: dict[int, dict[str, object]] = {}
        self.active_runners: dict[int, tuple[str, str]] = {}
        self.ownership_lock = threading.Lock()
        self.targets_verified = False
        self.output.mkdir(parents=True, exist_ok=False)
        os.environ.pop("GRANTIVA_API_KEY", None)
        os.environ.update(
            GRANTIVA_RUNNER_HOME=str(self.home),
            MAESTRO_RUNNER_HOME=str(self.home),
            GRANTIVA_SESSION_ID=ns.session_id,
        )
        ios_identity = validate_candidate_identity(
            ns.candidate_manifest, ns.ownership_manifest,
            source_root=self.source, binary=self.binary, bundle=self.bundle,
            runner=self.runner, runner_home=self.home, platform="ios", device=ns.ios_udid,
        )
        android_identity = validate_candidate_identity(
            ns.candidate_manifest, ns.ownership_manifest,
            source_root=self.source, binary=self.binary, bundle=self.bundle,
            runner=self.runner, runner_home=self.home, platform="android",
            device=ns.android_serial, android_avd=ns.android_avd,
        )
        if ios_identity != android_identity:
            raise AssertionError("platform identity validations disagree")
        self.provenance = ios_identity
        self.candidate_doc = json.loads(ns.candidate_manifest.read_text())
        self.ownership_doc = json.loads(ns.ownership_manifest.read_text())
        installed = self.candidate_doc["runner"]["installed"]
        self.installed_runner = Path(installed["path"]).resolve()
        self.installed_runner_sha256 = installed["sha256"]
        if Path(self.candidate_doc["demo"]["iosApp"]["path"]).resolve() != ns.ios_app.resolve():
            raise AssertionError("supplied iOS app is not the frozen clean-built app")
        write_json(self.output / "verified-candidate-identity.json", self.provenance)
        self.verify_live_targets()

    def record_ownership(self, state: str = "active") -> None:
        document = {
            "state": state,
            "candidateBinary": str(self.binary),
            "source": str(self.source),
            "bundle": str(self.bundle),
            "runner": str(self.runner),
            "project": str(self.project),
            "runnerHome": str(self.home),
            "sessionId": self.ns.session_id,
            "iosUDID": self.ns.ios_udid,
            "androidSerial": self.ns.android_serial,
            "androidAVD": self.ns.android_avd,
            "ownedPIDs": dict(self.owned_pids),
            "verifiedProvenance": self.provenance,
            "controllerOwnership": self.ownership_doc,
            "protected": {
                "ios": sorted(PROTECTED_UDIDS),
                "androidAVD": sorted(PROTECTED_AVDS),
            },
        }
        with self.ownership_lock:
            write_json(self.output / "owned-resources.json", document)

    def verify_live_targets(self) -> None:
        phase = "identity"
        sims = json.loads(self.command(phase, "ios-live-identity", ["/usr/bin/xcrun", "simctl", "list", "devices", "--json"]).stdout)
        matches = [(runtime, d) for runtime, devices in sims.get("devices", {}).items() for d in devices if d.get("udid") == self.ns.ios_udid]
        if len(matches) != 1 or matches[0][1].get("isAvailable") is not True:
            raise AssertionError(f"owned iOS simulator is not uniquely live/available: {matches}")
        ios_runtime, ios_live = matches[0]
        ios_owned = self.ownership_doc["devices"]["ios"]
        if ios_live.get("name") != ios_owned["name"] or identity_token(ios_owned["runtime"]) not in identity_token(ios_runtime):
            raise AssertionError({"owned": ios_owned, "liveRuntime": ios_runtime, "liveDevice": ios_live})
        avd = self.command(phase, "android-live-identity", [str(self.adb), "-s", self.ns.android_serial, "emu", "avd", "name"]).stdout.decode().strip().splitlines()
        if not avd or avd[0].strip() != self.ns.android_avd:
            raise AssertionError(f"serial {self.ns.android_serial} is not {self.ns.android_avd}: {avd}")
        android_owned = self.ownership_doc["devices"]["android"]
        sdk = self.command(phase, "android-live-runtime", [str(self.adb), "-s", self.ns.android_serial, "shell", "getprop", "ro.build.version.sdk"]).stdout.decode().strip()
        if android_owned["name"] != avd[0].strip() or sdk not in str(android_owned["runtime"]):
            raise AssertionError({"owned": android_owned, "liveAVD": avd[0].strip(), "liveSDK": sdk})
        self.targets_verified = True
        write_json(self.output / phase / "verified.json", {"iosRuntime": ios_runtime, "ios": ios_live, "androidSerial": self.ns.android_serial, "androidAVD": avd[0].strip(), "androidSDK": sdk})

    def command(
        self,
        phase: str,
        label: str,
        argv: list[str],
        expected: int | None = 0,
        timeout: float = 180,
        cwd: Path | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        target = self.output / phase
        target.mkdir(exist_ok=True)
        started = time.time()
        write_json(target / f"{label}.command.json", {"argv": argv, "cwd": str(cwd or self.project), "started": started})
        proc = subprocess.run(argv, cwd=cwd or self.project, capture_output=True, timeout=timeout)
        (target / f"{label}.stdout").write_bytes(proc.stdout)
        (target / f"{label}.stderr").write_bytes(proc.stderr)
        write_json(target / f"{label}.result.json", {"exit": proc.returncode, "started": started, "ended": time.time()})
        if expected is not None and proc.returncode != expected:
            raise AssertionError(f"{phase}/{label}: exit {proc.returncode}, expected {expected}: {proc.stderr.decode(errors='replace')}")
        return proc

    def spawn(self, phase: str, label: str, argv: list[str]) -> subprocess.Popen[bytes]:
        target = self.output / phase
        target.mkdir(exist_ok=True)
        write_json(target / f"{label}.command.json", {"argv": argv, "cwd": str(self.project), "started": time.time()})
        out = (target / f"{label}.stdout").open("wb")
        err = (target / f"{label}.stderr").open("wb")
        proc = subprocess.Popen(argv, cwd=self.project, stdout=out, stderr=err, start_new_session=True)
        self.owned_pids[proc.pid] = {"kind": "spawned-cli", "argv": argv, "phase": phase, "label": label}
        self.record_ownership()
        return proc

    def finish(self, phase: str, label: str, proc: subprocess.Popen[bytes], timeout: float) -> int:
        code = proc.wait(timeout=timeout)
        write_json(self.output / phase / f"{label}.result.json", {"exit": code, "ended": time.time(), "pid": proc.pid})
        return code

    def ps_argv(self, pid: int) -> list[str]:
        raw = subprocess.check_output(["/bin/ps", "-ww", "-p", str(pid), "-o", "command="], text=True).strip()
        return shlex.split(raw)

    def assert_pid_bound(self, pid: int, device: str) -> list[str]:
        argv = self.ps_argv(pid)
        if device not in argv:
            raise AssertionError(f"PID {pid} is not bound to owned device {device}: {argv}")
        return argv

    def pid_is_running(self, pid: int) -> bool:
        try:
            state = subprocess.check_output(["/bin/ps", "-p", str(pid), "-o", "stat="], text=True).strip()
        except subprocess.CalledProcessError:
            return False
        return bool(state) and "Z" not in state

    def bound_argv_if_running(self, pid: int, device: str) -> list[str] | None:
        if not self.pid_is_running(pid):
            return None
        try:
            return self.assert_pid_bound(pid, device)
        except (AssertionError, subprocess.CalledProcessError):
            if not self.pid_is_running(pid):
                return None
            raise

    def bind_log_runner(self, line: str, cli_pid: int, device: str, expected_report: Path, source_flow: Path) -> dict[str, object] | None:
        columns = line.split(maxsplit=3)
        if len(columns) != 4:
            return None
        pid, ppid, pgid = map(int, columns[:3])
        if ppid != cli_pid or pgid not in (cli_pid, pid):
            return None
        argv = shlex.split(columns[3])
        if not argv or "--output" not in argv or "--device" not in argv:
            return None
        output_index = argv.index("--output")
        device_index = argv.index("--device")
        if output_index + 1 >= len(argv) or device_index + 1 >= len(argv) or argv[device_index + 1] != device:
            return None
        executable = Path(argv[0]).resolve()
        if executable != self.installed_runner or file_sha256(executable) != self.installed_runner_sha256:
            return None
        runner_report = Path(argv[output_index + 1]).resolve()
        runner_flow = Path(argv[-1]).resolve()
        if runner_report != expected_report.resolve() or not runner_report.exists() or not runner_flow.exists():
            return None
        if yaml_documents(runner_flow) != yaml_documents(source_flow) or "extendedWaitUntil" not in runner_flow.read_text():
            return None
        return {
            "pid": pid, "ppid": ppid, "pgid": pgid, "cliPID": cli_pid,
            "executable": str(executable), "executableSHA256": self.installed_runner_sha256,
            "report": str(runner_report), "sourceFlow": str(source_flow.resolve()),
            "flow": str(runner_flow), "sourceFlowSHA256": file_sha256(source_flow),
            "flowSHA256": file_sha256(runner_flow), "flowSemanticallyEquivalent": True,
        }

    def register_runner(self, pid: int, platform: str, device: str, phase: str) -> list[str]:
        argv = self.assert_pid_bound(pid, device)
        self.active_runners[pid] = (platform, device)
        self.owned_pids[pid] = {"kind": "grantiva-runner", "argv": argv, "device": device, "platform": platform, "phase": phase}
        self.record_ownership()
        return argv

    def wait_state(self, proc: subprocess.Popen[bytes], state: str, timeout: float = 150) -> dict[str, object]:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.session.exists():
                try:
                    doc = json.loads(self.session.read_text())
                except json.JSONDecodeError:
                    continue
                if doc.get("state") == state:
                    return doc
            if proc.poll() is not None:
                raise AssertionError(f"CLI {proc.pid} exited before session reached {state}")
            time.sleep(0.005)
        raise TimeoutError(f"session did not reach {state}")

    def assert_pid_gone(self, pid: int) -> None:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        raise AssertionError(f"owned PID remains: {pid}")

    def assert_session_cleanup(self, pid: int) -> None:
        if self.session.exists():
            raise AssertionError(f"project session remains for owned runner {pid}")
        shared = [str(p) for p in Path("/tmp/grantiva-sessions").glob(f"{pid}*")]
        if shared:
            raise AssertionError(f"shared session state remains for owned runner {pid}: {shared}")

    def cleanup_owned(self) -> None:
        """Best-effort bounded cleanup of only previously verified owned resources."""
        phase = "failure-cleanup"
        actions: list[dict[str, object]] = []
        if not self.targets_verified:
            write_json(self.output / "cleanup.json", {"bounded": True, "skipped": "live identities were not verified", "actions": actions})
            return
        session_doc = None
        if self.session.exists():
            try:
                session_doc = json.loads(self.session.read_text())
            except json.JSONDecodeError as exc:
                actions.append({"action": "project-session", "result": "invalid-json-refused", "error": str(exc)})
        session_pid = int(session_doc["pid"]) if isinstance(session_doc, dict) and isinstance(session_doc.get("pid"), int) else None
        if session_pid in self.active_runners:
            platform, device = self.active_runners[session_pid]
            try:
                self.assert_pid_bound(session_pid, device)
                stopped = self.command(phase, f"stop-{session_pid}", [str(self.binary), "runner", "stop", "--json"], expected=None, timeout=45)
                actions.append({"action": "runner-stop", "pid": session_pid, "platform": platform, "exit": stopped.returncode})
            except Exception as exc:
                actions.append({"action": "runner-stop", "pid": session_pid, "result": "error", "error": str(exc)})
        elif session_pid is not None:
            actions.append({"action": "project-session", "pid": session_pid, "result": "unowned-refused"})
        for pid, (platform, device) in self.active_runners.items():
            try:
                argv = self.assert_pid_bound(pid, device)
            except (ProcessLookupError, subprocess.CalledProcessError):
                continue
            except Exception as exc:
                actions.append({"action": "exact-runner-sigterm", "pid": pid, "result": "identity-refused", "error": str(exc)})
                continue
            try:
                os.kill(pid, signal.SIGTERM)
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    try:
                        os.kill(pid, 0)
                    except ProcessLookupError:
                        break
                    time.sleep(0.05)
                self.assert_pid_gone(pid)
                actions.append({"action": "exact-runner-sigterm", "pid": pid, "platform": platform, "argv": argv, "result": "gone"})
            except Exception as exc:
                actions.append({"action": "exact-runner-sigterm", "pid": pid, "result": "error", "error": str(exc)})
            for shared in Path("/tmp/grantiva-sessions").glob(f"{pid}*"):
                try:
                    if shared.is_file() or shared.is_symlink():
                        shared.unlink()
                    elif shared.is_dir():
                        shutil.rmtree(shared)
                    actions.append({"action": "remove-owned-shared-session", "pid": pid, "path": str(shared)})
                except OSError as exc:
                    actions.append({"action": "remove-owned-shared-session", "pid": pid, "path": str(shared), "error": str(exc)})
        if self.session.exists():
            try:
                current = json.loads(self.session.read_text())
                current_pid = current.get("pid")
                if current_pid in self.active_runners:
                    self.session.unlink()
                    actions.append({"action": "remove-owned-project-session", "pid": current_pid, "path": str(self.session)})
            except (OSError, json.JSONDecodeError) as exc:
                actions.append({"action": "remove-owned-project-session", "result": "error", "error": str(exc)})
        try:
            forwards = self.command(phase, "android-forwards", [str(self.adb), "-s", self.ns.android_serial, "forward", "--list"], expected=None).stdout.decode().splitlines()
            for line in forwards:
                parts = line.split()
                if len(parts) >= 2 and parts[0] == self.ns.android_serial:
                    label = f"remove-forward-{identity_token(parts[1])}"
                    removed = self.command(phase, label, [str(self.adb), "-s", self.ns.android_serial, "forward", "--remove", parts[1]], expected=None)
                    actions.append({"action": "remove-owned-forward", "local": parts[1], "exit": removed.returncode})
        except Exception as exc:
            actions.append({"action": "android-forward-cleanup", "result": "error", "error": str(exc)})
        write_json(self.output / "cleanup.json", {"bounded": True, "actions": actions})

    def preserve_runner_report(self, phase: str, label: str, proc: subprocess.Popen[bytes], device: str, state: dict[str, object]) -> None:
        target = self.output / phase / f"{label}-runner-report"
        try:
            stop = state["stop"]
            assert isinstance(stop, threading.Event)
            while not stop.is_set():
                try:
                    session_text = self.session.read_text()
                except FileNotFoundError:
                    stop.wait(0.01)
                    continue
                try:
                    doc = json.loads(session_text)
                    pid = int(doc["pid"])
                    argv = self.bound_argv_if_running(pid, device)
                except (ProcessLookupError, json.JSONDecodeError, KeyError):
                    stop.wait(0.01)
                    continue
                if argv is not None:
                    platform = "ios" if device == self.ns.ios_udid else "android"
                    self.active_runners[pid] = (platform, device)
                    self.owned_pids[pid] = {"kind": "grantiva-runner", "argv": argv, "device": device, "platform": platform, "phase": phase}
                    if "--output" in argv:
                        report = Path(argv[argv.index("--output") + 1])
                        flow = Path(argv[-1])
                        state["report"] = report
                        state["flow"] = flow
                        if report.exists():
                            copied = copy_report_snapshot(report, target)
                            state["reportWasPresent"] = True
                            state["reportSnapshotCaptured"] |= copied
                            state["sourceDisappearanceObserved"] |= not copied
                        if flow.exists():
                            shutil.copy2(flow, self.output / phase / f"{label}-generated-flow.yaml")
                            state["flowWasPresent"] = True
                    self.record_ownership()
                    if isinstance(state.get("report"), Path) and isinstance(state.get("flow"), Path):
                        state["authenticatedPID"] = pid
                        authenticated = state["authenticated"]
                        assert isinstance(authenticated, threading.Event)
                        authenticated.set()
                stop.wait(0.01)

            # Use the last paths authenticated from the live runner. Session
            # teardown or process exit cannot suppress this terminal capture.
            # Required callers join here before triggering destructive cleanup.
            report = state.get("report")
            if not isinstance(report, Path):
                raise AssertionError("snapshot worker never authenticated a runner report path")
            if report.exists():
                copied = copy_report_snapshot(report, target)
                state["terminalReportCopied"] = copied
                state["terminalReportAbsent"] = not copied
                state["reportSnapshotCaptured"] |= copied
                state["sourceDisappearanceObserved"] |= not copied
            else:
                state["terminalReportAbsent"] = True
            flow = state.get("flow")
            if isinstance(flow, Path) and flow.exists():
                shutil.copy2(flow, self.output / phase / f"{label}-generated-flow.yaml")
                state["terminalFlowCopied"] = True
            if state.get("flowWasPresent") and not (self.output / phase / f"{label}-generated-flow.yaml").is_file():
                raise AssertionError("authenticated generated flow was not retained")
            terminal = {"sourceDisappearanceObserved": state["sourceDisappearanceObserved"], "reportPath": str(report), "reportRequired": state["reportRequired"], "reportWasPresent": state["reportWasPresent"], "snapshotCaptured": state["reportSnapshotCaptured"], "terminalReportCopied": state["terminalReportCopied"], "terminalReportAbsent": state["terminalReportAbsent"], "generatedFlowRetained": bool(state.get("flowWasPresent"))}
            write_json(self.output / phase / f"{label}-snapshot-terminal.json", terminal)
        except BaseException as exc:
            state["error"] = exc
            authenticated = state.get("authenticated")
            if isinstance(authenticated, threading.Event):
                authenticated.set()

    def start_report_snapshot(self, phase: str, label: str, proc: subprocess.Popen[bytes], device: str, *, report_required: bool = True) -> tuple[dict[str, object], threading.Thread]:
        state: dict[str, object] = {"stop": threading.Event(), "authenticated": threading.Event(), "authenticatedPID": None, "report": None, "flow": None, "flowWasPresent": False, "reportRequired": report_required, "retainedReport": self.output / phase / f"{label}-runner-report" / "report.json", "reportWasPresent": False, "reportSnapshotCaptured": False, "terminalReportCopied": False, "terminalReportAbsent": False, "error": None, "terminalFlowCopied": False, "sourceDisappearanceObserved": False}
        thread = threading.Thread(target=self.preserve_runner_report, args=(phase, label, proc, device, state), daemon=False)
        thread.start()
        return state, thread

    @staticmethod
    def wait_report_snapshot_authenticated(snapshot: tuple[dict[str, object], threading.Thread], expected_pid: int | None = None) -> int:
        state, thread = snapshot
        authenticated = state["authenticated"]
        assert isinstance(authenticated, threading.Event)
        if not authenticated.wait(timeout=15):
            raise TimeoutError("runner report snapshot authentication timed out")
        error = state.get("error")
        if isinstance(error, BaseException):
            raise error
        pid = state.get("authenticatedPID")
        if not isinstance(pid, int) or (expected_pid is not None and pid != expected_pid):
            raise AssertionError({"snapshotAuthenticatedPID": pid, "expectedPID": expected_pid, "workerAlive": thread.is_alive()})
        if not isinstance(state.get("report"), Path) or not isinstance(state.get("flow"), Path):
            raise AssertionError("snapshot authentication omitted report or generated-flow path")
        return pid

    @staticmethod
    def stop_report_snapshot(snapshot: tuple[dict[str, object], threading.Thread]) -> None:
        state, thread = snapshot
        stop = state["stop"]
        assert isinstance(stop, threading.Event)
        stop.set()
        thread.join(timeout=15)
        if thread.is_alive():
            raise TimeoutError("runner report snapshot thread did not stop")
        error = state.get("error")
        if isinstance(error, BaseException):
            raise error
        if not state.get("terminalReportCopied") and not state.get("terminalReportAbsent"):
            raise AssertionError("runner report terminal source state was not recorded")
        if state.get("reportRequired"):
            # Validate only retained bytes after the worker has joined. Repeated
            # stops must not re-read the live source after legitimate cleanup.
            # Detached start also deletes its temporary launch report on normal
            # return while the runner stays ready; retained proof is mandatory,
            # continued source existence is not.
            validate_retained_report(state["retainedReport"])
            state["retainedReportValidated"] = True

    def stop_stale(self, platform: str) -> None:
        if self.session.exists():
            raise AssertionError(f"refusing silently reused session before {platform}: {self.session}")

    def start_args(self, platform: str, detach: bool = False, json_mode: bool = False) -> list[str]:
        args = [str(self.binary), "runner", "start", "--platform", platform]
        if platform == "ios":
            args += ["--simulator", self.ns.ios_udid, "--bundle-id", self.ns.ios_bundle_id]
        else:
            args += ["--device", self.ns.android_serial, "--application-id", self.ns.android_application_id]
        if detach:
            args.append("--detach")
        if json_mode:
            args.append("--json")
        return args

    def startup_interrupt(self) -> None:
        phase = "startup-interrupt"
        for platform, device in (("ios", self.ns.ios_udid), ("android", self.ns.android_serial)):
            self.stop_stale(platform)
            label = platform
            proc = self.spawn(phase, label, self.start_args(platform))
            snapshot = self.start_report_snapshot(phase, label, proc, device, report_required=False)
            try:
                doc = self.wait_state(proc, "starting")
                runner_pid = int(doc["pid"])
                self.register_runner(runner_pid, platform, device, phase)
                write_json(self.output / phase / f"{label}.starting.json", doc)
                self.wait_report_snapshot_authenticated(snapshot, runner_pid)
                os.kill(proc.pid, signal.SIGINT)
                code = self.finish(phase, label, proc, 90)
                err = (self.output / phase / f"{label}.stderr").read_text()
                notices = [line for line in err.splitlines() if line.startswith("[grantiva] received SIGINT")]
                if code != 130 or notices != [INTERRUPT_NOTICES[platform]] or "Timed out waiting" in err or self.session.exists():
                    raise AssertionError(f"{platform} startup interrupt failed: exit={code}")
                self.assert_pid_gone(runner_pid)
                self.assert_session_cleanup(runner_pid)
                self.checks.append({"phase": phase, "platform": platform, "exit": code, "runnerPID": runner_pid, "state": "starting"})
            finally:
                if proc.poll() is None:
                    os.kill(proc.pid, signal.SIGINT)
                    proc.wait(timeout=30)
                self.stop_report_snapshot(snapshot)

    def detach_ready(self) -> None:
        phase = "detach-ready"
        for platform, device in (("ios", self.ns.ios_udid), ("android", self.ns.android_serial)):
            self.stop_stale(platform)
            label = platform
            args = self.start_args(platform, detach=True, json_mode=True)
            proc = self.spawn(phase, label, args)
            snapshot = self.start_report_snapshot(phase, label, proc, device)
            try:
                starting = self.wait_state(proc, "starting")
                runner_pid = int(starting["pid"])
                self.register_runner(runner_pid, platform, device, phase)
                self.wait_report_snapshot_authenticated(snapshot, runner_pid)
                if starting.get("port") is not None:
                    raise AssertionError("genuine starting state must have null port")
                second = json.loads(self.command(phase, f"{label}-second-json", args).stdout)
                if second.get("status") != "already_running" or second.get("pid") != runner_pid or second.get("port") is not None:
                    raise AssertionError(f"invalid already-running starting response: {second}")
                plain = self.command(phase, f"{label}-second-plain", args[:-1]).stdout.decode()
                if f"Runner already running (pid {runner_pid}, starting)" not in plain:
                    raise AssertionError(plain)
                if self.finish(phase, label, proc, 600) != 0:
                    raise AssertionError(f"{platform} detach start failed")
            finally:
                self.stop_report_snapshot(snapshot)
            ready = json.loads(self.session.read_text())
            started = json.loads((self.output / phase / f"{label}.stdout").read_text())
            if ready.get("state") != "ready" or ready.get("pid") != runner_pid or started.get("pid") != runner_pid or int(ready.get("port", 0)) <= 0:
                raise AssertionError({"starting": starting, "ready": ready, "stdout": started})
            hierarchy = self.command(phase, f"{label}-immediate-hierarchy", [str(self.binary), "runner", "dump-hierarchy", "--udid", device, "--format", "tree"])
            if "Landmarks" not in hierarchy.stdout.decode(errors="replace"):
                raise AssertionError("immediate hierarchy lacks Landmarks")
            report_file = self.output / phase / f"{label}-runner-report" / "report.json"
            if not report_file.exists():
                raise AssertionError("runner report snapshot absent")
            report = json.loads(report_file.read_text())
            statuses = [flow.get("status") for flow in report.get("flows", [])]
            if "passed" not in statuses and report.get("status") != "passed":
                raise AssertionError(report)
            stop = json.loads(self.command(phase, f"{label}-stop", [str(self.binary), "runner", "stop", "--json"]).stdout)
            if stop.get("status") != "stopped" or stop.get("pid") != runner_pid or self.session.exists():
                raise AssertionError(stop)
            self.assert_pid_gone(runner_pid)
            self.assert_session_cleanup(runner_pid)
            if platform == "android":
                forwards = self.command(phase, "android-forwards-after", [str(self.adb), "-s", device, "forward", "--list"]).stdout.decode()
                if device in forwards:
                    raise AssertionError("owned Android forward remains")
            self.checks.append({"phase": phase, "platform": platform, "starting": second, "ready": ready, "stop": stop, "immediateHierarchy": True})

        # Ready-state foreground interrupt, independently on each platform.
        for platform, device in (("ios", self.ns.ios_udid), ("android", self.ns.android_serial)):
            label = f"{platform}-ready-interrupt"
            proc = self.spawn(phase, label, self.start_args(platform))
            snapshot = self.start_report_snapshot(phase, label, proc, device)
            try:
                ready = self.wait_state(proc, "ready")
                runner_pid = int(ready["pid"])
                self.register_runner(runner_pid, platform, device, phase)
                self.wait_report_snapshot_authenticated(snapshot, runner_pid)
                hierarchy = self.command(phase, f"{label}-hierarchy", [str(self.binary), "runner", "dump-hierarchy", "--udid", device, "--format", "tree"])
                if "Landmarks" not in hierarchy.stdout.decode(errors="replace"):
                    raise AssertionError(f"{platform} ready-state hierarchy lacks Landmarks")
                self.stop_report_snapshot(snapshot)
                os.kill(proc.pid, signal.SIGINT)
                code = self.finish(phase, label, proc, 45)
                err = (self.output / phase / f"{label}.stderr").read_text()
                notices = [line for line in err.splitlines() if line.startswith("[grantiva] received SIGINT")]
                if code != 130 or notices != [INTERRUPT_NOTICES[platform]] or "Timed out waiting" in err or self.session.exists():
                    raise AssertionError(f"{label} failed")
                self.assert_pid_gone(runner_pid)
                self.assert_session_cleanup(runner_pid)
                self.checks.append({"phase": "ready-interrupt", "platform": platform, "exit": code, "runnerPID": runner_pid})
            finally:
                if proc.poll() is None:
                    os.kill(proc.pid, signal.SIGINT)
                    proc.wait(timeout=30)
                self.stop_report_snapshot(snapshot)

    def absent_app(self) -> None:
        phase = "absent-app"
        missing = "com.grantiva.task8.absent"
        self.command(phase, "ios-uninstall", ["/usr/bin/xcrun", "simctl", "uninstall", self.ns.ios_udid, self.ns.ios_bundle_id], expected=None)
        absent_before = self.command(phase, "ios-absent-before", ["/usr/bin/xcrun", "simctl", "get_app_container", self.ns.ios_udid, self.ns.ios_bundle_id, "app"], expected=None)
        if absent_before.returncode == 0:
            raise AssertionError("iOS app remains installed after targeted uninstall")
        ios = [str(self.binary), "build", "install", "--platform", "ios", "--simulator", self.ns.ios_udid, "--bundle-id", self.ns.ios_bundle_id, "--no-build"]
        refusal = self.command(phase, "ios-launch-refusal", ios, expected=1)
        if "not installed" not in refusal.stderr.decode(errors="replace"):
            raise AssertionError("iOS canonical absent-install error missing")
        absent_after = self.command(phase, "ios-absent-after", ["/usr/bin/xcrun", "simctl", "get_app_container", self.ns.ios_udid, self.ns.ios_bundle_id, "app"], expected=None)
        if absent_after.returncode == 0:
            raise AssertionError("canonical refusal unexpectedly installed the iOS app")
        restored = json.loads(self.command(phase, "ios-restore", ios + ["--app-file", str(self.ns.ios_app), "--no-launch", "--json"]).stdout)
        if restored.get("status") != "installed" or Path(restored.get("appPath", "")).resolve() != self.ns.ios_app.resolve():
            raise AssertionError(restored)
        android = self.start_args("android", detach=True, json_mode=True)
        android[android.index("--application-id") + 1] = missing
        result = self.command(phase, "android-launch-refusal", android, expected=1, timeout=45)
        if b"Timed out" in result.stderr or self.session.exists():
            raise AssertionError("Android absent app timed out or created a session")
        forwards = self.command(phase, "android-forwards-after", [str(self.adb), "-s", self.ns.android_serial, "forward", "--list"]).stdout.decode()
        if self.ns.android_serial in forwards:
            raise AssertionError("Android absent-app failure left an owned forward")
        self.checks.append({"phase": phase, "iosCanonicalNotInstalled": True, "iosRestored": str(self.ns.ios_app), "androidPromptFailure": True})

    def log_cleanup(self) -> None:
        phase = "log-cleanup"
        root = self.output / phase
        root.mkdir(exist_ok=True)
        flows = {
            "success": f"appId: {self.ns.ios_bundle_id}\n---\n- launchApp\n- assertVisible: Landmarks\n",
            "failed": f"appId: {self.ns.ios_bundle_id}\n---\n- launchApp\n- assertVisible: task8-deliberately-absent\n",
            "interrupted": f"appId: {self.ns.ios_bundle_id}\n---\n- launchApp\n- extendedWaitUntil:\n    visible: task8-deliberately-absent\n    timeout: 300000\n",
        }
        for label, body in flows.items():
            flow = root / f"{label}.yaml"
            flow.write_text(body)
            report = root / f"{label}-report"
            ready = root / f"{label}-ready.json"
            argv = [str(self.binary), "run", "--platform", "ios", "--no-build", "--simulator", self.ns.ios_udid, "--flow", str(flow), "--report-dir", str(report), "--logs", "--logs-predicate", 'process == "Landmarks"', "--verbose"]
            if label == "success":
                argv += ["--keep-alive", "--ready-file", str(ready)]
            proc = self.spawn(phase, label, argv)
            marker = None
            child_pid = None
            try:
                deadline = time.monotonic() + 180
                while time.monotonic() < deadline:
                    ps = subprocess.check_output(["/bin/ps", "-ww", "-axo", "pid=,ppid=,pgid=,command="], text=True)
                    wrappers = [line for line in ps.splitlines() if f"simctl spawn {self.ns.ios_udid} log stream" in line and "grantiva-log-" in line]
                    if wrappers:
                        match = re.search(r"grantiva-log-[A-F0-9-]+", wrappers[0])
                        if match:
                            marker = match.group()
                            children = [line for line in ps.splitlines() if marker in line and len(line.split(maxsplit=3)) == 4 and line.split(maxsplit=3)[3].startswith("log stream ")]
                            if children:
                                child_pid = int(children[0].split()[0])
                                self.owned_pids[child_pid] = {"kind": "log-child", "marker": marker, "device": self.ns.ios_udid, "phase": phase, "case": label}
                                break
                    if proc.poll() is not None:
                        raise AssertionError(f"{label} exited before owned log child was observed")
                    time.sleep(0.025)
                if not marker or child_pid is None:
                    raise TimeoutError(f"owned iOS log child not observed for {label}")
                self.record_ownership()
                active_runner = None
                if label == "success":
                    deadline = time.monotonic() + 240
                    while not ready.exists() and time.monotonic() < deadline:
                        if proc.poll() is not None:
                            raise AssertionError("success control exited before ready")
                        time.sleep(0.05)
                    ready_doc = json.loads(ready.read_text())
                    if ready_doc.get("status") != "passed":
                        raise AssertionError(ready_doc)
                    os.kill(proc.pid, signal.SIGINT)
                elif label == "interrupted":
                    deadline = time.monotonic() + 180
                    while time.monotonic() < deadline and active_runner is None:
                        ps = subprocess.check_output(["/bin/ps", "-ww", "-axo", "pid=,ppid=,pgid=,command="], text=True)
                        for line in ps.splitlines():
                            active_runner = self.bind_log_runner(line, proc.pid, self.ns.ios_udid, report, flow)
                            if active_runner is not None:
                                break
                        if proc.poll() is not None:
                            raise AssertionError("interrupted control exited before its long-wait runner became active")
                        if active_runner is None:
                            time.sleep(0.025)
                    if active_runner is None:
                        raise TimeoutError("interrupted long-wait runner/report did not become active")
                    os.kill(proc.pid, signal.SIGINT)
                code = self.finish(phase, label, proc, 180)
                expected = {"success": 0, "failed": 1, "interrupted": 130}[label]
                if code != expected:
                    raise AssertionError(f"{label} log cleanup exit {code}, expected {expected}")
                for index in range(3):
                    ps = self.command(phase, f"{label}-processes-after-{index}", ["/bin/ps", "-ww", "-axo", "pid=,ppid=,pgid=,command="]).stdout.decode()
                    if marker in ps:
                        raise AssertionError(f"{label} owned log child remains")
                err = (root / f"{label}.stderr").read_text()
                terminals = [line for line in err.splitlines() if f"simctl spawn {self.ns.ios_udid} log stream" in line and ("stopped by " in line or "exit " in line)]
                if len(terminals) != 1 or "could not confirm log-stream cleanup" in err:
                    raise AssertionError({"case": label, "terminalDiagnostics": terminals})
                report_path = report / "report.json"
                report_status = None
                if report_path.exists():
                    report_doc = json.loads(report_path.read_text())
                    expected_status = {"success": "passed", "failed": "failed", "interrupted": "interrupted"}[label]
                    if report_doc.get("status") != expected_status and not any(f.get("status") == expected_status for f in report_doc.get("flows", [])):
                        raise AssertionError({"case": label, "report": report_doc})
                    report_status = expected_status
                elif label != "interrupted":
                    raise AssertionError(f"{label} report is absent")
                self.checks.append({"phase": phase, "case": label, "exit": code, "ownedMarker": marker, "ownedChildPID": child_pid, "absentSnapshots": 3, "terminalDiagnostic": terminals[0], "activeRunner": active_runner, "reportStatus": report_status})
            finally:
                if proc.poll() is None:
                    os.kill(proc.pid, signal.SIGINT)
                    proc.wait(timeout=30)

    def cycle_controls(self) -> None:
        phase = "cycle-controls"
        root = self.output / phase / "project"
        root.mkdir(parents=True, exist_ok=True)
        (root / "a.yaml").write_text(f"appId: {self.ns.ios_bundle_id}\n---\n- runFlow: b.yaml\n")
        (root / "b.yaml").write_text(f"appId: {self.ns.ios_bundle_id}\n---\n- runFlow: a.yaml\n")
        base = f"bundle_id: {self.ns.ios_bundle_id}\nsimulator: {self.ns.ios_udid}\n"
        cases = (("screens", None, "grantiva.yml -> a.yaml -> b.yaml -> a.yaml"), ("root", "a.yaml", "a.yaml -> b.yaml -> a.yaml -> b.yaml"), ("absolute", str(root / "a.yaml"), f"{root / 'a.yaml'} -> b.yaml -> a.yaml -> b.yaml"))
        for label, flow_name, expected in cases:
            (root / "grantiva.yml").write_text(base + ("screens:\n  - name: S\n    path:\n      - run_flow: a.yaml\n" if flow_name is None else ""))
            argv = [str(self.binary), "run", "--platform", "ios", "--no-build", "--simulator", self.ns.ios_udid] + (["--flow", flow_name] if flow_name else [])
            started = time.monotonic()
            result = self.command(phase, label, argv, expected=1, timeout=20, cwd=root)
            elapsed = time.monotonic() - started
            text = (result.stdout + result.stderr).decode(errors="replace")
            if f"circular dependency detected: {expected}" not in text or elapsed >= 5:
                raise AssertionError({"case": label, "elapsed": elapsed, "expected": expected})
            self.checks.append({"phase": phase, "case": label, "exit": 1, "duration": elapsed, "diagnostic": expected})

    def force_teardown(self) -> None:
        phase = "force-teardown"
        self.stop_stale("ios-force-teardown")
        proc = self.spawn(phase, "live-start", self.start_args("ios", detach=True, json_mode=True))
        snapshot = self.start_report_snapshot(phase, "live-start", proc, self.ns.ios_udid)
        try:
            authenticated_pid = self.wait_report_snapshot_authenticated(snapshot)
            if self.finish(phase, "live-start", proc, 600) != 0:
                raise AssertionError("force-teardown runner start failed")
        finally:
            self.stop_report_snapshot(snapshot)
        start = json.loads((self.output / phase / "live-start.stdout").read_text())
        runner_pid = int(start["pid"])
        if runner_pid != authenticated_pid:
            raise AssertionError({"startedPID": runner_pid, "snapshotAuthenticatedPID": authenticated_pid})
        self.register_runner(runner_pid, "ios", self.ns.ios_udid, phase)
        self.command(phase, "live-hierarchy", [str(self.binary), "runner", "dump-hierarchy", "--udid", self.ns.ios_udid, "--format", "tree"])
        force_doc = json.loads(self.command(phase, "live-force", [str(self.binary), "simulator", "teardown", "--udid", self.ns.ios_udid, "--force", "--json"], timeout=240).stdout)
        entry = force_doc[0] if isinstance(force_doc, list) else force_doc
        if (entry.get("runnerSessionStopped") is not True or entry.get("reclaimed") is not True
                or not isinstance(entry.get("processes"), list) or not isinstance(entry.get("reapedProcesses"), list)):
            raise AssertionError(entry)
        self.assert_pid_gone(runner_pid)
        self.assert_session_cleanup(runner_pid)
        write_json(self.output / "IOS-FORCE-RECLAIMED.json", {
            "ownedUDID": self.ns.ios_udid, "phase": phase, "resourcesReclaimed": True,
            "physicalDeviceDeleted": False, "finalCleanupRequired": True,
        })
        self.checks.append({
            "phase": phase, "runnerPID": runner_pid, "result": entry,
            "resourcesReclaimed": True, "physicalDeviceDeleted": False,
            "finalCleanupRequired": True,
        })
        self.record_ownership("force-resources-reclaimed")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--binary", type=Path, required=True)
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--bundle", type=Path, required=True)
    p.add_argument("--runner", type=Path, required=True)
    p.add_argument("--candidate-manifest", type=Path, required=True)
    p.add_argument("--ownership-manifest", type=Path, required=True)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--runner-home", type=Path, required=True)
    p.add_argument("--session-id", default="completion-candidate5")
    p.add_argument("--ios-udid", required=True)
    p.add_argument("--android-serial", required=True)
    p.add_argument("--android-avd", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--adb", default=os.environ.get("ANDROID_HOME", str(Path.home() / "Library/Android/sdk")) + "/platform-tools/adb")
    p.add_argument("--ios-bundle-id", default="com.kylebrowning.Landmarks")
    p.add_argument("--ios-app", type=Path, required=True)
    p.add_argument("--android-application-id", default="com.kylebrowning.landmarks")
    p.add_argument("--phase", action="append", choices=PHASES)
    p.add_argument("--allow-force-reclaim-owned-ios", action="store_true")
    p.add_argument("--validate-only", action="store_true")
    return p


def validate(ns: argparse.Namespace) -> list[str]:
    errors: list[str] = []
    for name in ("binary", "source", "bundle", "runner", "candidate_manifest", "ownership_manifest", "project", "runner_home", "ios_app"):
        path = getattr(ns, name)
        if not path.is_absolute() or not path.exists():
            errors.append(f"--{name.replace('_', '-')} must be an existing absolute path: {path}")
    if ns.binary.exists() and not os.access(ns.binary, os.X_OK):
        errors.append(f"--binary is not executable: {ns.binary}")
    if not ns.output.is_absolute() or ns.output.exists():
        errors.append(f"--output must be an absent absolute path: {ns.output}")
    if ns.ios_udid in PROTECTED_UDIDS:
        errors.append("protected iOS owner device cannot be a smoke target")
    if ns.android_avd in PROTECTED_AVDS:
        errors.append("protected Android owner AVD cannot be a smoke target")
    if ns.session_id != "completion-candidate5":
        errors.append("Task 8 session must be literal completion-candidate5")
    phases = ns.phase or list(PHASES[:-1])
    if "force-teardown" in phases and (len(phases) != 1 or not ns.allow_force_reclaim_owned_ios):
        errors.append("force-teardown must run alone with --allow-force-reclaim-owned-ios")
    if "force-teardown" not in phases and ns.allow_force_reclaim_owned_ios:
        errors.append("--allow-force-reclaim-owned-ios is valid only with --phase force-teardown")
    return errors


def main() -> int:
    ns = parser().parse_args()
    errors = validate(ns)
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2), file=sys.stderr)
        return 2
    phases = ns.phase or list(PHASES[:-1])
    if ns.validate_only:
        print(json.dumps({"valid": True, "phases": phases, "forceTeardownIsolated": True}, indent=2))
        return 0
    smoke: Smoke | None = None
    status = "failed"
    try:
        smoke = Smoke(ns)
        smoke.record_ownership()
        for phase in phases:
            getattr(smoke, phase.replace("-", "_"))()
            write_json(smoke.output / "checks.partial.json", smoke.checks)
        status = "passed"
        write_json(smoke.output / "acceptance.json", {"status": status, "phases": phases, "checks": smoke.checks})
        return 0
    except Exception as exc:
        failure_output = smoke.output if smoke is not None else ns.output.resolve()
        failure_output.mkdir(parents=True, exist_ok=True)
        write_json(failure_output / "failure.json", {"status": status, "errorType": type(exc).__name__, "error": str(exc), "checks": smoke.checks if smoke else []})
        if smoke is not None:
            smoke.cleanup_owned()
        raise
    finally:
        if smoke is not None:
            smoke.record_ownership("force-resources-reclaimed" if (smoke.output / "IOS-FORCE-RECLAIMED.json").exists() else status)


if __name__ == "__main__":
    raise SystemExit(main())
