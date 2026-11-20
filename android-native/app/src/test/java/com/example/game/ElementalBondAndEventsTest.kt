package com.example.game

import com.example.game.engine.GameSimulation
import com.example.game.engine.WorldPropKind
import com.example.game.model.ElementType
import com.example.game.model.ElementalBondId
import com.example.game.model.ElementalBondSystem
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.ui.screens.RoamHighGroundPlateau
import com.example.ui.screens.RoamJumpPhysics
import com.example.ui.screens.TrainingDummyState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ElementalBondAndEventsTest {

    private fun createSim(
        starterId: String = "char",
        biomeId: String = "forest",
        gameMode: GameMode = GameMode.CLASSIC
    ): GameSimulation = GameSimulation(
        starter = GameCatalog.starterById(starterId),
        biome = GameCatalog.biomeById(biomeId),
        gameMode = gameMode,
        labLevels = emptyMap(),
        autoAimEnabled = true,
        screenShakeEnabled = false,
        onSfx = {},
        onHaptic = {}
    )

    @Test
    fun elementalBondSystemEvaluatesAllFourBondsAndDraftHints() {
        val hydroVolt = ElementalBondSystem.evaluateActiveBonds(
            moveElements = listOf(ElementType.WATER, ElementType.ELECTRIC),
            moveLevels = listOf(1, 1),
            vitaminLevels = emptyMap(),
            awakenedCount = 0,
            fusedCount = 0
        )
        assertTrue("WATER + ELECTRIC activates HYDRO_VOLT", ElementalBondId.HYDRO_VOLT in hydroVolt)
        assertFalse(ElementalBondId.VERDANT_BLAZE in hydroVolt)

        val verdantBlazeAndSky = ElementalBondSystem.evaluateActiveBonds(
            moveElements = listOf(ElementType.GRASS, ElementType.FIRE, ElementType.WATER),
            moveLevels = listOf(3, 3, 1),
            vitaminLevels = mapOf("carbos" to 1),
            awakenedCount = 0,
            fusedCount = 0
        )
        assertTrue(ElementalBondId.VERDANT_BLAZE in verdantBlazeAndSky)
        assertTrue(ElementalBondId.SKYBREAKER in verdantBlazeAndSky)
        assertTrue("3 distinct elements activates ASTRAL_OVERLOAD", ElementalBondId.ASTRAL_OVERLOAD in verdantBlazeAndSky)

        val hint = ElementalBondSystem.bondUnlockHintForElement(
            currentElements = setOf(ElementType.WATER),
            candidateElement = ElementType.ELECTRIC
        )
        assertNotNull("Picking ELECTRIC when holding WATER should surface HYDRO_VOLT draft hint", hint)
    }

    @Test
    fun fusionMachineSupportsTierOneFusionAndTierTwoOverclock() {
        val sim = createSim(starterId = "char")
        var state = sim.step(0.016f)

        // First Fusion Machine -> Tier-I Fusion
        sim.spawnPropForTest(WorldPropKind.FUSION_MACHINE, state.playerX, state.playerY)
        state = sim.step(0.016f)
        sim.triggerInteract()
        state = sim.step(0.016f)
        assertEquals(1, state.fusedMoveCount)
        assertEquals(0, state.overclockedMoveCount)

        // Second Fusion Machine -> Tier-II Overclock Fusion
        sim.spawnPropForTest(WorldPropKind.FUSION_MACHINE, state.playerX, state.playerY)
        state = sim.step(0.016f)
        sim.triggerInteract()
        state = sim.step(0.016f)
        assertEquals(1, state.overclockedMoveCount)
        val overclockSlot = state.activeMoves.first()
        assertTrue(
            "Overclocked move should carry ✧超频 signature title (actual=${overclockSlot.nameZh})",
            overclockSlot.nameZh.startsWith("✧")
        )
    }

    @Test
    fun stardustMimicEventSpawnsFleeingTreasureEnemyAndBossAlertBannerTriggers() {
        val sim = createSim(starterId = "spark")
        sim.grantMoveForTest("water_gun", level = 2)
        var state = sim.step(0.016f)
        assertTrue("Spark + Water Gun must activate HYDRO_VOLT bond in live sim", ElementalBondId.HYDRO_VOLT in state.activeBonds)

        // Trigger Event Kind 3 -> Stardust Mimic
        sim.triggerDynamicEventForTest(kindOverride = 3)
        state = sim.step(0.016f)
        assertTrue(
            "Dynamic event 3 must spawn stardust_mimic enemy",
            state.enemies.any { it.defId == "stardust_mimic" }
        )

        // Spawn Guardian Boss and verify Boss Alert Banner fires
        sim.forceSpawnBossForTest()
        state = sim.step(0.016f)
        assertNotNull("Spawning Boss must surface bossAlertBannerText", state.bossAlertBannerText)
        assertNotNull("Boss health bar name must be populated", state.activeBossName)
    }

    @Test
    fun roamTrainingSandboxTracksDpsAndExecutesHighGroundDropSlam() {
        val dummy = TrainingDummyState()
        dummy.recordHit(damage = 120f, isCrit = false, nowSec = 1.0f, hitFromLeft = true)
        dummy.recordHit(damage = 240f, isCrit = true, nowSec = 1.5f, hitFromLeft = true)
        assertEquals(2, dummy.comboCount)
        assertEquals(240, dummy.peakHit)
        assertTrue("Live DPS should be positive after hits", dummy.liveDps > 0)

        dummy.reset()
        assertEquals(0, dummy.comboCount)
        assertEquals(0, dummy.peakHit)
        assertEquals(0, dummy.liveDps)

        val plateau = RoamHighGroundPlateau()
        val physics = RoamJumpPhysics()
        // Stand on High-Ground Plateau -> Jump -> Air Glide -> Drop Slam off edge
        physics.step(0.016f, plateau.x, plateau.y, plateau)
        assertTrue("Standing on plateau center must report high ground", physics.isOnHighGround)
        assertEquals(RoamJumpPhysics.JumpActionResult.JUMPED, physics.triggerJumpOrGlide())
        repeat(6) { physics.step(0.016f, plateau.x, plateau.y, plateau) }
        assertTrue("Sprite should be airborne after jump", physics.isJumping)
        assertEquals(RoamJumpPhysics.JumpActionResult.GLIDE_OPENED, physics.triggerJumpOrGlide())
        assertTrue("Second tap airborne must deploy Air Glide", physics.isGliding)
        assertEquals(RoamJumpPhysics.JumpActionResult.SLAM_TRIGGERED, physics.triggerJumpOrGlide())
        var landedDropHeight = 0f
        repeat(60) {
            val h = physics.step(0.016f, 0f, 0f, plateau)
            if (h > 0f) landedDropHeight = h
        }
        assertTrue("Canceling glide off high ground must land a Drop-Slam (dropHeight=$landedDropHeight)", landedDropHeight >= 34f)
    }
}
