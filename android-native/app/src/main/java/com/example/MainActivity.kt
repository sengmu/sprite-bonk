package com.example

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ui.AppScreen
import com.example.ui.SpriteBonkViewModel
import com.example.ui.WalletSource
import com.example.ui.components.EvolutionTreeOverlay
import com.example.ui.screens.BattleScreen
import com.example.ui.screens.DexScreen
import com.example.ui.screens.LabScreen
import com.example.ui.screens.MainMenuScreen
import com.example.ui.screens.ProfileScreen
import com.example.ui.screens.SettingsDialogModal
import com.example.ui.screens.SpriteRoamScreen
import com.example.ui.screens.WalletDialog
import com.example.ui.theme.SpriteBonkTheme
import com.example.wallet.SolanaAddress
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private lateinit var walletAdapter: MobileWalletAdapter
    private lateinit var walletActivityResultSender: ActivityResultSender

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        walletAdapter = MobileWalletAdapter(
            connectionIdentity = ConnectionIdentity(
                identityUri = Uri.parse("https://github.com/sengmu/sprite-bonk"),
                iconUri = Uri.parse("icon.png"),
                identityName = "Sprite Bonk"
            )
        ).apply {
            blockchain = Solana.Mainnet
        }
        // Register the MWA activity-result launcher before the Activity reaches STARTED.
        walletActivityResultSender = ActivityResultSender(this)
        enableEdgeToEdge()
        setContent {
            SpriteBonkTheme {
                SpriteBonkApp(walletAdapter, walletActivityResultSender)
            }
        }
    }
}

