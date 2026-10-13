package com.kylebrowning.landmarks

import android.app.Application
import android.os.Handler
import android.os.Looper

class LandmarksApp : Application() {
    companion object {
        const val CRASH_DELAY_MS = 500L

        /** Crashes the process shortly after launch when `LANDMARKS_CRASH_ON_LAUNCH=1`. */
        fun scheduleCrashIfRequested() {
            if (!TestEnvironment.crashOnLaunch) return
            Handler(Looper.getMainLooper()).postDelayed(
                { throw RuntimeException("LANDMARKS_CRASH_ON_LAUNCH") },
                CRASH_DELAY_MS,
            )
        }
    }
}
