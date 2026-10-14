# cov5 CLI static preparation

Status: **prepared only; awaiting the completion-candidate4 smoke gate.** No coverage row, device command, build, test, or product command was executed.

`capture-one.original.rb` preserves the approved SHA-256 `f7a4e150…`. `capture-one.rb` changes only the candidate manifest/hash, isolated runner home, and session. `capture-one.diff` records those bindings. Both runner-home environment variables are set, and `GRANTIVA_API_KEY` is unset by the collector.

`direct-row-batches.json` contains all 425 directly executed CLI-owned effective keys in frozen matrix order, in 17 preparation batches of at most 25. `ios-handoffs.json` contains only CLI-048/049/061/064/066/083 in matrix order; they retain CLI result ownership and iOS execution routing. These are preparation inventories and carry no old verdict or evidence.
