package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.MetaProgressionSnapshot
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.GameCatalog
import com.example.game.model.MasteryAchievement
import com.example.game.model.MetaMasteryBonuses
import com.example.game.model.MetaMasteryCalculator
import com.example.ui.components.AsyncDrawableImage
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.components.DarkGlassPanel
import com.example.ui.components.ScreenScenicBackdrop
import com.example.ui.components.SettingToggleRow
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
import com.example.ui.theme.WarmOrange

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DexScreen(
    meta: MetaProgressionSnapshot,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)
    var activeTab by remember { mutableIntStateOf(0) } // 0 = Partners, 1 = Wild & Bosses
    var expandedStarterId by remember { mutableStateOf<String?>(null) }
    var selectedBiomeFilter by remember { mutableStateOf("all") }

    val unlockedSet = remember(meta.profile.unlockedEvolutionIds) { meta.unlockedEvolutionSet() }
    val totalForms = EvolutionRegistry.allNodes.size
    val unlockedForms = EvolutionRegistry.allNodes.values.count { it.tier == 0 || it.id in unlockedSet }
    val allEnemies = remember { GameCatalog.enemies.values.toList() }
    val discoveredEnemies = allEnemies.count { (meta.dexEntries[it.id]?.seenCount ?: 0) > 0 }
    val mastery = remember(meta) { MetaMasteryCalculator.compute(meta) }

    val filteredEnemies = remember(selectedBiomeFilter, allEnemies) {
        if (selectedBiomeFilter == "all") allEnemies
        else {
            val bm = GameCatalog.biomes.firstOrNull { it.id == selectedBiomeFilter }
            if (bm == null) allEnemies
            else {
                val ids = (bm.enemyPool + bm.bossId).toSet()
                allEnemies.filter { it.id in ids }
            }
        }
    }

    val progressFrac = if (activeTab == 0) {
        (unlockedForms.toFloat() / totalForms.coerceAtLeast(1)).coerceIn(0f, 1f)
    } else {
        (discoveredEnemies.toFloat() / allEnemies.size.coerceAtLeast(1)).coerceIn(0f, 1f)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        ScreenScenicBackdrop(
            biomeId = meta.profile.selectedBiomeId,
            accentTint = Color(0xFF153449)
        )
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            val isLandscape = (maxWidth > maxHeight && maxWidth >= 560.dp) || maxWidth >= 640.dp
            val isCompactH = maxHeight < 430.dp

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .widthIn(max = 980.dp)
                    .align(Alignment.Center),
                verticalArrangement = Arrangement.spacedBy(if (isCompactH) 7.dp else 10.dp)
            ) {
                // Header (Landscape integrates tab switcher inline to preserve vertical space for the 2-column grid)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .testTag("dex_back_btn")
                            .minimumInteractiveComponentSize()
                            .size(if (isCompactH) 40.dp else 44.dp)
                            .clip(CircleShape)
                            .background(HudInkDark.copy(alpha = 0.78f))
                            .border(1.4.dp, Color.White.copy(alpha = 0.24f), CircleShape)
                            .clickable(onClick = onBack),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回", tint = CreamSurface)
                    }
                    Column(modifier = if (isLandscape) Modifier else Modifier.weight(1f)) {
                        Text(
                            text = "精灵图鉴",
                            style = if (isCompactH) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineMedium,
                            color = Color.White,
                            maxLines = 1
                        )
                        Text(
                            text = if (activeTab == 0) "进化解锁 $unlockedForms/$totalForms" else "野外发现 $discoveredEnemies/${allEnemies.size}",
                            style = MaterialTheme.typography.labelSmall,
                            color = CreamSurface,
                            maxLines = 1
                        )
                    }

                    if (isLandscape) {
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .widthIn(max = 420.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(HudInkDark.copy(alpha = 0.82f))
                                .border(1.5.dp, DarkButtonRim, RoundedCornerShape(16.dp))
                                .padding(3.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            DexTabPill(
                                label = "伙伴 (${GameCatalog.starters.size})",
                                icon = Icons.Rounded.Pets,
                                selected = activeTab == 0,
                                compact = isCompactH,
                                onClick = { activeTab = 0 },
                                modifier = Modifier.weight(1f)
                            )
                            DexTabPill(
                                label = "群落 ($discoveredEnemies/${allEnemies.size})",
                                icon = Icons.Rounded.Public,
                                selected = activeTab == 1,
                                compact = isCompactH,
                                onClick = { activeTab = 1 },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }

                    // Compact Percentage Pill
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.85f))
                            .border(1.5.dp, GoldAccent, RoundedCornerShape(50))
                            .padding(horizontal = 10.dp, vertical = 5.dp)
                    ) {
                        Text(
                            text = "${(progressFrac * 100).toInt()}%",
                            style = MaterialTheme.typography.labelLarge,
                            color = GoldAccent
                        )
                    }
                }

                // Portrait Segmented Tab Switcher + Progress Bar
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    if (!isLandscape) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(18.dp))
                                .background(HudInkDark.copy(alpha = 0.82f))
                                .border(1.5.dp, DarkButtonRim, RoundedCornerShape(18.dp))
                                .padding(4.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            DexTabPill(
                                label = "伙伴档案 (${GameCatalog.starters.size})",
                                icon = Icons.Rounded.Pets,
                                selected = activeTab == 0,
                                onClick = { activeTab = 0 },
                                modifier = Modifier.weight(1f)
                            )
                            DexTabPill(
                                label = "群落图鉴 ($discoveredEnemies/${allEnemies.size})",
                                icon = Icons.Rounded.Public,
                                selected = activeTab == 1,
                                onClick = { activeTab = 1 },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(if (isCompactH) 4.5.dp else 6.dp)
                            .clip(RoundedCornerShape(50))
                            .background(HudInkDark.copy(alpha = 0.40f))
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxHeight()
                                .fillMaxWidth(progressFrac)
                                .clip(RoundedCornerShape(50))
                                .background(Brush.horizontalGradient(listOf(GoldAccent, GrassGreen)))
                        )
                    }
                    DexMasteryBonusStrip(mastery = mastery, compact = isCompactH)
                }

                if (activeTab == 1) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        DexFilterChip("全部群落", selectedBiomeFilter == "all") { selectedBiomeFilter = "all" }
                        GameCatalog.biomes.forEach { bm ->
                            DexFilterChip(bm.nameZh, selectedBiomeFilter == bm.id) { selectedBiomeFilter = bm.id }
                        }
                    }
                }

                // 2-Column Grid on Landscape vs Single-Column List on Portrait
                LazyVerticalGrid(
                    columns = GridCells.Fixed(if (isLandscape) 2 else 1),
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 10.dp),
                    contentPadding = PaddingValues(bottom = 12.dp)
                ) {
                    if (activeTab == 0) {
                        gridItems(GameCatalog.starters, key = { it.id }) { starter ->
                            val branchNodes = remember(starter.id) { EvolutionRegistry.treeForStarter(starter.id) }
                            val unlockedForStarter = branchNodes.count { it.id in unlockedSet || it.tier == 0 }
                            val isExpanded = expandedStarterId == starter.id
                            DarkGlassPanel(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { expandedStarterId = if (isExpanded) null else starter.id },
                                cornerRadius = if (isCompactH) 18.dp else 20.dp,
                                borderColor = if (isExpanded) starter.element.color else Color.White.copy(alpha = 0.16f),
                                borderWidth = if (isExpanded) 2.dp else 1.3.dp,
                                contentPadding = PaddingValues(if (isCompactH) 10.dp else 14.dp)
                            ) {
                                Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        StarterPortraitAvatar(
                                            starter.portraitRes,
                                            starter.element.color,
                                            size = if (isCompactH) 52.dp else 62.dp
                                        )
                                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Row(
                                                    verticalAlignment = Alignment.CenterVertically,
                                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                                ) {
                                                    Text(starter.codeName, style = MaterialTheme.typography.titleMedium, color = Color.White)
                                                    Box(
                                                        modifier = Modifier
                                                            .clip(RoundedCornerShape(50))
                                                            .background(starter.element.color)
                                                            .padding(horizontal = 7.dp, vertical = 1.dp)
                                                    ) {
                                                        Text(
                                                            text = starter.element.zhName,
                                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                                            color = EspressoDark
                                                        )
                                                    }
                                                }
                                                Row(verticalAlignment = Alignment.CenterVertically) {
                                                    Text(
                                                        text = "$unlockedForStarter/${branchNodes.size}",
                                                        style = MaterialTheme.typography.labelSmall,
                                                        color = GrassGreen
                                                    )
                                                    Icon(
                                                        imageVector = if (isExpanded) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                                                        contentDescription = "展开进化详情",
                                                        tint = CreamSurface.copy(alpha = 0.72f),
                                                        modifier = Modifier.size(18.dp)
                                                    )
                                                }
                                            }
                                            Text(starter.roleZh, style = MaterialTheme.typography.labelMedium, color = GoldAccent)
                                            Text(
                                                text = starter.loreZh,
                                                style = MaterialTheme.typography.bodySmall,
                                                color = CreamSurface.copy(alpha = 0.78f),
                                                maxLines = if (isExpanded) 4 else 2,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                        }
                                    }

                                    AnimatedVisibility(visible = isExpanded) {
                                        Column(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clip(RoundedCornerShape(14.dp))
                                                .background(Color.Black.copy(alpha = 0.30f))
                                                .border(1.dp, starter.element.color.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                                                .padding(10.dp),
                                            verticalArrangement = Arrangement.spacedBy(6.dp)
                                        ) {
                                            Text("专属被动：${starter.passiveDescZh}", style = MaterialTheme.typography.labelMedium, color = Color.White)
                                            Text("必杀演进：${starter.ultStageNames.joinToString(" → ")}", style = MaterialTheme.typography.labelSmall, color = GoldAccent)
                                            FlowRow(
                                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                                verticalArrangement = Arrangement.spacedBy(5.dp)
                                            ) {
                                                branchNodes.forEach { node ->
                                                    val unlocked = node.tier == 0 || node.id in unlockedSet
                                                    Box(
                                                        modifier = Modifier
                                                            .clip(RoundedCornerShape(10.dp))
                                                            .background(if (unlocked) GrassGreen.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.06f))
                                                            .border(
                                                                1.dp,
                                                                if (unlocked) GrassGreen else Color.White.copy(alpha = 0.14f),
                                                                RoundedCornerShape(10.dp)
                                                            )
                                                            .padding(horizontal = 8.dp, vertical = 3.dp)
                                                    ) {
                                                        Text(
                                                            text = if (unlocked) "✓ ${node.nameZh}" else "🔒 ${node.nameZh}",
                                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                                            color = if (unlocked) Color.White else HudDimText
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        gridItems(filteredEnemies, key = { it.id }) { enemy ->
                            val entry = meta.dexEntries[enemy.id]
                            val seen = entry?.seenCount ?: 0
                            val defeated = entry?.defeatedCount ?: 0
                            DarkGlassPanel(
                                modifier = Modifier.fillMaxWidth(),
                                cornerRadius = 18.dp,
                                borderColor = if (enemy.isBoss) WarmOrange.copy(alpha = 0.80f) else Color.White.copy(alpha = 0.14f),
                                borderWidth = if (enemy.isBoss) 1.8.dp else 1.2.dp,
                                contentPadding = PaddingValues(if (isCompactH) 10.dp else 12.dp)
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(if (isCompactH) 40.dp else 46.dp)
                                            .clip(CircleShape)
                                            .background(if (seen > 0) enemy.primaryColor else Color.White.copy(alpha = 0.12f))
                                            .border(2.dp, if (enemy.isBoss) GoldAccent else Color.White.copy(alpha = 0.28f), CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(14.dp)
                                                .clip(CircleShape)
                                                .background(if (seen > 0) enemy.secondaryColor else Color.White.copy(alpha = 0.22f))
                                        )
                                    }
                                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                                        ) {
                                            Text(
                                                text = if (seen > 0) enemy.nameZh else "？？？",
                                                style = MaterialTheme.typography.titleMedium,
                                                color = Color.White,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                            if (seen > 0) {
                                                Box(
                                                    modifier = Modifier
                                                        .clip(RoundedCornerShape(50))
                                                        .background(enemy.element.color)
                                                        .padding(horizontal = 6.dp, vertical = 1.dp)
                                                ) {
                                                    Text(
                                                        text = enemy.element.zhName,
                                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                                        color = EspressoDark
                                                    )
                                                }
                                            }
                                            if (enemy.isBoss) {
                                                Box(
                                                    modifier = Modifier
                                                        .clip(RoundedCornerShape(50))
                                                        .background(CrimsonRed)
                                                        .padding(horizontal = 6.dp, vertical = 1.dp)
                                                ) {
                                                    Text("守护者", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = Color.White)
                                                }
                                            }
                                        }
                                        Text(
                                            text = if (seen > 0) enemy.descZh else "在对应群落遭遇后解锁生态资料",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = CreamSurface.copy(alpha = 0.76f),
                                            maxLines = 2,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }
                                    Column(horizontalAlignment = Alignment.End) {
                                        Text("遭遇 $seen", style = MaterialTheme.typography.labelSmall, color = HudDimText)
                                        Text("击败 $defeated", style = MaterialTheme.typography.labelMedium, color = GrassGreen)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DexTabPill(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: Boolean,
    compact: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .background(if (selected) GoldAccent else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = if (compact) 5.dp else 8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (selected) EspressoDark else CreamSurface.copy(alpha = 0.80f),
            modifier = Modifier.size(if (compact) 14.dp else 16.dp)
        )
        Spacer(Modifier.width(5.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge.copy(fontSize = if (compact) 11.5.sp else 13.sp),
            color = if (selected) EspressoDark else CreamSurface.copy(alpha = 0.85f),
            maxLines = 1
        )
    }
}

@Composable
private fun DexFilterChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .minimumInteractiveComponentSize()
            .clip(RoundedCornerShape(50))
            .background(if (selected) GoldAccent else HudInkDark.copy(alpha = 0.72f))
            .border(1.3.dp, if (selected) DarkButtonRim else Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = if (selected) EspressoDark else CreamSurface
        )
    }
}

/**
 * Profile & Stardust Treasury screen with dark-glass vault hero card,
 * win rate KPI, biome clear medals with real scenic artwork, and run history.
 */
@Composable
fun ProfileScreen(
    meta: MetaProgressionSnapshot,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)
    val winRatePct = if (meta.profile.totalRuns > 0) {
        (meta.profile.totalVictories * 100 / meta.profile.totalRuns).coerceIn(0, 100)
    } else 0
    val mastery = remember(meta) { MetaMasteryCalculator.compute(meta) }

    Box(modifier = Modifier.fillMaxSize()) {
        ScreenScenicBackdrop(
            biomeId = meta.profile.selectedBiomeId,
            accentTint = Color(0xFF3A241A)
        )
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            val isLandscape = (maxWidth > maxHeight && maxWidth >= 560.dp) || maxWidth >= 640.dp
            val isCompactH = maxHeight < 430.dp

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .widthIn(max = 980.dp)
                    .align(Alignment.Center),
                verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 12.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .testTag("profile_back_btn")
                            .minimumInteractiveComponentSize()
                            .size(if (isCompactH) 40.dp else 44.dp)
                            .clip(CircleShape)
                            .background(HudInkDark.copy(alpha = 0.78f))
                            .border(1.4.dp, Color.White.copy(alpha = 0.24f), CircleShape)
                            .clickable(onClick = onBack),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回", tint = CreamSurface)
                    }
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "训练家档案与星尘库",
                            style = if (isCompactH) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineMedium,
                            color = Color.White
                        )
                        Text(
                            text = "本地持久化存档 · 随时畅玩",
                            style = MaterialTheme.typography.labelSmall,
                            color = CreamSurface.copy(alpha = 0.80f)
                        )
                    }
                }

                if (isLandscape) {
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Left Pane: Stardust Vault + Biome Clear Medals
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .verticalScroll(rememberScrollState()),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 10.dp)
                        ) {
                            StardustVaultHeroCard(meta = meta, winRatePct = winRatePct, compact = isCompactH)
                            BiomeClearMedalsCard(meta = meta, compact = isCompactH)
                            AchievementsMasteryCard(mastery = mastery, compact = isCompactH)
                        }

                        // Right Pane: Recent Run History
                        Column(
                            modifier = Modifier
                                .weight(1.05f)
                                .fillMaxHeight(),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 6.dp else 8.dp)
                        ) {
                            Text(
                                text = "最近冒险记录 (${meta.recentRuns.size})",
                                style = MaterialTheme.typography.titleMedium,
                                color = Color.White
                            )
                            LazyColumn(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                                contentPadding = PaddingValues(bottom = 10.dp)
                            ) {
                                if (meta.recentRuns.isEmpty()) {
                                    item {
                                        DarkGlassPanel(modifier = Modifier.fillMaxWidth(), cornerRadius = 18.dp) {
                                            Text("还没有战斗记录，回到主页开启你的第一场试炼吧！", style = MaterialTheme.typography.bodyMedium, color = CreamSurface.copy(alpha = 0.82f))
                                        }
                                    }
                                } else {
                                    items(meta.recentRuns, key = { it.id }) { run ->
                                        RecentRunRecordCard(run = run, compact = isCompactH)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        contentPadding = PaddingValues(bottom = 16.dp)
                    ) {
                        item { StardustVaultHeroCard(meta = meta, winRatePct = winRatePct, compact = false) }
                        item { BiomeClearMedalsCard(meta = meta, compact = false) }
                        item { AchievementsMasteryCard(mastery = mastery, compact = false) }
                        item { Text("最近冒险记录", style = MaterialTheme.typography.titleLarge, color = Color.White) }

                        if (meta.recentRuns.isEmpty()) {
                            item {
                                DarkGlassPanel(modifier = Modifier.fillMaxWidth(), cornerRadius = 18.dp) {
                                    Text("还没有战斗记录，回到主页开启你的第一场试炼吧！", style = MaterialTheme.typography.bodyMedium, color = CreamSurface.copy(alpha = 0.82f))
                                }
                            }
                        } else {
                            items(meta.recentRuns, key = { it.id }) { run ->
                                RecentRunRecordCard(run = run, compact = false)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StardustVaultHeroCard(
    meta: MetaProgressionSnapshot,
    winRatePct: Int,
    compact: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 20.dp else 24.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF231D36), Color(0xFF392B52), Color(0xFF211C31))
                )
            )
            .border(2.8.dp, GoldAccent, RoundedCornerShape(if (compact) 20.dp else 24.dp))
            .padding(if (compact) 12.dp else 16.dp),
        verticalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(if (compact) 40.dp else 48.dp)
                        .clip(CircleShape)
                        .background(GoldAccent.copy(alpha = 0.22f))
                        .border(2.dp, GoldAccent, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Rounded.AutoAwesome,
                        contentDescription = null,
                        tint = GoldAccent,
                        modifier = Modifier.size(if (compact) 22.dp else 28.dp)
                    )
                }
                Column {
                    Text("星尘库余额", style = MaterialTheme.typography.labelMedium, color = CreamSurface.copy(alpha = 0.78f))
                    Text(
                        text = "${meta.profile.stardust}",
                        style = if (compact) MaterialTheme.typography.headlineLarge else MaterialTheme.typography.displayLarge,
                        color = GoldAccent
                    )
                }
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.White.copy(alpha = 0.10f))
                    .border(1.dp, GoldAccent.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("$winRatePct%", style = MaterialTheme.typography.titleMedium, color = GrassGreen)
                    Text("通关胜率", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp), color = CreamSurface.copy(alpha = 0.8f))
                }
            }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MiniKpiCard("累计击破", "${meta.profile.totalKills}", dark = true, compact = compact, modifier = Modifier.weight(1f))
            MiniKpiCard("出击次数", "${meta.profile.totalRuns}", dark = true, compact = compact, modifier = Modifier.weight(1f))
            MiniKpiCard("凯旋通关", "${meta.profile.totalVictories}", dark = true, compact = compact, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun BiomeClearMedalsCard(
    meta: MetaProgressionSnapshot,
    compact: Boolean
) {
    DarkGlassPanel(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = if (compact) 18.dp else 20.dp,
        contentPadding = PaddingValues(if (compact) 11.dp else 14.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 10.dp)) {
            Text("四大群落通关徽章", style = MaterialTheme.typography.titleMedium, color = Color.White)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (biome in GameCatalog.biomes) {
                    val prog = meta.biomeProgress[biome.id]
                    val clears = prog?.clearedCount ?: 0
                    val bestSec = prog?.bestTimeSec ?: 0
                    val bestStr = if (bestSec > 0) "%02d:%02d".format(bestSec / 60, bestSec % 60) else "未挑战"
                    val shape = RoundedCornerShape(14.dp)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(shape)
                            .border(
                                width = if (clears > 0) 1.8.dp else 1.1.dp,
                                color = if (clears > 0) GoldAccent else Color.White.copy(alpha = 0.16f),
                                shape = shape
                            )
                    ) {
                        AsyncDrawableImage(
                            resId = biomeBackdropRes(biome.id),
                            contentDescription = biome.nameZh,
                            maxDimPx = 240,
                            preferRgb565 = true,
                            contentScale = ContentScale.Crop,
                            fallbackColor = biome.accentColor,
                            modifier = Modifier.matchParentSize()
                        )
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .background(
                                    if (clears > 0) HudInkDark.copy(alpha = 0.62f)
                                    else HudInkDark.copy(alpha = 0.80f)
                                )
                        )
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 4.dp, vertical = if (compact) 7.dp else 10.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Icon(
                                imageVector = if (clears > 0) Icons.Rounded.Verified else Icons.Rounded.EmojiEvents,
                                contentDescription = null,
                                tint = if (clears > 0) GoldAccent else HudDimText,
                                modifier = Modifier.size(if (compact) 18.dp else 22.dp)
                            )
                            Text(
                                text = biome.nameZh.take(2),
                                style = MaterialTheme.typography.labelMedium,
                                color = Color.White,
                                maxLines = 1
                            )
                            Text(
                                text = if (clears > 0) "×$clears" else "未通关",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                color = if (clears > 0) GrassGreen else HudDimText
                            )
                            Text(
                                text = bestStr,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = CreamSurface.copy(alpha = 0.72f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DexMasteryBonusStrip(
    mastery: MetaMasteryBonuses,
    compact: Boolean
) {
    val chips = remember(mastery) { mastery.summaryChips() }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("dex_mastery_strip")
            .clip(RoundedCornerShape(12.dp))
            .background(HudInkDark.copy(alpha = 0.84f))
            .border(1.2.dp, GoldAccent.copy(alpha = 0.65f), RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = if (compact) 5.dp else 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = Icons.Rounded.AutoAwesome,
            contentDescription = null,
            tint = GoldAccent,
            modifier = Modifier.size(15.dp)
        )
        Text(
            text = if (chips.isNotEmpty()) {
                "图鉴反哺战力：${chips.joinToString(" · ")}"
            } else {
                "图鉴反哺：解锁 2 种进化形态或发现 2 种群落精灵即可激活永久战力加成"
            },
            style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 10.sp else 11.sp),
            color = CreamSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun AchievementsMasteryCard(
    mastery: MetaMasteryBonuses,
    compact: Boolean
) {
    DarkGlassPanel(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("profile_achievements_card"),
        cornerRadius = if (compact) 18.dp else 20.dp,
        contentPadding = PaddingValues(if (compact) 11.dp else 14.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(if (compact) 6.dp else 9.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("里程碑成就与永久反哺", style = MaterialTheme.typography.titleMedium, color = Color.White)
                Text(
                    text = "${mastery.completedAchievementCount}/${mastery.achievements.size} · 星尘 +${(mastery.stardustBonusPct * 100).toInt()}%",
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = 11.sp),
                    color = GoldAccent
                )
            }

            if (mastery.hasAnyBonus) {
                Text(
                    text = "生效中：${mastery.summaryChips().joinToString(" · ")}",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                    color = GrassGreen,
                    maxLines = 2
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 7.dp)) {
                mastery.achievements.forEach { ach ->
                    AchievementProgressRow(ach = ach, compact = compact)
                }
            }
        }
    }
}

@Composable
private fun AchievementProgressRow(
    ach: MasteryAchievement,
    compact: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (ach.completed) GrassGreen.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.06f))
            .border(
                width = if (ach.completed) 1.4.dp else 1.dp,
                color = if (ach.completed) GrassGreen.copy(alpha = 0.78f) else Color.White.copy(alpha = 0.13f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(horizontal = 9.dp, vertical = if (compact) 5.dp else 7.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                modifier = Modifier.weight(1f)
            ) {
                Icon(
                    imageVector = if (ach.completed) Icons.Rounded.Verified else Icons.Rounded.EmojiEvents,
                    contentDescription = null,
                    tint = if (ach.completed) GrassGreen else WarmOrange,
                    modifier = Modifier.size(15.dp)
                )
                Text(
                    text = ach.titleZh,
                    style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.sp),
                    color = Color.White,
                    maxLines = 1
                )
                Text(
                    text = ach.progressText,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = HudDimText,
                    maxLines = 1
                )
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (ach.completed) GrassGreenDeep else Color.Black.copy(alpha = 0.42f))
                    .border(1.dp, if (ach.completed) GrassGreen else GoldAccent.copy(alpha = 0.45f), RoundedCornerShape(50))
                    .padding(horizontal = 6.dp, vertical = 1.5.dp)
            ) {
                Text(
                    text = if (ach.completed) "✓ ${ach.rewardTagZh}" else ach.rewardTagZh,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = if (ach.completed) Color.White else GoldAccent
                )
            }
        }
        Text(
            text = ach.descZh,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
            color = CreamSurface.copy(alpha = 0.74f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = 0.14f))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(ach.progressFrac)
                    .clip(RoundedCornerShape(50))
                    .background(if (ach.completed) GrassGreen else WarmOrange)
            )
        }
    }
}

@Composable
private fun RecentRunRecordCard(
    run: com.example.data.RunRecordEntity,
    compact: Boolean
) {
    val st = GameCatalog.starterById(run.starterId)
    val bm = GameCatalog.biomeById(run.biomeId)
    val durStr = "%02d:%02d".format(run.survivalSec / 60, run.survivalSec % 60)
    DarkGlassPanel(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 18.dp,
        borderColor = if (run.victory) GrassGreen.copy(alpha = 0.75f) else Color.White.copy(alpha = 0.14f),
        contentPadding = PaddingValues(if (compact) 10.dp else 12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.weight(1f)
            ) {
                StarterPortraitAvatar(st.portraitRes, if (run.victory) GrassGreen else WarmOrange, size = if (compact) 38.dp else 44.dp)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(if (run.victory) GrassGreenDeep else Color.White.copy(alpha = 0.18f))
                                .padding(horizontal = 6.dp, vertical = 1.dp)
                        ) {
                            Text(
                                text = if (run.victory) "凯旋" else "撤离",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = Color.White
                            )
                        }
                        Text(
                            text = "${bm.nameZh} · ${st.codeName}",
                            style = MaterialTheme.typography.titleSmall,
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Text(
                        text = "耗时 $durStr · Lv.${run.finalLevel} · 击破 ${run.kills}",
                        style = MaterialTheme.typography.labelSmall,
                        color = HudDimText
                    )
                }
            }
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(GoldAccent.copy(alpha = 0.18f))
                    .border(1.dp, GoldAccent.copy(alpha = 0.65f), RoundedCornerShape(50))
                    .padding(horizontal = 9.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Icon(Icons.Rounded.Whatshot, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(14.dp))
                Text("+${run.stardustEarned}", style = MaterialTheme.typography.labelLarge, color = GoldAccent)
            }
        }
    }
}

