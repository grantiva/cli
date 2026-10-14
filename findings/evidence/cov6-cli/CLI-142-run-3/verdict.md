# CLI-142 corrected candidate5 clause assessment

Verdict: **PASS**.

The two earlier attempts remain preserved and excluded. Before execution, `fixture-before.json` authenticates the copied binary as the frozen candidate5 CLI and records every file/hash from the intentionally older `.15` adjacent bundle plus the isolated installed-home tree. `install-mismatch.command.json` retains exact argv/cwd/env/times/exit/raw. The command refuses replacement with a warning naming `.15`, installed `.16`, and the adjacent resource bundle; `home-after.json` proves every installed-home file/symlink unchanged. As in the accepted prior-release behavior, refusal is represented by warning plus no install mutation and exit 0.
