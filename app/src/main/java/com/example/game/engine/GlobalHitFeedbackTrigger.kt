package com.example.game.engine

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Immutable frame snapshot of the global player-hit feedback trigger.
 */
data class HitFeedbackSnapshot(
    val hitEventId: Long = 0L,
    val edgeFlashIntensity: Float = 0f,
    val flashPulse: Float = 0f,
    val shakeOffsetX: Float = 0f,
    val shakeOffsetY: Float = 0f,
    val lastDamageRatio: Float = 0f
) {
    val isActive: Boolean
        get() = edgeFlashIntensity > 0.005f ||
            abs(shakeOffsetX) > 0.05f ||
            abs(shakeOffsetY) > 0.05f
}

/**
 * Global Hit Feedback Trigger driven directly by the main game loop (`step(dt)`).
 *
 * Whenever the player sprite takes enemy damage:
 * - Emits a discrete [hitEventId] trigger and invokes [onHitTriggered] for tactile vibration.
 * - Drives a crisp, flickering red screen-edge glow ([edgeFlashIntensity] + [flashPulse]).
 * - Drives a subtle, high-frequency damped viewport micro-shake ([shakeOffsetX], [shakeOffsetY]).
 */
class GlobalHitFeedbackTrigger(
    private val onHitTriggered: (intensity: Float) -> Unit = {}
) {
    private var hitEventId: Long = 0L
    private var flashRemainingSec: Float = 0f
    private var flashElapsedSec: Float = 0f
    private var peakFlashIntensity: Float = 0f

    private var shakeRemainingSec: Float = 0f
    private var shakeElapsedSec: Float = 0f
    private var peakShakeDp: Float = 0f

    private var edgeFlashIntensity: Float = 0f
    private var flashPulse: Float = 0f
    private var shakeOffsetX: Float = 0f
    private var shakeOffsetY: Float = 0f
    private var lastDamageRatio: Float = 0f

    fun triggerHit(
        damageAmount: Float,
        maxHp: Float,
        screenShakeEnabled: Boolean = true
    ) {
        if (damageAmount <= 0f) return
        val dmgRatio = (damageAmount / maxHp.coerceAtLeast(1f)).coerceIn(0.02f, 1f)
        val severity = (0.62f + dmgRatio * 1.45f).coerceIn(0.65f, 1.0f)

        hitEventId += 1L
        lastDamageRatio = dmgRatio

        flashRemainingSec = FLASH_DURATION_SEC
        flashElapsedSec = 0f
        peakFlashIntensity = severity
        edgeFlashIntensity = severity
        flashPulse = 1f

        if (screenShakeEnabled) {
            shakeRemainingSec = SHAKE_DURATION_SEC
            shakeElapsedSec = 0f
            peakShakeDp = 3.8f + 2.6f * severity
            shakeOffsetX = peakShakeDp * 0.7f
            shakeOffsetY = -peakShakeDp * 0.45f
        } else {
            shakeRemainingSec = 0f
            shakeOffsetX = 0f
            shakeOffsetY = 0f
        }

        onHitTriggered(severity)
    }

    fun step(dtSec: Float) {
        val dt = dtSec.coerceIn(0f, 0.05f)
        if (dt <= 0f) return

        if (flashRemainingSec > 0f) {
            flashElapsedSec += dt
            flashRemainingSec = (flashRemainingSec - dt).coerceAtLeast(0f)
            val progress = (flashElapsedSec / FLASH_DURATION_SEC).coerceIn(0f, 1f)
            val decay = (1f - progress) * (1f - progress * 0.30f)
            // Rapid double-flash shimmer so screen edges visibly flicker red on impact
            val flickerWave = 0.64f + 0.36f * abs(cos(flashElapsedSec * 24f))
            edgeFlashIntensity = if (flashRemainingSec <= 0f) {
                0f
            } else {
                (peakFlashIntensity * decay * flickerWave).coerceIn(0f, 1f)
            }
            flashPulse = if (flashRemainingSec <= 0f) {
                0f
            } else {
                (0.5f + 0.5f * cos(flashElapsedSec * 30f)).coerceIn(0f, 1f)
            }
        } else {
            edgeFlashIntensity = 0f
            flashPulse = 0f
        }

        if (shakeRemainingSec > 0f) {
            shakeElapsedSec += dt
            shakeRemainingSec = (shakeRemainingSec - dt).coerceAtLeast(0f)
            if (shakeRemainingSec <= 0f) {
                shakeOffsetX = 0f
                shakeOffsetY = 0f
            } else {
                val damp = (shakeRemainingSec / SHAKE_DURATION_SEC).coerceIn(0f, 1f)
                val amp = peakShakeDp * damp * damp
                shakeOffsetX = sin(shakeElapsedSec * 72f) * amp
                shakeOffsetY = cos(shakeElapsedSec * 88f) * amp * 0.72f
            }
        } else {
            shakeOffsetX = 0f
            shakeOffsetY = 0f
        }
    }

    fun reset() {
        flashRemainingSec = 0f
        flashElapsedSec = 0f
        peakFlashIntensity = 0f
        shakeRemainingSec = 0f
        shakeElapsedSec = 0f
        peakShakeDp = 0f
        edgeFlashIntensity = 0f
        flashPulse = 0f
        shakeOffsetX = 0f
        shakeOffsetY = 0f
        lastDamageRatio = 0f
    }

    fun snapshot(): HitFeedbackSnapshot = HitFeedbackSnapshot(
        hitEventId = hitEventId,
        edgeFlashIntensity = edgeFlashIntensity,
        flashPulse = flashPulse,
        shakeOffsetX = shakeOffsetX,
        shakeOffsetY = shakeOffsetY,
        lastDamageRatio = lastDamageRatio
    )

    companion object {
        const val FLASH_DURATION_SEC = 0.44f
        const val SHAKE_DURATION_SEC = 0.24f
    }
}
