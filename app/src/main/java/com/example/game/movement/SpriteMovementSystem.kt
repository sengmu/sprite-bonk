package com.example.game.movement

import androidx.compose.ui.graphics.Color
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Distinct locomotion physics & visual feel per sprite.
 * Tuned specifically for 树桩洞傀 (stump), 冷炭裂膛 (char), and 对旋双壳 (shell),
 * plus the extended roster so every playable character benefits from the system.
 */
data class SpriteLocomotionProfile(
    val starterId: String,
    val styleNameZh: String,
    val styleDescZh: String,
    val baseMaxSpeed: Float,
    val accelerationRate: Float,
    val decelerationRate: Float,
    val turnSmoothingRate: Float,
    val maxLeanDegrees: Float,
    val gaitFrequency: Float,
    val dashDurationSec: Float,
    val dashCooldownSec: Float,
    val dashSpeedMultiplier: Float,
    val dashCarryMomentum: Float,
    val cameraFollowRate: Float,
    val cameraLookAheadSec: Float,
    val trailColor: Color,
    val accentTrailColor: Color
)

object SpriteLocomotionProfiles {
    val STUMP = SpriteLocomotionProfile(
        starterId = "stump",
        styleNameZh = "根系稳步",
        styleDescZh = "高抓地起停 · 扎实弹性步态 · 藤蔓突进",
        baseMaxSpeed = 248f,
        accelerationRate = 14.5f,
        decelerationRate = 13.5f,
        turnSmoothingRate = 15.0f,
        maxLeanDegrees = 9.5f,
        gaitFrequency = 10.8f,
        dashDurationSec = 0.24f,
        dashCooldownSec = 2.15f,
        dashSpeedMultiplier = 2.55f,
        dashCarryMomentum = 0.55f,
        cameraFollowRate = 7.5f,
        cameraLookAheadSec = 0.24f,
        trailColor = GrassGreen,
        accentTrailColor = Color(0xFFC8F57A)
    )

    val CHAR = SpriteLocomotionProfile(
        starterId = "char",
        styleNameZh = "焰膛喷射",
        styleDescZh = "极速爆发加速 · 敏捷转向 · 喷焰长冲刺",
        baseMaxSpeed = 282f,
        accelerationRate = 18.0f,
        decelerationRate = 9.6f,
        turnSmoothingRate = 18.5f,
        maxLeanDegrees = 14.5f,
        gaitFrequency = 12.8f,
        dashDurationSec = 0.26f,
        dashCooldownSec = 1.95f,
        dashSpeedMultiplier = 2.95f,
        dashCarryMomentum = 0.72f,
        cameraFollowRate = 8.4f,
        cameraLookAheadSec = 0.30f,
        trailColor = WarmOrange,
        accentTrailColor = GoldAccent
    )

    val SHELL = SpriteLocomotionProfile(
        starterId = "shell",
        styleNameZh = "双壳涡流",
        styleDescZh = "流体惯性滑行 · 丝滑离心过弯 · 涡旋水滑",
        baseMaxSpeed = 266f,
        accelerationRate = 11.4f,
        decelerationRate = 6.6f,
        turnSmoothingRate = 12.5f,
        maxLeanDegrees = 16.0f,
        gaitFrequency = 11.5f,
        dashDurationSec = 0.30f,
        dashCooldownSec = 2.05f,
        dashSpeedMultiplier = 2.75f,
        dashCarryMomentum = 0.86f,
        cameraFollowRate = 7.0f,
        cameraLookAheadSec = 0.32f,
        trailColor = SkyBlue,
        accentTrailColor = Color(0xFFB5F5FF)
    )

