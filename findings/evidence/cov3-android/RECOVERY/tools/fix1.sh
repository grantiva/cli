#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; C=.maestro/coverage
U(){ echo "## $1 load: $(uptime | sed 's/.*load averages*: //')"; }
for i in 1 2 3; do U crash-$i; $S/tools/crashrun.sh rr-crash-$i .maestro/99-crash.yaml; done
for i in 1 2 3; do U l06-$i; $S/tools/crashrun.sh rr-l06-index0-$i $C/l06-index0.yaml; done
for i in 1 2 3; do U edit-$i; $S/tools/cflow.sh rr-edit-$i .maestro/03-edit.yaml | head -4; grep -m1 'POST /session/[^/]*/element ' $S/cf/rr-edit-$i/client.log | cut -c1-110; done
for i in 1 2 3; do U gest-$i; $S/tools/cflow.sh rr-gest-$i $C/03-gesture-lab-taps.yaml | grep -E '^==|doubleTap|Double|✗'; done
for i in 1 2 3; do U scroll-$i; $S/tools/cflow.sh rr-scroll-$i $C/08-scroll.yaml | grep -E '^==|scrollUntil|✗|╰'; done
for i in 1 2 3; do U uni-$i; $S/tools/cflow.sh rr-uni-$i $C/15-input-unicode.yaml | grep -E '^==|inputText|✗|╰'; grep -E 'actions|element/active' $S/cf/rr-uni-$i/client.log | cut -c1-140; done
U k09; $S/tools/k09loop.sh 10
echo FIX1-DONE
