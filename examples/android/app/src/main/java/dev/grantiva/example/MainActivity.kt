package dev.grantiva.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

enum class Screen(val title: String) { Home("Home"), Details("Details"), Settings("Settings") }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { ExampleApp() } }
    }
}

@Composable
fun ExampleApp() {
    var current by rememberSaveable { mutableStateOf(Screen.Home) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                Screen.entries.forEach { screen ->
                    NavigationBarItem(
                        selected = current == screen,
                        onClick = { current = screen },
                        icon = {},
                        label = { Text(screen.title) },
                        modifier = Modifier.semantics { contentDescription = screen.title }
                    )
                }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
            when (current) {
                Screen.Home -> {
                    Text("Welcome to Grantiva", style = MaterialTheme.typography.headlineMedium)
                    Text("This screen is the launch baseline.")
                }
                Screen.Details -> {
                    Text("Details", style = MaterialTheme.typography.headlineMedium)
                    Text("Three lines of body copy give the diff something to compare.")
                    Text("Line two.")
                    Text("Line three.")
                }
                Screen.Settings -> {
                    var enabled by rememberSaveable { mutableStateOf(true) }
                    Text("Settings", style = MaterialTheme.typography.headlineMedium)
                    Switch(checked = enabled, onCheckedChange = { enabled = it })
                }
            }
        }
    }
}
