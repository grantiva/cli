# Candidate 5 final broad-smoke review

**Review scope:** independent read-only review of the completed candidate 5 broad-smoke acceptances, recorded invocations, the previously approved Android and lifecycle-recorder reviews, final force teardown, final cleanup, and the root post-smoke artifact check. No command, build, device operation, or test was rerun.

**Spec verdict: APPROVED. Evidence-quality verdict: APPROVED WITH JOIN LIMITATIONS.** The required broad-smoke phases completed on frozen candidate manifest SHA `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`, and the final cleanup and postflight checks close the live-resource and artifact-integrity requirements. The limitations below restrict reuse for stronger full-coverage clauses; they do not invalidate the broad-smoke gate. This review does not claim that the canonical full-coverage campaign is complete.

## Candidate and phase binding

- Frozen CLI source is `dd5d3336296a41014a45070cc5a8c4295a0873ec`; runner source is `d98b08898f45b94bad607f76e19089bb0e15d5c0`. The installed and packaged runner are byte-identical at SHA `26b155ca9cca9b1bb7bbb77dcf7c54943afc8f4212fa7660cb6fb7adb46f62ab`; the QA CLI is SHA `b0e9eb55baab8bcb15727de658be0c28c9205b4c83b6013e3532996f5ae6843d`.
- Android runner acceptance SHA `7892093130ed51de610b2bc52e6a2560a34eed63df3445a750f7340c04f8568d` passed. Its invocation result SHA is `46c87015be7c0a29c78c7f844b8c5e05b37cc9174657700edaaa86786c020adc` with exit 0. The independent Android review approves the smoke while preserving the cycle-spelling and external-ADB-argv join limits.
- The preserved first lifecycle invocation remains a failure: result SHA `34f0e2eeb2d6dada0e231b8f4635d2bf410f7d5b53f010f8d3ac4a3f8606ae8b`. The independently approved recorder correction addresses its authenticated `os.DirEntry` source-race shape. The complete adjacent retry result SHA `53dbd0d08161fcf932401e62375a8ba0e9fd0e2ccf4be4f4358ecd1966ba66c0` exited 0; acceptance SHA `0c43ffab53491b921c10f00ea6b9017dd760deb9791995c9fa9422f33060af62` contains 13 passing checks across startup/ready interrupts, detached readiness, absent-app behavior, success/failure/interrupt log cleanup, and three cycle controls.
- Joint-forward acceptance SHA `5dfe1e6fbe7bae31e2712e33c3d3e688677f17595e8d457c3f9799fadd27fa10` passed all interrupt, normal-stop, absent-app, and healthy-stock cases with controls preserved and owned forwards, sessions, and runner PIDs absent. Invocation result SHA is `cffa1a28a9417a01644fe6fbb4ab759b0fb7dfe2a5550c4a27dba4341491b29a`.
- MCP iOS acceptance SHA `6820bdfb9a53d3405bd04319ac4b6beacca6fb73dd83a0c690aa06292a2f045c` passed session precedence, exact active-session retention, selector semantics, deterministic large responses, 10 transport pairs with unique IDs, and bounded retry behavior. Invocation result SHA is `f3d0da1ed2cbe960e2c9bfcf702ce99c68486884745571fe9d988b44e3ad34ff`.
- MCP Android acceptance SHA `f7bf6b16f722dc5833e58f1a1160f515955bad1fc01905b58e26c9e3b10a0cf4` passed session precedence and retention, deterministic large responses, and 10 transport pairs with unique IDs. Invocation result SHA is `d0dcd8c31e27f150c1a1f461e6548063f927c3ffb1d91b662e68ecf8fb60d941`.
- Docs/output acceptance SHA `191a86d56f9616d6f04f6220c9050d1513f4e1277a6f1d1fde21c8fddf5ae3bd` passed 172 help pages, 16 corpus tests with zero failures, fresh-home cleanliness, doctor text/JSON ownership agreement, public migration-note inspection, and the ambiguous-platform advisory in both zero-exit surfaces. Invocation result SHA is `3d66f3ac9f9e0d089daa88cf631f5e6488fb744c0365a98116b08ce764352c39`.

## Closing gates

- Final force-teardown acceptance SHA `e2f982de3a60f70207cee0f4d5e246223f3fa571fec54728bd40f30411ad9c1c` passed. It stopped the exact runner session, reclaimed its device home, left no owned processes, and explicitly deferred physical simulator deletion to final cleanup. Its invocation result SHA is `34f9cd45bb631bed7df45bc729382eaf1a1ff96084804ed0ab092ed60d1dbf9d`.
- Final-cleanup acceptance SHA `0555ab067fafd150e8c64773b23b0a47d9c26fbc9eea638c98f41074ac21fbda` passed. It records deletion of owned iOS simulator `0CA840ED-E98A-4A66-8548-6661C3C831BE`, owned Android AVD `smoke5-c5-android`, PID `40513`, and serial `emulator-5582`; protected simulators remained unchanged.
- Post-smoke artifact-check SHA `be6f0f9e5dc9c17e8e87f50d9c857eebf97f5e219cd0a2641ccbf04efcdeef3c` passed. It rehashes the frozen CLI, installed and packaged runner, APK, bundle members, and iOS app members; records both release worktrees clean; and records an empty capacity registry.

## Evidence limits

- The Android runner smoke does not by itself prove the canonical exact cycle-hop spelling or externally observe the engine-ADB argv. Its live results may join only the clauses identified in `candidate5-android-smoke-review.md`; stronger source/test or runtime obligations remain separate.
- The original lifecycle failure is preserved and must not be regraded as a pass. Approval rests on the reviewed narrow recorder correction plus the complete fresh retry.
- Summary acceptances are supported by their retained phase-local raw evidence, but this review does not promote smoke observations into unexecuted canonical matrix rows.
- Candidate 5 early iOS gate evidence is separate from this broad-smoke verdict. Canonical full coverage, including remaining iOS runtime obligations, remains pending.

No product failure or unresolved broad-smoke acceptance gap remains in the reviewed evidence.
