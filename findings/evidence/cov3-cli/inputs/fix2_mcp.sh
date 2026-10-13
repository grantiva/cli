#!/bin/bash
set +e
source "$(dirname "$0")/lib3.sh"
runone() {
  row=$1 tool=$2; d=$(fd "$row-fix2")
  call 101 "$tool" '{}' | mcpq "$row-fix2" ios "$d" ios
  call 201 "$tool" '{}' | mcpq "$row-fix2" android "$d" android
}
runone MCP-004 grantiva_screenshot
runone MCP-008 grantiva_tap
runone MCP-012 grantiva_swipe
runone MCP-016 grantiva_type
runone MCP-020 grantiva_a11y_tree
runone MCP-024 grantiva_a11y_check
runone MCP-028 grantiva_script
d=$(fd MCP-077-fix2)
reqs() { call "$1" grantiva_nope '{}'; call "$2" grantiva_sim_ensure '{}'; call "$3" grantiva_emulator_ensure '{}'; call "$4" grantiva_type '{}'; call "$5" grantiva_swipe '{}'; call "$6" grantiva_script '{}'; }
reqs 301 302 303 304 305 306 | mcpq MCP-077-fix2 ios "$d" ios
reqs 401 402 403 404 405 406 | mcpq MCP-077-fix2 android "$d" android
