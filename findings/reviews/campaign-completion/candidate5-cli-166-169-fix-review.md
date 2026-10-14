# Candidate 5 CLI-166–169 correction review

## Verdict

- **Spec: APPROVED**
- **Evidence quality: APPROVED**
- **CLI-166, CLI-167, CLI-168, CLI-169: PASS**

The fresh third captures execute the literal negative paths with the API key unset in the intended fixtures. Every product invocation exits 1 without timeout and has empty stdout.

- `CLI-166` emits the exact unauthenticated error for `ci run --json`.
- All four `CLI-167` Android variants refuse before build or boot with the documented local-baselines message. This includes `--derived-data-path`; the retained result records the platform refusal actually returned.
- Both `CLI-168` iOS variants accept and resolve their flags, then emit the exact unauthenticated error.
- Both `CLI-169` invocations reject the named flag as Android-only in the resolved iOS project.

The shared ADB inventory before `CLI-166` and after `CLI-169` is byte-identical, SHA-256 `36f15c2fe32964a6fbe902e914a47739d4e6304b0d3e812bf08096ff0419b7ae`. This supports the required no-boot/no-live-target boundary alongside the early validation messages. Each product capture carries the candidate 5 identity record SHA-256 `eab8f2b9c63ee0526e92f967e5c9b3e4e116df607069bedf0e4d00635f92e047`.

Corrected verdict hashes are `7b60e45acc992ac2ee7fde95a998eef36ec1da4535bbea4df1da7a4878ddfb92`, `c6206a9a44f8884b6308ba8ff1e75bf7412691f3e8e7d12e376b8ff5453033f1`, `5e9d5cb5fb1aa11ea4213a3f97931124c934a93afef4fa8ebfc427100f9d06da`, and `517daeb75d5adebe0d90c6b645696fd7723fb2550cd9924e06f64da8de5857c1` in key order. Earlier pending assessments and the two scheduling attempts remain preserved and excluded from the final grades.
