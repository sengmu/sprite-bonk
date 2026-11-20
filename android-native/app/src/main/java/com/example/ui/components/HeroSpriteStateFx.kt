package com.example.ui.components

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.lerp
import com.example.game.evolution.EvolutionVisualStyle
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Computes a two-stage arcade hit-flash color tint:
 * - Fresh impact frames (hurtProgress > 0.72f) flash incandescent white-peach for crisp readability.
 * - Recovery frames pulse into vivid crimson while preserving shaded silhouette contrast.
 */
internal fun blendHurtTint(baseColor: Color, hurtProgress: Float): Color {
    val p = hurtProgress.coerceIn(0f, 1f)
    if (p <= 0.01f) return baseColor
    if (p > 0.72f) {
        val whiteT = ((p - 0.72f) / 0.28f).coerceIn(0f, 1f)
        return lerp(CrimsonRed, Color(0xFFFFF5EB), 0.52f + whiteT * 0.40f)
    }
    val pulse = (0.58f + 0.42f * abs(sin(p * 22f))) * (p / 0.72f).coerceIn(0.25f, 1f)
    return lerp(baseColor, CrimsonRed, (pulse * 0.80f).coerceIn(0f, 0.85f))
}

/**
 * Track 6: Dynamic elemental contrast rim halo so heroes pop sharply against dark biomes
 * (Graveyard, Volcanic Abyss, Deep Desert), plus Ult/Hyper iridescent outline sheen.
 */
internal fun DrawScope.drawElementalRimAndUltSheen(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    orbitAngle: Float,
    isUltActive: Boolean
) {
    val rimCol = evolutionPrimaryFxColor(style)
    val rimRadius = (rx * (if (isUltActive) 1.72f else 1.42f)).coerceAtLeast(1f)
    // Subtle dark-biome figure-ground separation rim behind the silhouette
    drawCircle(
        brush = Brush.radialGradient(
            listOf(rimCol.copy(alpha = if (isUltActive) 0.34f else 0.16f), Color.Transparent),
            center = center,
            radius = rimRadius
        ),
        radius = rimRadius,
        center = center
    )
    if (isUltActive) {
        // Twin counter-rotating iridescent sweep arcs hugging the hero during Ult / Hyper-Awakening
        val deg = orbitAngle * 114.59156f
        drawArc(
            color = GoldAccent.copy(alpha = 0.86f),
            startAngle = deg,
            sweepAngle = 82f,
            useCenter = false,
            topLeft = Offset(center.x - rx * 1.24f, center.y - ry * 1.22f),
            size = Size(rx * 2.48f, ry * 2.44f),
            style = Stroke(width = 3.2f, cap = StrokeCap.Round)
        )
        drawArc(
            color = Color.White.copy(alpha = 0.82f),
            startAngle = -deg + 165f,
            sweepAngle = 64f,
            useCenter = false,
            topLeft = Offset(center.x - rx * 1.16f, center.y - ry * 1.14f),
            size = Size(rx * 2.32f, ry * 2.28f),
            style = Stroke(width = 2.4f, cap = StrokeCap.Round)
        )
    }
}

/**
 * Track 4: Species-specific 2.5D Air Glide visuals replacing the old generic blue wings.
 */
