# Candidate 5 CLI direct batch 03 review

**Scope:** independent read-only review of flattened direct ordinals 51–75 against canonical entries in `direct-row-batches.json`, the raw command/stream/identity evidence, assessments, and cumulative ledger. No command was rerun.

**Spec verdict: APPROVED AS RECORDED — 21 PASS and 4 PENDING. Quality verdict: APPROVED.** The keys match canonical flattened positions 51–75 exactly. The four pending rows are `CLI-166`, `CLI-167`, `CLI-168`, and `CLI-169`; none has a product invocation, and this review does not promote them. Cumulative state through ordinal 75 is 71 PASS and 4 PENDING.

Control hashes:

- `direct-row-batches.json`: `5c94137ef743aec7a2f946e525a9efdc02815193116260d855864146a8d65a98`
- `batch-03-verdict.json`: `e4827eb560d03321e2d5b5d7654ba7580f36f5bcbbb001328f939350c622d281`
- cumulative `results-ledger.json`: `3993051f3ae97cf90c939f9752591c30f94db7579384dce6dfc6197eb6dd2617`

## Findings

- The 20 passing rows from `CLI-047` through `CLI-165` retain 31 exact candidate5 commands covering invalid swipe parsing; all `--env` key errors; ready-file directory, stale, failed, and unwritable cases; enum/numeric usage errors; timeout-minimum and ready-file behavior; teardown target validation; platform-specific flags; missing flows; and the six-command other-platform family. Their observed errors occur at the parser/config/target-validation boundary required by the matrix, before compiler or live-device work.
- Each of those captures uses the frozen candidate5 identity, `candidate5-cli`, equal explicit runner homes, and an unset API key. No identity mismatch was found.
- `CLI-166`–`CLI-169` remain PENDING exactly as proposed. Their assessment files state that the required CI/build or application-facing commands were withheld pending an explicit compiler/live window. There is no runtime evidence to support PASS, and no older candidate result is transferred.
- `CLI-170` is supported by one bounded wrapper invocation over the exact accepted 172-page candidate5 help corpus. It exits 0 and records `rc=0 value=2.1.0` for every root/subcommand/leaf page, ending `total=172 passed=172`. The wrapper SHA is `b2d6c1f9b1ffaf885bbb508332fc9f1b5ee3fb2a5ccd1633ddf9d505309b57c9`; its assessment SHA is `d12d98ae129bfa76b22209edcc756b83f665da82299e0ce66d1eb680a545b2bd`. This satisfies the single inherited-flag row without duplicating 172 independent collector records.

## Gaps

The batch has four explicit unresolved obligations: `CLI-166` must prove unauthenticated `ci run --json` channel/exit behavior; `CLI-167` must prove all four Android CI flag refusals and unchanged ADB state; `CLI-168` must prove both iOS flags reach authentication without a build; and `CLI-169` must prove both Android-only run flags are rejected on iOS before build. They require the controller's designated build/live-safe window. No other material gap was found in ordinals 51–75.
