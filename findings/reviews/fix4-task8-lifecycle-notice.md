# Task 8 lifecycle interruption-notice review

Scope: `task8-lifecycle-notice-report.md`, `task8-lifecycle-notice-review.diff`, the two changed assertion sites, the binding B3-L37 platform wording, and preserved failed-attempt output. No device command or lifecycle rerun was performed.

## Verdicts

- **Specification compliance: APPROVED.** Both lifecycle interruption controls now require the exact platform-specific public notice.
- **Code quality: APPROVED.** The correction is minimal, shared by both assertion sites, and strengthens duplicate/unexpected notice detection.
- **Live acceptance: NOT ASSESSED.** The failed phase remains rejected and requires a fresh controller rerun.

## Review

The preserved output establishes a harness expectation error: both starts exited 130, iOS emitted the required `releasing simulator` notice, and Android emitted the required `releasing emulator` notice. B3-L37 defines those exact platform nouns, so the former single iOS-specific constant could only reject correct Android behavior.

`INTERRUPT_NOTICES` now maps `ios` and `android` to their exact full strings. Both the genuine-starting interruption and steady-ready interruption collect stderr lines beginning with the public SIGINT prefix and require the list to equal exactly one expected platform line. This preserves exact wording while rejecting missing, duplicate, or wrong-device-kind notices.

The surrounding requirements remain unchanged at both sites: exit 130, no substituted timeout, project-session absence, exact runner PID death, and PID-prefixed shared-session cleanup. Signal targets and bounded cleanup behavior are untouched. The durable and execution helper copies are reported byte-identical, and prior evidence remains immutable.

No new scoped defect was found.
