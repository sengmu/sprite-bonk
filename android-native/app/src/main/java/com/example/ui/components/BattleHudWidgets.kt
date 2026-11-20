package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.KeyboardDoubleArrowUp
import androidx.compose.material.icons.rounded.MonetizationOn
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.engine.ActiveMoveSlot
import com.example.game.engine.BattleRenderState
import com.example.game.engine.WorldPropKind
import com.example.game.model.ElementalBondId
import com.example.game.model.GameCatalog
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonDeep
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.EspressoInk
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import com.example.ui.theme.WarmOrangeDeep
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Unified dark-glass telemetry capsule merging Kills, Coins, and Chests
 * into a single sleek strip to cut horizontal clutter on compact screens.
 */
@Composable
fun UnifiedResourceStrip(
    kills: Int,
    coins: Int,
    chestsOpened: Int,
    compact: Boolean = false,
    modifier: Modifier = Modifier
) {
    val iconSize = if (compact) 11.5.dp else 13.dp
    val fontSize = if (compact) 9.5.sp else 10.5.sp
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(HudInkDark.copy(alpha = 0.84f))
            .border(1.2.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(50))
            .padding(
                horizontal = if (compact) 6.dp else 8.dp,
                vertical = if (compact) 3.5.dp else 4.5.dp
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 4.dp else 6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.Whatshot,
                contentDescription = "击败数",
                tint = WarmOrange,
                modifier = Modifier.size(iconSize)
            )
            Text(
                text = "$kills",
                style = MaterialTheme.typography.labelLarge.copy(fontSize = fontSize),
                color = Color.White,
                maxLines = 1
            )
        }
        ResourceStripDivider()
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.MonetizationOn,
                contentDescription = "金币",
                tint = GoldAccent,
                modifier = Modifier.size(iconSize)
            )
            Text(
                text = "$coins",
                style = MaterialTheme.typography.labelLarge.copy(fontSize = fontSize),
                color = Color.White,
                maxLines = 1
            )
        }
        ResourceStripDivider()
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            WoodenChestIcon(Modifier.size(if (compact) 10.5.dp else 12.dp))
            Text(
                text = "$chestsOpened",
                style = MaterialTheme.typography.labelLarge.copy(fontSize = fontSize),
                color = Color.White,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun ResourceStripDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(10.dp)
            .background(Color.White.copy(alpha = 0.18f))
    )
}

/**
 * Non-blocking quick-inspect popover displayed above the skill bar when the
 * player taps an unlocked skill slot during combat.
 */
