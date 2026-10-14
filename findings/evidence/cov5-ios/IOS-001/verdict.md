# IOS-001 — pass (4/4 clauses)

1. Fresh absence: `inventory-before.stdout` has no `cov5-ios-3 iPhone 17`.
2. Literal input: `ensure-name-only.command.json` records only `--name "cov5-ios-3 iPhone 17"`, with no type/runtime override.
3. Output: exit 0, UUID-only stdout `6F13E2A4-C53F-46BD-BD95-651A43875A94`, and human `Created … — Booted` stderr.
4. Latest runtime/state: `inventory-after-create.stdout` binds that UUID to iPhone 17, iOS 27.0, Booted.
