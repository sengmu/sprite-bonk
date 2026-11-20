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
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.HudInkDark
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Shared real-time procedural sprite renderer for EVERY evolution node!
 * Used identically inside the live UI Evolution Preview stage, Main Lobby Pedestal,
 * Free-Roam Playground, and the VSYNC BattleCanvas so every species and evolution branch
 * renders with layered cel-shading, natural eye blinks, and expressive attack motion.
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
    leanDeg: Float = 0f,
    attackProgress: Float = if (isAttacking) 0.55f else 0f,
    hurtProgress: Float = if (isHurt) 0.72f else 0f,
    evolutionFxProgress: Float = 0f,
    walkCycle: Float = animTime,
    isDashing: Boolean = false,
    isAirborne: Boolean = false,
    isGliding: Boolean = false,
    hpRatio: Float = 1f,
    quirkProgress: Float = 0f
) {
    val normAttack = if (isAttacking || attackProgress > 0f) attackProgress.coerceIn(0f, 1f) else 0f
    val normHurt = if (isHurt || hurtProgress > 0f) hurtProgress.coerceIn(0f, 1f) else 0f
    val normEvoFx = evolutionFxProgress.coerceIn(0f, 1f)
    val normQuirk = quirkProgress.coerceIn(0f, 1f)
    val effectiveAttacking = isAttacking || normAttack > 0.02f
    val effectiveHurt = isHurt || normHurt > 0.02f
    val isLowHp = hpRatio < 0.30f && hpRatio > 0f

    // Smooth blend between grounded idle breathing (0f) and lively walk hop (1f) — zero snapping on stop/start
    val moveBlend = ((moveSpeedRatio - 0.06f) / 0.24f).coerceIn(0f, 1f)
    val hopWave = sin(walkCycle)
    // Harmonic 1.5x frequency = exact 3 full breath cycles per 4*PI loop (100% seamless);
    // Low-HP adds a harmonic 3.0x anxious chest heave while keeping exact loop continuity!
    val criticalAmp = if (isLowHp) 1.45f else 1f
    val idleBreath = (sin(animTime * 1.5f) + if (isLowHp) sin(animTime * 3.0f) * 0.28f else 0f) * criticalAmp
    val scale = style.scaleFactor
    val baseRy = baseRadius * scale

    // Grounded breathing: inhaling stretches taller (+3.0%) & lifts center UP so feet stay planted on the ground!
    val idleBob = -idleBreath * (baseRy * 0.030f)
    val walkBob = -abs(hopWave) * (5.2f + 2.4f * moveSpeedRatio.coerceAtMost(1.5f))
    val quirkHop = if (normQuirk > 0.01f) -sin(normQuirk * 3.1415927f) * baseRy * 0.14f else 0f
    val bob = idleBob * (1f - moveBlend) + walkBob * moveBlend + quirkHop

    // Snappy attack impact squash/stretch + directional lunge + hurt impact shudder/compression
    val attackT = 1f - normAttack
    val attackPunch = if (normAttack > 0.01f) {
        (sin(attackT * 3.1415927f) * (1f - attackT * 0.30f)).coerceIn(0f, 1f)
    } else 0f
    val hurtWave = if (normHurt > 0.01f) sin(normHurt * 3.1415927f).coerceIn(0f, 1f) else 0f
    val hurtShudderX = if (normHurt > 0.01f) sin(normHurt * 46f) * baseRadius * 0.22f * normHurt else 0f
    val hurtLiftY = if (normHurt > 0.01f) -hurtWave * baseRadius * 0.10f else 0f

    val turnX = cos(facingAngle)
    val lungeScale = when (style.starterId) {
        "char" -> 0.28f
        "stump" -> 0.24f
        "shell" -> 0.20f
        "spark" -> 0.25f
        "drake" -> 0.24f
        else -> 0.22f
    }
    val lungeX = turnX * baseRadius * lungeScale * attackPunch
    val lungeY = sin(facingAngle) * baseRadius * (lungeScale * 0.72f) * attackPunch

    val idleStretchX = 1f - idleBreath * 0.024f
    val idleStretchY = 1f + idleBreath * 0.030f
    val walkStretchX = 1f + hopWave * 0.060f
    val walkStretchY = 1f - hopWave * 0.060f
    val baseStretchX = idleStretchX * (1f - moveBlend) + walkStretchX * moveBlend
    val baseStretchY = idleStretchY * (1f - moveBlend) + walkStretchY * moveBlend

    val attackStretchX = when (style.starterId) {
        "char" -> 1f + attackPunch * 0.16f
        "stump" -> 1f + attackPunch * 0.14f
        "shell" -> 1f + attackPunch * 0.15f
        "spark" -> 1f + attackPunch * 0.15f
        "drake" -> 1f + attackPunch * 0.14f
        else -> 1f + attackPunch * 0.12f
    }
    val attackStretchY = when (style.starterId) {
        "char" -> 1f + attackPunch * 0.06f
        "stump" -> 1f - attackPunch * 0.09f
        "shell" -> 1f - attackPunch * 0.11f
        "spark" -> 1f - attackPunch * 0.09f
        "drake" -> 1f - attackPunch * 0.08f
        else -> 1f - attackPunch * 0.07f
    }
    val dashStretchX = if (isDashing) 1.15f else 1f
    val dashStretchY = if (isDashing) 0.88f else 1f
    val hurtSquashX = 1f + hurtWave * 0.18f
    val hurtSquashY = 1f - hurtWave * 0.16f
    val evoPopScale = 1f + sin(normEvoFx * 3.1415927f) * 0.14f

    val rx = baseRadius * scale * baseStretchX * attackStretchX * dashStretchX * hurtSquashX * evoPopScale
    val ry = baseRadius * scale * baseStretchY * attackStretchY * dashStretchY * hurtSquashY * evoPopScale
    val bodyCenter = Offset(
        center.x + lungeX + hurtShudderX,
        center.y + bob + lungeY + hurtLiftY
    )

    // Natural periodic blink aligned to exact 4*PI period so UI loops & battle timers never glitch on wrap
    val blinkPeriod = 12.566371f
    val blinkCycle = (animTime % blinkPeriod).let { if (it < 0f) it + blinkPeriod else it }
    val blinkFactor = if (effectiveAttacking || effectiveHurt || isUltActive || isDashing) {
        0f
    } else if (blinkCycle > 11.35f && blinkCycle < 11.77f) {
        sin(((blinkCycle - 11.35f) / 0.42f) * 3.1415927f).coerceIn(0f, 1f)
    } else {
        0f
    }

    // 1. Back-layer Evolution Transformation Beam & Expanding Shockwave Rings
    if (normEvoFx > 0.01f) {
        drawEvolutionBurstBackLayer(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            evolutionFxProgress = normEvoFx,
            animTime = animTime
        )
    }

    // 2. Track 6: Dynamic elemental contrast rim halo + Ult/Hyper iridescent sheen
    drawElementalRimAndUltSheen(
        style = style,
        center = bodyCenter,
        rx = rx,
        ry = ry,
        orbitAngle = orbitAngle,
        isUltActive = isUltActive
    )

    // 3. Evolution & Ult glowing aura with crisp layered energy ring (ground oval hidden while airborne)
    val showAura = scale > 1.05f || isUltActive || normEvoFx > 0.05f
    if (showAura) {
        val auraCol = if (isUltActive) GoldAccent else style.auraColor
        val auraR = if (isUltActive) rx * 2.60f else rx * (1.78f + normEvoFx * 0.65f)
        drawCircle(
            Brush.radialGradient(listOf(auraCol.copy(alpha = 0.42f + normEvoFx * 0.22f), Color.Transparent), center, auraR),
            radius = auraR,
            center = center
        )
        if (!isAirborne) {
            drawOval(
                color = auraCol.copy(alpha = if (isUltActive) 0.78f else (0.48f + normEvoFx * 0.34f).coerceAtMost(0.9f)),
                topLeft = Offset(center.x - rx * 1.28f, center.y + baseRy * 0.58f),
                size = Size(rx * 2.56f, baseRy * 0.68f),
                style = Stroke(width = if (isUltActive || normEvoFx > 0.1f) 3.6f else 2.2f)
            )
            if (isUltActive) {
                // Exact 2x full revolution per 2*PI orbitAngle for seamless looping
                drawArc(
                    color = Color.White.copy(alpha = 0.85f),
                    startAngle = orbitAngle * 114.59156f,
                    sweepAngle = 110f,
                    useCenter = false,
                    topLeft = Offset(center.x - rx * 1.46f, center.y + baseRy * 0.52f),
                    size = Size(rx * 2.92f, baseRy * 0.80f),
                    style = Stroke(width = 2.6f, cap = StrokeCap.Round)
                )
            }
        }
    }

    // 4. Grounded drop shadow ONLY when NOT airborne (fixes airborne double-shadow bug in BattleCanvas & Roam!)
    if (!isAirborne) {
        val shadowScale = (1f - (abs(walkBob) * moveBlend / 38f).coerceIn(0f, 0.24f)) *
            (1f - idleBreath * 0.018f * (1f - moveBlend)) *
            (1f - abs(quirkHop) / (baseRy * 1.4f)).coerceIn(0.72f, 1f)
        drawOval(
            color = Color.Black.copy(alpha = 0.16f),
            topLeft = Offset(center.x - baseRy * 1.24f * shadowScale, center.y + baseRy * 0.72f),
            size = Size(baseRy * 2.48f * shadowScale, baseRy * 0.64f * shadowScale)
        )
        drawOval(
            color = Color.Black.copy(alpha = 0.30f),
            topLeft = Offset(center.x - baseRy * 0.96f * shadowScale, center.y + baseRy * 0.78f),
            size = Size(baseRy * 1.92f * shadowScale, baseRy * 0.48f * shadowScale)
        )
    }

    // 5. Track 4: Directional speed-lines behind the sprite during Dash
    if (isDashing) {
        drawDashSpeedLines(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            facingAngle = facingAngle
        )
    }

    // 6. Track 4: Species-specific 2.5D Air Glide visuals behind the sprite
    if (isGliding) {
        drawSpeciesGlideVfx(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            animTime = animTime,
            orbitAngle = orbitAngle
        )
    }

    val lookX = turnX * (baseRadius * 0.20f)
    val lookY = sin(facingAngle) * (baseRadius * 0.12f)
    val footSwing = sin(walkCycle) * (baseRadius * 0.25f) * moveBlend
    // Two-stage hurt color feedback (incandescent white-peach flash -> crimson pulse)
    val primary = if (effectiveHurt) blendHurtTint(style.primaryColor, normHurt) else style.primaryColor
    val secondary = if (effectiveHurt) blendHurtTint(style.secondaryColor, normHurt) else style.secondaryColor

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
        isAttacking = effectiveAttacking,
        isUltActive = isUltActive,
        blinkFactor = blinkFactor,
        facingAngle = facingAngle,
        isHurt = effectiveHurt,
        attackProgress = normAttack,
        hurtProgress = normHurt,
        evolutionFxProgress = normEvoFx,
        turnX = turnX,
        isDashing = isDashing,
        isGliding = isGliding,
        hpRatio = hpRatio,
        quirkProgress = normQuirk
    )

    val idleSwayTilt = sin(animTime * 0.5f) * 2.0f * (1f - moveBlend)
    val attackLean = turnX * 14f * attackPunch
    val dashLean = if (isDashing) turnX * 16f else 0f
    val hurtRecoilTilt = -hurtWave * 13f * (if (turnX >= 0f) 1f else -1f)
    val quirkSpin = if (style.starterId == "shell" && normQuirk > 0.01f) (1f - normQuirk) * 360f else 0f
    val totalLeanDeg = leanDeg + idleSwayTilt + attackLean + dashLean + hurtRecoilTilt + quirkSpin

    // 7. Species Hero Sprite Body
    rotate(degrees = totalLeanDeg, pivot = bodyCenter) {
        when (style.starterId) {
            "stump" -> drawStumpHeroArt(artCtx)
            "char" -> drawCharHeroArt(artCtx)
            "shell" -> drawShellHeroArt(artCtx)
            "spark" -> drawSparkHeroArt(artCtx)
            "wisp" -> drawWispHeroArt(artCtx)
            else -> drawDrakeHeroArt(artCtx)
        }
    }

    // 8. Species-specific directional strike impact arcs & bursts (all 6 starters)
    if (normAttack > 0.02f) {
        drawSpeciesActionImpactOverlay(artCtx)
    }

    // 9. Hurt impact starburst lines & species hurt debris (all 6 starters)
    if (normHurt > 0.02f) {
        drawHurtStateOverlay(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            hurtProgress = normHurt
        )
    }

    // 10. Track 4: Low-HP <30% critical warning + Char <50% Furnace Overdrive passive heat aura
    if (hpRatio < 0.50f && hpRatio > 0f) {
        drawLowHpAndPassiveOverlay(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            animTime = animTime,
            hpRatio = hpRatio
        )
    }

    // 11. Track 5: Species idle personality quirks & pedestal tap easter eggs
    if (normQuirk > 0.02f) {
        drawSpeciesPersonalityQuirk(
            style = style,
            center = bodyCenter,
            rx = rx,
            ry = ry,
            quirkProgress = normQuirk
        )
    }

    // 12. Front-layer spiraling evolution particles + persistent evolved ambient motes (all 6 starters)
    drawEvolutionParticlesFrontLayer(
        style = style,
        center = bodyCenter,
        rx = rx,
        ry = ry,
        animTime = animTime,
        orbitAngle = orbitAngle,
        scale = scale,
        evolutionFxProgress = normEvoFx
    )
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
        targetValue = 12.566371f,
        animationSpec = infiniteRepeatable(tween(6400, easing = LinearEasing), RepeatMode.Restart),
        label = "evo_anim"
    )
    val orbitAngle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 6.2831855f,
        animationSpec = infiniteRepeatable(tween(3800, easing = LinearEasing), RepeatMode.Restart),
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
                startAngle = orbitAngle * 57.29578f,
                sweepAngle = 115f,
                useCenter = false,
                topLeft = Offset(size.width * 0.16f, size.height * 0.69f),
                size = Size(size.width * 0.68f, size.height * 0.19f),
                style = Stroke(width = 3.0f, cap = StrokeCap.Round)
            )
            drawArc(
                color = Color.White.copy(alpha = 0.62f),
                startAngle = orbitAngle * 57.29578f + 180f,
                sweepAngle = 90f,
                useCenter = false,
                topLeft = Offset(size.width * 0.16f, size.height * 0.69f),
                size = Size(size.width * 0.68f, size.height * 0.19f),
                style = Stroke(width = 2.4f, cap = StrokeCap.Round)
            )

            // Ambient rising evolution motes (harmonic 0.5x period = 100% seamless loop)
            for (i in 0 until 8) {
                val a = orbitAngle + i * 0.7853982f
                val px = c.x + cos(a) * (size.width * 0.38f)
                val py = c.y - (size.height * 0.34f) * ((sin(animTime * 0.5f + i) + 1f) * 0.5f) + 16f
                drawCircle(style.auraColor.copy(alpha = 0.42f), 5.5f, Offset(px, py))
                drawCircle(Color.White.copy(alpha = 0.82f), 2.4f, Offset(px, py))
            }

            // Calm, grounded, seamless idle sprite render (no random attack snapping)
            drawEvolvedHeroSprite(
                style = style,
                center = c,
                baseRadius = size.minDimension * 0.22f,
                animTime = animTime,
                orbitAngle = orbitAngle,
                facingAngle = sin(animTime * 0.5f) * 0.38f,
                moveSpeedRatio = 0f,
                isAttacking = false,
                attackProgress = 0f
            )
        }
    }
}
