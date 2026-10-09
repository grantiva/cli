# Android example

A three-screen Jetpack Compose app used to exercise Grantiva's Android support.

Prerequisites: `scripts/android-env.sh` from the repository root (SDK, JDK 21, the
`Pixel_8_API_35` AVD), and `JAVA_HOME`/`ANDROID_HOME` exported as that script prints.

    cd examples/android
    grantiva doctor
    grantiva build
    grantiva run
    grantiva diff capture
    grantiva diff approve
    grantiva diff compare

The first `./gradlew` run downloads the Android Gradle Plugin and Compose; allow a few minutes.
