# CLI-165 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Error: Invalid argument: Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios\|android or set GRANTIVA_PLATFORM.`, exit 1, before any build (help: build_install.txt `--platform`; src PlatformResolver.swift:40)

Fresh candidate5 commands retained exact argv/cwd/identity/raw/exit. Clause review confirms the observed parser or validation boundary matches the expected requirement and occurred before compiler or live-device work. Evidence: `CLI-165-run-1/install.command.json`.