@Composable
fun MoveQuickTooltip(
    slot: ActiveMoveSlot,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val moveDef = remember(slot.moveId) { GameCatalog.moves[slot.moveId] }
    val synergy = remember(slot.moveId) { GameCatalog.synergyForMove(slot.moveId) }
    val reqVitamin = remember(synergy?.vitaminId) {
        synergy?.let { syn -> GameCatalog.vitamins.firstOrNull { it.id == syn.vitaminId } }
    }

    Column(
        modifier = modifier
            .widthIn(min = 210.dp, max = 300.dp)
            .shadow(10.dp, RoundedCornerShape(16.dp))
            .clip(RoundedCornerShape(16.dp))
            .background(HudInkDark.copy(alpha = 0.94f))
            .border(
                width = 1.8.dp,
                color = if (slot.awakened) GoldAccent else slot.element.color.copy(alpha = 0.88f),
                shape = RoundedCornerShape(16.dp)
            )
            .clickable(onClick = onDismiss)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(slot.element.color)
                        .padding(horizontal = 6.dp, vertical = 1.5.dp)
                ) {
                    Text(
                        text = slot.element.zhName,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                        color = EspressoDark
                    )
                }
                Text(
                    text = slot.nameZh,
                    style = MaterialTheme.typography.titleSmall.copy(fontSize = 13.sp),
                    color = if (slot.awakened) GoldAccent else Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = if (slot.awakened) "★Lv.${slot.level}" else "Lv.${slot.level}",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = GoldAccent
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "CD ${"%.1f".format(slot.cooldownTotal)}s",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = HudDimText
                )
                Icon(
                    imageVector = Icons.Rounded.Close,
                    contentDescription = "关闭招式详情",
                    tint = HudDimText,
                    modifier = Modifier.size(14.dp)
                )
            }
        }

        if (moveDef != null) {
            Text(
                text = moveDef.descZh,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp, lineHeight = 14.sp),
                color = CreamSurface.copy(alpha = 0.92f),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        if (synergy != null) {
            val synergyLine = if (slot.awakened) {
                "★ 协同已觉醒：${synergy.bonusDescZh}"
            } else {
                val vitName = reqVitamin?.nameZh ?: synergy.vitaminId
                "协同配方：配「$vitName」→ ${synergy.evolvedNameZh}"
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Rounded.AutoAwesome,
                    contentDescription = null,
                    tint = GoldAccent,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = synergyLine,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = GoldAccent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * Dramatic non-blocking crimson/gold alert strip for Boss arrival, Phase 2/3 transitions,
 * and 1v1 Duel intro announcements.
 */
@Composable
fun BossAlertWarningBanner(
    text: String,
    compact: Boolean = false,
    modifier: Modifier = Modifier
) {
    val transition = rememberInfiniteTransition(label = "boss_alert_pulse")
    val borderAlpha by transition.animateFloat(
        initialValue = 0.55f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(420), RepeatMode.Reverse),
        label = "boss_alert_alpha"
    )
    Row(
        modifier = modifier
            .testTag("hud_boss_alert_banner")
            .shadow(8.dp, RoundedCornerShape(50))
            .clip(RoundedCornerShape(50))
            .background(
                Brush.horizontalGradient(
                    listOf(Color(0xF0520B1C), Color(0xF29E152E), Color(0xF0520B1C))
                )
            )
            .border(
                width = 1.8.dp,
                color = GoldAccent.copy(alpha = borderAlpha),
                shape = RoundedCornerShape(50)
            )
            .padding(
                horizontal = if (compact) 11.dp else 15.dp,
                vertical = if (compact) 3.dp else 5.dp
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Icon(
            imageVector = Icons.Rounded.Whatshot,
            contentDescription = null,
            tint = GoldAccent,
            modifier = Modifier.size(if (compact) 13.dp else 15.dp)
        )
        Text(
            text = text,
            style = MaterialTheme.typography.titleSmall.copy(fontSize = if (compact) 10.5.sp else 12.5.sp),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/**
 * Compact dark-glass Elemental Bond chip for in-battle HUD strips.
 */
@Composable
fun ElementalBondMiniChip(
    bond: ElementalBondId,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .testTag("hud_bond_${bond.name.lowercase()}")
            .clip(RoundedCornerShape(8.dp))
            .background(HudInkDark.copy(alpha = 0.88f))
            .border(1.2.dp, bond.accentColor.copy(alpha = 0.90f), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(
            text = bond.shortBadgeZh,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
            color = bond.accentColor,
            maxLines = 1
        )
    }
}

/**
 * Guardian Boss HP Bar with glossy fill, pulsing Phase 2/3 & Stagger rims,
 * and 25% / 50% / 75% phase ticks.
 */
@Composable
fun BossHealthBar(
    bossTag: String,
    bossName: String,
    hpRatio: Float,
    bossPhase: Int = 1,
    isStaggered: Boolean = false,
    compact: Boolean = false,
    modifier: Modifier = Modifier
) {
    val animBossHp by animateFloatAsState(
        targetValue = hpRatio.coerceIn(0f, 1f),
        animationSpec = tween(150),
        label = "boss_hp"
    )
    val shouldPulseRim = isStaggered || bossPhase >= 2
    val rimPulseAlpha = if (shouldPulseRim) {
        val transition = rememberInfiniteTransition(label = "boss_rim_pulse")
        val a by transition.animateFloat(
            initialValue = 0.50f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(460), RepeatMode.Reverse),
            label = "boss_rim_alpha"
        )
        a
    } else {
        0.72f
    }
    val rimColor = when {
        isStaggered -> Color(0xFF66F6FF).copy(alpha = rimPulseAlpha)
        bossPhase >= 3 -> Color(0xFFFF2A8A).copy(alpha = rimPulseAlpha)
        bossPhase == 2 -> GoldAccent.copy(alpha = rimPulseAlpha)
        else -> CrimsonRed.copy(alpha = rimPulseAlpha)
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .widthIn(min = if (compact) 176.dp else 196.dp, max = if (compact) 256.dp else 296.dp)
            .clip(RoundedCornerShape(if (compact) 11.dp else 14.dp))
            .background(HudInkDark.copy(alpha = 0.84f))
            .border(
                width = if (shouldPulseRim) 2.dp else 1.5.dp,
                color = rimColor,
                shape = RoundedCornerShape(if (compact) 11.dp else 14.dp)
            )
            .padding(horizontal = if (compact) 8.dp else 10.dp, vertical = if (compact) 3.5.dp else 6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(CreamSurface)
                    .border(1.dp, EspressoDark, RoundedCornerShape(50))
                    .padding(horizontal = if (compact) 5.dp else 7.dp, vertical = 1.dp)
            ) {
                Text(
                    text = bossTag,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.sp else 10.sp),
                    color = EspressoInk,
                    maxLines = 1
                )
            }
            Text(
                text = bossName,
                style = MaterialTheme.typography.titleSmall.copy(fontSize = if (compact) 11.5.sp else 13.5.sp),
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (isStaggered || bossPhase >= 2) {
                val badgeBg = when {
                    isStaggered -> Color(0xFF66F6FF)
                    bossPhase >= 3 -> Color(0xFFFF2A8A)
                    else -> WarmOrange
                }
                val badgeText = when {
                    isStaggered -> "破防+35%"
                    bossPhase >= 3 -> "P3 终焉"
                    else -> "P2 狂暴"
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(badgeBg)
                        .padding(horizontal = 5.5.dp, vertical = 1.dp)
                ) {
                    Text(
                        text = badgeText,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 8.5.sp else 9.5.sp),
                        color = if (isStaggered) EspressoDark else Color.White,
                        maxLines = 1
                    )
                }
            }
        }
        Spacer(Modifier.height(if (compact) 3.dp else 5.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (compact) 13.dp else 17.dp)
                .clip(RoundedCornerShape(50))
                .background(HudInkDark.copy(alpha = 0.95f))
                .border(1.6.dp, DarkButtonRim, RoundedCornerShape(50))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(animBossHp)
                    .background(Brush.horizontalGradient(listOf(CrimsonDeep, CrimsonRed, Color(0xFFFF7A6A))))
            )
            // Specular highlight & 25/50/75% phase ticks
            Canvas(modifier = Modifier.fillMaxSize()) {
                val fillW = size.width * animBossHp
                if (fillW > 8f) {
                    drawRect(
                        color = Color.White.copy(alpha = 0.22f),
                        topLeft = Offset(3f, 2f),
                        size = Size((fillW - 6f).coerceAtLeast(0f), size.height * 0.28f)
                    )
                }
                for (i in BOSS_HP_TICKS.indices) {
                    val x = size.width * BOSS_HP_TICKS[i]
                    drawLine(
                        color = Color.Black.copy(alpha = 0.42f),
                        start = Offset(x, 2f),
                        end = Offset(x, size.height - 2f),
                        strokeWidth = 1.6f
                    )
                }
            }
            Text(
                text = "${(hpRatio.coerceIn(0f, 1f) * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.sp else 10.5.sp),
                color = Color.White,
                modifier = Modifier.align(Alignment.Center)
            )
        }
    }
}

/**
 * Right-hand Action Arc:
 * - Smart contextual Interact button (animates in cleanly only when near a world prop)
 * - Radial cooldown Dash button for instant peripheral readability
 * - Segmented Ult button
 */
@Composable
fun HudActionArc(
    state: BattleRenderState,
    actionArcSize: Dp,
    ultSize: Dp,
    dashSize: Dp,
    jumpSize: Dp,
    interactSize: Dp,
    isCompact: Boolean,
    interactPulse: Float,
    onInteractClick: () -> Unit,
    onDashClick: () -> Unit,
    onJumpClick: () -> Unit,
    onUltClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactReady = state.nearbyInteractKind != null
    val interactMeta = when (state.nearbyInteractKind) {
        WorldPropKind.WOODEN_CHEST -> Triple(
            "开箱",
            Icons.Rounded.CardGiftcard,
            listOf(Color(0xFFFFD15C), WarmOrange, WarmOrangeDeep)
        )
        WorldPropKind.HEAL_SHRINE -> Triple(
            "祈福",
            Icons.Rounded.Favorite,
            listOf(Color(0xFFD98BFF), Color(0xFF9E4CE8), Color(0xFF6B28B5))
        )
        WorldPropKind.GAMBLE_SHRINE -> Triple(
            "试炼",
            Icons.Rounded.Casino,
            listOf(Color(0xFFFF7A6A), CrimsonRed, CrimsonDeep)
        )
        WorldPropKind.MAGNET_OBELISK -> Triple(
            "磁吸",
            Icons.Rounded.AutoFixHigh,
            listOf(Color(0xFF8EF4FF), SkyBlue, Color(0xFF2B7BB9))
        )
        WorldPropKind.BOSS_PORTAL -> Triple(
            "迎战",
            Icons.Rounded.Whatshot,
            listOf(Color(0xFFFF6B8A), CrimsonRed, Color(0xFF6B0F2B))
        )
        WorldPropKind.FUSION_MACHINE -> Triple(
            "融合",
            Icons.Rounded.AutoAwesome,
            listOf(Color(0xFF7BE8FF), Color(0xFF26A6D1), GoldAccent)
        )
        null -> Triple(
            "互动",
            Icons.Rounded.TouchApp,
            listOf(Color(0xFFFFC04D), WarmOrange, WarmOrangeDeep)
        )
    }

    Box(modifier = modifier.size(actionArcSize)) {
        // Smart contextual Interact button: pops in with spring scale when near an interactable prop
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(top = 2.dp, start = if (isCompact) 12.dp else 16.dp)
        ) {
            AnimatedVisibility(
                visible = interactReady,
                enter = fadeIn(tween(150)) + scaleIn(spring(dampingRatio = 0.62f, stiffness = 480f), initialScale = 0.65f),
                exit = fadeOut(tween(140)) + scaleOut(tween(140), targetScale = 0.72f)
            ) {
                val (label, icon, colors) = interactMeta
                Box(
                    modifier = Modifier
                        .testTag("interact_action_button")
                        .minimumInteractiveComponentSize()
                        .scale(interactPulse)
                        .size(interactSize)
                        .shadow(8.dp, CircleShape)
                        .clip(CircleShape)
                        .background(Brush.verticalGradient(colors))
                        .border(2.8.dp, CreamSurface, CircleShape)
                        .clickable(onClick = onInteractClick),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = icon,
                            contentDescription = label,
                            tint = Color.White,
                            modifier = Modifier.size(19.dp)
                        )
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                            color = Color.White,
                            maxLines = 1
                        )
                    }
                }
            }
        }

        // Dash button with radial circular cooldown progress arc
        val dashReady = state.dashCooldownRatio <= 0.01f
        val dashProgress = (1f - state.dashCooldownRatio).coerceIn(0f, 1f)
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(bottom = 4.dp, start = 2.dp)
                .testTag("dash_action_button")
                .minimumInteractiveComponentSize()
                .size(dashSize)
                .shadow(if (dashReady) 6.dp else 2.dp, CircleShape)
                .clip(CircleShape)
                .background(
                    Brush.verticalGradient(
                        if (dashReady) listOf(Color(0xFFAEE262), GrassGreen, GrassGreenDeep)
                        else listOf(Color(0xFF3E523A), Color(0xFF283726))
                    )
                )
                .border(2.6.dp, if (dashReady) DarkButtonRim else HudInkDark, CircleShape)
                .clickable(enabled = dashReady, onClick = onDashClick),
            contentAlignment = Alignment.Center
        ) {
            if (!dashReady) {
                Canvas(modifier = Modifier.fillMaxSize().padding(3.dp)) {
                    val strokeW = 3.5.dp.toPx()
                    drawArc(
                        color = Color.White.copy(alpha = 0.14f),
                        startAngle = -90f,
                        sweepAngle = 360f,
                        useCenter = false,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                    drawArc(
                        color = Color(0xFFAEE262),
                        startAngle = -90f,
                        sweepAngle = 360f * dashProgress,
                        useCenter = false,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.AutoMirrored.Rounded.DirectionsRun,
                    contentDescription = "闪避冲刺",
                    tint = if (dashReady) Color.White else Color.White.copy(alpha = 0.72f),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = if (dashReady) "闪避" else "${"%.1f".format(state.dashCooldownRatio * 2.4f)}s",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = if (dashReady) Color.White else CreamSurface.copy(alpha = 0.86f),
                    maxLines = 1
                )
            }
        }

        // Tactile 2.5D Jump -> Air Glide -> Drop Slam Button
        val jumpGroundReady = !state.isJumping && state.jumpCooldownRatio <= 0.01f
        val jumpInteractive = jumpGroundReady || state.isJumping
        val jumpProgress = (1f - state.jumpCooldownRatio).coerceIn(0f, 1f)
        val jumpGradient = when {
            state.isGliding -> listOf(Color(0xFFFFC857), WarmOrange, WarmOrangeDeep)
            state.isJumping -> listOf(Color(0xFF9DF7FF), Color(0xFF39C6E8), GoldAccent)
            jumpGroundReady -> listOf(Color(0xFF7BE8FF), SkyBlue, Color(0xFF2B6EC4))
            else -> listOf(Color(0xFF334A5E), Color(0xFF213140))
        }
        val jumpLabel = when {
            state.isGliding -> "坠击"
            state.isJumping -> "滑翔"
            else -> "跳跃"
        }
        val jumpDesc = when {
            state.isGliding -> "取消滑翔快速坠击"
            state.isJumping -> "展开滑翔翼"
            else -> "跳跃登台"
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 2.dp, end = 6.dp)
                .testTag("jump_action_button")
                .minimumInteractiveComponentSize()
                .size(jumpSize)
                .shadow(if (jumpInteractive) 6.dp else 2.dp, CircleShape)
                .clip(CircleShape)
                .background(Brush.verticalGradient(jumpGradient))
                .border(
                    width = if (state.isJumping) 2.6.dp else 2.2.dp,
                    color = if (state.isJumping) CreamSurface else if (jumpGroundReady) DarkButtonRim else HudInkDark,
                    shape = CircleShape
                )
                .clickable(enabled = jumpInteractive, onClick = onJumpClick),
            contentAlignment = Alignment.Center
        ) {
            if (!jumpInteractive) {
                Canvas(modifier = Modifier.fillMaxSize().padding(3.dp)) {
                    val strokeW = 3.dp.toPx()
                    drawArc(
                        color = Color.White.copy(alpha = 0.14f),
                        startAngle = -90f,
                        sweepAngle = 360f,
                        useCenter = false,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                    drawArc(
                        color = Color(0xFF7BE8FF),
                        startAngle = -90f,
                        sweepAngle = 360f * jumpProgress,
                        useCenter = false,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = if (state.isGliding) Icons.Rounded.Bolt else Icons.Rounded.KeyboardDoubleArrowUp,
                    contentDescription = jumpDesc,
                    tint = if (jumpInteractive) Color.White else Color.White.copy(alpha = 0.72f),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = jumpLabel,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = if (jumpInteractive) Color.White else CreamSurface.copy(alpha = 0.84f),
                    maxLines = 1
                )
            }
        }

        // Crisp 2.5D aerial hint badge when jumping/gliding
        AnimatedVisibility(
            visible = state.isJumping || state.isGliding,
            enter = fadeIn(tween(120)) + scaleIn(initialScale = 0.85f),
            exit = fadeOut(tween(120)),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = jumpSize + 2.dp, end = 0.dp)
        ) {
            Box(
                modifier = Modifier
                    .testTag("hud_aerial_hint_pill")
                    .clip(RoundedCornerShape(50))
                    .background(HudInkDark.copy(alpha = 0.90f))
                    .border(
                        width = 1.2.dp,
                        color = if (state.isGliding) GoldAccent else SkyBlue,
                        shape = RoundedCornerShape(50)
                    )
                    .padding(horizontal = 7.dp, vertical = 2.dp)
            ) {
                Text(
                    text = if (state.isGliding) "滑翔中·再点坠击!" else "空中·再点滑翔",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp),
                    color = if (state.isGliding) GoldAccent else Color(0xFF9DF7FF),
                    maxLines = 1
                )
            }
        }

        // Segmented Ult Button
        SegmentedUltButton(
            charge = state.ultCharge,
            ultNameZh = state.ultNameZh,
            onClick = onUltClick,
            size = ultSize,
            modifier = Modifier.align(Alignment.BottomEnd)
        )
    }
}

