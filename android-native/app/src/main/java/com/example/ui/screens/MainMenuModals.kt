package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.MetaProgressionSnapshot
import com.example.game.engine.ElementalMatchup
import com.example.game.model.BiomeDef
import com.example.game.model.ChallengeModifier
import com.example.game.model.DifficultyTier
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryCalculator
import com.example.game.model.StarterLine
import com.example.ui.components.AsyncDrawableImage
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.components.StarterPortraitAvatar
import com.example.ui.components.biomeBackdropRes
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

/**
 * Dedicated Hero Roster & Build Preview Modal:
 * Consolidates all 6 Original Sprites, full passive/stats/ultimate details, and Evolution Tree jump
 * so the main lobby stays unobstructed and iconic.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HeroRosterModal(
    selected: StarterLine,
    onSelect: (String) -> Unit,
    onOpenEvolutionPreview: () -> Unit,
    onDismiss: () -> Unit
) {
    BackHandler(onBack = onDismiss)

    ModalScrimContainer(
        maxWidth = 640.dp,
        testTag = "hero_roster_modal",
        onDismiss = onDismiss
    ) { isWide ->
        ModalHeaderRow(
            title = "精灵编队 · 6只原创伙伴",
            subtitle = "点击切换出战精灵，查看被动与必杀",
            onDismiss = onDismiss
        )

        // Selected Hero Detail Highlight Banner
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(selected.element.color.copy(alpha = 0.16f))
                .border(1.5.dp, selected.element.color.copy(alpha = 0.72f), RoundedCornerShape(16.dp))
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            StarterPortraitAvatar(
                portraitRes = selected.portraitRes,
                ringColor = selected.element.color,
                size = 52.dp
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = selected.codeName,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold),
                        color = Color.White
                    )
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(selected.element.color)
                            .padding(horizontal = 7.dp, vertical = 1.dp)
                    ) {
                        Text(
                            text = "${selected.element.zhName} · ${selected.roleZh}",
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold),
                            color = EspressoDark
                        )
                    }
                }
                Text(
                    text = "被动【${selected.passiveNameZh}】${selected.passiveDescZh}",
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                    color = CreamSurface.copy(alpha = 0.92f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    ModalStatDot("生命 ${selected.baseHp.toInt()}", GrassGreen)
                    ModalStatDot("移速 ${selected.baseSpeed.toInt()}", SkyBlue)
                    ModalStatDot("攻倍 ${(selected.baseDamage * 100).toInt()}%", WarmOrange)
                    ModalStatDot("必杀 ${selected.ultStageNames.first()}", GoldAccent)
                }
            }
        }

        // Responsive 3x2 (landscape) or 2x3 (portrait) Starter Grid
        val cols = if (isWide) 3 else 2
        val rows = GameCatalog.starters.chunked(cols)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (rowItems in rows) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    for (starter in rowItems) {
                        val active = starter.id == selected.id
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .testTag("starter_select_${starter.id}")
                                .minimumInteractiveComponentSize()
                                .clip(RoundedCornerShape(14.dp))
                                .background(
                                    if (active) starter.element.color.copy(alpha = 0.24f)
                                    else Color.White.copy(alpha = 0.06f)
                                )
                                .border(
                                    width = if (active) 2.dp else 1.dp,
                                    color = if (active) starter.element.color else Color.White.copy(alpha = 0.14f),
                                    shape = RoundedCornerShape(14.dp)
                                )
                                .clickable { onSelect(starter.id) }
                                .padding(horizontal = 9.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            StarterPortraitAvatar(
                                portraitRes = starter.portraitRes,
                                ringColor = starter.element.color,
                                size = 36.dp
                            )
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = starter.codeName,
                                    style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.5.sp),
                                    color = Color.White,
                                    maxLines = 1
                                )
                                Text(
                                    text = "${starter.element.zhName} · ${starter.roleZh}",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                    color = if (active) GoldAccent else HudDimText,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            if (active) {
                                Icon(
                                    imageVector = Icons.Rounded.Check,
                                    contentDescription = "已选中",
                                    tint = GoldAccent,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        // Bottom Actions
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ChunkyButton(
                text = "查看进化树",
                onClick = {
                    onDismiss()
                    onOpenEvolutionPreview()
                },
                tone = ChunkyButtonTone.ORANGE,
                icon = Icons.Rounded.AutoAwesome,
                height = 46.dp,
                modifier = Modifier.weight(1f)
            )
            ChunkyButton(
                text = "确认出战",
                onClick = onDismiss,
                tone = ChunkyButtonTone.GREEN,
                icon = Icons.Rounded.Check,
                height = 46.dp,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

/**
 * Unified Expedition Configuration Modal:
 * Consolidates Game Modes (Classic / Survival / 1v1 Duel), Biome Selection with Boss Counter Intel,
 * Risk-Reward Challenge Modifiers with full descriptions, and Meta Mastery Permanent Bonuses.
 */
