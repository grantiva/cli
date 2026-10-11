/Users/kyle/.grantiva-qa/bin/grantiva run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml; echo exit=$?; ls .grantiva/run-captures/android | grep -c failure
