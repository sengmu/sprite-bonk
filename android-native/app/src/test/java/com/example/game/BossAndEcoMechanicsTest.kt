package com.example.game

import com.example.game.engine.BiomeEcoRules
import com.example.game.engine.BiomeEcoZone
import com.example.game.engine.BiomeZoneKind
import com.example.game.engine.BiomeZonePhase
import com.example.game.engine.GameSimulation
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BossAndEcoMechanicsTest {

    private fun newSim(starterId: String, biomeId: String): GameSimulation = GameSimulation(
        starter = GameCatalog.starterById(starterId),
        biome = GameCatalog.biomeById(biomeId),
        gameMode = GameMode.CLASSIC,
        labLevels = emptyMap(),
        autoAimEnabled = true,
        screenShakeEnabled = true,
        onSfx = {},
        onHaptic = {}
    )

    @Test
    fun `boss transitions cleanly through phase 1, phase 2, and phase 3 as hp drops`() {
        val sim = newSim("stump", "forest")

        sim.forceSpawnBossForTest()
        // Advance past the 36ms Boss arrival dramatic hitstop
        repeat(4) { sim.step(1f / 60f) }
        val p1 = sim.step(1f / 60f)
        assertNotNull("Boss should be active", p1.activeBossName)
        assertEquals("Fresh boss starts in Phase 1", 1, p1.activeBossPhase)

        // Drop boss HP below 75% threshold -> Phase 2 (also triggers micro-hitstop + zoom pulse)
        val maxHp = p1.enemies.first { it.isBoss }.maxHp
        sim.damageBossForTest(maxHp * 0.30f)
        val p2 = sim.step(1f / 60f)
        assertEquals("Boss below 75% HP should enter Phase 2", 2, p2.activeBossPhase)
        assertTrue("Phase 2 transition should trigger camera zoom tension", p2.cameraZoom > 1.0f)

        // Advance past the 36ms Phase 2 hitstop freeze frame before testing Phase 3 transition
        repeat(4) { sim.step(1f / 60f) }

        // Drop boss HP below 48% threshold -> Phase 3
        sim.damageBossForTest(maxHp * 0.30f)
        val p3 = sim.step(1f / 60f)
        assertEquals("Boss below 48% HP should enter Phase 3", 3, p3.activeBossPhase)
        assertTrue("Phase 3 transition should maintain camera zoom tension", p3.cameraZoom > 1.0f)
    }

    @Test
    fun `volcano lava vent cycles deterministically through dormant, warning, and erupting`() {
        val vent = BiomeEcoZone(
            id = 1,
            kind = BiomeZoneKind.VOLCANO_LAVA_VENT,
            x = 0f,
            y = 0f,
            radius = 102f,
            cycleOffsetSec = 0f
        )

        val (phaseDormant, _) = BiomeEcoRules.evaluatePhase(vent, elapsedSec = 1.0f)
        assertEquals(BiomeZonePhase.DORMANT, phaseDormant)

        val (phaseWarning, _) = BiomeEcoRules.evaluatePhase(
            vent,
            elapsedSec = BiomeEcoRules.VOLCANO_DORMANT_SEC + 0.5f
        )
        assertEquals(BiomeZonePhase.WARNING, phaseWarning)

        val (phaseErupting, _) = BiomeEcoRules.evaluatePhase(
            vent,
            elapsedSec = BiomeEcoRules.VOLCANO_DORMANT_SEC + BiomeEcoRules.VOLCANO_WARNING_SEC + 0.5f
        )
        assertEquals(BiomeZonePhase.ERUPTING, phaseErupting)
    }

    @Test
    fun `forest bloom ring activates eco buff and graveyard lantern accelerates ult charge`() {
        // 1. Forest Bloom Ring
        val forestSim = newSim("stump", "forest")
        val forestZone = forestSim.getTerrainLayoutForTest().ecoZones.first()
        forestSim.teleportPlayerForTest(forestZone.x, forestZone.y)
        val forestState = forestSim.step(0.05f)
        assertNotNull("Standing inside Forest Bloom Ring should show eco buff", forestState.activeEcoBuffZh)
        assertTrue(forestState.activeEcoBuffZh!!.contains("风花灵阵"))

        // 2. Graveyard Soul Lantern accelerates ult charge
        val graveSim = newSim("wisp", "graveyard")
        val lantern = graveSim.getTerrainLayoutForTest().ecoZones.first()
        graveSim.teleportPlayerForTest(lantern.x, lantern.y)
        val ultBefore = graveSim.step(1f / 60f).ultCharge
        var lastState = graveSim.step(0.05f)
        repeat(20) {
            lastState = graveSim.step(0.05f)
        }
        assertNotNull("Standing inside Soul Lantern should show eco buff", lastState.activeEcoBuffZh)
        assertTrue(lastState.activeEcoBuffZh!!.contains("幽魂灯柱"))
        assertTrue(
            "Soul Lantern should passively charge Ult gauge (before=$ultBefore, after=${lastState.ultCharge})",
            lastState.ultCharge > ultBefore + 0.03f
        )
    }

    @Test
    fun `desert quicksand applies slow buff when grounded and clears when jumping`() {
        val desertSim = newSim("spark", "desert")
        val quicksand = desertSim.getTerrainLayoutForTest().ecoZones.first()
        desertSim.teleportPlayerForTest(quicksand.x, quicksand.y)

        val groundedState = desertSim.step(0.05f)
        assertNotNull("Grounded player inside quicksand should see pull warning", groundedState.activeEcoBuffZh)
        assertTrue(groundedState.activeEcoBuffZh!!.contains("流沙"))

        // Trigger jump -> rising above quicksand altitude clears the grounded pull buff
        desertSim.triggerJump()
        var airborneState = desertSim.step(0.05f)
        repeat(4) {
            airborneState = desertSim.step(0.03f)
        }
        assertTrue("Player should be airborne after jump", airborneState.playerZ > 16f)
        assertNull("Airborne player should escape quicksand pull", airborneState.activeEcoBuffZh)
    }
}
