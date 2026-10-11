$GRANTIVA diff capture --device emulator-5556 --no-build > $S/n06-1b.out 2> $S/n06-1b.err; echo "second capture same boot rc=$?"; grep -E "Captured" $S/n06-1b.out
