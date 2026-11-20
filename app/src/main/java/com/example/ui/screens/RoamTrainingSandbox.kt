package com.example.ui.screens

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.model.BiomeDef
import com.example.game.model.GameCatalog
import com.example.game.model.MoveArchetype
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

/**
 * Elevated High-Ground Practice Plateau placed directly beside the Training Dummy
 * so players can practice climbing, jumping, Air-Gliding, and 2.5D Drop-Slam combos.
 */
data class RoamHighGroundPlateau(
    val x: Float = -155f,
    val y: Float = -24f,
    val rx: Float = 104f,
    val ry: Float = 72f,
    val elevationZ: Float = 44f
) {
    fun groundZAt(wx: Float, wy: Float): Float {
        val nx = (wx - x) / rx
        val ny = (wy - y) / ry
        val d2 = nx * nx + ny * ny
        if (d2 <= 1f) return elevationZ
        // Smooth east-facing ramp extending toward x = -15..+10 so players can walk right up
        if (wx in (x + rx * 0.72f)..(x + rx + 58f) && abs(wy - y) <= 34f) {
            val t = ((x + rx + 58f - wx) / (58f + rx * 0.28f)).coerceIn(0f, 1f)
            return elevationZ * t
        }
        return 0f
    }
}

/**
 * Lightweight 2.5D vertical jump / air-glide / drop-slam controller for the Training Sandbox.
 */
class RoamJumpPhysics {
    var z: Float = 0f
    var vz: Float = 0f
    var groundZ: Float = 0f
    var peakZ: Float = 0f
    var isGliding: Boolean = false
    var jumpCooldown: Float = 0f
    val jumpCooldownTotal: Float = 0.85f
    var dropSlamReady: Boolean = false

    val isJumping: Boolean get() = z > groundZ + 2.5f
    val isOnHighGround: Boolean get() = groundZ >= 18f

    enum class JumpActionResult {
        NONE,
        JUMPED,
        GLIDE_OPENED,
        SLAM_TRIGGERED
    }

    fun triggerJumpOrGlide(): JumpActionResult {
        return when {
            isGliding -> {
                isGliding = false
                vz = -640f
                dropSlamReady = true
                JumpActionResult.SLAM_TRIGGERED
            }
            isJumping -> {
                isGliding = true
                vz = vz.coerceAtLeast(-55f)
                dropSlamReady = true
                JumpActionResult.GLIDE_OPENED
            }
            jumpCooldown <= 0.01f -> {
                vz = 335f
                z += 4f
                peakZ = z
                isGliding = false
                dropSlamReady = groundZ >= 18f
                jumpCooldown = jumpCooldownTotal
                JumpActionResult.JUMPED
            }
            else -> JumpActionResult.NONE
        }
    }

    /**
     * Advances vertical physics by [dt]. Returns >0f drop height if a high-ground / glide Drop-Slam landed this frame.
     */
    fun step(dt: Float, wx: Float, wy: Float, plateau: RoamHighGroundPlateau): Float {
        if (jumpCooldown > 0f) jumpCooldown = (jumpCooldown - dt).coerceAtLeast(0f)
        val prevGroundZ = groundZ
        val newGroundZ = plateau.groundZAt(wx, wy)
        groundZ = newGroundZ

        if (prevGroundZ >= 18f && newGroundZ < 6f && z >= 18f) {
            peakZ = maxOf(peakZ, z)
            dropSlamReady = true
        }

        if (z > newGroundZ || vz > 0f) {
            val gravity = if (isGliding && vz < 0f) 190f else 980f
            vz -= gravity * dt
            if (isGliding && vz < -82f) vz = -82f
            z += vz * dt
            if (z > peakZ) peakZ = z
            if (z <= newGroundZ) {
                val dropHeight = (peakZ - newGroundZ).coerceAtLeast(0f)
                val shouldSlam = dropSlamReady && dropHeight >= 34f
                z = newGroundZ
                vz = 0f
                isGliding = false
                dropSlamReady = false
                peakZ = newGroundZ
                return if (shouldSlam) dropHeight else 0f
            }
        } else {
            z = newGroundZ
            vz = 0f
            isGliding = false
            dropSlamReady = false
            peakZ = newGroundZ
        }
        return 0f
    }
}

