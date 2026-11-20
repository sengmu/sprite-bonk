package com.example.game

import com.example.game.engine.GameSimulation
import com.example.game.engine.WorldPropKind
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PokebonkAlignmentMechanicsTest {

    private fun createSim(
        starterId: String = "char",
        biomeId: String = "forest",
        gameMode: GameMode = GameMode.CLASSIC,
        labLevels: Map<String, Int> = emptyMap()
    ): GameSimulation = GameSimulation(
        starter = GameCatalog.starterById(starterId),
        biome = GameCatalog.biomeById(biomeId),
        gameMode = gameMode,
        labLevels = labLevels,
        autoAimEnabled = true,
        screenShakeEnabled = false,
        onSfx = {},
        onHaptic = {}
    )

    @Test
    fun airGlideDeploysMidAirAndThirdTapCancelsIntoDropSlam() {
        val sim = createSim()
        sim.step(0.016f)

        // 1. Grounded jump launch
        sim.triggerJump()
        var state = sim.step(0.016f)
        repeat(8) { state = sim.step(0.016f) }
        assertTrue("Sprite should be airborne after jump", state.isJumping)
        assertFalse("Should not be gliding before second tap", state.isGliding)

        // 2. Second tap airborne activates Air Glide
        sim.triggerJump()
        state = sim.step(0.016f)
        assertTrue("Second jump tap while airborne must activate Air Glide", state.isGliding)

        // Step through apex into cushioned glide descent
        repeat(15) { state = sim.step(0.016f) }
        assertTrue("Sprite should stay gliding smoothly mid-air", state.isGliding)
        val zBeforeDrop = state.playerZ

        // 3. Third tap cancels glide into fast Drop Slam dive
        sim.triggerJump()
        state = sim.step(0.016f)
        assertFalse("Third tap while gliding must cancel glide into Drop Slam", state.isGliding)
        val zAfterCancelFrame = state.playerZ
        assertTrue(
            "Canceling glide into Drop Slam must descend rapidly (before=$zBeforeDrop, after=$zAfterCancelFrame)",
            zAfterCancelFrame < zBeforeDrop - 5f
        )
    }

    @Test
    fun bossPortalEarlySummonSpawnsBossOpensDraftAndAddsStardustBonus() {
        val baseline = createSim()
        baseline.addKillsForTest(60)
        val baselineDust = baseline.abandonRun().stardustEarned

        val portalSim = createSim()
        var state = portalSim.step(0.016f)
        portalSim.spawnPropForTest(WorldPropKind.BOSS_PORTAL, state.playerX, state.playerY)
        state = portalSim.step(0.016f)
        assertEquals(WorldPropKind.BOSS_PORTAL, state.nearbyInteractKind)

        portalSim.triggerInteract()
        state = portalSim.step(0.016f)
        assertEquals("Early Boss Portal activation grants +20% Stardust bonus", 20, state.bossPortalEarlyBonusPct)
        assertNotNull("Early Boss Portal activation immediately spawns Guardian Boss", state.activeBossName)
        assertNotNull("Early Boss Portal activation grants an immediate tactical Draft", state.draftOptions)

        // Resolve draft and verify Stardust multiplier applies
        val firstPick = state.draftOptions!!.first().id
        portalSim.selectDraftOption(firstPick)
        portalSim.addKillsForTest(60)
        val portalDust = portalSim.abandonRun().stardustEarned
        assertTrue(
            "Early Boss Portal +20% Stardust bonus should increase total Stardust (base=$baselineDust, portal=$portalDust)",
            portalDust > baselineDust
        )
    }

    @Test
    fun fusionMachineOverclocksActiveMoveIntoFusedSignatureTitle() {
        val sim = createSim(starterId = "char")
        var state = sim.step(0.016f)
        val initialLevel = state.activeMoves.first().level

        sim.spawnPropForTest(WorldPropKind.FUSION_MACHINE, state.playerX, state.playerY)
        state = sim.step(0.016f)
        assertEquals(WorldPropKind.FUSION_MACHINE, state.nearbyInteractKind)

        sim.triggerInteract()
        state = sim.step(0.016f)
        assertEquals("Fusion machine should increment fusedMoveCount", 1, state.fusedMoveCount)
        val fusedSlot = state.activeMoves.first()
        assertTrue("Fused move should display signature ✦ title (actual=${fusedSlot.nameZh})", fusedSlot.nameZh.startsWith("✦"))
        assertTrue("Fused move must be marked awakened", fusedSlot.awakened)
        assertEquals("Fusing a move should also boost its level by +1", initialLevel + 1, fusedSlot.level)
    }

    @Test
    fun labSlotExpansionAndVitaminAmplifierScaleBuildCapacityAndStats() {
        val baseSim = createSim(labLevels = emptyMap())
        val upgradedSim = createSim(labLevels = mapOf("move_slot" to 1, "vit_amp" to 2))

        assertEquals(4, baseSim.step(0.016f).maxMoveSlots)
        assertEquals(5, upgradedSim.step(0.016f).maxMoveSlots)

        // Grant same Vitamin ('protein') to both and compare amplified damagePct
        baseSim.grantSynergySetupForTest(moveId = "ember_shot", vitaminId = "protein")
        upgradedSim.grantSynergySetupForTest(moveId = "ember_shot", vitaminId = "protein")
        val baseDmgPct = baseSim.step(0.016f).buildStats.damagePct
        val ampDmgPct = upgradedSim.step(0.016f).buildStats.damagePct
        assertTrue(
            "Lab vit_amp Lv.2 (+24% vitamin power) must increase damagePct from Protein (base=$baseDmgPct, amp=$ampDmgPct)",
            ampDmgPct > baseDmgPct
        )
    }

    @Test
    fun guardianDuelModeStartsAtLevel4WithTwoOpeningDraftsThenSpawnsBoss() {
        val duelSim = createSim(gameMode = GameMode.DUEL)
        var state = duelSim.step(0.016f)

        assertEquals(GameMode.DUEL, state.gameMode)
        assertEquals("Duel Mode starts at Lv.4", 4, state.level)
        assertNotNull("Duel Mode opens first opening Draft immediately", state.draftOptions)
        assertNull("Boss waits until opening build drafts finish", state.activeBossName)

        // Pick Draft 1 -> Draft 2 opens immediately
        duelSim.selectDraftOption(state.draftOptions!!.first().id)
        state = duelSim.step(0.016f)
        assertNotNull("Duel Mode must present second opening Draft right after first", state.draftOptions)
        assertNull("Boss still waits for second opening Draft", state.activeBossName)

        // Pick Draft 2 -> Draft closes and Guardian Boss spawns immediately
        duelSim.selectDraftOption(state.draftOptions!!.first().id)
        // Step past spawn hitstop
        repeat(6) { state = duelSim.step(0.016f) }
        assertNull("Draft modal should be closed after 2 opening picks", state.draftOptions)
        assertNotNull("Guardian Boss must spawn immediately after opening drafts in Duel Mode", state.activeBossName)
        val escortCount = state.enemies.count { !it.isBoss }
        assertTrue("Duel Mode keeps trash escorts minimal (actual=$escortCount)", escortCount <= 4)
    }
}
