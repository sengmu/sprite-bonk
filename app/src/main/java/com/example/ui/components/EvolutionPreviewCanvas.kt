package com.example.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.game.evolution.EvolutionVisualStyle
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.HudInkDark
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Shared real-time procedural sprite renderer for EVERY evolution node!
 * Used identically inside the live UI Evolution Preview stage, Free-Roam Playground,
 * and the VSYNC BattleCanvas so every species and evolution branch renders with crisp cel-shading.
 */
fun DrawScope.drawEvolvedHeroSprite(
    style: EvolutionVisualStyle,
    center: Offset,
    baseRadius: Float,
    animTime: Float,
    orbitAngle: Float,
    facingAngle: Float = 0.25f,
    moveSpeedRatio: Float = 0f,
    isAttacking: Boolean = false,
    isHurt: Boolean = false,
    isUltActive: Boolean = false,
    leanDeg: Float = 0f
) {
    val moving = moveSpeedRatio > 0.1f
    val hopWave = sin(animTime)
    val bob = if (moving) -abs(hopWave) * (5.5f + 2.5f * moveSpeedRatio.coerceAtMost(1.5f)) else sin(animTime * 0.55f) * 3f
    val stretchX = if (moving) 1f + hopWave * 0.06f else 1f
    val stretchY = if (moving) 1f - hopWave * 0.06f else 1f
    val scale = style.scaleFactor
    val rx = baseRadius * scale * stretchX
    val ry = baseRadius * scale * stretchY
    val bodyCenter = Offset(center.x, center.y + bob)

    // Evolution & Ult glowing aura with subtle outer energy ring
    val showAura = scale > 1.05f || isUltActive
    if (showAura) {
        val auraCol = if (isUltActive) GoldAccent else style.auraColor
        val auraR = if (isUltActive) rx * 2.55f else rx * 1.72f
        drawCircle(
            Brush.radialGradient(listOf(auraCol.copy(alpha = 0.40f), Color.Transparent), center, auraR),
            radius = auraR,
            center = center
        )
        drawOval(
            color = auraCol.copy(alpha = if (isUltActive) 0.72f else 0.44f),
            topLeft = Offset(center.x - rx * 1.24f, center.y + ry * 0.60f),
            size = Size(rx * 2.48f, ry * 0.66f),
            style = Stroke(width = if (isUltActive) 3.4f else 2.2f)
        )
    }

    // Soft grounded drop shadow
    val shadowScale = 1f - (abs(bob) / 36f).coerceIn(0f, 0.25f)
    drawOval(
        color = Color.Black.copy(alpha = 0.28f),
        topLeft = Offset(center.x - rx * 1.06f * shadowScale, center.y + ry * 0.74f),
        size = Size(rx * 2.12f * shadowScale, ry * 0.56f * shadowScale)
    )

    val lookX = cos(facingAngle) * (baseRadius * 0.20f)
    val lookY = sin(facingAngle) * (baseRadius * 0.13f)
    val footSwing = if (moving) sin(animTime) * (baseRadius * 0.24f) else 0f
    val primary = if (isHurt) CrimsonRed else style.primaryColor
    val secondary = if (isHurt) Color(0xFFB52626) else style.secondaryColor

    val artCtx = HeroArtContext(
        style = style,
        bodyCenter = bodyCenter,
        rx = rx,
        ry = ry,
        animTime = animTime,
        orbitAngle = orbitAngle,
        lookX = lookX,
        lookY = lookY,
        footSwing = footSwing,
        primary = primary,
        secondary = secondary,
        scale = scale,
        isAttacking = isAttacking,
        isUltActive = isUltActive
    )

    rotate(degrees = leanDeg, pivot = bodyCenter) {
        when (style.starterId) {
            "stump" -> drawStumpHeroArt(artCtx)
            "char" -> drawCharHeroArt(artCtx)
            "shell" -> drawShellHeroArt(artCtx)
            "spark" -> drawSparkHeroArt(artCtx)
            "wisp" -> drawWispHeroArt(artCtx)
            else -> drawDrakeHeroArt(artCtx)
        }
    }
}

/**
 * Interactive animated real-time evolution preview stage widget for UI panels.
 */
@Composable
fun LiveEvolutionPreviewStage(
    style: EvolutionVisualStyle,
    modifier: Modifier = Modifier,
    stageSize: Dp = 148.dp
) {
    val transition = rememberInfiniteTransition(label = "evo_preview")
    val animTime by transition.animateFloat(
        initialValue = 0f,
        targetValue = 12.566f,
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "evo_anim"
    )
    val orbitAngle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 6.283f,
        animationSpec = infiniteRepeatable(tween(2600, easing = LinearEasing), RepeatMode.Restart),
        label = "evo_orbit"
    )

    val shape = RoundedCornerShape(22.dp)
    Box(
        modifier = modifier
            .size(stageSize)
            .clip(shape)
            .background(
                Brush.radialGradient(
                    listOf(style.auraColor.copy(alpha = 0.34f), HudInkDark.copy(alpha = 0.94f))
                )
            )
            .border(2.5.dp, style.auraColor.copy(alpha = 0.85f), shape),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val c = Offset(size.width / 2f, size.height * 0.56f)

            // Soft overhead showcase spotlight cone
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Color.White.copy(alpha = 0.14f), Color.Transparent),
                    center = Offset(size.width * 0.5f, size.height * 0.18f),
                    radius = size.minDimension * 0.58f
                ),
                radius = size.minDimension * 0.58f,
                center = Offset(size.width * 0.5f, size.height * 0.18f)
            )

            // Glowing turntable pedestal & rotating elemental rune arcs
            drawOval(
                color = style.auraColor.copy(alpha = 0.24f),
                topLeft = Offset(size.width * 0.12f, size.height * 0.67f),
                size = Size(size.width * 0.76f, size.height * 0.24f)
            )
            drawArc(
                color = style.auraColor.copy(alpha = 0.82f),
                startAngle = orbitAngle * 57.3f,
                sweepAngle = 115f,
                useCenter = false,
                topLeft = Offset(size.width * 0.16f, size.height * 0.69f),
                size = Size(size.width * 0.68f, size.height * 0.19f),
                style = Stroke(width = 3.0f, cap = StrokeCap.Round)
            )
            drawArc(
                color = Color.White.copy(alpha = 0.62f),
                startAngle = orbitAngle * 57.3f + 180f,
                sweepAngle = 90f,
                useCenter = false,
                topLeft = Offset(size.width * 0.16f, size.height * 0.69f),
                size = Size(size.width * 0.68f, size.height * 0.19f),
                style = Stroke(width = 2.4f, cap = StrokeCap.Round)
            )

            // Ambient rising evolution motes
            for (i in 0 until 8) {
                val a = orbitAngle + i * 0.785f
                val px = c.x + cos(a) * (size.width * 0.38f)
                val py = c.y - (size.height * 0.34f) * ((sin(animTime * 0.6f + i) + 1f) * 0.5f) + 16f
                drawCircle(style.auraColor.copy(alpha = 0.42f), 5.5f, Offset(px, py))
                drawCircle(Color.White.copy(alpha = 0.82f), 2.4f, Offset(px, py))
            }

            // Real-time animated sprite render
            drawEvolvedHeroSprite(
                style = style,
                center = c,
                baseRadius = size.minDimension * 0.22f,
                animTime = animTime,
                orbitAngle = orbitAngle,
                facingAngle = sin(animTime * 0.35f) * 0.6f,
                moveSpeedRatio = 0.25f,
                isAttacking = sin(animTime * 1.2f) > 0.78f
            )
        }
    }
}
