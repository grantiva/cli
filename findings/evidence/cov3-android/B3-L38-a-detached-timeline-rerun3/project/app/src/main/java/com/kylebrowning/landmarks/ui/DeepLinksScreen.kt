package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.TestEnvironment
import com.kylebrowning.landmarks.data.LandmarkStore

/** The landmark the Edit Landmark entry opens. */
const val EDIT_LANDMARK_ID = "golden-gate-bridge"

@Composable
fun DeepLinksScreen(
    onLink: (String) -> Unit,
    onCachingDemo: () -> Unit,
    onEditLandmark: (String) -> Unit,
    onMountainsYosemite: () -> Unit,
    onSlowScreen: () -> Unit,
    onGestureLab: () -> Unit,
) {
    val editTarget = LandmarkStore.landmark(EDIT_LANDMARK_ID)
    Scaffold(topBar = { LandmarksTopBar("Deep Links") }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TestEnvironment.note?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
            LinkButton("Gesture Lab", onGestureLab)
            LinkButton("Caching Demo", onCachingDemo)
            LinkButton("Edit Landmark") { onEditLandmark(EDIT_LANDMARK_ID) }
            // The landmark being edited, so a saved rename is visible here after Done.
            editTarget?.let { Text(it.name, style = MaterialTheme.typography.bodySmall) }
            LinkButton("landmarks://landmark/golden-gate-bridge") { onLink("landmarks://landmark/golden-gate-bridge") }
            LinkButton("landmarks://category/lakes") { onLink("landmarks://category/lakes") }
            LinkButton("Mountains → Yosemite Valley", onMountainsYosemite)
            LinkButton("Slow Screen", onSlowScreen)
        }
    }
}

@Composable
private fun LinkButton(label: String, onClick: () -> Unit) {
    OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) { Text(label) }
}
