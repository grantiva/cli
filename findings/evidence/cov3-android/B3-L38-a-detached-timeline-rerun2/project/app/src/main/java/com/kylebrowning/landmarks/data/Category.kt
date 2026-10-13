package com.kylebrowning.landmarks.data

enum class Category(val label: String) {
    MOUNTAINS("Mountains"),
    LAKES("Lakes"),
    BRIDGES("Bridges");

    val slug: String get() = label.lowercase()

    companion object {
        fun fromSlug(slug: String): Category? = entries.firstOrNull { it.slug == slug.lowercase() }
    }
}
