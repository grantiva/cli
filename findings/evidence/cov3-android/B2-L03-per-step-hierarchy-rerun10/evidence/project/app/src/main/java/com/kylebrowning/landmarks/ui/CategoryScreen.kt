package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.kylebrowning.landmarks.data.Category
import com.kylebrowning.landmarks.data.LandmarkStore

@Composable
fun CategoryScreen(slug: String, onBack: () -> Unit, onLandmark: (String) -> Unit) {
    val category = Category.fromSlug(slug)
    val landmarks = LandmarkStore.landmarks.filter { it.category == category }
    Scaffold(topBar = { LandmarksTopBar(category?.label ?: slug, onBack) }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            items(landmarks, key = { it.id }) { LandmarkRow(it) { onLandmark(it.id) } }
        }
    }
}
