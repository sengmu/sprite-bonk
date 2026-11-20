package com.example.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarOutline
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.engine.MoveDamageEntry
import com.example.game.engine.RunSummary
import com.example.game.model.DifficultyTier
import com.example.game.model.GameCatalog
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CreamSurfaceWarm
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
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Shared Move Damage Breakdown Bar List used by both PauseModal and RunSettlementOverlay.
 * Displays elemental progress bars, damage values, and share percentages.
 */
@Composable
internal fun MoveDamageBarsList(
    entries: List<MoveDamageEntry>,
    compact: Boolean,
    darkTheme: Boolean = false
) {
    val maxDmg = (entries.maxOfOrNull { it.totalDamage } ?: 1).coerceAtLeast(1)
    val sumDmg = entries.sumOf { it.totalDamage }.coerceAtLeast(1)
    val defaultNameColor = if (darkTheme) Color.White else EspressoInk
    val awakenedNameColor = if (darkTheme) GoldAccent else WarmOrange
    val dmgValueColor = if (darkTheme) CreamSurface.copy(alpha = 0.88f) else EspressoDark
    val trackBg = if (darkTheme) Color.White.copy(alpha = 0.12f) else SandstoneRim.copy(alpha = 0.42f)
    Column(verticalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 6.dp)) {
        entries.forEach { entry ->
            val frac = (entry.totalDamage.toFloat() / maxDmg).coerceIn(0.06f, 1f)
            val sharePct = ((entry.totalDamage * 100f) / sumDmg).toInt().coerceIn(1, 100)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(entry.element.color)
                        )
                        Text(
                            text = if (entry.awakened) "★${entry.nameZh} Lv.${entry.level}" else "${entry.nameZh} Lv.${entry.level}",
                            style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 10.sp else 11.sp),
                            color = if (entry.awakened) awakenedNameColor else defaultNameColor,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Text(
                        text = "${entry.totalDamage} · $sharePct%",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 10.sp else 11.sp),
                        color = dmgValueColor
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(if (compact) 6.dp else 7.dp)
                        .clip(RoundedCornerShape(50))
                        .background(trackBg)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(frac)
                            .clip(RoundedCornerShape(50))
                            .background(
                                Brush.horizontalGradient(
                                    listOf(entry.element.color, entry.element.color.copy(alpha = 0.72f))
                                )
                            )
                    )
                }
            }
        }
    }
}

/**
 * U5 Run Settlement Screen:
 * Animated victory confetti/sunburst, spring-popping golden stars + S/A/B/C rank badge,
 * featured Stardust reward banner, 2x2 KPI stat grid, move DPS chart, and AGAIN / HOME pills.
 */
