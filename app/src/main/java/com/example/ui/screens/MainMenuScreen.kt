package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Explore
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.MetaProgressionSnapshot
import com.example.game.engine.ElementalMatchup
import com.example.game.model.ChallengeModifier
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryCalculator
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

/**
 * Iconic, Zero-Scroll Game Lobby with Progressive Disclosure:
 * - Main Canvas shows ONLY 3 crystal-clear layers:
 *   1) Floating Top HUD Bar (Emblem left | Stardust + Settings right)
 *   2) Open-Air Hero Centerpiece (large animated sprite + quick ‹/› cycling + Nameplate with 编队/进化)
 *   3) Focused Launch Hub (1-tap Expedition Summary Card + Heroic Play CTA) & clean 4-Pill Utility Dock
 * - Deep configuration (6-Sprite Roster Details, Mode/Biome/Challenge Picker) opens in spacious
 *   1-tap modals ([HeroRosterModal], [ExpeditionConfigModal]) with zero home-screen clutter.
 */
@Composable
fun MainMenuScreen(
    meta: MetaProgressionSnapshot,
    selectedChallengeModifiers: Set<ChallengeModifier> = emptySet(),
    onSelectStarter: (String) -> Unit,
    onSelectBiome: (String) -> Unit,
    onSelectGameMode: (GameMode) -> Unit,
    onToggleChallengeModifier: (ChallengeModifier) -> Unit = {},
    onOpenEvolutionPreview: () -> Unit,
    onOpenRoam: () -> Unit,
    onStartRun: () -> Unit,
    onOpenLab: () -> Unit,
    onOpenDex: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenSettings: () -> Unit,
    walletLabel: String = "钱包",
    onOpenWallet: () -> Unit = {}
) {
    val selectedStarter = GameCatalog.starterById(meta.profile.selectedStarterId)
    val selectedBiome = GameCatalog.biomeById(meta.profile.selectedBiomeId)
    val selectedMode = GameMode.fromId(meta.profile.selectedGameMode)

    var showRosterModal by remember { mutableStateOf(false) }
    var showExpeditionModal by remember { mutableStateOf(false) }

    val unlockedEvolutionIds = remember(meta.profile.unlockedEvolutionIds) {
        meta.unlockedEvolutionSet()
    }
    val masteryBonuses = remember(meta) {
        MetaMasteryCalculator.compute(meta)
    }
    val masteryChips = remember(masteryBonuses) {
        masteryBonuses.summaryChips()
    }
    val challengeDustBonus = remember(selectedChallengeModifiers) {
        MetaMasteryCalculator.combinedChallengeStardustBonusPct(selectedChallengeModifiers)
    }
    val hasAffordableLabUpgrade = remember(meta.profile.stardust, meta.labLevels) {
        GameCatalog.labUpgrades.any { def ->
            val lv = meta.labLevels[def.id] ?: 0
            lv < def.maxLevel && meta.profile.stardust >= def.costForNext(lv)
        }
    }
    val matchupMult = remember(selectedStarter.id, selectedBiome.id) {
        val boss = GameCatalog.enemies[selectedBiome.bossId]
        if (boss != null) ElementalMatchup.multiplier(selectedStarter.element, boss.element) else 1.0f
    }

    val cycleStarter: (Int) -> Unit = { delta ->
        val list = GameCatalog.starters
        val curIdx = list.indexOfFirst { it.id == selectedStarter.id }.coerceAtLeast(0)
        val nextIdx = (curIdx + delta + list.size) % list.size
        onSelectStarter(list[nextIdx].id)
    }

    val ctaLabel = buildString {
        append("开始冒险")
        if (selectedMode == GameMode.DUEL) append(" · 1v1决斗")
        else if (selectedMode == GameMode.SURVIVAL) append(" · 无尽模式")
        if (challengeDustBonus > 0) append(" (+$challengeDustBonus%星尘)")
    }

    Box(modifier = Modifier.fillMaxSize()) {
        BiomeAtmosphereBackdrop(biome = selectedBiome)

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            val isLandscape = (maxWidth > maxHeight && maxWidth >= 560.dp) || (maxHeight < 460.dp && maxWidth >= 560.dp)
            val isCompactH = maxHeight < 430.dp
            val isCompactPortrait = !isLandscape && maxHeight < 700.dp

            if (isLandscape) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .widthIn(max = 1040.dp)
                        .align(Alignment.Center),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    LobbyTopBar(
                        stardust = meta.profile.stardust,
                        hasAffordableLabUpgrade = hasAffordableLabUpgrade,
                        compact = isCompactH,
                        onOpenLab = onOpenLab,
                        onOpenSettings = onOpenSettings,
                        walletLabel = walletLabel,
                        onOpenWallet = onOpenWallet
                    )

                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(top = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(18.dp),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        // Left 56%: Full-height Open-Air Hero Pedestal + Floating Nameplate
                        Box(
                            modifier = Modifier
                                .weight(1.16f)
                                .fillMaxHeight(),
                            contentAlignment = Alignment.BottomCenter
                        ) {
                            MinimalHeroShowcaseStage(
                                selected = selectedStarter,
                                unlockedEvolutionIds = unlockedEvolutionIds,
                                isLandscape = true,
                                compact = isCompactH,
                                onCyclePrev = { cycleStarter(-1) },
                                onCycleNext = { cycleStarter(+1) },
                                onOpenRosterModal = { showRosterModal = true },
                                onOpenEvolutionPreview = onOpenEvolutionPreview,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .fillMaxHeight()
                            )
                        }

                        // Right 44%: Bottom-Anchored Command Hub (Open scenic sky above!)
                        Column(
                            modifier = Modifier
                                .weight(0.94f)
                                .widthIn(max = 420.dp),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 7.dp else 10.dp)
                        ) {
                            ExpeditionSummaryCard(
                                biome = selectedBiome,
                                mode = selectedMode,
                                matchupMult = matchupMult,
                                challengeCount = selectedChallengeModifiers.size,
                                challengeDustBonusPct = challengeDustBonus,
                                onOpenConfig = { showExpeditionModal = true }
                            )

                            ChunkyButton(
                                text = ctaLabel,
                                onClick = onStartRun,
                                tone = ChunkyButtonTone.GREEN,
                                icon = Icons.Rounded.PlayArrow,
                                shimmer = true,
                                height = if (isCompactH) 48.dp else 54.dp,
                                testTag = "start_battle_button",
                                modifier = Modifier.fillMaxWidth()
                            )

                            LobbyUtilityNavDock(
                                hasAffordableLabUpgrade = hasAffordableLabUpgrade,
                                compact = isCompactH,
                                onOpenRoam = onOpenRoam,
                                onOpenLab = onOpenLab,
                                onOpenDex = onOpenDex,
                                onOpenProfile = onOpenProfile
                            )
                        }
                    }
                }
            } else {
                // Portrait Zero-Scroll Game Lobby
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .widthIn(max = 520.dp)
                        .align(Alignment.Center),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    LobbyTopBar(
                        stardust = meta.profile.stardust,
                        hasAffordableLabUpgrade = hasAffordableLabUpgrade,
                        compact = isCompactPortrait,
                        onOpenLab = onOpenLab,
                        onOpenSettings = onOpenSettings,
                        walletLabel = walletLabel,
                        onOpenWallet = onOpenWallet
                    )

                    // Centerpiece Open-Air Hero Stage (breathes generously in the open sky!)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        MinimalHeroShowcaseStage(
                            selected = selectedStarter,
                            unlockedEvolutionIds = unlockedEvolutionIds,
                            isLandscape = false,
                            compact = isCompactPortrait,
                            onCyclePrev = { cycleStarter(-1) },
                            onCycleNext = { cycleStarter(+1) },
                            onOpenRosterModal = { showRosterModal = true },
                            onOpenEvolutionPreview = onOpenEvolutionPreview,
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 210.dp, max = 360.dp)
                        )
                    }

                    // Bottom Focused Launch Hub + Utility Nav Dock
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(if (isCompactPortrait) 8.dp else 10.dp)
                    ) {
                        ExpeditionSummaryCard(
                            biome = selectedBiome,
                            mode = selectedMode,
                            matchupMult = matchupMult,
                            challengeCount = selectedChallengeModifiers.size,
                            challengeDustBonusPct = challengeDustBonus,
                            onOpenConfig = { showExpeditionModal = true }
                        )

                        ChunkyButton(
                            text = ctaLabel,
                            onClick = onStartRun,
                            tone = ChunkyButtonTone.GREEN,
                            icon = Icons.Rounded.PlayArrow,
                            shimmer = true,
                            height = if (isCompactPortrait) 52.dp else 56.dp,
                            testTag = "start_battle_button",
                            modifier = Modifier.fillMaxWidth()
                        )

                        LobbyUtilityNavDock(
                            hasAffordableLabUpgrade = hasAffordableLabUpgrade,
                            compact = isCompactPortrait,
                            onOpenRoam = onOpenRoam,
                            onOpenLab = onOpenLab,
                            onOpenDex = onOpenDex,
                            onOpenProfile = onOpenProfile
                        )
                    }
                }
            }
        }

        // Progressive Disclosure Modals (1-Tap Spacious Configuration)
        if (showRosterModal) {
            HeroRosterModal(
                selected = selectedStarter,
                onSelect = onSelectStarter,
                onOpenEvolutionPreview = onOpenEvolutionPreview,
                onDismiss = { showRosterModal = false }
            )
        }

        if (showExpeditionModal) {
            ExpeditionConfigModal(
                meta = meta,
                selectedStarter = selectedStarter,
                selectedMode = selectedMode,
                selectedBiomeId = selectedBiome.id,
                selectedChallengeModifiers = selectedChallengeModifiers,
                masteryChips = masteryChips,
                onSelectMode = onSelectGameMode,
                onSelectBiome = onSelectBiome,
                onToggleChallengeModifier = onToggleChallengeModifier,
                onStartRun = onStartRun,
                onDismiss = { showExpeditionModal = false }
            )
        }
    }
}

