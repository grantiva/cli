# IOS-095 attempt130 review

**Verdict: PASS.** The device-free current-round corpus at
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt130`
is an exact boundary test for the row.

The immutable 16×16 RGB images differ only in a constant red-channel colour:
baseline `(100,100,100)`, below `(108,100,100)`, and above `(112,100,100)`.
`grantiva.yml` sets `perceptual_threshold: 5.0` and a permissive pixel
threshold. The below case measures 3.437, exits 0 in text and JSON, and reports
`passed`. The above case measures 5.190, exits 1 in text and JSON, and reports
`failed` specifically because perceptual 5.2 exceeds 5.0 while pixel remains
within its threshold. The image dimensions and layout are identical, so the
result isolates the subtle colour boundary required by IOS-095.

