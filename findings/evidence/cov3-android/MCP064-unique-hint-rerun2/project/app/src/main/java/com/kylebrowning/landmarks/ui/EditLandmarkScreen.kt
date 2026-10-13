package com.kylebrowning.landmarks.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.kylebrowning.landmarks.data.LandmarkStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditLandmarkScreen(id: String, onClose: () -> Unit) {
    val original = LandmarkStore.landmark(id)
    var name by rememberSaveable(stateSaver = TextFieldValue.Saver) {
        mutableStateOf(TextFieldValue(original?.name.orEmpty()))
    }
    var location by rememberSaveable(stateSaver = TextFieldValue.Saver) {
        mutableStateOf(TextFieldValue(original?.location.orEmpty()))
    }
    var confirmDiscard by rememberSaveable { mutableStateOf(false) }
    val hasChanges = original != null && (name.text != original.name || location.text != original.location)

    val cancel = { if (hasChanges) confirmDiscard = true else onClose() }
    BackHandler(onBack = cancel)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit Landmark") },
                navigationIcon = { TextButton(onClick = cancel) { Text("Cancel") } },
                actions = {
                    TextButton(onClick = {
                        if (original != null) {
                            LandmarkStore.update(original.copy(name = name.text.trim(), location = location.text.trim()))
                        }
                        onClose()
                    }) { Text("Done") }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LabeledField("Name", name) { name = it }
            LabeledField("Location", location) { location = it }
        }
    }

    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            text = { Text("You have unsaved changes that will be lost.") },
            confirmButton = {
                TextButton(onClick = { confirmDiscard = false; onClose() }) { Text("Discard") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDiscard = false }) { Text("Keep Editing") }
            },
        )
    }
}

/** A text field that places the cursor at the end of its text when it gains focus. */
@Composable
private fun LabeledField(label: String, value: TextFieldValue, onChange: (TextFieldValue) -> Unit) {
    if (label == "Name") {
        androidx.compose.ui.viewinterop.AndroidView(
            factory = { context -> android.widget.EditText(context).apply {
                hint = "MCP064 Unique Hint"
                contentDescription = "Name"
                setText("")
                isSingleLine = true
            } },
            modifier = Modifier.fillMaxWidth(),
        )
        return
    }
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier
            .fillMaxWidth()
            .semantics { contentDescription = label }
            .onFocusChanged { focus ->
                if (focus.isFocused) onChange(value.copy(selection = TextRange(value.text.length)))
            },
    )
}
