package com.example.game

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.example.game.model.ChallengeModifier
import com.example.ui.AppScreen
import com.example.ui.SpriteBonkViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class BattleHudSyncRobolectricTest {

    @Test
    fun `challenge modifier toggles arm and disarm cleanly before launching a run`() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val vm = SpriteBonkViewModel(app)

        assertTrue(vm.selectedChallengeModifiers.value.isEmpty())

        vm.toggleChallengeModifier(ChallengeModifier.SWARM_FRENZY)
        vm.toggleChallengeModifier(ChallengeModifier.GLASS_CANNON)
        assertEquals(
            setOf(ChallengeModifier.SWARM_FRENZY, ChallengeModifier.GLASS_CANNON),
            vm.selectedChallengeModifiers.value
        )

        vm.toggleChallengeModifier(ChallengeModifier.SWARM_FRENZY)
        assertEquals(setOf(ChallengeModifier.GLASS_CANNON), vm.selectedChallengeModifiers.value)

        vm.startNewRun()
        assertEquals(AppScreen.BATTLE, vm.currentScreen.value)
        assertEquals(1, vm.battleState.value.activeChallengeCount)
        assertEquals(ChallengeModifier.GLASS_CANNON.stardustBonusPct, vm.battleState.value.challengeStardustBonusPct)
    }

    @Test
    fun `60Hz render state advances every frame while throttled hud syncs immediately on discrete actions`() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val vm = SpriteBonkViewModel(app)

        vm.startNewRun()
        val initialHudTime = vm.battleState.value.elapsedSec

        // Step 1 single 60Hz frame (16.6ms < 80ms HUD throttle window)
        vm.stepBattleFrame(1f / 60f)
        val afterOneFrameRender = vm.battleRenderState.value
        val afterOneFrameHud = vm.battleState.value

        assertTrue(
            "60Hz draw-phase render state should advance every frame",
            afterOneFrameRender.elapsedSec > initialHudTime
        )
        assertEquals(
            "Throttled HUD state should skip redundant intermediate frame when no discrete event happened",
            initialHudTime,
            afterOneFrameHud.elapsedSec,
            0.0001f
        )

        // Discrete action: Jump marks hudDirty and must flush immediately on the very next frame
        vm.onJumpPressed()
        vm.stepBattleFrame(1f / 60f)
        assertTrue(
            "Discrete Jump action should immediately flush HUD state",
            vm.battleState.value.isJumping
        )

        // Discrete action: Pause flushes immediately
        vm.onTogglePause()
        vm.stepBattleFrame(1f / 60f)
        assertTrue("Pause should immediately synchronize to HUD", vm.battleState.value.isPaused)

        // Resume flushes immediately
        vm.onResumeBattle()
        vm.stepBattleFrame(1f / 60f)
        assertFalse("Resume should immediately synchronize to HUD", vm.battleState.value.isPaused)

        vm.exitBattleToMenu()
        assertEquals(AppScreen.MENU, vm.currentScreen.value)
    }
}
