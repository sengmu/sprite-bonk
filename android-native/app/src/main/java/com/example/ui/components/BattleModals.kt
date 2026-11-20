package com.example.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Medication
import androidx.compose.material.icons.rounded.PauseCircle
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Radar
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.engine.BuildStatsSnapshot
import com.example.game.engine.DraftOption
import com.example.game.engine.DraftOptionKind
import com.example.game.evolution.EvolutionVisualStyle
import com.example.game.model.BossRelicId
import com.example.game.model.ElementalBondId
import com.example.game.model.MoveArchetype
import com.example.game.model.Rarity
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CreamSurfaceWarm
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.EspressoInk
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.MutedInk
import com.example.ui.theme.SandstoneRim
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Full-Screen Level-Up & Evolution Draft Modal:
 * Showcases 3 Evolution Form / Skill / Vitamin upgrade cards with animated previews,
 * rarity glow accents, clear tap-to-claim CTA footers, and Reroll / Skip / Banish controls.
 */
@Composable
fun LevelUpDraftModal(
    level: Int,
    options: List<DraftOption>,
    activeBonds: List<ElementalBondId> = emptyList(),
    rerollsLeft: Int,
    skipsLeft: Int,
    banishesLeft: Int,
    banishModeArmed: Boolean,
    onSelect: (String) -> Unit,
    onReroll: () -> Unit,
    onSkip: () -> Unit,
    onToggleBanish: () -> Unit
) {
    val hasEvolutionChoice = remember(options) {
        options.any { it.optionKind == DraftOptionKind.EVOLUTION_FORM }
    }
    val modalGlowTransition = rememberInfiniteTransition(label = "level_up_modal_glow")
    val glowPulse by modalGlowTransition.animateFloat(
        initialValue = 0f,
        targetValue = 6.283f,
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "modal_glow_phase"
    )

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .testTag("level_up_fullscreen_modal")
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        when {
                            banishModeArmed -> Color(0xE83D151B)
                            hasEvolutionChoice -> Color(0xE82D1E47)
                            else -> Color(0xE21A1830)
                        },
                        Color(0xEE0D0B1B)
                    )
                )
            )
            .clickable(enabled = false) {},
        contentAlignment = Alignment.Center
    ) {
        // Celebratory starlight & aura glow behind cards
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = Offset(size.width * 0.5f, size.height * 0.44f)
            val rayRadius = maxOf(size.width, size.height) * 0.65f
            val glowColor = when {
                banishModeArmed -> CrimsonRed
                hasEvolutionChoice -> GoldAccent
                else -> SkyBlue
            }
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(glowColor.copy(alpha = 0.22f), Color.Transparent),
                    center = center,
                    radius = rayRadius
                ),
                radius = rayRadius,
                center = center
            )
            for (i in 0 until 14) {
                val angle = glowPulse * 0.35f + i * (2f * PI.toFloat() / 14f)
                val dist = size.minDimension * (0.30f + (i % 4) * 0.14f)
                val sx = center.x + cos(angle) * dist
                val sy = center.y + sin(angle) * dist * 0.72f
                val alpha = 0.22f + 0.28f * (0.5f + 0.5f * sin(glowPulse * 1.6f + i))
                drawCircle(glowColor.copy(alpha = alpha), (2.4f + (i % 3)).dp.toPx(), Offset(sx, sy))
            }
        }

        val isLandscape = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
        val isWideDraft = isLandscape || maxWidth >= 580.dp
        val isShortViewport = maxHeight < 460.dp
        val isVeryShort = maxHeight < 400.dp
        val sectionGap = when {
            isVeryShort -> 5.dp
            isShortViewport -> 7.dp
            else -> 12.dp
        }
        val previewBoxSize = when {
            isVeryShort -> 40.dp
            isShortViewport -> 48.dp
            else -> 66.dp
        }
        val cardContentPad = when {
            isVeryShort -> PaddingValues(horizontal = 8.dp, vertical = 6.dp)
            isShortViewport -> PaddingValues(horizontal = 10.dp, vertical = 8.dp)
            else -> PaddingValues(14.dp)
        }
        val cardItemGap = when {
            isVeryShort -> 3.dp
            isShortViewport -> 4.dp
            else -> 7.dp
        }
        val footerBtnHeight = when {
            isVeryShort -> 38.dp
            isShortViewport -> 40.dp
            else -> 46.dp
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 12.dp, vertical = 6.dp)
                .widthIn(max = if (isWideDraft) 900.dp else 560.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(sectionGap)
        ) {
            // Header Ribbon
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(
                            Brush.horizontalGradient(
                                when {
                                    banishModeArmed -> listOf(CrimsonRed, Color(0xFFFF6A5E))
                                    hasEvolutionChoice -> listOf(Color(0xFFFF8A2B), GoldAccent, Color(0xFFFFE57F))
                                    else -> listOf(WarmOrange, GoldAccent)
                                }
                            )
                        )
                        .border(2.5.dp, DarkButtonRim, RoundedCornerShape(50))
                        .padding(
                            horizontal = if (isShortViewport) 18.dp else 24.dp,
                            vertical = if (isShortViewport) 4.dp else 7.dp
                        )
                ) {
                    Text(
                        text = when {
                            banishModeArmed -> "放逐模式：点击一项移出本局奖池"
                            hasEvolutionChoice -> "★ 升级突破 Lv.$level · 进化形态或技能强化"
                            else -> "升级强化！Lv.$level 选择一项提升"
                        },
                        style = if (isShortViewport) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleLarge,
                        color = if (banishModeArmed) Color.White else EspressoDark,
                        textAlign = TextAlign.Center
                    )
                }
                if (!isShortViewport) {
                    Text(
                        text = when {
                            banishModeArmed -> "进化形态不可放逐，点击下方红色按钮可退出放逐模式"
                            hasEvolutionChoice -> "点击下方卡片领取奖励 · 含专属进化形态突破"
                            else -> "点击任意强化卡片立即生效"
                        },
                        style = MaterialTheme.typography.labelMedium,
                        color = CreamSurface.copy(alpha = 0.86f),
                        textAlign = TextAlign.Center
                    )
                }
                if (activeBonds.isNotEmpty()) {
                    ActiveBondsStrip(activeBonds = activeBonds, compact = isShortViewport)
                }
            }

            if (isWideDraft) {
                // Wide screen: 3-column showcase cards side by side
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Max),
                    horizontalArrangement = Arrangement.spacedBy(if (isShortViewport) 10.dp else 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    options.forEachIndexed { index, opt ->
                        DraftCardWide(
                            opt = opt,
                            index = index,
                            isFeatured = opt.optionKind == DraftOptionKind.EVOLUTION_FORM ||
                                opt.rarity == Rarity.LEGENDARY || opt.rarity == Rarity.EPIC || index == options.size / 2,
                            banishModeArmed = banishModeArmed,
                            isShortViewport = isShortViewport,
                            previewBoxSize = previewBoxSize,
                            cardContentPad = cardContentPad,
                            cardItemGap = cardItemGap,
                            onSelect = { onSelect(opt.id) },
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                }
            } else {
                // Portrait phone: sleek stacked horizontal cards
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    options.forEachIndexed { index, opt ->
                        DraftCardCompact(
                            opt = opt,
                            index = index,
                            isFeatured = opt.optionKind == DraftOptionKind.EVOLUTION_FORM ||
                                opt.rarity == Rarity.LEGENDARY || opt.rarity == Rarity.EPIC,
                            banishModeArmed = banishModeArmed,
                            onSelect = { onSelect(opt.id) }
                        )
                    }
                }
            }

            // Bottom utility pills: Reroll / Skip / Banish
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .widthIn(max = 520.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ChunkyButton(
                    text = "重抽 ($rerollsLeft)",
                    onClick = onReroll,
                    tone = ChunkyButtonTone.BLUE,
                    icon = Icons.Rounded.Casino,
                    enabled = rerollsLeft > 0,
                    height = footerBtnHeight,
                    testTag = "draft_reroll_btn",
                    modifier = Modifier.weight(1f)
                )
                ChunkyButton(
                    text = "跳过 ($skipsLeft)",
                    onClick = onSkip,
                    tone = ChunkyButtonTone.CREAM,
                    icon = Icons.Rounded.FastForward,
                    enabled = skipsLeft > 0,
                    height = footerBtnHeight,
                    testTag = "draft_skip_btn",
                    modifier = Modifier.weight(1f)
                )
                ChunkyButton(
                    text = if (banishModeArmed) "取消" else "放逐 ($banishesLeft)",
                    onClick = onToggleBanish,
                    tone = ChunkyButtonTone.RED,
                    icon = Icons.Rounded.Block,
                    enabled = banishesLeft > 0,
                    height = footerBtnHeight,
                    testTag = "draft_banish_btn",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun DraftCardWide(
    opt: DraftOption,
    index: Int,
    isFeatured: Boolean,
    banishModeArmed: Boolean,
    isShortViewport: Boolean,
    previewBoxSize: Dp,
    cardContentPad: PaddingValues,
    cardItemGap: Dp,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isEvo = opt.optionKind == DraftOptionKind.EVOLUTION_FORM
    val cardBorder = when {
        banishModeArmed && !isEvo -> CrimsonRed
        isEvo -> opt.evolutionVisualStyle?.auraColor ?: GoldAccent
        isFeatured -> GoldAccent
        else -> opt.rarity.color
    }
    DarkGlassPanel(
        modifier = modifier
            .testTag("draft_option_$index")
            .offset(y = if (isFeatured && !isShortViewport) (-5).dp else 0.dp)
            .clickable(onClick = onSelect),
        cornerRadius = if (isShortViewport) 18.dp else 22.dp,
        borderColor = cardBorder.copy(alpha = if (isEvo || isFeatured || banishModeArmed) 0.95f else 0.72f),
        borderWidth = if (isEvo || isFeatured || banishModeArmed) 2.8.dp else 2.dp,
        containerColor = when {
            banishModeArmed && !isEvo -> Color(0xEC2E131B)
            isEvo -> Color(0xEC2A203B)
            isFeatured -> Color(0xEC221E36)
            else -> HudInkDark.copy(alpha = 0.91f)
        },
        contentPadding = cardContentPad
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(cardItemGap)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    DraftKindPill(kind = opt.optionKind)
                    RarityChip(rarity = opt.rarity)
                }
                DraftOptionVisualPreview(opt = opt, boxSize = previewBoxSize)
                Text(
                    text = opt.titleZh,
                    style = if (isShortViewport) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleLarge,
                    color = if (isEvo) GoldAccent else Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = opt.subtitleZh,
                    style = MaterialTheme.typography.labelMedium,
                    color = when (opt.optionKind) {
                        DraftOptionKind.EVOLUTION_FORM -> GoldAccent
                        DraftOptionKind.SKILL_UPGRADE -> opt.element?.color ?: GrassGreen
                        DraftOptionKind.VITAMIN_BOOST -> Color(0xFFFFB266)
                    },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = opt.detailZh,
                    style = if (isShortViewport) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium,
                    color = CreamSurface.copy(alpha = 0.84f),
                    maxLines = if (isShortViewport) 2 else 3,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center
                )
                opt.synergyHintZh?.let { hint ->
                    SynergyHintBadge(hint = hint, isEvo = isEvo, maxLines = if (isShortViewport) 1 else 2)
                }
            }

            Spacer(Modifier.height(if (isShortViewport) 4.dp else 6.dp))
            DraftCardActionStrip(
                isEvo = isEvo,
                banishModeArmed = banishModeArmed,
                compact = isShortViewport
            )
        }
    }
}

