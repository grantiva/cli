package com.kylebrowning.landmarks.data

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.snapshots.SnapshotStateList
import com.kylebrowning.landmarks.TestEnvironment

/** Process-wide in-memory store. Seeded once per launch from [TestEnvironment]. */
object LandmarkStore {
    val landmarks: SnapshotStateList<Landmark> = mutableStateListOf()
    val favorites: SnapshotStateList<String> = mutableStateListOf()

    /** True once [reset] has run in this process. */
    var isSeeded = false
        private set

    fun reset(seed: TestEnvironment.Seed) {
        clear()
        landmarks.addAll(SampleData.seeded(seed))
        isSeeded = true
    }

    fun landmark(id: String): Landmark? = landmarks.firstOrNull { it.id == id }

    fun isFavorite(id: String): Boolean = id in favorites

    fun toggleFavorite(id: String) {
        if (!favorites.remove(id)) favorites.add(id)
    }

    fun update(landmark: Landmark) {
        val index = landmarks.indexOfFirst { it.id == landmark.id }
        if (index >= 0) landmarks[index] = landmark
    }

    fun clear() {
        landmarks.clear()
        favorites.clear()
    }
}
