#!/usr/bin/env python3
"""Read one UIAutomator2 hierarchy through a narrowly owned adb forward."""
import json
import pathlib
import re
import subprocess
import sys
import time
import urllib.request


serial, client_log, out = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=False)
commands = []
owned_local = None
metadata = {"serial": serial, "createdOwnForward": False}


def run(argv):
    result = subprocess.run(argv, text=True, capture_output=True)
    commands.append({
        "argv": argv,
        "exitCode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    })
    return result


def get(url, stem):
    started = time.time_ns()
    with urllib.request.urlopen(url, timeout=20) as response:
        body = response.read()
        status = response.status
        headers = dict(response.headers.items())
    ended = time.time_ns()
    (out / f"{stem}.raw").write_bytes(body)
    (out / f"{stem}-headers.json").write_text(json.dumps(headers, indent=2) + "\n")
    return body, {"url": url, "httpStatus": status, "headers": headers,
                  "startedNs": started, "endedNs": ended,
                  "elapsedMs": (ended - started) / 1e6}


try:
    deadline = time.monotonic() + 30
    sid = None
    while time.monotonic() < deadline:
        text = client_log.read_text(errors="replace") if client_log.exists() else ""
        ids = re.findall(r"/session/([0-9A-Za-z-]+)(?:/|\b)", text)
        sid = ids[-1] if ids else None
        if sid:
            break
        time.sleep(.1)
    if not sid:
        raise SystemExit(75)
    metadata["sessionIdFromClientLog"] = sid

    prior = run(["adb", "forward", "--list"])
    (out / "prior-forward-list.txt").write_text(prior.stdout)
    if prior.returncode != 0:
        raise SystemExit(75)
    host_port = None
    for line in prior.stdout.splitlines():
        fields = line.split()
        if (len(fields) >= 3 and fields[0] == serial and fields[2] == "tcp:6790"
                and fields[1].startswith("tcp:")):
            host_port = fields[1][4:]
            break
    if host_port is None:
        created = run(["adb", "-s", serial, "forward", "tcp:0", "tcp:6790"])
        if created.returncode != 0 or not created.stdout.strip().isdigit():
            raise SystemExit(75)
        host_port = created.stdout.strip()
        owned_local = f"tcp:{host_port}"
        metadata["createdOwnForward"] = True
    metadata["hostPort"] = int(host_port)

    base = f"http://127.0.0.1:{host_port}/wd/hub"
    sessions_body, sessions_meta = get(f"{base}/sessions", "sessions-response")
    sessions_doc = json.loads(sessions_body)
    values = sessions_doc.get("value")
    returned_ids = []
    if isinstance(values, list):
        for item in values:
            if isinstance(item, dict):
                candidate = item.get("id") or item.get("sessionId")
                if isinstance(candidate, str):
                    returned_ids.append(candidate)
    metadata["sessionIdsFromEndpoint"] = returned_ids
    metadata["sessionsRequest"] = sessions_meta
    if sid not in returned_ids:
        raise SystemExit(76)

    source_url = f"{base}/session/{sid}/source"
    source_body, source_meta = get(source_url, "source-response")
    source_doc = json.loads(source_body)
    value = source_doc.get("value")
    if not isinstance(value, str) or "<hierarchy" not in value:
        raise SystemExit(76)
    (out / "hierarchy.xml").write_text(value)
    metadata["sourceRequest"] = source_meta
finally:
    if owned_local is not None:
        removed = run(["adb", "-s", serial, "forward", "--remove", owned_local])
        metadata["ownedForwardRemovalExitCode"] = removed.returncode
    after = run(["adb", "forward", "--list"])
    (out / "after-forward-list.txt").write_text(after.stdout)
    (out / "commands.json").write_text(json.dumps(commands, indent=2) + "\n")
    (out / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
