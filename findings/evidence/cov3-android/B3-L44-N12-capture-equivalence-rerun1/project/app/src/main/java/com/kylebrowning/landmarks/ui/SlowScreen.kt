package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import kotlinx.coroutines.delay

const val SLOW_SCREEN_DELAY_MS = 3000L

@Composable
fun SlowScreen(onBack: () -> Unit) {
    var loaded by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!loaded) {
            delay(SLOW_SCREEN_DELAY_MS)
            loaded = true
        }
    }
    Scaffold(topBar = { LandmarksTopBar("Slow Screen", onBack) }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            Text(if (loaded) "Loaded after delay" else "Loading…", style = MaterialTheme.typography.titleMedium)
        }
    }
}
