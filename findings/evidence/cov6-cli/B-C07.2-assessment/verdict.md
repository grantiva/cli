# B-C07.2 candidate5 clause assessment

Verdict: **PASS**.

Expected: Decide one behavior for unsupported commands (skip with a stderr warning naming command and line, or reject) and make README.md:149 say exactly that; also list `doubleTapOn`, `longPressOn`, `scrollUntilVisible`, `launchApp`, `stopApp`, `killApp`, which the parser accepts. (brief C07)

Fresh candidate5 negative public, docs, MCP, or exact-current-source evidence satisfies this clause without compiler/live action. Evidence: `B-C07.2-run-1/docs.command.json`.
