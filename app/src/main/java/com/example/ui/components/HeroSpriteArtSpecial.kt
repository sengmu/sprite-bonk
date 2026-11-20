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
import com.example.game.evolution.EvolutionCrownStyle
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * 雷铃狐 (spark) — Painted-Ceramic Thunder-Bell Spirit Fox:
 * Layered inner-ear gradients, zig-zag lightning tail, golden shrine collar with brass chime bell,
 * electric cheek sparks, and storm-drum halo or sleek cyan plasma visor branches.
 */
internal fun DrawScope.drawSparkHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style

    // 1. Storm Halo: floating taiko thunder drums linked by golden arc
    if (style.crownStyle == EvolutionCrownStyle.STORM_HALO) {
        drawArc(
            color = style.accentColor.copy(alpha = 0.55f),
            startAngle = 195f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 1.44f, c.y - ry * 1.46f),
            size = Size(rx * 2.88f, ry * 2.52f),
            style = Stroke(3.0f, cap = StrokeCap.Round)
        )
        val drums = if (ctx.scale > 1.24f) 5 else 3
        for (d in 0 until drums) {
            val a = -PI.toFloat() + (d + 1) * (PI.toFloat() / (drums + 1)) + sin(ctx.animTime * 0.6f) * 0.08f
            val dp = Offset(c.x + cos(a) * rx * 1.42f, c.y + sin(a) * ry * 1.28f)
            drawCircle(style.accentColor.copy(alpha = 0.35f), rx * 0.32f, dp)
            drawCircle(style.accentColor, rx * 0.22f, dp)
            drawCircle(Color.White, rx * 0.09f, dp)
            drawCircle(EspressoDark, rx * 0.22f, dp, style = Stroke(2.0f))
        }
    }

    // 2. Animated zig-zag lightning fox tail waving behind body
    val tailWag = sin(ctx.animTime * 2.4f) * (ry * 0.14f)
    val tailPath = Path().apply {
        moveTo(c.x + rx * 0.58f, c.y + ry * 0.38f)
        lineTo(c.x + rx * 1.24f, c.y + ry * 0.06f + tailWag)
        lineTo(c.x + rx * 1.02f, c.y - ry * 0.20f + tailWag)
        lineTo(c.x + rx * 1.56f, c.y - ry * 0.62f + tailWag * 1.2f)
        lineTo(c.x + rx * 1.28f, c.y + ry * 0.42f + tailWag * 0.6f)
        close()
    }
    drawPath(tailPath, Brush.linearGradient(listOf(style.accentColor, ctx.primary)))
    drawPath(tailPath, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))

    // 3. Tall pointed fox ears with luminous inner ear cavities
    val earWag = sin(ctx.animTime * 1.6f) * (rx * 0.07f)
    for (side in listOf(-1f, 1f)) {
        val outerEar = Path().apply {
            moveTo(c.x + side * rx * 0.68f, c.y - ry * 0.40f)
            lineTo(c.x + side * rx * 1.02f - side * earWag, c.y - ry * 1.56f)
            lineTo(c.x + side * rx * 0.14f, c.y - ry * 0.78f)
            close()
        }
        val innerEar = Path().apply {
            moveTo(c.x + side * rx * 0.58f, c.y - ry * 0.54f)
            lineTo(c.x + side * rx * 0.84f - side * earWag * 0.8f, c.y - ry * 1.26f)
            lineTo(c.x + side * rx * 0.28f, c.y - ry * 0.76f)
            close()
        }
        drawPath(outerEar, ctx.primary)
        drawPath(innerEar, Color(0xFFFFF0B8))
        drawPath(outerEar, EspressoDark, style = Stroke(2.6f, join = StrokeJoin.Round))
    }

    // 4. Nimble ceramic paws
    for (side in listOf(-1f, 1f)) {
        val fSwing = if (side < 0f) ctx.footSwing else -ctx.footSwing
        val paw = Offset(c.x + side * rx * 0.48f, c.y + ry * 0.86f + fSwing)
        drawCircle(ctx.secondary, rx * 0.26f, paw)
        drawCircle(EspressoDark, rx * 0.26f, paw, style = Stroke(2.2f))
    }

    // 5. Ceramic fox body + cream muzzle + glossy highlight
    drawCircle(
        Brush.radialGradient(listOf(ctx.secondary, ctx.primary), Offset(c.x - rx * 0.24f, c.y - ry * 0.34f), rx * 1.28f),
        rx * 0.98f,
        c
    )
    drawOval(
        color = Color(0xFFFFF8DF).copy(alpha = 0.86f),
        topLeft = Offset(c.x - rx * 0.62f, c.y + ry * 0.08f),
        size = Size(rx * 1.24f, ry * 0.74f)
    )
    drawGlossySpecular(Offset(c.x - rx * 0.26f, c.y - ry * 0.52f), rx * 0.30f, ry * 0.14f, alpha = 0.34f)

    // Rosy electric cheek sparks
    drawCircle(Color(0xFFFF7A5C).copy(alpha = 0.76f), rx * 0.14f, Offset(c.x - rx * 0.54f + ctx.lookX * 0.4f, c.y + ry * 0.20f + ctx.lookY * 0.3f))
    drawCircle(Color(0xFFFF7A5C).copy(alpha = 0.76f), rx * 0.14f, Offset(c.x + rx * 0.54f + ctx.lookX * 0.4f, c.y + ry * 0.20f + ctx.lookY * 0.3f))

    // Crimson shrine ribbon + golden thunder bell
    drawArc(
        color = Color(0xFFD93B3B),
        startAngle = 25f,
        sweepAngle = 130f,
        useCenter = false,
        topLeft = Offset(c.x - rx * 0.80f, c.y + ry * 0.08f),
        size = Size(rx * 1.60f, ry * 0.72f),
        style = Stroke(5.0f, cap = StrokeCap.Round)
    )
    val bellCenter = Offset(c.x, c.y + ry * 0.60f)
    drawCircle(GoldAccent, rx * 0.24f, bellCenter)
    drawCircle(Color.White.copy(alpha = 0.85f), rx * 0.08f, Offset(bellCenter.x - rx * 0.07f, bellCenter.y - ry * 0.07f))
    drawLine(EspressoDark, Offset(bellCenter.x - rx * 0.14f, bellCenter.y + ry * 0.08f), Offset(bellCenter.x + rx * 0.14f, bellCenter.y + ry * 0.08f), 2.0f, StrokeCap.Round)
    drawCircle(EspressoDark, rx * 0.24f, bellCenter, style = Stroke(2.2f))

    // 6. Sleek Plasma Visor OR bright alert fox eyes
    if (style.crownStyle == EvolutionCrownStyle.PLASMA_VISOR) {
        val visorPos = Offset(c.x - rx * 0.72f + ctx.lookX * 0.4f, c.y - ry * 0.28f + ctx.lookY * 0.4f)
        val visorSize = Size(rx * 1.44f, ry * 0.42f)
        drawRoundRect(
            Brush.horizontalGradient(listOf(style.accentColor, Color.White, style.accentColor)),
            topLeft = visorPos,
            size = visorSize,
            cornerRadius = CornerRadius(10f, 10f)
        )
        drawRoundRect(EspressoDark, visorPos, visorSize, CornerRadius(10f, 10f), style = Stroke(2.4f))
    } else {
        val eyeR = rx * 0.18f
        drawGlowingPupilEye(Offset(c.x - rx * 0.30f + ctx.lookX, c.y - ry * 0.08f + ctx.lookY), eyeR, style.eyeColor)
        drawGlowingPupilEye(Offset(c.x + rx * 0.30f + ctx.lookX, c.y - ry * 0.08f + ctx.lookY), eyeR, style.eyeColor)
    }
    drawCircle(EspressoDark, rx * 0.98f, c, style = Stroke(3.0f))
}

