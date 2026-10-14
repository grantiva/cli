# B4-L75 iOS runtime handoff

Use the owned primary `cov5-ios-26` in the next exclusive iOS window. Do not use a default or unowned simulator. Candidate, session, homes, and API-key bindings remain the cov5 CLI bindings.

## B4-L75.1 and B4-L75.5 — nested relative cycle

Fixture source: `/private/tmp/grantiva-cov5-cli-gtwQZB/batch17/l75/`. Before execution, change only `simulator:` in `grantiva.yml` to `cov5-ios-26`.

```text
/Users/kyle/.grantiva-qa/bin/grantiva run --no-build --flow flows/a.yaml
```

Require exit 1 within five seconds and `flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`. Retain exact argv/cwd/env/times/raw and verify no `/private/tmp` or `/tmp` staging path leaks. The same capture satisfies L75.1 and the public half of L75.5.

## B4-L75.2 — root cycle

Fixture source: `/private/tmp/grantiva-cov5-cli-gtwQZB/batch17/l75-root/`. Change only `simulator:` to `cov5-ios-26`.

```text
/Users/kyle/.grantiva-qa/bin/grantiva run --no-build --flow a.yaml
```

Require exit 1 within five seconds and `a.yaml -> b.yaml -> a.yaml -> b.yaml`. Then run the config-driven form by omitting `--flow`; require `grantiva.yml -> a.yaml -> b.yaml -> a.yaml`.

## B4-L75.3 — absolute operand preservation

Make an adjacent fixture copy whose `runFlow` operands are absolute paths to its `a.yaml` and `b.yaml`. Run the same command with the absolute `a.yaml` path and `--simulator cov5-ios-26`. Require the cycle error to preserve each user-supplied absolute operand. Retain fixture file hashes with the evidence.

L75.4 is already source-complete. Earlier proven-absent-UUID attempts are preserved and excluded from these public runtime clauses because device resolution occurred before runner-side cycle validation.
