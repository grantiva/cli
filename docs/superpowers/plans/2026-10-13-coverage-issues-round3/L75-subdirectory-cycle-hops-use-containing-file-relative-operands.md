# Subdirectory cycle output uses containing-file-relative operands

Severity: contract
Component: CLI runner-output path rewriting
Rows: B3-L20 [ios] (platform-independent source path)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; runner fd9d8e8d1cb109eda6116f4221da10257b9838e3.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

For a project-root invocation whose cycle is `flows/a.yaml` → `../shared/b.yaml` → `../flows/a.yaml`, every cycle hop is rendered relative to the project working directory:

`flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`

B3-L20 and the accepted L20 brief explicitly require project-directory-relative hops. Absolute paths remain absolute only when the user supplied an absolute path.

## Actual

The cycle is found in 2.02 seconds and exits 1, but stderr prints:

`flows/a.yaml -> ../shared/b.yaml -> ../flows/a.yaml -> ../shared/b.yaml`

Root-directory and screens-cycle controls render correctly. The defect is limited to reachable subflows whose written operands contain parent-directory components.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt79/inputs/flows/a.yaml` and `inputs/shared/b.yaml` preserve the exact fixture.
- `subdirectory-cycle.command.json`, `.exit.txt`, and `.err` preserve the invocation and result.
- `summary.json` and `all-files.sha256` preserve timings and the immutable artifact set.
- Root/screens controls in the same directory show correct rendering.
- Independent source/evidence review: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/ios79-android-l10-n207-review.md`.

## Cause

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/FlowReferenceResolver.swift:147-166` computes the correct canonical absolute → project-relative reachable map.

`/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/RunnerSession.swift:420-473` also collects `subFlowPathMap`, whose values are operands exactly as written relative to their containing file. It merges that map after the reachable map with `{ _, written in written }`. For duplicate canonical targets, `../shared/b.yaml` and `../flows/a.yaml` overwrite `shared/b.yaml` and `flows/a.yaml`. `OutputRewriter` faithfully applies the wrong winning values.

The existing reachable-map source test verifies the correct map before this merge and therefore does not cover the failing integration.

## Acceptance criteria

- The exact subdirectory fixture prints `flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`, exits 1, and completes within five seconds.
- Preserve root-flow `a.yaml -> b.yaml -> a.yaml -> b.yaml` and screens `grantiva.yml -> a.yaml -> b.yaml -> a.yaml` output.
- Preserve user-supplied absolute paths as absolute where the contract requires them.
- Add a focused `RunnerSessionOutputTests` assertion that exercises the final merged output map for nested `../` operands, rather than testing `reachableFlowDisplayMap` alone.
- Verify both `/tmp` and `/private/tmp` source spellings still rewrite correctly.
