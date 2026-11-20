package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Diamond
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.model.BossRelicId
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.WarmOrange

/**
 * Full-screen dark-glass Guardian Relic 3-choice reward modal triggered on
 * Lv.5 milestone (Classic/Duel) or after every Guardian defeat in Endless Survival.
 */
@Composable
fun RelicDraftModal(
    options: List<BossRelicId>,
    survivalWave: Int,
    onSelect: (BossRelicId) -> Unit
) {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .testTag("relic_draft_modal")
            .background(
                Brush.radialGradient(
                    colors = listOf(Color(0xEE2B1B46), Color(0xF20B0A18))
                )
            )
            .clickable(enabled = false) {},
        contentAlignment = Alignment.Center
    ) {
        val isWide = (maxWidth > maxHeight && maxWidth >= 540.dp) || maxWidth >= 600.dp
        val isShort = maxHeight < 450.dp

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 14.dp, vertical = 8.dp)
                .widthIn(max = if (isWide) 880.dp else 520.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (isShort) 8.dp else 14.dp)
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent, Color(0xFFFFE57F))))
                        .border(2.2.dp, DarkButtonRim, RoundedCornerShape(50))
                        .padding(horizontal = 20.dp, vertical = if (isShort) 4.dp else 7.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Diamond,
                            contentDescription = null,
                            tint = EspressoDark,
                            modifier = Modifier.size(if (isShort) 16.dp else 19.dp)
                        )
                        Text(
                            text = if (survivalWave > 1) "守护遗物赏赐 · 无尽第 $survivalWave 波" else "✦ 守护遗物觉醒 · 三选一",
                            style = if (isShort) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleLarge,
                            color = EspressoDark
                        )
                    }
                }
                if (!isShort) {
                    Text(
                        text = "本局永久生效的高阶遗物，可与元素羁绊和进化形态叠加",
                        style = MaterialTheme.typography.labelMedium,
                        color = CreamSurface.copy(alpha = 0.85f),
                        textAlign = TextAlign.Center
                    )
                }
            }

            if (isWide) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Max),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    options.forEachIndexed { idx, relic ->
                        RelicChoiceCard(
                            relic = relic,
                            index = idx,
                            compact = isShort,
                            onSelect = { onSelect(relic) },
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                }
            } else {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    options.forEachIndexed { idx, relic ->
                        RelicChoiceCard(
                            relic = relic,
                            index = idx,
                            compact = false,
                            onSelect = { onSelect(relic) },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun RelicChoiceCard(
    relic: BossRelicId,
    index: Int,
    compact: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier
) {
    DarkGlassPanel(
        modifier = modifier
            .testTag("relic_option_$index")
            .clickable(onClick = onSelect),
        cornerRadius = if (compact) 18.dp else 22.dp,
        borderColor = relic.accentColor.copy(alpha = 0.92f),
        borderWidth = 2.4.dp,
        containerColor = Color(0xEC1B1730),
        contentPadding = PaddingValues(if (compact) 10.dp else 14.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 8.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(relic.accentColor.copy(alpha = 0.22f))
                        .border(1.dp, relic.accentColor.copy(alpha = 0.78f), RoundedCornerShape(50))
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "◆ 守护遗物",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold),
                        color = relic.accentColor
                    )
                }
                RarityChip(rarity = relic.rarity)
            }

            Box(
                modifier = Modifier
                    .size(if (compact) 46.dp else 58.dp)
                    .clip(CircleShape)
                    .background(Brush.radialGradient(listOf(relic.accentColor.copy(alpha = 0.45f), HudInkDark)))
                    .border(2.2.dp, relic.accentColor, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.AutoAwesome,
                    contentDescription = relic.titleZh,
                    tint = Color.White,
                    modifier = Modifier.size(if (compact) 24.dp else 30.dp)
                )
            }

            Text(
                text = relic.titleZh,
                style = if (compact) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleLarge,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            Text(
                text = relic.subtitleZh,
                style = MaterialTheme.typography.labelMedium,
                color = relic.accentColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            Text(
                text = relic.descZh,
                style = if (compact) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium,
                color = CreamSurface.copy(alpha = 0.88f),
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(2.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(relic.accentColor)
                    .padding(vertical = if (compact) 4.dp else 6.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Rounded.TouchApp, contentDescription = null, tint = EspressoDark, modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    text = "铭刻遗物",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.ExtraBold),
                    color = EspressoDark
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ActiveRelicsStrip(
    relics: List<BossRelicId>,
    compact: Boolean = false,
    modifier: Modifier = Modifier
) {
    if (relics.isEmpty()) return
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        relics.forEach { relic ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(relic.accentColor.copy(alpha = 0.18f))
                    .border(1.1.dp, relic.accentColor.copy(alpha = 0.82f), RoundedCornerShape(50))
                    .padding(horizontal = if (compact) 7.dp else 9.dp, vertical = 2.5.dp)
            ) {
                Text(
                    text = relic.badgeZh,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = if (compact) 9.5.sp else 10.5.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = relic.accentColor,
                    maxLines = 1
                )
            }
        }
    }
}