@Composable
fun RunSettlementOverlay(
    summary: RunSummary,
    onPlayAgain: () -> Unit,
    onGoHome: () -> Unit
) {
    val starter = remember(summary.starterId) { GameCatalog.starterById(summary.starterId) }
    val biome = remember(summary.biomeId) { GameCatalog.biomeById(summary.biomeId) }

    val confettiTransition = rememberInfiniteTransition(label = "settlement_fx")
    val confettiPhase by confettiTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "confetti_phase"
    )

    // Sequential spring pop-in for stars
    val starScales = remember { listOf(Animatable(0.2f), Animatable(0.2f), Animatable(0.2f)) }
    LaunchedEffect(summary.stars) {
        starScales.forEachIndexed { idx, anim ->
            delay(idx * 110L)
            anim.animateTo(
                targetValue = 1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessMedium
                )
            )
        }
    }

    val (gradeLabel, gradeColor) = when {
        summary.victory && summary.stars >= 3 -> "S" to GoldAccent
        summary.victory && summary.stars >= 2 -> "A" to GrassGreen
        summary.stars >= 1 -> "B" to SkyBlue
        else -> "C" to WarmOrange
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.radialGradient(
                    colors = if (summary.victory) {
                        listOf(Color(0xE0263B2C), Color(0xEC0E131D))
                    } else {
                        listOf(Color(0xE02A1D2E), Color(0xEC0E0E18))
                    }
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        // Animated ambient celebration / twilight backdrop (full-bleed edge-to-edge)
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = Offset(size.width * 0.5f, size.height * 0.42f)
            val glowColor = if (summary.victory) GoldAccent else starter.element.color
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(glowColor.copy(alpha = 0.22f), Color.Transparent),
                    center = center,
                    radius = size.maxDimension * 0.62f
                ),
                radius = size.maxDimension * 0.62f,
                center = center
            )
            if (summary.victory) {
                val colors = listOf(GoldAccent, GrassGreen, SkyBlue, WarmOrange, Color(0xFFFF7A9A))
                for (i in 0 until 28) {
                    val baseX = ((i * 197 + 41) % 100) / 100f * size.width
                    val drift = sin(confettiPhase * 2f * PI.toFloat() + i) * 18f
                    val yFrac = (((i * 313 + 73) % 100) / 100f + confettiPhase) % 1f
                    val y = yFrac * size.height
                    drawCircle(
                        color = colors[i % colors.size].copy(alpha = 0.72f),
                        radius = (3.5f + (i % 4)).dp.toPx(),
                        center = Offset(baseX + drift, y)
                    )
                }
            }
        }

        val m = summary.survivalSec / 60
        val s = summary.survivalSec % 60

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            val isLandscape = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
            val isCompactH = maxHeight < 430.dp

            DarkGlassPanel(
                modifier = Modifier
                    .widthIn(min = 300.dp, max = if (isLandscape) 780.dp else 460.dp)
                    .verticalScroll(rememberScrollState()),
                cornerRadius = if (isCompactH) 22.dp else 28.dp,
                borderColor = if (summary.victory) GoldAccent.copy(alpha = 0.85f) else Color(0xFF9C7BFF).copy(alpha = 0.72f),
                borderWidth = 2.6.dp,
                containerColor = HudInkDark.copy(alpha = 0.93f),
                contentPadding = PaddingValues(
                    horizontal = if (isCompactH) 14.dp else 20.dp,
                    vertical = if (isCompactH) 12.dp else 18.dp
                )
            ) {
                if (isLandscape) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(if (isCompactH) 14.dp else 18.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(
                            modifier = Modifier.weight(1f),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 10.dp)
                        ) {
                            SettlementHeaderRow(
                                victory = summary.victory,
                                stars = summary.stars,
                                starScales = starScales.map { it.value },
                                gradeLabel = gradeLabel,
                                gradeColor = gradeColor,
                                starterPortrait = starter.portraitRes,
                                starterColor = starter.element.color,
                                subtitle = buildString {
                                    append("${biome.nameZh} · ${starter.codeName}")
                                    if (summary.difficulty != DifficultyTier.STANDARD) append(" · ${summary.difficulty.nameZh}")
                                    if (summary.bossesCleared > 0) append(" · 守护者×${summary.bossesCleared}")
                                },
                                compact = isCompactH
                            )
                            StardustRewardBanner(stardust = summary.stardustEarned, compact = isCompactH)
                            if (summary.activeRelics.isNotEmpty()) {
                                ActiveRelicsStrip(relics = summary.activeRelics, compact = true)
                            }
                            if (summary.victory && !isCompactH) {
                                Text(
                                    text = "已记录群落通关进度，前往星尘实验室解锁永久强化！",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = GrassGreen,
                                    textAlign = TextAlign.Center
                                )
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                ChunkyButton(
                                    text = "再来一局",
                                    onClick = onPlayAgain,
                                    tone = ChunkyButtonTone.GREEN,
                                    icon = Icons.Rounded.Refresh,
                                    shimmer = summary.victory,
                                    height = if (isCompactH) 42.dp else 46.dp,
                                    testTag = "settlement_again_btn",
                                    modifier = Modifier.weight(1f)
                                )
                                ChunkyButton(
                                    text = "主页",
                                    onClick = onGoHome,
                                    tone = ChunkyButtonTone.CREAM,
                                    icon = Icons.Rounded.Home,
                                    height = if (isCompactH) 42.dp else 46.dp,
                                    testTag = "settlement_home_btn",
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }

                        Column(
                            modifier = Modifier.weight(1.08f),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 6.dp else 9.dp)
                        ) {
                            SettlementKpiGrid(
                                timeText = "%02d:%02d".format(m, s),
                                killsComboText = "${summary.kills} · ${summary.maxCombo}连",
                                scoreText = "${summary.score}",
                                levelText = "Lv.${summary.finalLevel}",
                                compact = isCompactH
                            )
                            if (summary.topMoveDamages.isNotEmpty()) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(if (isCompactH) 14.dp else 16.dp))
                                        .background(Color.White.copy(alpha = 0.06f))
                                        .border(1.2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(if (isCompactH) 14.dp else 16.dp))
                                        .padding(horizontal = 10.dp, vertical = if (isCompactH) 7.dp else 9.dp),
                                    verticalArrangement = Arrangement.spacedBy(if (isCompactH) 4.dp else 6.dp)
                                ) {
                                    Text("主力输出招式", style = MaterialTheme.typography.labelMedium, color = GoldAccent)
                                    MoveDamageBarsList(entries = summary.topMoveDamages.take(3), compact = isCompactH, darkTheme = true)
                                }
                            }
                        }
                    }
                } else {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        SettlementHeaderRow(
                            victory = summary.victory,
                            stars = summary.stars,
                            starScales = starScales.map { it.value },
                            gradeLabel = gradeLabel,
                            gradeColor = gradeColor,
                            starterPortrait = starter.portraitRes,
                            starterColor = starter.element.color,
                            subtitle = buildString {
                                append("${biome.nameZh} · ${starter.codeName}")
                                if (summary.difficulty != DifficultyTier.STANDARD) append(" · ${summary.difficulty.nameZh}")
                                if (summary.bossesCleared > 0) append(" · 守护者×${summary.bossesCleared}")
                            },
                            compact = false
                        )

                        StardustRewardBanner(stardust = summary.stardustEarned, compact = false)
                        if (summary.activeRelics.isNotEmpty()) {
                            ActiveRelicsStrip(relics = summary.activeRelics, compact = false)
                        }

                        SettlementKpiGrid(
                            timeText = "%02d:%02d".format(m, s),
                            killsComboText = "${summary.kills} · ${summary.maxCombo}连",
                            scoreText = "${summary.score}",
                            levelText = "Lv.${summary.finalLevel}",
                            compact = false
                        )

                        if (summary.topMoveDamages.isNotEmpty()) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(Color.White.copy(alpha = 0.06f))
                                    .border(1.2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(16.dp))
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text("主力输出招式", style = MaterialTheme.typography.labelLarge, color = GoldAccent)
                                MoveDamageBarsList(entries = summary.topMoveDamages.take(3), compact = false, darkTheme = true)
                            }
                        }

                        if (summary.victory) {
                            Text(
                                text = "已记录群落通关进度，前往星尘实验室解锁永久强化吧！",
                                style = MaterialTheme.typography.labelMedium,
                                color = GrassGreen,
                                textAlign = TextAlign.Center
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            ChunkyButton(
                                text = "再来一局",
                                onClick = onPlayAgain,
                                tone = ChunkyButtonTone.GREEN,
                                icon = Icons.Rounded.Refresh,
                                shimmer = summary.victory,
                                testTag = "settlement_again_btn",
                                modifier = Modifier.weight(1f)
                            )
                            ChunkyButton(
                                text = "返回主页",
                                onClick = onGoHome,
                                tone = ChunkyButtonTone.CREAM,
                                icon = Icons.Rounded.Home,
                                testTag = "settlement_home_btn",
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettlementHeaderRow(
    victory: Boolean,
    stars: Int,
    starScales: List<Float>,
    gradeLabel: String,
    gradeColor: Color,
    starterPortrait: Int,
    starterColor: Color,
    subtitle: String,
    compact: Boolean
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (compact) 6.dp else 8.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            for (st in 1..3) {
                val lit = st <= stars
                val scaleVal = starScales.getOrElse(st - 1) { 1f }
                Icon(
                    imageVector = if (lit) Icons.Rounded.Star else Icons.Rounded.StarOutline,
                    contentDescription = null,
                    tint = if (lit) GoldAccent else SandstoneRim,
                    modifier = Modifier
                        .size(if (st == 2) (if (compact) 34.dp else 44.dp) else (if (compact) 28.dp else 36.dp))
                        .scale(if (lit) scaleVal else 1f)
                )
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box {
                StarterPortraitAvatar(
                    portraitRes = starterPortrait,
                    ringColor = if (victory) GoldAccent else starterColor,
                    size = if (compact) 52.dp else 64.dp
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(if (compact) 22.dp else 26.dp)
                        .clip(CircleShape)
                        .background(gradeColor)
                        .border(2.dp, EspressoDark, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = gradeLabel,
                        style = MaterialTheme.typography.labelLarge.copy(fontSize = if (compact) 11.sp else 13.sp),
                        color = EspressoDark
                    )
                }
            }
            Column {
                Text(
                    text = if (victory) "试炼凯旋！" else "冒险暂歇",
                    style = if (compact) MaterialTheme.typography.headlineSmall else MaterialTheme.typography.headlineLarge,
                    color = if (victory) GoldAccent else Color.White
                )
                Text(
                    text = subtitle,
                    style = if (compact) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium,
                    color = CreamSurface.copy(alpha = 0.78f)
                )
            }
        }
    }
}

@Composable
private fun StardustRewardBanner(stardust: Int, compact: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.horizontalGradient(
                    listOf(Color(0xFF282038), Color(0xFF3E2D52), Color(0xFF2A223B))
                )
            )
            .border(2.dp, GoldAccent, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = if (compact) 7.dp else 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(if (compact) 28.dp else 34.dp)
                    .clip(CircleShape)
                    .background(GoldAccent.copy(alpha = 0.22f))
                    .border(1.5.dp, GoldAccent, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.AutoAwesome,
                    contentDescription = "星尘奖励",
                    tint = GoldAccent,
                    modifier = Modifier.size(if (compact) 16.dp else 20.dp)
                )
            }
            Column {
                Text(
                    text = "本局星尘收获",
                    style = MaterialTheme.typography.labelMedium,
                    color = CreamSurface.copy(alpha = 0.85f)
                )
                if (!compact) {
                    Text(
                        text = "已自动存入实验室星尘库",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = GoldAccent.copy(alpha = 0.80f)
                    )
                }
            }
        }
        Text(
            text = "+$stardust",
            style = MaterialTheme.typography.headlineMedium.copy(fontSize = if (compact) 20.sp else 24.sp),
            color = GoldAccent
        )
    }
}