@Composable
internal fun ExpeditionConfigModal(
    meta: MetaProgressionSnapshot,
    selectedStarter: StarterLine,
    selectedMode: GameMode,
    selectedDifficulty: DifficultyTier = DifficultyTier.STANDARD,
    selectedBiomeId: String,
    selectedChallengeModifiers: Set<ChallengeModifier>,
    masteryChips: List<String>,
    onSelectMode: (GameMode) -> Unit,
    onSelectDifficulty: (DifficultyTier) -> Unit = {},
    onSelectBiome: (String) -> Unit,
    onToggleChallengeModifier: (ChallengeModifier) -> Unit,
    onStartRun: () -> Unit,
    onDismiss: () -> Unit
) {
    BackHandler(onBack = onDismiss)
    val totalChallengeDustPct = remember(selectedChallengeModifiers, selectedDifficulty) {
        MetaMasteryCalculator.combinedChallengeStardustBonusPct(selectedChallengeModifiers, selectedDifficulty)
    }

    ModalScrimContainer(
        maxWidth = 680.dp,
        testTag = "expedition_config_modal",
        onDismiss = onDismiss
    ) { isWide ->
        ModalHeaderRow(
            title = "出征配置",
            subtitle = "选择玩法模式、试炼群落与高风险词条",
            onDismiss = onDismiss
        )

        // Section 1: 3 Game Modes with clear descriptions
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ModalSectionLabel(title = "玩法模式", trailing = selectedMode.nameZh)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                for (mode in GameMode.entries) {
                    val active = mode == selectedMode
                    val tint = when (mode) {
                        GameMode.CLASSIC -> GrassGreenDeep
                        GameMode.SURVIVAL -> WarmOrange
                        GameMode.DUEL -> Color(0xFF7B4CE8)
                    }
                    val icon = when (mode) {
                        GameMode.CLASSIC -> Icons.Rounded.Flag
                        GameMode.SURVIVAL -> Icons.Rounded.Whatshot
                        GameMode.DUEL -> Icons.Rounded.Bolt
                    }
                    val desc = when (mode) {
                        GameMode.CLASSIC -> "击败守护者通关"
                        GameMode.SURVIVAL -> "无尽波次冲高分"
                        GameMode.DUEL -> "Lv.4 双选 1v1"
                    }
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .testTag("mode_select_${mode.id}")
                            .minimumInteractiveComponentSize()
                            .clip(RoundedCornerShape(13.dp))
                            .background(if (active) tint else Color.White.copy(alpha = 0.07f))
                            .border(
                                width = if (active) 2.dp else 1.dp,
                                color = if (active) GoldAccent else Color.White.copy(alpha = 0.14f),
                                shape = RoundedCornerShape(13.dp)
                            )
                            .clickable { onSelectMode(mode) }
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(icon, contentDescription = null, tint = if (active) Color.White else HudDimText, modifier = Modifier.size(14.dp))
                            Text(
                                text = mode.nameZh,
                                style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.sp, fontWeight = FontWeight.ExtraBold),
                                color = if (active) Color.White else CreamSurface,
                                maxLines = 1
                            )
                        }
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                            color = if (active) Color.White.copy(alpha = 0.90f) else HudDimText,
                            maxLines = 1
                        )
                    }
                }
            }
        }

        // Section 1.5: 3-Tier Difficulty Selector
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ModalSectionLabel(
                title = "试炼难度",
                trailing = if (selectedDifficulty.stardustBonusPct > 0) "星尘 +${selectedDifficulty.stardustBonusPct}%" else "标准倍率",
                trailingColor = if (selectedDifficulty.stardustBonusPct > 0) GoldAccent else HudDimText
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                for (tier in DifficultyTier.entries) {
                    val active = tier == selectedDifficulty
                    val tierColor = when (tier) {
                        DifficultyTier.STANDARD -> SkyBlue
                        DifficultyTier.ELITE -> WarmOrange
                        DifficultyTier.ABYSS -> CrimsonRed
                    }
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .testTag("difficulty_select_${tier.id}")
                            .minimumInteractiveComponentSize()
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (active) tierColor.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.06f))
                            .border(
                                width = if (active) 2.dp else 1.dp,
                                color = if (active) GoldAccent else Color.White.copy(alpha = 0.14f),
                                shape = RoundedCornerShape(12.dp)
                            )
                            .clickable { onSelectDifficulty(tier) }
                            .padding(horizontal = 8.dp, vertical = 7.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(
                            text = tier.nameZh,
                            style = MaterialTheme.typography.labelLarge.copy(fontSize = 11.5.sp, fontWeight = FontWeight.ExtraBold),
                            color = if (active) Color.White else CreamSurface,
                            maxLines = 1
                        )
                        Text(
                            text = tier.subtitleZh,
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                            color = if (active) GoldAccent else HudDimText,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }
        }

        // Section 2: Biomes (2x2 Grid with Boss & Matchup Intel)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ModalSectionLabel(
                title = "试炼群落",
                trailing = "已解锁 ${GameCatalog.biomes.count { meta.isBiomeUnlocked(it.id) }}/${GameCatalog.biomes.size}"
            )
            val biomeCols = if (isWide) 4 else 2
            val biomeRows = GameCatalog.biomes.chunked(biomeCols)
            for (rowItems in biomeRows) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    for (biome in rowItems) {
                        val unlocked = meta.isBiomeUnlocked(biome.id)
                        val isSelected = biome.id == selectedBiomeId
                        val clears = meta.biomeProgress[biome.id]?.clearedCount ?: 0
                        val bossDef = GameCatalog.enemies[biome.bossId]
                        val matchupMult = bossDef?.let {
                            ElementalMatchup.multiplier(selectedStarter.element, it.element)
                        } ?: 1.0f

                        ModalBiomeCard(
                            biome = biome,
                            bossElementName = bossDef?.element?.zhName ?: "",
                            bossElementColor = bossDef?.element?.color ?: HudDimText,
                            matchupMult = matchupMult,
                            unlocked = unlocked,
                            isSelected = isSelected,
                            clears = clears,
                            onClick = { onSelectBiome(biome.id) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        // Section 3: Challenge Modifiers (2x2 Grid with full readable descriptions)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ModalSectionLabel(
                title = "试炼词条（可选）",
                trailing = if (totalChallengeDustPct > 0) "星尘 +$totalChallengeDustPct%" else "提升难度换取额外星尘",
                trailingColor = if (totalChallengeDustPct > 0) GoldAccent else HudDimText
            )
            val modCols = if (isWide) 4 else 2
            val modRows = ChallengeModifier.entries.chunked(modCols)
            for (rowMods in modRows) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    for (mod in rowMods) {
                        val armed = mod in selectedChallengeModifiers
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .testTag("challenge_mod_${mod.id}")
                                .minimumInteractiveComponentSize()
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (armed) Brush.horizontalGradient(listOf(Color(0xFF7D1D32), Color(0xFFB4323F)))
                                    else Brush.horizontalGradient(listOf(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.06f)))
                                )
                                .border(
                                    width = if (armed) 1.8.dp else 1.dp,
                                    color = if (armed) GoldAccent else Color.White.copy(alpha = 0.14f),
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { onToggleChallengeModifier(mod) }
                                .padding(horizontal = 9.dp, vertical = 7.dp),
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = mod.nameZh,
                                    style = MaterialTheme.typography.labelMedium.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold),
                                    color = Color.White,
                                    maxLines = 1
                                )
                                Text(
                                    text = "+${mod.stardustBonusPct}%",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.ExtraBold),
                                    color = if (armed) GoldAccent else WarmOrange
                                )
                            }
                            Text(
                                text = mod.shortEffectZh,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                color = if (armed) CreamSurface.copy(alpha = 0.90f) else HudDimText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }

        // Section 4: Meta Mastery Summary (when unlocked)
        if (masteryChips.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("menu_mastery_bonus_strip")
                    .clip(RoundedCornerShape(11.dp))
                    .background(Color.Black.copy(alpha = 0.30f))
                    .border(1.dp, GoldAccent.copy(alpha = 0.45f), RoundedCornerShape(11.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(Icons.Rounded.AutoAwesome, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(14.dp))
                Text(
                    text = "图鉴永久加成：${masteryChips.joinToString(" · ")}",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                    color = CreamSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // Footer CTA
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ChunkyButton(
                text = "保存返回",
                onClick = onDismiss,
                tone = ChunkyButtonTone.ORANGE,
                height = 46.dp,
                modifier = Modifier.weight(0.85f)
            )
            ChunkyButton(
                text = "立即出征",
                onClick = {
                    onDismiss()
                    onStartRun()
                },
                tone = ChunkyButtonTone.GREEN,
                icon = Icons.Rounded.PlayArrow,
                shimmer = true,
                height = 46.dp,
                modifier = Modifier.weight(1.25f)
            )
        }
    }
}

@Composable
private fun ModalScrimContainer(
    maxWidth: androidx.compose.ui.unit.Dp,
    testTag: String,
    onDismiss: () -> Unit,
    content: @Composable (isWide: Boolean) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.64f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss
            )
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(14.dp),
        contentAlignment = Alignment.Center
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .widthIn(max = maxWidth)
                .fillMaxWidth()
                .testTag(testTag)
                .shadow(18.dp, RoundedCornerShape(24.dp))
                .clip(RoundedCornerShape(24.dp))
                .background(HudInkDark.copy(alpha = 0.96f))
                .border(1.8.dp, GoldAccent.copy(alpha = 0.55f), RoundedCornerShape(24.dp))
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {}
                )
        ) {
            val isWide = this.maxWidth >= 540.dp
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(11.dp)
            ) {
                content(isWide)
            }
        }
    }
}

