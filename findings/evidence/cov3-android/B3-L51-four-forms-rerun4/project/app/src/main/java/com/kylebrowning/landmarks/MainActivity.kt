package com.kylebrowning.landmarks

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.kylebrowning.landmarks.data.LandmarkStore
import com.kylebrowning.landmarks.nav.AppNavHost

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    /** Deep link delivered by a `VIEW` intent, consumed by the nav host. */
    private val pendingLink = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logLaunch(intent)
        TestEnvironment.load(intent.extras)
        // Seed on a fresh launch, and again if the process died while the activity was saved.
        if (savedInstanceState == null || !LandmarkStore.isSeeded) LandmarkStore.reset(TestEnvironment.seed)
        if (savedInstanceState == null) pendingLink.value = intent.dataString
        setContent {
            MaterialTheme {
                AppNavHost(
                    pendingLink = pendingLink.value,
                    onLinkHandled = { pendingLink.value = null },
                    // Expose Compose test tags (e.g. "clock", "gesture-pad") as resource ids for `id:` selectors.
                    modifier = Modifier.semantics { testTagsAsResourceId = true },
                )
            }
        }
        LandmarksApp.scheduleCrashIfRequested()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        logLaunch(intent)
        pendingLink.value = intent.dataString
    }

    private fun logLaunch(intent: Intent) {
        val extras = intent.extras
        val keys = extras?.keySet()?.joinToString { "$it=${extras.get(it)}" } ?: "none"
        val env = listOf("LANDMARKS_SEED", "LANDMARKS_CRASH_ON_LAUNCH", "LANDMARKS_NOTE")
            .joinToString { "$it=${System.getenv(it)}" }
        Log.i("Landmarks", "launch action=${intent.action} data=${intent.dataString} extras=[$keys] env=[$env]")
    }
}
