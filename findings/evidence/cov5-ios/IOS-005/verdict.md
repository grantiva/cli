# IOS-005 — pass (4/4 clauses)

1. Fresh explicit-type/runtime `--no-boot` invocation exited 0 and returned only UUID `FF9991D6-AA4B-42B1-A6CD-2F93F8F0AB26` on stdout.
2. Stderr reports `Created … — Shutdown`.
3. `inventory-after-create-before-delete.stdout` independently binds the exact UUID to Shutdown before cleanup.
4. Exact delegated deletion removed that UUID and the final inventory proves absence.
