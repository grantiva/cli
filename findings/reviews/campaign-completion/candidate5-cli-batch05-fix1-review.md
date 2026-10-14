# Candidate 5 CLI batch 05 fix 1 review

Scope: `CLI-142` corrected execution only. The two earlier attempts remain excluded. This review does not reopen any other batch 05 row.

## Verdict

- **Spec: APPROVED**
- **Evidence quality: APPROVED**
- **CLI-142: PASS**

The canonical clause requires `runner install` beside a bundle from another release to refuse replacement while naming both versions and the bundle, leaving the existing installation untouched. The campaign ruling accepts this refusal as an exit-zero warning with no mutation.

`CLI-142-run-3` exercises that condition with the frozen candidate 5 binary. `fixture-before.json` records the copied executable at SHA-256 `b0e9eb55baab8bcb15727de658be0c28c9205b4c83b6013e3532996f5ae6843d`, equal to the candidate value, and an intentionally older `.15` adjacent bundle whose four retained member hashes are `d8f587bd826c2cb4176ae92c35db0e65574e9cc0da1bd959348dd436e8c4d68b`, `59cbbf5725cfe682e857b8e1e3ec1a063a265c537aeee1fb57c5d4b8a5c1fb2c`, `c7bdb3703f23cadf464844cb77a250acc2a926b226d93728b29b1322eb15e132`, and `12aae9dc17c9ce5942bcd5becd56d6a810932476633f6c5e1c3167e602c54761`.

The exact invocation routes both runner-home variables to the isolated CLI142 home and completes without timeout at exit 0. Its warning names adjacent bundle version `1.1.28-grantiva.15`, installed version `1.1.28-grantiva.16`, and the adjacent bundle path; it says the installed runner is left in place. Stdout reports the installed `.16` runner. The 9,997-entry before and after manifests compare equal, `home-after.json` records `unchanged: true`, and the installed runner remains SHA-256 `26b155ca9cca9b1bb7bbb77dcf7c54943afc8f4212fa7660cb6fb7adb46f62ab`.

Candidate identity is bound to manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; all expected frozen QA artifact hashes in `install-mismatch.identity.json` match. The corrected author verdict SHA-256 is `7df5cf7ca0989b1e4f65c0c6614ef515f42798ddac6a36108325ec7942465478`.

## Evidence hashes

- `fixture-before.json`: `e748ad9b0013f5356d0b0eff287d7167f30fbb889d3a57e120a6a65e762f8c9f`
- `home-after.json`: `5950a51d754ab145516c4acdda3fbacb438a14f7442b792834d0ca31ecf16d86`
- `install-mismatch.command.json`: `1ea869e7a2c3f4cce1124a33433b45506d57652da2212011179af4c898a48848`
- `install-mismatch.identity.json`: `eab8f2b9c63ee0526e92f967e5c9b3e4e116df607069bedf0e4d00635f92e047`
- `install-mismatch.stderr`: `d57d77ef7918f2becc2c262945a69a5b8ba50118ade29a94350de4f6b4da31e3`
- `install-mismatch.stdout`: `f9167a35a5aea026114d9580ff2d7f598725c9c59bbe65f9eb0c809df51389a5`

This addendum clears the sole CLI-142 gap recorded in the initial batch 05 review. It does not change that review's disposition of the six other pending rows.
