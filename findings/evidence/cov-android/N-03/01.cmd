for i in 1 2 3; do $S/tools/seedmany.sh emulator-5554 a$i; done; for i in 1 2; do $S/tools/seedmany.sh emulator-5554 f$i --snapshot full; done
