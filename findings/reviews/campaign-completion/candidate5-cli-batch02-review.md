# Candidate 5 CLI direct batch 02 review

**Scope:** independent read-only review of flattened direct ordinals 26–50 against the corresponding entries in `direct-row-batches.json`, cumulative `results-ledger.json`, raw command/stream/identity evidence, and corrected assessments. No command was rerun.

**Spec verdict: APPROVED — batch 25 PASS, 0 FAIL, 0 N/A, 0 pending; cumulative 50 PASS. Quality verdict: APPROVED.** The ledger keys match canonical flattened positions 26–50 exactly. Forty-two retained commands across these rows bind the candidate5 manifest `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; every identity record reports all frozen artifacts matched. The commands use session `candidate5-cli`, the explicit candidate5 CLI runner home for both runner-home variables, and an unset API key.

Control hashes:

- `direct-row-batches.json`: `5c94137ef743aec7a2f946e525a9efdc02815193116260d855864146a8d65a98`
- `batch-02-verdict.json`: `b7723faecf2d3d1ebcea2610495faf89997af2763039c9a2734c25691e1e542b`
- cumulative `results-ledger.json`: `cc302ac1895a921c9c7e8d240f6441f72cc87ce89732cef196a2b84c2d2a0869`

## Clause findings

- `CLI-024`–`CLI-032`, `CLI-034`–`CLI-035`, `CLI-127`–`CLI-128`, and `CLI-036`–`CLI-045` retain their literal platform/config fixtures and command variants. Their raw outcomes support the required platform resolution, advisory/error channel, syntax location, option-family rejection, ready/report preflight, and mutual-exclusion clauses. Proven-absent simulator controls stop at resolution and do not cross into live device work.
- `CLI-033`'s first assessment is preserved at SHA `46f5d0d779d9a8b18d07713e1ea727279256b6c34215ec0d35d20aa1927aa3f0`. Its product evidence was already correct; the grader incorrectly treated an empty `find` result as a failed filename search. The corrected assessment SHA `a3fd67f2d6ed834095c05ce9a7fb878060b0a9588d0a2fd1fc556e1eeb9cb4e9` is supported by three exit-1 commands with the exact invalid `GRANTIVA_PLATFORM` diagnostic and the separately captured empty file inventory (`files.command.json` SHA `7e268a746d42432e0daac751597d1b8577dd84e5edaa075b62ecda9d6612e1ed`; empty stdout SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). No source or fixture correction was needed.
- `CLI-046` preserves the malformed first fixture and its parser rejection. That attempt put `launch` inside a screen action list and failed at `grantiva.yml:6` with an expected-value parse error; its command SHA is `e4d12dc7766479a94d60ac483883c9000a771fc98d148fa90872de11c4ce5fb3`. It is excluded from the PASS.
- The adjacent corrected `CLI-046` fixture separates the launch screen from a second action screen and includes every required tap, exact tap, five swipe spellings, type, wait, both not-visible forms, visible assertion, and subflow. The durable fixture construction is retained in `resolve-batch2-blocks.py` SHA `12fc2c0fee2d5a31748f9455ea68b9e0f3f96c2add8b358c6727aaf363d76276`. The corrected command SHA `3ceb9715410c6a9481db8674cffa53031b0a730fec57e243d9f64f97fb986d3d` reaches only the explicit proven-absent simulator resolution error, demonstrating that all action forms parsed. The final assessment SHA `c8adb55be1dbdfffcc74b4249cc9a4167bbec4717256efcdd38f9f1407c76dd5` correctly grades this corrected attempt.

## Gaps

No material clause or provenance gap remains for direct ordinals 26–50. The `CLI-033` initial FAIL is solely a grader interpretation defect. The malformed `CLI-046` fixture remains visible as a failed first attempt and is not used to support the PASS; the corrected fixture and resolution-stage result provide the required evidence.