private val BOSS_HP_TICKS = floatArrayOf(0.25f, 0.50f, 0.75f)
private val MINIMAP_RIM_STROKE = Stroke(1.8f)
private val MINIMAP_GRID_STROKE = Stroke(1f)
private val MINIMAP_BOSS_STROKE = Stroke(1.2f)

/**
 * Circular radar minimap showing props, enemies, pulsing boss indicator,
 * and player heading chevron. Reads [stateProvider] strictly inside [Canvas]
 * so radar blips update at full 60fps in the draw phase with zero recompositions.
 */
@Composable
fun CircularMinimap(
    stateProvider: () -> BattleRenderState,
    mapSize: Dp = 80.dp,
    modifier: Modifier = Modifier
) {
    val arrowPath = remember { Path() }
    Box(
        modifier = modifier
            .size(mapSize)
            .shadow(5.dp, CircleShape)
            .clip(CircleShape)
            .background(HudInkDark.copy(alpha = 0.86f))
            .border(1.6.dp, Color.White.copy(alpha = 0.22f), CircleShape)
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val state = stateProvider()
            val center = Offset(size.width / 2f, size.height / 2f)
            val mapRadius = size.width / 2f - 4.5f
            val worldScale = mapRadius / 780f

            // Subtle radar rings, inner bezel & crosshairs
            drawCircle(DarkButtonRim.copy(alpha = 0.55f), mapRadius + 1.5f, center, style = MINIMAP_RIM_STROKE)
            drawCircle(Color.White.copy(alpha = 0.10f), mapRadius * 0.84f, center, style = MINIMAP_GRID_STROKE)
            drawCircle(Color.White.copy(alpha = 0.14f), mapRadius * 0.46f, center, style = MINIMAP_GRID_STROKE)
            drawLine(Color.White.copy(alpha = 0.10f), Offset(center.x, 5f), Offset(center.x, size.height - 5f), 1f)
            drawLine(Color.White.copy(alpha = 0.10f), Offset(5f, center.y), Offset(size.width - 5f, center.y), 1f)

            // Subtle high-ground plateau silhouettes on radar
            val plateaus = state.terrainPlateaus
            for (i in plateaus.indices) {
                val p = plateaus[i]
                val dx = (p.x - state.playerX) * worldScale
                val dy = (p.y - state.playerY) * worldScale
                if (hypot(dx, dy) > mapRadius - 2f) continue
                val prx = (p.rx * worldScale).coerceAtLeast(3.5f)
                val pry = (p.ry * worldScale).coerceAtLeast(2.5f)
                drawOval(
                    color = GrassGreen.copy(alpha = 0.24f),
                    topLeft = Offset(center.x + dx - prx, center.y + dy - pry),
                    size = Size(prx * 2f, pry * 2f)
                )
            }

            val props = state.props
            for (i in props.indices) {
                val prop = props[i]
                if (prop.opened) continue
                val dx = (prop.x - state.playerX) * worldScale
                val dy = (prop.y - state.playerY) * worldScale
                val d = hypot(dx, dy)
                val clamped = if (d > mapRadius - 3.5f) {
                    Offset(center.x + dx / d * (mapRadius - 3.5f), center.y + dy / d * (mapRadius - 3.5f))
                } else {
                    Offset(center.x + dx, center.y + dy)
                }
                val col = when (prop.kind) {
                    WorldPropKind.WOODEN_CHEST -> Color(0xFFFFC83A)
                    WorldPropKind.HEAL_SHRINE -> Color(0xFFC25AFF)
                    WorldPropKind.GAMBLE_SHRINE -> CrimsonRed
                    WorldPropKind.MAGNET_OBELISK -> SkyBlue
                    WorldPropKind.BOSS_PORTAL -> Color(0xFFFF2A5A)
                    WorldPropKind.FUSION_MACHINE -> Color(0xFF5CF6FF)
                }
                if (prop.kind == WorldPropKind.BOSS_PORTAL) {
                    drawCircle(Color(0xFFFF2A5A).copy(alpha = 0.34f), 7.5f, clamped)
                    drawCircle(col, 4.4f, clamped)
                    drawCircle(GoldAccent, 4.4f, clamped, style = MINIMAP_BOSS_STROKE)
                } else {
                    drawCircle(col, 3.6f, clamped)
                }
            }

            val enemies = state.enemies
            for (i in enemies.indices) {
                val e = enemies[i]
                val dx = (e.x - state.playerX) * worldScale
                val dy = (e.y - state.playerY) * worldScale
                val d = hypot(dx, dy)
                if (d > mapRadius - 2f && !e.isBoss) continue
                val pt = if (d > mapRadius - 3.5f) {
                    Offset(center.x + dx / d * (mapRadius - 3.5f), center.y + dy / d * (mapRadius - 3.5f))
                } else {
                    Offset(center.x + dx, center.y + dy)
                }
                if (e.isBoss) {
                    drawCircle(Color(0xFFFF2A4A).copy(alpha = 0.32f), 9.5f, pt)
                    drawCircle(Color(0xFFFF2A4A), 5.2f, pt)
                    drawCircle(Color.White, 5.2f, pt, style = MINIMAP_BOSS_STROKE)
                } else {
                    val col = if (e.isElite) Color(0xFFFF8A2A) else Color(0xFFFF7A88).copy(alpha = 0.72f)
                    drawCircle(col, if (e.isElite) 3.4f else 2.1f, pt)
                }
            }

            // Player directional arrow + center dot (reusing Path)
            val rad = state.facingAngle
            val tipX = center.x + cos(rad) * 8.5f
            val tipY = center.y + sin(rad) * 8.5f
            val leftX = center.x + cos(rad + 2.35f) * 5.2f
            val leftY = center.y + sin(rad + 2.35f) * 5.2f
            val rightX = center.x + cos(rad - 2.35f) * 5.2f
            val rightY = center.y + sin(rad - 2.35f) * 5.2f
            arrowPath.reset()
            arrowPath.moveTo(tipX, tipY)
            arrowPath.lineTo(leftX, leftY)
            arrowPath.lineTo(rightX, rightY)
            arrowPath.close()
            drawPath(arrowPath, color = GrassGreen)
            drawCircle(Color.White, 2.2f, center)
        }
    }
}