@Composable
private fun LobbyTopBar(
    stardust: Int,
    hasAffordableLabUpgrade: Boolean,
    compact: Boolean,
    onOpenLab: () -> Unit,
    onOpenSettings: () -> Unit,
    walletLabel: String,
    onOpenWallet: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        BrandLogoEmblem(compact = compact)

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box {
                Row(
                    modifier = Modifier
                        .testTag("menu_stardust_pill")
                        .minimumInteractiveComponentSize()
                        .clip(RoundedCornerShape(50))
                        .background(HudInkDark.copy(alpha = 0.78f))
                        .border(1.4.dp, GoldAccent.copy(alpha = 0.75f), RoundedCornerShape(50))
                        .clickable(onClick = onOpenLab)
                        .padding(horizontal = if (compact) 10.dp else 13.dp, vertical = if (compact) 6.dp else 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.AutoAwesome,
                        contentDescription = "星尘",
                        tint = GoldAccent,
                        modifier = Modifier.size(if (compact) 15.dp else 17.dp)
                    )
                    Text(
                        text = if (compact) "$stardust" else "$stardust 星尘",
                        style = MaterialTheme.typography.titleSmall.copy(
                            fontSize = if (compact) 12.5.sp else 13.5.sp,
                            fontWeight = FontWeight.ExtraBold
                        ),
                        color = Color.White,
                        maxLines = 1
                    )
                }
                if (hasAffordableLabUpgrade) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(WarmOrange)
                            .border(1.5.dp, CreamSurface, CircleShape)
                    )
                }
            }

            Row(
                modifier = Modifier
                    .testTag("menu_wallet_pill")
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(50))
                    .background(HudInkDark.copy(alpha = 0.78f))
                    .border(1.4.dp, SkyBlue.copy(alpha = 0.72f), RoundedCornerShape(50))
                    .clickable(onClick = onOpenWallet)
                    .padding(horizontal = if (compact) 9.dp else 12.dp, vertical = if (compact) 6.dp else 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Icon(
                    imageVector = Icons.Rounded.AccountBalanceWallet,
                    contentDescription = "钱包",
                    tint = SkyBlue,
                    modifier = Modifier.size(if (compact) 15.dp else 17.dp)
                )
                Text(
                    text = walletLabel,
                    style = MaterialTheme.typography.titleSmall.copy(
                        fontSize = if (compact) 11.5.sp else 13.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Color.White,
                    maxLines = 1
                )
            }

            Box(
                modifier = Modifier
                    .testTag("menu_settings_icon_btn")
                    .minimumInteractiveComponentSize()
                    .size(if (compact) 40.dp else 44.dp)
                    .clip(CircleShape)
                    .background(HudInkDark.copy(alpha = 0.78f))
                    .border(1.4.dp, Color.White.copy(alpha = 0.24f), CircleShape)
                    .clickable(onClick = onOpenSettings),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.Settings,
                    contentDescription = "设置",
                    tint = CreamSurface,
                    modifier = Modifier.size(if (compact) 19.dp else 21.dp)
                )
            }
        }
    }
}

