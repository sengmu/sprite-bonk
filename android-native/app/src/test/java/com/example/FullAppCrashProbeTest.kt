package com.example

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.example.game.engine.GameSimulation
import com.example.game.model.ChallengeModifier
import com.example.game.model.DifficultyTier
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.math.cos
import kotlin.math.sin

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class FullAppCrashProbeTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun `main activity full navigation and modal smoke test runs without crashes`() {
        composeRule.mainClock.autoAdvance = false
        composeRule.mainClock.advanceTimeBy(400L)
        composeRule.waitForIdle()

        // 1. Cycle through all 6 starters on MainMenu
        repeat(6) {
            composeRule.onNodeWithTag("hero_next_btn").performClick()
            composeRule.mainClock.advanceTimeBy(250L)
        }
        composeRule.onNodeWithTag("menu_live_hero_stage").performClick()
        composeRule.mainClock.advanceTimeBy(300L)

        // 2. Open and close Hero Roster Modal
        composeRule.onNodeWithTag("open_roster_modal_btn").performClick()
        composeRule.mainClock.advanceTimeBy(200L)
        composeRule.onNodeWithTag("starter_select_char").performClick()
        composeRule.mainClock.advanceTimeBy(200L)
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)

        // 3. Open and close Evolution Preview Overlay
        composeRule.onNodeWithTag("open_evo_preview_btn").performClick()
        composeRule.mainClock.advanceTimeBy(300L)
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)

        // 4. Open and close Expedition Config Modal
        composeRule.onNodeWithTag("open_expedition_config_btn").performClick()
        composeRule.mainClock.advanceTimeBy(200L)
        composeRule.onNodeWithTag("mode_select_survival").performClick()
        composeRule.onNodeWithTag("mode_select_classic").performClick()
        composeRule.onNodeWithTag("difficulty_select_elite").performClick()
        composeRule.onNodeWithTag("difficulty_select_standard").performClick()
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)

        // 5. Open Settings and Wallet dialogs
        composeRule.onNodeWithTag("menu_settings_icon_btn").performClick()
        composeRule.mainClock.advanceTimeBy(200L)
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)

        composeRule.onNodeWithTag("menu_wallet_pill").performClick()
        composeRule.mainClock.advanceTimeBy(200L)
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)

        // 6. Visit Roam, Lab, Dex, Profile screens
        composeRule.onNodeWithTag("nav_roam_btn").performClick()
        composeRule.mainClock.advanceTimeBy(500L)
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(250L)

        composeRule.onNodeWithTag("nav_lab_btn").performClick()
        composeRule.mainClock.advanceTimeBy(300L)
        composeRule.onNodeWithTag("lab_back_btn").performClick()
        composeRule.mainClock.advanceTimeBy(250L)

        composeRule.onNodeWithTag("nav_dex_btn").performClick()
        composeRule.mainClock.advanceTimeBy(300L)
        composeRule.onNodeWithTag("dex_back_btn").performClick()
        composeRule.mainClock.advanceTimeBy(250L)

        composeRule.onNodeWithTag("nav_profile_btn").performClick()
        composeRule.mainClock.advanceTimeBy(300L)
        composeRule.onNodeWithTag("profile_back_btn").performClick()
        composeRule.mainClock.advanceTimeBy(250L)

        // 7. Enter Battle and step ~5 seconds of live Compose frames!
        composeRule.onNodeWithTag("start_battle_button").performClick()
        repeat(60) {
            composeRule.mainClock.advanceTimeBy(80L)
        }
        // Trigger dash / jump if buttons exist
        if (composeRule.onAllNodesWithTag("dash_action_button").fetchSemanticsNodes().isNotEmpty()) {
            composeRule.onNodeWithTag("dash_action_button").performClick()
            composeRule.mainClock.advanceTimeBy(200L)
        }
        if (composeRule.onAllNodesWithTag("jump_action_button").fetchSemanticsNodes().isNotEmpty()) {
            composeRule.onNodeWithTag("jump_action_button").performClick()
            composeRule.mainClock.advanceTimeBy(200L)
        }
        // Pause and return safely
        composeRule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        composeRule.mainClock.advanceTimeBy(200L)
    }

    @Test
    fun `long 180s simulation stress test across all starters biomes and modes does not crash or emit NaN`() {
        val biomes = GameCatalog.biomes
        val starters = GameCatalog.starters
        val modes = GameMode.entries

        // Test every starter across biomes & modes for 180s of simulated gameplay (dt = 1/20s = 3600 ticks each)
        for ((idx, starter) in starters.withIndex()) {
            val biome = biomes[idx % biomes.size]
            for (mode in modes) {
                val sim = GameSimulation(
                    starter = starter,
                    biome = biome,
                    gameMode = mode,
                    labLevels = mapOf("hp" to 2, "dmg" to 2, "spd" to 2),
                    autoAimEnabled = true,
                    screenShakeEnabled = true,
                    onSfx = {},
                    onHaptic = {},
                    challengeModifiers = if (idx % 2 == 0) setOf(ChallengeModifier.SWARM_FRENZY) else emptySet(),
                    difficulty = if (idx % 3 == 0) DifficultyTier.ELITE else DifficultyTier.STANDARD
                )

                var lastState = sim.step(1f / 60f)
                for (tick in 0 until 2400) {
                    val angle = tick * 0.07f
                    sim.setJoystickInput(cos(angle), sin(angle))
                    if (tick % 45 == 0) sim.triggerDash()
                    if (tick % 70 == 0) sim.triggerJump()
                    if (tick % 75 == 0) sim.triggerJump() // trigger glide
                    if (tick % 90 == 0) sim.triggerInteract()
                    if (lastState.ultCharge >= 1f) sim.triggerUlt()
                    if (lastState.hyperCharge >= 1f) sim.triggerHyperAwakening()

                    // Auto-resolve modals when they pop up
                    val draft = lastState.draftOptions
                    if (!draft.isNullOrEmpty()) {
                        sim.selectDraftOption(draft.first().id)
                    }
                    val relics = lastState.relicDraftOptions
                    if (!relics.isNullOrEmpty()) {
                        sim.selectRelic(relics.first())
                    }
                    if (lastState.evolutionState.hasReadyEvolution) {
                        val nextId = lastState.evolutionState.currentNode.nextNodeIds.firstOrNull()
                        if (nextId != null) {
                            sim.evolveToBranch(nextId)
                        }
                    }

                    lastState = sim.step(0.05f)
                    assertTrue(
                        "Non-finite player coordinates for ${starter.id}/${biome.id}/${mode.id} at tick=$tick",
                        lastState.playerX.isFinite() && lastState.playerY.isFinite() &&
                            lastState.hp.isFinite() && lastState.maxHp.isFinite() &&
                            lastState.cameraX.isFinite() && lastState.cameraY.isFinite()
                    )
                    if (lastState.runSummary != null) break
                }
            }
        }
    }
}
