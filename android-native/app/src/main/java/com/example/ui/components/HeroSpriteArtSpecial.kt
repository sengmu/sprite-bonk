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
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * 雷铃狐 (spark) — Painted-Ceramic Shrine Thunder Fox:
 * Tri-tone kitsune ears with dark tips & gold rings, crackling forked lightning tail(s) with electric arcs,
 * fluffy chest ruff, crimson shrine cheek-markings, fluttering shrine collar ribbon + 3D brass thunder bell,
 * expressive blinking/wincing fox eyes + cute muzzle, 2.5D parallax, and distinct Mid/Apex silhouettes.
 */
internal fun DrawScope.drawSparkHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val hurtJolt = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f)
    val pxTurn = ctx.turnX * rx * 0.14f
    val dashBackX = if (ctx.isDashing) -ctx.turnX * rx * 0.34f else 0f

    // 1. Storm Halo: floating taiko thunder drums linked by golden arc
    if (style.crownStyle == EvolutionCrownStyle.STORM_HALO) {
        drawArc(
            color = style.accentColor.copy(alpha = 0.58f + attackPulse * 0.32f),
            startAngle = 195f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 1.46f - pxTurn * 0.3f, c.y - ry * 1.48f),
            size = Size(rx * 2.92f, ry * 2.54f),
            style = Stroke(3.2f + attackPulse * 1.6f, cap = StrokeCap.Round)
        )
        val drums = if (ctx.isApexTier) 5 else 3
        for (d in 0 until drums) {
            val a = -PI.toFloat() + (d + 1) * (PI.toFloat() / (drums + 1)) + sin(ctx.animTime * 0.5f) * 0.08f
            val dp = Offset(c.x + cos(a) * rx * 1.44f - pxTurn * 0.3f, c.y + sin(a) * ry * 1.30f)
            drawCircle(style.accentColor.copy(alpha = 0.36f + attackPulse * 0.34f), rx * (0.34f + attackPulse * 0.08f), dp)
            drawCircle(style.accentColor, rx * 0.22f, dp)
            drawCircle(Color.White, rx * 0.09f, dp)
            drawCircle(EspressoDark, rx * 0.22f, dp, style = Stroke(2.0f))
        }
    }

    // Track 2 Apex Tier (PLASMA_VISOR): floating twin cyber-antenna fin blades behind ears!
    if (style.crownStyle == EvolutionCrownStyle.PLASMA_VISOR && ctx.isApexTier) {
        val finFloat = sin(ctx.animTime * 2.0f) * ry * 0.08f
        for (side in listOf(-1f, 1f)) {
            val blade = Path().apply {
                moveTo(c.x + side * rx * 1.05f - pxTurn * 0.4f, c.y - ry * 0.44f + finFloat)
                lineTo(c.x + side * rx * 1.72f - pxTurn * 0.4f, c.y - ry * 1.26f + finFloat)
                lineTo(c.x + side * rx * 1.38f - pxTurn * 0.4f, c.y - ry * 0.14f + finFloat)
                close()
            }
            drawPath(blade, Brush.linearGradient(listOf(Color.White, style.accentColor)))
            drawPath(blade, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
        }
    }

    // 2. Animated forked zig-zag lightning fox tail (snaps forward on attack; Apex STORM_HALO gets twin tails!)
    val tailWag = sin(ctx.animTime * 2.5f) * (ry * 0.14f) - attackPulse * ry * 0.32f
    val tailSides = if (style.crownStyle == EvolutionCrownStyle.STORM_HALO && ctx.isApexTier) listOf(-1f, 1f) else listOf(1f)
    for (ts in tailSides) {
        val tailReach = 1f + attackPulse * 0.28f
        val tx = c.x - pxTurn * 0.55f + dashBackX
        val tailPath = Path().apply {
            moveTo(tx + ts * rx * 0.54f, c.y + ry * 0.40f)
            lineTo(tx + ts * rx * 1.28f * tailReach, c.y + ry * 0.06f + tailWag)
            lineTo(tx + ts * rx * 1.04f * tailReach, c.y - ry * 0.22f + tailWag)
            lineTo(tx + ts * rx * 1.66f * tailReach, c.y - ry * 0.72f + tailWag * 1.25f)
            lineTo(tx + ts * rx * 1.42f * tailReach, c.y + ry * 0.04f + tailWag * 0.85f)
            lineTo(tx + ts * rx * 1.56f * tailReach, c.y + ry * 0.30f + tailWag * 0.65f)
            lineTo(tx + ts * rx * 1.18f, c.y + ry * 0.50f + tailWag * 0.55f)
            close()
        }
        drawPath(tailPath, Brush.linearGradient(listOf(Color.White, style.accentColor, ctx.primary)))
        drawPath(tailPath, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
    }
    // Live crackling cyan-white spark leaping near tail tip
    val sparkPhase = sin(ctx.animTime * 8.0f)
    if (sparkPhase > -0.25f || attackPulse > 0.15f) {
        val sp1 = Offset(c.x + rx * 1.44f - pxTurn * 0.5f, c.y - ry * 0.68f + tailWag)
        val sp2 = Offset(c.x + rx * 1.72f - pxTurn * 0.5f, c.y - ry * 0.36f + tailWag)
        val spMid = Offset(c.x + rx * 1.64f - pxTurn * 0.5f, c.y - ry * 0.54f + tailWag)
        drawLine(Color.White, sp1, spMid, 2.2f + attackPulse * 1.6f, StrokeCap.Round)
        drawLine(style.accentColor, spMid, sp2, 2.2f + attackPulse * 1.6f, StrokeCap.Round)
    }

    // 3. Tall tri-tone pointed kitsune ears (flatten back when hurt or dashing!)
    val earWag = sin(ctx.animTime * 1.5f) * (rx * 0.07f)
    val earFlattenY = hurtJolt * ry * 0.42f + if (ctx.isDashing) ry * 0.22f else 0f
    val earSpreadX = hurtJolt * rx * 0.26f
    for (side in listOf(-1f, 1f)) {
        val tipX = c.x + side * (rx * 1.06f + earSpreadX) - side * earWag + dashBackX * 0.8f - pxTurn * 0.25f
        val tipY = c.y - ry * 1.62f + earFlattenY
        val outerEar = Path().apply {
            moveTo(c.x + side * rx * 0.70f, c.y - ry * 0.38f)
            lineTo(tipX, tipY)
            lineTo(c.x + side * rx * 0.14f, c.y - ry * 0.78f)
            close()
        }
        val earTip = Path().apply {
            moveTo(tipX, tipY)
            lineTo(c.x + side * rx * 0.90f - side * earWag * 0.75f + dashBackX * 0.5f, c.y - ry * 1.18f + earFlattenY * 0.7f)
            lineTo(c.x + side * rx * 0.68f - side * earWag * 0.65f + dashBackX * 0.4f, c.y - ry * 1.24f + earFlattenY * 0.7f)
            close()
        }
        val innerEar = Path().apply {
            moveTo(c.x + side * rx * 0.58f, c.y - ry * 0.54f)
            lineTo(c.x + side * rx * 0.84f - side * earWag * 0.8f + dashBackX * 0.5f, c.y - ry * 1.24f + earFlattenY * 0.75f)
            lineTo(c.x + side * rx * 0.28f, c.y - ry * 0.76f)
            close()
        }
        drawPath(outerEar, Brush.verticalGradient(listOf(ctx.secondary, ctx.primary), tipY, c.y - ry * 0.38f))
        drawPath(earTip, Color(0xFF282032))
        drawPath(innerEar, Color(0xFFFFF2C4))
        drawPath(outerEar, EspressoDark, style = Stroke(2.6f, join = StrokeJoin.Round))
        // Delicate golden shrine ear-ring on outer edge (+ Mid-tier dangling shrine tassel!)
        if (side > 0f || (style.crownStyle == EvolutionCrownStyle.CHIME_EARS && ctx.isMidTier)) {
            val ringPos = Offset(c.x + side * rx * 0.86f - side * earWag * 0.5f, c.y - ry * 0.86f + earFlattenY * 0.45f)
            drawCircle(GoldAccent, rx * 0.12f, ringPos, style = Stroke(2.4f))
            if (ctx.isMidTier) {
                drawLine(Color(0xFFD93B3B), Offset(ringPos.x, ringPos.y + rx * 0.12f), Offset(ringPos.x + side * rx * 0.08f, ringPos.y + ry * 0.38f), 2.8f, StrokeCap.Round)
            }
        }
    }

    // 4. Fluttering crimson shrine ribbon tails (or plasma energy scarf for Apex PLASMA_VISOR)
    val ribbonWave = sin(ctx.animTime * 3.0f) * (ry * 0.12f)
    val ribbonCol = if (style.crownStyle == EvolutionCrownStyle.PLASMA_VISOR && ctx.isApexTier) style.accentColor else Color(0xFFD93B3B)
    val ribbonTail = Path().apply {
        moveTo(c.x - rx * 0.72f - pxTurn * 0.3f, c.y + ry * 0.34f)
        quadraticTo(c.x - rx * 1.22f + dashBackX, c.y + ry * 0.44f + ribbonWave, c.x - rx * 1.48f + dashBackX * 1.2f, c.y + ry * 0.78f + ribbonWave)
        lineTo(c.x - rx * 1.12f + dashBackX, c.y + ry * 0.82f + ribbonWave * 0.8f)
        quadraticTo(c.x - rx * 0.96f, c.y + ry * 0.56f, c.x - rx * 0.64f - pxTurn * 0.3f, c.y + ry * 0.48f)
        close()
    }
    drawPath(ribbonTail, ribbonCol)
    drawPath(ribbonTail, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))

    // 5. Nimble ceramic paws
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing else -ctx.footSwing
        val paw = Offset(c.x + side * rx * 0.48f, c.y + ry * 0.88f + fSwing)
        drawCircle(ctx.secondary, rx * 0.26f, paw)
        drawCircle(EspressoDark, rx * 0.26f, paw, style = Stroke(2.2f))
    }

    // 6. Sculpted glazed-ceramic fox body + cream cheeks/muzzle + cel rim highlight
    drawCircle(
        Brush.radialGradient(listOf(ctx.secondary, ctx.primary), Offset(c.x - rx * 0.26f, c.y - ry * 0.36f), rx * 1.32f),
        rx * 0.98f,
        c
    )
    drawCelRimArc(c, rx * 0.88f, ry * 0.88f, color = Color.White.copy(alpha = 0.46f), startAngle = 200f, sweepAngle = 72f)
    // Cream muzzle & fluffy cheek-tuft oval (2.5D forward parallax)
    val faceX = c.x + pxTurn * 0.58f
    drawOval(
        color = Color(0xFFFFFAEA).copy(alpha = 0.92f),
        topLeft = Offset(faceX - rx * 0.66f, c.y + ry * 0.06f),
        size = Size(rx * 1.32f, ry * 0.78f)
    )
    drawGlossySpecular(Offset(c.x - rx * 0.28f, c.y - ry * 0.54f), rx * 0.32f, ry * 0.14f, alpha = 0.36f)

    // Painted crimson kitsune cheek-markings & rosy electric sparks
    for (side in listOf(-1f, 1f)) {
        val cx = faceX + side * rx * 0.54f + ctx.lookX * 0.35f
        val cy = c.y + ry * 0.20f + ctx.lookY * 0.3f
        drawCircle(Color(0xFFFF7A5C).copy(alpha = 0.68f + attackPulse * 0.28f), rx * (0.14f + attackPulse * 0.04f), Offset(cx, cy))
        drawLine(
            Color(0xFFD93B3B),
            Offset(cx - side * rx * 0.08f, cy - ry * 0.05f),
            Offset(cx + side * rx * 0.14f, cy - ry * 0.09f),
            2.2f,
            StrokeCap.Round
        )
        drawLine(
            Color(0xFFD93B3B),
            Offset(cx - side * rx * 0.06f, cy + ry * 0.06f),
            Offset(cx + side * rx * 0.14f, cy + ry * 0.05f),
            2.0f,
            StrokeCap.Round
        )
    }

    // Tiny cute fox nose + expressive smile / battle grin
    val nosePt = Offset(faceX + ctx.lookX * 0.65f, c.y + ry * 0.14f + ctx.lookY * 0.5f)
    drawCircle(EspressoDark, rx * 0.075f, nosePt)
    drawArc(
        color = EspressoDark,
        startAngle = 15f,
        sweepAngle = 150f,
        useCenter = false,
        topLeft = Offset(nosePt.x - rx * 0.17f, nosePt.y + ry * 0.01f),
        size = Size(rx * 0.34f, ry * (if (ctx.isAttacking || ctx.isUltActive) 0.24f else 0.15f)),
        style = Stroke(2.2f, cap = StrokeCap.Round)
    )

    // Crimson shrine collar + gleaming 3D golden thunder bell (flares brightly on attack & quirk!)
    drawArc(
        color = Color(0xFFD93B3B),
        startAngle = 22f,
        sweepAngle = 136f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 0.82f, c.y + ry * 0.08f),
        size = Size(rx * 1.64f, ry * 0.74f),
        style = Stroke(5.4f, cap = StrokeCap.Round)
    )
    val bellJitter = sin(ctx.quirkProgress * 28f) * rx * 0.08f * ctx.quirkProgress
    val bellCenter = Offset(faceX + bellJitter, c.y + ry * 0.62f)
    if (attackPulse > 0.12f || ctx.quirkProgress > 0.1f) {
        val bellGlow = maxOf(attackPulse, ctx.quirkProgress)
        drawCircle(GoldAccent.copy(alpha = bellGlow * 0.52f), rx * (0.46f + bellGlow * 0.18f), bellCenter)
    }
    drawCircle(
        Brush.radialGradient(listOf(Color(0xFFFFF5B8), GoldAccent, Color(0xFFC28212)), Offset(bellCenter.x - rx * 0.07f, bellCenter.y - ry * 0.08f), rx * 0.30f),
        rx * (0.25f + attackPulse * 0.04f),
        bellCenter
    )
    drawCircle(Color.White.copy(alpha = 0.88f), rx * 0.08f, Offset(bellCenter.x - rx * 0.07f, bellCenter.y - ry * 0.07f))
    drawLine(EspressoDark, Offset(bellCenter.x - rx * 0.14f, bellCenter.y + ry * 0.08f), Offset(bellCenter.x + rx * 0.14f, bellCenter.y + ry * 0.08f), 2.0f, StrokeCap.Round)
    drawCircle(EspressoDark, rx * (0.25f + attackPulse * 0.04f), bellCenter, style = Stroke(2.2f))

    // 7. Sleek Plasma Visor OR bright blinking/wincing fox eyes (Track 1 parity!)
    if (style.crownStyle == EvolutionCrownStyle.PLASMA_VISOR) {
        val visorPos = Offset(faceX - rx * 0.72f + ctx.lookX * 0.35f, c.y - ry * 0.30f + ctx.lookY * 0.4f)
        val visorSize = Size(rx * 1.44f, ry * 0.42f)
        val visorCol = if (ctx.isHurt) Color(0xFFFF5252) else style.accentColor
        drawRoundRect(
            Brush.horizontalGradient(listOf(visorCol, Color.White, visorCol)),
            topLeft = visorPos,
            size = visorSize,
            cornerRadius = CornerRadius(10f, 10f)
        )
        if (ctx.isHurt) {
            // Glitch static crack line across visor on damage
            drawLine(EspressoDark, Offset(visorPos.x + rx * 0.25f, visorPos.y + ry * 0.08f), Offset(visorPos.x + rx * 1.18f, visorPos.y + ry * 0.34f), 2.6f, StrokeCap.Round)
        }
        drawRoundRect(EspressoDark, visorPos, visorSize, CornerRadius(10f, 10f), style = Stroke(2.4f))
    } else {
        val eyeR = rx * (0.19f + attackPulse * 0.035f)
        val foxTilt = if (ctx.isAttacking || ctx.isUltActive) 0.52f else 0.14f
        drawGlowingPupilEye(
            center = Offset(faceX - rx * 0.30f + ctx.lookX * 0.65f, c.y - ry * 0.10f + ctx.lookY),
            radius = eyeR,
            glowColor = style.eyeColor,
            angryTilt = foxTilt,
            blinkFactor = ctx.blinkFactor,
            isHurt = ctx.isHurt,
            isRightEye = false,
            eyeFlare = attackPulse
        )
        drawGlowingPupilEye(
            center = Offset(faceX + rx * 0.30f + ctx.lookX * 0.65f, c.y - ry * 0.10f + ctx.lookY),
            radius = eyeR,
            glowColor = style.eyeColor,
            angryTilt = -foxTilt,
            blinkFactor = ctx.blinkFactor,
            isHurt = ctx.isHurt,
            isRightEye = true,
            eyeFlare = attackPulse
        )
    }
    drawCircle(EspressoDark, rx * 0.98f, c, style = Stroke(3.0f))
}

