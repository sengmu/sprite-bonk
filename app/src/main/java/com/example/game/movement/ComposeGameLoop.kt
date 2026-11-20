package com.example.game.movement

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameNanos
import kotlinx.coroutines.isActive

/**
 * VSYNC-synchronized Compose Game Loop powered by [withFrameNanos].
 *
 * Automatically adapts to 60Hz, 90Hz, and 120Hz Android displays without `delay()` timer drift,
 * clamping delta time cleanly to prevent physics spikes after lifecycle pauses.
 */
@Composable
fun ComposeGameLoop(
    active: Boolean = true,
    maxDeltaSec: Float = 0.05f,
    onFrame: (dtSec: Float, smoothedFps: Float) -> Unit
) {
    val latestOnFrame by rememberUpdatedState(onFrame)

    LaunchedEffect(active) {
        if (!active) return@LaunchedEffect
        var lastFrameNanos = 0L
        var smoothedFps = 60f

        while (isActive) {
            withFrameNanos { frameNanos ->
                if (lastFrameNanos == 0L) {
                    lastFrameNanos = frameNanos
                    latestOnFrame(1f / 60f, smoothedFps)
                } else {
                    val rawDt = (frameNanos - lastFrameNanos) / 1_000_000_000f
                    lastFrameNanos = frameNanos
                    val clampedDt = rawDt.coerceIn(0.001f, maxDeltaSec)
                    val instantFps = (1f / rawDt.coerceAtLeast(0.001f)).coerceIn(1f, 240f)
                    smoothedFps = smoothedFps * 0.88f + instantFps * 0.12f
                    latestOnFrame(clampedDt, smoothedFps)
                }
            }
        }
    }
}
