package com.example.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.game.engine.HitFeedbackSnapshot
import com.example.ui.theme.CrimsonRed

private val HitEdgeScarlet = Color(0xFFFF1E38)
private val HitEdgeHotRim = Color(0xFFFF6B7A)
private val HitEdgeColorsForward = listOf(HitEdgeScarlet, CrimsonRed.copy(alpha = 0.42f), Color.Transparent)
private val HitEdgeColorsReverse = listOf(Color.Transparent, CrimsonRed.copy(alpha = 0.42f), HitEdgeScarlet)
private val HitCornerColors = listOf(HitEdgeScarlet, Color.Transparent)

/**
 * Viewport-cached gradient brushes for [GlobalHitEdgeFlashOverlay] so hit flashes
 * perform zero Brush/List/Array allocations per frame during high-intensity damage bursts.
 */
private class HitFlashBrushCache {
    private var lastW = -1f
    private var lastH = -1f
    var edgeDepth = 48f
        private set
    var cornerRadius = 120f
        private set
    var topBrush: Brush? = null
        private set
    var bottomBrush: Brush? = null
        private set
    var leftBrush: Brush? = null
        private set
    var rightBrush: Brush? = null
        private set
    var cornerTL: Brush? = null
        private set
    var cornerTR: Brush? = null
        private set
    var cornerBL: Brush? = null
        private set
    var cornerBR: Brush? = null
        private set
    var rimStrokeThin: Stroke = Stroke(width = 6f)
        private set
    var rimStrokeThick: Stroke = Stroke(width = 10f)
        private set

    fun ensure(w: Float, h: Float, minEdgePx: Float, rimThinPx: Float, rimThickPx: Float) {
        if (w == lastW && h == lastH) return
        lastW = w
        lastH = h
        val minDim = minOf(w, h)
        edgeDepth = (minDim * 0.145f).coerceAtLeast(minEdgePx)
        cornerRadius = (minDim * 0.36f).coerceAtLeast(1f)
        topBrush = Brush.verticalGradient(colors = HitEdgeColorsForward, startY = 0f, endY = edgeDepth)
        bottomBrush = Brush.verticalGradient(colors = HitEdgeColorsReverse, startY = h - edgeDepth, endY = h)
        leftBrush = Brush.horizontalGradient(colors = HitEdgeColorsForward, startX = 0f, endX = edgeDepth)
        rightBrush = Brush.horizontalGradient(colors = HitEdgeColorsReverse, startX = w - edgeDepth, endX = w)
        cornerTL = Brush.radialGradient(colors = HitCornerColors, center = Offset.Zero, radius = cornerRadius)
        cornerTR = Brush.radialGradient(colors = HitCornerColors, center = Offset(w, 0f), radius = cornerRadius)
        cornerBL = Brush.radialGradient(colors = HitCornerColors, center = Offset(0f, h), radius = cornerRadius)
        cornerBR = Brush.radialGradient(colors = HitCornerColors, center = Offset(w, h), radius = cornerRadius)
        rimStrokeThin = Stroke(width = rimThinPx)
        rimStrokeThick = Stroke(width = rimThickPx)
    }
}

/**
 * Full-screen non-blocking red edge flash effect driven by [GlobalHitFeedbackTrigger].
 * Reads [hitFeedbackProvider] strictly inside the draw phase (`Canvas`) with cached brushes
 * so hit feedback animates at full 60Hz with zero Compose recompositions or GC allocations.
 */
@Composable
fun GlobalHitEdgeFlashOverlay(
    hitFeedbackProvider: () -> HitFeedbackSnapshot,
    modifier: Modifier = Modifier
) {
    val brushCache = remember { HitFlashBrushCache() }

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .testTag("global_hit_edge_flash")
    ) {
        val hitFeedback = hitFeedbackProvider()
        val intensity = hitFeedback.edgeFlashIntensity
        if (intensity <= 0.005f) return@Canvas

        val w = size.width
        val h = size.height
        if (w <= 1f || h <= 1f) return@Canvas

        val pulse = hitFeedback.flashPulse
        brushCache.ensure(
            w = w,
            h = h,
            minEdgePx = 36.dp.toPx(),
            rimThinPx = 3.dp.toPx(),
            rimThickPx = 5.dp.toPx()
        )
        val edgeDepth = brushCache.edgeDepth
        val outerAlpha = (intensity * (0.56f + 0.20f * pulse)).coerceIn(0f, 0.78f)

        // 4 glowing perimeter edge gradients (cached shaders, alpha-modulated)
        brushCache.topBrush?.let {
            drawRect(brush = it, topLeft = Offset.Zero, size = Size(w, edgeDepth), alpha = outerAlpha)
        }
        brushCache.bottomBrush?.let {
            drawRect(brush = it, topLeft = Offset(0f, h - edgeDepth), size = Size(w, edgeDepth), alpha = outerAlpha)
        }
        brushCache.leftBrush?.let {
            drawRect(brush = it, topLeft = Offset.Zero, size = Size(edgeDepth, h), alpha = outerAlpha)
        }
        brushCache.rightBrush?.let {
            drawRect(brush = it, topLeft = Offset(w - edgeDepth, 0f), size = Size(edgeDepth, h), alpha = outerAlpha)
        }

        // 4 subtle corner crimson radial blooms
        val cornerRadius = brushCache.cornerRadius
        val cornerAlpha = (outerAlpha * 0.45f).coerceIn(0f, 0.38f)
        brushCache.cornerTL?.let { drawCircle(brush = it, radius = cornerRadius, center = Offset.Zero, alpha = cornerAlpha) }
        brushCache.cornerTR?.let { drawCircle(brush = it, radius = cornerRadius, center = Offset(w, 0f), alpha = cornerAlpha) }
        brushCache.cornerBL?.let { drawCircle(brush = it, radius = cornerRadius, center = Offset(0f, h), alpha = cornerAlpha) }
        brushCache.cornerBR?.let { drawCircle(brush = it, radius = cornerRadius, center = Offset(w, h), alpha = cornerAlpha) }

        // Crisp flashing perimeter rim highlight
        val rimStroke = if (pulse > 0.5f) brushCache.rimStrokeThick else brushCache.rimStrokeThin
        val rimWidth = rimStroke.width
        val rimAlpha = (intensity * (0.65f + 0.30f * pulse)).coerceIn(0f, 0.92f)
        drawRect(
            color = HitEdgeHotRim.copy(alpha = rimAlpha),
            topLeft = Offset(rimWidth * 0.5f, rimWidth * 0.5f),
            size = Size((w - rimWidth).coerceAtLeast(1f), (h - rimWidth).coerceAtLeast(1f)),
            style = rimStroke
        )
    }
}
