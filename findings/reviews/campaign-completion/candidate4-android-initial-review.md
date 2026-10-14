# Candidate4 Android AND-001–009 evidence review

Disposition: **APPROVED with one bounded AND-002 wording correction; no proposed verdict changes.** This review performed no rerun or device action.

All 97 command identity records examined bind candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and QA binary SHA-256 `2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5`. The fresh raw records support proposed pass for AND-001 and AND-003–009 and blocked for AND-002.

The only material correction is the AND-002 summary wording. The raw installed-package inventory proves that only `system-images/android-35/google_apis/arm64-v8a` is installed, and the active reservation forbids an SDK image download. It does **not** prove whether a suitable small uninstalled image exists remotely. Keep the blocked verdict, but state its exact basis as `blocked: required uninstalled-image execution would require a prohibited SDK download`; do not claim remote unavailability. `basis-clarification.json` already preserves this evidence limit, while the current results-file note overstates it.

The reviewed equivalences are supported:

- AND-006's no-name command reads the captured configuration selecting `cov5-android-2`; both `cov5-android` and `cov5-android-2` were live, and output plus `adb emu avd name` bind selection to the configured secondary. This is semantically equivalent to the matrix's configured-primary example.
- AND-007 legitimately joins the fresh AND-004 creation. Its exact creation argv has no `--system-image`; the project configuration contains no system-image override; and the resulting AVD config records Android 35 Google APIs arm64-v8a with `pixel_8`. No duplicate creation is required. AND-001 independently demonstrates the same default during primary creation.

No other material gap was found. AND-001 proves absent-name creation, pixel_8 configuration, boot and serial-only stdout; AND-003 proves same-name/same-serial reuse; AND-004 proves no-boot creation and stopped state; AND-005 proves `-no-window` on the authenticated emulator process; AND-008 is valid JSON; and AND-009 lists both Grantiva-started generations with live PIDs/serials. The failed optional `started.json` read in AND-009 does not weaken the command's literal sessions-JSON clause because the fresh session output, ADB names and process captures independently establish both entries.
