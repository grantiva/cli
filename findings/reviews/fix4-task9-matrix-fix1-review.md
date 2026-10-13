# Task 9 matrix fix 1 independent review

## Verdicts

- **Spec: PASS.** All four findings from `task-9-matrix-review.md` are addressed. The revised artifact remains a scratch preparation matrix gated on Task 8 green smoke; it does not claim coverage execution or authorize canonical publication.
- **Quality: PASS.** The new controls are specific, indexed, platform-owned, and leave results empty. No new breakage was identified in the scoped diff.

## Finding closure

1. **iOS startup/readiness coverage — resolved.** `B4-PC.4` through `.8` separately pin exact owned WDA death including the after-port schedule, the completed same-PID launch-report gate, failed/incomplete/missing-report behavior, foreground and detached real failed-launch cleanup, and healthy ready/interruption/explicit-stop siblings. The original failed attempt is retained only as provenance. These rows cite the accepted Task 4 fix 5/6 review and report rather than inventing a pass.
2. **Task 2 deadline/cancellation coverage — resolved with approval correctly pending.** `B4-PC.9` through `.13` add bounded/cancellable force-stop/process/foreground shell transport, owned child termination/reaping, delayed second-Rect cancellation with no late tap, successful-read siblings, ordinary soft-deadline behavior, keyboard step-context cancellation, and the long-press/action-budget sibling. Every row explicitly says final Task 2 fix 2 source approval/evidence remains pending. No result or preparation text promotes that work to accepted evidence.
3. **Device evidence ownership — resolved.** `B4-EJ.1` delegates L53.P5's device clauses to indexed iOS L71 rows and both platform halves of `B3-L20`, while keeping empty-target/source validation device-free. `B4-EJ.2` requires separate current-candidate iOS and Android session JSON. `B4-EJ.3` joins production command behavior to both `B3-L20` halves. None permits one platform's capture to satisfy the other or permits the CLI slice to boot a device.
4. **Absolute-path/stream-boundary proof — resolved.** `B4-EJ.3` requires the exact supplied `/private/tmp/<project>/a.yaml` spelling, separately written relative operands, every stream split, non-cascading inserted targets, overlaps, longer prefixes, Unicode, the existing root/screens/subdirectory chains, and both aliases.

## Preservation and count review

- The scoped diff appends 13 controls and changes only count/index/report metadata around them; quoted source criteria are not edited.
- The recorded inherited-row extraction SHA-256 remains `3b8d951d26700c06a727893ad2c7669902f331be217a87a17ba0c1548df5b848`. The report continues to claim 1,170 inherited logical rows and 107/107 indexed source criteria.
- Counts are arithmetically coherent: 1,170 inherited + 123 B4 = 1,293 logical rows. Shared-row expansion gives 419 CLI + 531 iOS + 518 Android = 1,468 results. The B4 delta is 35 CLI + 53 iOS + 51 Android = 139 expanded results.
- Candidate version, source SHAs, executable/bundle hashes, demo SHA, WDA manifest, and release-home manifest remain `UNKNOWN`; all logical result cells remain empty according to the retained structural check.
- Runtime mapping remains iOS 26.0/27.0 for coverage, with 26.2/26.4 confined to Task 7/8 packaging. Protected-device, no-default-home, no-global-teardown, unset-key, and Task 8 smoke-gate constraints remain present.

## Boundary

This review accepted the retained structural checks and did not rerun them. It performed no tests, builds, device operations, coverage execution, product edits, or canonical publication. Task 2 fix 2 source approval remains an explicit prerequisite for accepting the corresponding source evidence, and Task 8 green smoke remains the prerequisite for all Task 9 coverage execution.