/**
 * Interactive Training Dummy with spring recoil, hit flash, combo counter,
 * peak crit tracking, and sliding 3-second real-time DPS telemetry.
 */
class TrainingDummyState(
    val x: Float = 175f,
    val y: Float = -24f,
    val radius: Float = 34f
) {
    private data class HitSample(val timeSec: Float, val damage: Float)

    private val recentHits = ArrayDeque<HitSample>()
    var recoilAngle: Float = 0f
    var recoilVel: Float = 0f
    var hitFlash: Float = 0f
    var comboCount: Int = 0
    var comboTimer: Float = 0f
    var totalDamage: Long = 0L
    var peakHit: Int = 0
    var liveDps: Int = 0
    var lastHitWasCrit: Boolean = false

    fun recordHit(damage: Float, isCrit: Boolean, nowSec: Float, hitFromLeft: Boolean) {
        val dmgInt = damage.toInt().coerceAtLeast(1)
        totalDamage += dmgInt.toLong()
        if (dmgInt > peakHit) peakHit = dmgInt
        comboCount++
        comboTimer = 3.2f
        hitFlash = 1f
        lastHitWasCrit = isCrit
        recoilVel += if (hitFromLeft) 11.5f else -11.5f
        recentHits.addLast(HitSample(nowSec, damage))
        recomputeDps(nowSec)
    }

    fun step(dt: Float, nowSec: Float) {
        if (hitFlash > 0f) hitFlash = (hitFlash - dt * 5.5f).coerceAtLeast(0f)
        if (comboTimer > 0f) {
            comboTimer = (comboTimer - dt).coerceAtLeast(0f)
            if (comboTimer <= 0f) comboCount = 0
        }
        val springAcc = -recoilAngle * 95f - recoilVel * 11f
        recoilVel += springAcc * dt
        recoilAngle = (recoilAngle + recoilVel * dt).coerceIn(-0.62f, 0.62f)
        recomputeDps(nowSec)
    }

    fun reset() {
        recentHits.clear()
        comboCount = 0
        comboTimer = 0f
        totalDamage = 0L
        peakHit = 0
        liveDps = 0
        recoilAngle = 0f
        recoilVel = 0f
        hitFlash = 0f
    }

    private fun recomputeDps(nowSec: Float) {
        val windowSec = 3.0f
        while (recentHits.isNotEmpty() && nowSec - recentHits.first().timeSec > windowSec) {
            recentHits.removeFirst()
        }
        if (recentHits.isEmpty()) {
            liveDps = 0
            return
        }
        val sum = recentHits.sumOf { it.damage.toDouble() }
        val span = (nowSec - recentHits.first().timeSec).coerceIn(0.65f, windowSec)
        liveDps = (sum / span).toInt().coerceAtLeast(0)
    }
}

data class RoamTrainingProjectile(
    var x: Float,
    var y: Float,
    val vx: Float,
    val vy: Float,
    val radius: Float,
    val damage: Float,
    val color: Color,
    var life: Float,
    val maxLife: Float,
    val isBeam: Boolean = false,
    val endX: Float = 0f,
    val endY: Float = 0f,
    var hitDummy: Boolean = false,
    val isUlt: Boolean = false
)

data class RoamFloatingDamage(
    var x: Float,
    var y: Float,
    val text: String,
    val color: Color,
    val isCrit: Boolean,
    var life: Float,
    val maxLife: Float
)

/**
 * Fires the active starter's signature move toward the Training Dummy (or facing angle if far).
 */