/**
 * 提灯幽灵 (wisp) — Moon-Bronze Shrine Lantern Spirit:
 * Ornate bronze crown cap & swaying bottom tassel, ribbed lantern frame, glowing teardrop spirit flame
 * housing mischievous luminous eyes, orbiting soul wisps, and crescent eclipse halo branch.
 */
internal fun DrawScope.drawWispHeroArt(ctx: HeroArtContext) {
    val floatOff = sin(ctx.animTime * 1.2f) * (ctx.ry * 0.12f)
    val c = Offset(ctx.bodyCenter.x, ctx.bodyCenter.y + floatOff)
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style

    // 1. Orbiting spirit flames with glowing trails
    val orbCount = if (ctx.scale > 1.22f) 4 else 2
    for (i in 0 until orbCount) {
        val a = ctx.orbitAngle + i * (2f * PI.toFloat() / orbCount)
        val trailA = a - 0.28f
        val op = Offset(c.x + cos(a) * rx * 1.44f, c.y + sin(a) * ry * 0.86f)
        val tp = Offset(c.x + cos(trailA) * rx * 1.38f, c.y + sin(trailA) * ry * 0.82f)
        drawLine(style.accentColor.copy(alpha = 0.45f), tp, op, rx * 0.18f, StrokeCap.Round)
        drawCircle(style.accentColor.copy(alpha = 0.36f), rx * 0.30f, op)
        drawCircle(style.accentColor, rx * 0.16f, op)
        drawCircle(Color.White, rx * 0.07f, op)
    }

    // 2. Swaying bottom crimson-gold shrine tassel
    val tasselSway = sin(ctx.animTime * 1.8f) * (rx * 0.14f)
    drawLine(GoldAccent, Offset(c.x, c.y + ry * 0.94f), Offset(c.x + tasselSway, c.y + ry * 1.38f), 4.2f, StrokeCap.Round)
    drawCircle(style.accentColor, rx * 0.14f, Offset(c.x + tasselSway, c.y + ry * 1.38f))

    // 3. Crown handle OR radiant Moon-Eclipse halo
    if (style.crownStyle == EvolutionCrownStyle.ECLIPSE_CROWN) {
        drawArc(
            color = style.accentColor,
            startAngle = 195f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 0.84f, c.y - ry * 1.72f),
            size = Size(rx * 1.68f, ry * 0.98f),
            style = Stroke(width = 7.5f, cap = StrokeCap.Round)
        )
        drawCircle(Color.White, rx * 0.13f, Offset(c.x, c.y - ry * 1.70f))
    } else {
        drawArc(
            color = GoldAccent,
            startAngle = 180f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(c.x - rx * 0.56f, c.y - ry * 1.56f),
            size = Size(rx * 1.12f, ry * 0.88f),
            style = Stroke(width = 5.2f, cap = StrokeCap.Round)
        )
    }

    // 4. Sculpted lantern chamber + inner glowing teardrop spirit core
    val shellRect = Offset(c.x - rx * 0.92f, c.y - ry * 0.88f)
    val shellSize = Size(rx * 1.84f, ry * 1.78f)
    drawRoundRect(
        Brush.verticalGradient(listOf(ctx.secondary, ctx.primary)),
        topLeft = shellRect,
        size = shellSize,
        cornerRadius = CornerRadius(rx * 0.62f, rx * 0.62f)
    )
    // Glowing translucent spirit core
    val flameBreath = 0.94f + 0.08f * sin(ctx.animTime * 4f)
    drawCircle(
        Brush.radialGradient(listOf(Color.White, style.accentColor, ctx.primary.copy(alpha = 0.25f)), c, rx * 0.82f * flameBreath),
        rx * 0.74f * flameBreath,
        c
    )

    // Ornamental bronze ribs
    drawLine(EspressoDark.copy(alpha = 0.55f), Offset(c.x - rx * 0.56f, c.y - ry * 0.82f), Offset(c.x - rx * 0.56f, c.y + ry * 0.82f), 2.4f)
    drawLine(EspressoDark.copy(alpha = 0.55f), Offset(c.x + rx * 0.56f, c.y - ry * 0.82f), Offset(c.x + rx * 0.56f, c.y + ry * 0.82f), 2.4f)

    // Top & bottom bronze caps
    drawRoundRect(Color(0xFF473742), Offset(c.x - rx * 0.72f, c.y - ry * 1.04f), Size(rx * 1.44f, ry * 0.28f), CornerRadius(8f, 8f))
    drawRoundRect(EspressoDark, Offset(c.x - rx * 0.72f, c.y - ry * 1.04f), Size(rx * 1.44f, ry * 0.28f), CornerRadius(8f, 8f), style = Stroke(2.2f))
    drawRoundRect(Color(0xFF473742), Offset(c.x - rx * 0.62f, c.y + ry * 0.78f), Size(rx * 1.24f, ry * 0.22f), CornerRadius(8f, 8f))
    drawRoundRect(EspressoDark, Offset(c.x - rx * 0.62f, c.y + ry * 0.78f), Size(rx * 1.24f, ry * 0.22f), CornerRadius(8f, 8f), style = Stroke(2.2f))

    // 5. Playful glowing eyes inside lantern flame
    val eyeR = rx * 0.17f
    drawGlowingPupilEye(Offset(c.x - rx * 0.27f + ctx.lookX, c.y - ry * 0.04f + ctx.lookY), eyeR, style.eyeColor)
    drawGlowingPupilEye(Offset(c.x + rx * 0.27f + ctx.lookX, c.y - ry * 0.04f + ctx.lookY), eyeR, style.eyeColor)

    drawRoundRect(EspressoDark, shellRect, shellSize, CornerRadius(rx * 0.62f, rx * 0.62f), style = Stroke(3.0f))
}

