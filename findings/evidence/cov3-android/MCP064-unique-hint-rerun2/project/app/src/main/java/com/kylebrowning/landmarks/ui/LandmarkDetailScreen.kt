package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.data.LandmarkStore

@Composable
fun LandmarkDetailScreen(id: String, onBack: () -> Unit, onPlanVisit: (String) -> Unit) {
    val landmark = LandmarkStore.landmark(id)
    val favorite = id in LandmarkStore.favorites
    Scaffold(
        topBar = {
            LandmarksTopBar(landmark?.name ?: "Landmark", onBack) {
                if (landmark != null) {
                    IconButton(
                        onClick = { LandmarkStore.toggleFavorite(id) },
                        modifier = Modifier.semantics {
                            contentDescription = if (favorite) "Unfavorite" else "Favorite"
                        },
                    ) {
                        Icon(
                            if (favorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = null,
                        )
                    }
                }
            }
        },
    ) { padding ->
        if (landmark == null) {
            Text("Landmark not found", Modifier.padding(padding).padding(16.dp))
            return@Scaffold
        }
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(landmark.location, style = MaterialTheme.typography.titleMedium)
            Text(landmark.category.label, style = MaterialTheme.typography.bodyMedium)
            Text("About", style = MaterialTheme.typography.titleLarge)
            Text(landmark.description, style = MaterialTheme.typography.bodyLarge)
            Button(onClick = { onPlanVisit(landmark.id) }) { Text("Plan Visit") }
        }
    }
}
