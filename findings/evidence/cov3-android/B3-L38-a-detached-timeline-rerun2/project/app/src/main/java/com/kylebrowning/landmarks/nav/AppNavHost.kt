package com.kylebrowning.landmarks.nav

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.kylebrowning.landmarks.ui.CachingDemoScreen
import com.kylebrowning.landmarks.ui.CategoryScreen
import com.kylebrowning.landmarks.ui.DeepLinksScreen
import com.kylebrowning.landmarks.ui.EditLandmarkScreen
import com.kylebrowning.landmarks.ui.FavoritesScreen
import com.kylebrowning.landmarks.ui.GestureLabScreen
import com.kylebrowning.landmarks.ui.LandmarkDetailScreen
import com.kylebrowning.landmarks.ui.LandmarksListScreen
import com.kylebrowning.landmarks.ui.SlowScreen
import com.kylebrowning.landmarks.ui.VisitConfirmationScreen

private fun Tab.icon(): ImageVector = when (this) {
    Tab.LANDMARKS -> Icons.Filled.Home
    Tab.FAVORITES -> Icons.Filled.Favorite
    Tab.DEEP_LINKS -> Icons.Filled.Share
}

/** Bottom navigation with one independent back stack per tab. */
@Composable
fun AppNavHost(pendingLink: String?, onLinkHandled: () -> Unit, modifier: Modifier = Modifier) {
    var selected by rememberSaveable { mutableStateOf(Tab.LANDMARKS) }
    val controllers = mapOf(
        Tab.LANDMARKS to rememberNavController(),
        Tab.FAVORITES to rememberNavController(),
        Tab.DEEP_LINKS to rememberNavController(),
    )
    val stateHolder = rememberSaveableStateHolder()
    // Gesture Lab fills the window, so a tap at a bottom corner cannot switch tabs.
    val currentRoute = controllers.getValue(selected).currentBackStackEntryAsState().value?.destination?.route
    val showTabs = currentRoute != Screen.GestureLab.route

    // External VIEW intents open in the Landmarks tab.
    LaunchedEffect(pendingLink) {
        val link = pendingLink ?: return@LaunchedEffect
        val routes = DeepLinkResolver.routes(link)
        if (routes.isNotEmpty()) {
            selected = Tab.LANDMARKS
            val nav = controllers.getValue(Tab.LANDMARKS)
            nav.popBackStack(Screen.List.route, inclusive = false)
            routes.forEach { nav.navigate(it) }
        }
        onLinkHandled()
    }

    Scaffold(
        modifier = modifier,
        bottomBar = {
            if (showTabs) NavigationBar {
                Tab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = tab == selected,
                        onClick = {
                            if (tab == selected) {
                                controllers.getValue(tab).popBackStack(tab.root.route, inclusive = false)
                            } else {
                                selected = tab
                            }
                        },
                        icon = { Icon(tab.icon(), contentDescription = null) },
                        label = { Text(tab.label) },
                        alwaysShowLabel = true,
                    )
                }
            }
        },
    ) { padding ->
        val tab = selected
        stateHolder.SaveableStateProvider(tab.name) {
            val nav = controllers.getValue(tab)
            NavHost(
                navController = nav,
                startDestination = tab.root.route,
                modifier = Modifier.padding(padding),
            ) {
                landmarkGraph(nav)
            }
        }
    }
}

private fun NavGraphBuilder.landmarkGraph(nav: NavHostController) {
    val openLink: (String) -> Unit = { link -> DeepLinkResolver.routes(link).forEach { nav.navigate(it) } }

    composable(Screen.List.route) {
        LandmarksListScreen(
            onLandmark = { nav.navigate(Screen.Detail.of(it)) },
            onCategory = { nav.navigate(Screen.Category.of(it)) },
        )
    }
    composable(Screen.Favorites.route) {
        FavoritesScreen(onLandmark = { nav.navigate(Screen.Detail.of(it)) })
    }
    composable(Screen.DeepLinks.route) {
        DeepLinksScreen(
            onLink = openLink,
            onCachingDemo = { nav.navigate(Screen.CachingDemo.route) },
            onEditLandmark = { nav.navigate(Screen.Edit.of(it)) },
            onMountainsYosemite = {
                nav.navigate(Screen.Category.of("mountains"))
                nav.navigate(Screen.Detail.of("yosemite-valley"))
            },
            onSlowScreen = { nav.navigate(Screen.Slow.route) },
            onGestureLab = { nav.navigate(Screen.GestureLab.route) },
        )
    }
    composable(Screen.Detail.route) { entry ->
        LandmarkDetailScreen(
            id = entry.arguments?.getString("id").orEmpty(),
            onBack = { nav.popBackStack() },
            onPlanVisit = { nav.navigate(Screen.Visit.of(it)) },
        )
    }
    composable(Screen.Category.route) { entry ->
        CategoryScreen(
            slug = entry.arguments?.getString("slug").orEmpty(),
            onBack = { nav.popBackStack() },
            onLandmark = { nav.navigate(Screen.Detail.of(it)) },
        )
    }
    composable(Screen.Visit.route) { entry ->
        VisitConfirmationScreen(
            id = entry.arguments?.getString("id").orEmpty(),
            onDone = { nav.popBackStack() },
        )
    }
    composable(Screen.Edit.route) { entry ->
        EditLandmarkScreen(
            id = entry.arguments?.getString("id").orEmpty(),
            onClose = { nav.popBackStack() },
        )
    }
    composable(Screen.CachingDemo.route) {
        CachingDemoScreen(onBack = { nav.popBackStack() })
    }
    composable(Screen.Slow.route) {
        SlowScreen(onBack = { nav.popBackStack() })
    }
    composable(Screen.GestureLab.route) {
        GestureLabScreen(onBack = { nav.popBackStack() })
    }
}
