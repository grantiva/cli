# CLI-014 candidate5 clause assessment

Verdict: **PASS**.

Expected: No ANSI escapes in redirected stdout; `NO_COLOR` suppresses colour (README:373-376)

Clause checks: [True, True, True]. Evidence commands: `CLI-014/no-color-tty.command.json`, `CLI-014/redirected.command.json`.
