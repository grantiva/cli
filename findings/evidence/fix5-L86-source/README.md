# L86 ownership-race validation

Base source: `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`.

Each command directory contains `start.json` (argv, cwd, base HEAD, explicit API-key removal and fresh home paths), `result.json` (exit, elapsed, home existence and SHA-256), and byte-preserving gzip archives of stdout, stderr and the source/test diff against that base. Decompress with `gzip -dc`; hashes in result.json describe decompressed bytes. Original raw files remain locally alongside archives and are ignored to avoid duplicating evidence in git. `run.py` is the exact harness used; it refuses to overwrite a command directory.

| Command | Outcome |
| --- | --- |
| red | Exit 1; two deterministic tests, nine expected assertions fail on original product source. |
| focused-green | Exit 1, compile-only failure. Directory name is not a passing verdict. One migrated test captured non-Sendable XCTest self. |
| focused-corrected | Exit 0; 84 tests pass after capturing an immutable device array. |
| full | Exit 0; 2,027 tests, zero failures, 201.123 seconds; one invocation. |

Every invocation unsets GRANTIVA_API_KEY and uses distinct initially absent GRANTIVA_RUNNER_HOME / MAESTRO_RUNNER_HOME paths. All four commands leave both roots absent. No failed attempt was overwritten or suppressed. No live simulator, runner build, release, or frozen candidate operation was performed.

The fix captures registry records before enumeration and prunes only unchanged records. Reserve and sessions both use this protocol; manager boot ownership lookup, managed sessions, teardown by session/UDID and cleanup were migrated. Deterministic tests retain twin boot ownership and record identity across a stale Shutdown list, avoid a second boot, and verify owned created-device shutdown/deletion. Session tests also cover missing snapshots, new reservations and subsequent genuine stale pruning. Focused existing controls cover manual/legacy-device protection, capacity, foreign sessions, pending twins and dead/durable owners.
