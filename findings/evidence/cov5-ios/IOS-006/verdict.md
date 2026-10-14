# IOS-006 — pass (5/5 clauses)

1. New-device output is valid JSON with `created: true` and UUID `178F2CE1-9E23-460B-AF26-7D1560152643`.
2. JSON contains iPhone 17, iOS 26.0, Booted, scale, point dimensions, and pixel dimensions; inventory independently matches.
3. Bare-name primary reuse is valid JSON with `created: false` and allocated UUID `532523A7-30B3-4048-A538-4F3DB2EFB807`.
4. Primary JSON reports its own iPhone 17/iOS 26.0 identity, Booted state, and geometry.
5. Only the fresh extra was deleted; the primary remains Booted and was not physically deleted.
