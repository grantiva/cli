# Task 9 AND-111 compile collector preparation review

**Specification compliance: CHANGES REQUIRED. Code quality and execution safety: CHANGES REQUIRED.** Do not execute this revision. The approved input recipe remains valid; the collector needs the bounded corrections below before collecting its first compile result.

Reviewed helper SHA-256: `7938955d92548212b47b98b9926500ee9b53f26fd8894e5dd0e2293ab5a8c769`. The preparation report and three fake fixtures were inspected; they were not rerun. No build, test, device, network or helper execution occurred.

## Findings

### P1 — ordinary Gradle project-cache output is incorrectly rejected

`task9_and111_compile.py:122` permits generated files only beneath `app/build/` and `build/`. A normal Gradle invocation also writes the project's `.gradle/` cache. Setting `GRADLE_USER_HOME` redirects the user home, not the project cache. The frozen CLI's `GradleBuildRunner.command` (`Sources/GrantivaCore/Android/GradleBuildRunner.swift:30–42`) constructs `./gradlew :app:assembleFreeDebug --console=plain` plus supplied extra args; the reviewed literal recipe/config supplies no `--project-cache-dir`. The frozen demo's `.gitignore` explicitly includes `.gradle/`, and its existing source project has that directory.

Thus a valid compilation can be rejected for expected generated files after the one allowed command has already run. Define and record `.gradle/` as an allowed scratch-only generated cache root, alongside the existing build roots, without changing the literal public command or frozen source. Keep tracked-file changes and unexpected sibling paths rejected. Add a fake project-cache file to the allowed-output fixture and retain the unexpected-file negative control.

### P1 — frozen runner identity omits its actual symlink and candidate binary hash

`files`/`tree_hash` (`36–44`) omit symlinks, and `frozen_state` (`89–97`) checks only the runner-home path and its before/after tree digest. The actual frozen home contains `versions/1.1.28-grantiva.15+android-drivers-2/cache`, a symlink to the home cache. Retargeting/removing that link can leave the reported tree unchanged. The same routine never compares `candidate.runner.installed.path` against `candidate.runner.installed.sha256`; a changed installed binary present before both snapshots becomes the accepted baseline.

Use a non-following tree manifest that includes entry kind, regular-file content, relevant mode bits and symlink target text. Explicitly validate the candidate's installed runner hash before compilation and afterward. Preserve the declared cache symlink instead of rejecting the valid existing home. The candidate supplies the actual installed path/hash, so no new candidate schema is needed. Add fake symlink-retarget and preexisting-installed-hash-mismatch cases.

### P1 — fresh scratch/output checks do not all precede compilation

`main:129,138–150` accepts any absent `--output` location, creates it, and places `GRADLE_USER_HOME` beneath it. There is no exclusion for descendants of the frozen source repositories, candidate runner home or artifact trees. For example, an absent root inside the frozen runner home's cache causes the collector and Gradle to write there before the later comparison rejects the mutation.

Also, `before["scratch"]["generated"] == []` is enforced only in `validate_transition:121`, after compilation. A scratch project with preexisting generated files therefore still runs, contrary to the asserted clean-input boundary.

Before creating output or invoking compilation, reject output roots within frozen source/home/artifact locations or within the reviewed scratch project. After collecting the before snapshot, require its generated list to be empty before launching the compile. Non-following scratch entry checks should reject unexpected symlinks rather than silently ignoring them at `83–86`. These are preflight guards, not permission to clean or reset contaminated paths.

### P2 — compile failure prevents required after-state evidence

`run:58` raises for timeout/nonzero exit, so the compile call at `150` skips the after snapshot, source checks and terminal comparison on precisely those outcomes. Raw compile streams survive, but there is no after-device/frozen/scratch state or durable terminal acceptance/failure record. A partially completed failed build still needs evidence of whether it changed device or frozen state.

Allow the compile wrapper to return its recorded non-pass result, then attempt the same bounded read-only after-state captures and persist a non-pass terminal record regardless of exit. Keep later snapshot/validation failures recorded alongside the original compile failure without overwriting it. Never write a passing `grantiva.task9.and111.v1` acceptance on this path, and do not retry or clean up. Extend fake checks to a nonzero compile and a timeout without invoking live tools.

## Correctly bounded controls and schema compatibility

The candidate, provision, shutdown, input manifest and input-review hashes are pinned. The actual shutdown artifact supplies the consumed allocation, protected Pixel and registration hash fields, and its literal AVD/serial/PID agrees with the collector. The compile argv is exactly the frozen CLI followed by `build`, `build`, with no device flag. Cwd, API-key removal, both frozen runner homes, JDK21 and SDK variables match the reviewed recipe. No install, boot, launch, shutdown or candidate substitution command is encoded.

Normal successful execution retains raw bounded command streams, checks existing AVD and absence of the owned serial/PID, compares adb/forwards/AVD registration/config and protected/owned iOS records, validates the config rewrite and tracked scratch hashes, and emits the external-join candidate/shutdown fields expected by the source-window collector. Exclusive evidence creation prevents in-place overwrites. Those controls should remain unchanged while repairing the findings.

The three fixtures exercise useful isolated checks but not realistic project-cache output, actual runner-link identity, precompile contamination refusal or failure postflight. Only this review document was added; source, prepared helper and evidence were not modified.