/**
 * 提灯幽灵 (wisp) — Moon-Bronze Pagoda Lantern Spirit:
 * Sculpted upturned pagoda roof eaves (double-tiered on Apex!) with golden corner chimes,
 * translucent spirit-glass chamber, dancing teardrop phantom-flame silhouette inside with
 * blinking/wincing mischievous eyes & ghostly grin, flowing ethereal spectral tails, orbiting
 * soul comets, 2.5D parallax, and crescent eclipse halo branch.
 */
internal fun DrawScope.drawWispHeroArt(ctx: HeroArtContext) {
    val floatOff = sin(ctx.animTime * 1.5f) * (ctx.ry * 0.11f)
    val c = Offset(ctx.bodyCenter.x, ctx.bodyCenter.y + floatOff)
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val hurtJolt = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f)
    val pxTurn = ctx.turnX * rx * 0.14f
    val dashBackX = if (ctx.isDashing) -ctx.turnX * rx * 0.36f else 0f

    // 1. Orbiting spirit flames with luminous comet trails (expand & intensify on attack!)
    val orbCount = if (ctx.isApexTier) 4 else 2
    val orbExpand = 1f + attackPulse * 0.24f
    for (i in 0 until orbCount) {
        val a = ctx.orbitAngle + i * (2f * PI.toFloat() / orbCount) + attackPulse * 1.6f
        val trailA = a - 0.32f
        val op = Offset(c.x + cos(a) * rx * 1.48f * orbExpand, c.y + sin(a) * ry * 0.86f * orbExpand)
        val tp = Offset(c.x + cos(trailA) * rx * 1.40f * orbExpand, c.y + sin(trailA) * ry * 0.82f * orbExpand)
        drawLine(style.accentColor.copy(alpha = 0.48f + attackPulse * 0.34f), tp, op, rx * (0.19f + attackPulse * 0.06f), StrokeCap.Round)
        drawCircle(style.accentColor.copy(alpha = 0.38f + attackPulse * 0.34f), rx * (0.32f + attackPulse * 0.08f), op)
        drawCircle(style.accentColor, rx * 0.17f, op)
        drawCircle(Color.White, rx * 0.075f, op)
    }

    // 2. Flowing ethereal ghostly tails + swaying golden-crimson shrine tassel
    val tasselSway = sin(ctx.animTime * 2.0f) * (rx * 0.16f) + dashBackX - pxTurn * 0.35f
    for (side in listOf(-1f, 1f)) {
        val wispTail = Path().apply {
            moveTo(c.x + side * rx * 0.36f, c.y + ry * 0.84f)
            quadraticTo(
                c.x + side * rx * 0.62f + tasselSway * 0.6f,
                c.y + ry * 1.18f,
                c.x + side * rx * 0.26f + tasselSway * 1.1f,
                c.y + ry * 1.44f
            )
        }
        drawPath(wispTail, style.accentColor.copy(alpha = 0.42f + attackPulse * 0.32f), style = Stroke(width = rx * 0.16f, cap = StrokeCap.Round))
    }
    drawLine(GoldAccent, Offset(c.x, c.y + ry * 0.94f), Offset(c.x + tasselSway, c.y + ry * 1.42f), 4.2f, StrokeCap.Round)
    drawCircle(style.accentColor, rx * 0.15f, Offset(c.x + tasselSway, c.y + ry * 1.42f))
    drawCircle(EspressoDark, rx * 0.15f, Offset(c.x + tasselSway, c.y + ry * 1.42f), style = Stroke(1.8f))

    // 3. Crown handle OR radiant Moon-Eclipse halo (double-crescent + star beads on Apex!)
    if (style.crownStyle == EvolutionCrownStyle.ECLIPSE_CROWN) {
        drawArc(
            color = style.accentColor,
            startAngle = 195f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 0.86f, c.y - ry * 1.78f),
            size = Size(rx * 1.72f, ry * 1.00f),
            style = Stroke(width = 7.6f, cap = StrokeCap.Round)
        )
        drawCircle(Color.White, rx * 0.14f, Offset(c.x, c.y - ry * 1.76f))
        if (ctx.isApexTier) {
            drawArc(
                color = GoldAccent.copy(alpha = 0.88f),
                startAngle = 205f,
                sweepAngle = 130f,
                useCenter = false,
                topLeft = Offset(c.x - rx * 1.16f, c.y - ry * 2.02f),
                size = Size(rx * 2.32f, ry * 1.24f),
                style = Stroke(width = 3.2f, cap = StrokeCap.Round)
            )
            for (side in listOf(-1f, 1f)) {
                drawCircle(GoldAccent, rx * 0.11f, Offset(c.x + side * rx * 1.04f, c.y - ry * 1.62f))
                drawCircle(Color.White, rx * 0.05f, Offset(c.x + side * rx * 1.04f, c.y - ry * 1.62f))
            }
        }
    } else {
        drawArc(
            color = GoldAccent,
            startAngle = 180f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 0.56f, c.y - ry * 1.64f),
            size = Size(rx * 1.12f, ry * 0.92f),
            style = Stroke(width = 5.2f, cap = StrokeCap.Round)
        )
    }

    // 4. Sculpted lantern chamber + dancing teardrop spirit flame inside (surges on attack!)
    val shellRect = Offset(c.x - rx * 0.92f, c.y - ry * 0.88f)
    val shellSize = Size(rx * 1.84f, ry * 1.78f)
    drawRoundRect(
        Brush.verticalGradient(listOf(ctx.secondary, ctx.primary, Color(0xFF2B1C54))),
        topLeft = shellRect,
        size = shellSize,
        cornerRadius = CornerRadius(rx * 0.60f, rx * 0.60f)
    )
    // Track 2 Mid Tier: ornate golden lantern side corner-frames
    if (ctx.isMidTier) {
        drawRoundRect(
            color = GoldAccent.copy(alpha = 0.62f),
            topLeft = Offset(shellRect.x + rx * 0.08f, shellRect.y + ry * 0.08f),
            size = Size(shellSize.width - rx * 0.16f, shellSize.height - ry * 0.16f),
            cornerRadius = CornerRadius(rx * 0.52f, rx * 0.52f),
            style = Stroke(2.2f)
        )
    }
    // Undulating inner teardrop phantom flame
    val flameBreath = (0.94f + 0.08f * sin(ctx.animTime * 4.0f)) * (1f + attackPulse * 0.24f)
    val flameTipSway = sin(ctx.animTime * 3.0f) * rx * 0.11f + pxTurn * 0.35f
    val spiritFlame = Path().apply {
        moveTo(c.x + flameTipSway, c.y - ry * 0.72f * flameBreath)
        quadraticTo(c.x + rx * 0.78f, c.y - ry * 0.05f, c.x + rx * 0.58f, c.y + ry * 0.54f)
        quadraticTo(c.x, c.y + ry * 0.76f, c.x - rx * 0.58f, c.y + ry * 0.54f)
        quadraticTo(c.x - rx * 0.78f, c.y - ry * 0.05f, c.x + flameTipSway, c.y - ry * 0.72f * flameBreath)
        close()
    }
    drawPath(
        spiritFlame,
        Brush.radialGradient(listOf(Color.White, style.accentColor, ctx.primary.copy(alpha = 0.35f)), c, rx * 0.84f * flameBreath)
    )

    // Ornamental antique bronze ribs + inner glass reflection (with 2.5D shift)
    drawLine(EspressoDark.copy(alpha = 0.58f), Offset(c.x - rx * 0.56f + pxTurn * 0.2f, c.y - ry * 0.82f), Offset(c.x - rx * 0.56f + pxTurn * 0.2f, c.y + ry * 0.82f), 2.5f)
    drawLine(EspressoDark.copy(alpha = 0.58f), Offset(c.x + rx * 0.56f + pxTurn * 0.2f, c.y - ry * 0.82f), Offset(c.x + rx * 0.56f + pxTurn * 0.2f, c.y + ry * 0.82f), 2.5f)
    drawGlossySpecular(Offset(c.x - rx * 0.44f, c.y - ry * 0.42f), rx * 0.14f, ry * 0.28f, alpha = 0.28f)

    // Sculpted upturned Pagoda roof eaves cap (lifts/tilts slightly on hurt!)
    val roofLift = -hurtJolt * ry * 0.14f
    val roofPath = Path().apply {
        moveTo(c.x - rx * 1.18f, c.y - ry * 0.86f + roofLift)
        quadraticTo(c.x - rx * 0.70f, c.y - ry * 0.96f + roofLift, c.x, c.y - ry * 1.24f + roofLift)
        quadraticTo(c.x + rx * 0.70f, c.y - ry * 0.96f + roofLift, c.x + rx * 1.18f, c.y - ry * 0.86f + roofLift)
        quadraticTo(c.x + rx * 0.68f, c.y - ry * 0.74f + roofLift, c.x, c.y - ry * 0.76f + roofLift)
        quadraticTo(c.x - rx * 0.68f, c.y - ry * 0.74f + roofLift, c.x - rx * 1.18f, c.y - ry * 0.86f + roofLift)
        close()
    }
    drawPath(roofPath, Brush.verticalGradient(listOf(Color(0xFF6B5360), Color(0xFF3A2B36))))
    drawPath(roofPath, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))

    // Track 2 Apex Tier (LANTERN_CREST): grand double-tiered imperial pagoda roof + 3 orbiting talisman seals!
    if (style.crownStyle == EvolutionCrownStyle.LANTERN_CREST && ctx.isApexTier) {
        val upperEave = Path().apply {
            moveTo(c.x - rx * 0.88f, c.y - ry * 1.18f + roofLift)
            quadraticTo(c.x - rx * 0.44f, c.y - ry * 1.32f + roofLift, c.x, c.y - ry * 1.62f + roofLift)
            quadraticTo(c.x + rx * 0.44f, c.y - ry * 1.32f + roofLift, c.x + rx * 0.88f, c.y - ry * 1.18f + roofLift)
            quadraticTo(c.x, c.y - ry * 1.10f + roofLift, c.x - rx * 0.88f, c.y - ry * 1.18f + roofLift)
            close()
        }
        drawPath(upperEave, Brush.verticalGradient(listOf(GoldAccent, Color(0xFF594052))))
        drawPath(upperEave, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
        for (t in 0 until 3) {
            val ta = -ctx.orbitAngle + t * 2.0943952f
            val tp = Offset(c.x + cos(ta) * rx * 1.34f, c.y + sin(ta) * ry * 0.62f)
            drawRoundRect(
                color = Color(0xFFFFF4C8),
                topLeft = Offset(tp.x - rx * 0.11f, tp.y - ry * 0.18f),
                size = Size(rx * 0.22f, ry * 0.36f),
                cornerRadius = CornerRadius(3f, 3f)
            )
            drawRoundRect(
                color = EspressoDark,
                topLeft = Offset(tp.x - rx * 0.11f, tp.y - ry * 0.18f),
                size = Size(rx * 0.22f, ry * 0.36f),
                cornerRadius = CornerRadius(3f, 3f),
                style = Stroke(1.5f)
            )
        }
    }

    for (side in listOf(-1f, 1f)) {
        val chimeX = c.x + side * rx * 1.08f
        val chimeY = c.y - ry * 0.68f + roofLift + sin(ctx.animTime * 2.5f + side) * ry * 0.04f
        drawLine(GoldAccent, Offset(chimeX, c.y - ry * 0.84f + roofLift), Offset(chimeX, chimeY), 1.8f)
        drawCircle(GoldAccent, rx * 0.07f, Offset(chimeX, chimeY))
    }

    // Bottom bronze pedestal cap
    drawRoundRect(Color(0xFF473742), Offset(c.x - rx * 0.66f, c.y + ry * 0.78f), Size(rx * 1.32f, ry * 0.22f), CornerRadius(8f, 8f))
    drawRoundRect(EspressoDark, Offset(c.x - rx * 0.66f, c.y + ry * 0.78f), Size(rx * 1.32f, ry * 0.22f), CornerRadius(8f, 8f), style = Stroke(2.2f))

    // 5. Playful blinking/wincing glowing eyes + mischievous ghostly smile inside lantern flame (2.5D parallax!)
    val faceX = c.x + pxTurn * 0.55f
    val eyeR = rx * (0.18f + attackPulse * 0.04f)
    drawGlowingPupilEye(
        center = Offset(faceX - rx * 0.27f + ctx.lookX * 0.65f, c.y - ry * 0.06f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = if (ctx.isAttacking || ctx.isUltActive) 0.48f else 0f,
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = false,
        eyeFlare = attackPulse
    )
    drawGlowingPupilEye(
        center = Offset(faceX + rx * 0.27f + ctx.lookX * 0.65f, c.y - ry * 0.06f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = if (ctx.isAttacking || ctx.isUltActive) -0.48f else 0f,
        blinkFactor = ctx.blinkFactor,
        isHurt = ctx.isHurt,
        isRightEye = true,
        eyeFlare = attackPulse
    )
    // Mischievous playful crescent grin (widens fiercely on attack, shrinks to O-gasp on hurt)
    if (ctx.isHurt) {
        drawCircle(EspressoDark, rx * 0.11f, Offset(faceX + ctx.lookX * 0.45f, c.y + ry * 0.24f + ctx.lookY * 0.45f))
    } else {
        drawArc(
            color = EspressoDark,
            startAngle = 12f,
            sweepAngle = 156f,
            useCenter = false,
            topLeft = Offset(faceX - rx * 0.26f + ctx.lookX * 0.55f, c.y + ry * 0.12f + ctx.lookY * 0.45f),
            size = Size(rx * 0.52f, ry * (if (ctx.isAttacking) 0.30f else 0.20f)),
            style = Stroke(2.4f, cap = StrokeCap.Round)
        )
    }

    drawRoundRect(EspressoDark, shellRect, shellSize, CornerRadius(rx * 0.60f, rx * 0.60f), style = Stroke(3.0f))
}

/**
 * 星晶幼龙 (drake) — Astral Sapphire Crystal Dragon:
 * Layered twin translucent faceted crystal wings (primary + lower prism feathers),
 * curled starry tail with rotating 4-point star-diamond crystal, articulated dragon claws,
 * plated cream belly scales with glowing 4-point star sternum emblem, sculpted cheek-crests,
 * proud golden slit-pupil blinking/wincing eyes, 2.5D parallax, and distinct Apex Seraph/Meteor silhouettes.
 */
internal fun DrawScope.drawDrakeHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style
    val attackPulse = sin(ctx.attackProgress * PI.toFloat()).coerceIn(0f, 1f)
    val hurtJolt = sin(ctx.hurtProgress * PI.toFloat()).coerceIn(0f, 1f)
    val pxTurn = ctx.turnX * rx * 0.14f
    val dashBackX = if (ctx.isDashing) -ctx.turnX * rx * 0.34f else 0f

    // Track 2 Apex Tier (STAR_SERAPH): majestic luminous astral halo ring behind double crystal wings!
    if (style.crownStyle == EvolutionCrownStyle.STAR_SERAPH && ctx.isApexTier) {
        val haloR = rx * (1.58f + attackPulse * 0.16f)
        drawCircle(
            color = GoldAccent.copy(alpha = 0.52f + attackPulse * 0.35f),
            radius = haloR,
            center = Offset(c.x - pxTurn * 0.4f, c.y - ry * 0.10f),
            style = Stroke(width = 3.4f)
        )
        drawArc(
            color = Color.White.copy(alpha = 0.88f),
            startAngle = ctx.orbitAngle * 57.29578f,
            sweepAngle = 110f,
            useCenter = false,
            topLeft = Offset(c.x - pxTurn * 0.4f - haloR, c.y - ry * 0.10f - haloR),
            size = Size(haloR * 2f, haloR * 2f),
            style = Stroke(width = 2.6f, cap = StrokeCap.Round)
        )
    }

    // 1. Multi-layered translucent faceted crystal wings (sweep wide on attack, fold inward on hurt, delta-sweep on dash)
    val wingFlap = sin(ctx.animTime * 2.0f) * (ry * 0.19f) - attackPulse * ry * 0.36f + hurtJolt * ry * 0.28f
    val baseWingSpan = if (style.crownStyle == EvolutionCrownStyle.STAR_SERAPH) 1.72f else 1.48f
    val wingSpan = (baseWingSpan + attackPulse * 0.32f - hurtJolt * 0.32f + if (ctx.isGliding) 0.22f else 0f)
    for (side in listOf(-1f, 1f)) {
        val wingOffX = -pxTurn * 0.45f + dashBackX * 0.8f
        // Lower secondary prism feather
        val lowerWing = Path().apply {
            moveTo(c.x + side * rx * 0.46f + wingOffX * 0.4f, c.y + ry * 0.06f)
            lineTo(c.x + side * rx * (wingSpan * 0.84f) + wingOffX, c.y + ry * 0.22f + wingFlap * 0.55f)
            lineTo(c.x + side * rx * (wingSpan * 0.62f) + wingOffX, c.y + ry * 0.60f + wingFlap * 0.35f)
            close()
        }
        drawPath(
            lowerWing,
            Brush.linearGradient(
                listOf(style.accentColor.copy(alpha = 0.82f), ctx.primary.copy(alpha = 0.78f))
            )
        )
        drawPath(lowerWing, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))

        // Upper primary crystal blade wing
        val tipPos = Offset(c.x + side * rx * wingSpan + wingOffX, c.y - ry * 0.94f + wingFlap)
        val wing = Path().apply {
            moveTo(c.x + side * rx * 0.48f + wingOffX * 0.4f, c.y - ry * 0.10f)
            lineTo(tipPos.x, tipPos.y)
            lineTo(c.x + side * rx * (wingSpan * 0.84f) + wingOffX, c.y + ry * 0.02f + wingFlap * 0.6f)
            lineTo(c.x + side * rx * (wingSpan * 0.66f) + wingOffX, c.y + ry * 0.40f + wingFlap * 0.35f)
            close()
        }
        drawPath(
            wing,
            Brush.linearGradient(
                listOf(Color.White.copy(alpha = 0.92f), style.accentColor.copy(alpha = 0.92f), ctx.primary.copy(alpha = 0.86f)),
                tipPos,
                Offset(c.x + side * rx * 0.48f, c.y + ry * 0.2f)
            )
        )
        drawLine(
            Color.White.copy(alpha = 0.78f + attackPulse * 0.20f),
            Offset(c.x + side * rx * 0.52f + wingOffX * 0.4f, c.y - ry * 0.08f),
            Offset(c.x + side * rx * (wingSpan * 0.88f) + wingOffX, c.y - ry * 0.68f + wingFlap * 0.85f),
            2.4f + attackPulse * 1.4f,
            StrokeCap.Round
        )
        // Mid-tier golden crystal wing-tip rune sparkle
        if (ctx.isMidTier) {
            drawCircle(GoldAccent, rx * 0.09f, tipPos)
        }
        drawPath(wing, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
    }

    // 2. Curled dragon tail tipped with a rotating 4-point diamond star crystal (exact 360deg per 2*PI)
    val tailTip = Offset(c.x + rx * 1.18f - pxTurn * 0.55f + dashBackX, c.y + ry * 0.64f + sin(ctx.animTime * 2.0f) * ry * 0.12f)
    val tailCurve = Path().apply {
        moveTo(c.x + rx * 0.42f - pxTurn * 0.25f, c.y + ry * 0.68f)
        quadraticTo(c.x + rx * 0.88f - pxTurn * 0.4f, c.y + ry * 0.92f, tailTip.x, tailTip.y)
    }
    drawPath(tailCurve, EspressoDark, style = Stroke(rx * 0.26f + 3.2f, cap = StrokeCap.Round))
    drawPath(tailCurve, ctx.primary, style = Stroke(rx * 0.22f, cap = StrokeCap.Round))
    rotate(degrees = ctx.orbitAngle * 57.29578f + attackPulse * 180f, pivot = tailTip) {
        val starR = rx * (0.24f + attackPulse * 0.08f)
        val starDiamond = Path().apply {
            moveTo(tailTip.x, tailTip.y - starR)
            lineTo(tailTip.x + starR * 0.44f, tailTip.y - starR * 0.44f)
            lineTo(tailTip.x + starR, tailTip.y)
            lineTo(tailTip.x + starR * 0.44f, tailTip.y + starR * 0.44f)
            lineTo(tailTip.x, tailTip.y + starR)
            lineTo(tailTip.x - starR * 0.44f, tailTip.y + starR * 0.44f)
            lineTo(tailTip.x - starR, tailTip.y)
            lineTo(tailTip.x - starR * 0.44f, tailTip.y - starR * 0.44f)
            close()
        }
        drawPath(starDiamond, GoldAccent)
        drawPath(starDiamond, EspressoDark, style = Stroke(1.8f, join = StrokeJoin.Round))
    }

    // 3. Articulated clawed dragon feet
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing else -ctx.footSwing
        val paw = Offset(c.x + side * rx * 0.48f, c.y + ry * 0.92f + fSwing)
        drawOval(
            ctx.primary,
            topLeft = Offset(paw.x - rx * 0.26f, paw.y - ry * 0.16f),
            size = Size(rx * 0.52f, ry * 0.32f)
        )
        drawOval(
            EspressoDark,
            topLeft = Offset(paw.x - rx * 0.26f, paw.y - ry * 0.16f),
            size = Size(rx * 0.52f, ry * 0.32f),
            style = Stroke(2.2f)
        )
        drawCircle(Color(0xFFFFF8E0), rx * 0.06f, Offset(paw.x + side * rx * 0.16f, paw.y + ry * 0.10f))
    }

    // 4. Meteor Horns OR Astral Star Crest + sculpted side cheek-crests
    for (side in listOf(-1f, 1f)) {
        val cheekFin = Path().apply {
            moveTo(c.x + side * rx * 0.86f, c.y - ry * 0.12f)
            lineTo(c.x + side * rx * 1.24f, c.y - ry * 0.24f)
            lineTo(c.x + side * rx * 0.92f, c.y + ry * 0.16f)
            close()
        }
        drawPath(cheekFin, style.accentColor)
        drawPath(cheekFin, EspressoDark, style = Stroke(2.0f, join = StrokeJoin.Round))
    }
    if (style.crownStyle == EvolutionCrownStyle.METEOR_HORNS) {
        for (side in listOf(-1f, 1f)) {
            val horn = Path().apply {
                moveTo(c.x + side * rx * 0.30f, c.y - ry * 0.74f)
                lineTo(c.x + side * rx * 0.94f, c.y - ry * 1.60f)
                lineTo(c.x + side * rx * 0.66f, c.y - ry * 0.56f)
                close()
            }
            drawPath(horn, Brush.verticalGradient(listOf(Color.White, GoldAccent, style.accentColor)))
            drawPath(horn, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
        }
        // Track 2 Apex Tier (METEOR_HORNS): 3 orbiting mini-meteorite crystal shards + comet ridge!
        if (ctx.isApexTier) {
            for (m in 0 until 3) {
                val ma = ctx.orbitAngle + m * 2.0943952f
                val mp = Offset(c.x + cos(ma) * rx * 1.54f, c.y + sin(ma) * ry * 0.82f)
                val shard = Path().apply {
                    moveTo(mp.x, mp.y - ry * 0.20f)
                    lineTo(mp.x + rx * 0.16f, mp.y)
                    lineTo(mp.x, mp.y + ry * 0.18f)
                    lineTo(mp.x - rx * 0.14f, mp.y + ry * 0.04f)
                    close()
                }
                drawPath(shard, Brush.linearGradient(listOf(Color.White, GoldAccent, style.accentColor)))
                drawPath(shard, EspressoDark, style = Stroke(1.6f, join = StrokeJoin.Round))
            }
        }
    } else {
        val starCrest = Path().apply {
            moveTo(c.x, c.y - ry * 1.66f)
            lineTo(c.x + rx * 0.30f, c.y - ry * 0.78f)
            lineTo(c.x - rx * 0.30f, c.y - ry * 0.78f)
            close()
        }
        drawPath(starCrest, Brush.verticalGradient(listOf(Color.White, GoldAccent, style.accentColor)))
        drawPath(starCrest, EspressoDark, style = Stroke(2.2f, join = StrokeJoin.Round))
        // Track 2 Apex Tier (STAR_SERAPH): triple-spire royal star tiara flanking center crest
        if (style.crownStyle == EvolutionCrownStyle.STAR_SERAPH && ctx.isApexTier) {
            for (side in listOf(-1f, 1f)) {
                val subSpire = Path().apply {
                    moveTo(c.x + side * rx * 0.56f, c.y - ry * 1.38f)
                    lineTo(c.x + side * rx * 0.58f, c.y - ry * 0.74f)
                    lineTo(c.x + side * rx * 0.26f, c.y - ry * 0.84f)
                    close()
                }
                drawPath(subSpire, GoldAccent)
                drawPath(subSpire, EspressoDark, style = Stroke(1.8f, join = StrokeJoin.Round))
            }
        }
    }

    // 5. Sapphire body + cel rim + plated cream belly scales + glowing star sternum core (2.5D forward parallax!)
    drawCircle(
        Brush.radialGradient(listOf(ctx.secondary, ctx.primary, Color(0xFF1D286B)), Offset(c.x - rx * 0.24f, c.y - ry * 0.34f), rx * 1.30f),
        rx * 1.02f,
        c
    )
    drawCelRimArc(c, rx * 0.92f, ry * 0.92f, color = Color(0xFFA8E6FF).copy(alpha = 0.45f), startAngle = 205f, sweepAngle = 68f)
    drawGlossySpecular(Offset(c.x - rx * 0.28f, c.y - ry * 0.56f), rx * 0.32f, ry * 0.14f, alpha = 0.34f)

    val faceX = c.x + pxTurn * 0.55f
    drawOval(
        color = Color(0xFFEFF5FF).copy(alpha = 0.92f),
        topLeft = Offset(faceX - rx * 0.54f, c.y + ry * 0.14f),
        size = Size(rx * 1.08f, ry * 0.76f)
    )
    drawLine(Color(0xFF9EB9E6), Offset(faceX - rx * 0.38f, c.y + ry * 0.44f), Offset(faceX + rx * 0.38f, c.y + ry * 0.44f), 2.0f, StrokeCap.Round)
    drawLine(Color(0xFF9EB9E6), Offset(faceX - rx * 0.28f, c.y + ry * 0.66f), Offset(faceX + rx * 0.28f, c.y + ry * 0.66f), 2.0f, StrokeCap.Round)
    // Glowing golden star-crystal emblem on chest sternum (blazes bright on attack!)
    val gemCenter = Offset(faceX, c.y + ry * 0.28f)
    if (attackPulse > 0.1f) {
        drawCircle(GoldAccent.copy(alpha = attackPulse * 0.55f), rx * (0.34f + attackPulse * 0.18f), gemCenter)
    }
    val gemScale = 1f + attackPulse * 0.24f
    val gemPath = Path().apply {
        moveTo(gemCenter.x, gemCenter.y - ry * 0.15f * gemScale)
        lineTo(gemCenter.x + rx * 0.13f * gemScale, gemCenter.y)
        lineTo(gemCenter.x, gemCenter.y + ry * 0.15f * gemScale)
        lineTo(gemCenter.x - rx * 0.13f * gemScale, gemCenter.y)
        close()
    }
    drawPath(gemPath, Brush.radialGradient(listOf(Color.White, GoldAccent), gemCenter, rx * 0.18f * gemScale))
    drawPath(gemPath, EspressoDark, style = Stroke(1.6f, join = StrokeJoin.Round))

    // 6. Proud golden slit-pupil blinking/wincing dragon eyes (Track 1 parity!)
    val eyeR = rx * (0.20f + attackPulse * 0.035f)
    drawGlowingPupilEye(
        center = Offset(faceX - rx * 0.31f + ctx.lookX * 0.65f, c.y - ry * 0.18f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = if (ctx.isAttacking || ctx.isUltActive) 0.58f else 0.36f,
        blinkFactor = ctx.blinkFactor,
        slitPupil = true,
        isHurt = ctx.isHurt,
        isRightEye = false,
        eyeFlare = attackPulse
    )
    drawGlowingPupilEye(
        center = Offset(faceX + rx * 0.31f + ctx.lookX * 0.65f, c.y - ry * 0.18f + ctx.lookY),
        radius = eyeR,
        glowColor = style.eyeColor,
        angryTilt = if (ctx.isAttacking || ctx.isUltActive) -0.58f else -0.36f,
        blinkFactor = ctx.blinkFactor,
        slitPupil = true,
        isHurt = ctx.isHurt,
        isRightEye = true,
        eyeFlare = attackPulse
    )
    drawCircle(EspressoDark, rx * 1.02f, c, style = Stroke(3.0f))
}