fun fireRoamSignatureMove(
    starterId: String,
    previewTier: Int,
    heroX: Float,
    heroY: Float,
    heroZ: Float,
    facingAngle: Float,
    dummy: TrainingDummyState,
    nowSec: Float,
    rng: Random,
    projectiles: MutableList<RoamTrainingProjectile>,
    floatingNumbers: MutableList<RoamFloatingDamage>,
    onRing: (x: Float, y: Float, maxR: Float, color: Color) -> Unit
) {
    val starter = GameCatalog.starterById(starterId)
    val moveId = starter.signatureMoves.firstOrNull() ?: return
    val move = GameCatalog.moves[moveId] ?: return
    val tierMult = 1f + previewTier * 0.42f
    val highGroundMult = if (heroZ >= 18f) 1.25f else 1f
    val distToDummy = hypot(dummy.x - heroX, dummy.y - heroY)
    val aimAngle = if (distToDummy <= 540f) {
        atan2(dummy.y - heroY, dummy.x - heroX)
    } else {
        facingAngle
    }
    val baseDmg = move.baseDamage * tierMult * highGroundMult

    when (move.archetype) {
        MoveArchetype.BEAM -> {
            val len = 360f + previewTier * 45f
            val ex = heroX + cos(aimAngle) * len
            val ey = heroY + sin(aimAngle) * len
            projectiles.add(
                RoamTrainingProjectile(
                    x = heroX,
                    y = heroY - heroZ,
                    vx = 0f,
                    vy = 0f,
                    radius = 22f + previewTier * 4f,
                    damage = baseDmg,
                    color = move.type.color,
                    life = 0.28f,
                    maxLife = 0.28f,
                    isBeam = true,
                    endX = ex,
                    endY = ey - heroZ * 0.3f,
                    hitDummy = true
                )
            )
            if (distToDummy <= len + dummy.radius) {
                applyRoamDummyHit(dummy, baseDmg, move.type.color, heroX < dummy.x, nowSec, rng, floatingNumbers)
            }
        }
        MoveArchetype.NOVA -> {
            val novaR = 165f + previewTier * 30f
            onRing(heroX, heroY - heroZ * 0.4f, novaR, move.type.color)
            if (distToDummy <= novaR + dummy.radius) {
                applyRoamDummyHit(dummy, baseDmg * 1.15f, move.type.color, heroX < dummy.x, nowSec, rng, floatingNumbers)
            }
        }
        MoveArchetype.STRIKE -> {
            val strikeR = 155f + previewTier * 26f
            onRing(heroX + cos(aimAngle) * 46f, heroY + sin(aimAngle) * 46f - heroZ * 0.4f, strikeR * 0.72f, move.type.color)
            if (distToDummy <= strikeR + dummy.radius) {
                applyRoamDummyHit(dummy, baseDmg * 1.18f, move.type.color, heroX < dummy.x, nowSec, rng, floatingNumbers)
            }
        }
        else -> {
            val shots = 1 + previewTier
            val spread = 0.16f
            val spd = 610f
            for (i in 0 until shots) {
                val off = (i - (shots - 1) / 2f) * spread
                val a = aimAngle + off
                projectiles.add(
                    RoamTrainingProjectile(
                        x = heroX + cos(a) * 24f,
                        y = heroY + sin(a) * 24f - heroZ * 0.65f,
                        vx = cos(a) * spd,
                        vy = sin(a) * spd,
                        radius = 12f + previewTier * 1.5f,
                        damage = baseDmg,
                        color = move.type.color,
                        life = 0.85f,
                        maxLife = 0.85f
                    )
                )
            }
        }
    }
}

/**
 * Triggers a showcase Ultimate Burst toward the Training Dummy & surrounding arena.
 */
