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
import kotlin.math.abs
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
    val isUltActive: Boolean,
    val blinkFactor: Float = 0f,
    val facingAngle: Float = 0f,
    val isHurt: Boolean = false,
    val attackProgress: Float = 0f,
    val hurtProgress: Float = 0f,
    val evolutionFxProgress: Float = 0f,
    val turnX: Float = 0f,
    val isDashing: Boolean = false,
    val isGliding: Boolean = false,
    val hpRatio: Float = 1f,
    val quirkProgress: Float = 0f
) {
    val isMidTier: Boolean get() = scale >= 1.08f
    val isApexTier: Boolean get() = scale >= 1.24f
}

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

internal fun DrawScope.drawCelRimArc(
    center: Offset,
    rx: Float,
    ry: Float,
    color: Color = Color.White.copy(alpha = 0.42f),
    startAngle: Float = 205f,
    sweepAngle: Float = 75f,
    strokeWidth: Float = 2.8f
) {
    drawArc(
        color = color,
        startAngle = startAngle,
        sweepAngle = sweepAngle,
        useCenter = false,
        topLeft = Offset(center.x - rx, center.y - ry),
        size = Size(rx * 2f, ry * 2f),
        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
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
            quadraticTo(base.x - width * 0.76f, base.y - length * 0.46f, base.x, base.y - length)
            quadraticTo(base.x + width * 0.76f, base.y - length * 0.46f, base.x, base.y)
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
        // Central botanical midrib + side leaf veins
        drawLine(
            color = highlightColor.copy(alpha = 0.85f),
            start = Offset(base.x, base.y - length * 0.14f),
            end = Offset(base.x, base.y - length * 0.80f),
            strokeWidth = (width * 0.12f).coerceIn(1.4f, 3.2f),
            cap = StrokeCap.Round
        )
        drawLine(
            color = highlightColor.copy(alpha = 0.50f),
            start = Offset(base.x, base.y - length * 0.42f),
            end = Offset(base.x - width * 0.30f, base.y - length * 0.60f),
            strokeWidth = (width * 0.08f).coerceIn(1.1f, 2.2f),
            cap = StrokeCap.Round
        )
        drawLine(
            color = highlightColor.copy(alpha = 0.50f),
            start = Offset(base.x, base.y - length * 0.42f),
            end = Offset(base.x + width * 0.30f, base.y - length * 0.60f),
            strokeWidth = (width * 0.08f).coerceIn(1.1f, 2.2f),
            cap = StrokeCap.Round
        )
        drawPath(
            path = leaf,
            color = EspressoDark,
            style = Stroke(width = 2.1f, join = StrokeJoin.Round)
        )
    }
}

/**
 * Expressive cel-shaded eye supporting natural blinking, slit/round pupils, dual specular glints,
 * and angled battle brows.
 */
internal fun DrawScope.drawGlowingPupilEye(
    center: Offset,
    radius: Float,
    glowColor: Color,
    coreColor: Color = Color.White,
    angryTilt: Float = 0f,
    blinkFactor: Float = 0f,
    slitPupil: Boolean = false,
    isHurt: Boolean = false,
    isRightEye: Boolean = false,
    eyeFlare: Float = 0f
) {
    if (isHurt) {
        // Sharp expressive "> <" damaged wince eye with white-hot impact rim
        val dir = if (isRightEye) -1f else 1f
        val w = radius * 1.15f
        val h = radius * 0.85f
        val wince = Path().apply {
            moveTo(center.x - dir * w, center.y - h)
            lineTo(center.x + dir * w * 0.55f, center.y)
            lineTo(center.x - dir * w, center.y + h)
        }
        drawPath(
            wince,
            Color.White.copy(alpha = 0.88f),
            style = Stroke(width = (radius * 0.82f).coerceIn(3.2f, 6.0f), cap = StrokeCap.Round, join = StrokeJoin.Round)
        )
        drawPath(
            wince,
            EspressoDark,
            style = Stroke(width = (radius * 0.46f).coerceIn(2.0f, 3.8f), cap = StrokeCap.Round, join = StrokeJoin.Round)
        )
        return
    }
    if (blinkFactor > 0.68f) {
        // Closed happy/relaxed curved eyelid arc
        drawArc(
            color = EspressoDark,
            startAngle = 195f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(center.x - radius * 1.05f, center.y - radius * 0.48f),
            size = Size(radius * 2.1f, radius * 1.15f),
            style = Stroke(width = (radius * 0.48f).coerceIn(2.0f, 3.8f), cap = StrokeCap.Round)
        )
        return
    }
    val openScaleY = (1f - blinkFactor * 0.82f).coerceIn(0.22f, 1f)
    val ry = radius * openScaleY
    val flareBoost = 1f + eyeFlare.coerceIn(0f, 1f) * 0.48f
    // Soft outer luminescence (flares intensely on strike/ult)
    drawOval(
        color = glowColor.copy(alpha = (0.36f + eyeFlare * 0.34f).coerceAtMost(0.82f)),
        topLeft = Offset(center.x - radius * 1.90f * flareBoost, center.y - ry * 1.85f * flareBoost),
        size = Size(radius * 3.80f * flareBoost, ry * 3.70f * flareBoost)
    )
    // Dark ink socket rim
    drawOval(
        color = EspressoDark,
        topLeft = Offset(center.x - radius * 1.18f, center.y - ry * 1.18f),
        size = Size(radius * 2.36f, ry * 2.36f)
    )
    // Luminous iris gradient
    drawOval(
        brush = Brush.verticalGradient(
            listOf(glowColor, coreColor.copy(alpha = 0.85f), glowColor),
            startY = center.y - ry,
            endY = center.y + ry
        ),
        topLeft = Offset(center.x - radius * 0.92f, center.y - ry * 0.92f),
        size = Size(radius * 1.84f, ry * 1.84f)
    )
    // Optional dragon/fox vertical slit pupil
    if (slitPupil && openScaleY > 0.55f) {
        drawOval(
            color = EspressoDark.copy(alpha = 0.88f),
            topLeft = Offset(center.x - radius * 0.22f, center.y - ry * 0.68f),
            size = Size(radius * 0.44f, ry * 1.36f)
        )
    }
    // Primary + secondary anime specular glints
    drawCircle(
        coreColor.copy(alpha = 0.96f),
        radius * 0.40f * openScaleY,
        Offset(center.x - radius * 0.28f, center.y - ry * 0.28f)
    )
    drawCircle(
        coreColor.copy(alpha = 0.70f),
        radius * 0.17f * openScaleY,
        Offset(center.x + radius * 0.26f, center.y + ry * 0.26f)
    )
    if (angryTilt != 0f) {
        val bw = radius * 1.48f
        val dy = radius * 0.54f * angryTilt
        drawLine(
            color = EspressoDark,
            start = Offset(center.x - bw, center.y - ry * 0.96f - dy),
            end = Offset(center.x + bw, center.y - ry * 0.96f + dy),
            strokeWidth = (radius * 0.54f).coerceIn(2.2f, 4.4f),
            cap = StrokeCap.Round
        )
    }
}