@Composable
private fun MiniKpiCard(
    label: String,
    value: String,
    dark: Boolean = true,
    compact: Boolean = false,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(1.2.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .padding(if (compact) 7.dp else 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = if (compact) MaterialTheme.typography.titleMedium else MaterialTheme.typography.headlineSmall,
            color = Color.White
        )
        Text(label, style = MaterialTheme.typography.labelSmall, color = CreamSurface.copy(alpha = 0.72f))
    }
}

@Composable
fun SettingsDialogModal(
    meta: MetaProgressionSnapshot,
    onUpdateSettings: (Boolean?, Boolean?, Boolean?, Boolean?) -> Unit,
    onResetProgress: () -> Unit,
    onDismiss: () -> Unit
) {
    BackHandler(onBack = onDismiss)
    var resetArmed by remember { mutableStateOf(false) }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.68f))
            .clickable(onClick = onDismiss)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        val isLandscape = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
        val isCompactH = maxHeight < 430.dp

        DarkGlassPanel(
            modifier = Modifier
                .widthIn(min = 290.dp, max = if (isLandscape) 660.dp else 430.dp)
                .clickable(enabled = false) {}
                .verticalScroll(rememberScrollState()),
            cornerRadius = if (isCompactH) 20.dp else 24.dp,
            borderColor = GoldAccent.copy(alpha = 0.55f),
            borderWidth = 1.8.dp,
            containerColor = HudInkDark.copy(alpha = 0.96f),
            contentPadding = PaddingValues(if (isCompactH) 14.dp else 20.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 10.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Rounded.Settings,
                            contentDescription = null,
                            tint = GoldAccent,
                            modifier = Modifier.size(if (isCompactH) 22.dp else 26.dp)
                        )
                        Text(
                            text = "游戏设置",
                            style = if (isCompactH) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineMedium,
                            color = Color.White
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
                        Icon(Icons.Rounded.Close, contentDescription = "关闭设置", tint = CreamSurface, modifier = Modifier.size(18.dp))
                    }
                }

                if (isLandscape) {
                    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Box(modifier = Modifier.weight(1f)) {
                                SettingToggleRow("音效与打击声效", meta.profile.sfxEnabled, { onUpdateSettings(it, null, null, null) }, icon = Icons.Rounded.VolumeUp, compact = true, darkTheme = true)
                            }
                            Box(modifier = Modifier.weight(1f)) {
                                SettingToggleRow("触感震动反馈", meta.profile.vibrationEnabled, { onUpdateSettings(null, it, null, null) }, icon = Icons.Rounded.Vibration, compact = true, darkTheme = true)
                            }
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Box(modifier = Modifier.weight(1f)) {
                                SettingToggleRow("必杀与暴击震屏", meta.profile.screenShakeEnabled, { onUpdateSettings(null, null, it, null) }, icon = Icons.Rounded.Whatshot, compact = true, darkTheme = true)
                            }
                            Box(modifier = Modifier.weight(1f)) {
                                SettingToggleRow("默认开启自动锁敌", meta.profile.autoAimEnabled, { onUpdateSettings(null, null, null, it) }, icon = Icons.Rounded.GpsFixed, compact = true, darkTheme = true)
                            }
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        ChunkyButton(
                            text = if (resetArmed) "再点一次确认清空" else "重置本地存档",
                            onClick = {
                                if (resetArmed) {
                                    resetArmed = false
                                    onResetProgress()
                                } else {
                                    resetArmed = true
                                }
                            },
                            tone = ChunkyButtonTone.RED,
                            icon = Icons.Rounded.DeleteForever,
                            height = 42.dp,
                            testTag = "settings_reset_btn",
                            modifier = Modifier.weight(1f)
                        )
                        ChunkyButton(
                            text = "完成",
                            onClick = onDismiss,
                            tone = ChunkyButtonTone.GREEN,
                            height = 42.dp,
                            testTag = "settings_close_btn",
                            modifier = Modifier.weight(1f)
                        )
                    }
                } else {
                    SettingToggleRow("音效与打击声效", meta.profile.sfxEnabled, { onUpdateSettings(it, null, null, null) }, icon = Icons.Rounded.VolumeUp, darkTheme = true)
                    SettingToggleRow("触感震动反馈", meta.profile.vibrationEnabled, { onUpdateSettings(null, it, null, null) }, icon = Icons.Rounded.Vibration, darkTheme = true)
                    SettingToggleRow("必杀与暴击震屏", meta.profile.screenShakeEnabled, { onUpdateSettings(null, null, it, null) }, icon = Icons.Rounded.Whatshot, darkTheme = true)
                    SettingToggleRow("默认开启自动锁敌", meta.profile.autoAimEnabled, { onUpdateSettings(null, null, null, it) }, icon = Icons.Rounded.GpsFixed, darkTheme = true)

                    Spacer(Modifier.height(4.dp))

                    ChunkyButton(
                        text = if (resetArmed) "再点一次确认清空所有存档" else "重置本地存档",
                        onClick = {
                            if (resetArmed) {
                                resetArmed = false
                                onResetProgress()
                            } else {
                                resetArmed = true
                            }
                        },
                        tone = ChunkyButtonTone.RED,
                        icon = Icons.Rounded.DeleteForever,
                        testTag = "settings_reset_btn",
                        modifier = Modifier.fillMaxWidth()
                    )
                    ChunkyButton(
                        text = "完成",
                        onClick = onDismiss,
                        tone = ChunkyButtonTone.GREEN,
                        testTag = "settings_close_btn",
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}
