#!/bin/sh
set -eu

changelog=${1:-CHANGELOG.md}

test -f "$changelog" || exit 0

if awk '
  /^## Unreleased[[:space:]]*$/ { in_unreleased = 1; next }
  in_unreleased && /^## [^#]/ { in_unreleased = 0 }
  in_unreleased && /^[[:space:]]*$/ { next }
  in_unreleased && /^###[#]*[[:space:]]/ { next }
  in_unreleased { has_entries = 1 }
  END { exit has_entries }
' "$changelog"; then
  exit 0
fi

echo "CHANGELOG.md has unreleased entries; move them under the release version before tagging." >&2
exit 1