/**
 * 星晶幼龙 (drake) — Sapphire Star-Crystal Drake:
 * Translucent faceted crystal wings with inner prism shine, star-tipped tail, plated cream belly scales,
 * proud golden slit-pupil eyes, and star-seraph crest or twin meteor horns.
 */
internal fun DrawScope.drawDrakeHeroArt(ctx: HeroArtContext) {
    val c = ctx.bodyCenter
    val rx = ctx.rx
    val ry = ctx.ry
    val style = ctx.style

    // 1. Multi-layered translucent crystal wings
    val wingFlap = sin(ctx.animTime * 2.2f) * (ry * 0.18f)
    val wingSpan = if (style.crownStyle == EvolutionCrownStyle.STAR_SERAPH) 1.68f else 1.44f
    for (side in listOf(-1f, 1f)) {
        val wing = Path().apply {
            moveTo(c.x + side * rx * 0.48f, c.y - ry * 0.10f)
            lineTo(c.x + side * rx * wingSpan, c.y - ry * 0.88f + wingFlap)
            lineTo(c.x + side * rx * (wingSpan * 0.82f), c.y + ry * 0.02f + wingFlap * 0.6f)
            lineTo(c.x + side * rx * (wingSpan * 0.66f), c.y + ry * 0.42f + wingFlap * 0.35f)
            close()
        }
        drawPath(
            wing,
            Brush.linearGradient(
                listOf(Color.White.copy(alpha = 0.88f), style.accentColor.copy(alpha = 0.90f), ctx.primary.copy(alpha = 0.85f)),
                Offset(c.x + side * rx * wingSpan, c.y - ry * 0.88f + wingFlap),
                Offset(c.x + side * rx * 0.48f, c.y + ry * 0.2f)
            )
        )
        // Wing crystal vein
        drawLine(
            Color.White.copy(alpha = 0.72f),
            Offset(c.x + side * rx * 0.52f, c.y - ry * 0.08f),
            Offset(c.x + side * rx * (wingSpan * 0.86f), c.y - ry * 0.64f + wingFlap * 0.85f),
            2.2f,
            StrokeCap.Round
        )
        drawPath(wing, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
    }

    // 2. Curled dragon tail with glowing star-tip crystal
    val tailTip = Offset(c.x + rx * 1.12f, c.y + ry * 0.66f + sin(ctx.animTime * 2f) * ry * 0.10f)
    drawLine(ctx.primary, Offset(c.x + rx * 0.44f, c.y + ry * 0.66f), tailTip, rx * 0.24f, StrokeCap.Round)
    drawCircle(GoldAccent, rx * 0.18f, tailTip)
    drawCircle(EspressoDark, rx * 0.18f, tailTip, style = Stroke(2.0f))

    // 3. Meteor Horns OR Astral Star Crest
    if (style.crownStyle == EvolutionCrownStyle.METEOR_HORNS) {
        for (side in listOf(-1f, 1f)) {
            val horn = Path().apply {
                moveTo(c.x + side * rx * 0.30f, c.y - ry * 0.74f)
                lineTo(c.x + side * rx * 0.92f, c.y - ry * 1.56f)
                lineTo(c.x + side * rx * 0.64f, c.y - ry * 0.56f)
                close()
            }
            drawPath(horn, Brush.verticalGradient(listOf(GoldAccent, style.accentColor)))
            drawPath(horn, EspressoDark, style = Stroke(2.4f, join = StrokeJoin.Round))
        }
    } else {
        val starCrest = Path().apply {
            moveTo(c.x, c.y - ry * 1.62f)
            lineTo(c.x + rx * 0.28f, c.y - ry * 0.80f)
            lineTo(c.x - rx * 0.28f, c.y - ry * 0.80f)
            close()
        }
        drawPath(starCrest, Brush.verticalGradient(listOf(Color.White, style.accentColor)))
        drawPath(starCrest, EspressoDark, style = Stroke(2.2f, join = StrokeJoin.Round))
    }

    // 4. Sapphire body + specular shine + plated cream belly scales
    drawCircle(
        Brush.radialGradient(listOf(ctx.secondary, ctx.primary), Offset(c.x - rx * 0.24f, c.y - ry * 0.32f), rx * 1.28f),
        rx * 1.02f,
        c
    )
    drawGlossySpecular(Offset(c.x - rx * 0.28f, c.y - ry * 0.54f), rx * 0.32f, ry * 0.14f, alpha = 0.32f)

    drawOval(
        color = Color(0xFFEAF2FF).copy(alpha = 0.88f),
        topLeft = Offset(c.x - rx * 0.54f, c.y + ry * 0.14f),
        size = Size(rx * 1.08f, ry * 0.76f)
    )
    // Belly scale lines
    drawLine(Color(0xFF9EB9E6), Offset(c.x - rx * 0.38f, c.y + ry * 0.42f), Offset(c.x + rx * 0.38f, c.y + ry * 0.42f), 2.0f, StrokeCap.Round)
    drawLine(Color(0xFF9EB9E6), Offset(c.x - rx * 0.30f, c.y + ry * 0.64f), Offset(c.x + rx * 0.30f, c.y + ry * 0.64f), 2.0f, StrokeCap.Round)

    // 5. Proud golden dragon eyes
    val eyeR = rx * 0.19f
    drawGlowingPupilEye(Offset(c.x - rx * 0.30f + ctx.lookX, c.y - ry * 0.18f + ctx.lookY), eyeR, style.eyeColor, angryTilt = 0.35f)
    drawGlowingPupilEye(Offset(c.x + rx * 0.30f + ctx.lookX, c.y - ry * 0.18f + ctx.lookY), eyeR, style.eyeColor, angryTilt = -0.35f)
    drawCircle(EspressoDark, rx * 1.02f, c, style = Stroke(3.0f))
}
