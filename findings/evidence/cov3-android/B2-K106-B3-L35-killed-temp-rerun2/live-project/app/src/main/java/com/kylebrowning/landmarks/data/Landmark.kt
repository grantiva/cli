package com.kylebrowning.landmarks.data

data class Landmark(
    val id: String,
    val name: String,
    val location: String,
    val description: String,
    val isFeatured: Boolean,
    val category: Category,
) {
    companion object {
        /** Lowercased name, punctuation removed, spaces as hyphens. */
        fun slug(name: String): String =
            name.lowercase()
                .filter { it.isLetterOrDigit() || it == ' ' }
                .trim()
                .split(Regex("\\s+"))
                .joinToString("-")
    }
}
