# Task 2 final source and live acceptance review

Verdict: APPROVED for L86 source/full-suite and bounded live acceptance. No actionable evidence gap found in this scope. Required CI run 38482057908 remains pending per controller status; this review makes no integration, release-candidate or complete-campaign claim.

Read-only review of `findings/evidence/fix5-L86-source`, original retained source patches, and `findings/evidence/fix5-L86-live`. No test, build, device, process-control or network commands were executed.

## Source and full suite

Commit `77aa2a63064afc3a68d9ea71232f46e1937ba2ff` contains exactly the tested Sources/Tests patch over base `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`: independently compared git's commit diff byte-for-byte with the retained full-run source.patch.gz after decompression. SHA-256 is `007c7ff6b5bf28a51a2eb1898a7d18032964ab60252380356b3ad92374dfe9c6`. Current fix-worktree Sources/Tests also match that commit. This completes the identity link to the prior source review; the run began on the base with this uncommitted patch, then the identical change was committed.

The single retained full invocation is literal `swift test`, exit 0, 201.1229 seconds. Independently verified decompressed stdout/stderr hashes against result.json and counted 2,027 passing XCTest case records. The separate test-bundle summaries report zero failures; no nonexistent single 2,027-test summary is inferred. Both fresh runner-home paths remained absent and API-key-unset metadata is retained. The original deterministic red and intermediate compilation failure remain preserved; neither is overwritten by this pass.

## Live provenance and results

The executed collector asserts the exact commit and no Sources/Tests delta before running. It records the local debug binary `/Users/kyle/Developer/grantiva-cli/.worktrees/fix5-twin-ownership/.build/debug/grantiva`, SHA-256 `3b80a6e791d1065bb07423b2c6d3b804403cd30893303a4f4647223062868ab5`, and checks it again before acceptance. A read-only hash check during review matches. The tested source and local build output form the acceptance provenance; this is not a packaged/released candidate certification. Per-command starts identify the literal binary, private working directory, same isolated home for both runner variables, session fix5-L86-live and unset API key.

All 40 retained commands exit 0 with timedOut:false. Each of five distinct generations is first created with --no-boot, then receives two overlapping ensure processes launched through the two-worker executor. Their recorded intervals overlap; both raw JSON outputs identify the same generation UUID and Booted state. Every captured session ledger contains one active, durable, true-boot-ownership record for that UUID/session. Each exact-UUID teardown reports deleted:true with the retained true ownership, and the following independent inventory omits that UUID.

The manual-origin control is separately created and booted through root simctl. Grantiva ensure reports the same Booted UUID; Grantiva teardown returns an empty array, and the next simctl inventory still shows that control Booted. Only the later explicit root-owned cleanup shuts it down and deletes it. Final inventory omits all six allocated UUIDs. Independent comparison of before/final runtime, UUID, name, state and device-type maps is identical, including both protected Booted devices.

## Interpretation and remaining gates

These live captures demonstrate concurrent successful reuse, true ownership retained after both processes finish, effective owned teardown, manual-origin protection and completed cleanup for five sampled schedules. They do not instrument internal simctl boot-command count or force the exact stale-snapshot interleaving; the deterministic regression supplies those ordering/single-boot assertions. The live collector's timeout branch was not exercised, and this approval is for completed evidence rather than general-purpose collector safety certification.

Bindings: live acceptance.json SHA-256 `6e2a6e1689dd1a3a9c0d448720df716e702e8e77de45d241dbece578de205faa`; provenance.json `83213e9f5ed782446e9d9f3c402e14714245740976c193325ea0fb77ec14902b`; executed run.py `78a6ad7ea84fda7cd5513a2b0330264980957051887b30a61753443a1773b478`.

CI must complete successfully before integration under the plan. A replacement frozen candidate and fresh campaign coverage remain separate requirements. Candidate3's failed Swift result and incomplete coverage are unchanged historical evidence.
