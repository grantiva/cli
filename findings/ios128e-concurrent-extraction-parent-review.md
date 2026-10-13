# iOS B-C01.2 parent review

PASS. Attempt128e waits for streamed launchApp completion in stderr while the parent and its exact descendant runner remain alive. Active lease JSON records parent42479 and runner42611 before and after extraction; the inode is unchanged. `runner install --json` reports extracted:true in the isolated cloned QA home. Preserved-before/after SHA256 inventories are identical for the static lock marker, home/version reports, and both xcconfigs. Binary/version exist after replacement and drivers remain. Both processes are captured alive on either side of extraction and stock11-slow completes0. Exact candidate RunnerManagerTests retains the staging/preserved-directory assertions.

Attempts128c/d did not trigger extraction because they polled the wrong stream/schema; they are excluded as invalid fixtures. Attempt128b supplies only partial evidence. Attempt128e independently closes the concurrency criterion.

Evidence: cov3-ios/findings/evidence/cov3-ios-attempt128e/.
