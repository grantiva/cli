$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml; echo exit=$?; ls .grantiva/run-captures/android | grep failure | tail -2; cat .grantiva/session.json
