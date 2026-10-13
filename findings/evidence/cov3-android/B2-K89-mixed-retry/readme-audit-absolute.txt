Candidate source provenance
8f2cff676b3c12e951478920fa20e600cdca4e29

$ sed -n 722,733p /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md
shot an older `grantiva run` left there) is listed in a note (and under `ignored` in `--json`) and left alone. `diff approve <screen>...` approves the named
screens; when any of them has no capture it names every missing one in one error and approves none. A failing screen's line names the check it
failed and its limit, for example `Failed: perceptual=63.6 exceeds perceptual_threshold 5.0 (pixel=0.03%, threshold 2.00%)`.

`diff compare` exits 0 only when every screen has a baseline and passes. It exits 1 when a screen fails or errors,
and also when a screen has no baseline: with no baselines at all it prints `? No baselines: <n> new screens. Run:
grantiva diff approve`, and when only some are missing `? Visual diff incomplete: …`; `--json` has `"passed": false`
in both cases. (`ci run` keeps reporting a new screen as `new_screen` without failing the run.)

Local baselines are stored in `.grantiva/baselines/`. Connect to [Grantiva](https://grantiva.io) to store baselines remotely and enable CI across machines.

## License
