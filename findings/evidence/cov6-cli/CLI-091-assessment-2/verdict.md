# CLI-091 candidate5 corrected clause assessment

Verdict: **PENDING**.

Expected: `Error: Not authenticated. Run: grantiva auth login`, non-zero, stdout empty (README:47; src GrantivaError.swift)

Fresh run2 reached the host default-name ownership refusal before authentication. CLI-091 strictly requires the authentication diagnostic, so this remains pending an owned named-target prevalidation window.

Evidence: `../CLI-091-run-2/`. First pending assessment is preserved.