@Composable
private fun DraftCardCompact(
    opt: DraftOption,
    index: Int,
    isFeatured: Boolean,
    banishModeArmed: Boolean,
    onSelect: () -> Unit
) {
    val isEvo = opt.optionKind == DraftOptionKind.EVOLUTION_FORM
    val cardBorder = when {
        banishModeArmed && !isEvo -> CrimsonRed
        isEvo -> opt.evolutionVisualStyle?.auraColor ?: GoldAccent
        isFeatured -> GoldAccent
        else -> opt.rarity.color
    }
    DarkGlassPanel(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("draft_option_$index")
            .clickable(onClick = onSelect),
        cornerRadius = 22.dp,
        borderColor = cardBorder.copy(alpha = if (isEvo || isFeatured || banishModeArmed) 0.95f else 0.72f),
        borderWidth = if (isEvo || isFeatured || banishModeArmed) 2.8.dp else 2.dp,
        containerColor = when {
            banishModeArmed && !isEvo -> Color(0xEC2E131B)
            isEvo -> Color(0xEC2A203B)
            isFeatured -> Color(0xEC221E36)
            else -> HudInkDark.copy(alpha = 0.91f)
        },
        contentPadding = PaddingValues(13.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            DraftOptionVisualPreview(opt = opt, boxSize = 66.dp)

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        DraftKindPill(kind = opt.optionKind)
                        RarityChip(rarity = opt.rarity)
                    }
                    Text(
                        text = when {
                            banishModeArmed && !isEvo -> "放逐"
                            isEvo -> "突破"
                            else -> "领取"
                        },
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = when {
                            banishModeArmed && !isEvo -> Color(0xFFFF7A88)
                            isEvo -> GoldAccent
                            else -> GrassGreen
                        }
                    )
                }
                Text(
                    text = opt.titleZh,
                    style = MaterialTheme.typography.titleLarge,
                    color = if (isEvo) GoldAccent else Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = opt.subtitleZh,
                    style = MaterialTheme.typography.labelMedium,
                    color = when (opt.optionKind) {
                        DraftOptionKind.EVOLUTION_FORM -> GoldAccent
                        DraftOptionKind.SKILL_UPGRADE -> opt.element?.color ?: GrassGreen
                        DraftOptionKind.VITAMIN_BOOST -> Color(0xFFFFB266)
                    }
                )
                Text(
                    text = opt.detailZh,
                    style = MaterialTheme.typography.bodyMedium,
                    color = CreamSurface.copy(alpha = 0.84f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                opt.synergyHintZh?.let { hint ->
                    Spacer(Modifier.height(2.dp))
                    SynergyHintBadge(hint = hint, isEvo = isEvo, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun DraftCardActionStrip(
    isEvo: Boolean,
    banishModeArmed: Boolean,
    compact: Boolean = false
) {
    val bg = when {
        banishModeArmed && !isEvo -> CrimsonRed
        isEvo -> GoldAccent
        else -> GrassGreenDeep
    }
    val fg = if (isEvo && !banishModeArmed) EspressoDark else Color.White
    val label = when {
        banishModeArmed && !isEvo -> "点击放逐"
        isEvo -> "点击突破进化"
        else -> "点击领取"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 9.dp else 12.dp))
            .background(bg)
            .padding(vertical = if (compact) 3.dp else 5.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (banishModeArmed && !isEvo) Icons.Rounded.Block else Icons.Rounded.TouchApp,
            contentDescription = null,
            tint = fg,
            modifier = Modifier.size(if (compact) 11.dp else 13.dp)
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium.copy(fontSize = if (compact) 10.5.sp else 12.sp),
            color = fg,
            maxLines = 1
        )
    }
}

@Composable
private fun SynergyHintBadge(hint: String, isEvo: Boolean, maxLines: Int) {
    val accent = if (isEvo) GoldAccent else Color(0xFF7BE8FF)
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(accent.copy(alpha = 0.16f))
            .border(1.1.dp, accent.copy(alpha = 0.72f), RoundedCornerShape(8.dp))
            .padding(horizontal = 7.dp, vertical = 2.5.dp)
    ) {
        Text(
            text = hint,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
            color = if (isEvo) GoldAccent else Color(0xFFB5F4FF),
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ActiveBondsStrip(
    activeBonds: List<ElementalBondId>,
    compact: Boolean = false
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        activeBonds.take(4).forEach { bond ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(bond.accentColor.copy(alpha = 0.18f))
                    .border(1.1.dp, bond.accentColor.copy(alpha = 0.85f), RoundedCornerShape(50))
                    .padding(horizontal = if (compact) 6.dp else 8.dp, vertical = 2.dp)
            ) {
                Text(
                    text = bond.shortBadgeZh,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.sp else 10.sp),
                    color = bond.accentColor,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun DraftKindPill(kind: DraftOptionKind) {
    val (label, bg, fg) = when (kind) {
        DraftOptionKind.EVOLUTION_FORM -> Triple("✦ 进化形态", GoldAccent, EspressoDark)
        DraftOptionKind.SKILL_UPGRADE -> Triple("技能强化", GrassGreenDeep, Color.White)
        DraftOptionKind.VITAMIN_BOOST -> Triple("属性强化", WarmOrange, Color.White)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .padding(horizontal = 7.dp, vertical = 2.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
            color = fg,
            maxLines = 1
        )
    }
}

@Composable
private fun DraftOptionVisualPreview(
    opt: DraftOption,
    boxSize: Dp
) {
    when {
        opt.optionKind == DraftOptionKind.EVOLUTION_FORM && opt.evolutionVisualStyle != null -> {
            DraftEvolutionPreviewBox(style = opt.evolutionVisualStyle, boxSize = boxSize)
        }
        opt.isMove && opt.archetype != null -> {
            MoveEffectPreviewBox(
                archetype = opt.archetype,
                accentColor = opt.element?.color ?: opt.rarity.color,
                boxSize = boxSize
            )
        }
        else -> {
            DraftVitaminBadge(rarityColor = opt.rarity.color, boxSize = boxSize)
        }
    }
}

@Composable
private fun DraftEvolutionPreviewBox(
    style: EvolutionVisualStyle,
    boxSize: Dp
) {
    val corner = if (boxSize <= 48.dp) 12.dp else 16.dp
    val transition = rememberInfiniteTransition(label = "draft_evo_preview")
    val animTime by transition.animateFloat(
        initialValue = 0f,
        targetValue = 12.566371f,
        animationSpec = infiniteRepeatable(tween(6000, easing = LinearEasing), RepeatMode.Restart),
        label = "draft_evo_anim"
    )
    val orbitAngle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 6.2831855f,
        animationSpec = infiniteRepeatable(tween(3600, easing = LinearEasing), RepeatMode.Restart),
        label = "draft_evo_orbit"
    )
    Box(
        modifier = Modifier
            .size(boxSize)
            .shadow(5.dp, RoundedCornerShape(corner))
            .clip(RoundedCornerShape(corner))
            .background(Brush.radialGradient(listOf(style.auraColor.copy(alpha = 0.42f), HudInkDark)))
            .border(2.4.dp, style.auraColor, RoundedCornerShape(corner)),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawEvolvedHeroSprite(
                style = style,
                center = Offset(size.width * 0.5f, size.height * 0.56f),
                baseRadius = size.minDimension * 0.25f,
                animTime = animTime,
                orbitAngle = orbitAngle,
                facingAngle = sin(animTime * 0.5f) * 0.38f,
                moveSpeedRatio = 0f,
                isAttacking = false,
                attackProgress = 0f
            )
        }
    }
}

@Composable
private fun DraftVitaminBadge(rarityColor: Color, boxSize: Dp = 62.dp) {
    val corner = if (boxSize <= 48.dp) 12.dp else 16.dp
    Box(
        modifier = Modifier
            .size(boxSize)
            .shadow(4.dp, RoundedCornerShape(corner))
            .clip(RoundedCornerShape(corner))
            .background(Brush.verticalGradient(listOf(rarityColor, rarityColor.copy(alpha = 0.72f))))
            .border(2.2.dp, DarkButtonRim, RoundedCornerShape(corner)),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Rounded.Medication,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(boxSize * 0.48f)
        )
    }
}

@Composable
private fun MoveEffectPreviewBox(
    archetype: MoveArchetype,
    accentColor: Color,
    boxSize: Dp = 62.dp
) {
    val corner = if (boxSize <= 48.dp) 12.dp else 16.dp
    val transition = rememberInfiniteTransition(label = "move_card_preview")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1300, easing = LinearEasing), RepeatMode.Restart),
        label = "move_phase"
    )
    Box(
        modifier = Modifier
            .size(boxSize)
            .clip(RoundedCornerShape(corner))
            .background(HudInkDark)
            .border(2.2.dp, accentColor, RoundedCornerShape(corner)),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val c = Offset(size.width / 2f, size.height / 2f)
            drawCircle(Color.White.copy(alpha = 0.85f), 5.5f, c)
            when (archetype) {
                MoveArchetype.STRIKE -> {
                    val r = size.minDimension * 0.34f
                    drawArc(
                        color = accentColor,
                        startAngle = -60f + phase * 180f,
                        sweepAngle = 120f,
                        useCenter = false,
                        topLeft = Offset(c.x - r, c.y - r),
                        size = Size(r * 2f, r * 2f),
                        style = Stroke(width = 7f, cap = StrokeCap.Round)
                    )
                }
                MoveArchetype.PROJECTILE -> {
                    for (i in -1..1) {
                        val angle = -0.35f + i * 0.35f
                        val dist = 10f + phase * (size.minDimension * 0.38f)
                        val pt = Offset(c.x + cos(angle) * dist, c.y + sin(angle) * dist)
                        drawCircle(accentColor.copy(alpha = 1f - phase * 0.5f), 5f, pt)
                        drawCircle(Color.White, 2f, pt)
                    }
                }
                MoveArchetype.NOVA -> {
                    val r = 6f + phase * (size.minDimension * 0.42f)
                    drawCircle(accentColor.copy(alpha = (1f - phase) * 0.85f), r, c, style = Stroke(4.5f))
                }
                MoveArchetype.BEAM -> {
                    val len = size.width * 0.44f
                    val pulse = 0.6f + 0.4f * sin(phase * 2f * PI.toFloat())
                    drawLine(accentColor.copy(alpha = 0.45f), c, Offset(c.x + len, c.y - len * 0.35f), 12f * pulse, StrokeCap.Round)
                    drawLine(Color.White, c, Offset(c.x + len, c.y - len * 0.35f), 4f * pulse, StrokeCap.Round)
                }
                MoveArchetype.ORBIT -> {
                    val r = size.minDimension * 0.32f
                    drawCircle(accentColor.copy(alpha = 0.25f), r, c, style = Stroke(2f))
                    for (k in 0 until 3) {
                        val a = phase * 2f * PI.toFloat() + k * (2f * PI.toFloat() / 3f)
                        val pt = Offset(c.x + cos(a) * r, c.y + sin(a) * r)
                        drawCircle(accentColor, 5.5f, pt)
                        drawCircle(Color.White, 2.2f, pt)
                    }
                }
            }
        }
    }
}

