package com.kylebrowning.landmarks

import android.os.Bundle

/**
 * Launch-time test configuration. Values come from intent extras first (the Grantiva
 * runner delivers `launchApp` env that way on Android), then from the process environment.
 */
object TestEnvironment {
    enum class Seed { DEFAULT, EMPTY, MANY }

    var seed: Seed = Seed.DEFAULT
    var crashOnLaunch = false
    var note: String? = null

    fun load(extras: Bundle?) {
        fun v(k: String) = extras?.getString(k) ?: System.getenv(k)
        seed = when (v("LANDMARKS_SEED")) {
            "empty" -> Seed.EMPTY
            "many" -> Seed.MANY
            else -> Seed.DEFAULT
        }
        crashOnLaunch = v("LANDMARKS_CRASH_ON_LAUNCH") == "1"
        note = v("LANDMARKS_NOTE")
    }
}
