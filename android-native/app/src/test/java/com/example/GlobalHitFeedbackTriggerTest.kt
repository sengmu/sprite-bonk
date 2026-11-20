package com.example

import com.example.game.engine.GlobalHitFeedbackTrigger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class GlobalHitFeedbackTriggerTest {

    @Test
    fun triggerHitActivatesRedEdgeFlashMicroShakeAndCallback() {
        var callbackCount = 0
        var lastIntensity = 0f
        val trigger = GlobalHitFeedbackTrigger { intensity ->
            callbackCount++
            lastIntensity = intensity
        }

        assertFalse(trigger.snapshot().isActive)

        trigger.triggerHit(damageAmount = 18f, maxHp = 100f, screenShakeEnabled = true)
        val onHit = trigger.snapshot()

        assertEquals(1L, onHit.hitEventId)
        assertEquals(1, callbackCount)
        assertTrue("Callback intensity should be > 0.6f", lastIntensity >= 0.65f)
        assertTrue("Edge flash intensity should activate immediately", onHit.edgeFlashIntensity >= 0.65f)
        assertTrue("Micro-shake X should activate immediately", abs(onHit.shakeOffsetX) > 0.5f)
        assertTrue(onHit.isActive)

        // Advance mid-way through flash: should stay active and animate
        repeat(8) { trigger.step(1f / 60f) }
        val mid = trigger.snapshot()
        assertTrue("Edge flash should still glow mid-window", mid.edgeFlashIntensity > 0.1f)

        // Advance past total duration: should cleanly decay to zero
        repeat(40) { trigger.step(1f / 60f) }
        val ended = trigger.snapshot()
        assertFalse("Hit feedback should decay completely after duration", ended.isActive)
        assertEquals(0f, ended.edgeFlashIntensity, 0.0001f)
        assertEquals(0f, ended.shakeOffsetX, 0.0001f)
        assertEquals(0f, ended.shakeOffsetY, 0.0001f)
    }

    @Test
    fun respectsDisabledScreenShakeWhileKeepingEdgeFlash() {
        val trigger = GlobalHitFeedbackTrigger()
        trigger.triggerHit(damageAmount = 22f, maxHp = 100f, screenShakeEnabled = false)

        val snap = trigger.snapshot()
        assertTrue(snap.edgeFlashIntensity > 0.6f)
        assertEquals(0f, snap.shakeOffsetX, 0.0001f)
        assertEquals(0f, snap.shakeOffsetY, 0.0001f)
    }
}
