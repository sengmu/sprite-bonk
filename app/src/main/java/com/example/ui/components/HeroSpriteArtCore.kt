package com.example.ui.components

import androidx.compose.ui.geometry.CornerRadius
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
import com.example.game.evolution.EvolutionCrownStyle
import com.example.game.evolution.EvolutionVisualStyle
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

internal data class HeroArtContext(
    val style: EvolutionVisualStyle,
    val bodyCenter: Offset,
    val rx: Float,
    val ry: Float,
    val animTime: Float,
    val orbitAngle: Float,
    val lookX: Float,
    val lookY: Float,
    val footSwing: Float,
    val primary: Color,
    val secondary: Color,
    val scale: Float,
    val isAttacking: Boolean,
    val isUltActive: Boolean
)

internal fun DrawScope.drawGlossySpecular(
    center: Offset,
    radiusX: Float,
    radiusY: Float,
    alpha: Float = 0.34f
) {
    drawOval(
        color = Color.White.copy(alpha = alpha),
        topLeft = Offset(center.x - radiusX, center.y - radiusY),
        size = Size(radiusX * 2f, radiusY * 2f)
    )
}

internal fun DrawScope.drawStylizedLeaf(
    base: Offset,
    angleDeg: Float,
    length: Float,
    width: Float,
    fillColor: Color,
    highlightColor: Color
) {
    rotate(degrees = angleDeg, pivot = base) {
        val leaf = Path().apply {
            moveTo(base.x, base.y)
            quadraticTo(base.x - width * 0.72f, base.y - length * 0.48f, base.x, base.y - length)
            quadraticTo(base.x + width * 0.72f, base.y - length * 0.48f, base.x, base.y)
            close()
        }
        drawPath(
            path = leaf,
            brush = Brush.verticalGradient(
                listOf(highlightColor, fillColor),
                startY = base.y - length,
                endY = base.y
            )
        )
        drawLine(
            color = highlightColor.copy(alpha = 0.78f),
            start = Offset(base.x, base.y - length * 0.14f),
            end = Offset(base.x, base.y - length * 0.78f),
            strokeWidth = (width * 0.12f).coerceIn(1.4f, 3.2f),
            cap = StrokeCap.Round
        )
        drawPath(
            path = leaf,
            color = EspressoDark,
            style = Stroke(width = 2.1f, join = StrokeJoin.Round)
        )
    }
}

internal fun DrawScope.drawGlowingPupilEye(
    center: Offset,
    radius: Float,
    glowColor: Color,
    coreColor: Color = Color.White,
    angryTilt: Float = 0f
) {
    drawCircle(glowColor.copy(alpha = 0.34f), radius * 1.95f, center)
    drawCircle(EspressoDark, radius * 1.18f, center)
    drawCircle(glowColor, radius * 0.92f, center)
    drawCircle(coreColor.copy(alpha = 0.92f), radius * 0.42f, Offset(center.x - radius * 0.24f, center.y - radius * 0.24f))
    if (angryTilt != 0f) {
        val bw = radius * 1.45f
        val dy = radius * 0.52f * angryTilt
        drawLine(
            color = EspressoDark,
            start = Offset(center.x - bw, center.y - radius * 0.92f - dy),
            end = Offset(center.x + bw, center.y - radius * 0.92f + dy),
            strokeWidth = (radius * 0.55f).coerceIn(2.2f, 4.5f),
            cap = StrokeCap.Round
        )
    }
}

/**
 * 树桩洞傀 (stump) — Carved Ancient Stump Spirit:
 * Sculpted gnarled bark trunk, concentric heartwood ring crown, living moss shoulders,
 * shadowed hollow with luminous puppeteer eyes, and lush foliage / blossom / shadow-bramble branches.
 */
