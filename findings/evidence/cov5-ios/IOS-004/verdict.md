# IOS-004 — pass (5/5 clauses)

1. Exact explicit-26 invocation exited 0 and returned UUID `D4FBCF43-AED1-4F38-BE45-0244CB0176A7`.
2. `inventory-after-26-before-delete.stdout` independently binds that UUID to iOS 26.0, iPhone 17, Booted before cleanup.
3. The 99.9 invocation exited 1 with the clear unavailable-runtime error.
4. `inventory-after-99.stdout` contains no `cov5-ios-4` negative target; the retained `cov5-ios-4 Pin` is a distinct exact name.
5. Exact delegated deletion removed the positive UUID and the final inventory proves absence.