@Composable
private fun SettlementKpiGrid(
    timeText: String,
    killsComboText: String,
    scoreText: String,
    levelText: String,
    compact: Boolean
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 7.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(if (compact) 6.dp else 8.dp)
        ) {
            SettlementKpiTile(Icons.Rounded.Timer, SkyBlue, "存活时间", timeText, compact, Modifier.weight(1f))
            SettlementKpiTile(Icons.Rounded.Whatshot, WarmOrange, "击败 · 最高连击", killsComboText, compact, Modifier.weight(1f))
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(if (compact) 6.dp else 8.dp)
        ) {
            SettlementKpiTile(Icons.Rounded.Bolt, Color(0xFFD95CE8), "本局积分", scoreText, compact, Modifier.weight(1f))
            SettlementKpiTile(Icons.AutoMirrored.Rounded.TrendingUp, GrassGreenDeep, "最终等级", levelText, compact, Modifier.weight(1f))
        }
    }
}

@Composable
private fun SettlementKpiTile(
    icon: ImageVector,
    iconTint: Color,
    label: String,
    value: String,
    compact: Boolean,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .border(1.2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(14.dp))
            .padding(horizontal = 10.dp, vertical = if (compact) 6.dp else 9.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(if (compact) 14.dp else 16.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.5.sp else 10.5.sp),
                color = CreamSurface.copy(alpha = 0.74f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium.copy(fontSize = if (compact) 14.sp else 16.sp),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
