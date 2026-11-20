package com.example.game

import androidx.compose.ui.graphics.Color
import com.example.game.engine.DraftOptionKind
import com.example.game.engine.GameSimulation
import com.example.game.engine.ParticleShape
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.ui.components.blendHurtTint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HeroStateFeedbackTest {

    @Test
    fun `blendHurtTint returns base color at rest, flashes bright on fresh impact, and shifts crimson on recovery`() {
        val base = Color(0xFF2E8B57)
        assertEquals(base, blendHurtTint(base, 0f))

        val freshFlash = blendHurtTint(base, 0.95f)
        assertTrue("Fresh impact flash should be bright white-peach", freshFlash.red > 0.92f && freshFlash.green > 0.70f)

        val crimsonRecovery = blendHurtTint(base, 0.45f)
        assertTrue("Recovery frames should tint noticeably toward crimson", crimsonRecovery.red > base.red + 0.25f)
    }

    @Test
    fun `evolving all six starters triggers evolutionFxTimer and species-themed rings and particles`() {
        val expectations = listOf(
            "stump" to ParticleShape.LEAF,
            "char" to ParticleShape.SPARK,
            "shell" to ParticleShape.RING_POP,
            "spark" to ParticleShape.SPARK,
            "wisp" to ParticleShape.DOT,
            "drake" to ParticleShape.RING_POP
        )

        for ((starterId, expectedShape) in expectations) {
            val sim = GameSimulation(
                starter = GameCatalog.starterById(starterId),
                biome = GameCatalog.biomeById("forest"),
                gameMode = GameMode.CLASSIC,
                labLevels = emptyMap(),
                autoAimEnabled = true,
                screenShakeEnabled = false,
                onSfx = {},
                onHaptic = {}
            )

            var evolvedConfirmed = false
            // Advance levels until the guaranteed Tier-1 EVOLUTION_FORM draft card appears and select it
            for (stepIdx in 0 until 8) {
                val snap = sim.step(0f)
                sim.grantXpForTest(snap.xpToNext + 1f)
                val draftSnap = sim.step(0.05f)
                val options = draftSnap.draftOptions ?: emptyList()
                val evoOption = options.firstOrNull { it.optionKind == DraftOptionKind.EVOLUTION_FORM }
                if (evoOption != null) {
                    val evolvedNode = sim.selectDraftOption(evoOption.id)
                    assertTrue("$starterId evolution option should succeed", evolvedNode != null)
                    val evoSnap = sim.step(0f)
                    assertTrue("$starterId should activate evolutionFxTimer", evoSnap.evolutionFxTimer > 1.2f)
                    assertTrue("$starterId should spawn multi-wave evolution rings", evoSnap.rings.size >= 2)
                    assertTrue(
                        "$starterId should emit species-themed evolution particles ($expectedShape)",
                        evoSnap.particles.any { it.shape == expectedShape }
                    )

                    // Step past 1.5s and verify evolutionFxTimer decays cleanly back to 0
                    repeat(32) { sim.step(0.05f) }
                    val settled = sim.step(0.05f)
                    assertEquals("$starterId evolutionFxTimer should decay cleanly to 0", 0f, settled.evolutionFxTimer, 0.001f)
                    evolvedConfirmed = true
                    break
                } else {
                    options.firstOrNull()?.let { sim.selectDraftOption(it.id) }
                    repeat(15) { sim.step(0.05f) }
                }
            }

            assertTrue("$starterId must have reached and triggered Tier-1 evolution FX", evolvedConfirmed)
        }
    }
}
