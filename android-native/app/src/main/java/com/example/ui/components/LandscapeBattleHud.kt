package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.constraintlayout.compose.ConstraintLayout
import androidx.constraintlayout.compose.Dimension
import com.example.game.engine.BattleRenderState
import com.example.game.evolution.EvolutionResourceType
import com.example.game.model.BiomeDef
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.StarterLine
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonDeep
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DangerTierColors
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

/**
 * Responsive Landscape Battle HUD built with Compose [Box] + [ConstraintLayout].
 *
 * Layout anchors:
 * - **Top-Left**: Hero Portrait + Player HP Bar + Experience Bar (+ slim Hyper strip & Evolution pill)
 * - **Top-Center**: Centered Match Clock / Pause / Danger Tier + single-priority non-blocking banner slot
 * - **Top-Right**: Current Level Badge + Ultimate Cooldown/Charge Readout + Radar Minimap (+ compact Telemetry/Objectives)
 * - **Bottom-Center**: Strictly horizontally centered Skill Bar inside a cohesive glass dock
 * - **Bottom-Right**: Responsive Action Arc (Dash, Jump, Ult, Contextual Interact)
 */
@Composable
fun LandscapeBattleHud(
    state: BattleRenderState,
    renderStateProvider: () -> BattleRenderState = { state },
    starter: StarterLine,
    biome: BiomeDef,
    maxWidth: Dp,
    maxHeight: Dp,
    animatedHpFrac: Float,
    animatedXpFrac: Float,
    animatedHyperFrac: Float,
    targetHpFrac: Float,
    interactPulse: Float,
    objectiveDrawerOpen: Boolean,
    onToggleObjectiveDrawer: () -> Unit,
    inspectedMoveId: String?,
    onInspectMove: (String?) -> Unit,
    onDashClick: () -> Unit,
    onJumpClick: () -> Unit,
    onUltClick: () -> Unit,
    onHyperAwakenClick: () -> Unit,
    onInteractClick: () -> Unit,
    onOpenEvolution: () -> Unit,
    onPauseClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isCompactH = maxHeight < 410.dp
    val isCompactW = maxWidth < 740.dp
    val isWide = maxWidth >= 860.dp

    val edgePadH = when {
        isWide -> 18.dp
        isCompactW -> 10.dp
        else -> 14.dp
    }
    val edgePadV = if (isCompactH) 4.dp else 8.dp

    val avatarSize = if (isCompactH) 38.dp else 44.dp
    val minimapSize = when {
        isCompactW -> 46.dp
        isCompactH -> 48.dp
        else -> 56.dp
    }
    val actionArcSize = when {
        isCompactH -> 132.dp
        isWide -> 156.dp
        else -> 144.dp
    }
    val ultSize = when {
        isCompactH -> 62.dp
        isWide -> 74.dp
        else -> 68.dp
    }
    val dashSize = if (isCompactH) 48.dp else 54.dp
    val jumpSize = if (isCompactH) 46.dp else 50.dp
    val interactSize = if (isCompactH) 46.dp else 52.dp

    // Responsive bottom-center skill slot sizing: guarantees zero overlap with bottom-right Action Arc
    val slotCount = state.maxMoveSlots.coerceAtLeast(1)
    val skillSpacing = if (isWide) 8.dp else 5.dp
    val availableCenterW = (maxWidth - actionArcSize * 2 - edgePadH * 2 - 40.dp).coerceAtLeast(168.dp)
    val maxSlotFromWidth = (availableCenterW - skillSpacing * (slotCount - 1) - 16.dp) / slotCount
    val skillSlotSize = maxSlotFromWidth.coerceIn(38.dp, if (isCompactH) 44.dp else 52.dp)

    val evoReady = state.evolutionState.hasReadyEvolution
    val curNode = state.evolutionState.currentNode
    val hyperActive = state.hyperActiveTimer > 0f
    val hyperReady = state.hyperCharge >= 1f && !hyperActive
    val totalRes = EvolutionResourceType.entries.sumOf { state.evolutionState.resources[it] ?: 0 }
    val doneCount = state.objectives.count { it.completed }
    val mins = (state.elapsedSec / 60).toInt()
    val secs = (state.elapsedSec % 60).toInt()
    val dangerIdx = state.dangerTier.coerceIn(0, DangerTierColors.lastIndex)
    val dangerColor = DangerTierColors[dangerIdx]
    val dangerText = when (state.gameMode) {
        GameMode.SURVIVAL -> if (state.survivalWave > 1) "无尽·第${state.survivalWave}波" else "无尽·${GameCatalog.dangerNames[dangerIdx]}"
        GameMode.DUEL -> "决斗·${GameCatalog.dangerNames[dangerIdx]}"
        GameMode.CLASSIC -> GameCatalog.dangerNames[dangerIdx]
    }

    val showBossAlert = state.bossAlertBannerText != null
    val showEvoBanner = !showBossAlert && state.evolutionBannerText != null
    val showBiomeBanner = !showBossAlert && !showEvoBanner && state.biomeBannerTimer > 0f && state.activeBossName == null
    val showWaveBanner = !showBossAlert && !showEvoBanner && !showBiomeBanner && state.activeWaveEventTitleZh != null && state.activeBossName == null
    val inspectedSlot = state.activeMoves.firstOrNull { it.moveId == inspectedMoveId }

    Box(
        modifier = modifier
            .fillMaxSize()
            .testTag("landscape_battle_hud")
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = edgePadH, vertical = edgePadV)
    ) {
        ConstraintLayout(modifier = Modifier.fillMaxSize()) {
            val (
                topLeftVitals,
                topCenterClock,
                topRightStatus,
                topRightTelemetry,
                leftFloatAlerts,
                centerBanner,
                rightDrawer,
                bottomLeftPassives,
                bottomCenterSkills,
                bottomRightActions
            ) = createRefs()

            // =========================================================================
            // 1. TOP-LEFT: Player HP Bar + Experience Bar + Portrait + Evolution Pill
            // =========================================================================
            Row(
                modifier = Modifier.constrainAs(topLeftVitals) {
                    top.linkTo(parent.top)
                    start.linkTo(parent.start)
                    end.linkTo(topCenterClock.start, margin = 8.dp)
                    horizontalBias = 0f
                    width = Dimension.preferredWrapContent
                },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(if (isCompactW) 5.dp else 7.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(18.dp))
                        .background(HudInkDark.copy(alpha = 0.72f))
                        .border(1.1.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(18.dp))
                        .padding(start = 4.dp, end = 9.dp, top = 4.dp, bottom = 4.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        StarterPortraitAvatar(
                            portraitRes = starter.portraitRes,
                            ringColor = starter.element.color,
                            size = avatarSize
                        )

                        Column(
                            modifier = Modifier.widthIn(min = 104.dp, max = if (isWide) 180.dp else 142.dp),
                            verticalArrangement = Arrangement.spacedBy(3.5.dp)
                        ) {
                            // Player HP Bar (生命槽)
                            val hpGradient = if (targetHpFrac < 0.30f) {
                                listOf(Color(0xFF9E1522), CrimsonRed, Color(0xFFFF8F6B))
                            } else {
                                listOf(CrimsonDeep, CrimsonRed, Color(0xFFFF7A6A))
                            }
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("hud_hp_bar")
                                    .height(if (isCompactH) 15.dp else 17.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(HudInkDark.copy(alpha = 0.94f))
                                    .border(1.3.dp, Color.White.copy(alpha = 0.20f), RoundedCornerShape(50))
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(animatedHpFrac)
                                        .clip(RoundedCornerShape(50))
                                        .background(Brush.horizontalGradient(hpGradient))
                                )
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth(animatedHpFrac)
                                        .height(3.5.dp)
                                        .padding(top = 1.dp, start = 4.dp, end = 4.dp)
                                        .clip(RoundedCornerShape(50))
                                        .background(Color.White.copy(alpha = 0.28f))
                                )
                                Text(
                                    text = "HP ${state.hp.toInt()}/${state.maxHp.toInt()}",
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontSize = if (isCompactH) 8.5.sp else 9.5.sp,
                                        fontWeight = FontWeight.Bold
                                    ),
                                    color = Color.White,
                                    maxLines = 1,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            // Experience Bar (经验条 — anchored directly in Top-Left under HP)
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("hud_xp_bar")
                                    .height(if (isCompactH) 10.dp else 11.5.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(HudInkDark.copy(alpha = 0.90f))
                                    .border(1.dp, SkyBlue.copy(alpha = 0.40f), RoundedCornerShape(50))
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(animatedXpFrac)
                                        .clip(RoundedCornerShape(50))
                                        .background(
                                            Brush.horizontalGradient(
                                                listOf(SkyBlue, Color(0xFF72FFCC), GoldAccent)
                                            )
                                        )
                                )
                                if (animatedXpFrac > 0.02f) {
                                    Canvas(modifier = Modifier.fillMaxSize()) {
                                        val tipX = (size.width * animatedXpFrac).coerceIn(3f, size.width - 3f)
                                        drawCircle(
                                            color = Color.White.copy(alpha = 0.92f),
                                            radius = size.height * 0.34f,
                                            center = Offset(tipX, size.height / 2f)
                                        )
                                    }
                                }
                                Text(
                                    text = "EXP ${(animatedXpFrac * 100f).toInt()}%",
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontSize = 7.5.sp,
                                        fontWeight = FontWeight.Bold
                                    ),
                                    color = if (animatedXpFrac > 0.45f) EspressoDark else CreamSurface,
                                    maxLines = 1,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            // Slim Prismatic Hyper-Awakening Strip
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(4.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(Color.White.copy(alpha = 0.12f))
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(animatedHyperFrac)
                                        .clip(RoundedCornerShape(50))
                                        .background(
                                            Brush.horizontalGradient(
                                                listOf(Color(0xFFFF5CE6), GoldAccent, Color(0xFF5CF6FF))
                                            )
                                        )
                                )
                            }
                        }
                    }
                }

                // Compact Evolution Branch Pill trailing the Top-Left vitals capsule
                Row(
                    modifier = Modifier
                        .testTag("hud_evolution_pill")
                        .scale(if (evoReady) interactPulse else 1f)
                        .clip(RoundedCornerShape(50))
                        .background(
                            if (evoReady) Brush.horizontalGradient(listOf(WarmOrange, GoldAccent))
                            else Brush.horizontalGradient(listOf(HudInkDark.copy(alpha = 0.84f), HudInkDark.copy(alpha = 0.78f)))
                        )
                        .border(
                            width = if (evoReady) 1.6.dp else 1.1.dp,
                            color = if (evoReady) DarkButtonRim else curNode.visualStyle.auraColor.copy(alpha = 0.76f),
                            shape = RoundedCornerShape(50)
                        )
                        .clickable(onClick = onOpenEvolution)
                        .padding(horizontal = if (isCompactW) 6.dp else 8.dp, vertical = 4.5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.AutoAwesome,
                        contentDescription = "打开进化分支面板",
                        tint = if (evoReady) EspressoDark else GoldAccent,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = if (evoReady) "可进化!" else if (isCompactW) "$totalRes" else "${curNode.nameZh}·$totalRes",
                        style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.sp),
                        color = if (evoReady) EspressoDark else Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // =========================================================================
            // 2. TOP-CENTER: Strictly Centered Match Clock + Pause + Danger Tier
            // =========================================================================
            Row(
                modifier = Modifier
                    .constrainAs(topCenterClock) {
                        top.linkTo(parent.top)
                        start.linkTo(parent.start)
                        end.linkTo(parent.end)
                    }
                    .testTag("hud_timer_pause_pill")
                    .clip(RoundedCornerShape(50))
                    .background(HudInkDark.copy(alpha = 0.86f))
                    .border(1.3.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
                    .clickable(onClick = onPauseClick)
                    .padding(
                        horizontal = if (isCompactH) 10.dp else 13.dp,
                        vertical = if (isCompactH) 4.5.dp else 6.dp
                    ),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Rounded.Pause,
                    contentDescription = "暂停战斗",
                    tint = CreamSurface,
                    modifier = Modifier.size(if (isCompactH) 13.dp else 15.dp)
                )
                Text(
                    text = "%02d:%02d".format(mins, secs),
                    style = MaterialTheme.typography.titleMedium.copy(fontSize = if (isCompactH) 13.sp else 14.5.sp),
                    color = Color.White,
                    maxLines = 1
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(dangerColor)
                        .padding(horizontal = 6.5.dp, vertical = 1.dp)
                ) {
                    Text(
                        text = dangerText,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (isCompactH) 9.sp else 9.5.sp),
                        color = if (dangerIdx <= 2) EspressoDark else Color.White,
                        maxLines = 1
                    )
                }
            }

            // =========================================================================
            // 3. TOP-RIGHT: Current Level Info + Ultimate Cooldown/Charge + Minimap
            // =========================================================================
            Row(
                modifier = Modifier.constrainAs(topRightStatus) {
                    top.linkTo(parent.top)
                    end.linkTo(parent.end)
                    start.linkTo(topCenterClock.end, margin = 8.dp)
                    horizontalBias = 1f
                    width = Dimension.preferredWrapContent
                },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(if (isCompactW) 5.dp else 8.dp)
            ) {
                // Dedicated Level + Ult Cooldown/Charge Status Card
                TopRightLevelAndUltCard(
                    level = state.level,
                    ultCharge = state.ultCharge,
                    ultActiveTimer = state.ultActiveTimer,
                    ultNameZh = state.ultNameZh,
                    compact = isCompactH || isCompactW,
                    pulseScale = interactPulse,
                    onUltClick = onUltClick
                )

                CircularMinimap(stateProvider = renderStateProvider, mapSize = minimapSize)
            }

            // Secondary Top-Right Strip directly below Level/Ult/Minimap (Resources + Objective Drawer Toggle)
            Row(
                modifier = Modifier.constrainAs(topRightTelemetry) {
                    top.linkTo(topRightStatus.bottom, margin = 4.dp)
                    end.linkTo(parent.end)
                },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                UnifiedResourceStrip(
                    kills = state.kills,
                    coins = state.coins,
                    chestsOpened = state.chestsOpened,
                    compact = true
                )

                Row(
                    modifier = Modifier
                        .testTag("objective_drawer_toggle")
                        .clip(RoundedCornerShape(50))
                        .background(HudInkDark.copy(alpha = 0.84f))
                        .border(1.2.dp, GoldAccent.copy(alpha = 0.68f), RoundedCornerShape(50))
                        .clickable(onClick = onToggleObjectiveDrawer)
                        .padding(horizontal = 7.dp, vertical = 3.5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Flag,
                        contentDescription = "目标抽屉",
                        tint = GoldAccent,
                        modifier = Modifier.size(11.5.dp)
                    )
                    Text(
                        text = if (isWide) "目标 $doneCount/${state.objectives.size}" else "$doneCount/${state.objectives.size}",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                        color = Color.White,
                        maxLines = 1
                    )
                    Icon(
                        imageVector = if (objectiveDrawerOpen) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                        contentDescription = null,
                        tint = HudDimText,
                        modifier = Modifier.size(11.5.dp)
                    )
                }
            }

            // =========================================================================
            // 4. MARGIN FLOATS (Zero Center Obstruction!)
            // =========================================================================
            // Left Margin Float: High-Ground Buff + Hyper-Awakening Ready CTA + Combo Counter
            Column(
                modifier = Modifier.constrainAs(leftFloatAlerts) {
                    top.linkTo(topLeftVitals.bottom, margin = 5.dp)
                    start.linkTo(parent.start)
                },
                verticalArrangement = Arrangement.spacedBy(5.dp),
                horizontalAlignment = Alignment.Start
            ) {
                AnimatedVisibility(visible = state.isOnHighGround, enter = fadeIn(), exit = fadeOut()) {
                    Row(
                        modifier = Modifier
                            .testTag("hud_high_ground_pill")
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.84f))
                            .border(1.3.dp, GoldAccent.copy(alpha = 0.90f), RoundedCornerShape(50))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.KeyboardArrowUp,
                            contentDescription = "高地战术优势",
                            tint = GoldAccent,
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = "高地优势 · 伤害+20% 射程+",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontSize = 9.5.sp,
                                fontWeight = FontWeight.Bold
                            ),
                            color = GoldAccent,
                            maxLines = 1
                        )
                    }
                }

                AnimatedVisibility(visible = state.activeEcoBuffZh != null, enter = fadeIn(), exit = fadeOut()) {
                    Row(
                        modifier = Modifier
                            .testTag("hud_eco_zone_pill")
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.86f))
                            .border(1.3.dp, SkyBlue.copy(alpha = 0.85f), RoundedCornerShape(50))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.AutoAwesome,
                            contentDescription = "生态区域效果",
                            tint = SkyBlue,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = state.activeEcoBuffZh.orEmpty(),
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontSize = 9.5.sp,
                                fontWeight = FontWeight.Bold
                            ),
                            color = CreamSurface,
                            maxLines = 1
                        )
                    }
                }

                if (state.activeChallengeCount > 0) {
                    Box(
                        modifier = Modifier
                            .testTag("hud_challenge_badge")
                            .clip(RoundedCornerShape(50))
                            .background(CrimsonDeep.copy(alpha = 0.86f))
                            .border(1.1.dp, GoldAccent.copy(alpha = 0.82f), RoundedCornerShape(50))
                            .padding(horizontal = 7.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "试炼×${state.activeChallengeCount} · 星尘+${state.challengeStardustBonusPct}%",
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold),
                            color = GoldAccent,
                            maxLines = 1
                        )
                    }
                }

                if (hyperReady || hyperActive) {
                    Row(
                        modifier = Modifier
                            .testTag("hud_hyper_awaken_btn")
                            .scale(if (hyperReady) interactPulse else 1f)
                            .clip(RoundedCornerShape(50))
                            .background(
                                Brush.horizontalGradient(
                                    listOf(Color(0xFFFF5CE6), GoldAccent, Color(0xFF5CF6FF))
                                )
                            )
                            .border(1.6.dp, DarkButtonRim, RoundedCornerShape(50))
                            .clickable(enabled = hyperReady, onClick = onHyperAwakenClick)
                            .padding(horizontal = 9.dp, vertical = 3.5.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Bolt,
                            contentDescription = "释放超觉醒",
                            tint = EspressoDark,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = if (hyperActive) "超觉醒 ${state.hyperActiveTimer.toInt() + 1}s" else "超觉醒!",
                            style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.sp),
                            color = EspressoDark,
                            maxLines = 1
                        )
                    }
                }

                AnimatedVisibility(visible = state.comboCount >= 3, enter = fadeIn(), exit = fadeOut()) {
                    Column(
                        modifier = Modifier
                            .testTag("hud_combo_pill")
                            .clip(RoundedCornerShape(10.dp))
                            .background(HudInkDark.copy(alpha = 0.80f))
                            .border(
                                width = 1.2.dp,
                                color = if (state.scoreMultiplier >= 3f) Color(0xFFFF66E5) else GoldAccent,
                                shape = RoundedCornerShape(10.dp)
                            )
                            .padding(horizontal = 8.dp, vertical = 2.5.dp),
                        horizontalAlignment = Alignment.Start,
                        verticalArrangement = Arrangement.spacedBy(1.5.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(3.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Bolt,
                                contentDescription = "连击倍率",
                                tint = GoldAccent,
                                modifier = Modifier.size(11.dp)
                            )
                            Text(
                                text = "${state.comboCount}连击 · ×${"%.1f".format(state.scoreMultiplier)}",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = GoldAccent,
                                maxLines = 1
                            )
                        }
                        Box(
                            modifier = Modifier
                                .width(72.dp)
                                .height(2.5.dp)
                                .clip(RoundedCornerShape(50))
                                .background(Color.White.copy(alpha = 0.16f))
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxHeight()
                                    .fillMaxWidth(state.comboTimerRatio.coerceIn(0f, 1f))
                                    .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent)))
                            )
                        }
                    }
                }
            }

            // Top-Center High-Edge Single Priority Banner / Boss Bar (Hugs clock, never blocks hero)
            Column(
                modifier = Modifier
                    .constrainAs(centerBanner) {
                        top.linkTo(topCenterClock.bottom, margin = 4.dp)
                        start.linkTo(parent.start)
                        end.linkTo(parent.end)
                    }
                    .widthIn(max = 290.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                AnimatedVisibility(visible = showBossAlert, enter = fadeIn(), exit = fadeOut()) {
                    BossAlertWarningBanner(
                        text = state.bossAlertBannerText.orEmpty(),
                        compact = true
                    )
                }
                when {
                    state.activeBossName != null -> {
                        BossHealthBar(
                            bossTag = state.activeBossTag,
                            bossName = state.activeBossName,
                            hpRatio = state.activeBossHpRatio,
                            bossPhase = state.activeBossPhase,
                            isStaggered = state.activeBossStaggered,
                            compact = true
                        )
                    }
                    showEvoBanner -> {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent)))
                                .border(1.5.dp, DarkButtonRim, RoundedCornerShape(50))
                                .padding(horizontal = 11.dp, vertical = 2.5.dp)
                        ) {
                            Text(
                                text = state.evolutionBannerText.orEmpty(),
                                style = MaterialTheme.typography.titleSmall.copy(fontSize = 11.sp),
                                color = EspressoDark,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    showBiomeBanner -> {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.82f))
                                .border(1.2.dp, GoldAccent, RoundedCornerShape(50))
                                .padding(horizontal = 10.dp, vertical = 2.5.dp)
                        ) {
                            Text(
                                text = "${biome.nameZh} · ${biome.subtitleZh}",
                                style = MaterialTheme.typography.titleSmall.copy(fontSize = 10.5.sp),
                                color = CreamSurface,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    showWaveBanner -> {
                        Column(
                            modifier = Modifier
                                .testTag("hud_wave_event_pill")
                                .clip(RoundedCornerShape(10.dp))
                                .background(HudInkDark.copy(alpha = 0.82f))
                                .border(1.2.dp, WarmOrange, RoundedCornerShape(10.dp))
                                .padding(horizontal = 10.dp, vertical = 2.5.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Text(
                                text = state.activeWaveEventTitleZh.orEmpty(),
                                style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.sp),
                                color = GoldAccent,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Box(
                                modifier = Modifier
                                    .width(92.dp)
                                    .height(2.5.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(Color.White.copy(alpha = 0.16f))
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(state.activeWaveEventTimerRatio.coerceIn(0f, 1f))
                                        .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent, Color(0xFF66F6FF))))
                                )
                            }
                        }
                    }
                }
            }

            // Right Margin Expandable Objective Drawer
            Box(
                modifier = Modifier.constrainAs(rightDrawer) {
                    top.linkTo(topRightTelemetry.bottom, margin = 4.dp)
                    end.linkTo(parent.end)
                }
            ) {
                AnimatedVisibility(
                    visible = objectiveDrawerOpen,
                    enter = fadeIn() + expandVertically(),
                    exit = fadeOut() + shrinkVertically()
                ) {
                    Column(
                        modifier = Modifier
                            .widthIn(min = 156.dp, max = 198.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(HudInkDark.copy(alpha = 0.92f))
                            .border(1.3.dp, GoldAccent.copy(alpha = 0.58f), RoundedCornerShape(12.dp))
                            .padding(8.dp),
                        verticalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        for (obj in state.objectives) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = if (obj.completed) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                                    contentDescription = null,
                                    tint = if (obj.completed) GrassGreen else GoldAccent,
                                    modifier = Modifier.size(13.dp)
                                )
                                Spacer(Modifier.width(5.dp))
                                Column {
                                    Text(
                                        text = obj.titleZh,
                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                        color = if (obj.completed) GrassGreen else Color.White,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = obj.progressText,
                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                        color = HudDimText,
                                        maxLines = 1
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // 5. BOTTOM-LEFT: Low-Profile Synergy & Vitamin Chips (Joystick stays open)
            // =========================================================================
            Box(
                modifier = Modifier.constrainAs(bottomLeftPassives) {
                    bottom.linkTo(parent.bottom)
                    start.linkTo(parent.start)
                    end.linkTo(bottomCenterSkills.start, margin = 8.dp)
                    horizontalBias = 0f
                    width = Dimension.preferredWrapContent
                }
            ) {
                if (state.activeVitamins.isNotEmpty() || state.activeSynergyCount > 0 || state.fusedMoveCount > 0 || state.overclockedMoveCount > 0 || state.activeBonds.isNotEmpty()) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        horizontalAlignment = Alignment.Start
                    ) {
                        if (state.activeBonds.isNotEmpty()) {
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                state.activeBonds.take(2).forEach { bond ->
                                    ElementalBondMiniChip(bond = bond)
                                }
                            }
                        }
                        if (state.activeSynergyCount > 0 || state.fusedMoveCount > 0 || state.overclockedMoveCount > 0) {
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                if (state.activeSynergyCount > 0) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(GoldAccent)
                                            .border(1.2.dp, DarkButtonRim, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = "★协同×${state.activeSynergyCount}",
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                            color = EspressoDark,
                                            maxLines = 1
                                        )
                                    }
                                }
                                if (state.fusedMoveCount > 0) {
                                    Box(
                                        modifier = Modifier
                                            .testTag("hud_fused_badge")
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color(0xFF5CF6FF))
                                            .border(1.2.dp, DarkButtonRim, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = "✦融合×${state.fusedMoveCount}",
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                            color = EspressoDark,
                                            maxLines = 1
                                        )
                                    }
                                }
                                if (state.overclockedMoveCount > 0) {
                                    Box(
                                        modifier = Modifier
                                            .testTag("hud_overclock_badge")
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color(0xFFFF66E5))
                                            .border(1.2.dp, DarkButtonRim, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = "✧超频×${state.overclockedMoveCount}",
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                            color = Color.White,
                                            maxLines = 1
                                        )
                                    }
                                }
                            }
                        }
                        if (state.activeVitamins.isNotEmpty()) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                state.activeVitamins.take(if (isCompactW) 2 else 3).forEach { (shortName, lv) ->
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(HudInkDark.copy(alpha = 0.80f))
                                            .border(1.dp, DarkButtonRim, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 5.5.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = "$shortName+$lv",
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                            color = CreamSurface,
                                            maxLines = 1
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // 6. BOTTOM-CENTER: Always Horizontally Centered Skill Bar via ConstraintLayout
            // =========================================================================
            Column(
                modifier = Modifier
                    .constrainAs(bottomCenterSkills) {
                        bottom.linkTo(parent.bottom)
                        start.linkTo(parent.start)
                        end.linkTo(parent.end)
                    }
                    .testTag("hud_skill_bar"),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                AnimatedVisibility(
                    visible = inspectedSlot != null,
                    enter = fadeIn(tween(150)) + expandVertically(expandFrom = Alignment.Bottom),
                    exit = fadeOut(tween(140)) + shrinkVertically(shrinkTowards = Alignment.Bottom)
                ) {
                    if (inspectedSlot != null) {
                        MoveQuickTooltip(
                            slot = inspectedSlot,
                            onDismiss = { onInspectMove(null) }
                        )
                    }
                }

                if (inspectedSlot == null && state.nearSynergyHintZh != null) {
                    Box(
                        modifier = Modifier
                            .testTag("hud_synergy_tracker")
                            .widthIn(max = availableCenterW + 24.dp)
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.84f))
                            .border(1.1.dp, GoldAccent.copy(alpha = 0.78f), RoundedCornerShape(50))
                            .padding(horizontal = 9.dp, vertical = 2.5.dp)
                    ) {
                        Text(
                            text = state.nearSynergyHintZh,
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                            color = GoldAccent,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(18.dp))
                        .background(HudInkDark.copy(alpha = 0.58f))
                        .border(1.2.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(18.dp))
                        .padding(horizontal = 7.dp, vertical = 5.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(skillSpacing),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        for (idx in 0 until slotCount) {
                            val slot = state.activeMoves.getOrNull(idx)
                            SkillSlotTile(
                                slot = slot,
                                slotSize = skillSlotSize,
                                selected = slot != null && slot.moveId == inspectedMoveId,
                                onClick = slot?.let { active ->
                                    {
                                        onInspectMove(if (inspectedMoveId == active.moveId) null else active.moveId)
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // =========================================================================
            // 7. BOTTOM-RIGHT: Responsive Action Arc (Dash, Jump, Ult, Contextual Interact)
            // =========================================================================
            HudActionArc(
                state = state,
                actionArcSize = actionArcSize,
                ultSize = ultSize,
                dashSize = dashSize,
                jumpSize = jumpSize,
                interactSize = interactSize,
                isCompact = isCompactH || isCompactW,
                interactPulse = interactPulse,
                onInteractClick = onInteractClick,
                onDashClick = onDashClick,
                onJumpClick = onJumpClick,
                onUltClick = onUltClick,
                modifier = Modifier.constrainAs(bottomRightActions) {
                    bottom.linkTo(parent.bottom)
                    end.linkTo(parent.end)
                }
            )
        }
    }
}

/**
 * Top-Right cohesive dark-glass card displaying Current Level and Ultimate Cooldown / Charge status.
 */
@Composable
fun TopRightLevelAndUltCard(
    level: Int,
    ultCharge: Float,
    ultActiveTimer: Float,
    ultNameZh: String,
    compact: Boolean,
    pulseScale: Float,
    onUltClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isUltActive = ultActiveTimer > 0f
    val isUltReady = ultCharge >= 0.999f && !isUltActive
    val chargePct = (ultCharge.coerceIn(0f, 1f) * 100f).toInt()
    val ultBarFrac = if (isUltActive) (ultActiveTimer / 4f).coerceIn(0.1f, 1f) else ultCharge.coerceIn(0f, 1f)

    Box(
        modifier = modifier
            .testTag("hud_level_ult_card")
            .clip(RoundedCornerShape(16.dp))
            .background(HudInkDark.copy(alpha = 0.78f))
            .border(
                width = if (isUltReady) 1.5.dp else 1.1.dp,
                color = if (isUltReady) GoldAccent else Color.White.copy(alpha = 0.16f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(horizontal = if (compact) 7.dp else 9.dp, vertical = if (compact) 4.dp else 5.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(3.5.dp)
        ) {
            // Current Level Info Row (当前等级信息)
            Row(
                modifier = Modifier.testTag("hud_level_badge"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Brush.horizontalGradient(listOf(GoldAccent, WarmOrange)))
                        .padding(horizontal = 6.dp, vertical = 1.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Star,
                            contentDescription = "当前等级",
                            tint = EspressoDark,
                            modifier = Modifier.size(10.dp)
                        )
                        Text(
                            text = "Lv.$level",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontSize = if (compact) 9.5.sp else 10.5.sp,
                                fontWeight = FontWeight.ExtraBold
                            ),
                            color = EspressoDark,
                            maxLines = 1
                        )
                    }
                }
                Text(
                    text = ultNameZh.take(4),
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.sp else 10.sp),
                    color = CreamSurface.copy(alpha = 0.88f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Ultimate Cooldown / Charge Status Pill (必杀技冷却/充能显示)
            Column(
                modifier = Modifier
                    .testTag("hud_ult_cooldown_pill")
                    .scale(if (isUltReady) pulseScale else 1f)
                    .clip(RoundedCornerShape(9.dp))
                    .background(
                        when {
                            isUltReady -> GoldAccent.copy(alpha = 0.22f)
                            isUltActive -> WarmOrange.copy(alpha = 0.24f)
                            else -> Color.White.copy(alpha = 0.08f)
                        }
                    )
                    .clickable(enabled = isUltReady, onClick = onUltClick)
                    .padding(horizontal = 6.dp, vertical = 2.5.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Icon(
                        imageVector = if (isUltReady) Icons.Rounded.AutoAwesome else Icons.Rounded.Bolt,
                        contentDescription = "必杀技冷却状态",
                        tint = when {
                            isUltReady -> GoldAccent
                            isUltActive -> WarmOrange
                            else -> SkyBlue
                        },
                        modifier = Modifier.size(11.dp)
                    )
                    Text(
                        text = when {
                            isUltActive -> "释放中 ${"%.1f".format(ultActiveTimer)}s"
                            isUltReady -> "必杀就绪!"
                            else -> "必杀充能 $chargePct%"
                        },
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = if (compact) 8.5.sp else 9.5.sp,
                            fontWeight = FontWeight.Bold
                        ),
                        color = when {
                            isUltReady -> GoldAccent
                            isUltActive -> WarmOrange
                            else -> Color.White
                        },
                        maxLines = 1
                    )
                }

                Box(
                    modifier = Modifier
                        .width(if (compact) 76.dp else 94.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.16f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(ultBarFrac)
                            .clip(RoundedCornerShape(50))
                            .background(
                                Brush.horizontalGradient(
                                    when {
                                        isUltReady -> listOf(GoldAccent, Color(0xFFFFF199))
                                        isUltActive -> listOf(WarmOrange, GoldAccent)
                                        else -> listOf(SkyBlue, Color(0xFF72FFCC))
                                    }
                                )
                            )
                    )
                }
            }
        }
    }
}