@Composable
fun SpriteBonkApp(
    walletAdapter: MobileWalletAdapter,
    walletActivityResultSender: ActivityResultSender,
    viewModel: SpriteBonkViewModel = viewModel()
) {
    val meta by viewModel.metaState.collectAsStateWithLifecycle()
    val currentScreen by viewModel.currentScreen.collectAsStateWithLifecycle()
    val showSettings by viewModel.showSettingsDialog.collectAsStateWithLifecycle()
    val showMenuEvoPreview by viewModel.showMenuEvolutionPreview.collectAsStateWithLifecycle()
    val selectedChallenges by viewModel.selectedChallengeModifiers.collectAsStateWithLifecycle()
    val selectedDifficulty by viewModel.selectedDifficulty.collectAsStateWithLifecycle()
    val walletState by viewModel.walletState.collectAsStateWithLifecycle()
    val cosmeticLoadout by viewModel.cosmeticLoadout.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var showWalletDialog by remember { mutableStateOf(false) }

    val connectWallet: () -> Unit = {
        viewModel.beginWalletConnection()
        coroutineScope.launch {
            try {
                when (val result = walletAdapter.connect(walletActivityResultSender)) {
                    is TransactionResult.Success -> {
                        val publicKey = result.authResult.accounts.firstOrNull()?.publicKey
                        if (publicKey == null || publicKey.size != 32) {
                            viewModel.walletConnectionFailed("钱包没有返回有效的 Solana 地址")
                        } else {
                            viewModel.connectWalletAddress(SolanaAddress.encode(publicKey))
                        }
                    }
                    is TransactionResult.NoWalletFound -> {
                        viewModel.walletConnectionFailed("未找到兼容的钱包")
                    }
                    is TransactionResult.Failure -> {
                        viewModel.walletConnectionFailed("授权未完成：${result.message}")
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                viewModel.walletConnectionFailed("钱包连接失败：${error.message ?: "请重试"}")
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        when (currentScreen) {
            AppScreen.MENU -> MainMenuScreen(
                meta = meta,
                selectedChallengeModifiers = selectedChallenges,
                selectedDifficulty = selectedDifficulty,
                onSelectStarter = viewModel::selectStarter,
                onSelectBiome = viewModel::selectBiome,
                onSelectGameMode = viewModel::selectGameMode,
                onToggleChallengeModifier = viewModel::toggleChallengeModifier,
                onSelectDifficulty = viewModel::selectDifficulty,
                onOpenEvolutionPreview = viewModel::openMenuEvolutionPreview,
                onOpenRoam = { viewModel.navigateTo(AppScreen.ROAM) },
                onStartRun = viewModel::startNewRun,
                onOpenLab = { viewModel.navigateTo(AppScreen.LAB) },
                onOpenDex = { viewModel.navigateTo(AppScreen.DEX) },
                onOpenProfile = { viewModel.navigateTo(AppScreen.PROFILE) },
                onOpenSettings = viewModel::openSettings,
                walletLabel = if (walletState.isConnected) walletState.shortAddress() else "连接钱包",
                onOpenWallet = { showWalletDialog = true },
                shopEntry = {
                    com.example.wallet.DevnetShopEntry(
                        sender = walletActivityResultSender,
                        biomeId = meta.profile.selectedBiomeId,
                        stardust = meta.profile.stardust,
                        totalVictories = meta.profile.totalVictories,
                        cosmeticLoadout = cosmeticLoadout,
                        onPurchaseStardustItem = viewModel::purchaseOrUnlockCosmetic,
                        onToggleEquipLocal = viewModel::toggleEquipCosmetic
                    )
                }
            )

            AppScreen.ROAM -> SpriteRoamScreen(
                initialStarterId = meta.profile.selectedStarterId,
                biomeId = meta.profile.selectedBiomeId,
                onSelectStarterPersist = viewModel::selectStarter,
                onBack = { viewModel.navigateTo(AppScreen.MENU) }
            )

            AppScreen.BATTLE -> BattleScreenHost(
                viewModel = viewModel,
                unlockedEvolutionIds = meta.unlockedEvolutionSet(),
                autoAimEnabled = meta.profile.autoAimEnabled,
                sfxEnabled = meta.profile.sfxEnabled,
                screenShakeEnabled = meta.profile.screenShakeEnabled
            )

            AppScreen.LAB -> LabScreen(
                meta = meta,
                onBuyUpgrade = viewModel::buyLabUpgrade,
                onRefundAll = viewModel::refundLab,
                onBack = { viewModel.navigateTo(AppScreen.MENU) }
            )

            AppScreen.DEX -> DexScreen(
                meta = meta,
                onBack = { viewModel.navigateTo(AppScreen.MENU) }
            )

            AppScreen.PROFILE -> ProfileScreen(
                meta = meta,
                onBack = { viewModel.navigateTo(AppScreen.MENU) }
            )
        }

        if (showMenuEvoPreview && currentScreen == AppScreen.MENU) {
            EvolutionTreeOverlay(
                starterId = meta.profile.selectedStarterId,
                inBattle = false,
                playerLevel = 1,
                evoSnapshot = null,
                unlockedEvolutionIds = meta.unlockedEvolutionSet(),
                onEvolveTo = null,
                onDismiss = viewModel::closeMenuEvolutionPreview
            )
        }

        if (showSettings) {
            SettingsDialogModal(
                meta = meta,
                onUpdateSettings = viewModel::updateSettings,
                onResetProgress = viewModel::resetAllData,
                onDismiss = viewModel::closeSettings
            )
        }

        if (showWalletDialog) {
            WalletDialog(
                state = walletState,
                onConnect = connectWallet,
                onDisconnect = {
                    if (walletState.source != WalletSource.AUTHORIZED) {
                        viewModel.disconnectWallet()
                    } else {
                        viewModel.beginWalletConnection()
                        coroutineScope.launch {
                            try {
                                when (walletAdapter.disconnect(walletActivityResultSender)) {
                                    is TransactionResult.Success -> viewModel.disconnectWallet()
                                    else -> viewModel.walletConnectionFailed("未能撤销钱包授权，请重试")
                                }
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (_: Exception) {
                                viewModel.walletConnectionFailed("未能撤销钱包授权，请重试")
                            }
                        }
                    }
                },
                onCopyAddress = { address ->
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("Solana wallet address", address))
                    Toast.makeText(context, "地址已复制", Toast.LENGTH_SHORT).show()
                },
                onRetryBalance = viewModel::refreshWalletBalance,
                onDismiss = { showWalletDialog = false }
            )
        }
    }
}

@Composable
private fun BattleScreenHost(
    viewModel: SpriteBonkViewModel,
    unlockedEvolutionIds: Set<String>,
    autoAimEnabled: Boolean,
    sfxEnabled: Boolean,
    screenShakeEnabled: Boolean
) {
    val battleState by viewModel.battleState.collectAsStateWithLifecycle()
    val renderStateProvider = androidx.compose.runtime.remember(viewModel) {
        { viewModel.battleRenderState.value }
    }

    BattleScreen(
        state = battleState,
        renderStateProvider = renderStateProvider,
        unlockedEvolutionIds = unlockedEvolutionIds,
        autoAimEnabled = autoAimEnabled,
        sfxEnabled = sfxEnabled,
        screenShakeEnabled = screenShakeEnabled,
        onStepFrame = viewModel::stepBattleFrame,
        onJoystickChange = viewModel::setJoystick,
        onKeyboardChange = viewModel::setKeyboardMovement,
        onDashClick = viewModel::onDashPressed,
        onJumpClick = viewModel::onJumpPressed,
        onUltClick = viewModel::onUltPressed,
        onHyperAwakenClick = viewModel::onHyperAwakenPressed,
        onInteractClick = viewModel::onInteractPressed,
        onOpenEvolution = viewModel::onOpenBattleEvolution,
        onCloseEvolution = viewModel::onCloseBattleEvolution,
        onEvolveTo = viewModel::onEvolveTo,
        onTogglePause = viewModel::onTogglePause,
        onResume = viewModel::onResumeBattle,
        onToggleAutoAim = { viewModel.updateSettings(autoAimEnabled = it) },
        onToggleSfx = { viewModel.updateSettings(sfxEnabled = it) },
        onToggleScreenShake = { viewModel.updateSettings(screenShakeEnabled = it) },
        onSelectDraft = viewModel::onSelectDraft,
        onRerollDraft = viewModel::onRerollDraft,
        onSkipDraft = viewModel::onSkipDraft,
        onToggleBanish = viewModel::onToggleBanish,
        onSelectRelic = viewModel::onSelectRelic,
        onAbandonRun = viewModel::onAbandonRun,
        onPlayAgain = viewModel::startNewRun,
        onExitToMenu = viewModel::exitBattleToMenu
    )
}
