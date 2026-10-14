# B-I14.2 candidate5 clause assessment

Verdict: **PASS**.

Expected: Prefer reserving capacity before `simctl create`, or wrap the boot in a do/catch that deletes a device with `created == true`. (brief I14)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-I14.2-run-1/source-inspection.command.json`.
