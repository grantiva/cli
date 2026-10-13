# Task 8 candidate 2 docs controller correction

## Scope and correction

Corrected only `candidate2_docs.py`; no docs phase, test suite, authenticated console operation, build, or device command was run.

The canonical subcommand parser still requires exactly two leading spaces and a lowercase command name. It now accepts a comma immediately after that canonical name, matching the actual Swift Argument Parser alias rendering `  flags, featureflags     Manage feature flags.`. The canonical queue entry remains `flags`; the alias is not separately traversed. Ordinary whitespace-delimited subcommands remain accepted, and four-space wrapped description lines remain excluded.

The controller now requires an explicit `--output` path and creates that distinct path with `exist_ok=False`. It no longer selects `06-docs-output` internally, so the failed 150-page attempt remains immutable and a reviewed retry can target a fresh evidence directory.

All other candidate hash binding, environment isolation, breadth-first help traversal, 172-page assertion, docs inspection, text/JSON doctor checks, fresh scratch-path test invocation, 16-test assertion, and final publication behavior remain unchanged.

## Verification

- Python syntax compiled in memory and parsed as an AST.
- The corrected parser extracted canonical `flags` from the already captured candidate-2 `console.txt` alias line.
- Synthetic checks accepted a normal two-space command and rejected a four-space wrapped description.
- An offline traversal over the already captured 172-page corpus reached all 172 canonical pages, including exactly 22 `console_flags*` pages.
- Static checks confirmed `--output` is required, resolved directly, and the failed `06-docs-output` path is no longer embedded in the controller.

The pre-correction script is preserved under `task8-candidate2-docs-fix-base/`; the scoped diff is `task8-candidate2-docs-fix.diff`.