    val SPARK = SpriteLocomotionProfile(
        starterId = "spark",
        styleNameZh = "电弧闪步",
        styleDescZh = "瞬时电光折返 · 超短冷却冲刺",
        baseMaxSpeed = 296f,
        accelerationRate = 21.0f,
        decelerationRate = 15.0f,
        turnSmoothingRate = 22.0f,
        maxLeanDegrees = 15.0f,
        gaitFrequency = 13.8f,
        dashDurationSec = 0.21f,
        dashCooldownSec = 1.65f,
        dashSpeedMultiplier = 3.05f,
        dashCarryMomentum = 0.65f,
        cameraFollowRate = 9.0f,
        cameraLookAheadSec = 0.28f,
        trailColor = Color(0xFFFAD02C),
        accentTrailColor = Color(0xFFFFFAAD)
    )

    val WISP = SpriteLocomotionProfile(
        starterId = "wisp",
        styleNameZh = "幽灯浮游",
        styleDescZh = "低阻灵体漂浮 · 柔缓弧线飘移",
        baseMaxSpeed = 268f,
        accelerationRate = 10.5f,
        decelerationRate = 6.0f,
        turnSmoothingRate = 11.5f,
        maxLeanDegrees = 13.0f,
        gaitFrequency = 9.2f,
        dashDurationSec = 0.28f,
        dashCooldownSec = 2.0f,
        dashSpeedMultiplier = 2.70f,
        dashCarryMomentum = 0.85f,
        cameraFollowRate = 6.8f,
        cameraLookAheadSec = 0.30f,
        trailColor = Color(0xFF9A6AFF),
        accentTrailColor = Color(0xFF6CF7FF)
    )

    val DRAKE = SpriteLocomotionProfile(
        starterId = "drake",
        styleNameZh = "星翼滑翔",
        styleDescZh = "均衡推进与滑翔动量 · 彗星尾迹",
        baseMaxSpeed = 276f,
        accelerationRate = 14.0f,
        decelerationRate = 8.4f,
        turnSmoothingRate = 15.0f,
        maxLeanDegrees = 14.0f,
        gaitFrequency = 11.8f,
        dashDurationSec = 0.26f,
        dashCooldownSec = 2.0f,
        dashSpeedMultiplier = 2.85f,
        dashCarryMomentum = 0.78f,
        cameraFollowRate = 7.8f,
        cameraLookAheadSec = 0.29f,
        trailColor = Color(0xFF56B4FF),
        accentTrailColor = GoldAccent
    )

    fun forStarter(starterId: String): SpriteLocomotionProfile = when (starterId) {
        "stump" -> STUMP
        "char" -> CHAR
        "shell" -> SHELL
        "spark" -> SPARK
        "wisp" -> WISP
        "drake" -> DRAKE
        else -> STUMP
    }
}

enum class MapObstacleKind {
    TREE,
    BOULDER,
    POND,
    SPEED_PAD
}

data class MapObstacle(
    val id: Int,
    val x: Float,
    val y: Float,
    val radius: Float,
    val kind: MapObstacleKind
)

data class MovementTrailPoint(
    val x: Float,
    val y: Float,
    val alpha: Float,
    val radius: Float,
    val color: Color,
    val isDash: Boolean
)

/**
 * Immutable per-frame snapshot produced by [SpriteMovementController.step].
 */
data class SpriteMovementState(
    val starterId: String = "stump",
    val profile: SpriteLocomotionProfile = SpriteLocomotionProfiles.STUMP,
    val x: Float = 0f,
    val y: Float = 0f,
    val vx: Float = 0f,
    val vy: Float = 0f,
    val speed: Float = 0f,
    val maxSpeed: Float = 248f,
    val speedRatio: Float = 0f,
    val facingAngle: Float = 0f,
    val leanDeg: Float = 0f,
    val walkCycle: Float = 0f,
    val cameraX: Float = 0f,
    val cameraY: Float = 0f,
    val isDashing: Boolean = false,
    val dashActiveTimer: Float = 0f,
    val dashCooldownRatio: Float = 0f,
    val inputMagnitude: Float = 0f,
    val waypointX: Float? = null,
    val waypointY: Float? = null,
    val onSpeedPad: Boolean = false,
    val trailPoints: List<MovementTrailPoint> = emptyList()
)

