package com.example.ui

import android.app.Application
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.MetaProgressionSnapshot
import com.example.data.SpriteBonkDatabase
import com.example.data.SpriteBonkRepository
import com.example.game.audio.SfxType
import com.example.game.audio.SoundEffectsManager
import com.example.game.engine.BattleRenderState
import com.example.game.engine.GameSimulation
import com.example.game.engine.RunSummary
import com.example.game.model.ChallengeModifier
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryCalculator
import com.example.wallet.SolanaAddress
import com.example.wallet.SolanaWalletRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class WalletSource(val label: String) {
    NONE("尚未连接"),
    SAVED("已保存地址"),
    AUTHORIZED("钱包已授权")
}

data class WalletUiState(
    val address: String = "",
    val source: WalletSource = WalletSource.NONE,
    val balanceSol: Double? = null,
    val isConnecting: Boolean = false,
    val isLoadingBalance: Boolean = false,
    val errorMessage: String? = null,
    val balanceError: String? = null
) {
    val isConnected: Boolean get() = address.isNotBlank()

    fun shortAddress(): String = if (address.length > 10) {
        "${address.take(4)}…${address.takeLast(4)}"
    } else {
        address
    }
}

enum class AppScreen {
    MENU,
    BATTLE,
    ROAM,
    LAB,
    DEX,
    PROFILE
}

class SpriteBonkViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SpriteBonkRepository(SpriteBonkDatabase.getInstance(application).dao())
    private val walletRepository = SolanaWalletRepository(application)
    private val sfx = SoundEffectsManager(application)
    private val initialWalletAddress = walletRepository.loadAddress().takeIf(SolanaAddress::isValid).orEmpty()

    private val _walletState = MutableStateFlow(WalletUiState(
        address = initialWalletAddress,
        source = if (initialWalletAddress.isEmpty()) WalletSource.NONE else WalletSource.SAVED
    ))
    val walletState: StateFlow<WalletUiState> = _walletState.asStateFlow()

    private var walletBalanceJob: kotlinx.coroutines.Job? = null

    val metaState: StateFlow<MetaProgressionSnapshot> = repository.metaSnapshot
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = MetaProgressionSnapshot()
        )

    private val _currentScreen = MutableStateFlow(AppScreen.MENU)
    val currentScreen: StateFlow<AppScreen> = _currentScreen.asStateFlow()

    private val _showSettingsDialog = MutableStateFlow(false)
    val showSettingsDialog: StateFlow<Boolean> = _showSettingsDialog.asStateFlow()

    private val _showMenuEvolutionPreview = MutableStateFlow(false)
    val showMenuEvolutionPreview: StateFlow<Boolean> = _showMenuEvolutionPreview.asStateFlow()

    private val _selectedChallengeModifiers = MutableStateFlow<Set<ChallengeModifier>>(emptySet())
    val selectedChallengeModifiers: StateFlow<Set<ChallengeModifier>> = _selectedChallengeModifiers.asStateFlow()

    // Throttled (~12.5Hz + immediate discrete events) state for Compose HUD & Modals
    private val _battleState = MutableStateFlow(BattleRenderState())
    val battleState: StateFlow<BattleRenderState> = _battleState.asStateFlow()

    // Full 60Hz draw-phase state read strictly inside Canvas / graphicsLayer blocks (zero recompositions)
    private val _battleRenderState = mutableStateOf(BattleRenderState())
    val battleRenderState: State<BattleRenderState> get() = _battleRenderState

    private var hudEmitAccumSec = 0f
    private var hudDirty = false
    private var lastHudState = BattleRenderState()

    private var activeSim: GameSimulation? = null
    private var runSettled = false

    init {
        viewModelScope.launch(Dispatchers.IO) {
            repository.ensureInitialized()
        }
        viewModelScope.launch {
            metaState.collect { snap ->
                sfx.enabled = snap.profile.sfxEnabled
                activeSim?.autoAimEnabled = snap.profile.autoAimEnabled
                activeSim?.screenShakeEnabled = snap.profile.screenShakeEnabled
            }
        }
        if (initialWalletAddress.isNotEmpty()) refreshWalletBalance()
    }

    fun beginWalletConnection() {
        _walletState.value = _walletState.value.copy(isConnecting = true, errorMessage = null)
    }

    fun walletConnectionFailed(reason: String) {
        _walletState.value = _walletState.value.copy(isConnecting = false, errorMessage = reason)
    }

    fun connectWalletAddress(address: String) {
        val normalizedAddress = address.trim()
        if (!SolanaAddress.isValid(normalizedAddress)) {
            _walletState.value = _walletState.value.copy(
                isConnecting = false,
                errorMessage = "地址无效，请检查后重试"
            )
            return
        }

        walletRepository.saveAddress(normalizedAddress)
        _walletState.value = WalletUiState(
            address = normalizedAddress,
            source = WalletSource.AUTHORIZED,
            isLoadingBalance = true
        )
        refreshWalletBalance()
    }

    fun disconnectWallet() {
        walletBalanceJob?.cancel()
        walletRepository.clearAddress()
        _walletState.value = WalletUiState()
    }

    fun refreshWalletBalance() {
        val address = _walletState.value.address
        if (address.isBlank()) return

        walletBalanceJob?.cancel()
        _walletState.value = _walletState.value.copy(
            isLoadingBalance = true,
            balanceError = null
        )
        walletBalanceJob = viewModelScope.launch {
            try {
                val balance = walletRepository.fetchMainnetBalance(address)
                if (_walletState.value.address == address) {
                    _walletState.value = _walletState.value.copy(
                        balanceSol = balance,
                        isLoadingBalance = false,
                        balanceError = null
                    )
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                if (_walletState.value.address == address) {
                    _walletState.value = _walletState.value.copy(
                        isLoadingBalance = false,
                        balanceError = error.message?.takeIf(String::isNotBlank) ?: "网络请求失败"
                    )
                }
            }
        }
    }

    fun navigateTo(screen: AppScreen) {
        sfx.play(SfxType.PANEL, 0.55f)
        if (screen != AppScreen.BATTLE) {
            stopBattleLoop()
        }
        _currentScreen.value = screen
    }

    fun openSettings() {
        sfx.play(SfxType.PANEL, 0.55f)
        _showSettingsDialog.value = true
    }

    fun closeSettings() {
        _showSettingsDialog.value = false
    }

    fun openMenuEvolutionPreview() {
        sfx.play(SfxType.PANEL, 0.55f)
        _showMenuEvolutionPreview.value = true
    }

    fun closeMenuEvolutionPreview() {
        _showMenuEvolutionPreview.value = false
    }

    fun selectStarter(starterId: String) {
        sfx.play(SfxType.PANEL, 0.5f)
        viewModelScope.launch { repository.selectStarter(starterId) }
    }

    fun selectBiome(biomeId: String) {
        if (!metaState.value.isBiomeUnlocked(biomeId)) return
        sfx.play(SfxType.PANEL, 0.5f)
        viewModelScope.launch { repository.selectBiome(biomeId) }
    }

    fun selectGameMode(mode: GameMode) {
        sfx.play(SfxType.PANEL, 0.5f)
        viewModelScope.launch { repository.selectGameMode(mode.id) }
    }

    fun toggleChallengeModifier(modifier: ChallengeModifier) {
        val current = _selectedChallengeModifiers.value
        val armed = modifier !in current
        _selectedChallengeModifiers.value = if (armed) current + modifier else current - modifier
        sfx.play(SfxType.PANEL, 0.55f, pitch = if (armed) 1.14f else 0.90f)
    }

    fun updateSettings(
        sfxEnabled: Boolean? = null,
        vibrationEnabled: Boolean? = null,
        screenShakeEnabled: Boolean? = null,
        autoAimEnabled: Boolean? = null
    ) {
        viewModelScope.launch {
            repository.updateSettings(sfxEnabled, vibrationEnabled, screenShakeEnabled, autoAimEnabled)
        }
    }

    fun buyLabUpgrade(upgradeId: String) {
        viewModelScope.launch {
            val ok = repository.purchaseLabUpgrade(upgradeId)
            if (ok) {
                sfx.play(SfxType.LEVEL_UP, 0.68f)
                pulseHaptic()
            }
        }
    }

    fun refundLab() {
        viewModelScope.launch {
            val refunded = repository.refundAllLabUpgrades()
            if (refunded > 0) {
                sfx.play(SfxType.CHEST, 0.65f)
            }
        }
    }

    fun resetAllData() {
        viewModelScope.launch {
            repository.resetAllProgress()
            _showSettingsDialog.value = false
            sfx.play(SfxType.PANEL, 0.6f)
        }
    }

    fun startNewRun() {
        stopBattleLoop()
        val snap = metaState.value
        val starter = GameCatalog.starterById(snap.profile.selectedStarterId)
        val biome = GameCatalog.biomeById(snap.profile.selectedBiomeId)
        val mode = GameMode.fromId(snap.profile.selectedGameMode)
        runSettled = false
        hudEmitAccumSec = 0f
        hudDirty = false

        val masteryBonuses = MetaMasteryCalculator.compute(snap)
        val selectedChallenges = _selectedChallengeModifiers.value

        val sim = GameSimulation(
            starter = starter,
            biome = biome,
            gameMode = mode,
            labLevels = snap.labLevels,
            autoAimEnabled = snap.profile.autoAimEnabled,
            screenShakeEnabled = snap.profile.screenShakeEnabled,
            onSfx = { type -> sfx.play(type) },
            onHaptic = { pulseHaptic() },
            onHitHaptic = { intensity -> pulseHitHaptic(intensity) },
            masteryBonuses = masteryBonuses,
            challengeModifiers = selectedChallenges,
            onSfxPitch = { type, pitch -> sfx.play(type, pitch = pitch) }
        )
        activeSim = sim
        val initialState = sim.step(1f / 60f)
        _battleRenderState.value = initialState
        _battleState.value = initialState
        lastHudState = initialState
        _currentScreen.value = AppScreen.BATTLE
    }

    /**
     * Driven directly by Compose VSYNC [ComposeGameLoop] (`withFrameNanos`) inside [BattleScreen].
     * Updates the 60Hz draw-phase state every frame while throttling HUD recompositions to ~12.5Hz
     * plus immediate synchronization on any discrete gameplay or modal transition.
     */
    fun stepBattleFrame(dt: Float) {
        val sim = activeSim ?: return
        val state = sim.step(dt)
        _battleRenderState.value = state

        hudEmitAccumSec += dt
        if (hudDirty || hudEmitAccumSec >= HUD_EMIT_INTERVAL_SEC || shouldEmitHudImmediately(lastHudState, state)) {
            hudEmitAccumSec = 0f
            hudDirty = false
            lastHudState = state
            _battleState.value = state
        }

        if (state.runSummary != null && !runSettled) {
            runSettled = true
            settleSummary(sim, state.runSummary)
        }
    }

    private fun shouldEmitHudImmediately(prev: BattleRenderState, next: BattleRenderState): Boolean {
        if (prev.hp.toInt() != next.hp.toInt() || prev.maxHp.toInt() != next.maxHp.toInt()) return true
        if (prev.level != next.level || prev.kills != next.kills || prev.coins != next.coins || prev.chestsOpened != next.chestsOpened) return true
        if (prev.dangerTier != next.dangerTier || prev.isOnHighGround != next.isOnHighGround || prev.isJumping != next.isJumping || prev.isGliding != next.isGliding) return true
        if (prev.fusedMoveCount != next.fusedMoveCount || prev.overclockedMoveCount != next.overclockedMoveCount || prev.bossPortalEarlyBonusPct != next.bossPortalEarlyBonusPct) return true
        if (prev.comboCount != next.comboCount || prev.evolutionStage != next.evolutionStage || prev.revivesRemaining != next.revivesRemaining) return true
        if (prev.activeBossName != next.activeBossName || prev.activeBossPhase != next.activeBossPhase || prev.activeBossStaggered != next.activeBossStaggered) return true
        if (prev.bossAlertBannerText != next.bossAlertBannerText || prev.activeBonds.size != next.activeBonds.size) return true
        if (prev.activeEcoBuffZh != next.activeEcoBuffZh) return true
        if (prev.nearbyPropId != next.nearbyPropId || prev.nearbyInteractKind != next.nearbyInteractKind) return true
        if (prev.evolutionBannerText != next.evolutionBannerText || prev.activeWaveEventTitleZh != next.activeWaveEventTitleZh) return true
        if ((prev.biomeBannerTimer > 0f) != (next.biomeBannerTimer > 0f)) return true
        if (prev.isPaused != next.isPaused || prev.isEvolutionModalOpen != next.isEvolutionModalOpen) return true
        if ((prev.draftOptions == null) != (next.draftOptions == null) || prev.banishModeArmed != next.banishModeArmed) return true
        if ((prev.runSummary == null) != (next.runSummary == null)) return true
        if (prev.activeSynergyCount != next.activeSynergyCount || prev.nearSynergyHintZh != next.nearSynergyHintZh) return true
        if (prev.activeMoves.size != next.activeMoves.size || prev.activeVitamins.size != next.activeVitamins.size) return true
        if ((prev.ultCharge >= 1f) != (next.ultCharge >= 1f) || (prev.ultActiveTimer > 0f) != (next.ultActiveTimer > 0f)) return true
        if ((prev.hyperCharge >= 1f) != (next.hyperCharge >= 1f) || (prev.hyperActiveTimer > 0f) != (next.hyperActiveTimer > 0f)) return true
        if ((prev.dashCooldownRatio <= 0.01f) != (next.dashCooldownRatio <= 0.01f)) return true
        if ((prev.jumpCooldownRatio <= 0.01f) != (next.jumpCooldownRatio <= 0.01f)) return true
        if (prev.evolutionState.hasReadyEvolution != next.evolutionState.hasReadyEvolution) return true
        if (prev.hitFeedback.isActive != next.hitFeedback.isActive) return true
        return false
    }

    private fun settleSummary(sim: GameSimulation, summary: RunSummary) {
        viewModelScope.launch {
            repository.settleRun(
                starterId = summary.starterId,
                biomeId = summary.biomeId,
                victory = summary.victory,
                survivalSec = summary.survivalSec,
                kills = summary.kills,
                finalLevel = summary.finalLevel,
                stardustEarned = summary.stardustEarned,
                seenCounts = sim.seenEnemyCounts.toMap(),
                defeatedCounts = sim.defeatedEnemyCounts.toMap()
            )
        }
    }

    fun setJoystick(dx: Float, dy: Float) {
        activeSim?.setJoystickInput(dx, dy)
    }

    fun setKeyboardMovement(dx: Float, dy: Float) {
        activeSim?.setKeyboardInput(dx, dy)
    }

    fun onDashPressed() {
        activeSim?.triggerDash()
        hudDirty = true
    }

    fun onJumpPressed() {
        activeSim?.triggerJump()
        hudDirty = true
    }

    fun onUltPressed() {
        activeSim?.triggerUlt()
        hudDirty = true
    }

    fun onHyperAwakenPressed() {
        activeSim?.triggerHyperAwakening()
        hudDirty = true
    }

    fun onInteractPressed() {
        activeSim?.triggerInteract()
        hudDirty = true
    }

    fun onTogglePause() {
        activeSim?.togglePause()
        hudDirty = true
    }

    fun onResumeBattle() {
        activeSim?.resume()
        hudDirty = true
    }

    fun onSelectDraft(optionId: String) {
        val evolved = activeSim?.selectDraftOption(optionId)
        hudDirty = true
        if (evolved != null) {
            viewModelScope.launch { repository.unlockEvolution(evolved.id) }
        }
    }

    fun onRerollDraft() {
        activeSim?.rerollDraft()
        hudDirty = true
    }

    fun onSkipDraft() {
        activeSim?.skipDraft()
        hudDirty = true
    }

    fun onToggleBanish() {
        activeSim?.toggleBanishMode()
        hudDirty = true
    }

    fun onOpenBattleEvolution() {
        activeSim?.openEvolutionModal()
        hudDirty = true
    }

    fun onCloseBattleEvolution() {
        activeSim?.closeEvolutionModal()
        hudDirty = true
    }

    fun onEvolveTo(nodeId: String) {
        val evolved = activeSim?.evolveToBranch(nodeId)
        hudDirty = true
        if (evolved != null) {
            viewModelScope.launch { repository.unlockEvolution(evolved.id) }
        }
    }

    fun onAbandonRun() {
        val sim = activeSim ?: return
        val summary = sim.abandonRun()
        if (!runSettled) {
            runSettled = true
            settleSummary(sim, summary)
        }
        val finalState = sim.step(0.016f)
        _battleRenderState.value = finalState
        _battleState.value = finalState
        lastHudState = finalState
        hudDirty = false
    }

    fun exitBattleToMenu() {
        stopBattleLoop()
        _currentScreen.value = AppScreen.MENU
    }

    private fun stopBattleLoop() {
        activeSim = null
    }

    companion object {
        private const val HUD_EMIT_INTERVAL_SEC = 0.08f // ~12.5Hz smooth HUD refresh
    }

    @Suppress("DEPRECATION")
    private fun pulseHaptic() {
        vibrateOneShot(durationMs = 18L, amplitude = VibrationEffect.DEFAULT_AMPLITUDE)
    }

    @Suppress("DEPRECATION")
    private fun pulseHitHaptic(intensity: Float) {
        val durationMs = (24L + (intensity.coerceIn(0f, 1f) * 18f).toLong())
        val amplitude = (75 + (intensity.coerceIn(0f, 1f) * 85f).toInt()).coerceIn(60, 170)
        vibrateOneShot(durationMs = durationMs, amplitude = amplitude)
    }

    @Suppress("DEPRECATION")
    private fun vibrateOneShot(durationMs: Long, amplitude: Int) {
        if (!metaState.value.profile.vibrationEnabled) return
        val ctx = getApplication<Application>()
        runCatching {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
            } else {
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val resolvedAmp = if (vibrator?.hasAmplitudeControl() == true) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
                vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, resolvedAmp))
            } else {
                vibrator?.vibrate(durationMs)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopBattleLoop()
        sfx.release()
    }
}