/**
 * Pause Menu Modal with live build telemetry, color-coded stat cards, DPS share bars,
 * and icon-labeled toggles.
 */
@Composable
fun PauseModal(
    buildStats: BuildStatsSnapshot = BuildStatsSnapshot(),
    activeBonds: List<ElementalBondId> = emptyList(),
    activeRelics: List<BossRelicId> = emptyList(),
    autoAimEnabled: Boolean,
    sfxEnabled: Boolean,
    screenShakeEnabled: Boolean,
    onToggleAutoAim: (Boolean) -> Unit,
    onToggleSfx: (Boolean) -> Unit,
    onToggleScreenShake: (Boolean) -> Unit,
    onResume: () -> Unit,
    onAbandon: () -> Unit
) {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(HudInkDark.copy(alpha = 0.82f))
            .clickable(enabled = false) {}
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        val isShort = maxHeight < 440.dp
        val isWide = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
        DarkGlassPanel(
            modifier = Modifier
                .widthIn(min = 300.dp, max = if (isWide) 780.dp else 430.dp)
                .verticalScroll(rememberScrollState()),
            cornerRadius = if (isShort) 22.dp else 26.dp,
            borderColor = GoldAccent.copy(alpha = 0.65f),
            borderWidth = 2.4.dp,
            containerColor = HudInkDark.copy(alpha = 0.94f),
            contentPadding = PaddingValues(
                horizontal = if (isShort) 14.dp else 20.dp,
                vertical = if (isShort) 10.dp else 18.dp
            )
        ) {
            if (isWide) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(if (isShort) 6.dp else 10.dp)
                    ) {
                        PauseHeader(isShort = isShort)
                        SettingToggleRow("自动锁定最近目标", autoAimEnabled, onToggleAutoAim, icon = Icons.Rounded.GpsFixed, compact = isShort, darkTheme = true)
                        SettingToggleRow("游戏音效", sfxEnabled, onToggleSfx, icon = Icons.AutoMirrored.Rounded.VolumeUp, compact = isShort, darkTheme = true)
                        SettingToggleRow("打击画面震动", screenShakeEnabled, onToggleScreenShake, icon = Icons.Rounded.Vibration, compact = isShort, darkTheme = true)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            ChunkyButton(
                                text = "继续战斗",
                                onClick = onResume,
                                tone = ChunkyButtonTone.GREEN,
                                icon = Icons.Rounded.PlayArrow,
                                height = if (isShort) 42.dp else 46.dp,
                                testTag = "pause_resume_btn",
                                modifier = Modifier.weight(1f)
                            )
                            ChunkyButton(
                                text = "提前结算",
                                onClick = onAbandon,
                                tone = ChunkyButtonTone.RED,
                                icon = Icons.Rounded.Stop,
                                height = if (isShort) 42.dp else 46.dp,
                                testTag = "pause_abandon_btn",
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }

                    LiveBuildStatsSection(
                        buildStats = buildStats,
                        activeBonds = activeBonds,
                        activeRelics = activeRelics,
                        compact = isShort,
                        modifier = Modifier.weight(1.05f)
                    )
                }
            } else {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(if (isShort) 8.dp else 11.dp)
                ) {
                    PauseHeader(isShort = isShort)
                    LiveBuildStatsSection(
                        buildStats = buildStats,
                        activeBonds = activeBonds,
                        activeRelics = activeRelics,
                        compact = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    SettingToggleRow("自动锁定最近目标", autoAimEnabled, onToggleAutoAim, icon = Icons.Rounded.GpsFixed, darkTheme = true)
                    SettingToggleRow("游戏音效", sfxEnabled, onToggleSfx, icon = Icons.AutoMirrored.Rounded.VolumeUp, darkTheme = true)
                    SettingToggleRow("打击画面震动", screenShakeEnabled, onToggleScreenShake, icon = Icons.Rounded.Vibration, darkTheme = true)
                    ChunkyButton(
                        text = "继续战斗",
                        onClick = onResume,
                        tone = ChunkyButtonTone.GREEN,
                        icon = Icons.Rounded.PlayArrow,
                        testTag = "pause_resume_btn",
                        modifier = Modifier.fillMaxWidth()
                    )
                    ChunkyButton(
                        text = "提前结算本局",
                        onClick = onAbandon,
                        tone = ChunkyButtonTone.RED,
                        icon = Icons.Rounded.Stop,
                        testTag = "pause_abandon_btn",
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun PauseHeader(isShort: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            imageVector = Icons.Rounded.PauseCircle,
            contentDescription = null,
            tint = GoldAccent,
            modifier = Modifier.size(if (isShort) 24.dp else 30.dp)
        )
        Text(
            text = "战斗暂停",
            style = if (isShort) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineMedium,
            color = Color.White
        )
    }
}

@Composable
private fun LiveBuildStatsSection(
    buildStats: BuildStatsSnapshot,
    activeBonds: List<ElementalBondId>,
    activeRelics: List<BossRelicId> = emptyList(),
    compact: Boolean,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(16.dp))
            .padding(if (compact) 10.dp else 12.dp),
        verticalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 9.dp)
    ) {
        Text(
            text = "实时构筑属性",
            style = MaterialTheme.typography.titleMedium,
            color = GoldAccent
        )
        val statItems = listOf(
            Triple("攻击", "${buildStats.damagePct}%", Pair(Icons.Rounded.LocalFireDepartment, WarmOrange)),
            Triple("攻速", "${buildStats.atkSpdPct}%", Pair(Icons.Rounded.Bolt, GoldAccent)),
            Triple("暴击", "${buildStats.critPct}%", Pair(Icons.Rounded.AutoAwesome, Color(0xFFFF7A88))),
            Triple("移速", "${buildStats.speedPct}%", Pair(Icons.Rounded.Speed, SkyBlue)),
            Triple("范围", "${buildStats.areaPct}%", Pair(Icons.Rounded.Radar, Color(0xFFC28BFF))),
            Triple("护甲", "${buildStats.armor}", Pair(Icons.Rounded.Shield, GrassGreen))
        )
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            statItems.chunked(3).forEach { rowItems ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    rowItems.forEach { (label, value, iconPair) ->
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(11.dp))
                                .background(Color.White.copy(alpha = 0.07f))
                                .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(11.dp))
                                .padding(horizontal = 6.dp, vertical = 5.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(1.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(3.dp)
                            ) {
                                Icon(
                                    imageVector = iconPair.first,
                                    contentDescription = null,
                                    tint = iconPair.second,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(label, style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp), color = CreamSurface.copy(alpha = 0.72f))
                            }
                            Text(value, style = MaterialTheme.typography.labelLarge.copy(fontSize = 11.5.sp), color = Color.White)
                        }
                    }
                }
            }
        }

        if (activeBonds.isNotEmpty()) {
            ActiveBondsStrip(activeBonds = activeBonds, compact = true)
        }
        if (activeRelics.isNotEmpty()) {
            ActiveRelicsStrip(relics = activeRelics, compact = true)
        }

        if (buildStats.moveDamages.isNotEmpty()) {
            Text(
                text = "招式输出占比",
                style = MaterialTheme.typography.labelLarge,
                color = CreamSurface
            )
            MoveDamageBarsList(
                entries = buildStats.moveDamages.take(if (compact) 3 else 4),
                compact = compact,
                darkTheme = true
            )
        }
    }
}

