#!/bin/bash
if [ -t 0 ]; then stdin_tty=true; else stdin_tty=false; fi
if [ -t 1 ]; then stdout_tty=true; else stdout_tty=false; fi
if [ -t 2 ]; then stderr_tty=true; else stderr_tty=false; fi
printf 'stdin_is_tty=%s stdout_is_tty=%s stderr_is_tty=%s CI=%s GRANTIVA_EMULATOR_HEADLESS=%s\n' \
 "$stdin_tty" "$stdout_tty" "$stderr_tty" "${CI-unset}" "${GRANTIVA_EMULATOR_HEADLESS-unset}"
exec "$GRANTIVA" emulator ensure --name "$K27_AVD_NAME"
