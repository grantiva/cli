#!/usr/bin/env python3
import json
import os
import pathlib
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent
mode = sys.argv[1]
runner_home = pathlib.Path("/private/tmp/grantiva-fix4-2.WiwpaS/runner-home")
runner = runner_home / "grantiva-runner"
sdk = pathlib.Path("/Users/kyle/Library/Android/sdk")
serial = "emulator-5580"
forms = ("direction", "coordinates", "element", "engine-adb")
mode_root = root / mode
source_reader = root / "uia2-source-snapshot-v2.py"

env = os.environ.copy()
env.pop("GRANTIVA_API_KEY", None)
env.update({
    "GRANTIVA_RUNNER_HOME": str(runner_home),
    "MAESTRO_RUNNER_HOME": str(runner_home),
    "GRANTIVA_SESSION_ID": "fix4-2",
    "PATH": f"{sdk / 'platform-tools'}:{env['PATH']}",
})

def wait_log(path, needle, proc, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        text = path.read_text(errors="replace") if path.exists() else ""
        if needle in text:
            return
        if proc.poll() is not None:
            raise RuntimeError(f"runner exited {proc.returncode} before {needle}")
        time.sleep(.05)
    raise TimeoutError(needle)

def app_only(source, destination):
    rows = []
    for node in ET.parse(source).getroot().iter():
        if node.attrib.get("package") == "com.kylebrowning.landmarks":
            rows.append(dict(sorted(node.attrib.items())))
    if not rows:
        raise RuntimeError(f"no application nodes in {source}")
    destination.write_text(json.dumps(rows, indent=2) + "\n")
    return len(rows)

summary = []
for form in forms:
    out = mode_root / f"l51-{form}-final"
    out.mkdir(parents=True, exist_ok=False)
    stdout = (mode_root / f"l51-{form}-final.out").open("w")
    stderr = (mode_root / f"l51-{form}-final.err").open("w")
    command = [
        str(runner), "--platform", "android", "--device", serial,
        "--driver", "uiautomator2", "--verbose", "--no-app-install",
        "--artifacts", "always", "test", "--output", str(out), "--flatten",
        str(root / "inputs" / f"l51-{form}.yaml"),
    ]
    proc = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=env)
    try:
        log = out / "maestro-runner.log"
        wait_log(log, "Step 2 completed successfully", proc)
        before = out / "source-before"
        subprocess.run([sys.executable, "-I", str(source_reader), serial,
                        str(out / "client.log"), str(before)], env=env, check=True)
        wait_log(log, "Step 6 completed successfully", proc)
        after = out / "source-after"
        subprocess.run([sys.executable, "-I", str(source_reader), serial,
                        str(out / "client.log"), str(after)], env=env, check=True)
        rc = proc.wait(timeout=30)
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
        stdout.close()
        stderr.close()
    (mode_root / f"l51-{form}-final.exit").write_text(f"{rc}\n")
    report = json.loads((out / "report.json").read_text())
    before_count = app_only(before / "hierarchy.xml", out / "app-only-before.json")
    after_count = app_only(after / "hierarchy.xml", out / "app-only-after.json")
    before_text = (before / "hierarchy.xml").read_text()
    after_text = (after / "hierarchy.xml").read_text()
    row = {
        "form": form,
        "exit": rc,
        "status": report.get("status"),
        "beforeAppNodes": before_count,
        "afterAppNodes": after_count,
        "beforeHasGoldenGate": "Golden Gate Bridge" in before_text,
        "afterHasMonoLake": "Mono Lake" in after_text,
        "hierarchyChanged": before_text != after_text,
        "command": command,
    }
    summary.append(row)
    if rc != 0 or row["status"] != "passed" or not all((
        row["beforeHasGoldenGate"], row["afterHasMonoLake"], row["hierarchyChanged"]
    )):
        raise RuntimeError(row)

(mode_root / "l51-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
