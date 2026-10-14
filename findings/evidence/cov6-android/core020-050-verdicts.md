# Candidate5 Android core through AND-050

Proposed outcome: all 36 canonical keys PASS: AND-020–025, AND-111–113, AND-143, AND-144, and AND-026–050.

Expected nonzero outcomes are retained for AND-024/025 invalid Gradle inputs, AND-027's explicit mismatched test target, AND-031/033 early validation, AND-040 crash, AND-046 continue-on-failure, all AND-047 failure snapshot modes, AND-049 timeout, and AND-050 failing JSON. They are graded from clause semantics and artifacts rather than exit code alone. AND-022's release APK is debug-signed, so the conditional unsigned warning is inapplicable; `apksigner` proves v2 signature and one Android Debug signer. AND-111 compiles with identical empty adb inventories while the primary is shut down. AND-113 and AND-143 retain boot narration and exact normal/headless process identities. AND-144's iOS config contains explicit `THIS_MUST_NOT_BE_SELECTED` markers while the successful Android install uses `grantiva-android.yml`.

AND-040 retains the crash report, ready failure, and failure screenshot. AND-046 proves the flow after the crash ran and passed. AND-047 retains distinct failure/trailing/full reports. AND-048 adjacent run2 proves `.grantiva/captures` state byte-identical around the separate report directory. AND-049 terminates at the literal 30-second cap with a failed ready file. Both AND-050 stdout documents parse as JSON.

Final state: primary cov6-android generation 4 is healthy at emulator-5554 / PID 91961 with exact identity retained; frozen APK restored and source hash remains `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`. No extra AVD/device, adb forward, or extra Grantiva session remains.
