package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.data.Category
import com.kylebrowning.landmarks.data.Landmark
import com.kylebrowning.landmarks.data.LandmarkStore

@Composable
fun LandmarksListScreen(onLandmark: (String) -> Unit, onCategory: (String) -> Unit) {
    val landmarks = LandmarkStore.landmarks
    Scaffold(topBar = { LandmarksTopBar("Landmarks") }) { padding ->
        if (landmarks.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("No landmarks yet", style = MaterialTheme.typography.titleMedium)
            }
            return@Scaffold
        }
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            item(key = "h-featured") { SectionHeader("Featured") }
            items(landmarks.filter { it.isFeatured }, key = { "f-${it.id}" }) {
                LandmarkRow(it) { onLandmark(it.id) }
            }
            item(key = "h-categories") { SectionHeader("Categories") }
            items(Category.entries, key = { "c-${it.slug}" }) { category ->
                ListItem(
                    headlineContent = { Text(category.label) },
                    modifier = Modifier.clickable { onCategory(category.slug) },
                )
            }
            item(key = "h-all") { SectionHeader("All Landmarks") }
            items(landmarks, key = { "a-${it.id}" }) {
                LandmarkRow(it) { onLandmark(it.id) }
            }
        }
    }
}

@Composable
fun SectionHeader(title: String) {
    Column {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
        )
        HorizontalDivider()
    }
}

@Composable
fun LandmarkRow(landmark: Landmark, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(landmark.name) },
        supportingContent = { Text(landmark.location) },
        modifier = Modifier.clickable(onClick = onClick),
    )
}