/**
 * Frame-rate-independent 2D Sprite Locomotion Controller designed for Compose game loops (`withFrameNanos`).
 *
 * Key features:
 * - Exponential acceleration & deceleration smoothing (`1 - exp(-rate * dt)`)
 * - Radial deadzone & non-linear analog joystick sensitivity curve
 * - Smooth shortest-arc facing angle interpolation & velocity-driven banking lean
 * - Species-specific locomotion feel (Stump / Char / Shell + extended roster)
 * - Momentum-preserving dash with easing curve
 * - Tap-to-move waypoint guidance with soft arrival damping
 * - Smooth circle-vs-circle obstacle sliding collision & arena boundary clamping
 * - Spring-damped camera follow with velocity look-ahead
 */
class SpriteMovementController(
    initialStarterId: String = "stump",
    startX: Float = 0f,
    startY: Float = 0f,
    val spriteCollisionRadius: Float = 24f
) {
    var profile: SpriteLocomotionProfile = SpriteLocomotionProfiles.forStarter(initialStarterId)
        private set

    var x: Float = startX
        private set
    var y: Float = startY
        private set
    var vx: Float = 0f
        private set
    var vy: Float = 0f
        private set
    var facingAngle: Float = 0f
        private set
    var leanDeg: Float = 0f
        private set
    var walkCycle: Float = 0f
        private set
    var cameraX: Float = startX
        private set
    var cameraY: Float = startY
        private set

    private var analogX: Float = 0f
    private var analogY: Float = 0f
    private var keyX: Float = 0f
    private var keyY: Float = 0f
    private var waypointX: Float? = null
    private var waypointY: Float? = null

    var dashActiveTimer: Float = 0f
        private set
    var dashCooldownTimer: Float = 0f
        private set
    private var dashDirX: Float = 1f
    private var dashDirY: Float = 0f

    private var speedPadBoostTimer: Float = 0f
    private var trailEmitAccum: Float = 0f

    private class InternalTrail(
        val x: Float,
        val y: Float,
        var life: Float,
        val maxLife: Float,
        val radius: Float,
        val color: Color,
        val isDash: Boolean
    )

    private val trails = mutableListOf<InternalTrail>()

    fun switchProfile(starterId: String) {
        profile = SpriteLocomotionProfiles.forStarter(starterId)
        dashCooldownTimer = min(dashCooldownTimer, profile.dashCooldownSec)
    }

    fun reset(newX: Float = 0f, newY: Float = 0f) {
        x = newX
        y = newY
        vx = 0f
        vy = 0f
        cameraX = newX
        cameraY = newY
        leanDeg = 0f
        analogX = 0f
        analogY = 0f
        keyX = 0f
        keyY = 0f
        dashActiveTimer = 0f
        dashCooldownTimer = 0f
        speedPadBoostTimer = 0f
        waypointX = null
        waypointY = null
        trails.clear()
    }

    /**
     * Analog joystick input in [-1, 1] range with radial deadzone and smooth response curve.
     */
    fun setAnalogInput(rawX: Float, rawY: Float) {
        val rawMag = hypot(rawX, rawY)
        val deadzone = 0.08f
        if (rawMag <= deadzone) {
            analogX = 0f
            analogY = 0f
            return
        }
        val normalizedMag = ((rawMag - deadzone) / (1f - deadzone)).coerceIn(0f, 1f)
        // Non-linear power curve gives fine low-speed precision while reaching 100% smoothly
        val curvedMag = normalizedMag.pow(1.32f)
        analogX = (rawX / rawMag) * curvedMag
        analogY = (rawY / rawMag) * curvedMag
        // Manual joystick takes priority over tap-to-move waypoint
        waypointX = null
        waypointY = null
    }

    /**
     * Optional keyboard WASD / D-Pad directional input.
     */
    fun setKeyboardInput(dx: Float, dy: Float) {
        val mag = hypot(dx, dy)
        if (mag > 0.01f) {
            keyX = dx / mag
            keyY = dy / mag
            waypointX = null
            waypointY = null
        } else {
            keyX = 0f
            keyY = 0f
        }
    }

    /**
     * Sets a world-space target destination for smooth Tap-to-Move guidance.
     */
    fun setWaypoint(worldX: Float, worldY: Float, arenaHalfSize: Float) {
        waypointX = worldX.coerceIn(-arenaHalfSize + 24f, arenaHalfSize - 24f)
        waypointY = worldY.coerceIn(-arenaHalfSize + 24f, arenaHalfSize - 24f)
    }

    fun clearWaypoint() {
        waypointX = null
        waypointY = null
    }

    /**
     * Triggers a species-tuned burst dash along the active movement or facing direction.
     * Returns true if the dash was triggered.
     */
    fun triggerDash(speedMultiplier: Float = 1f, baseSpeedOverride: Float? = null): Boolean {
        if (dashCooldownTimer > 0f || dashActiveTimer > 0f) return false
        val (inX, inY) = resolveSteeringVector()
        val inMag = hypot(inX, inY)
        if (inMag > 0.1f) {
            dashDirX = inX / inMag
            dashDirY = inY / inMag
        } else {
            dashDirX = cos(facingAngle)
            dashDirY = sin(facingAngle)
        }
        facingAngle = atan2(dashDirY, dashDirX)
        dashActiveTimer = profile.dashDurationSec
        dashCooldownTimer = profile.dashCooldownSec

        val maxSpd = (baseSpeedOverride ?: profile.baseMaxSpeed) * speedMultiplier
        val burstSpeed = maxSpd * profile.dashSpeedMultiplier
        vx = dashDirX * burstSpeed
        vy = dashDirY * burstSpeed
        return true
    }

    fun applyImpulse(ix: Float, iy: Float) {
        vx += ix
        vy += iy
    }

    /**
     * Synchronizes controller coordinates after external 2.5D terrain ledge resolution.
     */
    fun clampWorldPosition(newX: Float, newY: Float) {
        x = newX
        y = newY
    }

    private fun resolveSteeringVector(): Pair<Float, Float> {
        val aMag = hypot(analogX, analogY)
        if (aMag > 0.01f) return analogX to analogY

        val kMag = hypot(keyX, keyY)
        if (kMag > 0.01f) return keyX to keyY

        val wx = waypointX
        val wy = waypointY
        if (wx != null && wy != null) {
            val dx = wx - x
            val dy = wy - y
            val dist = hypot(dx, dy)
            if (dist < 18f) {
                waypointX = null
                waypointY = null
                return 0f to 0f
            }
            // Smooth arrival deceleration within 72 world units of waypoint
            val arrivalScale = (dist / 72f).coerceIn(0.32f, 1f)
            return (dx / dist * arrivalScale) to (dy / dist * arrivalScale)
        }
        return 0f to 0f
    }

    fun step(
        rawDt: Float,
        speedMultiplier: Float = 1f,
        arenaHalfSize: Float = 1450f,
        obstacles: List<MapObstacle> = emptyList(),
        baseSpeedOverride: Float? = null,
        emitTrails: Boolean = true
    ): SpriteMovementState {
        val dt = rawDt.coerceIn(0.001f, 0.05f)
        if (dashCooldownTimer > 0f) dashCooldownTimer = (dashCooldownTimer - dt).coerceAtLeast(0f)
        if (speedPadBoostTimer > 0f) speedPadBoostTimer = (speedPadBoostTimer - dt).coerceAtLeast(0f)

        val (steerX, steerY) = resolveSteeringVector()
        val steerMag = hypot(steerX, steerY).coerceIn(0f, 1f)

        val padBoost = if (speedPadBoostTimer > 0f) 1.42f else 1f
        val effectiveMaxSpeed = (baseSpeedOverride ?: profile.baseMaxSpeed) * speedMultiplier * padBoost

        val isDashingNow = dashActiveTimer > 0f
        if (isDashingNow) {
            dashActiveTimer = (dashActiveTimer - dt).coerceAtLeast(0f)
            val progress = 1f - (dashActiveTimer / profile.dashDurationSec).coerceIn(0f, 1f)
            // Ease-out burst curve so dash starts punchy and blends cleanly into normal sprint
            val dashCurve = 1f - 0.35f * progress * progress
            val targetDashSpeed = effectiveMaxSpeed * profile.dashSpeedMultiplier * dashCurve
            vx = dashDirX * targetDashSpeed
            vy = dashDirY * targetDashSpeed
            if (dashActiveTimer <= 0f) {
                // Preserve species-specific carry momentum after dash finishes
                val carry = effectiveMaxSpeed * (0.95f + profile.dashCarryMomentum * 0.45f)
                vx = dashDirX * carry
                vy = dashDirY * carry
            }
        } else {
            val targetVx = steerX * effectiveMaxSpeed
            val targetVy = steerY * effectiveMaxSpeed
            val rate = if (steerMag > 0.05f) profile.accelerationRate else profile.decelerationRate
            // Frame-rate-independent exponential interpolation
            val blend = 1f - exp(-rate * dt)
            vx += (targetVx - vx) * blend
            vy += (targetVy - vy) * blend

            // Snap tiny residual drift to clean zero
            if (steerMag < 0.01f && hypot(vx, vy) < 3.5f) {
                vx = 0f
                vy = 0f
            }
        }

        // Integrate position
        x += vx * dt
        y += vy * dt

        // Resolve obstacle collisions (smooth tangential wall-sliding + speed pad triggers)
        var touchingSpeedPad = false
        for (obs in obstacles) {
            val dx = x - obs.x
            val dy = y - obs.y
            val dist = hypot(dx, dy)
            if (obs.kind == MapObstacleKind.SPEED_PAD) {
                if (dist < obs.radius + spriteCollisionRadius * 0.6f) {
                    speedPadBoostTimer = 1.6f
                    touchingSpeedPad = true
                }
            } else {
                val minDist = obs.radius + spriteCollisionRadius
                if (dist < minDist) {
                    val nx = if (dist > 0.001f) dx / dist else 1f
                    val ny = if (dist > 0.001f) dy / dist else 0f
                    x = obs.x + nx * minDist
                    y = obs.y + ny * minDist
                    // Remove only the inward normal velocity so the sprite glides smoothly around the obstacle
                    val vn = vx * nx + vy * ny
                    if (vn < 0f) {
                        vx -= vn * nx
                        vy -= vn * ny
                    }
                }
            }
        }

        // Arena boundary clamp with clean wall-slide
        val boundLimit = (arenaHalfSize - spriteCollisionRadius).coerceAtLeast(100f)
        if (x < -boundLimit) {
            x = -boundLimit
            if (vx < 0f) vx = 0f
        } else if (x > boundLimit) {
            x = boundLimit
            if (vx > 0f) vx = 0f
        }
        if (y < -boundLimit) {
            y = -boundLimit
            if (vy < 0f) vy = 0f
        } else if (y > boundLimit) {
            y = boundLimit
            if (vy > 0f) vy = 0f
        }

        val currentSpeed = hypot(vx, vy)
        val speedRatio = (currentSpeed / effectiveMaxSpeed.coerceAtLeast(1f)).coerceIn(0f, 2.2f)

        // Smooth shortest-arc facing rotation & velocity-driven body lean
        if (currentSpeed > 12f) {
            val targetAngle = atan2(vy, vx)
            val deltaAngle = normalizeAngle(targetAngle - facingAngle)
            val rotBlend = 1f - exp(-profile.turnSmoothingRate * dt)
            facingAngle = normalizeAngle(facingAngle + deltaAngle * rotBlend)

            // Horizontal velocity + turning lean
            val horizontalFactor = (vx / effectiveMaxSpeed.coerceAtLeast(1f)).coerceIn(-1.2f, 1.2f)
            val targetLean = horizontalFactor * profile.maxLeanDegrees
            val leanBlend = 1f - exp(-12f * dt)
            leanDeg += (targetLean - leanDeg) * leanBlend

            walkCycle += dt * profile.gaitFrequency * (0.45f + 0.65f * min(1.6f, speedRatio))
        } else {
            val leanBlend = 1f - exp(-10f * dt)
            leanDeg += (0f - leanDeg) * leanBlend
        }

        // Spring-damped camera follow with velocity look-ahead
        val lookAheadX = (vx * profile.cameraLookAheadSec).coerceIn(-115f, 115f)
        val lookAheadY = (vy * profile.cameraLookAheadSec).coerceIn(-95f, 95f)
        val camTargetX = x + lookAheadX
        val camTargetY = y + lookAheadY
        val camBlend = 1f - exp(-profile.cameraFollowRate * dt)
        cameraX += (camTargetX - cameraX) * camBlend
        cameraY += (camTargetY - cameraY) * camBlend

        // Motion trail points (footsteps / ember sparks / water ripples / dash ribbons)
        if (emitTrails) {
            val iter = trails.iterator()
            while (iter.hasNext()) {
                val t = iter.next()
                t.life -= dt
                if (t.life <= 0f) iter.remove()
            }
            if (currentSpeed > 45f || isDashingNow) {
                val emitInterval = if (isDashingNow) 0.024f else 0.058f
                trailEmitAccum += dt
                if (trailEmitAccum >= emitInterval) {
                    trailEmitAccum = 0f
                    val col = if (isDashingNow || speedPadBoostTimer > 0f) profile.accentTrailColor else profile.trailColor
                    val r = when {
                        isDashingNow -> 18f
                        profile.starterId == "shell" -> 13f
                        else -> 8.5f
                    }
                    trails.add(
                        InternalTrail(
                            x = x - cos(facingAngle) * 10f,
                            y = y + 10f,
                            life = if (isDashingNow) 0.32f else 0.38f,
                            maxLife = if (isDashingNow) 0.32f else 0.38f,
                            radius = r,
                            color = col,
                            isDash = isDashingNow
                        )
                    )
                    if (trails.size > 36) trails.removeAt(0)
                }
            }
        }

        val dashCooldownRatio = if (profile.dashCooldownSec > 0f) {
            (dashCooldownTimer / profile.dashCooldownSec).coerceIn(0f, 1f)
        } else 0f

        return SpriteMovementState(
            starterId = profile.starterId,
            profile = profile,
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            speed = currentSpeed,
            maxSpeed = effectiveMaxSpeed,
            speedRatio = speedRatio,
            facingAngle = facingAngle,
            leanDeg = leanDeg,
            walkCycle = walkCycle,
            cameraX = cameraX,
            cameraY = cameraY,
            isDashing = isDashingNow,
            dashActiveTimer = dashActiveTimer,
            dashCooldownRatio = dashCooldownRatio,
            inputMagnitude = steerMag,
            waypointX = waypointX,
            waypointY = waypointY,
            onSpeedPad = touchingSpeedPad || speedPadBoostTimer > 0f,
            trailPoints = if (emitTrails) {
                trails.map {
                    MovementTrailPoint(
                        x = it.x,
                        y = it.y,
                        alpha = (it.life / it.maxLife).coerceIn(0f, 1f),
                        radius = it.radius,
                        color = it.color,
                        isDash = it.isDash
                    )
                }
            } else emptyList()
        )
    }

    private fun normalizeAngle(angle: Float): Float {
        var a = angle
        val twoPi = (2.0 * PI).toFloat()
        val pi = PI.toFloat()
        while (a > pi) a -= twoPi
        while (a < -pi) a += twoPi
        return a
    }
}