fun fireRoamUltBurst(
    starterId: String,
    previewTier: Int,
    heroX: Float,
    heroY: Float,
    heroZ: Float,
    dummy: TrainingDummyState,
    nowSec: Float,
    rng: Random,
    projectiles: MutableList<RoamTrainingProjectile>,
    floatingNumbers: MutableList<RoamFloatingDamage>,
    onRing: (x: Float, y: Float, maxR: Float, color: Color) -> Unit
) {
    val starter = GameCatalog.starterById(starterId)
    val ultColor = starter.element.color
    val tierMult = 1f + previewTier * 0.55f
    val ultRange = 290f + previewTier * 36f
    onRing(heroX, heroY - heroZ * 0.4f, ultRange, ultColor)
    onRing(heroX, heroY - heroZ * 0.4f, ultRange * 0.68f, GoldAccent)

    val aimAngle = atan2(dummy.y - heroY, dummy.x - heroX)
    val volleyCount = 5 + previewTier * 2
    for (i in 0 until volleyCount) {
        val off = (i - (volleyCount - 1) / 2f) * 0.15f
        val a = aimAngle + off
        projectiles.add(
            RoamTrainingProjectile(
                x = heroX + cos(a) * 26f,
                y = heroY + sin(a) * 26f - heroZ * 0.55f,
                vx = cos(a) * 660f,
                vy = sin(a) * 660f,
                radius = 15f,
                damage = 42f * tierMult,
                color = if (i % 2 == 0) ultColor else GoldAccent,
                life = 0.72f,
                maxLife = 0.72f,
                isUlt = true
            )
        )
    }

    val distToDummy = hypot(dummy.x - heroX, dummy.y - heroY)
    if (distToDummy <= ultRange + dummy.radius) {
        val burstDmg = 135f * tierMult * if (heroZ >= 18f) 1.25f else 1f
        applyRoamDummyHit(dummy, burstDmg, GoldAccent, heroX < dummy.x, nowSec, rng, floatingNumbers, forceCrit = true)
    }
}

fun applyRoamDummyHit(
    dummy: TrainingDummyState,
    rawDamage: Float,
    accentColor: Color,
    hitFromLeft: Boolean,
    nowSec: Float,
    rng: Random,
    floatingNumbers: MutableList<RoamFloatingDamage>,
    forceCrit: Boolean = false,
    prefixLabel: String? = null
) {
    val isCrit = forceCrit || rng.nextFloat() < 0.28f
    val variance = 0.94f + rng.nextFloat() * 0.12f
    val finalDmg = rawDamage * variance * if (isCrit) 1.85f else 1f
    dummy.recordHit(finalDmg, isCrit, nowSec, hitFromLeft)
    val jitterX = (rng.nextFloat() - 0.5f) * 28f
    val label = buildString {
        if (prefixLabel != null) append("$prefixLabel ")
        append(finalDmg.toInt())
        if (isCrit) append("!")
    }
    floatingNumbers.add(
        RoamFloatingDamage(
            x = dummy.x + jitterX,
            y = dummy.y - dummy.radius - 18f,
            text = label,
            color = if (isCrit) GoldAccent else accentColor,
            isCrit = isCrit,
            life = 0.78f,
            maxLife = 0.78f
        )
    )
    if (floatingNumbers.size > 26) {
        floatingNumbers.removeAt(0)
    }
}

/**
 * Draws the Elevated High-Ground Practice Plateau & East-facing Stone Ramp.
 */
