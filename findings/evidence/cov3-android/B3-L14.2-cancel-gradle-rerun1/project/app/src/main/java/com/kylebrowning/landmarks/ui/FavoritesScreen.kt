package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.data.Landmark
import com.kylebrowning.landmarks.data.LandmarkStore

@Composable
fun FavoritesScreen(onLandmark: (String) -> Unit) {
    val favorites = LandmarkStore.favorites.mapNotNull { LandmarkStore.landmark(it) }
    Scaffold(topBar = { LandmarksTopBar("Favorites") }) { padding ->
        if (favorites.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding).padding(24.dp), contentAlignment = Alignment.Center) {
                Text("Landmarks you favorite will appear here.", style = MaterialTheme.typography.bodyLarge)
            }
            return@Scaffold
        }
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            items(favorites, key = { it.id }) { landmark ->
                FavoriteRow(
                    landmark = landmark,
                    onClick = { onLandmark(landmark.id) },
                    onRemove = { LandmarkStore.favorites.remove(landmark.id) },
                )
            }
        }
    }
}

/**
 * Swiping end-to-start reveals a `Remove from favorites` action (the row stays until it is
 * tapped, like an iOS swipe action). Every row also has a visible `Remove` button. The swipe
 * action has its own label so a flow that taps it fails when the swipe did not open the row,
 * instead of tapping the inline button.
 */
@Composable
private fun FavoriteRow(landmark: Landmark, onClick: () -> Unit, onRemove: () -> Unit) {
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = { it != SwipeToDismissBoxValue.StartToEnd },
    )
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            if (state.dismissDirection == SwipeToDismissBoxValue.EndToStart ||
                state.currentValue == SwipeToDismissBoxValue.EndToStart
            ) {
                Row(
                    Modifier.fillMaxSize().background(MaterialTheme.colorScheme.errorContainer),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = onRemove, modifier = Modifier.padding(end = 16.dp)) {
                        Text("Remove from favorites", color = MaterialTheme.colorScheme.onErrorContainer)
                    }
                }
            }
        },
    ) {
        ListItem(
            headlineContent = { Text(landmark.name) },
            supportingContent = { Text(landmark.location) },
            trailingContent = { TextButton(onClick = onRemove) { Text("Remove") } },
            modifier = Modifier.clickable(onClick = onClick),
        )
    }
}
