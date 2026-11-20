package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.unit.dp
import com.example.game.engine.BattleRenderState
import com.example.game.movement.ComposeGameLoop
import com.example.ui.components.BattleCanvas
import com.example.ui.components.BattleHudOverlay
import com.example.ui.components.EvolutionTreeOverlay
import com.example.ui.components.GlobalHitEdgeFlashOverlay
import com.example.ui.components.LevelUpDraftModal
import com.example.ui.components.PauseModal
import com.example.ui.components.RunSettlementOverlay

@Composable
fun BattleScreen(
    state: BattleRenderState,
    renderStateProvider: () -> BattleRenderState,
    unlockedEvolutionIds: Set<String>,
    autoAimEnabled: Boolean,
    sfxEnabled: Boolean,
    screenShakeEnabled: Boolean,
    onStepFrame: (Float) -> Unit,
    onJoystickChange: (Float, Float) -> Unit,
    onKeyboardChange: (Float, Float) -> Unit,
    onDashClick: () -> Unit,
    onJumpClick: () -> Unit,
    onUltClick: () -> Unit,
    onHyperAwakenClick: () -> Unit,
    onInteractClick: () -> Unit,
    onOpenEvolution: () -> Unit,
    onCloseEvolution: () -> Unit,
    onEvolveTo: (String) -> Unit,
    onTogglePause: () -> Unit,
    onResume: () -> Unit,
    onToggleAutoAim: (Boolean) -> Unit,
    onToggleSfx: (Boolean) -> Unit,
    onToggleScreenShake: (Boolean) -> Unit,
    onSelectDraft: (String) -> Unit,
    onRerollDraft: () -> Unit,
    onSkipDraft: () -> Unit,
    onToggleBanish: () -> Unit,
    onAbandonRun: () -> Unit,
    onPlayAgain: () -> Unit,
    onExitToMenu: () -> Unit
) {
    // VSYNC-synchronized Compose main game loop (`withFrameNanos`)
    ComposeGameLoop(active = state.runSummary == null || state.hitFeedback.isActive) { dt, _ ->
        onStepFrame(dt)
    }

    val pressedKeys = remember { mutableSetOf<Key>() }
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { focusRequester.requestFocus() }
    }

    fun syncKeyboard() {
        var kx = 0f
        var ky = 0f
        if (Key.A in pressedKeys || Key.DirectionLeft in pressedKeys) kx -= 1f
        if (Key.D in pressedKeys || Key.DirectionRight in pressedKeys) kx += 1f
        if (Key.W in pressedKeys || Key.DirectionUp in pressedKeys) ky -= 1f
        if (Key.S in pressedKeys || Key.DirectionDown in pressedKeys) ky += 1f
        onKeyboardChange(kx, ky)
    }

    BackHandler {
        when {
            state.runSummary != null -> onExitToMenu()
            state.isEvolutionModalOpen -> onCloseEvolution()
            state.draftOptions != null -> Unit
            state.isPaused -> onResume()
            else -> onTogglePause()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .focusRequester(focusRequester)
            .focusable()
            .onPreviewKeyEvent { event ->
                val isDown = event.type == KeyEventType.KeyDown
                val isUp = event.type == KeyEventType.KeyUp
                when (event.key) {
                    Key.W, Key.A, Key.S, Key.D,
                    Key.DirectionUp, Key.DirectionDown, Key.DirectionLeft, Key.DirectionRight -> {
                        if (isDown) pressedKeys.add(event.key)
                        if (isUp) pressedKeys.remove(event.key)
                        syncKeyboard()
                        true
                    }
                    Key.Spacebar -> {
                        if (isDown) onJumpClick()
                        true
                    }
                    Key.ShiftLeft, Key.ShiftRight -> {
                        if (isDown) onDashClick()
                        true
                    }
                    else -> false
                }
            }
    ) {
        BattleCanvas(
            stateProvider = renderStateProvider,
            modifier = Modifier.graphicsLayer {
                val rs = renderStateProvider()
                val z = rs.cameraZoom
                scaleX = z
                scaleY = z
                translationX = rs.hitFeedback.shakeOffsetX.dp.toPx()
                translationY = rs.hitFeedback.shakeOffsetY.dp.toPx()
            }
        )

        BattleHudOverlay(
            state = state,
            renderStateProvider = renderStateProvider,
            onJoystickChange = onJoystickChange,
            onDashClick = onDashClick,
            onJumpClick = onJumpClick,
            onUltClick = onUltClick,
            onHyperAwakenClick = onHyperAwakenClick,
            onInteractClick = onInteractClick,
            onOpenEvolution = onOpenEvolution,
            onPauseClick = onTogglePause
        )

        GlobalHitEdgeFlashOverlay(hitFeedbackProvider = { renderStateProvider().hitFeedback })

        if (state.isEvolutionModalOpen && state.runSummary == null) {
            EvolutionTreeOverlay(
                starterId = state.starterId,
                inBattle = true,
                playerLevel = state.level,
                evoSnapshot = state.evolutionState,
                unlockedEvolutionIds = unlockedEvolutionIds,
                onEvolveTo = onEvolveTo,
                onDismiss = onCloseEvolution
            )
        }

        val draft = state.draftOptions
        if (draft != null && state.runSummary == null && !state.isEvolutionModalOpen) {
            LevelUpDraftModal(
                level = state.level,
                options = draft,
                activeBonds = state.activeBonds,
                rerollsLeft = state.rerollsLeft,
                skipsLeft = state.skipsLeft,
                banishesLeft = state.banishesLeft,
                banishModeArmed = state.banishModeArmed,
                onSelect = onSelectDraft,
                onReroll = onRerollDraft,
                onSkip = onSkipDraft,
                onToggleBanish = onToggleBanish
            )
        }

        if (state.isPaused && state.runSummary == null && draft == null && !state.isEvolutionModalOpen) {
            PauseModal(
                buildStats = state.buildStats,
                activeBonds = state.activeBonds,
                autoAimEnabled = autoAimEnabled,
                sfxEnabled = sfxEnabled,
                screenShakeEnabled = screenShakeEnabled,
                onToggleAutoAim = onToggleAutoAim,
                onToggleSfx = onToggleSfx,
                onToggleScreenShake = onToggleScreenShake,
                onResume = onResume,
                onAbandon = onAbandonRun
            )
        }

        val summary = state.runSummary
        if (summary != null) {
            RunSettlementOverlay(
                summary = summary,
                onPlayAgain = onPlayAgain,
                onGoHome = onExitToMenu
            )
        }
    }
}