fun DrawScope.drawRoamHighGroundPlateau(
    plateau: RoamHighGroundPlateau,
    biome: BiomeDef,
    toScreen: (Float, Float) -> Offset
) {
    val baseCenter = toScreen(plateau.x, plateau.y)
    val topCenter = Offset(baseCenter.x, baseCenter.y - plateau.elevationZ)

    drawOval(
        color = Color.Black.copy(alpha = 0.24f),
        topLeft = Offset(baseCenter.x - plateau.rx * 1.06f, baseCenter.y - plateau.ry * 0.92f + 12f),
        size = Size(plateau.rx * 2.12f, plateau.ry * 1.90f)
    )

    val cliffWall = Path().apply {
        moveTo(topCenter.x - plateau.rx, topCenter.y)
        lineTo(baseCenter.x - plateau.rx, baseCenter.y)
        lineTo(baseCenter.x + plateau.rx, baseCenter.y)
        lineTo(topCenter.x + plateau.rx, topCenter.y)
        close()
    }
    drawPath(cliffWall, color = Color(0xFF5D534B))
    drawOval(
        color = Color(0xFF4C433C),
        topLeft = Offset(baseCenter.x - plateau.rx, baseCenter.y - plateau.ry),
        size = Size(plateau.rx * 2f, plateau.ry * 2f)
    )

    val rampTop = Offset(topCenter.x + plateau.rx * 0.76f, topCenter.y)
    val rampBottom = Offset(baseCenter.x + plateau.rx + 56f, baseCenter.y)
    val rampPath = Path().apply {
        moveTo(rampTop.x, rampTop.y - 26f)
        lineTo(rampBottom.x, rampBottom.y - 24f)
        lineTo(rampBottom.x, rampBottom.y + 24f)
        lineTo(rampTop.x, rampTop.y + 26f)
        close()
    }
    drawPath(rampPath, color = biome.pathColor.copy(alpha = 0.92f))
    drawPath(rampPath, color = EspressoDark.copy(alpha = 0.55f), style = Stroke(3f))

    drawOval(
        color = biome.groundBase,
        topLeft = Offset(topCenter.x - plateau.rx, topCenter.y - plateau.ry),
        size = Size(plateau.rx * 2f, plateau.ry * 2f)
    )
    drawOval(
        color = biome.groundAlt.copy(alpha = 0.65f),
        topLeft = Offset(topCenter.x - plateau.rx * 0.80f, topCenter.y - plateau.ry * 0.76f),
        size = Size(plateau.rx * 1.60f, plateau.ry * 1.52f)
    )
    drawOval(
        color = GoldAccent.copy(alpha = 0.78f),
        topLeft = Offset(topCenter.x - plateau.rx, topCenter.y - plateau.ry),
        size = Size(plateau.rx * 2f, plateau.ry * 2f),
        style = Stroke(width = 3.5f)
    )
}

/**
 * Draws the animated Training Dummy with target bullseye, hit flash, and spring recoil sway.
 */
