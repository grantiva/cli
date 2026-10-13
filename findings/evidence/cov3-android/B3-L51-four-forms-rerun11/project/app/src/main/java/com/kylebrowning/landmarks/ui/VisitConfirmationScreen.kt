package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.data.LandmarkStore

@Composable
fun VisitConfirmationScreen(id: String, onDone: () -> Unit) {
    val name = LandmarkStore.landmark(id)?.name ?: id
    Scaffold(topBar = { LandmarksTopBar("Confirmation") }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Visit Scheduled!", style = MaterialTheme.typography.headlineMedium)
            Text("You're all set to visit $name.", style = MaterialTheme.typography.bodyLarge)
            Button(onClick = onDone) { Text("Done") }
        }
    }
}