@Composable
private fun ModalHeaderRow(
    title: String,
    subtitle: String,
    onDismiss: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge.copy(fontSize = 17.sp, fontWeight = FontWeight.ExtraBold),
                color = Color.White
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                color = HudDimText
            )
        }
        Box(
            modifier = Modifier
                .minimumInteractiveComponentSize()
                .size(38.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.10f))
                .border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape)
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Rounded.Close, contentDescription = "关闭", tint = CreamSurface, modifier = Modifier.size(19.dp))
        }
    }
}

@Composable
private fun ModalSectionLabel(
    title: String,
    trailing: String,
    trailingColor: Color = GoldAccent
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.sp, fontWeight = FontWeight.Bold),
            color = CreamSurface
        )
        Text(
            text = trailing,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
            color = trailingColor
        )
    }
}

@Composable
private fun ModalStatDot(text: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Box(modifier = Modifier.size(6.dp).clip(CircleShape).background(color))
        Text(text = text, style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp), color = CreamSurface)
    }
}

@Composable
private fun ModalBiomeCard(
    biome: BiomeDef,
    bossElementName: String,
    bossElementColor: Color,
    matchupMult: Float,
    unlocked: Boolean,
    isSelected: Boolean,
    clears: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val borderCol = when {
        isSelected -> GoldAccent
        unlocked -> Color.White.copy(alpha = 0.16f)
        else -> Color.White.copy(alpha = 0.08f)
    }
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier = modifier
            .testTag("biome_card_${biome.id}")
            .minimumInteractiveComponentSize()
            .alpha(if (unlocked) 1f else 0.50f)
            .clip(shape)
            .background(if (isSelected) Color.White.copy(alpha = 0.14f) else Color.Black.copy(alpha = 0.28f))
            .border(if (isSelected) 2.2.dp else 1.1.dp, borderCol, shape)
            .clickable(enabled = unlocked, onClick = onClick)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(38.dp)
        ) {
            AsyncDrawableImage(
                resId = biomeBackdropRes(biome.id),
                contentDescription = biome.nameZh,
                maxDimPx = 360,
                preferRgb565 = true,
                contentScale = ContentScale.Crop,
                fallbackColor = biome.accentColor,
                modifier = Modifier.fillMaxSize()
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.20f), Color.Black.copy(alpha = 0.62f))
                        )
                    )
            )
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = biome.nameZh,
                    style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.sp, fontWeight = FontWeight.ExtraBold),
                    color = Color.White,
                    maxLines = 1
                )
                if (!unlocked) {
                    Icon(Icons.Rounded.Lock, contentDescription = "未解锁", tint = Color.White, modifier = Modifier.size(13.dp))
                } else if (clears > 0) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.65f))
                            .padding(horizontal = 4.5.dp, vertical = 1.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Icon(Icons.Rounded.EmojiEvents, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(10.dp))
                        Text("×$clears", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = GoldAccent)
                    }
                }
            }
        }
        Column(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(bossElementColor))
                Text(
                    text = "${biome.bossNameZh}·$bossElementName",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = CreamSurface.copy(alpha = 0.90f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "+${biome.stardustBonus} 星尘",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = GoldAccent.copy(alpha = 0.90f)
                )
                when {
                    !unlocked -> Text("待解锁", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = HudDimText)
                    matchupMult >= 1.3f -> Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(5.dp))
                            .background(GrassGreenDeep)
                            .padding(horizontal = 4.5.dp, vertical = 1.dp)
                    ) {
                        Text("⚡克制", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold), color = Color.White)
                    }
                    matchupMult <= 0.9f -> Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(5.dp))
                            .background(CrimsonRed.copy(alpha = 0.30f))
                            .border(1.dp, CrimsonRed.copy(alpha = 0.72f), RoundedCornerShape(5.dp))
                            .padding(horizontal = 4.5.dp, vertical = 1.dp)
                    ) {
                        Text("受阻", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold), color = Color(0xFFFF9EA6))
                    }
                    else -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Shield, contentDescription = null, tint = HudDimText, modifier = Modifier.size(9.5.dp))
                        Spacer(Modifier.width(2.dp))
                        Text("均势", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = HudDimText)
                    }
                }
            }
        }
    }
}
