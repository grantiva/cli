# Task 9 source-window controller fix2 re-review

**Specification compliance: APPROVED for future gated execution. Code quality: APPROVED within the reviewed preparation scope.** Both residual P2 findings are resolved; no new breakage was found in these changes.

This is static approval of prepared controller code, not approval of a Task 9 gate or live result. Task 9 remains subject to the independently reviewed zero gate and the controller's candidate, provision, shutdown and other required inputs. No test, build, Go inventory, network, device or helper execution was performed in this review.

Verified hashes:

- Helper: `0c1e3966dd9eab5fd7086c19e9d47092bc303fef57b5040ff7ba89b9d103bafb`
- Fixtures: `04dbf5c982908ea396de017345b9c36ec74a4add10c5452af32eb1d8fc370022`
- Fix2 diff: `e8a3d8feb9d9adf6fe146e4378af8d8e94cd1c57a3ffb09779a87817a55427ea`

## Residual findings resolved

**Home root classification.** `path_entries` now uses `lexists` to distinguish absence, checks symlink roots before directory traversal, and records the root kind. Postflight rejects every present Swift home root that is not a real directory and rejects any entries in a real directory. A regular file, dangling symlink, or symlink to a directory can no longer be mistaken for an empty home. The condition remains specific to the two Swift home variables, preserving expected Go cache population.

**Durable tracked-file drift observations.** `observe_repo` now returns structured issues for missing, invalid and unreadable tracked entries while retaining HEAD, status, tracked-entry count and a digest containing failure sentinels. `proof_failures` rejects those issues. The existing postflight and terminal-failure writes therefore receive the observation rather than losing it to the former per-file assertion. Final observation uses the same behavior, retains the first failure and writes `CLOSED_NONPASS_UNREVIEWED` without repair, rerun or overwrite. Clean readable tracked entries retain their prior hashing behavior; the added empty issues field is produced consistently by inventory and execution proofs.

## Validation and scope

The fix2 report and diff, changed helper/fixture paths, and terminal manifest flow were inspected. The reported 12 fake fixture passes were not rerun. The updated actual-controller fake fixture deletes a tracked file and checks the resulting durable observation, failure record and closed manifest; the added bounded fake cases cover regular-file and dangling-symlink home roots.

The four findings resolved in fix1 remain resolved, including consumption of the approved provision helper's actual inline ownership and launch metadata shape. Inventory pinning, literal argv, separate Go inventory/review/execute stages, exclusive evidence creation, source identity checks, API-key removal, AND-111 external-only handling and non-verdict row mappings are unchanged. No product or helper code was modified by this review; only this review document was added.
