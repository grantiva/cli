$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/05-category.yaml; echo rc=$?; ls .grantiva/captures/android | grep -c failure; cat $S/f063.txt
