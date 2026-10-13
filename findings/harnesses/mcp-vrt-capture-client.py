#!/usr/bin/env python3
"""Make one MCP VRT capture call and preserve the exact JSON-RPC exchange."""

import json
import pathlib
import subprocess
import sys


out = pathlib.Path(sys.argv[1])
project = pathlib.Path(sys.argv[2])
grantiva = sys.argv[3]
out.mkdir(parents=True, exist_ok=False)

requests = [
    {
        "jsonrpc": "2.0",
        "id": "init-l44-n12",
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "round3-l44-n12", "version": "1"},
        },
    },
    {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
    {
        "jsonrpc": "2.0",
        "id": "capture-l44-n12",
        "method": "tools/call",
        "params": {"name": "grantiva_vrt_capture", "arguments": {}},
    },
]
stdin = "\n".join(json.dumps(item, separators=(",", ":")) for item in requests) + "\n"
(out / "stdin.raw").write_text(stdin)
result = subprocess.run(
    [grantiva, "mcp", "--project-dir", str(project), "--platform", "android"],
    cwd=project,
    input=stdin,
    text=True,
    capture_output=True,
    check=False,
)
(out / "stdout.raw").write_text(result.stdout)
(out / "stderr.raw").write_text(result.stderr)
(out / "server.exit").write_text(f"{result.returncode}\n")

documents = []
for line in result.stdout.splitlines():
    try:
        documents.append(json.loads(line))
    except json.JSONDecodeError:
        continue
(out / "responses.json").write_text(json.dumps(documents, indent=2) + "\n")
capture = next((item for item in documents if item.get("id") == "capture-l44-n12"), None)
if result.returncode != 0 or not capture or "result" not in capture:
    raise SystemExit(1)
content = capture["result"].get("content", [])
text = next((item.get("text") for item in content if item.get("type") == "text"), None)
if not text:
    raise SystemExit(2)
decoded = json.loads(text)
(out / "capture.json").write_text(json.dumps(decoded, indent=2) + "\n")
if len(decoded.get("screens", [])) != 5:
    raise SystemExit(3)
