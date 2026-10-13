#!/bin/bash
printf 'stdin_is_tty=%s stdout_is_tty=%s stderr_is_tty=%s CI=%s GRANTIVA_EMULATOR_HEADLESS=%s\n' \
 "$([ -t 0 ] && echo true || echo false)" "$([ -t 1 ] && echo true || echo false)" "$([ -t 2 ] && echo true || echo false)" \
 "${CI-unset}" "${GRANTIVA_EMULATOR_HEADLESS-unset}"
exec "$GRANTIVA" emulator ensure --name "$K27_AVD_NAME"
