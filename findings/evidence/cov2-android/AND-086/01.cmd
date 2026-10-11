find .grantiva/baselines -type f | sort; /Users/kyle/.grantiva-qa/bin/grantiva diff approve --json; echo exit=$?; find .grantiva/baselines -type f | sort; ls ../ios 2>/dev/null | head -1
