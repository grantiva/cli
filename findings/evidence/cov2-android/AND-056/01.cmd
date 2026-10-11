$GRANTIVA hierarchy --udid emulator-5554 | grep -o 'text="\(Plan Visit\|Mono Lake\)"' | sort -u; $GRANTIVA hierarchy --udid emulator-5556 | grep -o 'text="\(Plan Visit\|Mono Lake\)"' | sort -u
