package com.kylebrowning.landmarks.nav

import android.net.Uri
import com.kylebrowning.landmarks.data.Category

/** Routes shared by every tab's back stack. */
sealed class Screen(val route: String) {
    data object List : Screen("list")
    data object Favorites : Screen("favorites")
    data object DeepLinks : Screen("deeplinks")
    data object CachingDemo : Screen("caching")
    data object Slow : Screen("slow")
    data object GestureLab : Screen("gesture-lab")
    data object Detail : Screen("detail/{id}") { fun of(id: String) = "detail/$id" }
    data object Category : Screen("category/{slug}") { fun of(slug: String) = "category/$slug" }
    data object Visit : Screen("visit/{id}") { fun of(id: String) = "visit/$id" }
    data object Edit : Screen("edit/{id}") { fun of(id: String) = "edit/$id" }
}

enum class Tab(val label: String, val root: Screen) {
    LANDMARKS("Landmarks", Screen.List),
    FAVORITES("Favorites", Screen.Favorites),
    DEEP_LINKS("Deep Links", Screen.DeepLinks),
}

/**
 * Resolves `landmarks://landmark/<slug>` and `landmarks://category/<slug>` to the routes to
 * push, in order. Used by both the `VIEW` intent and the Deep Links buttons.
 */
object DeepLinkResolver {
    fun routes(link: String): kotlin.collections.List<String> {
        val uri = Uri.parse(link)
        if (uri.scheme != "landmarks") return emptyList()
        val slug = uri.pathSegments.firstOrNull() ?: return emptyList()
        return when (uri.host) {
            "landmark" -> listOf(Screen.Detail.of(slug))
            "category" -> Category.fromSlug(slug)?.let { listOf(Screen.Category.of(it.slug)) } ?: emptyList()
            else -> emptyList()
        }
    }
}