internal fun DrawScope.drawStumpHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val sway = sin(ctx.animTime * 0.9f) * (rx * 0.10f)

    // 1. Knobby root-claw feet
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing else -ctx.footSwing
        val footCenter = Offset(c.x + side * rx * 0.56f, c.y + ry * 0.86f + fSwing)
        drawOval(
            color = ctx.secondary,
            topLeft = Offset(footCenter.x - rx * 0.34f, footCenter.y - ry * 0.20f),
            size = Size(rx * 0.68f, ry * 0.42f)
        )
        drawOval(
            color = EspressoDark,
            topLeft = Offset(footCenter.x - rx * 0.34f, footCenter.y - ry * 0.20f),
            size = Size(rx * 0.68f, ry * 0.42f),
            style = Stroke(2.4f)
        )
    }

    // 2. Sculpted organic tapered stump trunk (wider flared root base)
    val trunkPath = Path().apply {
        moveTo(c.x - rx * 0.90f, c.y - ry * 0.82f)
        quadraticTo(c.x - rx * 1.06f, c.y + ry * 0.16f, c.x - rx * 1.12f, c.y + ry * 0.86f)
        quadraticTo(c.x, c.y + ry * 1.05f, c.x + rx * 1.12f, c.y + ry * 0.86f)
        quadraticTo(c.x + rx * 1.06f, c.y + ry * 0.16f, c.x + rx * 0.90f, c.y - ry * 0.82f)
        close()
    }
    drawPath(
        path = trunkPath,
        brush = Brush.horizontalGradient(
            colors = listOf(
                ctx.secondary,
                ctx.primary,
                ctx.primary.copy(alpha = 0.95f),
                ctx.secondary.copy(alpha = 0.88f)
            ),
            startX = c.x - rx * 1.12f,
            endX = c.x + rx * 1.12f
        )
    )

    // Bark vertical grain grooves + warm side highlight
    drawLine(
        color = EspressoDark.copy(alpha = 0.38f),
        start = Offset(c.x - rx * 0.58f, c.y - ry * 0.46f),
        end = Offset(c.x - rx * 0.68f, c.y + ry * 0.72f),
        strokeWidth = 2.6f,
        cap = StrokeCap.Round
    )
    drawLine(
        color = EspressoDark.copy(alpha = 0.35f),
        start = Offset(c.x + rx * 0.58f, c.y - ry * 0.40f),
        end = Offset(c.x + rx * 0.70f, c.y + ry * 0.70f),
        strokeWidth = 2.6f,
        cap = StrokeCap.Round
    )
    drawLine(
        color = Color(0xFFFFE5B8).copy(alpha = 0.24f),
        start = Offset(c.x - rx * 0.74f, c.y - ry * 0.48f),
        end = Offset(c.x - rx * 0.80f, c.y + ry * 0.44f),
        strokeWidth = 3.2f,
        cap = StrokeCap.Round
    )

    // Living shoulder moss drapes
    drawOval(
        color = style.accentColor.copy(alpha = 0.92f),
        topLeft = Offset(c.x - rx * 1.04f, c.y - ry * 0.62f),
        size = Size(rx * 0.56f, ry * 0.38f)
    )
    drawOval(
        color = style.accentColor.copy(alpha = 0.88f),
        topLeft = Offset(c.x + rx * 0.48f, c.y - ry * 0.58f),
        size = Size(rx * 0.54f, ry * 0.34f)
    )

    // 3. Bevelled heartwood top with concentric growth rings
    val topRect = Offset(c.x - rx * 0.90f, c.y - ry * 1.06f)
    val topSize = Size(rx * 1.80f, ry * 0.56f)
    drawOval(
        brush = Brush.radialGradient(
            listOf(Color(0xFFF6DFB7), Color(0xFFD9AE76)),
            center = Offset(c.x, c.y - ry * 0.78f),
            radius = rx * 0.95f
        ),
        topLeft = topRect,
        size = topSize
    )
    drawOval(
        color = Color(0xFFA67948).copy(alpha = 0.55f),
        topLeft = Offset(c.x - rx * 0.58f, c.y - ry * 0.94f),
        size = Size(rx * 1.16f, ry * 0.32f),
        style = Stroke(1.8f)
    )
    drawOval(
        color = EspressoDark,
        topLeft = topRect,
        size = topSize,
        style = Stroke(2.6f)
    )

    // 4. Deep carved face hollow + expressive puppeteer eyes
    val hollowCenter = Offset(c.x + ctx.lookX * 0.52f, c.y + ry * 0.18f + ctx.lookY * 0.42f)
    drawOval(
        color = Color(0xFF1A0D07),
        topLeft = Offset(hollowCenter.x - rx * 0.64f, hollowCenter.y - ry * 0.42f),
        size = Size(rx * 1.28f, ry * 0.86f)
    )
    drawOval(
        color = style.eyeColor.copy(alpha = 0.22f),
        topLeft = Offset(hollowCenter.x - rx * 0.58f, hollowCenter.y - ry * 0.36f),
        size = Size(rx * 1.16f, ry * 0.74f),
        style = Stroke(2.0f)
    )
    val eyeR = rx * 0.17f
    val attackTilt = if (ctx.isAttacking || ctx.isUltActive) 0.55f else 0f
    drawGlowingPupilEye(
        center = Offset(c.x - rx * 0.26f + ctx.lookX, c.y + ry * 0.16f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = attackTilt
    )
    drawGlowingPupilEye(
        center = Offset(c.x + rx * 0.26f + ctx.lookX, c.y + ry * 0.16f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = -attackTilt
    )

    // Trunk outer ink stroke
    drawPath(trunkPath, EspressoDark, style = Stroke(3.0f, join = StrokeJoin.Round))

    // 5. Evolution Branch Crowns (Layered botanical leaves / blossom / shadow antlers)
    val leafHighlight = Color(0xFFE1FFB3)
    when (style.crownStyle) {
        EvolutionCrownStyle.SPROUT -> {
            drawStylizedLeaf(
                base = Offset(c.x - rx * 0.20f, c.y - ry * 0.82f),
                angleDeg = -34f + sway * 1.4f,
                length = ry * 0.86f,
                width = rx * 0.44f,
                fillColor = style.accentColor,
                highlightColor = leafHighlight
            )
            drawStylizedLeaf(
                base = Offset(c.x + rx * 0.20f, c.y - ry * 0.82f),
                angleDeg = 32f + sway * 1.4f,
                length = ry * 0.82f,
                width = rx * 0.42f,
                fillColor = style.accentColor,
                highlightColor = leafHighlight
            )
            drawStylizedLeaf(
                base = Offset(c.x, c.y - ry * 0.88f),
                angleDeg = sway * 1.2f,
                length = ry * 0.98f,
                width = rx * 0.46f,
                fillColor = style.accentColor,
                highlightColor = leafHighlight
            )
        }
        EvolutionCrownStyle.BLOOM_CANOPY -> {
            val leafCount = if (ctx.scale > 1.24f) 7 else 5
            for (i in 0 until leafCount) {
                val frac = (i - (leafCount - 1) / 2f)
                drawStylizedLeaf(
                    base = Offset(c.x + frac * rx * 0.22f, c.y - ry * 0.84f),
                    angleDeg = frac * 24f + sway * 1.4f,
                    length = ry * (1.02f - kotlin.math.abs(frac) * 0.08f),
                    width = rx * 0.44f,
                    fillColor = style.accentColor,
                    highlightColor = leafHighlight
                )
            }
            // Sculpted 5-petal coral blossom with golden stamen
            val flowerCenter = Offset(c.x + sway * 0.7f, c.y - ry * 1.32f)
            for (p in 0 until 5) {
                val pa = p * (2f * PI.toFloat() / 5f) + ctx.animTime * 0.15f
                val pc = Offset(flowerCenter.x + cos(pa) * rx * 0.22f, flowerCenter.y + sin(pa) * ry * 0.22f)
                drawCircle(Color(0xFFFF7A6B), rx * 0.20f, pc)
                drawCircle(EspressoDark, rx * 0.20f, pc, style = Stroke(1.8f))
            }
            drawCircle(GoldAccent, rx * 0.17f, flowerCenter)
            drawCircle(Color.White.copy(alpha = 0.8f), rx * 0.06f, Offset(flowerCenter.x - rx * 0.05f, flowerCenter.y - ry * 0.05f))
        }
        EvolutionCrownStyle.THORN_CROWN, EvolutionCrownStyle.SHADOW_ROOTS -> {
            val spikes = if (style.crownStyle == EvolutionCrownStyle.SHADOW_ROOTS) 5 else 3
            for (i in 0 until spikes) {
                val frac = i - (spikes - 1) / 2f
                val baseOff = frac * rx * 0.42f
                val tipX = c.x + baseOff + frac * rx * 0.18f + sway
                val tipY = c.y - ry * (if (i == spikes / 2) 1.66f else 1.34f)
                val horn = Path().apply {
                    moveTo(c.x + baseOff - rx * 0.17f, c.y - ry * 0.84f)
                    quadraticTo(c.x + baseOff, c.y - ry * 1.18f, tipX, tipY)
                    quadraticTo(c.x + baseOff + rx * 0.14f, c.y - ry * 1.12f, c.x + baseOff + rx * 0.17f, c.y - ry * 0.84f)
                    close()
                }
                drawPath(horn, Brush.verticalGradient(listOf(style.eyeColor, style.accentColor), tipY, c.y - ry * 0.84f))
                drawPath(horn, EspressoDark, style = Stroke(2.2f, join = StrokeJoin.Round))
            }
            if (style.crownStyle == EvolutionCrownStyle.SHADOW_ROOTS) {
                for (w in 0 until 3) {
                    val wa = ctx.orbitAngle + w * 2.094f
                    val wp = Offset(c.x + cos(wa) * rx * 1.44f, c.y + sin(wa) * ry * 0.78f)
                    drawCircle(style.eyeColor.copy(alpha = 0.32f), rx * 0.30f, wp)
                    drawCircle(style.eyeColor, rx * 0.16f, wp)
                    drawCircle(Color.White, rx * 0.07f, wp)
                }
            }
        }
        else -> Unit
    }
}

/**
 * 冷炭裂膛 (char) — Cracked Charcoal Magma Golem:
 * Faceted obsidian shoulders & jagged armored fists, blazing branching furnace chest fissures,
 * fierce angled glowing ember eyes under a heavy brow ridge, and volcanic chimney / plasma crest branches.
 */
internal fun DrawScope.drawCharHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val isFiring = ctx.isAttacking || ctx.isUltActive || ctx.scale > 1.24f
    val emberPulse = 0.72f + 0.28f * sin(ctx.animTime * 4.5f)

    // 1. Chunky articulated obsidian gauntlets with molten ember knuckles
    for (side in listOf(-1f, 1f)) {
        val swing = if (side < 0f) ctx.footSwing * 1.2f else -ctx.footSwing * 1.2f
        val fist = Offset(c.x + side * rx * 1.10f, c.y + ry * 0.26f + swing)
        drawCircle(
            brush = Brush.radialGradient(listOf(ctx.secondary, ctx.primary), Offset(fist.x - rx * 0.1f, fist.y - ry * 0.12f), rx * 0.48f),
            radius = rx * 0.40f,
            center = fist
        )
        // Molten knuckle crack
        drawLine(
            color = style.accentColor.copy(alpha = 0.9f),
            start = Offset(fist.x - rx * 0.14f, fist.y + ry * 0.06f),
            end = Offset(fist.x + rx * 0.14f, fist.y + ry * 0.06f),
            strokeWidth = 3.0f,
            cap = StrokeCap.Round
        )
        drawCircle(EspressoDark, rx * 0.40f, fist, style = Stroke(2.6f))
    }

    // 2. Branch-specific volcanic chimney stacks / obsidian pauldrons / plasma flame crown
    when (style.crownStyle) {
        EvolutionCrownStyle.MAGMA_TITAN -> {
            for (side in listOf(-1f, 1f)) {
                val stackX = c.x + side * rx * 0.72f
                val stackRect = Offset(stackX - rx * 0.24f, c.y - ry * 1.36f)
                drawRoundRect(
                    brush = Brush.verticalGradient(listOf(ctx.secondary, ctx.primary)),
                    topLeft = stackRect,
                    size = Size(rx * 0.48f, ry * 0.72f),
                    cornerRadius = CornerRadius(rx * 0.12f, rx * 0.12f)
                )
                // Glowing molten vent plume
                drawCircle(style.accentColor.copy(alpha = 0.45f * emberPulse), rx * 0.34f, Offset(stackX, c.y - ry * 1.42f))
                drawCircle(style.eyeColor, rx * 0.18f, Offset(stackX, c.y - ry * 1.38f))
                drawRoundRect(
                    EspressoDark,
                    topLeft = stackRect,
                    size = Size(rx * 0.48f, ry * 0.72f),
                    cornerRadius = CornerRadius(rx * 0.12f, rx * 0.12f),
                    style = Stroke(2.5f)
                )
            }
        }
        EvolutionCrownStyle.ASH_FLARE, EvolutionCrownStyle.BLUE_SERAPH_FLAME -> {
            // Triple-layered sweeping plasma flame crest
            val flameSway = sin(ctx.animTime * 3.8f) * (rx * 0.10f)
            val outerFlame = Path().apply {
                moveTo(c.x - rx * 0.62f, c.y - ry * 0.74f)
                quadraticTo(c.x - rx * 0.28f, c.y - ry * 1.32f, c.x + flameSway, c.y - ry * 1.72f)
                quadraticTo(c.x + rx * 0.28f, c.y - ry * 1.32f, c.x + rx * 0.62f, c.y - ry * 0.74f)
                close()
            }
            val innerFlame = Path().apply {
                moveTo(c.x - rx * 0.30f, c.y - ry * 0.80f)
                lineTo(c.x + flameSway * 0.6f, c.y - ry * 1.38f)
                lineTo(c.x + rx * 0.30f, c.y - ry * 0.80f)
                close()
            }
            drawPath(outerFlame, Brush.verticalGradient(listOf(style.eyeColor, style.accentColor), c.y - ry * 1.72f, c.y - ry * 0.74f))
            drawPath(innerFlame, Color.White.copy(alpha = 0.85f))
            drawPath(outerFlame, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))

            if (style.crownStyle == EvolutionCrownStyle.BLUE_SERAPH_FLAME) {
                for (k in 0 until 4) {
                    val ka = ctx.orbitAngle * 1.4f + k * (PI.toFloat() / 2f)
                    val kp = Offset(c.x + cos(ka) * rx * 1.46f, c.y + sin(ka) * ry * 0.84f)
                    drawCircle(style.accentColor.copy(alpha = 0.36f), rx * 0.32f, kp)
                    drawCircle(style.accentColor, rx * 0.18f, kp)
                    drawCircle(Color.White, rx * 0.08f, kp)
                }
            }
        }
        else -> {
            // Rugged faceted charcoal shoulder pauldrons with ember vents
            for (side in listOf(-1f, 1f)) {
                val px = c.x + side * rx * 0.74f
                val py = c.y - ry * 0.64f
                val pauldron = Path().apply {
                    moveTo(px - side * rx * 0.32f, py - ry * 0.28f)
                    lineTo(px + side * rx * 0.34f, py - ry * 0.18f)
                    lineTo(px + side * rx * 0.24f, py + ry * 0.32f)
                    lineTo(px - side * rx * 0.28f, py + ry * 0.24f)
                    close()
                }
                drawPath(pauldron, ctx.secondary)
                drawCircle(style.accentColor.copy(alpha = 0.85f * emberPulse), rx * 0.11f, Offset(px, py))
                drawPath(pauldron, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
            }
        }
    }

    // 3. Broad-shouldered faceted charcoal golem torso
    val bodyPath = Path().apply {
        moveTo(c.x - rx * 0.82f, c.y - ry * 0.82f)
        lineTo(c.x, c.y - ry * 1.04f)
        lineTo(c.x + rx * 0.82f, c.y - ry * 0.82f)
        quadraticTo(c.x + rx * 1.14f, c.y - ry * 0.08f, c.x + rx * 0.90f, c.y + ry * 0.82f)
        quadraticTo(c.x, c.y + ry * 1.08f, c.x - rx * 0.90f, c.y + ry * 0.82f)
        quadraticTo(c.x - rx * 1.14f, c.y - ry * 0.08f, c.x - rx * 0.82f, c.y - ry * 0.82f)
        close()
    }
    drawPath(
        path = bodyPath,
        brush = Brush.radialGradient(
            colors = listOf(ctx.secondary, ctx.primary, Color(0xFF1A1415)),
            center = Offset(c.x - rx * 0.26f, c.y - ry * 0.34f),
            radius = rx * 1.45f
        )
    )
    // Specular mineral sheen on upper brow
    drawGlossySpecular(Offset(c.x - rx * 0.26f, c.y - ry * 0.62f), rx * 0.36f, ry * 0.14f, alpha = 0.16f)

    // 4. Blazing branching magma furnace chest fissure
    val furnaceCenter = Offset(c.x, c.y + ry * 0.32f)
    val glowRadius = rx * (if (isFiring) 0.92f else 0.66f) * emberPulse
    drawCircle(
        brush = Brush.radialGradient(
            listOf(
                style.eyeColor.copy(alpha = if (isFiring) 0.92f else 0.56f),
                style.accentColor.copy(alpha = if (isFiring) 0.52f else 0.26f),
                Color.Transparent
            ),
            center = furnaceCenter,
            radius = glowRadius
        ),
        radius = glowRadius,
        center = furnaceCenter
    )
    val fissurePath = Path().apply {
        moveTo(c.x - rx * 0.56f, c.y + ry * 0.20f)
        lineTo(c.x - rx * 0.16f, c.y + ry * 0.32f)
        lineTo(c.x + rx * 0.18f, c.y + ry * 0.24f)
        lineTo(c.x + rx * 0.56f, c.y + ry * 0.36f)
    }
    val subCrack = Path().apply {
        moveTo(c.x - rx * 0.16f, c.y + ry * 0.32f)
        lineTo(c.x, c.y + ry * 0.62f)
        lineTo(c.x + rx * 0.28f, c.y + ry * 0.54f)
    }
    drawPath(fissurePath, style.accentColor, style = Stroke(if (isFiring) 7.5f else 5.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    drawPath(subCrack, style.accentColor, style = Stroke(if (isFiring) 5.5f else 3.8f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    drawPath(fissurePath, Color(0xFFFFF8C6), style = Stroke(if (isFiring) 3.2f else 2.0f, cap = StrokeCap.Round, join = StrokeJoin.Round))

    // 5. Fierce glowing ember eyes beneath sculpted obsidian brow
    val eyeR = rx * 0.17f
    drawGlowingPupilEye(
        center = Offset(c.x - rx * 0.30f + ctx.lookX, c.y - ry * 0.24f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = 0.65f
    )
    drawGlowingPupilEye(
        center = Offset(c.x + rx * 0.30f + ctx.lookX, c.y - ry * 0.24f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = -0.65f
    )

    drawPath(bodyPath, EspressoDark, style = Stroke(3.0f, join = StrokeJoin.Round))
}

/**
 * 对旋双壳 (shell) — Counter-Rotating Twin Hydro-Shell Sprite:
 * Twin pearlescent turbine shells with aqua energy seam, foaming double-vortex currents,
 * deep sapphire face cowl with crisp luminous eyes, and hydro-spout / abyssal prism branches.
 */
internal fun DrawScope.drawShellHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style

    // 1. Lower surging tide ring for Tidal Spout branch
    if (style.crownStyle == EvolutionCrownStyle.TIDAL_SPOUT) {
        drawOval(
            brush = Brush.radialGradient(listOf(style.accentColor.copy(alpha = 0.68f), Color.Transparent), Offset(c.x, c.y + ry * 0.78f), rx * 1.15f),
            topLeft = Offset(c.x - rx * 1.05f, c.y + ry * 0.45f),
            size = Size(rx * 2.10f, ry * 0.76f)
        )
        drawOval(
            color = Color.White.copy(alpha = 0.74f),
            topLeft = Offset(c.x - rx * 0.68f, c.y + ry * 0.62f),
            size = Size(rx * 1.36f, ry * 0.42f),
            style = Stroke(2.8f)
        )
    }

    // 2. Counter-rotating aqua water-vortex ribbons + foam droplets
    drawArc(
        color = style.accentColor.copy(alpha = 0.54f),
        startAngle = ctx.orbitAngle * 57.3f,
        sweepAngle = 240f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 1.56f, c.y - ry * 0.96f),
        size = Size(rx * 3.12f, ry * 1.92f),
        style = Stroke(width = 9.0f, cap = StrokeCap.Round)
    )
    drawArc(
        color = Color.White.copy(alpha = 0.88f),
        startAngle = -ctx.orbitAngle * 76f,
        sweepAngle = 155f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 1.34f, c.y - ry * 0.80f),
        size = Size(rx * 2.68f, ry * 1.60f),
        style = Stroke(width = 4.6f, cap = StrokeCap.Round)
    )
    for (d in 0 until 3) {
        val da = ctx.orbitAngle * 1.25f + d * 2.094f
        val dp = Offset(c.x + cos(da) * rx * 1.46f, c.y + sin(da) * ry * 0.88f)
        drawCircle(Color.White.copy(alpha = 0.92f), rx * 0.10f, dp)
    }

    // 3. Reef / Abyssal faceted crystal crown behind upper shell
    if (style.crownStyle == EvolutionCrownStyle.REEF_FORTRESS || style.crownStyle == EvolutionCrownStyle.ABYSS_CITADEL) {
        val crystalCount = if (style.crownStyle == EvolutionCrownStyle.ABYSS_CITADEL) 5 else 3
        for (i in 0 until crystalCount) {
            val frac = i - (crystalCount - 1) / 2f
            val a = -PI.toFloat() / 2f + frac * 0.38f
            val basePt = Offset(c.x + cos(a) * rx * 0.86f, c.y + sin(a) * ry * 0.86f)
            val tipPt = Offset(c.x + cos(a) * rx * 1.48f, c.y + sin(a) * ry * 1.48f)
            val perpX = -sin(a) * rx * 0.22f
            val perpY = cos(a) * ry * 0.22f
            val prism = Path().apply {
                moveTo(basePt.x - perpX, basePt.y - perpY)
                lineTo(tipPt.x, tipPt.y)
                lineTo(basePt.x + perpX, basePt.y + perpY)
                close()
            }
            drawPath(prism, Brush.linearGradient(listOf(Color.White, style.accentColor), tipPt, basePt))
            drawPath(prism, EspressoDark, style = Stroke(2.1f, join = StrokeJoin.Round))
        }
    }

    // 4. Twin Counter-Rotating Armored Shells (Upper Dome + Lower Keel + Aqua Core Seam)
    // Inner glowing core visible between twin shells
    drawCircle(
        brush = Brush.radialGradient(listOf(Color.White, style.accentColor, ctx.primary), c, rx * 1.04f),
        radius = rx * 0.96f,
        center = c
    )
    // Upper sculpted shell dome
    val upperShell = Path().apply {
        moveTo(c.x - rx * 1.04f, c.y - ry * 0.14f)
        quadraticTo(c.x - rx * 0.96f, c.y - ry * 1.12f, c.x, c.y - ry * 1.08f)
        quadraticTo(c.x + rx * 0.96f, c.y - ry * 1.12f, c.x + rx * 1.04f, c.y - ry * 0.14f)
        quadraticTo(c.x, c.y - ry * 0.34f, c.x - rx * 1.04f, c.y - ry * 0.14f)
        close()
    }
    drawPath(
        upperShell,
        Brush.verticalGradient(listOf(ctx.secondary, ctx.primary), c.y - ry * 1.08f, c.y)
    )
    // Pearlescent ridge seams on upper shell
    drawLine(Color.White.copy(alpha = 0.42f), Offset(c.x - rx * 0.44f, c.y - ry * 0.92f), Offset(c.x - rx * 0.26f, c.y - ry * 0.30f), 2.5f, StrokeCap.Round)
    drawLine(Color.White.copy(alpha = 0.42f), Offset(c.x + rx * 0.44f, c.y - ry * 0.92f), Offset(c.x + rx * 0.26f, c.y - ry * 0.30f), 2.5f, StrokeCap.Round)
    drawGlossySpecular(Offset(c.x - rx * 0.24f, c.y - ry * 0.72f), rx * 0.34f, ry * 0.14f, alpha = 0.36f)
    drawPath(upperShell, EspressoDark, style = Stroke(2.8f, join = StrokeJoin.Round))

    // Lower armored keel shell
    val lowerShell = Path().apply {
        moveTo(c.x - rx * 1.02f, c.y + ry * 0.22f)
        quadraticTo(c.x, c.y + ry * 0.44f, c.x + rx * 1.02f, c.y + ry * 0.22f)
        quadraticTo(c.x + rx * 0.88f, c.y + ry * 1.06f, c.x, c.y + ry * 1.04f)
        quadraticTo(c.x - rx * 0.88f, c.y + ry * 1.06f, c.x - rx * 1.02f, c.y + ry * 0.22f)
        close()
    }
    drawPath(
        lowerShell,
        Brush.verticalGradient(listOf(ctx.primary, Color(0xFF183A63)), c.y + ry * 0.20f, c.y + ry * 1.06f)
    )
    drawPath(lowerShell, EspressoDark, style = Stroke(2.8f, join = StrokeJoin.Round))

    // 5. Deep sapphire visor gap with bright expressive eyes
    drawOval(
        color = Color(0xFF101940),
        topLeft = Offset(c.x - rx * 0.78f, c.y - ry * 0.24f),
        size = Size(rx * 1.56f, ry * 0.56f)
    )
    val eyeW = rx * 0.21f
    val leftEye = Offset(c.x - rx * 0.28f + ctx.lookX * 0.65f, c.y + ry * 0.04f + ctx.lookY * 0.45f)
    val rightEye = Offset(c.x + rx * 0.28f + ctx.lookX * 0.65f, c.y + ry * 0.04f + ctx.lookY * 0.45f)
    drawCircle(Color.White, eyeW, leftEye)
    drawCircle(Color.White, eyeW, rightEye)
    drawCircle(style.eyeColor, eyeW * 0.60f, Offset(leftEye.x + ctx.lookX * 0.25f, leftEye.y + ctx.lookY * 0.2f))
    drawCircle(style.eyeColor, eyeW * 0.60f, Offset(rightEye.x + ctx.lookX * 0.25f, rightEye.y + ctx.lookY * 0.2f))
    drawCircle(Color.White, eyeW * 0.24f, Offset(leftEye.x - eyeW * 0.24f, leftEye.y - eyeW * 0.24f))
    drawCircle(Color.White, eyeW * 0.24f, Offset(rightEye.x - eyeW * 0.24f, rightEye.y - eyeW * 0.24f))
}