@Composable
private fun BrandLogoEmblem(compact: Boolean) {
    val shape = RoundedCornerShape(if (compact) 13.dp else 16.dp)
    Row(
        modifier = Modifier
            .shadow(6.dp, shape)
            .clip(shape)
            .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent)))
            .border(2.dp, DarkButtonRim, shape)
            .padding(horizontal = if (compact) 11.dp else 14.dp, vertical = if (compact) 5.dp else 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Text(
            text = "SPRITE BONK",
            style = MaterialTheme.typography.titleLarge.copy(
                fontSize = if (compact) 15.sp else 18.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 0.6.sp
            ),
            color = EspressoDark,
            maxLines = 1
        )
        if (!compact) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(EspressoDark.copy(alpha = 0.14f))
                    .padding(horizontal = 7.dp, vertical = 2.dp)
            ) {
                Text(
                    text = "精灵肉鸽",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold),
                    color = EspressoDark
                )
            }
        }
    }
}

@Composable
private fun LobbyUtilityNavDock(
    hasAffordableLabUpgrade: Boolean,
    compact: Boolean,
    onOpenRoam: () -> Unit,
    onOpenLab: () -> Unit,
    onOpenDex: () -> Unit,
    onOpenProfile: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HudInkDark.copy(alpha = 0.78f))
            .border(1.2.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(16.dp))
            .padding(horizontal = 6.dp, vertical = if (compact) 4.dp else 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        LobbyNavPill("漫游", Icons.Rounded.Explore, GrassGreen, "nav_roam_btn", false, compact, onOpenRoam, Modifier.weight(1f))
        LobbyNavPill("实验室", Icons.Rounded.Science, EpicPurple, "nav_lab_btn", hasAffordableLabUpgrade, compact, onOpenLab, Modifier.weight(1f))
        LobbyNavPill("图鉴", Icons.Rounded.AutoStories, SkyBlue, "nav_dex_btn", false, compact, onOpenDex, Modifier.weight(1f))
        LobbyNavPill("档案", Icons.Rounded.EmojiEvents, WarmOrange, "nav_profile_btn", false, compact, onOpenProfile, Modifier.weight(1f))
    }
}

@Composable
private fun LobbyNavPill(
    label: String,
    icon: ImageVector,
    badgeColor: Color,
    tag: String,
    showAlertDot: Boolean,
    compact: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .testTag(tag)
            .minimumInteractiveComponentSize()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = if (compact) 4.dp else 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box {
            Box(
                modifier = Modifier
                    .size(if (compact) 22.dp else 26.dp)
                    .clip(CircleShape)
                    .background(badgeColor),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = label,
                    tint = Color.White,
                    modifier = Modifier.size(if (compact) 13.dp else 15.dp)
                )
            }
            if (showAlertDot) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(WarmOrange)
                        .border(1.2.dp, CreamSurface, CircleShape)
                )
            }
        }
        Spacer(Modifier.size(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium.copy(
                fontSize = if (compact) 10.sp else 11.sp,
                fontWeight = FontWeight.Bold
            ),
            color = CreamSurface,
            maxLines = 1
        )
    }
}
