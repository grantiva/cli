kill -9 60857 60882; sleep 1; ls /tmp/grantiva-sessions/; $GRANTIVA hierarchy --udid emulator-5556; echo rc=$?; $GRANTIVA hierarchy | grep -o 'text="[^"]\+"' | sed -n 2,3p
