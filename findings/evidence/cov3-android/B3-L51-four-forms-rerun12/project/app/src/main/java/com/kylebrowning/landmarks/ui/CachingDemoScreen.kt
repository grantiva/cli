package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.time.LocalTime
import java.time.format.DateTimeFormatter

val CACHE_POLICIES = listOf(
    "Cache Then Fetch",
    "Cache Else Fetch",
    "Network Only",
    "Cache Only",
    "Network Else Cache",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CachingDemoScreen(onBack: () -> Unit) {
    var policy by rememberSaveable { mutableStateOf(CACHE_POLICIES.first()) }
    var expanded by remember { mutableStateOf(false) }
    var status by rememberSaveable { mutableStateOf("Cache empty") }
    var fetches by rememberSaveable { mutableStateOf(0) }
    val formatter = remember { DateTimeFormatter.ofPattern("HH:mm:ss") }
    var clock by remember { mutableStateOf(LocalTime.now().format(formatter)) }

    LaunchedEffect(Unit) {
        while (true) {
            clock = LocalTime.now().format(formatter)
            delay(1000)
        }
    }

    Scaffold(topBar = { LandmarksTopBar("Caching Demo", onBack) }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = policy,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Cache Policy") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    CACHE_POLICIES.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = { policy = option; expanded = false },
                        )
                    }
                }
            }
            Button(onClick = {
                fetches += 1
                status = "Fetched $fetches time(s) using $policy"
            }) { Text("Fetch with Policy") }
            OutlinedButton(onClick = { fetches = 0; status = "Cache empty" }) { Text("Clear Cache") }
            Text(status, style = MaterialTheme.typography.bodyMedium)
            Text(
                clock,
                style = MaterialTheme.typography.displaySmall,
                modifier = Modifier.testTag("clock").semantics { contentDescription = "clock" },
            )
        }
    }
}
