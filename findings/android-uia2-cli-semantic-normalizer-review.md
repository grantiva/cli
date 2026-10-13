# Android UIA2-to-CLI semantic normalization

`findings/harnesses/compare-uia2-cli-app-semantics.py` compares the application surface rather than byte-comparing two whole Android hierarchy documents.

For each node whose `package` is `com.kylebrowning.landmarks`, it maps the UIA2 `class` attribute or XML tag to class, `resource-id` or `identifier` to ID, and the deduplicated nonempty values among `text`, `content-desc`, `label`, `name`, and `value` to semantic labels. Anonymous layout wrappers and all system-UI nodes are excluded. The comparison is a multiset match, so serializer ordering does not matter, but every meaningful node must match in both directions and both inputs must be nonempty.

UIA2 `[x1,y1][x2,y2]` bounds are physical pixels. The harness records `adb shell wm density`; at the retained emulator's 420 dpi, the scale is 420/160 = 2.625 pixels per dp. Bounds are converted to `(x,y,width,height)` dp. A maximum coordinate/dimension delta of 1.25 dp allows integer pixel serialization and rounding while remaining much smaller than an application row or gesture displacement.

The retained B3-L51 rerun9 direction pair validates the decoder: 23 direct meaningful app nodes and 23 CLI nodes match, with no missing or extra nodes. The preserved result is `B3-L51-four-forms-rerun9/direction/posthoc-app-semantic-comparison.json`.

The L03 v10 harness also closes a timing flaw in v9: it accepts the baseline only while `Yosemite Valley` is visible and before any measured scroll completion appears in the runner log, then preserves the acceptance timestamp and log snapshot. This prevents a post-gesture numeric landmark hierarchy from being mislabeled as the baseline.