fun DrawScope.drawRoamTrainingDummy(
    dummy: TrainingDummyState,
    time: Float,
    toScreen: (Float, Float) -> Offset
) {
    val base = toScreen(dummy.x, dummy.y)
    val pulse = 0.94f + 0.06f * sin(time * 4.5f)

    drawCircle(
        color = GoldAccent.copy(alpha = 0.16f + dummy.hitFlash * 0.24f),
        radius = (dummy.radius + 18f) * pulse,
        center = base
    )
    drawCircle(
        color = GoldAccent.copy(alpha = 0.55f),
        radius = dummy.radius + 18f,
        center = base,
        style = Stroke(width = 2.4f)
    )

    drawOval(
        color = Color.Black.copy(alpha = 0.28f),
        topLeft = Offset(base.x - 32f, base.y + 8f),
        size = Size(64f, 22f)
    )
    drawOval(
        color = Color(0xFF6B472B),
        topLeft = Offset(base.x - 26f, base.y + 4f),
        size = Size(52f, 18f)
    )
    drawOval(
        color = EspressoDark,
        topLeft = Offset(base.x - 26f, base.y + 4f),
        size = Size(52f, 18f),
        style = Stroke(2.5f)
    )

    val tiltDeg = dummy.recoilAngle * (180f / PI.toFloat())
    rotate(degrees = tiltDeg, pivot = Offset(base.x, base.y + 10f)) {
        drawRoundRect(
            color = Color(0xFF8C5A34),
            topLeft = Offset(base.x - 7f, base.y - 44f),
            size = Size(14f, 54f),
            cornerRadius = CornerRadius(5f, 5f)
        )
        drawRoundRect(
            color = Color(0xFF9C663C),
            topLeft = Offset(base.x - 34f, base.y - 34f),
            size = Size(68f, 11f),
            cornerRadius = CornerRadius(5f, 5f)
        )
        drawRoundRect(
            color = EspressoDark,
            topLeft = Offset(base.x - 34f, base.y - 34f),
            size = Size(68f, 11f),
            cornerRadius = CornerRadius(5f, 5f),
            style = Stroke(2.2f)
        )

        val bodyCenter = Offset(base.x, base.y - 26f)
        val bodyTint = if (dummy.hitFlash > 0.1f) Color.White else Color(0xFFE7C796)
        drawOval(
            color = bodyTint,
            topLeft = Offset(bodyCenter.x - 22f, bodyCenter.y - 22f),
            size = Size(44f, 46f)
        )
        drawOval(
            color = EspressoDark,
            topLeft = Offset(bodyCenter.x - 22f, bodyCenter.y - 22f),
            size = Size(44f, 46f),
            style = Stroke(2.8f)
        )

        drawCircle(CrimsonRed, 13f, bodyCenter)
        drawCircle(CreamSurface, 8.5f, bodyCenter)
        drawCircle(CrimsonRed, 4.2f, bodyCenter)

        val headCenter = Offset(base.x, base.y - 54f)
        drawCircle(if (dummy.hitFlash > 0.15f) GoldAccent else Color(0xFFF0D5A8), 16f, headCenter)
        drawCircle(EspressoDark, 16f, headCenter, style = Stroke(2.6f))
        drawLine(
            color = CrimsonRed,
            start = Offset(headCenter.x - 15f, headCenter.y - 4f),
            end = Offset(headCenter.x + 15f, headCenter.y - 4f),
            strokeWidth = 5f,
            cap = StrokeCap.Round
        )
        drawCircle(EspressoDark, 2.2f, Offset(headCenter.x - 5.5f, headCenter.y + 3f))
        drawCircle(EspressoDark, 2.2f, Offset(headCenter.x + 5.5f, headCenter.y + 3f))
    }
}

fun DrawScope.drawRoamTrainingProjectiles(
    projectiles: List<RoamTrainingProjectile>,
    toScreen: (Float, Float) -> Offset
) {
    for (p in projectiles) {
        val alpha = (p.life / p.maxLife).coerceIn(0f, 1f)
        val start = toScreen(p.x, p.y)
        if (p.isBeam) {
            val end = toScreen(p.endX, p.endY)
            drawLine(p.color.copy(alpha = alpha * 0.45f), start, end, strokeWidth = p.radius * 1.4f, cap = StrokeCap.Round)
            drawLine(p.color.copy(alpha = alpha), start, end, strokeWidth = p.radius * 0.72f, cap = StrokeCap.Round)
            drawLine(Color.White.copy(alpha = alpha), start, end, strokeWidth = p.radius * 0.28f, cap = StrokeCap.Round)
        } else {
            drawCircle(p.color.copy(alpha = alpha * 0.34f), p.radius * 1.75f, start)
            drawCircle(p.color.copy(alpha = alpha), p.radius, start)
            drawCircle(Color.White.copy(alpha = alpha * 0.92f), p.radius * 0.46f, start)
        }
    }
}