@Composable
fun SettingToggleRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    icon: ImageVector? = null,
    compact: Boolean = false,
    darkTheme: Boolean = false
) {
    val bg = if (darkTheme) Color.White.copy(alpha = 0.07f) else CreamSurfaceWarm
    val rim = if (darkTheme) {
        if (checked) GrassGreen.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.14f)
    } else SandstoneRim
    val titleColor = if (darkTheme) Color.White else EspressoInk
    val iconTint = when {
        darkTheme && checked -> GrassGreen
        darkTheme -> CreamSurface.copy(alpha = 0.65f)
        checked -> GrassGreenDeep
        else -> MutedInk
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .background(bg)
            .border(1.4.dp, rim, RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .clickable { onCheckedChange(!checked) }
            .padding(horizontal = if (compact) 10.dp else 12.dp, vertical = if (compact) 2.dp else 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(if (compact) 16.dp else 18.dp)
                )
            }
            Text(
                text = title,
                style = if (compact) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium,
                color = titleColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = if (compact) Modifier.scale(0.84f) else Modifier,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = if (darkTheme) GrassGreen else GrassGreenDeep,
                uncheckedThumbColor = if (darkTheme) CreamSurface.copy(alpha = 0.80f) else Color.White,
                uncheckedTrackColor = if (darkTheme) Color.White.copy(alpha = 0.18f) else SandstoneRim.copy(alpha = 0.55f)
            )
        )
    }
}