/**
 * 树桩洞傀 (stump) — Ancient Hollow Forest Puppeteer:
 * Sculpted flared treant stump with living curling vine-arms that whip during attacks,
 * shoulder moss collar with tiny glowing forest mushrooms, concentric heartwood rings,
 * shadowed hollow housing blinking puppeteer eyes, and lush layered botanical crowns.
 */
internal fun DrawScope.drawStumpHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val sway = sin(ctx.animTime * 1.0f) * (rx * 0.10f)
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val lash = 1.0f + attackPulse * 0.62f + if (ctx.isUltActive) 0.25f else 0f
    val hurtJolt = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f)
    val aimBiasX = cos(ctx.facingAngle) * rx * 0.46f * attackPulse
    val aimBiasY = sin(ctx.facingAngle) * ry * 0.34f * attackPulse
    val pxTurn = ctx.turnX * rx * 0.14f
    val dashPullX = if (ctx.isDashing) -ctx.turnX * rx * 0.38f else 0f

    // 1. Living curling vine-arms extending from the trunk sides (whip fiercely forward on attack, trail back on dash)
    for (side in listOf(-1f, 1f)) {
        val armWave = sin(ctx.animTime * 2.0f + side) * (ry * 0.12f)
        val hurtFlinch = -hurtJolt * ry * 0.24f
        val tipX = c.x + side * rx * (1.42f * lash) - pxTurn * 0.45f + dashPullX + aimBiasX * (if (side * cos(ctx.facingAngle) >= 0f) 1.25f else 0.55f)
        val tipY = c.y + ry * 0.04f + armWave + aimBiasY - attackPulse * ry * 0.26f + hurtFlinch
        val vinePath = Path().apply {
            moveTo(c.x + side * rx * 0.84f - pxTurn * 0.25f, c.y + ry * 0.08f)
            quadraticTo(
                c.x + side * rx * (1.24f + attackPulse * 0.24f) + dashPullX * 0.5f,
                c.y + ry * (0.44f - attackPulse * 0.22f) + armWave * 0.5f,
                tipX,
                tipY
            )
        }
        drawPath(vinePath, EspressoDark, style = Stroke(width = rx * 0.24f + 3.2f, cap = StrokeCap.Round))
        drawPath(
            vinePath,
            if (attackPulse > 0.25f) Color(0xFF9DF86A) else style.accentColor,
            style = Stroke(width = rx * (0.18f + attackPulse * 0.05f), cap = StrokeCap.Round)
        )
        // Glowing forest bud at vine tip — ignites into a bright razor-leaf blade during strike!
        drawCircle(style.eyeColor.copy(alpha = 0.34f + attackPulse * 0.48f), rx * (0.22f + attackPulse * 0.18f), Offset(tipX, tipY))
        if (attackPulse > 0.15f) {
            drawStylizedLeaf(
                base = Offset(tipX, tipY),
                angleDeg = ctx.facingAngle * 57.29578f + 90f + side * 18f,
                length = ry * (0.58f * attackPulse),
                width = rx * (0.28f * attackPulse),
                fillColor = Color(0xFF98F65E),
                highlightColor = Color(0xFFFFFFCC)
            )
        }
        drawCircle(Color(0xFFDFFFA0), rx * (0.11f + attackPulse * 0.05f), Offset(tipX, tipY))
        drawCircle(EspressoDark, rx * 0.11f, Offset(tipX, tipY), style = Stroke(1.6f))
    }

    // 2. Flared knobby root-claw feet
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing else -ctx.footSwing
        val footCenter = Offset(c.x + side * rx * 0.58f, c.y + ry * 0.88f + fSwing)
        drawOval(
            brush = Brush.verticalGradient(listOf(ctx.primary, ctx.secondary)),
            topLeft = Offset(footCenter.x - rx * 0.36f, footCenter.y - ry * 0.21f),
            size = Size(rx * 0.72f, ry * 0.42f)
        )
        // Little toe-root notches
        drawLine(
            EspressoDark.copy(alpha = 0.65f),
            Offset(footCenter.x, footCenter.y + ry * 0.04f),
            Offset(footCenter.x, footCenter.y + ry * 0.20f),
            2.0f,
            StrokeCap.Round
        )
        drawOval(
            color = EspressoDark,
            topLeft = Offset(footCenter.x - rx * 0.36f, footCenter.y - ry * 0.21f),
            size = Size(rx * 0.72f, ry * 0.42f),
            style = Stroke(2.4f)
        )
    }

    // 3. Sculpted organic tapered stump trunk with flared root silhouette
    val trunkPath = Path().apply {
        moveTo(c.x - rx * 0.90f, c.y - ry * 0.82f)
        quadraticTo(c.x - rx * 1.04f, c.y + ry * 0.14f, c.x - rx * 1.16f, c.y + ry * 0.86f)
        quadraticTo(c.x, c.y + ry * 1.06f, c.x + rx * 1.16f, c.y + ry * 0.86f)
        quadraticTo(c.x + rx * 1.04f, c.y + ry * 0.14f, c.x + rx * 0.90f, c.y - ry * 0.82f)
        close()
    }
    drawPath(
        path = trunkPath,
        brush = Brush.horizontalGradient(
            colors = listOf(
                ctx.secondary,
                ctx.primary,
                ctx.primary.copy(alpha = 0.96f),
                ctx.secondary.copy(alpha = 0.84f)
            ),
            startX = c.x - rx * 1.16f,
            endX = c.x + rx * 1.16f
        )
    )

    // Bark vertical grain grooves + carved side knot + sunlit cel highlight
    drawLine(
        color = EspressoDark.copy(alpha = 0.40f),
        start = Offset(c.x - rx * 0.60f, c.y - ry * 0.44f),
        end = Offset(c.x - rx * 0.72f, c.y + ry * 0.74f),
        strokeWidth = 2.6f,
        cap = StrokeCap.Round
    )
    drawLine(
        color = EspressoDark.copy(alpha = 0.36f),
        start = Offset(c.x + rx * 0.60f, c.y - ry * 0.40f),
        end = Offset(c.x + rx * 0.72f, c.y + ry * 0.72f),
        strokeWidth = 2.6f,
        cap = StrokeCap.Round
    )
    // Carved bark knot detail on right flank (2.5D counter-parallax)
    drawOval(
        color = EspressoDark.copy(alpha = 0.34f),
        topLeft = Offset(c.x + rx * 0.62f - pxTurn * 0.55f, c.y + ry * 0.24f),
        size = Size(rx * 0.24f, ry * 0.28f),
        style = Stroke(2.0f)
    )
    drawLine(
        color = Color(0xFFFFE5B8).copy(alpha = 0.30f),
        start = Offset(c.x - rx * 0.76f, c.y - ry * 0.50f),
        end = Offset(c.x - rx * 0.84f, c.y + ry * 0.48f),
        strokeWidth = 3.6f,
        cap = StrokeCap.Round
    )

    // Layered lush shoulder moss collar + cute tiny glowing mushroom on left shoulder (bounces on quirk!)
    drawOval(
        color = style.accentColor.copy(alpha = 0.95f),
        topLeft = Offset(c.x - rx * 1.06f, c.y - ry * 0.66f),
        size = Size(rx * 0.62f, ry * 0.40f)
    )
    drawOval(
        color = Color(0xFFD8FFA0).copy(alpha = 0.45f),
        topLeft = Offset(c.x - rx * 0.96f, c.y - ry * 0.62f),
        size = Size(rx * 0.34f, ry * 0.16f)
    )
    drawOval(
        color = style.accentColor.copy(alpha = 0.90f),
        topLeft = Offset(c.x + rx * 0.44f, c.y - ry * 0.60f),
        size = Size(rx * 0.58f, ry * 0.36f)
    )
    val mushPop = sin(ctx.quirkProgress * PI.toFloat()).coerceIn(0f, 1f) * ry * 0.18f
    val mushBase = Offset(c.x - rx * 0.78f - pxTurn * 0.35f, c.y - ry * 0.54f - mushPop)
    drawLine(Color(0xFFFFF1D6), Offset(mushBase.x, mushBase.y + mushPop), Offset(mushBase.x - rx * 0.04f, mushBase.y - ry * 0.20f), 3.4f, StrokeCap.Round)
    drawArc(
        color = Color(0xFFFF7A59),
        startAngle = 180f,
        sweepAngle = 180f,
        useCenter = true,
        topLeft = Offset(mushBase.x - rx * 0.22f, mushBase.y - ry * 0.34f),
        size = Size(rx * 0.36f, ry * 0.28f)
    )
    drawCircle(Color(0xFFFFF6D6), rx * 0.045f, Offset(mushBase.x - rx * 0.08f, mushBase.y - ry * 0.25f))

    // 4. Bevelled heartwood top with double concentric growth rings
    val topRect = Offset(c.x - rx * 0.90f, c.y - ry * 1.06f)
    val topSize = Size(rx * 1.80f, ry * 0.56f)
    drawOval(
        brush = Brush.radialGradient(
            listOf(Color(0xFFF9E5BF), Color(0xFFD7A86E)),
            center = Offset(c.x, c.y - ry * 0.78f),
            radius = rx * 0.95f
        ),
        topLeft = topRect,
        size = topSize
    )
    drawOval(
        color = Color(0xFFA67948).copy(alpha = 0.58f),
        topLeft = Offset(c.x - rx * 0.62f, c.y - ry * 0.96f),
        size = Size(rx * 1.24f, ry * 0.36f),
        style = Stroke(1.8f)
    )
    drawOval(
        color = Color(0xFFA67948).copy(alpha = 0.42f),
        topLeft = Offset(c.x - rx * 0.34f, c.y - ry * 0.88f),
        size = Size(rx * 0.68f, ry * 0.20f),
        style = Stroke(1.4f)
    )
    drawOval(
        color = EspressoDark,
        topLeft = topRect,
        size = topSize,
        style = Stroke(2.6f)
    )

    // 5. Deep carved face hollow with 2.5D forward parallax + blinking puppeteer eyes
    val hollowCenter = Offset(c.x + ctx.lookX * 0.54f + pxTurn * 0.55f, c.y + ry * 0.18f + ctx.lookY * 0.42f)
    drawOval(
        brush = Brush.radialGradient(
            listOf(Color(0xFF28160C), Color(0xFF120804)),
            center = hollowCenter,
            radius = rx * 0.70f
        ),
        topLeft = Offset(hollowCenter.x - rx * 0.66f, hollowCenter.y - ry * 0.44f),
        size = Size(rx * 1.32f, ry * 0.88f)
    )
    drawOval(
        color = style.eyeColor.copy(alpha = 0.28f + attackPulse * 0.46f),
        topLeft = Offset(hollowCenter.x - rx * 0.60f, hollowCenter.y - ry * 0.38f),
        size = Size(rx * 1.20f, ry * 0.76f),
        style = Stroke(2.0f + attackPulse * 1.8f)
    )
    val eyeR = rx * (0.18f + attackPulse * 0.045f)
    val attackTilt = if (ctx.isAttacking || ctx.isUltActive) 0.62f else 0f
    drawGlowingPupilEye(
        center = Offset(c.x - rx * 0.26f + ctx.lookX + pxTurn * 0.55f, c.y + ry * 0.16f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = attackTilt,
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = false,
        eyeFlare = attackPulse
    )
    drawGlowingPupilEye(
        center = Offset(c.x + rx * 0.26f + ctx.lookX + pxTurn * 0.55f, c.y + ry * 0.16f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = -attackTilt,
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = true,
        eyeFlare = attackPulse
    )

    // Trunk outer ink stroke
    drawPath(trunkPath, EspressoDark, style = Stroke(3.0f, join = StrokeJoin.Round))

    // 6. Evolution Branch Crowns (Layered botanical leaves / blossom / shadow antlers)
    val leafHighlight = Color(0xFFE6FFBA)
    when (style.crownStyle) {
        EvolutionCrownStyle.SPROUT -> {
            drawStylizedLeaf(
                base = Offset(c.x - rx * 0.22f, c.y - ry * 0.82f),
                angleDeg = -36f + sway * 1.4f,
                length = ry * 0.90f,
                width = rx * 0.46f,
                fillColor = style.accentColor,
                highlightColor = leafHighlight
            )
            drawStylizedLeaf(
                base = Offset(c.x + rx * 0.22f, c.y - ry * 0.82f),
                angleDeg = 34f + sway * 1.4f,
                length = ry * 0.86f,
                width = rx * 0.44f,
                fillColor = style.accentColor,
                highlightColor = leafHighlight
            )
            drawStylizedLeaf(
                base = Offset(c.x, c.y - ry * 0.88f),
                angleDeg = sway * 1.2f,
                length = ry * 1.04f,
                width = rx * 0.48f,
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
                    length = ry * (1.04f - abs(frac) * 0.08f),
                    width = rx * 0.44f,
                    fillColor = style.accentColor,
                    highlightColor = leafHighlight
                )
            }
            val flowerCenter = Offset(c.x + sway * 0.7f, c.y - ry * 1.34f)
            for (p in 0 until 5) {
                val pa = p * (2f * PI.toFloat() / 5f) + ctx.animTime * 0.5f
                val pc = Offset(flowerCenter.x + cos(pa) * rx * 0.23f, flowerCenter.y + sin(pa) * ry * 0.23f)
                drawCircle(Color(0xFFFF7A6B), rx * 0.21f, pc)
                drawCircle(Color(0xFFFFC1B4).copy(alpha = 0.55f), rx * 0.10f, Offset(pc.x - rx * 0.04f, pc.y - ry * 0.04f))
                drawCircle(EspressoDark, rx * 0.21f, pc, style = Stroke(1.8f))
            }
            drawCircle(GoldAccent, rx * 0.18f, flowerCenter)
            drawCircle(Color.White.copy(alpha = 0.85f), rx * 0.06f, Offset(flowerCenter.x - rx * 0.05f, flowerCenter.y - ry * 0.05f))
            // Track 2 Apex Tier silhouette: floating orbiting emerald vine-shield leaves!
            if (ctx.isApexTier) {
                for (l in 0 until 3) {
                    val la = ctx.orbitAngle + l * 2.0943952f
                    val lp = Offset(c.x + cos(la) * rx * 1.54f, c.y + sin(la) * ry * 0.76f)
                    drawStylizedLeaf(
                        base = lp,
                        angleDeg = la * 57.29578f + 90f,
                        length = ry * 0.56f,
                        width = rx * 0.28f,
                        fillColor = style.accentColor,
                        highlightColor = Color(0xFFFFF8B0)
                    )
                }
            }
        }
        EvolutionCrownStyle.THORN_CROWN, EvolutionCrownStyle.SHADOW_ROOTS -> {
            val spikes = if (style.crownStyle == EvolutionCrownStyle.SHADOW_ROOTS) 5 else 3
            for (i in 0 until spikes) {
                val frac = i - (spikes - 1) / 2f
                val baseOff = frac * rx * 0.42f
                val tipX = c.x + baseOff + frac * rx * 0.18f + sway
                val tipY = c.y - ry * (if (i == spikes / 2) 1.68f else 1.36f)
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
                // Track 2 Apex Tier silhouette: twin curved dark-crystal root spears flanking shoulders
                if (ctx.isApexTier) {
                    for (side in listOf(-1f, 1f)) {
                        val spear = Path().apply {
                            moveTo(c.x + side * rx * 0.92f, c.y - ry * 0.22f)
                            quadraticTo(c.x + side * rx * 1.56f, c.y - ry * 0.72f, c.x + side * rx * 1.34f, c.y - ry * 1.44f)
                            quadraticTo(c.x + side * rx * 1.24f, c.y - ry * 0.76f, c.x + side * rx * 0.88f, c.y - ry * 0.48f)
                            close()
                        }
                        drawPath(spear, Brush.verticalGradient(listOf(style.eyeColor, Color(0xFF2B133D))))
                        drawPath(spear, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
                    }
                }
                for (w in 0 until 3) {
                    val wa = ctx.orbitAngle + w * 2.0943952f
                    val wp = Offset(c.x + cos(wa) * rx * 1.46f, c.y + sin(wa) * ry * 0.78f)
                    drawCircle(style.eyeColor.copy(alpha = 0.34f), rx * 0.30f, wp)
                    drawCircle(style.eyeColor, rx * 0.16f, wp)
                    drawCircle(Color.White, rx * 0.07f, wp)
                }
            }
        }
        else -> Unit
    }

    // Floating sunlit pollen spore sparkles around the crown (exact 1x orbitAngle = seamless)
    for (p in 0 until 2) {
        val pa = ctx.orbitAngle + p * PI.toFloat()
        val pt = Offset(c.x + cos(pa) * rx * 1.18f, c.y - ry * 1.10f + sin(ctx.animTime * 2.0f + p) * ry * 0.22f)
        drawCircle(Color(0xFFFFF6A8).copy(alpha = 0.72f), rx * 0.075f, pt)
    }
}

/**
 * 冷炭裂膛 (char) — Cracked Charcoal Magma Golem:
 * Beveled volcanic obsidian plates & articulated molten-knuckle gauntlets that punch forward on attack,
 * incandescent branching magma furnace chest that cracks wider during skills, rising ember sparks,
 * sculpted brow ridge with fiercely glowing eyes, and chimney/plasma crest branches.
 */
internal fun DrawScope.drawCharHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val hurtJolt = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f)
    // Track 4 Passive Visual: <50% HP triggers Char's +30% Fire Damage Furnace Overdrive continuously!
    val isOverdrive = ctx.hpRatio < 0.50f && ctx.hpRatio > 0f
    val isFiring = ctx.isAttacking || ctx.isUltActive || ctx.isApexTier || attackPulse > 0.08f || isOverdrive
    val emberPulse = (0.76f + 0.24f * sin(ctx.animTime * 4.0f)) *
        (if (isOverdrive) 1.18f else 1f) *
        (if (ctx.isHurt) (0.55f + 0.45f * abs(sin(ctx.hurtProgress * 30f))) else 1f)
    val pxTurn = ctx.turnX * rx * 0.14f

    // 1. Heavy obsidian feet
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing * 0.85f else -ctx.footSwing * 0.85f
        val foot = Offset(c.x + side * rx * 0.50f, c.y + ry * 0.88f + fSwing)
        drawRoundRect(
            color = Color(0xFF211C22),
            topLeft = Offset(foot.x - rx * 0.30f, foot.y - ry * 0.18f),
            size = Size(rx * 0.60f, ry * 0.36f),
            cornerRadius = CornerRadius(rx * 0.14f, rx * 0.14f)
        )
        drawRoundRect(
            color = EspressoDark,
            topLeft = Offset(foot.x - rx * 0.30f, foot.y - ry * 0.18f),
            size = Size(rx * 0.60f, ry * 0.36f),
            cornerRadius = CornerRadius(rx * 0.14f, rx * 0.14f),
            style = Stroke(2.2f)
        )
    }

    // 2. Chunky articulated obsidian gauntlets with blazing molten knuckle fissures & power-slam thrust
    val punchReach = attackPulse * 0.44f + if (ctx.isUltActive) 0.14f else 0f
    val fistAimX = cos(ctx.facingAngle) * rx * 0.48f * attackPulse
    val fistAimY = sin(ctx.facingAngle) * ry * 0.36f * attackPulse
    val dashFistBack = if (ctx.isDashing) -ctx.turnX * rx * 0.30f else 0f
    for (side in listOf(-1f, 1f)) {
        val swing = if (side < 0f) ctx.footSwing * 1.2f else -ctx.footSwing * 1.2f
        val fist = Offset(
            c.x + side * rx * (1.12f + punchReach * 0.7f - hurtJolt * 0.14f) - pxTurn * 0.35f + dashFistBack + fistAimX,
            c.y + ry * (0.24f - punchReach * 0.52f - hurtJolt * 0.16f) + swing + fistAimY
        )
        if (attackPulse > 0.12f) {
            // Molten power-slam fist halo
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(Color(0xFFFFF4B8).copy(alpha = attackPulse * 0.72f), style.accentColor.copy(alpha = attackPulse * 0.45f), Color.Transparent),
                    center = fist,
                    radius = rx * (0.72f + attackPulse * 0.28f)
                ),
                radius = rx * (0.72f + attackPulse * 0.28f),
                center = fist
            )
        }
        drawCircle(
            brush = Brush.radialGradient(listOf(ctx.secondary, ctx.primary, Color(0xFF1A1418)), Offset(fist.x - rx * 0.1f, fist.y - ry * 0.12f), rx * 0.50f),
            radius = rx * (0.42f + attackPulse * 0.08f),
            center = fist
        )
        // Molten glowing knuckle cracks
        drawLine(
            color = style.accentColor.copy(alpha = 0.96f),
            start = Offset(fist.x - rx * 0.18f, fist.y + ry * 0.04f),
            end = Offset(fist.x + rx * 0.18f, fist.y + ry * 0.08f),
            strokeWidth = if (isFiring) 4.8f + attackPulse * 2.2f else 3.0f,
            cap = StrokeCap.Round
        )
        drawLine(
            color = Color(0xFFFFF4B8),
            start = Offset(fist.x - rx * 0.12f, fist.y + ry * 0.05f),
            end = Offset(fist.x + rx * 0.12f, fist.y + ry * 0.07f),
            strokeWidth = 1.6f + attackPulse * 1.4f,
            cap = StrokeCap.Round
        )
        drawCircle(EspressoDark, rx * (0.42f + attackPulse * 0.08f), fist, style = Stroke(2.6f))
    }

    // 3. Branch-specific volcanic chimney stacks / obsidian pauldrons / plasma flame crown (with Track 2 tier silhouettes)
    when (style.crownStyle) {
        EvolutionCrownStyle.MAGMA_TITAN -> {
            for (side in listOf(-1f, 1f)) {
                val stackX = c.x + side * rx * 0.72f - pxTurn * 0.45f
                val stackRect = Offset(stackX - rx * 0.24f, c.y - ry * 1.38f)
                drawRoundRect(
                    brush = Brush.verticalGradient(listOf(ctx.secondary, ctx.primary)),
                    topLeft = stackRect,
                    size = Size(rx * 0.48f, ry * 0.74f),
                    cornerRadius = CornerRadius(rx * 0.12f, rx * 0.12f)
                )
                drawCircle(style.accentColor.copy(alpha = 0.52f * emberPulse), rx * 0.36f, Offset(stackX, c.y - ry * 1.44f))
                drawCircle(style.eyeColor, rx * 0.19f, Offset(stackX, c.y - ry * 1.40f))
                drawRoundRect(
                    EspressoDark,
                    topLeft = stackRect,
                    size = Size(rx * 0.48f, ry * 0.74f),
                    cornerRadius = CornerRadius(rx * 0.12f, rx * 0.12f),
                    style = Stroke(2.5f)
                )
                // Track 2 Apex Tier: erupting magma plume tongues + jagged obsidian shoulder spikes!
                if (ctx.isApexTier) {
                    val plumeH = ry * (0.68f + 0.14f * sin(ctx.animTime * 4.0f + side))
                    val plume = Path().apply {
                        moveTo(stackX - rx * 0.20f, c.y - ry * 1.38f)
                        quadraticTo(stackX, c.y - ry * 1.38f - plumeH, stackX + rx * 0.20f, c.y - ry * 1.38f)
                        close()
                    }
                    drawPath(plume, Brush.verticalGradient(listOf(Color(0xFFFFF4B8), style.accentColor)))
                    val spike = Path().apply {
                        moveTo(c.x + side * rx * 0.88f, c.y - ry * 0.68f)
                        lineTo(c.x + side * rx * 1.42f, c.y - ry * 1.02f)
                        lineTo(c.x + side * rx * 1.02f, c.y - ry * 0.24f)
                        close()
                    }
                    drawPath(spike, Brush.linearGradient(listOf(style.accentColor, ctx.primary)))
                    drawPath(spike, EspressoDark, style = Stroke(2.2f, join = StrokeJoin.Round))
                }
            }
        }
        EvolutionCrownStyle.ASH_FLARE, EvolutionCrownStyle.BLUE_SERAPH_FLAME -> {
            // Track 2 Apex Tier: twin blazing blue-white plasma seraph shoulder-wings behind the torso!
            if (style.crownStyle == EvolutionCrownStyle.BLUE_SERAPH_FLAME && ctx.isApexTier) {
                val wingWave = sin(ctx.animTime * 3.0f) * ry * 0.14f
                for (side in listOf(-1f, 1f)) {
                    val wing = Path().apply {
                        moveTo(c.x + side * rx * 0.64f, c.y - ry * 0.24f)
                        quadraticTo(c.x + side * rx * 1.65f, c.y - ry * 1.15f + wingWave, c.x + side * rx * 1.88f, c.y - ry * 0.36f + wingWave)
                        quadraticTo(c.x + side * rx * 1.32f, c.y + ry * 0.14f, c.x + side * rx * 0.72f, c.y + ry * 0.18f)
                        close()
                    }
                    drawPath(wing, Brush.linearGradient(listOf(Color.White, style.eyeColor, style.accentColor)))
                    drawPath(wing, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
                }
            }
            val flameSway = sin(ctx.animTime * 3.0f) * (rx * 0.10f)
            val outerFlame = Path().apply {
                moveTo(c.x - rx * 0.64f, c.y - ry * 0.74f)
                quadraticTo(c.x - rx * 0.28f, c.y - ry * 1.36f, c.x + flameSway, c.y - ry * 1.76f)
                quadraticTo(c.x + rx * 0.28f, c.y - ry * 1.36f, c.x + rx * 0.64f, c.y - ry * 0.74f)
                close()
            }
            val innerFlame = Path().apply {
                moveTo(c.x - rx * 0.32f, c.y - ry * 0.80f)
                lineTo(c.x + flameSway * 0.6f, c.y - ry * 1.42f)
                lineTo(c.x + rx * 0.32f, c.y - ry * 0.80f)
                close()
            }
            drawPath(outerFlame, Brush.verticalGradient(listOf(style.eyeColor, style.accentColor), c.y - ry * 1.76f, c.y - ry * 0.74f))
            drawPath(innerFlame, Color.White.copy(alpha = 0.88f))
            drawPath(outerFlame, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))

            if (style.crownStyle == EvolutionCrownStyle.BLUE_SERAPH_FLAME) {
                for (k in 0 until 4) {
                    val ka = ctx.orbitAngle * 2f + k * (PI.toFloat() / 2f)
                    val kp = Offset(c.x + cos(ka) * rx * 1.48f, c.y + sin(ka) * ry * 0.84f)
                    drawCircle(style.accentColor.copy(alpha = 0.38f), rx * 0.32f, kp)
                    drawCircle(style.accentColor, rx * 0.18f, kp)
                    drawCircle(Color.White, rx * 0.08f, kp)
                }
            }
        }
        else -> {
            // Track 2 Mid Tier FURNACE_CHIMNEY adds twin dorsal iron exhaust stacks above pauldrons
            if (ctx.isMidTier) {
                for (side in listOf(-1f, 1f)) {
                    val ex = c.x + side * rx * 0.56f - pxTurn * 0.35f
                    val topY = c.y - ry * 1.24f
                    drawRoundRect(
                        color = Color(0xFF2A2229),
                        topLeft = Offset(ex - rx * 0.16f, topY),
                        size = Size(rx * 0.32f, ry * 0.46f),
                        cornerRadius = CornerRadius(rx * 0.08f, rx * 0.08f)
                    )
                    drawCircle(style.accentColor.copy(alpha = 0.65f * emberPulse), rx * 0.15f, Offset(ex, topY))
                    drawRoundRect(
                        EspressoDark,
                        topLeft = Offset(ex - rx * 0.16f, topY),
                        size = Size(rx * 0.32f, ry * 0.46f),
                        cornerRadius = CornerRadius(rx * 0.08f, rx * 0.08f),
                        style = Stroke(2.0f)
                    )
                }
            }
            // Rugged faceted charcoal shoulder pauldrons with glowing magma vents
            for (side in listOf(-1f, 1f)) {
                val px = c.x + side * rx * 0.76f - pxTurn * 0.35f
                val py = c.y - ry * 0.66f
                val pauldron = Path().apply {
                    moveTo(px - side * rx * 0.34f, py - ry * 0.30f)
                    lineTo(px + side * rx * 0.38f, py - ry * 0.22f)
                    lineTo(px + side * rx * 0.26f, py + ry * 0.32f)
                    lineTo(px - side * rx * 0.28f, py + ry * 0.24f)
                    close()
                }
                drawPath(pauldron, Brush.linearGradient(listOf(ctx.secondary, ctx.primary)))
                drawCircle(style.accentColor.copy(alpha = 0.90f * emberPulse), rx * 0.12f, Offset(px, py))
                drawCircle(Color(0xFFFFF4C0), rx * 0.05f, Offset(px, py))
                drawPath(pauldron, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
            }
        }
    }

    // 4. Broad-shouldered faceted charcoal golem torso
    val bodyPath = Path().apply {
        moveTo(c.x - rx * 0.84f, c.y - ry * 0.82f)
        lineTo(c.x, c.y - ry * 1.06f)
        lineTo(c.x + rx * 0.84f, c.y - ry * 0.82f)
        quadraticTo(c.x + rx * 1.16f, c.y - ry * 0.08f, c.x + rx * 0.90f, c.y + ry * 0.82f)
        quadraticTo(c.x, c.y + ry * 1.08f, c.x - rx * 0.90f, c.y + ry * 0.82f)
        quadraticTo(c.x - rx * 1.16f, c.y - ry * 0.08f, c.x - rx * 0.84f, c.y - ry * 0.82f)
        close()
    }
    drawPath(
        path = bodyPath,
        brush = Brush.radialGradient(
            colors = listOf(ctx.secondary, ctx.primary, Color(0xFF171216)),
            center = Offset(c.x - rx * 0.26f, c.y - ry * 0.36f),
            radius = rx * 1.48f
        )
    )
    // Chamfered obsidian mineral sheen on upper brow
    drawGlossySpecular(Offset(c.x - rx * 0.26f, c.y - ry * 0.64f), rx * 0.38f, ry * 0.14f, alpha = 0.18f)
    drawCelRimArc(c, rx * 0.90f, ry * 0.86f, color = Color(0xFFFFB284).copy(alpha = 0.28f), startAngle = 210f, sweepAngle = 62f)

    // 5. Blazing branching magma furnace chest fissure with 2.5D forward parallax (splits wide on attack/Overdrive)
    val fx = c.x + pxTurn * 0.65f
    val furnaceCenter = Offset(fx, c.y + ry * 0.32f)
    val glowRadius = rx * (if (isFiring) (0.98f + attackPulse * 0.42f) else 0.70f) * emberPulse
    drawCircle(
        brush = Brush.radialGradient(
            listOf(
                style.eyeColor.copy(alpha = if (isFiring) 0.98f else 0.62f),
                style.accentColor.copy(alpha = if (isFiring) 0.64f else 0.28f),
                Color.Transparent
            ),
            center = furnaceCenter,
            radius = glowRadius
        ),
        radius = glowRadius,
        center = furnaceCenter
    )
    // Open incandescent furnace core cavity when attacking/ulting/Overdrive (<50% HP)
    if (isFiring) {
        val cavityBoost = 1f + attackPulse * 0.38f + if (isOverdrive) 0.16f else 0f
        drawOval(
            brush = Brush.radialGradient(listOf(Color.White, style.eyeColor, style.accentColor), furnaceCenter, rx * 0.46f * cavityBoost),
            topLeft = Offset(fx - rx * 0.38f * cavityBoost, c.y + ry * 0.16f - ry * 0.04f * attackPulse),
            size = Size(rx * 0.76f * cavityBoost, ry * 0.34f * cavityBoost)
        )
    }
    val fissurePath = Path().apply {
        moveTo(fx - rx * 0.56f, c.y + ry * 0.18f)
        lineTo(fx - rx * 0.14f, c.y + ry * 0.32f)
        lineTo(fx + rx * 0.16f, c.y + ry * 0.24f)
        lineTo(fx + rx * 0.56f, c.y + ry * 0.36f)
    }
    val subCrack = Path().apply {
        moveTo(fx - rx * 0.14f, c.y + ry * 0.32f)
        lineTo(fx, c.y + ry * 0.64f)
        lineTo(fx + rx * 0.28f, c.y + ry * 0.56f)
    }
    drawPath(fissurePath, style.accentColor, style = Stroke((if (isFiring) 8.2f else 5.4f) + attackPulse * 3.0f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    drawPath(subCrack, style.accentColor, style = Stroke((if (isFiring) 5.8f else 4.0f) + attackPulse * 2.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    drawPath(fissurePath, Color(0xFFFFFAD2), style = Stroke((if (isFiring) 3.6f else 2.2f) + attackPulse * 1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round))

    // 6. Fierce glowing ember eyes beneath sculpted obsidian brow
    val eyeR = rx * (0.18f + attackPulse * 0.04f)
    drawGlowingPupilEye(
        center = Offset(c.x - rx * 0.30f + ctx.lookX + pxTurn * 0.45f, c.y - ry * 0.26f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = 0.68f + attackPulse * 0.22f,
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = false,
        eyeFlare = maxOf(attackPulse, if (isOverdrive) 0.55f else 0f)
    )
    drawGlowingPupilEye(
        center = Offset(c.x + rx * 0.30f + ctx.lookX + pxTurn * 0.45f, c.y - ry * 0.26f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = -(0.68f + attackPulse * 0.22f),
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = true,
        eyeFlare = maxOf(attackPulse, if (isOverdrive) 0.55f else 0f)
    )

    // Rising animated ember sparks above shoulders (exact 2*PI period = seamless loop)
    val twoPi = (2.0 * PI).toFloat()
    for (s in 0 until 2) {
        val phase = ((ctx.animTime / twoPi + s * 0.5f) % 1f).let { if (it < 0f) it + 1f else it }
        val sx = c.x + (if (s == 0) -0.58f else 0.52f) * rx + sin(ctx.animTime * 3.0f + s) * rx * 0.10f
        val sy = c.y - ry * (0.72f + phase * 0.85f)
        drawCircle(style.eyeColor.copy(alpha = (1f - phase) * 0.85f), rx * 0.08f * (1f - phase * 0.4f), Offset(sx, sy))
    }

    drawPath(bodyPath, EspressoDark, style = Stroke(3.0f, join = StrokeJoin.Round))
}

/**
 * 对旋双壳 (shell) — Counter-Rotating Twin Hydro-Shell Sprite:
 * Fluted pearlescent twin turbine shells with visible opposite-direction spin ribs,
 * foaming back-and-front double-vortex currents, luminous pearl core, deep sapphire visor
 * with expressive glossy blinking eyes, and hydro-spout / abyssal prism branches.
 */
internal fun DrawScope.drawShellHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val hurtClamp = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f) * ry * 0.12f
    val pxTurn = ctx.turnX * rx * 0.14f
    // Exact 2x orbitAngle frequency = seamless counter-rotation with zero wrap snap
    val spinPhase = ctx.orbitAngle * 2.0f + (1f - ctx.attackProgress) * 5.6f * (if (ctx.attackProgress > 0.01f) 1f else 0f)

    // 1. Lower surging tide ring + Track 2 Mid/Apex Tier hydro-fins & twin side water-jets
    if (style.crownStyle == EvolutionCrownStyle.VORTEX_WINGS && ctx.isMidTier) {
        val finFlap = sin(ctx.animTime * 2.5f) * ry * 0.08f
        for (side in listOf(-1f, 1f)) {
            val fin = Path().apply {
                moveTo(c.x + side * rx * 0.92f, c.y - ry * 0.18f)
                lineTo(c.x + side * rx * 1.56f, c.y - ry * 0.56f + finFlap)
                lineTo(c.x + side * rx * 1.24f, c.y + ry * 0.22f)
                close()
            }
            drawPath(fin, Brush.linearGradient(listOf(Color.White, style.accentColor)))
            drawPath(fin, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
        }
    }
    if (style.crownStyle == EvolutionCrownStyle.TIDAL_SPOUT) {
        drawOval(
            brush = Brush.radialGradient(listOf(style.accentColor.copy(alpha = 0.70f), Color.Transparent), Offset(c.x, c.y + ry * 0.78f), rx * 1.18f),
            topLeft = Offset(c.x - rx * 1.08f, c.y + ry * 0.45f),
            size = Size(rx * 2.16f, ry * 0.78f)
        )
        drawOval(
            color = Color.White.copy(alpha = 0.76f),
            topLeft = Offset(c.x - rx * 0.70f, c.y + ry * 0.62f),
            size = Size(rx * 1.40f, ry * 0.42f),
            style = Stroke(2.8f)
        )
        // Track 2 Apex Tier: roaring twin pressurized side hydro-jets + regal fin crest
        if (ctx.isApexTier) {
            val jetWave = sin(ctx.animTime * 4.0f) * ry * 0.10f
            for (side in listOf(-1f, 1f)) {
                val jet = Path().apply {
                    moveTo(c.x + side * rx * 0.92f, c.y - ry * 0.08f)
                    quadraticTo(c.x + side * rx * 1.72f, c.y - ry * 0.76f + jetWave, c.x + side * rx * 1.84f, c.y - ry * 0.10f + jetWave)
                    quadraticTo(c.x + side * rx * 1.38f, c.y + ry * 0.26f, c.x + side * rx * 0.96f, c.y + ry * 0.18f)
                    close()
                }
                drawPath(jet, Brush.linearGradient(listOf(Color.White, Color(0xFF7BE8FF), style.accentColor)))
                drawPath(jet, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
            }
        }
    }

    // 2. Back-layer aqua water-vortex ribbon (widens & speeds up during torque attack!)
    val backVortexScale = 1f + attackPulse * 0.16f
    drawArc(
        color = style.accentColor.copy(alpha = (0.56f + attackPulse * 0.34f).coerceAtMost(0.92f)),
        startAngle = ctx.orbitAngle * 57.29578f + attackPulse * 145f,
        sweepAngle = 240f + attackPulse * 48f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 1.58f * backVortexScale, c.y - ry * 0.96f * backVortexScale),
        size = Size(rx * 3.16f * backVortexScale, ry * 1.92f * backVortexScale),
        style = Stroke(width = 9.2f + attackPulse * 3.8f, cap = StrokeCap.Round)
    )

    // 3. Reef / Abyssal faceted crystal crown behind upper shell
    if (style.crownStyle == EvolutionCrownStyle.REEF_FORTRESS || style.crownStyle == EvolutionCrownStyle.ABYSS_CITADEL) {
        val crystalCount = if (style.crownStyle == EvolutionCrownStyle.ABYSS_CITADEL) 5 else 3
        for (i in 0 until crystalCount) {
            val frac = i - (crystalCount - 1) / 2f
            val a = -PI.toFloat() / 2f + frac * 0.38f
            val basePt = Offset(c.x + cos(a) * rx * 0.86f, c.y + sin(a) * ry * 0.86f)
            val tipPt = Offset(c.x + cos(a) * rx * 1.52f, c.y + sin(a) * ry * 1.52f)
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
        // Track 2 Apex Tier: 3 orbiting frost-crystal Aegis diamond shields!
        if (style.crownStyle == EvolutionCrownStyle.ABYSS_CITADEL && ctx.isApexTier) {
            for (s in 0 until 3) {
                val sa = -ctx.orbitAngle + s * 2.0943952f
                val sp = Offset(c.x + cos(sa) * rx * 1.62f, c.y + sin(sa) * ry * 0.72f)
                val shield = Path().apply {
                    moveTo(sp.x, sp.y - ry * 0.24f)
                    lineTo(sp.x + rx * 0.18f, sp.y)
                    lineTo(sp.x, sp.y + ry * 0.24f)
                    lineTo(sp.x - rx * 0.18f, sp.y)
                    close()
                }
                drawPath(shield, Brush.linearGradient(listOf(Color.White, style.accentColor)))
                drawPath(shield, EspressoDark, style = Stroke(1.8f, join = StrokeJoin.Round))
            }
        }
    }

    // 4. Twin Counter-Rotating Armored Shells with live opposite-direction turbine ribs
    drawCircle(
        brush = Brush.radialGradient(listOf(Color.White, style.accentColor, ctx.primary), c, rx * 1.04f),
        radius = rx * 0.96f,
        center = c
    )

    // Upper sculpted fluted shell dome (clamps slightly downward on hurt!)
    val upperY = c.y + hurtClamp
    val upperShell = Path().apply {
        moveTo(c.x - rx * 1.06f, upperY - ry * 0.14f)
        quadraticTo(c.x - rx * 0.96f, upperY - ry * 1.14f, c.x, upperY - ry * 1.10f)
        quadraticTo(c.x + rx * 0.96f, upperY - ry * 1.14f, c.x + rx * 1.06f, upperY - ry * 0.14f)
        quadraticTo(c.x, upperY - ry * 0.34f, c.x - rx * 1.06f, upperY - ry * 0.14f)
        close()
    }
    drawPath(
        upperShell,
        Brush.verticalGradient(listOf(ctx.secondary, ctx.primary), upperY - ry * 1.10f, upperY)
    )
    // Counter-rotating upper turbine flutes (+spinPhase, turbocharged on strike!)
    val upperShift = sin(spinPhase) * rx * (0.14f + attackPulse * 0.12f)
    for (rib in listOf(-0.48f, 0f, 0.48f)) {
        val topX = c.x + rib * rx * 0.62f + upperShift * 0.5f
        val botX = c.x + rib * rx * 0.90f + upperShift
        drawLine(
            Color.White.copy(alpha = 0.48f + attackPulse * 0.38f),
            Offset(topX, upperY - ry * 0.96f),
            Offset(botX, upperY - ry * 0.30f),
            2.6f + attackPulse * 1.4f,
            StrokeCap.Round
        )
    }
    drawGlossySpecular(Offset(c.x - rx * 0.24f, upperY - ry * 0.74f), rx * 0.36f, ry * 0.14f, alpha = 0.38f)
    // Iridescent mother-of-pearl crown emblem at shell apex (2.5D forward parallax)
    val emblemX = c.x + pxTurn * 0.55f
    drawCircle(Color(0xFF9DF6FF), rx * (0.13f + attackPulse * 0.04f), Offset(emblemX, upperY - ry * 0.96f))
    drawCircle(Color.White, rx * 0.055f, Offset(emblemX - rx * 0.03f, upperY - ry * 0.99f))
    drawCircle(EspressoDark, rx * 0.13f, Offset(emblemX, upperY - ry * 0.96f), style = Stroke(1.8f))
    drawPath(upperShell, EspressoDark, style = Stroke(2.8f, join = StrokeJoin.Round))

    // Lower armored keel shell with opposite counter-rotating ribs (-spinPhase, clamps up on hurt!)
    val lowerY = c.y - hurtClamp
    val lowerShell = Path().apply {
        moveTo(c.x - rx * 1.04f, lowerY + ry * 0.22f)
        quadraticTo(c.x, lowerY + ry * 0.44f, c.x + rx * 1.04f, lowerY + ry * 0.22f)
        quadraticTo(c.x + rx * 0.88f, lowerY + ry * 1.08f, c.x, lowerY + ry * 1.06f)
        quadraticTo(c.x - rx * 0.88f, lowerY + ry * 1.08f, c.x - rx * 1.04f, lowerY + ry * 0.22f)
        close()
    }
    drawPath(
        lowerShell,
        Brush.verticalGradient(listOf(ctx.primary, Color(0xFF14325B)), lowerY + ry * 0.20f, lowerY + ry * 1.08f)
    )
    val lowerShift = -sin(spinPhase) * rx * (0.14f + attackPulse * 0.12f)
    for (rib in listOf(-0.44f, 0f, 0.44f)) {
        drawLine(
            style.accentColor.copy(alpha = 0.50f + attackPulse * 0.36f),
            Offset(c.x + rib * rx * 0.82f + lowerShift, lowerY + ry * 0.42f),
            Offset(c.x + rib * rx * 0.56f + lowerShift * 0.5f, lowerY + ry * 0.96f),
            2.4f + attackPulse * 1.4f,
            StrokeCap.Round
        )
    }
    drawPath(lowerShell, EspressoDark, style = Stroke(2.8f, join = StrokeJoin.Round))

    // 5. Deep sapphire visor gap with 2.5D forward parallax + large expressive blinking/wincing eyes
    val vx = c.x + pxTurn * 0.50f
    drawOval(
        color = Color(0xFF0E163B),
        topLeft = Offset(vx - rx * 0.78f, c.y - ry * 0.24f),
        size = Size(rx * 1.56f, ry * 0.56f)
    )
    drawOval(
        color = style.accentColor.copy(alpha = 0.42f + attackPulse * 0.42f),
        topLeft = Offset(vx - rx * 0.76f, c.y - ry * 0.22f),
        size = Size(rx * 1.52f, ry * 0.52f),
        style = Stroke(1.8f + attackPulse * 1.4f)
    )
    val eyeR = rx * (0.20f + attackPulse * 0.04f)
    val leftEye = Offset(vx - rx * 0.29f + ctx.lookX * 0.55f, c.y + ry * 0.04f + ctx.lookY * 0.45f)
    val rightEye = Offset(vx + rx * 0.29f + ctx.lookX * 0.55f, c.y + ry * 0.04f + ctx.lookY * 0.45f)
    val shellTilt = if (ctx.isAttacking || ctx.isUltActive) 0.52f else 0f
    drawGlowingPupilEye(leftEye, eyeR, style.eyeColor, angryTilt = shellTilt, blinkFactor = ctx.blinkFactor, isHurt = ctx.isHurt, isRightEye = false, eyeFlare = attackPulse)
    drawGlowingPupilEye(rightEye, eyeR, style.eyeColor, angryTilt = -shellTilt, blinkFactor = ctx.blinkFactor, isHurt = ctx.isHurt, isRightEye = true, eyeFlare = attackPulse)

    // 6. Front-layer foaming aqua vortex arc & sparkling water droplets (exact integer revolutions = seamless)
    drawArc(
        color = Color.White.copy(alpha = 0.92f),
        startAngle = -ctx.orbitAngle * 57.29578f - attackPulse * 180f,
        sweepAngle = 150f + attackPulse * 45f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 1.36f * backVortexScale, c.y - ry * 0.80f * backVortexScale),
        size = Size(rx * 2.72f * backVortexScale, ry * 1.60f * backVortexScale),
        style = Stroke(width = 4.6f + attackPulse * 2.4f, cap = StrokeCap.Round)
    )
    for (d in 0 until 4) {
        val da = ctx.orbitAngle + d * (PI.toFloat() / 2f) + attackPulse * 2.2f
        val dp = Offset(c.x + cos(da) * rx * (1.48f + attackPulse * 0.24f), c.y + sin(da) * ry * (0.88f + attackPulse * 0.16f))
        drawCircle(style.accentColor.copy(alpha = 0.45f + attackPulse * 0.35f), rx * (0.14f + attackPulse * 0.05f), dp)
        drawCircle(Color.White.copy(alpha = 0.94f), rx * 0.08f, dp)
    }
}
