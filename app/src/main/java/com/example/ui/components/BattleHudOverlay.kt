package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.engine.BattleRenderState
import com.example.game.evolution.EvolutionResourceType
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
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
import kotlinx.coroutines.delay
import kotlin.math.hypot

@Composable
fun BattleHudOverlay(
    state: BattleRenderState,
    renderStateProvider: () -> BattleRenderState = { state },
    onJoystickChange: (Float, Float) -> Unit,
    onDashClick: () -> Unit,
    onJumpClick: () -> Unit,
    onUltClick: () -> Unit,
    onHyperAwakenClick: () -> Unit,
    onInteractClick: () -> Unit,
    onOpenEvolution: () -> Unit,
    onPauseClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val starter = remember(state.starterId) { GameCatalog.starterById(state.starterId) }
    val biome = remember(state.biomeId) { GameCatalog.biomeById(state.biomeId) }
    var objectiveDrawerOpen by remember { mutableStateOf(false) }
    var inspectedMoveId by remember { mutableStateOf<String?>(null) }

    // Auto-dismiss skill quick-inspect tooltip after 3.8s so it never lingers
    LaunchedEffect(inspectedMoveId) {
        if (inspectedMoveId != null) {
            delay(3800L)
            inspectedMoveId = null
        }
    }

    val targetHpFrac = (state.hp / state.maxHp.coerceAtLeast(1f)).coerceIn(0f, 1f)
    val animatedHpFrac by animateFloatAsState(targetValue = targetHpFrac, animationSpec = tween(160), label = "hp_bar")
    val targetXpFrac = (state.xp / state.xpToNext.coerceAtLeast(1f)).coerceIn(0f, 1f)
    val animatedXpFrac by animateFloatAsState(targetValue = targetXpFrac, animationSpec = tween(180), label = "xp_bar")
    val targetHyperFrac = if (state.hyperActiveTimer > 0f) {
        (state.hyperActiveTimer / state.hyperMaxDuration.coerceAtLeast(1f)).coerceIn(0f, 1f)
    } else {
        state.hyperCharge.coerceIn(0f, 1f)
    }
    val animatedHyperFrac by animateFloatAsState(targetValue = targetHyperFrac, animationSpec = tween(180), label = "hyper_bar")

    // Only tick the CTA pulse transition when an actionable CTA is actually ready (eliminates idle 60Hz HUD recompositions)
    val needsInteractPulse = state.nearbyInteractKind != null ||
        state.evolutionState.hasReadyEvolution ||
        (state.hyperCharge >= 1f && state.hyperActiveTimer <= 0f) ||
        (state.ultCharge >= 1f && state.ultActiveTimer <= 0f)
    val interactPulse = if (needsInteractPulse) {
        val pulse = rememberInfiniteTransition(label = "hud_cta_pulse")
        val value by pulse.animateFloat(
            initialValue = 1f,
            targetValue = 1.07f,
            animationSpec = infiniteRepeatable(tween(520), RepeatMode.Reverse),
            label = "interact_pulse"
        )
        value
    } else {
        1f
    }

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val isLandscape = maxWidth > maxHeight || maxHeight < 520.dp
        val isCompact = maxWidth < 430.dp
        val isUltraCompact = maxWidth < 375.dp
        val isNarrowForCenteredSkills = maxWidth < 560.dp
        val edgePad = if (isCompact) 10.dp else 16.dp
        val avatarSize = if (isCompact) 44.dp else 52.dp
        val barWidth = if (isCompact) 106.dp else 142.dp
        val minimapSize = if (isCompact) 54.dp else 74.dp
        val skillSlotSize = if (isCompact) 47.dp else 54.dp
        val skillSpacing = if (isCompact) 5.dp else 8.dp
        val actionArcSize = if (isCompact) 148.dp else 172.dp
        val ultSize = if (isCompact) 70.dp else 82.dp
        val dashSize = if (isCompact) 54.dp else 62.dp
        val jumpSize = if (isCompact) 48.dp else 54.dp
        val interactSize = if (isCompact) 50.dp else 58.dp

        // Isolated Low-HP crimson heartbeat vignette (only animates when HP < 30%)
        if (targetHpFrac < 0.30f && state.hp > 0f) {
            LowHpHeartbeatVignette()
        }

        // Isolated floating virtual joystick (drag updates redraw only its Canvas, never recomposing HUD)
        VirtualJoystickOverlay(
            accentColor = starter.element.color,
            onJoystickChange = onJoystickChange,
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(0.54f)
                .align(Alignment.BottomStart)
        )

        if (isLandscape) {
            LandscapeBattleHud(
                state = state,
                renderStateProvider = renderStateProvider,
                starter = starter,
                biome = biome,
                maxWidth = maxWidth,
                maxHeight = maxHeight,
                animatedHpFrac = animatedHpFrac,
                animatedXpFrac = animatedXpFrac,
                animatedHyperFrac = animatedHyperFrac,
                targetHpFrac = targetHpFrac,
                interactPulse = interactPulse,
                objectiveDrawerOpen = objectiveDrawerOpen,
                onToggleObjectiveDrawer = { objectiveDrawerOpen = !objectiveDrawerOpen },
                inspectedMoveId = inspectedMoveId,
                onInspectMove = { inspectedMoveId = it },
                onDashClick = onDashClick,
                onJumpClick = onJumpClick,
                onUltClick = onUltClick,
                onHyperAwakenClick = onHyperAwakenClick,
                onInteractClick = onInteractClick,
                onOpenEvolution = onOpenEvolution,
                onPauseClick = onPauseClick
            )
            return@BoxWithConstraints
        }

        // PORTRAIT / TALL LAYOUT: Inset XP Strip + Balanced Row 1 Anchors + Aligned Row 2 Ribbon + Dynamic Layer
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
            GameMode.SURVIVAL -> "无尽·${GameCatalog.dangerNames[dangerIdx]}"
            GameMode.DUEL -> "决斗·${GameCatalog.dangerNames[dangerIdx]}"
            GameMode.CLASSIC -> GameCatalog.dangerNames[dangerIdx]
        }

        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(top = 4.dp, start = edgePad, end = edgePad),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // ROW 1: Top-Left (Portrait + HP + XP Bar) | Center (Clock) | Top-Right (Minimap + Level/Ult)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Left: Portrait + Glossy HP Bar + Experience Bar + slim Hyper strip
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    StarterPortraitAvatar(
                        portraitRes = starter.portraitRes,
                        ringColor = starter.element.color,
                        size = avatarSize
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        val hpGradient = if (targetHpFrac < 0.30f) {
                            listOf(Color(0xFF9E1522), CrimsonRed, Color(0xFFFF8F6B))
                        } else {
                            listOf(CrimsonDeep, CrimsonRed, Color(0xFFFF7A6A))
                        }
                        // Player HP Bar
                        Box(
                            modifier = Modifier
                                .width(barWidth)
                                .testTag("hud_hp_bar")
                                .height(16.5.dp)
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.88f))
                                .border(1.4.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
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
                                text = "${state.hp.toInt()}/${state.maxHp.toInt()}",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                color = Color.White,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }

                        // Experience Bar directly under HP at Top-Left
                        Box(
                            modifier = Modifier
                                .width(barWidth)
                                .testTag("hud_xp_bar")
                                .height(10.dp)
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.86f))
                                .border(1.dp, SkyBlue.copy(alpha = 0.38f), RoundedCornerShape(50))
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxHeight()
                                    .fillMaxWidth(animatedXpFrac)
                                    .clip(RoundedCornerShape(50))
                                    .background(Brush.horizontalGradient(listOf(SkyBlue, Color(0xFF72FFCC), GoldAccent)))
                            )
                            Text(
                                text = "EXP ${(animatedXpFrac * 100f).toInt()}%",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp),
                                color = if (animatedXpFrac > 0.45f) EspressoDark else CreamSurface,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }

                        // Slim Hyper-Awakening Strip
                        Box(
                            modifier = Modifier
                                .width(barWidth)
                                .height(4.5.dp)
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.82f))
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

                // Center: Timer + Pause + Danger Tier
                if (isCompact) {
                    Column(
                        modifier = Modifier
                            .testTag("hud_timer_pause_pill")
                            .minimumInteractiveComponentSize()
                            .clip(RoundedCornerShape(14.dp))
                            .background(HudInkDark.copy(alpha = 0.84f))
                            .border(1.4.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(14.dp))
                            .clickable(onClick = onPauseClick)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Pause,
                                contentDescription = "暂停战斗",
                                tint = CreamSurface,
                                modifier = Modifier.size(12.dp)
                            )
                            Text(
                                text = "%02d:%02d".format(mins, secs),
                                style = MaterialTheme.typography.titleMedium.copy(fontSize = 13.sp),
                                color = Color.White
                            )
                        }
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(dangerColor)
                                .padding(horizontal = 7.dp, vertical = 1.dp)
                        ) {
                            Text(
                                text = dangerText,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = if (dangerIdx <= 2) EspressoDark else Color.White,
                                maxLines = 1
                            )
                        }
                    }
                } else {
                    Row(
                        modifier = Modifier
                            .testTag("hud_timer_pause_pill")
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.84f))
                            .border(1.4.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
                            .clickable(onClick = onPauseClick)
                            .padding(horizontal = 13.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Pause,
                            contentDescription = "暂停战斗",
                            tint = CreamSurface,
                            modifier = Modifier.size(15.dp)
                        )
                        Text(
                            text = "%02d:%02d".format(mins, secs),
                            style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.5.sp),
                            color = Color.White
                        )
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(dangerColor)
                                .padding(horizontal = 7.dp, vertical = 1.5.dp)
                        ) {
                            Text(
                                text = dangerText,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = if (dangerIdx <= 2) EspressoDark else Color.White,
                                maxLines = 1
                            )
                        }
                    }
                }

                // Right: Level + Ult Cooldown Status Card & Radar Minimap
                if (isCompact) {
                    Column(
                        horizontalAlignment = Alignment.End,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        CircularMinimap(stateProvider = renderStateProvider, mapSize = minimapSize)
                        TopRightLevelAndUltCard(
                            level = state.level,
                            ultCharge = state.ultCharge,
                            ultActiveTimer = state.ultActiveTimer,
                            ultNameZh = state.ultNameZh,
                            compact = true,
                            pulseScale = interactPulse,
                            onUltClick = onUltClick
                        )
                    }
                } else {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        TopRightLevelAndUltCard(
                            level = state.level,
                            ultCharge = state.ultCharge,
                            ultActiveTimer = state.ultActiveTimer,
                            ultNameZh = state.ultNameZh,
                            compact = false,
                            pulseScale = interactPulse,
                            onUltClick = onUltClick
                        )
                        CircularMinimap(stateProvider = renderStateProvider, mapSize = minimapSize)
                    }
                }
            }

            // ROW 2: Portrait Telemetry Ribbon
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier
                        .testTag("hud_evolution_pill")
                        .scale(if (evoReady) interactPulse else 1f)
                        .clip(RoundedCornerShape(50))
                        .background(
                            if (evoReady) Brush.horizontalGradient(listOf(WarmOrange, GoldAccent))
                            else Brush.horizontalGradient(listOf(HudInkDark.copy(alpha = 0.86f), HudInkDark.copy(alpha = 0.80f)))
                        )
                        .border(
                            width = if (evoReady) 1.8.dp else 1.2.dp,
                            color = if (evoReady) DarkButtonRim else curNode.visualStyle.auraColor.copy(alpha = 0.78f),
                            shape = RoundedCornerShape(50)
                        )
                        .clickable(onClick = onOpenEvolution)
                        .padding(horizontal = 8.dp, vertical = 4.5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.AutoAwesome,
                        contentDescription = "打开进化分支面板",
                        tint = if (evoReady) EspressoDark else GoldAccent,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        text = if (evoReady) "可进化!" else curNode.nameZh,
                        style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.5.sp),
                        color = if (evoReady) EspressoDark else Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (!evoReady) {
                        Text(
                            text = if (isUltraCompact) "·$totalRes" else "·精华$totalRes",
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                            color = GoldAccent,
                            maxLines = 1
                        )
                    }
                }

                UnifiedResourceStrip(
                    kills = state.kills,
                    coins = state.coins,
                    chestsOpened = state.chestsOpened
                )

                Row(
                    modifier = Modifier
                        .testTag("objective_drawer_toggle")
                        .clip(RoundedCornerShape(50))
                        .background(HudInkDark.copy(alpha = 0.84f))
                        .border(1.2.dp, GoldAccent.copy(alpha = 0.68f), RoundedCornerShape(50))
                        .clickable { objectiveDrawerOpen = !objectiveDrawerOpen }
                        .padding(horizontal = 8.dp, vertical = 4.5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.5.dp)
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Flag,
                        contentDescription = "目标抽屉",
                        tint = GoldAccent,
                        modifier = Modifier.size(12.5.dp)
                    )
                    Text(
                        text = if (isUltraCompact) "$doneCount/${state.objectives.size}" else "目标 $doneCount/${state.objectives.size}",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = Color.White,
                        maxLines = 1
                    )
                    Icon(
                        imageVector = if (objectiveDrawerOpen) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                        contentDescription = null,
                        tint = HudDimText,
                        modifier = Modifier.size(13.dp)
                    )
                }
            }

            // PRIORITY TRANSIENT BANNER SELECTION: Never stack multiple horizontal banners over the hero!
            val showBossAlert = state.bossAlertBannerText != null
            val showEvoBanner = !showBossAlert && state.evolutionBannerText != null
            val showBiomeBanner = !showBossAlert && !showEvoBanner && state.biomeBannerTimer > 0f && state.activeBossName == null
            val showWaveBanner = !showBossAlert && !showEvoBanner && !showBiomeBanner && state.activeWaveEventTitleZh != null && state.activeBossName == null

            // OVERLAY LAYER: Side Hyper (Start), Single Priority Banner or Boss Bar (Center), Objective Drawer (End)
            Box(modifier = Modifier.fillMaxWidth()) {
                if (hyperReady || hyperActive) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .testTag("hud_hyper_awaken_btn")
                            .scale(if (hyperReady) interactPulse else 1f)
                            .clip(RoundedCornerShape(50))
                            .background(
                                Brush.horizontalGradient(
                                    listOf(Color(0xFFFF5CE6), GoldAccent, Color(0xFF5CF6FF))
                                )
                            )
                            .border(1.8.dp, DarkButtonRim, RoundedCornerShape(50))
                            .clickable(enabled = hyperReady, onClick = onHyperAwakenClick)
                            .padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Bolt,
                            contentDescription = "释放超觉醒",
                            tint = EspressoDark,
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = if (hyperActive) "超觉醒 ${state.hyperActiveTimer.toInt() + 1}s" else "超觉醒!",
                            style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.5.sp),
                            color = EspressoDark,
                            maxLines = 1
                        )
                    }
                }

                // Center Dynamic Slot: Eco Buff + Combo + Single Priority Banner / Boss Bar
                Column(
                    modifier = Modifier.align(Alignment.TopCenter),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    AnimatedVisibility(visible = state.activeEcoBuffZh != null, enter = fadeIn(), exit = fadeOut()) {
                        Box(
                            modifier = Modifier
                                .testTag("hud_eco_zone_pill")
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.86f))
                                .border(1.3.dp, SkyBlue.copy(alpha = 0.85f), RoundedCornerShape(50))
                                .padding(horizontal = 10.dp, vertical = 3.dp)
                        ) {
                            Text(
                                text = state.activeEcoBuffZh.orEmpty(),
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = CreamSurface,
                                maxLines = 1
                            )
                        }
                    }
                    AnimatedVisibility(visible = state.comboCount >= 3, enter = fadeIn(), exit = fadeOut()) {
                        Column(
                            modifier = Modifier
                                .testTag("hud_combo_pill")
                                .clip(RoundedCornerShape(12.dp))
                                .background(HudInkDark.copy(alpha = 0.84f))
                                .border(
                                    width = 1.4.dp,
                                    color = if (state.scoreMultiplier >= 3f) Color(0xFFFF66E5) else GoldAccent,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .padding(horizontal = 10.dp, vertical = 3.5.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Rounded.Bolt,
                                    contentDescription = "连击倍率",
                                    tint = GoldAccent,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(
                                    text = "${state.comboCount}连击 · ×${"%.1f".format(state.scoreMultiplier)}",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                                    color = GoldAccent,
                                    maxLines = 1
                                )
                                if (!isCompact && state.runScore > 0) {
                                    Text(
                                        text = "· ${state.runScore}分",
                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                        color = CreamSurface,
                                        maxLines = 1
                                    )
                                }
                            }
                            Box(
                                modifier = Modifier
                                    .width(88.dp)
                                    .height(3.dp)
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

                    AnimatedVisibility(visible = showBossAlert, enter = fadeIn(), exit = fadeOut()) {
                        BossAlertWarningBanner(
                            text = state.bossAlertBannerText.orEmpty(),
                            compact = isCompact
                        )
                    }

                    AnimatedVisibility(visible = showEvoBanner, enter = fadeIn(), exit = fadeOut()) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent)))
                                .border(1.6.dp, DarkButtonRim, RoundedCornerShape(50))
                                .padding(horizontal = 15.dp, vertical = 4.5.dp)
                        ) {
                            Text(
                                text = state.evolutionBannerText.orEmpty(),
                                style = MaterialTheme.typography.titleSmall.copy(
                                    fontSize = if (isCompact) 12.sp else 13.5.sp
                                ),
                                color = EspressoDark,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    AnimatedVisibility(visible = showBiomeBanner, enter = fadeIn(), exit = fadeOut()) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.84f))
                                .border(1.4.dp, GoldAccent, RoundedCornerShape(50))
                                .padding(horizontal = 14.dp, vertical = 4.5.dp)
                        ) {
                            Text(
                                text = "${biome.nameZh} · ${biome.subtitleZh}",
                                style = MaterialTheme.typography.titleSmall.copy(
                                    fontSize = if (isCompact) 12.sp else 13.sp
                                ),
                                color = CreamSurface,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    AnimatedVisibility(visible = showWaveBanner, enter = fadeIn(), exit = fadeOut()) {
                        Column(
                            modifier = Modifier
                                .testTag("hud_wave_event_pill")
                                .clip(RoundedCornerShape(12.dp))
                                .background(HudInkDark.copy(alpha = 0.84f))
                                .border(1.3.dp, WarmOrange, RoundedCornerShape(12.dp))
                                .padding(horizontal = 12.dp, vertical = 4.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Text(
                                text = state.activeWaveEventTitleZh.orEmpty(),
                                style = MaterialTheme.typography.labelLarge.copy(fontSize = 11.sp),
                                color = GoldAccent,
                                maxLines = 1
                            )
                            Box(
                                modifier = Modifier
                                    .width(120.dp)
                                    .height(3.dp)
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

                    if (state.activeBossName != null) {
                        BossHealthBar(
                            bossTag = state.activeBossTag,
                            bossName = state.activeBossName,
                            hpRatio = state.activeBossHpRatio,
                            bossPhase = state.activeBossPhase,
                            isStaggered = state.activeBossStaggered,
                            compact = false
                        )
                    }
                }

                // Top-Right Expandable Objective Drawer
                Box(modifier = Modifier.align(Alignment.TopEnd)) {
                    androidx.compose.animation.AnimatedVisibility(
                        visible = objectiveDrawerOpen,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        Column(
                            modifier = Modifier
                                .widthIn(min = 160.dp, max = 205.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(HudInkDark.copy(alpha = 0.92f))
                                .border(1.4.dp, GoldAccent.copy(alpha = 0.58f), RoundedCornerShape(14.dp))
                                .padding(10.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            for (obj in state.objectives) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = if (obj.completed) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                                        contentDescription = null,
                                        tint = if (obj.completed) GrassGreen else GoldAccent,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Spacer(Modifier.width(6.dp))
                                    Column {
                                        Text(
                                            text = obj.titleZh,
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                                            color = if (obj.completed) GrassGreen else Color.White
                                        )
                                        Text(
                                            text = obj.progressText,
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                            color = HudDimText
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // BOTTOM SKILL BAR: BottomStart on portrait phones (zero clash with Action Arc!) / BottomCenter on wide screens
        val inspectedSlot = state.activeMoves.firstOrNull { it.moveId == inspectedMoveId }
        val leftSafeWidth = (maxWidth - actionArcSize - edgePad * 2 - 8.dp).coerceAtLeast(188.dp)
        Column(
            modifier = Modifier
                .align(if (isNarrowForCenteredSkills) Alignment.BottomStart else Alignment.BottomCenter)
                .testTag("hud_skill_bar")
                .navigationBarsPadding()
                .padding(
                    start = if (isNarrowForCenteredSkills) edgePad else 0.dp,
                    bottom = if (isCompact) 12.dp else 14.dp
                )
                .then(
                    if (isNarrowForCenteredSkills) Modifier.widthIn(max = leftSafeWidth)
                    else Modifier
                ),
            horizontalAlignment = if (isNarrowForCenteredSkills) Alignment.Start else Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            AnimatedVisibility(
                visible = inspectedSlot != null,
                enter = fadeIn(tween(150)) + expandVertically(expandFrom = Alignment.Bottom),
                exit = fadeOut(tween(140)) + shrinkVertically(shrinkTowards = Alignment.Bottom)
            ) {
                if (inspectedSlot != null) {
                    MoveQuickTooltip(
                        slot = inspectedSlot,
                        onDismiss = { inspectedMoveId = null }
                    )
                }
            }

            state.nearSynergyHintZh?.let { hint ->
                Box(
                    modifier = Modifier
                        .testTag("hud_synergy_tracker")
                        .clip(RoundedCornerShape(50))
                        .background(HudInkDark.copy(alpha = 0.86f))
                        .border(1.2.dp, GoldAccent.copy(alpha = 0.80f), RoundedCornerShape(50))
                        .padding(horizontal = 9.dp, vertical = 3.dp)
                ) {
                    Text(
                        text = hint,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (isCompact) 9.5.sp else 10.sp),
                        color = GoldAccent,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            if (state.activeVitamins.isNotEmpty() || state.activeSynergyCount > 0 || state.fusedMoveCount > 0 || state.overclockedMoveCount > 0 || state.activeBonds.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
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
                                color = EspressoDark
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
                                color = EspressoDark
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
                                color = Color.White
                            )
                        }
                    }
                    state.activeBonds.take(2).forEach { bond ->
                        ElementalBondMiniChip(bond = bond)
                    }
                    state.activeVitamins.take(if (state.activeBonds.isNotEmpty()) 2 else 3).forEach { (shortName, lv) ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(HudInkDark.copy(alpha = 0.84f))
                                .border(1.dp, DarkButtonRim, RoundedCornerShape(8.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text(
                                text = "$shortName+$lv",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                color = CreamSurface
                            )
                        }
                    }
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(skillSpacing),
                verticalAlignment = Alignment.CenterVertically
            ) {
                for (idx in 0 until state.maxMoveSlots) {
                    val slot = state.activeMoves.getOrNull(idx)
                    SkillSlotTile(
                        slot = slot,
                        slotSize = skillSlotSize,
                        selected = slot != null && slot.moveId == inspectedMoveId,
                        onClick = slot?.let { active ->
                            {
                                inspectedMoveId = if (inspectedMoveId == active.moveId) null else active.moveId
                            }
                        }
                    )
                }
            }
        }

        // BOTTOM-RIGHT: Responsive Action Arc (Dash, Jump, Ult, Contextual Interact)
        HudActionArc(
            state = state,
            actionArcSize = actionArcSize,
            ultSize = ultSize,
            dashSize = dashSize,
            jumpSize = jumpSize,
            interactSize = interactSize,
            isCompact = isCompact,
            interactPulse = interactPulse,
            onInteractClick = onInteractClick,
            onDashClick = onDashClick,
            onJumpClick = onJumpClick,
            onUltClick = onUltClick,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = edgePad, bottom = if (isCompact) 10.dp else 14.dp)
        )
    }
}

private val JOY_RING_STROKE = Stroke(width = 4.5f)
private val JOY_CENTER_STROKE = Stroke(width = 2f)
private val JOY_THUMB_STROKE = Stroke(width = 3.5f)
private val LOW_HP_VIGNETTE_COLORS = listOf(Color.Transparent, CrimsonRed)

@Composable
private fun LowHpHeartbeatVignette() {
    val transition = rememberInfiniteTransition(label = "low_hp_vignette")
    val alphaState = transition.animateFloat(
        initialValue = 0.08f,
        targetValue = 0.34f,
        animationSpec = infiniteRepeatable(tween(650), RepeatMode.Reverse),
        label = "low_hp_alpha"
    )
    val brushCache = remember {
        object {
            var w = -1f
            var h = -1f
            var brush: Brush? = null
        }
    }
    Canvas(modifier = Modifier.fillMaxSize()) {
        val alpha = alphaState.value
        if (size.width != brushCache.w || size.height != brushCache.h) {
            brushCache.w = size.width
            brushCache.h = size.height
            brushCache.brush = Brush.radialGradient(
                colors = LOW_HP_VIGNETTE_COLORS,
                center = Offset(size.width / 2f, size.height / 2f),
                radius = maxOf(size.width, size.height) * 0.65f
            )
        }
        brushCache.brush?.let { drawRect(brush = it, size = size, alpha = alpha) }
    }
}

@Composable
private fun VirtualJoystickOverlay(
    accentColor: Color,
    onJoystickChange: (Float, Float) -> Unit,
    modifier: Modifier = Modifier
) {
    val originState = remember { mutableStateOf<Offset?>(null) }
    val thumbState = remember { mutableStateOf<Offset?>(null) }

    Box(
        modifier = modifier.pointerInput(Unit) {
            detectDragGestures(
                onDragStart = { startOffset ->
                    originState.value = startOffset
                    thumbState.value = startOffset
                },
                onDrag = { change, _ ->
                    val origin = originState.value ?: return@detectDragGestures
                    val maxRadius = 115f
                    val dx = change.position.x - origin.x
                    val dy = change.position.y - origin.y
                    val dist = hypot(dx, dy)
                    val clamped = if (dist > maxRadius) {
                        Offset(origin.x + dx / dist * maxRadius, origin.y + dy / dist * maxRadius)
                    } else {
                        change.position
                    }
                    thumbState.value = clamped
                    onJoystickChange((clamped.x - origin.x) / maxRadius, (clamped.y - origin.y) / maxRadius)
                },
                onDragEnd = {
                    originState.value = null
                    thumbState.value = null
                    onJoystickChange(0f, 0f)
                },
                onDragCancel = {
                    originState.value = null
                    thumbState.value = null
                    onJoystickChange(0f, 0f)
                }
            )
        }
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val origin = originState.value ?: return@Canvas
            val thumb = thumbState.value ?: return@Canvas
            drawCircle(HudInkDark.copy(alpha = 0.34f), 112f, origin)
            drawCircle(accentColor.copy(alpha = 0.72f), 112f, origin, style = JOY_RING_STROKE)
            drawCircle(CreamSurface.copy(alpha = 0.22f), 18f, origin, style = JOY_CENTER_STROKE)
            drawLine(accentColor.copy(alpha = 0.65f), origin, thumb, strokeWidth = 6f, cap = StrokeCap.Round)
            drawCircle(CreamSurface.copy(alpha = 0.94f), 40f, thumb)
            drawCircle(DarkButtonRim, 40f, thumb, style = JOY_THUMB_STROKE)
        }
    }
}

