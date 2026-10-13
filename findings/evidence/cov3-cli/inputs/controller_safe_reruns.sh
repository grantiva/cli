#!/bin/bash
# Controller-executable bounded reruns for B3-L17 and N3-11 only.
# Preconditions: run from the cov3-cli worktree with full host read access.
# Safety: no boot/ensure/teardown/delete/build/test command; cov-missing must not exist.
set -u
source "$(dirname "$0")/lib3.sh"

# Read-only guard: the fake name must not resolve to any simulator.
if xcrun simctl list devices --json | jq -e '.. | objects | select(.name? == "cov-missing")' >/dev/null; then
  echo 'blocked: a simulator named cov-missing exists' >&2
  exit 2
fi

# B3-L17: genuine --project-dir contrasts and a genuine cwd/default invocation.
base=$(ios_copy B3-L17-fullaccess-base)
empty=$(fd B3-L17-fullaccess-empty)
row=B3-L17-fullaccess
mkdir -p "$E/$row"
cat > "$E/$row/requests.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}}}
]
JSON
run_client() {
  label=$1 cwd=$2; shift 2
  out="$E/$row/$label"
  mkdir -p "$out"
  { echo "# cwd: $cwd"; printf '$ python3 %q %q %q %q --' "$T/client.py" "$E/$row/requests.json" "$out" "$cwd"; printf ' %q' "$@"; echo; } >> "$E/$row/commands.txt"
  python3 "$T/client.py" "$E/$row/requests.json" "$out" "$cwd" -- "$@"
  rc=$?
  echo "# exit=$rc -> $label/{transcript.txt,stdout.raw,server.stderr}" >> "$E/$row/commands.txt"
  return "$rc"
}
run_client project_auto "$base" "$GRANTIVA" mcp --project-dir "$empty"
run_client project_ios "$base" "$GRANTIVA" mcp --project-dir "$empty" --platform ios
run_client cwd_auto "$empty" "$GRANTIVA" mcp

# N3-11: use only a scratch runner home and a nonexistent simulator name.
row=N3-11-fullaccess
d=$(fd "$row")
mkdir -p "$d/bin" "$E/$row"
cp "$GRANTIVA" "$d/bin/grantiva"
(cd "$d" && ev "$row" install_current "GRANTIVA_RUNNER_HOME=$d/home $GRANTIVA runner install")
(cd "$d" && ev "$row" fake_start "GRANTIVA_RUNNER_HOME=$d/home ./bin/grantiva runner start --bundle-id com.example.app --simulator cov-missing --verbose")
grep -c '^Warning: The grantiva_GrantivaCore.bundle resource bundle was not found' "$E/$row/fake_start.err" > "$E/$row/warning-count.txt" || true
echo '# warning-count.txt counts exact missing-bundle warning lines in fake_start.err' >> "$E/$row/commands.txt"
