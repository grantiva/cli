# iOS65b/67b review and L71 draft check

## Attempt65b

The installed-app control is valid and sharpens, rather than resolves, D2-08's failure. Before and after probes both exit 0 and identify the same installed Landmarks container. The exact `build install --no-build --no-launch` command exits 0, prints the expected `Done ... (install skipped, not launched)` line, and retains the container. Joined with attempt65's proven-absent exit-1 case, this isolates the defect to the unconditional absent data-container lookup.

D2-08 should remain **fail** with both captures cited. Attempt65b does not by itself grade D2-07, whose row separately requires launched, installed, and skipped JSON documents on each platform.

One ledger citation needs correction: the current D2-08 line names `Sources/GrantivaCLI/Commands/BuildCommand.swift`, but the exact candidate file is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/BuildCommand.swift`.

## Attempt67b / D2-05 [ios]

The pass is supported. The Maestro-format `grantiva.yml` uses `appId`, a scalar `runFlow: sub-shot.yaml`, ordinary `scroll: DOWN`, `scrollUntilVisible` with direction/timeout/speed/centerElement, `extendedWaitUntil` with a 5000 ms timeout, and a main screenshot. The subflow contains `takeScreenshot: FromSub`.

The live capture exits 0, retains both `FromSub.png` and `Main.png`, and its output preserves the distinct subflow and main screen step lists. Runner narration explicitly retains scroll-until-visible and the 5000 ms extended wait. Joining current attempt59 mapping/inline fixtures and exact-head `FlowStagingTests.swift` supplies the other `{file:}` and inline `{commands:}` runFlow forms. This covers every D2-05 iOS clause without treating test names alone as runtime evidence.

## L71 draft

`L71-no-build-no-launch-queries-absent-ios-container.md` accurately separates D2-08's no-app-file control from its successful app-file legs, cites D2-07's intended `skipped` status, contrasts absent attempt65 with installed attempt65b, and identifies the unconditional candidate `BuildCommand.swift:191` data-container call. Its acceptance criteria preserve installed/app-file/ordinary-launch behavior and request a focused absent-app source test. The brief is ready for independent review.

