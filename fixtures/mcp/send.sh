#!/bin/bash
# Usage: send.sh <project-dir> <platform|-> [request.jsonl]
# Pipes newline-delimited JSON-RPC (initialize + initialized + the given requests) to
# `grantiva mcp`, waits for responses, then closes stdin. Prints stdout; stderr goes to $MCP_STDERR (default /dev/stderr).
G=${GRANTIVA:-$HOME/.grantiva-qa/bin/grantiva}
dir=$1; plat=$2; reqs=${3:-/dev/null}
args=(mcp --project-dir "$dir"); [ "$plat" != "-" ] && args+=(--platform "$plat")
{
  echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  cat "$reqs"
  sleep "${MCP_WAIT:-3}"
} | timeout "${MCP_TIMEOUT:-30}" "$G" "${args[@]}" 2>"${MCP_STDERR:-/dev/stderr}"
echo "exit=$?" >&2
