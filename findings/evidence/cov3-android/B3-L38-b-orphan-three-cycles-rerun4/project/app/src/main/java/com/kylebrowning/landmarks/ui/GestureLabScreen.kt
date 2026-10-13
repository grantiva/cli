package com.kylebrowning.landmarks.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.abs

/** Finger travel below this is not a swipe. */
private val SWIPE_MIN_DISTANCE = 50.dp

/**
 * A single gesture pad whose read-outs show which gesture it last received, so a flow can prove
 * that a double tap, a long press, a tap location or a swipe direction did what it says.
 */
@Composable
fun GestureLabScreen(onBack: () -> Unit) {
    var taps by remember { mutableIntStateOf(0) }
    var doubleTaps by remember { mutableIntStateOf(0) }
    var longPresses by remember { mutableIntStateOf(0) }
    var lastSwipe by remember { mutableStateOf("none") }
    var lastTap by remember { mutableStateOf("none") }
    val minDistancePx = with(LocalDensity.current) { SWIPE_MIN_DISTANCE.toPx() }

    Scaffold(topBar = { LandmarksTopBar("Gesture Lab", onBack) }) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
                .testTag("gesture-pad")
                .semantics { contentDescription = "Gesture pad" }
                .pointerInput(Unit) {
                    detectTapGestures(
                        onDoubleTap = { doubleTaps++ },
                        onLongPress = { longPresses++ },
                        onTap = { offset ->
                            taps++
                            lastTap = GestureLab.zone(offset, size)
                        },
                    )
                }
                .pointerInput(Unit) {
                    // detectDragGestures reports travel from the point where touch slop was crossed, so the
                    // 50 dp threshold is about 58 dp of real finger travel; the flows' full swipes clear it.
                    var travel = Offset.Zero
                    detectDragGestures(
                        onDragStart = { travel = Offset.Zero },
                        onDragEnd = {
                            if (travel.getDistance() >= minDistancePx) lastSwipe = GestureLab.direction(travel.x, travel.y)
                        },
                        onDrag = { change, amount ->
                            change.consume()
                            travel += amount
                        },
                    )
                },
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Taps: $taps")
                Text("Double taps: $doubleTaps")
                Text("Long presses: $longPresses")
                Text("Last swipe: $lastSwipe")
                Text("Last tap: $lastTap")
            }
        }
    }
}

/** Pure helpers behind the Gesture Lab read-outs. */
object GestureLab {
    /** `center` when the tap is inside the middle third of the pad on both axes, else `edge`. */
    fun zone(offset: Offset, size: IntSize): String {
        val inX = offset.x >= size.width / 3f && offset.x <= size.width * 2 / 3f
        val inY = offset.y >= size.height / 3f && offset.y <= size.height * 2 / 3f
        return if (inX && inY) "center" else "edge"
    }

    /** The dominant axis direction of finger travel (end minus start). */
    fun direction(dx: Float, dy: Float): String =
        if (abs(dx) >= abs(dy)) {
            if (dx < 0) "left" else "right"
        } else {
            if (dy < 0) "up" else "down"
        }
}