fun DrawScope.drawRoamFloatingDamages(
    floatingNumbers: List<RoamFloatingDamage>,
    toScreen: (Float, Float) -> Offset,
    strokePaint: Paint,
    fillPaint: Paint
) {
    val nativeCanvas = drawContext.canvas.nativeCanvas
    for (ft in floatingNumbers) {
        val pos = toScreen(ft.x, ft.y)
        if (pos.x < -80f || pos.x > size.width + 80f || pos.y < -60f || pos.y > size.height + 60f) continue
        val alpha = (ft.life / ft.maxLife).coerceIn(0f, 1f)
        val pop = if (alpha > 0.78f) 1f + (alpha - 0.78f) * 1.15f else 1f
        val textSize = (if (ft.isCrit) 40f else 28f) * pop
        val alphaInt = (alpha * 255).toInt().coerceIn(0, 255)
        strokePaint.textSize = textSize
        strokePaint.strokeWidth = if (ft.isCrit) 8.5f else 6f
        strokePaint.alpha = alphaInt
        fillPaint.textSize = textSize
        fillPaint.color = ft.color.toArgb()
        fillPaint.alpha = alphaInt
        nativeCanvas.drawText(ft.text, pos.x, pos.y, strokePaint)
        nativeCanvas.drawText(ft.text, pos.x, pos.y, fillPaint)
    }
}

fun createRoamDamagePaints(): Pair<Paint, Paint> {
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        color = EspressoDark.toArgb()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    return strokePaint to fillPaint
}

/**
 * Dark-glass live DPS / Peak Crit / Combo telemetry strip for the Training Sandbox.
 */
@Composable
fun RoamDpsTelemetryCard(
    liveDps: Int,
    peakHit: Int,
    comboCount: Int,
    isOnHighGround: Boolean,
    autoFireEnabled: Boolean,
    compact: Boolean,
    onToggleAutoFire: () -> Unit,
    onResetStats: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .testTag("roam_dps_card")
            .clip(RoundedCornerShape(16.dp))
            .background(HudInkDark.copy(alpha = 0.88f))
            .border(1.4.dp, GoldAccent.copy(alpha = 0.72f), RoundedCornerShape(16.dp))
            .padding(horizontal = if (compact) 8.dp else 11.dp, vertical = if (compact) 4.dp else 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 10.dp)
    ) {
        Column(horizontalAlignment = Alignment.Start) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Icon(Icons.Rounded.Whatshot, contentDescription = null, tint = WarmOrange, modifier = Modifier.size(12.dp))
                Text(
                    text = "DPS $liveDps",
                    style = MaterialTheme.typography.titleSmall.copy(fontSize = if (compact) 11.sp else 12.5.sp),
                    color = GoldAccent,
                    maxLines = 1
                )
            }
            Text(
                text = "峰值 $peakHit · ${comboCount}连${if (isOnHighGround) " · 高地+" else ""}",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 8.5.sp else 9.5.sp),
                color = CreamSurface.copy(alpha = 0.85f),
                maxLines = 1
            )
        }

        Row(
            modifier = Modifier
                .testTag("roam_autofire_btn")
                .clip(RoundedCornerShape(50))
                .background(if (autoFireEnabled) GrassGreen.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.08f))
                .border(
                    width = 1.2.dp,
                    color = if (autoFireEnabled) GrassGreen else Color.White.copy(alpha = 0.22f),
                    shape = RoundedCornerShape(50)
                )
                .clickable(onClick = onToggleAutoFire)
                .padding(horizontal = 7.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Icon(
                imageVector = if (autoFireEnabled) Icons.Rounded.Bolt else Icons.Rounded.AutoAwesome,
                contentDescription = "自动试招开关",
                tint = if (autoFireEnabled) GrassGreen else CreamSurface.copy(alpha = 0.72f),
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = if (autoFireEnabled) "连发开" else "连发关",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                color = if (autoFireEnabled) GrassGreen else CreamSurface.copy(alpha = 0.80f),
                maxLines = 1
            )
        }

        Box(
            modifier = Modifier
                .testTag("roam_dps_reset_btn")
                .minimumInteractiveComponentSize()
                .size(if (compact) 28.dp else 32.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.10f))
                .border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape)
                .clickable(onClick = onResetStats),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Rounded.Refresh,
                contentDescription = "重置打桩统计",
                tint = CreamSurface,
                modifier = Modifier.size(15.dp)
            )
        }
    }
}


