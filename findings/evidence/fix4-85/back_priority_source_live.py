#!/usr/bin/env python3
"""Bounded L85 source-build acceptance. Provision/install are controller-owned prerequisites."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

APP_ID = "com.kylebrowning.Landmarks"
SESSION_ID = "fix4-85"
EXPECTED_RUNNER_SOURCE = "ba9008f4b2cd2c7320a9c46e04faed612b0958a2"
EXPECTED_DEMO_SOURCE = "84af7581b75134b0e417b254e4317d565f7b73c6"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def walk(node):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def good(reply):
    return not reply.get("error") and not reply.get("result", {}).get("isError")


def hierarchy_from(text):
    return json.loads(text[text.index("{"):])


def node(nodes, **attrs):
    return next((item for item in nodes if all(item.get(key) == value for key, value in attrs.items())), None)


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()


def normalized_manifest(root, declared, label):
    root = Path(root).resolve()
    require(root.is_dir(), f"{label} root is not a directory")
    require(isinstance(declared, list) and declared, f"{label} manifest is empty")
    normalized = []
    seen = set()
    for item in declared:
        relative = Path(item["path"])
        require(not relative.is_absolute() and ".." not in relative.parts, f"unsafe {label} path: {relative}")
        relative_text = relative.as_posix()
        require(relative_text not in seen, f"duplicate {label} path: {relative_text}")
        seen.add(relative_text)
        path = (root / relative).resolve()
        require(path.is_relative_to(root) and path.is_file(), f"missing or escaped {label} file: {relative_text}")
        normalized.append({"path": relative_text, "sha256": item["sha256"]})
    actual = [{"path": path.relative_to(root).as_posix(), "sha256": sha(path)}
              for path in sorted((item for item in root.rglob("*") if item.is_file()), key=lambda item: item.relative_to(root).as_posix())]
    require(sorted(normalized, key=lambda item: item["path"]) == actual, f"{label} complete manifest mismatch")
    return actual


parser = argparse.ArgumentParser()
parser.add_argument("--source-manifest", required=True)
parser.add_argument("--ownership", required=True)
parser.add_argument("--project", required=True)
parser.add_argument("--output", required=True)
ns = parser.parse_args()

manifest_path = Path(ns.source_manifest).resolve()
ownership_path = Path(ns.ownership).resolve()
project = Path(ns.project).resolve()
output = Path(ns.output).resolve()
require(manifest_path.is_file(), "source manifest missing")
require(ownership_path.is_file(), "ownership manifest missing")
require(project.is_dir(), "controller must create the fresh project directory")
require(not (project / ".grantiva/session.json").exists(), "project already has a runner session")
require(not output.exists(), "output already exists")
output.mkdir(parents=True)

source = load(manifest_path)
ownership = load(ownership_path)
require(source.get("schema") == "grantiva.fix4-85.source.v1", "wrong source manifest schema")
require(source.get("finalMergedCandidate") is False, "source build must be explicitly non-final")
require(source.get("task8Passed") is False, "source build must not claim Task 8 passed")
runtime = source["runtimeOwner"]
require(runtime.get("sessionId") == SESSION_ID, "runtime owner session must be fix4-85")
require(Path(runtime["ownershipManifest"]).resolve() == ownership_path, "source manifest ownership path mismatch")

device = ownership["device"]
require(ownership.get("schema") == "grantiva.fix4-85.ownership.v1", "wrong ownership schema")
require(device.get("owned") is True, "device is not explicitly owned")
require(device.get("platform") == "ios", "owned device is not iOS")
require(device.get("id") == runtime.get("deviceId"), "runtime owner/device mismatch")
require(device.get("name") in ("fix4-back-26", "fix4-back-27"), "unexpected owned simulator name")
require(isinstance(device.get("runtime"), str) and device["runtime"], "runtime missing")
require(isinstance(device.get("deviceType"), str) and device["deviceType"], "device type missing")
expected_creation = ["xcrun", "simctl", "create", device["name"], device["deviceType"], device["runtime"]]
require(device.get("creationCommand") == expected_creation, "literal creation command does not bind name/device type/runtime")
require(device.get("claimedBeforeCreation") is True, "ownership was not preclaimed")
require(isinstance(device.get("claimedAtEpoch"), (int, float)) and isinstance(device.get("createdAtEpoch"), (int, float))
        and device["claimedAtEpoch"] <= device["createdAtEpoch"], "ownership claim must precede creation")
udid = device["id"]

cli = source["cli"]
runner = source["runner"]
demo = source["demo"]
binary = Path(cli["releaseBinary"]["path"]).resolve()
bundle = Path(cli["adjacentBundle"]["path"]).resolve()
runner_binary = Path(runner["installed"]["path"]).resolve()
runner_home = Path(runner["home"]).resolve()
app = Path(demo["app"]["path"]).resolve()
for required_path in (binary, bundle, runner_binary, runner_home, app):
    require(required_path.exists(), f"missing identity path: {required_path}")

require(cli.get("cleanStatus") == "" and git(cli["repo"], "status", "--porcelain") == "", "CLI source is not clean")
require(git(cli["repo"], "rev-parse", "HEAD") == cli["head"], "CLI source HEAD changed")
require(sha(binary) == cli["releaseBinary"]["sha256"], "release binary hash changed")
require(subprocess.run([binary, "--version"], check=True, capture_output=True, text=True).stdout.strip() == cli["releaseBinary"]["version"], "CLI version changed")
bundle_manifest = normalized_manifest(bundle, cli["adjacentBundle"]["files"], "adjacent bundle")
proof = cli["frozenBuildProof"]
require(Path(proof["path"]).is_file() and sha(proof["path"]) == proof["sha256"], "frozen build proof changed")
proof_doc = load(proof["path"])
require(proof_doc.get("schema") == "grantiva.fix4-85.release-build.v1", "wrong frozen build-proof schema")
require(proof_doc.get("success") is True and proof_doc.get("exit") == 0, "frozen release build did not succeed")
require(Path(proof_doc["repo"]).resolve() == Path(cli["repo"]).resolve() and proof_doc.get("sourceHead") == cli["head"], "build proof source binding mismatch")
require(Path(proof_doc["binary"]["path"]).resolve() == binary and proof_doc["binary"].get("sha256") == sha(binary), "build proof binary binding mismatch")
require(Path(proof_doc["bundle"]["path"]).resolve() == bundle and proof_doc["bundle"].get("files") == bundle_manifest, "build proof bundle binding mismatch")
build_command = proof_doc["command"]
require(isinstance(build_command.get("argv"), list) and build_command["argv"], "build proof argv missing")
require(Path(build_command["cwd"]).resolve() == Path(cli["repo"]).resolve(), "build proof cwd mismatch")
require(build_command.get("exit") == 0 and isinstance(build_command.get("startEpoch"), (int, float))
        and isinstance(build_command.get("endEpoch"), (int, float)) and build_command["endEpoch"] >= build_command["startEpoch"], "build proof terminal metadata invalid")
for stream in ("stdout", "stderr"):
    stream_proof = build_command[stream]
    require(Path(stream_proof["path"]).is_file() and sha(stream_proof["path"]) == stream_proof["sha256"], f"build proof {stream} changed")
require(runner.get("sourceHead") == EXPECTED_RUNNER_SOURCE, "runner is not unchanged ba9008 .15 source")
expected_stamp = "1.1.28-grantiva.15+android-drivers-2"
require(runner["installed"].get("installStamp") == expected_stamp, "runner install stamp changed")
require(runner_binary.is_relative_to(runner_home) and runner_binary == runner_home / "versions" / expected_stamp / "grantiva-runner", "installed runner path is not bound to fresh home/stamp")
require(sha(runner_binary) == runner["installed"]["sha256"], "installed runner hash changed")
require(subprocess.run([runner_binary, "--version"], check=True, capture_output=True, text=True).stdout.strip() == runner["installed"]["nativeVersion"], "runner native version changed")
require(demo.get("sourceHead") == EXPECTED_DEMO_SOURCE, "demo source is not frozen 84af")
require(git(demo["repo"], "rev-parse", "HEAD") == EXPECTED_DEMO_SOURCE, "demo checkout HEAD changed")
require(demo.get("cleanStatus") == "" and git(demo["repo"], "status", "--porcelain") == "", "demo source is not clean")
app_manifest = normalized_manifest(app, demo["app"]["files"], "source app")

env = os.environ.copy()
env.pop("GRANTIVA_API_KEY", None)
env.update(GRANTIVA_RUNNER_HOME=str(runner_home), MAESTRO_RUNNER_HOME=str(runner_home), GRANTIVA_SESSION_ID=SESSION_ID)
os.environ.pop("GRANTIVA_API_KEY", None)
os.environ.update(GRANTIVA_RUNNER_HOME=str(runner_home), MAESTRO_RUNNER_HOME=str(runner_home), GRANTIVA_SESSION_ID=SESSION_ID)

provenance = {
    "schema": source["schema"], "finalMergedCandidate": False, "task8Passed": False,
    "sourceManifest": str(manifest_path), "sourceManifestSHA256": sha(manifest_path),
    "ownership": str(ownership_path), "ownershipSHA256": sha(ownership_path),
    "cliHead": cli["head"], "binary": str(binary), "binarySHA256": sha(binary),
    "releaseBuildProof": {"path": str(Path(proof["path"]).resolve()), "sha256": proof["sha256"],
                          "schema": proof_doc["schema"], "sourceHead": proof_doc["sourceHead"],
                          "binary": proof_doc["binary"], "bundle": proof_doc["bundle"], "command": build_command},
    "runnerSourceHead": runner["sourceHead"], "runner": str(runner_binary), "runnerSHA256": sha(runner_binary),
    "demoSourceHead": demo["sourceHead"], "app": str(app), "device": device,
    "project": str(project), "runnerHome": str(runner_home), "sessionId": SESSION_ID, "apiKey": "unset",
}
(output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


def command(label, argv, timeout=240, expect=0):
    directory = output / label
    directory.mkdir()
    argv = [str(value) for value in argv]
    record = {"argv": argv, "cwd": str(project), "start": time.time(), "environment": {
        "GRANTIVA_RUNNER_HOME": str(runner_home), "MAESTRO_RUNNER_HOME": str(runner_home),
        "GRANTIVA_SESSION_ID": SESSION_ID, "GRANTIVA_API_KEY": "unset"}}
    (directory / "start.json").write_text(json.dumps(record, indent=2) + "\n")
    try:
        with (directory / "stdout.raw").open("wb") as stdout, (directory / "stderr.raw").open("wb") as stderr:
            result = subprocess.run(argv, cwd=project, env=env, stdout=stdout, stderr=stderr, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        record.update(end=time.time(), exit=None, timedOut=True, timeoutSeconds=timeout,
                      partialStdoutBytes=(directory / "stdout.raw").stat().st_size,
                      partialStderrBytes=(directory / "stderr.raw").stat().st_size)
        (directory / "result.json").write_text(json.dumps(record, indent=2) + "\n")
        raise
    record.update(end=time.time(), exit=result.returncode, timedOut=False)
    (directory / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    require(result.returncode == expect, f"{label} exit {result.returncode}, expected {expect}")
    return directory


session_path = project / ".grantiva/session.json"
client = None
owned_pid = None
checks = []
try:
    simulator_list = command("simulator-identity", ["/usr/bin/xcrun", "simctl", "list", "devices", "--json"], timeout=60)
    listed = load(simulator_list / "stdout.raw")
    matches = [(runtime_name, item) for runtime_name, devices in listed.get("devices", {}).items()
               for item in devices if item.get("udid") == udid]
    require(len(matches) == 1, "owned simulator UUID is not unique in simctl inventory")
    actual_runtime, actual_device = matches[0]
    require(actual_runtime == device["runtime"] and actual_device.get("name") == device["name"], "actual simulator name/runtime mismatch")
    expected_major = "26" if device["name"] == "fix4-back-26" else "27"
    require(actual_runtime.startswith(f"com.apple.CoreSimulator.SimRuntime.iOS-{expected_major}-"), "owned simulator name is paired with the wrong approved runtime")
    provenance["actualSimulator"] = {"runtime": actual_runtime, **actual_device}
    installed_query = command("installed-app-container", ["/usr/bin/xcrun", "simctl", "get_app_container", udid, APP_ID, "app"], timeout=60)
    installed_app = Path((installed_query / "stdout.raw").read_text().strip()).resolve()
    require(installed_app.is_dir(), "installed demo app container missing")
    installed_manifest = normalized_manifest(installed_app, demo["app"]["files"], "installed app")
    require(installed_manifest == app_manifest, "installed app differs from frozen source app")
    provenance["installedApp"] = str(installed_app)
    (output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    command("runner-start", [binary, "runner", "start", "--platform", "ios", "--simulator", udid,
                              "--bundle-id", APP_ID, "--detach", "--json"])
    session = load(session_path)
    require(session.get("platform") == "ios" and udid in (session.get("udid"), session.get("device"), session.get("deviceId")), "started session identity mismatch")
    owned_pid = session.get("pid") or session.get("runnerPid")
    require(isinstance(owned_pid, int) and not isinstance(owned_pid, bool) and owned_pid > 0, "started session lacks a positive runner PID")

    client_dir = Path(__file__).resolve().parents[3] / "findings/tools/round4-smoke-candidate2"
    sys.path.insert(0, str(client_dir))
    from mcp_client import Client
    client = Client(binary, project, "ios", output / "mcp")
    ready = None
    for _ in range(30):
        ready = client.tool("grantiva_a11y_tree", {})
        if good(ready):
            break
        time.sleep(1)
    require(good(ready), "MCP hierarchy never became ready")

    for arguments, expected in [({}, "Error: Invalid argument: 'steps' is required."),
                                ({"steps": "tap"}, "Error: Invalid argument: 'steps' array is required.")]:
        reply = client.tool("grantiva_script", arguments)
        require(reply["result"].get("isError") and client.text(reply) == expected, "L65 exact error changed")
    empty = client.tool("grantiva_script", {"steps": []})
    require(good(empty) and "Final hierarchy:" in client.text(empty), "L65 empty script behavior changed")
    missing = client.tool("grantiva_tap", {"label": "No Such Selector fix4-85"})
    require(missing["result"].get("isError") and "Element not found" in client.text(missing), "unknown-selector error changed")
    checks.append({"L65ExactErrors": True, "unknownSelector": client.text(missing)})

    cold = hierarchy_from(client.text(ready)); cold_nodes = list(walk(cold))
    heart = node(cold_nodes, type="XCUIElementTypeButton", identifier="heart")
    require(heart and heart.get("value") != "1", "cold Favorites heart identifier is not unselected")
    first_heart = client.tool("grantiva_tap", {"label": "heart"})
    require(good(first_heart) and client.text(first_heart).startswith('Tapped on "heart" (matched by identifier).'), "unselected heart identifier tap failed")
    selected_heart = node(list(walk(hierarchy_from(client.text(first_heart)))), type="XCUIElementTypeButton", identifier="heart")
    require(selected_heart and selected_heart.get("value") == "1", "heart did not become selected")
    landmarks = client.tool("grantiva_tap", {"label": "Landmarks"}); require(good(landmarks), "Landmarks tab failed")
    second_heart = client.tool("grantiva_tap", {"label": "heart"})
    require(good(second_heart) and client.text(second_heart).startswith('Tapped on "heart" (matched by identifier).'), "second unselected heart identifier tap failed")
    selected_heart = node(list(walk(hierarchy_from(client.text(second_heart)))), type="XCUIElementTypeButton", identifier="heart")
    require(selected_heart and selected_heart.get("value") == "1", "second heart did not become selected")
    checks.append({"coldHeartUnselectedAndSelectedIdentifier": True})

    for label in ("Deep Links", "Edit Landmark"):
        reply = client.tool("grantiva_tap", {"label": label}); require(good(reply), f"{label} tap failed")
    name_reply = client.tool("grantiva_tap", {"label": "Name"})
    require(good(name_reply) and client.text(name_reply).startswith('Tapped on "Name" (matched by placeholder).'), "Name placeholder fallback failed")
    require(good(client.tool("grantiva_tap", {"label": "Cancel"})), "Cancel failed")
    require(good(client.tool("grantiva_tap", {"label": "Landmarks"})), "return to Landmarks failed")
    require(good(client.tool("grantiva_tap", {"label": "Mountains"})), "Mountains row failed")
    denali = client.tool("grantiva_tap", {"label": 'Mount "Denali"'})
    require(good(denali) and client.text(denali).startswith('Tapped on "Mount "Denali""'), "quoted Denali selector failed")
    require(node(list(walk(hierarchy_from(client.text(denali)))), type="XCUIElementTypeButton", identifier="BackButton", label="Mountains"), "Denali Mountains back missing")

    require(good(client.tool("grantiva_tap", {"label": "Favorites"})), "switch to Favorites failed")
    restored = client.tool("grantiva_tap", {"label": "Landmarks"}); require(good(restored), "switch back to Landmarks failed")
    restored_tree = hierarchy_from(client.text(restored)); restored_nodes = list(walk(restored_tree))
    require(node(restored_nodes, type="XCUIElementTypeButton", identifier="BackButton", label="Mountains"), "Denali stack was not preserved")
    mountains = client.tool("grantiva_tap", {"label": "Mountains"}); require(good(mountains), "Mountains back failed")
    category = hierarchy_from(client.text(mountains)); category_nodes = list(walk(category))
    require(category.get("type") == "XCUIElementTypeApplication" and category.get("label") == "Landmarks", "category application root missing")
    require(node(category_nodes, type="XCUIElementTypeButton", identifier="BackButton", label="Landmarks"), "Landmarks back button missing")
    selected_tab = next((n for n in category_nodes if n.get("type") == "XCUIElementTypeButton" and n.get("label") == "Landmarks" and n.get("identifier") != "BackButton" and n.get("value") == "1"), None)
    require(selected_tab, "same-labelled selected Landmarks tab missing")
    back = client.tool("grantiva_tap", {"label": "Landmarks"}); back_text = client.text(back)
    require(good(back) and back_text.startswith('Tapped on "Landmarks". Updated hierarchy:'), "semantic Landmarks tap lost label-stage annotation")
    root_tree = hierarchy_from(back_text)
    require(any(n.get("label") == "Golden Gate Bridge" for n in walk(root_tree)), "Landmarks back did not reach root list")
    fresh = client.tool("grantiva_a11y_tree", {}); require(good(fresh), "independent hierarchy failed")
    fresh_tree = hierarchy_from(client.text(fresh))
    require(any(n.get("label") == "Golden Gate Bridge" for n in walk(fresh_tree)), "fresh hierarchy does not confirm root list")
    (output / "independent-root-hierarchy.json").write_text(json.dumps(fresh_tree, indent=2) + "\n")
    command("independent-screenshot", ["/usr/bin/xcrun", "simctl", "io", udid, "screenshot", output / "root-after-back.png"], timeout=60)
    checks.append({"quotedDenali": True, "mountainsStackPreservedAcrossTabs": True,
                   "collisionHasApplicationBackAndSelectedTab": True, "semanticBackWins": True,
                   "independentHierarchy": "independent-root-hierarchy.json", "screenshot": "root-after-back.png"})

    favorite = node(list(walk(fresh_tree)), type="XCUIElementTypeButton", label="Favorites")
    require(favorite and favorite.get("frame"), "Favorites frame missing for coordinate control")
    frame = favorite["frame"]
    point = {"x": frame["x"] + frame["width"] / 2, "y": frame["y"] + frame["height"] / 2}
    coordinate = client.tool("grantiva_tap", point)
    require(good(coordinate) and client.text(coordinate).startswith("Tapped at ("), "coordinate control failed")
    checks.append({"coordinateControl": point})
finally:
    primary_error = sys.exc_info()[1]
    cleanup_errors = []
    if client is not None:
        try:
            client.close()
        except Exception as error:
            cleanup_errors.append(f"MCP close: {type(error).__name__}: {error}")
    if session_path.exists():
        try:
            current = load(session_path)
            require(current.get("platform") == "ios" and udid in (current.get("udid"), current.get("device"), current.get("deviceId")), "refusing to stop non-owned project session")
            command("runner-stop", [binary, "runner", "stop", "--json"], timeout=120)
        except Exception as error:
            cleanup_errors.append(f"runner stop: {type(error).__name__}: {error}")
    session_absent = not session_path.exists()
    if not session_absent:
        cleanup_errors.append("owned project session remains after stop")
    pid_absent = False
    if isinstance(owned_pid, int) and not isinstance(owned_pid, bool) and owned_pid > 0:
        deadline = time.monotonic() + 10
        while True:
            try:
                os.kill(int(owned_pid), 0)
                pid_absent = False
            except (ProcessLookupError, ValueError):
                pid_absent = True
            except PermissionError:
                pid_absent = False
            if pid_absent or time.monotonic() >= deadline:
                break
            time.sleep(0.2)
    else:
        cleanup_errors.append("no valid positive owned runner PID was captured")
    if not pid_absent:
        cleanup_errors.append("exact owned runner PID remains or could not be proven absent")
    cleanup = {"projectSessionAbsent": session_absent, "ownedRunnerPid": owned_pid, "ownedRunnerPidAbsent": pid_absent,
               "deviceDeleted": False, "simulatorCreationOrDeletionAttempted": False,
               "primaryError": None if primary_error is None else f"{type(primary_error).__name__}: {primary_error}",
               "cleanupErrors": cleanup_errors}
    (output / "cleanup.json").write_text(json.dumps(cleanup, indent=2) + "\n")
    if primary_error is None and cleanup_errors:
        raise AssertionError("; ".join(cleanup_errors))

(output / "acceptance.json").write_text(json.dumps({"passed": True, "scope": "L85 source-live only",
    "finalMergedCandidate": False, "task8Passed": False, "device": udid, "checks": checks}, indent=2) + "\n")
