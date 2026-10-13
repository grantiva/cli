# Android B3-L40 comparator review

The round-2 and round-3 Landmarks-list fixtures are materially comparable. The old MCP tree at `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/cov2-android/MCP-S1/mcp-03/tree_landmarks.json` and current hierarchy at `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/hierarchy-resource-ready-rerun1/hierarchy.json` each contain 77 nodes, 76 frames, and 10 clickable nodes. They share the 411-wide viewport, status-bar/system hierarchy, application labels including `Featured`, and the same sole undersized clickable `android.view.View` at x=0, y=745, width=411, height=41. Apart from the intended frame type change (numeric strings to JSON integers), the relevant layout is the same; the clock differs only AM/PM.

The numeric-frame half is fully supported by `N3-07-B3L40-hierarchy-frame-audit-current/audit.txt`: CLI hierarchy, runner dump, and MCP tree decode identically, with 76 frames and all 304 members numeric integers.

The fresh controlled comparison at `B3-L40-same-screen-stability-rerun1/` resolves the earlier state mismatch. On one MCP server, with no UI calls between them, tree-before and tree-after are byte-identical and have identical frame/clickable vectors. The intervening check returns exactly one `small_tap_target` result: the same `android.view.View`, `411x41` size, and message as the historical round-2 comparator. The earlier `411x13` plus `missing_label` capture came from a non-equivalent transient state and is retained as diagnostic evidence only.

Verdict: B3-L40 **passes**. Numeric frames are complete across all three outputs, and the controlled same-screen accessibility result is unchanged in full, not merely in identity/count.