internal fun DrawScope.drawSpeciesGlideVfx(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    animTime: Float,
    orbitAngle: Float
) {
    val flap = sin(animTime * 6.0f) * ry * 0.14f
    when (style.starterId) {
        "stump" -> {
            // Oversized botanical leaf-canopy glider unfurling overhead + falling spores
            val canopyY = center.y - ry * 1.18f
            val canopy = Path().apply {
                moveTo(center.x - rx * 1.88f, canopyY + ry * 0.24f + flap * 0.5f)
                quadraticTo(center.x, canopyY - ry * 0.72f, center.x + rx * 1.88f, canopyY + ry * 0.24f + flap * 0.5f)
                quadraticTo(center.x, canopyY - ry * 0.08f, center.x - rx * 1.88f, canopyY + ry * 0.24f + flap * 0.5f)
                close()
            }
            drawPath(canopy, Brush.verticalGradient(listOf(Color(0xFFC8FF82), Color(0xFF43B94E))))
            drawPath(canopy, EspressoDark, style = Stroke(2.2f, join = StrokeJoin.Round))
            // Updraft ring
            drawOval(
                color = Color(0x999DF86A),
                topLeft = Offset(center.x - rx * 1.35f, center.y + ry * 0.78f),
                size = Size(rx * 2.70f, ry * 0.52f),
                style = Stroke(2.2f)
            )
        }
        "char" -> {
            // Twin volcanic jet-thruster flame cones firing downward!
            for (side in listOf(-1f, 1f)) {
                val jx = center.x + side * rx * 0.72f
                val jy = center.y + ry * 0.58f
                val flameH = ry * (1.05f + 0.22f * sin(animTime * 9.0f + side))
                val jet = Path().apply {
                    moveTo(jx - rx * 0.28f, jy)
                    lineTo(jx, jy + flameH)
                    lineTo(jx + rx * 0.28f, jy)
                    close()
                }
                drawPath(jet, Brush.verticalGradient(listOf(Color(0xFFFFF4B8), Color(0xFFFF7A29), Color.Transparent), jy, jy + flameH))
            }
        }
        "shell" -> {
            // Pressurized spinning hydro-geyser hover column & foam rings beneath shell keel
            val geyserTop = center.y + ry * 0.65f
            val geyserH = ry * 1.15f
            drawRect(
                brush = Brush.verticalGradient(
                    listOf(Color(0xCC7BE8FF), Color(0x66D6FCFF), Color.Transparent),
                    startY = geyserTop,
                    endY = geyserTop + geyserH
                ),
                topLeft = Offset(center.x - rx * 0.56f, geyserTop),
                size = Size(rx * 1.12f, geyserH)
            )
            drawArc(
                color = Color.White.copy(alpha = 0.88f),
                startAngle = orbitAngle * 114.59156f,
                sweepAngle = 210f,
                useCenter = false,
                topLeft = Offset(center.x - rx * 1.28f, center.y + ry * 0.74f),
                size = Size(rx * 2.56f, ry * 0.58f),
                style = Stroke(3.0f, cap = StrokeCap.Round)
            )
        }
        "spark" -> {
            // Crackling golden lightning-ribbon wings spread wide
            for (side in listOf(-1f, 1f)) {
                val wing = Path().apply {
                    moveTo(center.x + side * rx * 0.52f, center.y - ry * 0.12f)
                    lineTo(center.x + side * rx * 1.92f, center.y - ry * 0.56f + flap)
                    lineTo(center.x + side * rx * 1.44f, center.y + ry * 0.02f + flap * 0.5f)
                    lineTo(center.x + side * rx * 1.76f, center.y + ry * 0.26f + flap * 0.4f)
                    lineTo(center.x + side * rx * 0.58f, center.y + ry * 0.28f)
                    close()
                }
                drawPath(wing, Brush.horizontalGradient(listOf(Color.White, GoldAccent)))
                drawPath(wing, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
            }
        }
        "wisp" -> {
            // Expanding translucent ghostly veil cloak floating gracefully
            val cloak = Path().apply {
                moveTo(center.x - rx * 1.72f, center.y + ry * 0.18f + flap)
                quadraticTo(center.x, center.y - ry * 0.96f, center.x + rx * 1.72f, center.y + ry * 0.18f + flap)
                quadraticTo(center.x, center.y + ry * 0.52f, center.x - rx * 1.72f, center.y + ry * 0.18f + flap)
                close()
            }
            drawPath(cloak, Brush.verticalGradient(listOf(Color(0xAA9A6BFF), Color(0x885EF2E8))))
            drawPath(cloak, Color.White.copy(alpha = 0.65f), style = Stroke(2.0f, join = StrokeJoin.Round))
        }
        else -> {
            // Drake: Grand luminous astral-prism glider aura behind expanded crystal wings
            for (side in listOf(-1f, 1f)) {
                val spanWing = Path().apply {
                    moveTo(center.x + side * rx * 0.42f, center.y - ry * 0.08f)
                    lineTo(center.x + side * rx * 2.18f, center.y - ry * 0.72f + flap)
                    lineTo(center.x + side * rx * 1.65f, center.y + ry * 0.34f + flap * 0.5f)
                    close()
                }
                drawPath(spanWing, Brush.linearGradient(listOf(Color(0xCCFFFFFF), Color(0xAA7BE8FF), Color(0x886C7BFF))))
                drawPath(spanWing, GoldAccent.copy(alpha = 0.85f), style = Stroke(2.2f, join = StrokeJoin.Round))
            }
        }
    }
}

/**
 * Track 4: Directional speed-lines trailing behind the sprite during Dash.
 */
internal fun DrawScope.drawDashSpeedLines(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    facingAngle: Float
) {
    val backX = -cos(facingAngle)
    val backY = -sin(facingAngle)
    val perpX = -backY
    val perpY = backX
    val col = evolutionPrimaryFxColor(style)
    for (i in -1..1) {
        val lat = i * ry * 0.46f
        val start = Offset(center.x + backX * rx * 0.75f + perpX * lat, center.y + backY * ry * 0.75f + perpY * lat)
        val end = Offset(center.x + backX * rx * (1.85f + abs(i) * 0.25f) + perpX * lat, center.y + backY * ry * (1.85f + abs(i) * 0.25f) + perpY * lat)
        drawLine(col.copy(alpha = 0.72f), start, end, strokeWidth = if (i == 0) 4.2f else 2.8f, cap = StrokeCap.Round)
        drawLine(Color.White.copy(alpha = 0.88f), start, Offset((start.x + end.x) * 0.5f, (start.y + end.y) * 0.5f), strokeWidth = 1.8f, cap = StrokeCap.Round)
    }
}

/**
 * Track 4: Low-HP Critical state (<30% HP) crimson warning pulse & brow sweat bead,
 * plus Char's <50% HP Furnace Overdrive passive heat aura!
 */
internal fun DrawScope.drawLowHpAndPassiveOverlay(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    animTime: Float,
    hpRatio: Float
) {
    // Char's gameplay passive: <50% HP triggers +30% Fire Damage -> continuous Overdrive heat aura!
    if (style.starterId == "char" && hpRatio < 0.50f && hpRatio > 0f) {
        val overdrivePulse = (0.65f + 0.35f * sin(animTime * 6.0f)).coerceIn(0f, 1f)
        val odRadius = (rx * 1.65f).coerceAtLeast(1f)
        drawCircle(
            brush = Brush.radialGradient(
                listOf(
                    Color(0xFFFFF2B0).copy(alpha = (0.28f * overdrivePulse).coerceIn(0f, 1f)),
                    Color(0xFFFF6E24).copy(alpha = (0.22f * overdrivePulse).coerceIn(0f, 1f)),
                    Color.Transparent
                ),
                center = center,
                radius = odRadius
            ),
            radius = odRadius,
            center = center
        )
        for (i in 0 until 3) {
            val phase = ((animTime * 0.8f + i * 0.333f) % 1f).let { if (it < 0f) it + 1f else it }.coerceIn(0f, 1f)
            val sx = center.x + (i - 1) * rx * 0.65f + sin(animTime * 4f + i) * rx * 0.12f
            val sy = center.y + ry * 0.2f - phase * ry * 1.55f
            drawCircle(Color(0xFFFFF4B8).copy(alpha = ((1f - phase) * 0.9f).coerceIn(0f, 1f)), rx * 0.09f, Offset(sx, sy))
        }
    }

    // Universal <30% HP critical danger warning pulse + anxious sweat droplet
    if (hpRatio < 0.30f && hpRatio > 0f) {
        val dangerPulse = (0.35f + 0.65f * abs(sin(animTime * 4.0f)))
        drawCircle(
            color = CrimsonRed.copy(alpha = 0.42f * dangerPulse),
            radius = rx * (1.22f + dangerPulse * 0.10f),
            center = center,
            style = Stroke(width = 2.6f)
        )
        // Tiny animated anime sweat-drop near upper right temple
        val dropSlide = ((animTime * 0.5f) % 1f).let { if (it < 0f) it + 1f else it }
        val dx = center.x + rx * 0.82f
        val dy = center.y - ry * 0.62f + dropSlide * ry * 0.30f
        val dropAlpha = (1f - dropSlide * 0.7f).coerceIn(0f, 1f)
        val drop = Path().apply {
            moveTo(dx, dy - ry * 0.16f)
            quadraticTo(dx + rx * 0.11f, dy + ry * 0.04f, dx, dy + ry * 0.12f)
            quadraticTo(dx - rx * 0.11f, dy + ry * 0.04f, dx, dy - ry * 0.16f)
            close()
        }
        drawPath(drop, Color(0xFF9BEFFF).copy(alpha = dropAlpha))
        drawPath(drop, EspressoDark.copy(alpha = dropAlpha * 0.85f), style = Stroke(1.3f, join = StrokeJoin.Round))
    }
}

/**
 * Track 5: Charming species-specific idle personality quirks & pedestal tap easter eggs!
 * Smoothly animates over `quirkProgress` (1f -> 0f).
 */
internal fun DrawScope.drawSpeciesPersonalityQuirk(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    quirkProgress: Float
) {
    val p = quirkProgress.coerceIn(0f, 1f)
    if (p <= 0.02f) return
    val t = 1f - p
    val alpha = sin(p * PI.toFloat()).coerceIn(0f, 1f)

    when (style.starterId) {
        "stump" -> {
            // Left shoulder mushroom puffs out happy drifting golden-lime spore clouds!
            val origin = Offset(center.x - rx * 0.76f, center.y - ry * 0.72f)
            for (i in 0 until 4) {
                val spreadX = (-0.55f + i * 0.36f) * rx * t
                val riseY = -(0.45f + i * 0.18f) * ry * t
                val pos = Offset(origin.x + spreadX, origin.y + riseY)
                drawCircle(Color(0xFFC8FF78).copy(alpha = alpha * 0.55f), rx * (0.14f + t * 0.08f), pos)
                drawCircle(GoldAccent.copy(alpha = alpha * 0.92f), rx * 0.06f, pos)
            }
        }
        "char" -> {
            // Chest furnace hiccups a cute puff of fiery mini-ember sneeze sparks!
            val origin = Offset(center.x, center.y + ry * 0.25f)
            for (i in 0 until 5) {
                val a = -0.85f + i * 0.42f
                val dist = rx * (0.55f + t * 1.15f)
                val pos = Offset(origin.x + cos(a) * dist, origin.y + sin(a) * dist * 0.65f - t * ry * 0.35f)
                drawCircle(Color(0xFFFF7A29).copy(alpha = alpha * 0.85f), rx * 0.10f * p, pos)
                drawCircle(Color(0xFFFFFAD2).copy(alpha = alpha), rx * 0.05f * p, pos)
            }
        }
        "shell" -> {
            // Playful hydro-top spin ring & sparkling aqua water droplets
            val spinR = rx * (1.25f + t * 0.55f)
            drawArc(
                color = Color(0xFF7BE8FF).copy(alpha = alpha * 0.85f),
                startAngle = t * 360f,
                sweepAngle = 160f,
                useCenter = false,
                topLeft = Offset(center.x - spinR, center.y - spinR * 0.55f),
                size = Size(spinR * 2f, spinR * 1.10f),
                style = Stroke(width = 3.6f * p + 1.2f, cap = StrokeCap.Round)
            )
            for (i in 0 until 4) {
                val a = t * 6.283f + i * 1.57f
                val dp = Offset(center.x + cos(a) * spinR, center.y + sin(a) * spinR * 0.55f)
                drawCircle(Color.White.copy(alpha = alpha), rx * 0.08f, dp)
            }
        }
        "spark" -> {
            // Golden shrine bell chimes with expanding golden musical sound-wave arcs & ear sparks!
            val bellPos = Offset(center.x, center.y + ry * 0.62f)
            for (ring in 0..1) {
                val r = rx * (0.35f + (t + ring * 0.25f).coerceAtMost(1f) * 1.15f)
                drawCircle(GoldAccent.copy(alpha = alpha * (0.85f - ring * 0.35f)), r, bellPos, style = Stroke(2.4f))
            }
        }
        "wisp" -> {
            // Lantern puffs 3 cute floating mischievous mini soul-wisps upward!
            for (i in -1..1) {
                val pos = Offset(center.x + i * rx * (0.45f + t * 0.45f), center.y - ry * (0.95f + t * 0.85f))
                drawCircle(Color(0xFF8EF7FF).copy(alpha = alpha * 0.50f), rx * 0.16f, pos)
                drawCircle(Color.White.copy(alpha = alpha * 0.92f), rx * 0.08f, pos)
            }
        }
        else -> {
            // Drake: Proud twinkling 4-point star sparkles bursting around crystal wings!
            for (i in 0 until 4) {
                val a = -0.6f + i * 1.57f + t * 0.8f
                val sp = Offset(center.x + cos(a) * rx * (1.15f + t * 0.55f), center.y + sin(a) * ry * (0.90f + t * 0.45f))
                val sr = rx * (0.14f * alpha)
                drawLine(GoldAccent.copy(alpha = alpha), Offset(sp.x - sr, sp.y), Offset(sp.x + sr, sp.y), 2.2f, StrokeCap.Round)
                drawLine(Color.White.copy(alpha = alpha), Offset(sp.x, sp.y - sr), Offset(sp.x, sp.y + sr), 2.2f, StrokeCap.Round)
            }
        }
    }
}

/**
 * Renders the back-layer radiant energy pillar and expanding transformation rings
 * behind the hero sprite during an evolution burst (`evolutionFxProgress` 1f -> 0f).
 */
internal fun DrawScope.drawEvolutionBurstBackLayer(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    evolutionFxProgress: Float,
    animTime: Float
) {
    val p = evolutionFxProgress.coerceIn(0f, 1f)
    if (p <= 0.01f) return

    val t = 1f - p
    val primaryCol = evolutionPrimaryFxColor(style)
    val accentCol = evolutionAccentFxColor(style)

    val pillarAlpha = (p * 0.58f).coerceIn(0f, 0.58f)
    val pillarWidth = rx * (1.55f + sin(t * PI.toFloat()) * 0.85f)
    val pillarHeight = ry * (3.2f + t * 1.4f)
    drawRect(
        brush = Brush.verticalGradient(
            colors = listOf(
                Color.Transparent,
                primaryCol.copy(alpha = pillarAlpha * 0.65f),
                Color.White.copy(alpha = pillarAlpha),
                accentCol.copy(alpha = pillarAlpha * 0.72f),
                Color.Transparent
            ),
            startY = center.y - pillarHeight,
            endY = center.y + ry * 1.35f
        ),
        topLeft = Offset(center.x - pillarWidth * 0.5f, center.y - pillarHeight),
        size = Size(pillarWidth, pillarHeight + ry * 1.35f)
    )

    val outerScale = 0.85f + t * 2.15f
    drawOval(
        color = primaryCol.copy(alpha = (p * 0.88f).coerceIn(0f, 0.9f)),
        topLeft = Offset(center.x - rx * outerScale, center.y + ry * 0.35f - ry * 0.42f * outerScale),
        size = Size(rx * 2f * outerScale, ry * 0.84f * outerScale),
        style = Stroke(width = (5.2f * p).coerceAtLeast(1.4f))
    )
    val innerScale = 0.55f + (t * 1.65f)
    drawCircle(
        color = Color.White.copy(alpha = (p * 0.76f).coerceIn(0f, 0.8f)),
        radius = rx * innerScale,
        center = center,
        style = Stroke(width = (4.0f * p).coerceAtLeast(1.2f))
    )

    if (p > 0.62f) {
        val flashT = ((p - 0.62f) / 0.38f).coerceIn(0f, 1f)
        val flashR = (rx * (2.4f + flashT * 0.8f)).coerceAtLeast(1f)
        drawCircle(
            brush = Brush.radialGradient(
                listOf(
                    Color.White.copy(alpha = flashT * 0.78f),
                    accentCol.copy(alpha = flashT * 0.45f),
                    Color.Transparent
                ),
                center = center,
                radius = flashR
            ),
            radius = flashR,
            center = center
        )
    }
}

/**
 * Renders front-layer spiraling species-themed evolution particles for ALL 6 starters
 * plus subtle persistent evolved-tier ambient motes when `scale > 1.05f`.
 */
internal fun DrawScope.drawEvolutionParticlesFrontLayer(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    animTime: Float,
    orbitAngle: Float,
    scale: Float,
    evolutionFxProgress: Float
) {
    val burst = evolutionFxProgress.coerceIn(0f, 1f)
    val isEvolved = scale > 1.05f
    if (burst <= 0.01f && !isEvolved) return

    val primaryCol = evolutionPrimaryFxColor(style)
    val accentCol = evolutionAccentFxColor(style)

    // 1. Subtle continuous species evolution motes for Tier 1 / Tier 2 evolved sprites
    if (isEvolved) {
        val count = if (scale >= 1.24f) 5 else 3
        val twoPi = (2.0 * PI).toFloat()
        for (i in 0 until count) {
            val phase = ((animTime / twoPi + i.toFloat() / count) % 1f).let { if (it < 0f) it + 1f else it }
            val angle = orbitAngle + i * (twoPi / count)
            val orbitR = rx * (1.28f + 0.22f * sin(phase * PI.toFloat()))
            val px = center.x + cos(angle) * orbitR
            val py = center.y + ry * 0.58f - phase * ry * 1.95f
            val alpha = sin(phase * PI.toFloat()).coerceIn(0f, 1f) * 0.72f
            drawSpeciesEvolutionMote(
                starterId = style.starterId,
                pos = Offset(px, py),
                radius = rx * (0.11f + 0.04f * sin(phase * PI.toFloat())),
                rotationDeg = angle * 57.29578f + phase * 360f,
                primaryCol = primaryCol,
                accentCol = accentCol,
                alpha = alpha
            )
        }
    }

    // 2. High-energy spiraling species transformation particle shower during active evolution
    if (burst > 0.01f) {
        val t = 1f - burst
        val moteCount = 12
        for (i in 0 until moteCount) {
            val frac = i.toFloat() / moteCount
            val spiralAngle = frac * 2f * PI.toFloat() + t * 5.8f
            val radialExpand = rx * (0.75f + t * 1.55f + (i % 3) * 0.22f)
            val rise = ry * (0.55f - t * (1.95f + (i % 4) * 0.32f))
            val px = center.x + cos(spiralAngle) * radialExpand
            val py = center.y + rise + sin(spiralAngle) * ry * 0.34f
            val moteAlpha = (burst * 1.15f).coerceIn(0f, 0.95f)
            val moteSize = rx * (0.16f + (i % 3) * 0.045f) * (0.55f + burst * 0.65f)
            drawSpeciesEvolutionMote(
                starterId = style.starterId,
                pos = Offset(px, py),
                radius = moteSize,
                rotationDeg = spiralAngle * 57.29578f,
                primaryCol = primaryCol,
                accentCol = accentCol,
                alpha = moteAlpha
            )
        }

        val arcSweep = 125f * burst + 40f
        drawArc(
            color = Color.White.copy(alpha = burst * 0.85f),
            startAngle = t * 320f,
            sweepAngle = arcSweep,
            useCenter = false,
            topLeft = Offset(center.x - rx * (1.35f + t * 0.65f), center.y - ry * (0.95f + t * 0.45f)),
            size = Size(rx * 2f * (1.35f + t * 0.65f), ry * 2f * (0.95f + t * 0.45f)),
            style = Stroke(width = (4.2f * burst).coerceAtLeast(1.4f), cap = StrokeCap.Round)
        )
        drawArc(
            color = primaryCol.copy(alpha = burst * 0.78f),
            startAngle = -t * 280f + 160f,
            sweepAngle = arcSweep,
            useCenter = false,
            topLeft = Offset(center.x - rx * (1.50f + t * 0.75f), center.y - ry * (1.05f + t * 0.50f)),
            size = Size(rx * 2f * (1.50f + t * 0.75f), ry * 2f * (1.05f + t * 0.50f)),
            style = Stroke(width = (3.4f * burst).coerceAtLeast(1.2f), cap = StrokeCap.Round)
        )
    }
}

private fun DrawScope.drawSpeciesEvolutionMote(
    starterId: String,
    pos: Offset,
    radius: Float,
    rotationDeg: Float,
    primaryCol: Color,
    accentCol: Color,
    alpha: Float
) {
    if (alpha <= 0.02f || radius <= 0.5f) return
    when (starterId) {
        "stump" -> {
            rotate(degrees = rotationDeg, pivot = pos) {
                val leaf = Path().apply {
                    moveTo(pos.x, pos.y - radius * 1.45f)
                    quadraticTo(pos.x + radius * 0.95f, pos.y, pos.x, pos.y + radius * 1.25f)
                    quadraticTo(pos.x - radius * 0.95f, pos.y, pos.x, pos.y - radius * 1.45f)
                    close()
                }
                drawPath(leaf, primaryCol.copy(alpha = alpha))
                drawPath(leaf, EspressoDark.copy(alpha = alpha * 0.7f), style = Stroke(1.3f, join = StrokeJoin.Round))
            }
            drawCircle(accentCol.copy(alpha = alpha * 0.92f), radius * 0.42f, pos)
        }
        "char" -> {
            rotate(degrees = rotationDeg * 0.35f, pivot = pos) {
                val flame = Path().apply {
                    moveTo(pos.x, pos.y - radius * 1.65f)
                    lineTo(pos.x + radius * 0.85f, pos.y + radius * 0.20f)
                    lineTo(pos.x, pos.y + radius * 1.05f)
                    lineTo(pos.x - radius * 0.85f, pos.y + radius * 0.20f)
                    close()
                }
                drawPath(flame, primaryCol.copy(alpha = alpha))
                drawCircle(Color.White.copy(alpha = alpha * 0.92f), radius * 0.44f, pos)
            }
        }
        "shell" -> {
            drawCircle(primaryCol.copy(alpha = alpha * 0.42f), radius * 1.15f, pos)
            drawCircle(Color.White.copy(alpha = alpha * 0.86f), radius * 1.15f, pos, style = Stroke(1.6f))
            drawCircle(Color.White.copy(alpha = alpha * 0.95f), radius * 0.38f, Offset(pos.x - radius * 0.34f, pos.y - radius * 0.34f))
        }
        "spark" -> {
            // Crackling zigzag golden thunderbolt mote
            rotate(degrees = rotationDeg * 0.5f, pivot = pos) {
                val bolt = Path().apply {
                    moveTo(pos.x + radius * 0.35f, pos.y - radius * 1.45f)
                    lineTo(pos.x - radius * 0.55f, pos.y + radius * 0.05f)
                    lineTo(pos.x + radius * 0.20f, pos.y + radius * 0.10f)
                    lineTo(pos.x - radius * 0.35f, pos.y + radius * 1.45f)
                }
                drawPath(bolt, primaryCol.copy(alpha = alpha), style = Stroke(radius * 0.52f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                drawPath(bolt, Color.White.copy(alpha = alpha * 0.92f), style = Stroke(radius * 0.22f, cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
        }
        "wisp" -> {
            // Ethereal teardrop ghost-fire spirit wisp
            val wisp = Path().apply {
                moveTo(pos.x, pos.y - radius * 1.55f)
                quadraticTo(pos.x + radius * 1.05f, pos.y + radius * 0.15f, pos.x, pos.y + radius * 1.05f)
                quadraticTo(pos.x - radius * 1.05f, pos.y + radius * 0.15f, pos.x, pos.y - radius * 1.55f)
                close()
            }
            drawPath(wisp, primaryCol.copy(alpha = alpha * 0.88f))
            drawCircle(Color.White.copy(alpha = alpha * 0.95f), radius * 0.42f, Offset(pos.x, pos.y + radius * 0.15f))
        }
        else -> {
            // Drake: 4-point astral sapphire-gold crystal star
            rotate(degrees = rotationDeg, pivot = pos) {
                val star = Path().apply {
                    moveTo(pos.x, pos.y - radius * 1.45f)
                    lineTo(pos.x + radius * 0.45f, pos.y - radius * 0.45f)
                    lineTo(pos.x + radius * 1.45f, pos.y)
                    lineTo(pos.x + radius * 0.45f, pos.y + radius * 0.45f)
                    lineTo(pos.x, pos.y + radius * 1.45f)
                    lineTo(pos.x - radius * 0.45f, pos.y + radius * 0.45f)
                    lineTo(pos.x - radius * 1.45f, pos.y)
                    lineTo(pos.x - radius * 0.45f, pos.y - radius * 0.45f)
                    close()
                }
                drawPath(star, primaryCol.copy(alpha = alpha))
                drawCircle(Color.White.copy(alpha = alpha * 0.95f), radius * 0.36f, pos)
            }
        }
    }
}

/**
 * Renders unmistakable damaged feedback over ALL 6 sprites:
 * - Crisp white-crimson impact flash ring & starburst hit-lines
 * - Species-themed hurt debris for all 6 heroes
 */
internal fun DrawScope.drawHurtStateOverlay(
    style: EvolutionVisualStyle,
    center: Offset,
    rx: Float,
    ry: Float,
    hurtProgress: Float
) {
    val p = hurtProgress.coerceIn(0f, 1f)
    if (p <= 0.01f) return
    val t = 1f - p

    if (p > 0.55f) {
        val flashAlpha = ((p - 0.55f) / 0.45f).coerceIn(0f, 1f)
        val hurtR = (rx * 1.55f).coerceAtLeast(1f)
        drawCircle(
            brush = Brush.radialGradient(
                listOf(
                    Color.White.copy(alpha = flashAlpha * 0.52f),
                    CrimsonRed.copy(alpha = flashAlpha * 0.35f),
                    Color.Transparent
                ),
                center = center,
                radius = hurtR
            ),
            radius = hurtR,
            center = center
        )
    }

    val debrisCol = evolutionPrimaryFxColor(style)
    val spikeCount = 6
    for (i in 0 until spikeCount) {
        val a = i * (2f * PI.toFloat() / spikeCount) + 0.35f
        val innerR = rx * (0.85f + t * 0.35f)
        val outerR = rx * (1.28f + t * 0.72f)
        val start = Offset(center.x + cos(a) * innerR, center.y + sin(a) * innerR * 0.85f)
        val end = Offset(center.x + cos(a) * outerR, center.y + sin(a) * outerR * 0.85f)
        drawLine(
            color = (if (i % 2 == 0) Color.White else CrimsonRed).copy(alpha = p * 0.88f),
            start = start,
            end = end,
            strokeWidth = (3.2f * p).coerceAtLeast(1.2f),
            cap = StrokeCap.Round
        )
        val chipPos = Offset(center.x + cos(a + 0.25f) * (outerR * 1.06f), center.y + sin(a + 0.25f) * (outerR * 0.90f))
        when (style.starterId) {
            "shell" -> drawCircle(debrisCol.copy(alpha = p * 0.82f), rx * 0.11f * p, chipPos, style = Stroke(1.8f))
            "drake" -> {
                val sr = rx * 0.12f * p
                drawLine(Color.White.copy(alpha = p * 0.9f), Offset(chipPos.x - sr, chipPos.y), Offset(chipPos.x + sr, chipPos.y), 2.0f, StrokeCap.Round)
                drawLine(debrisCol.copy(alpha = p * 0.9f), Offset(chipPos.x, chipPos.y - sr), Offset(chipPos.x, chipPos.y + sr), 2.0f, StrokeCap.Round)
            }
            else -> drawCircle(debrisCol.copy(alpha = p * 0.88f), rx * 0.10f * p, chipPos)
        }
    }
}

/**
 * Renders directional high-impact strike overlays tailored to ALL 6 starters
 * right on top of the character when attacking (`attackProgress` 1f -> 0f).
 */
internal fun DrawScope.drawSpeciesActionImpactOverlay(ctx: HeroArtContext) {
    val p = ctx.attackProgress.coerceIn(0f, 1f)
    if (p <= 0.02f) return
    val t = 1f - p
    val impactAlpha = (sin(p * PI.toFloat()) * 0.95f).coerceIn(0f, 0.95f)
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val facingDeg = ctx.facingAngle * 57.29578f
    val dirX = cos(ctx.facingAngle)
    val dirY = sin(ctx.facingAngle)

    when (ctx.style.starterId) {
        "stump" -> {
            val arcR = rx * (1.42f + t * 0.42f)
            drawArc(
                color = Color(0xFF9DF86A).copy(alpha = impactAlpha * 0.86f),
                startAngle = facingDeg - 68f + t * 24f,
                sweepAngle = 136f * (0.65f + p * 0.35f),
                useCenter = false,
                topLeft = Offset(c.x - arcR, c.y - arcR * 0.82f),
                size = Size(arcR * 2f, arcR * 1.64f),
                style = Stroke(width = (8.5f * p).coerceAtLeast(2.0f), cap = StrokeCap.Round)
            )
            val innerArcR = arcR * 0.84f
            drawArc(
                color = Color(0xFFEFFFBD).copy(alpha = impactAlpha * 0.94f),
                startAngle = facingDeg - 52f + t * 28f,
                sweepAngle = 104f * (0.6f + p * 0.4f),
                useCenter = false,
                topLeft = Offset(c.x - innerArcR, c.y - innerArcR * 0.82f),
                size = Size(innerArcR * 2f, innerArcR * 1.64f),
                style = Stroke(width = (3.8f * p).coerceAtLeast(1.2f), cap = StrokeCap.Round)
            )
            val tipCenter = Offset(c.x + dirX * arcR * 0.96f, c.y + dirY * arcR * 0.78f)
            for (s in listOf(-0.45f, 0f, 0.45f)) {
                val sa = ctx.facingAngle + s
                drawLine(
                    color = GoldAccent.copy(alpha = impactAlpha * 0.85f),
                    start = tipCenter,
                    end = Offset(tipCenter.x + cos(sa) * rx * 0.56f * p, tipCenter.y + sin(sa) * ry * 0.48f * p),
                    strokeWidth = (3.2f * p).coerceAtLeast(1.2f),
                    cap = StrokeCap.Round
                )
            }
        }
        "char" -> {
            val slamCenter = Offset(c.x + dirX * rx * (0.72f + t * 0.34f), c.y + dirY * ry * (0.58f + t * 0.28f))
            val blastR = rx * (0.85f + t * 0.88f)
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(
                        Color(0xFFFFFAD2).copy(alpha = impactAlpha * 0.72f),
                        ctx.style.accentColor.copy(alpha = impactAlpha * 0.48f),
                        Color.Transparent
                    ),
                    center = slamCenter,
                    radius = blastR
                ),
                radius = blastR,
                center = slamCenter
            )
            drawArc(
                color = ctx.style.eyeColor.copy(alpha = impactAlpha * 0.92f),
                startAngle = facingDeg - 58f,
                sweepAngle = 116f,
                useCenter = false,
                topLeft = Offset(c.x - rx * (1.32f + t * 0.52f), c.y - ry * (1.16f + t * 0.44f)),
                size = Size(rx * 2f * (1.32f + t * 0.52f), ry * 2f * (1.16f + t * 0.44f)),
                style = Stroke(width = (9.0f * p).coerceAtLeast(2.2f), cap = StrokeCap.Round)
            )
            for (k in -1..1) {
                val ka = ctx.facingAngle + k * 0.34f
                val start = Offset(c.x + cos(ka) * rx * 0.88f, c.y + sin(ka) * ry * 0.72f)
                val end = Offset(c.x + cos(ka) * rx * (1.68f + t * 0.36f), c.y + sin(ka) * ry * (1.38f + t * 0.30f))
                drawLine(Color(0xFFFFF2B0).copy(alpha = impactAlpha * 0.90f), start, end, (4.2f * p).coerceAtLeast(1.4f), StrokeCap.Round)
            }
        }
        "shell" -> {
            val spinR = rx * (1.46f + t * 0.40f)
            val spinSpin = t * 240f
            drawArc(
                color = Color(0xFF7BE8FF).copy(alpha = impactAlpha * 0.90f),
                startAngle = facingDeg + spinSpin - 75f,
                sweepAngle = 150f,
                useCenter = false,
                topLeft = Offset(c.x - spinR, c.y - spinR * 0.68f),
                size = Size(spinR * 2f, spinR * 1.36f),
                style = Stroke(width = (7.8f * p).coerceAtLeast(2.0f), cap = StrokeCap.Round)
            )
            drawArc(
                color = Color.White.copy(alpha = impactAlpha * 0.95f),
                startAngle = facingDeg - spinSpin + 105f,
                sweepAngle = 135f,
                useCenter = false,
                topLeft = Offset(c.x - spinR * 0.86f, c.y - spinR * 0.58f),
                size = Size(spinR * 1.72f, spinR * 1.16f),
                style = Stroke(width = (4.2f * p).coerceAtLeast(1.4f), cap = StrokeCap.Round)
            )
            for (d in -1..1) {
                val da = ctx.facingAngle + d * 0.28f
                val dist = rx * (1.28f + t * 0.68f + abs(d) * 0.14f)
                val dropPos = Offset(c.x + cos(da) * dist, c.y + sin(da) * dist * 0.82f)
                drawCircle(Color(0xFF7BE8FF).copy(alpha = impactAlpha * 0.72f), rx * 0.14f * p, dropPos)
                drawCircle(Color.White.copy(alpha = impactAlpha * 0.96f), rx * 0.07f * p, dropPos)
            }
        }
        "spark" -> {
            // Crackling zigzag thunder-whip bolt & golden shrine bell shock-ring
            val boltOrigin = Offset(c.x + dirX * rx * 0.68f, c.y + dirY * ry * 0.55f)
            val boltTip = Offset(c.x + dirX * rx * (1.85f + t * 0.45f), c.y + dirY * ry * (1.52f + t * 0.35f))
            val perpX = -dirY * rx * 0.32f
            val perpY = dirX * ry * 0.32f
            val mid1 = Offset(boltOrigin.x + (boltTip.x - boltOrigin.x) * 0.36f + perpX, boltOrigin.y + (boltTip.y - boltOrigin.y) * 0.36f + perpY)
            val mid2 = Offset(boltOrigin.x + (boltTip.x - boltOrigin.x) * 0.68f - perpX, boltOrigin.y + (boltTip.y - boltOrigin.y) * 0.68f - perpY)
            val zigzag = Path().apply {
                moveTo(boltOrigin.x, boltOrigin.y)
                lineTo(mid1.x, mid1.y)
                lineTo(mid2.x, mid2.y)
                lineTo(boltTip.x, boltTip.y)
            }
            drawPath(zigzag, GoldAccent.copy(alpha = impactAlpha * 0.92f), style = Stroke((7.2f * p).coerceAtLeast(2.0f), cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawPath(zigzag, Color.White.copy(alpha = impactAlpha), style = Stroke((2.8f * p).coerceAtLeast(1.1f), cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawArc(
                color = Color(0xFFFFF282).copy(alpha = impactAlpha * 0.82f),
                startAngle = facingDeg - 62f,
                sweepAngle = 124f,
                useCenter = false,
                topLeft = Offset(c.x - rx * (1.38f + t * 0.36f), c.y - ry * (1.16f + t * 0.30f)),
                size = Size(rx * 2f * (1.38f + t * 0.36f), ry * 2f * (1.16f + t * 0.30f)),
                style = Stroke((5.0f * p).coerceAtLeast(1.6f), cap = StrokeCap.Round)
            )
        }
        "wisp" -> {
            // Crescent moon-teal soulfire wave + expanding spectral ring
            val waveR = rx * (1.38f + t * 0.56f)
            drawArc(
                color = Color(0xFF5EF2E8).copy(alpha = impactAlpha * 0.88f),
                startAngle = facingDeg - 74f,
                sweepAngle = 148f,
                useCenter = false,
                topLeft = Offset(c.x - waveR, c.y - waveR * 0.88f),
                size = Size(waveR * 2f, waveR * 1.76f),
                style = Stroke((8.2f * p).coerceAtLeast(2.0f), cap = StrokeCap.Round)
            )
            drawArc(
                color = Color(0xFFD5B4FF).copy(alpha = impactAlpha * 0.90f),
                startAngle = facingDeg - 54f + t * 30f,
                sweepAngle = 108f,
                useCenter = false,
                topLeft = Offset(c.x - waveR * 0.82f, c.y - waveR * 0.72f),
                size = Size(waveR * 1.64f, waveR * 1.44f),
                style = Stroke((3.8f * p).coerceAtLeast(1.2f), cap = StrokeCap.Round)
            )
        }
        else -> {
            // Drake: Twin astral star-blade wing gusts + 4-point diamond glint
            val gustR = rx * (1.48f + t * 0.48f)
            drawArc(
                color = Color(0xFF7BE8FF).copy(alpha = impactAlpha * 0.88f),
                startAngle = facingDeg - 64f,
                sweepAngle = 128f,
                useCenter = false,
                topLeft = Offset(c.x - gustR, c.y - gustR * 0.84f),
                size = Size(gustR * 2f, gustR * 1.68f),
                style = Stroke((8.0f * p).coerceAtLeast(2.0f), cap = StrokeCap.Round)
            )
            drawArc(
                color = GoldAccent.copy(alpha = impactAlpha * 0.94f),
                startAngle = facingDeg - 46f,
                sweepAngle = 92f,
                useCenter = false,
                topLeft = Offset(c.x - gustR * 0.86f, c.y - gustR * 0.72f),
                size = Size(gustR * 1.72f, gustR * 1.44f),
                style = Stroke((3.8f * p).coerceAtLeast(1.2f), cap = StrokeCap.Round)
            )
            val starTip = Offset(c.x + dirX * gustR * 0.98f, c.y + dirY * gustR * 0.82f)
            val sr = rx * 0.34f * p
            drawLine(Color.White.copy(alpha = impactAlpha), Offset(starTip.x - sr, starTip.y), Offset(starTip.x + sr, starTip.y), 3.0f, StrokeCap.Round)
            drawLine(GoldAccent.copy(alpha = impactAlpha), Offset(starTip.x, starTip.y - sr), Offset(starTip.x, starTip.y + sr), 3.0f, StrokeCap.Round)
        }
    }
}

private fun evolutionPrimaryFxColor(style: EvolutionVisualStyle): Color = when (style.starterId) {
    "stump" -> Color(0xFF7BF26B)
    "char" -> Color(0xFFFF7A29)
    "shell" -> Color(0xFF56DCFF)
    "spark" -> Color(0xFFFFD84D)
    "wisp" -> Color(0xFF7DF5E6)
    else -> Color(0xFF7CC8FF)
}

private fun evolutionAccentFxColor(style: EvolutionVisualStyle): Color = when (style.starterId) {
    "stump" -> GoldAccent
    "char" -> Color(0xFFFFEB85)
    "shell" -> Color(0xFFD6FCFF)
    "spark" -> Color(0xFFFFF8C4)
    "wisp" -> Color(0xFFC59BFF)
    else -> GoldAccent
}
