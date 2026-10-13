rm -rf .grantiva/baselines/android; /Users/kyle/.grantiva-qa/bin/grantiva diff approve --json; echo approve-exit=$?; /Users/kyle/.grantiva-qa/bin/grantiva diff compare --json; echo compare-exit=$?
