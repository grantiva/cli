# Candidate 5 freeze provenance review

Decision: **APPROVED for frozen provenance only.** The immutable manifest `findings/evidence/completion-candidate5/candidate.json` is read-only and independently hashes to `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`, matching `candidate.sha256`. This review does not approve early live acceptance, Task 8 smoke, or complete coverage; those gates remain pending.

## Source and integration binding

The clean CLI release worktree is at merged SHA `dd5d3336296a41014a45070cc5a8c4295a0873ec`, tree `858d699c6edcf817e36893327ce07c2489dfb182`. `fix6-L87-package/merge-acceptance.json` binds that tree to reviewed package commit `5de5f36bd7132d981676830716ec1d946d5477e1`, merged PR 217, and successful required CI run `38496369854`. Its delta from functional baseline `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226` is exactly the two runner archives, `RunnerManager.swift`, and its two-constant packaging expectation in `RunnerManagerTests.swift`.

The clean runner release worktree is at squash merge `d98b08898f45b94bad607f76e19089bb0e15d5c0`. Its tree `060236c478bceba52bb7e54081dd06a44d6aa299` equals independently reviewed and tested source `9c18b962a0d85bcbb76fb8141fdd4aae97d28389`. `fix6-L87-source/merge-acceptance.json` records merged PR 28 and successful CI run `38494276359` for Lint, Test, and Build. The manifest-bound focused, full Go, and vet files all retain their stated hashes and passing exits; I did not rerun them.

## Build, package, and installation identity

`release-build/result.json` records the single release build from the clean merged CLI worktree, with fresh scratch/build homes, API key unset, and exit 0. `cli-source-before.json` and `cli-source-after.json` retain the same clean merged head. The resulting QA binary is SHA-256 `b0e9eb55baab8bcb15727de658be0c28c9205b4c83b6013e3532996f5ae6843d`; its promoted bundle files rehash exactly to the manifest, including arm64 archive `9b202199…`, amd64 archive `cb8cf912…`, and unchanged Android drivers `59cbbf57…`.

The extracted arm64 native runner and installed runner are byte-identical at SHA-256 `26b155ca9cca9b1bb7bbb77dcf7c54943afc8f4212fa7660cb6fb7adb46f62ab`. Both report `1.1.28-grantiva.16`, commit `d98b088`, and the install stamp is `1.1.28-grantiva.16+android-drivers-2`. `upgrade/acceptance.json` passes packaged/installed equality and records 8,069 preserved cache entries.

## Clone, WDA, and demo preservation

The owner runner-home clone was taken read-only before upgrade. `clone-equivalence.json` reports 8,593 identical entries, and `source-before-upgrade.json` is byte-identical to `clone-before-upgrade.json` at SHA-256 `f3715483…`. The accepted L87 package review and archive proof bind both architecture archives to unchanged WDA cache/config manifests and empty forbidden-file inventories.

The demo remains clean at source SHA `84af7581b75134b0e417b254e4317d565f7b73c6`. Every referenced retained iOS/Android build-proof file rehashes to its manifest value, as do the frozen APK (`5891bf37…`) and all five frozen iOS app files. All 39 manifest file references were checked: 30 direct paths and nine bundle/app-relative entries resolve and match after applying their declared parent paths.

No provenance discrepancy was found. Candidate 5 is suitable to enter its separately controlled live and coverage gates.
