# CLI-170 candidate5 clause assessment

Verdict: **PASS**.

Expected: Prints `2.1.0`, exit 0, for every one; one row because the flag is inherited from the root command and behaves identically everywhere (help: every page lists `--version`)

Fresh candidate5 commands retained exact argv/cwd/identity/raw/exit. Clause review confirms the observed parser or validation boundary matches the expected requirement and occurred before compiler or live-device work. Evidence: `CLI-170-run-1/all.command.json`.
