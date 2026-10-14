# AND-027 verdict

Result: **pass**

The CLI override warning names .debug versus the APK own ID; the APK installs under its own ID and the runner targets .debug, producing the expected absent-target failure.
