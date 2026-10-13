
Everything a caller captures or parses — a `--json` payload, the `ensure` UDID,
a result table, a dumped hierarchy — goes to **stdout**, undecorated. Progress
narration, warnings, and errors go to **stderr**. So both of these work, and
neither sees the other's output:

```bash
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva doctor --json | jq '.[] | select(.status == "error")'
```

Each doctor check's `status` is `ok`, `warning` or `error`. Only `error` makes `grantiva doctor` exit non-zero;
a `warning` (an advisory check such as no booted simulator) never does.

Every `--json` document, and the `--ready-file` file, uses camelCase keys.

