# Android stable manual fixture fix2 re-review

**APPROVED for the three scoped corrections.** All three findings from the fix1 review are addressed by the fix1-to-fix2 diff, and no important breakage was found in that diff. This is an evidence-only review; it does not grant live emulator or coverage authorization.

Verified revised-helper SHA-256 `6d4a99694878ccbe9b5a3790b0bfc869a0b961724128c8a3313800d9254a1397`. Also verified the retained focused-check SHA-256 `d7d3783d297e5d1b484714cabc1fe2a01cff83f76ec58a5ae6c46464a1ae2d20`, focused output SHA-256 `2678e449c9fa27353bc3180ccd8760ef58560b2d3be0ce2fac9e74764b9ac6bf`, regression output SHA-256 `4f8737a9f17b4e4b7c5ba769f32694354a69793ec0aa8ee7eb49e43dc4c040fd`, and fix1-to-fix2 diff SHA-256 `1721066a00acd9704b8eaaf76c985346d8a28cfb43676a2c8c8c096a4729f30f`. The retained checks and their outputs were inspected, not rerun.

## Finding disposition

| Fix1 finding | Verdict | Evidence in fix2 |
|---|---|---|
| Ordinary not-yet-attached adb response aborts readiness | Addressed | Startup device probes accept nonzero exits as recorded observations. Readiness still requires all three exits to be zero and the exact device, AVD, and boot values to match. The focused retained scenario shows a nonzero/offline observation followed by readiness within one launch attempt. |
| Identity frozen before wrapper-to-qemu handoff | Addressed | The returned PID is journaled immediately, then anchored by PID, start, process group, and session. Each polling iteration requires that anchor to remain unchanged; durable ownership is written only when the same anchored process has the exact expected qemu/AVD/port command and the device probes are ready. The focused retained scenario exercises the wrapper-to-qemu transition. |
| Nonempty timeout streams cannot be JSON encoded | Addressed | Timeout stdout and stderr are converted to explicit base64 records before entering failure evidence, preserving arbitrary bytes and making them JSON serializable. The focused retained scenario verifies both streams through parseable launch and numbered verification terminal records. |

## Quality verdict

The changes preserve the prior boundaries: strict overall deadlines, exact readiness acceptance, immutable evidence, and no cleanup or signal behavior. The new `accept_nonzero` behavior is limited to startup device-state probes; identity and other probes remain strict. The handoff anchor prevents following another process while allowing the intended same-process exec transition. The base64 timeout schema is explicit and lossless.

No new important breakage is evident in the fix diff. Spec verdict: **pass**. Quality verdict: **pass**.

This review used only the supplied prior review, package, diff, helper snapshot, focused-check source, and retained outputs. No test, device, adb, emulator, build, or network command was run.
