# Candidate5 source-evidence join review

Status: **APPROVED at source-clause scope only**. This review proposes no public, frozen-binary, device, smoke, or runtime PASS. The adjacent JSON is the clause-level integration artifact.

The immutable candidate manifest hashes to `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`. It binds CLI merge `dd5d3336296a41014a45070cc5a8c4295a0873ec`, runner merge `d98b08898f45b94bad607f76e19089bb0e15d5c0`, reviewed runner head `9c18b962a0d85bcbb76fb8141fdd4aae97d28389`, and their equal tree `060236c478bceba52bb7e54081dd06a44d6aa299`.

The fresh Swift package suite is valid current-candidate proof: exit 0, 2,027 passing tests, stdout SHA-256 `96e0e82c1b8ac6eec5d975c8a465ea46efa9cdee9675fa81476e97ca591ef552`, 63 mapped references to 58 unique named tests, and zero missing names. The candidate packaging delta is restricted to the two runner archives, `RunnerManager.swift`, and its expectation update, so those fresh test results bind the CLI tree shipped in candidate5.

The runner proof is also current-tree evidence. Focused L87, package, full Go, and vet exits are all zero and match `source-proof.json`; the manifest independently binds their hashes. `merge-acceptance.json` proves the reviewed head and squash merge have the same tree. Fresh full Go/vet can therefore join source clauses in unchanged packages, while the old scratch runner cannot join any candidate5 runtime clause.

The JSON marks 25 rows `SOURCE_CLAUSE_SATISFIED`. These are clauses whose canonical wording is itself a source test, production-path regression, compatibility ruling, or scoped implementation invariant covered by the fresh suites: L53 parser/target validation, L74's ISO encoder test, L75's merged-output-map test, L81's production-entry test requirement, L82's production regression, L83/L84 ownership-safe cleanup source regressions, L85 selector priority/transport tests, and PC.9–PC.13 runner cancellation/budget source contracts.

Twenty-five mixed rows retain only a source portion. Their row verdict remains incomplete because the canonical clause also requires public commands, frozen-binary behavior, live sessions/attachments/orphans, device evidence, smoke, or campaign completion. This includes L53.P5, L67, L74.4, public L75 cycles, live L81, L82/L83/L84 completion clauses, PC.5, both EJ.3 platform halves, and L85.5. No source result substitutes for those captures.

A follow-up read-only inspection closes the exact-file binding gap. `README.md` and `docs/mcp.md` are now bound by absolute path and SHA-256 to the frozen CLI tree and directly contain the canonical L70 literal/legacy/migration wording and L74 ISO-8601/string-only wording. L70.1–3 and L74.1–2 therefore join as source/documentation clauses. The frozen demo bindings cover `PersistentTabContainer.swift`, `ContentView.swift`, and `Navigator.swift`: UIKit tab labels/order/symbols, literal `heart` identifier, separate navigation stacks, and persisted selected-tab/path state are source-supported. L85.4 remains mixed because source inspection does not prove rendered geometry or live switch-away/switch-back retention.

AND-111 still requires its literal candidate5 compile/shutdown capture. L87 stock and diff behavior is already covered by the separately approved early iOS gate and is not relabeled as source evidence here. The final L85.5 campaign join remains pending full smoke and coverage completion.

No commands, builds, tests, devices, or product files were changed during this review.
