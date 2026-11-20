package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Upgrade
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.MetaProgressionSnapshot
import com.example.game.model.GameCatalog
import com.example.game.model.LabUpgradeDef
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.components.DarkGlassPanel
import com.example.ui.components.ResourcePill
import com.example.ui.components.ScreenScenicBackdrop
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlinx.coroutines.delay

/**
 * U4 Lab Permanent Upgrade Panel:
 * Category filters, affordable counter, segmented node progress pips,
 * detailed upgrade inspector, and two-step safe refund confirmation.
 */
@Composable
fun LabScreen(
    meta: MetaProgressionSnapshot,
    onBuyUpgrade: (String) -> Unit,
    onRefundAll: () -> Unit,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)
    val categories = remember {
        listOf("全部") + GameCatalog.labUpgrades.map { it.categoryZh }.distinct()
    }
    var activeCategory by remember { mutableStateOf("全部") }
    var selectedId by remember { mutableStateOf(GameCatalog.labUpgrades.first().id) }
    var refundArmed by remember { mutableStateOf(false) }

    // Auto-disarm refund confirmation after 4s
    LaunchedEffect(refundArmed) {
        if (refundArmed) {
            delay(4000L)
            refundArmed = false
        }
    }

    val filteredUpgrades = remember(activeCategory) {
        if (activeCategory == "全部") GameCatalog.labUpgrades
        else GameCatalog.labUpgrades.filter { it.categoryZh == activeCategory }
    }
    val selectedDef = GameCatalog.labUpgrades.firstOrNull { it.id == selectedId } ?: GameCatalog.labUpgrades.first()
    val selectedLevel = meta.labLevels[selectedDef.id] ?: 0
    val nextCost = selectedDef.costForNext(selectedLevel)
    val isMaxed = selectedLevel >= selectedDef.maxLevel
    val canAfford = !isMaxed && meta.profile.stardust >= nextCost
    val totalInvestedLevels = meta.labLevels.values.sum()
    val totalMaxLevels = remember { GameCatalog.labUpgrades.sumOf { it.maxLevel } }
    val affordableCount = GameCatalog.labUpgrades.count { def ->
        val lv = meta.labLevels[def.id] ?: 0
        lv < def.maxLevel && meta.profile.stardust >= def.costForNext(lv)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        ScreenScenicBackdrop(
            biomeId = meta.profile.selectedBiomeId,
            accentTint = Color(0xFF1D294D)
        )
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            val isWide = (maxWidth > maxHeight && maxWidth >= 540.dp) || maxWidth >= 640.dp
            val isCompactH = maxHeight < 430.dp

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .widthIn(max = 980.dp)
                    .align(Alignment.Center),
                verticalArrangement = Arrangement.spacedBy(if (isCompactH) 7.dp else 10.dp)
            ) {
                // Header (Landscape integrates category chips inline to maximize grid & inspector height)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = if (isWide) Modifier else Modifier.weight(1f)
                    ) {
                        Box(
                            modifier = Modifier
                                .testTag("lab_back_btn")
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
                        Spacer(Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "星尘实验室",
                                style = if (isCompactH) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineMedium,
                                color = Color.White,
                                maxLines = 1
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text(
                                    text = "$totalInvestedLevels/$totalMaxLevels 级",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = CreamSurface
                                )
                                if (affordableCount > 0) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(50))
                                            .background(GoldAccent)
                                            .padding(horizontal = 6.dp, vertical = 1.dp)
                                    ) {
                                        Text(
                                            text = "可升 $affordableCount",
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                            color = EspressoDark
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if (isWide) {
                        LabCategoryFilterRow(
                            categories = categories,
                            activeCategory = activeCategory,
                            meta = meta,
                            selectedDef = selectedDef,
                            compact = isCompactH,
                            onSelectCategory = { cat, firstId ->
                                activeCategory = cat
                                if (firstId != null) selectedId = firstId
                            },
                            modifier = Modifier.weight(1f)
                        )
                    }

                    ResourcePill(
                        valueText = "${meta.profile.stardust} 星尘",
                        icon = Icons.Rounded.AutoAwesome,
                        iconTint = GoldAccent,
                        darkTheme = true
                    )
                }

                // Portrait Category Filter Strip
                if (!isWide) {
                    LabCategoryFilterRow(
                        categories = categories,
                        activeCategory = activeCategory,
                        meta = meta,
                        selectedDef = selectedDef,
                        compact = false,
                        onSelectCategory = { cat, firstId ->
                            activeCategory = cat
                            if (firstId != null) selectedId = firstId
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                if (isWide) {
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        LabNodesGridPanel(
                            upgrades = filteredUpgrades,
                            meta = meta,
                            selectedId = selectedId,
                            compact = isCompactH,
                            onSelect = {
                                selectedId = it
                                refundArmed = false
                            },
                            modifier = Modifier
                                .weight(1.32f)
                                .fillMaxHeight()
                        )
                        LabDetailActionPanel(
                            selectedDef = selectedDef,
                            selectedLevel = selectedLevel,
                            nextCost = nextCost,
                            isMaxed = isMaxed,
                            canAfford = canAfford,
                            totalInvestedLevels = totalInvestedLevels,
                            refundArmed = refundArmed,
                            compact = isCompactH,
                            onBuyUpgrade = {
                                refundArmed = false
                                onBuyUpgrade(selectedDef.id)
                            },
                            onRefundClick = {
                                if (refundArmed) {
                                    refundArmed = false
                                    onRefundAll()
                                } else {
                                    refundArmed = true
                                }
                            },
                            modifier = Modifier
                                .weight(0.92f)
                                .fillMaxHeight()
                        )
                    }
                } else {
                    LabNodesGridPanel(
                        upgrades = filteredUpgrades,
                        meta = meta,
                        selectedId = selectedId,
                        compact = false,
                        onSelect = {
                            selectedId = it
                            refundArmed = false
                        },
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                    )
                    LabDetailActionPanel(
                        selectedDef = selectedDef,
                        selectedLevel = selectedLevel,
                        nextCost = nextCost,
                        isMaxed = isMaxed,
                        canAfford = canAfford,
                        totalInvestedLevels = totalInvestedLevels,
                        refundArmed = refundArmed,
                        compact = false,
                        onBuyUpgrade = {
                            refundArmed = false
                            onBuyUpgrade(selectedDef.id)
                        },
                        onRefundClick = {
                            if (refundArmed) {
                                refundArmed = false
                                onRefundAll()
                            } else {
                                refundArmed = true
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun LabCategoryFilterRow(
    categories: List<String>,
    activeCategory: String,
    meta: MetaProgressionSnapshot,
    selectedDef: LabUpgradeDef,
    compact: Boolean,
    onSelectCategory: (String, String?) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        categories.forEach { cat ->
            val selected = cat == activeCategory
            val catAffordable = GameCatalog.labUpgrades.count { def ->
                (cat == "全部" || def.categoryZh == cat) &&
                    (meta.labLevels[def.id] ?: 0) < def.maxLevel &&
                    meta.profile.stardust >= def.costForNext(meta.labLevels[def.id] ?: 0)
            }
            Row(
                modifier = Modifier
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(50))
                    .background(if (selected) GoldAccent else HudInkDark.copy(alpha = 0.72f))
                    .border(
                        width = if (selected) 1.6.dp else 1.2.dp,
                        color = if (selected) DarkButtonRim else Color.White.copy(alpha = 0.18f),
                        shape = RoundedCornerShape(50)
                    )
                    .clickable {
                        val firstInCat = if (cat == "全部") GameCatalog.labUpgrades.firstOrNull()
                        else GameCatalog.labUpgrades.firstOrNull { it.categoryZh == cat }
                        val nextSelectedId = if (firstInCat != null && cat != "全部" && selectedDef.categoryZh != cat) {
                            firstInCat.id
                        } else null
                        onSelectCategory(cat, nextSelectedId)
                    }
                    .padding(horizontal = if (compact) 11.dp else 13.dp, vertical = if (compact) 5.dp else 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = cat,
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = if (compact) 11.sp else 12.sp),
                    color = if (selected) EspressoDark else CreamSurface,
                    maxLines = 1
                )
                if (catAffordable > 0 && cat != "全部") {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(if (selected) GrassGreenDeep else GrassGreen)
                    )
                }
            }
        }
    }
}

@Composable
private fun LabNodesGridPanel(
    upgrades: List<LabUpgradeDef>,
    meta: MetaProgressionSnapshot,
    selectedId: String,
    compact: Boolean = false,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    DarkGlassPanel(
        modifier = modifier,
        cornerRadius = if (compact) 18.dp else 22.dp,
        contentPadding = PaddingValues(if (compact) 9.dp else 12.dp)
    ) {
        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = if (compact) 94.dp else 106.dp),
            horizontalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 10.dp),
            verticalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 10.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            items(upgrades, key = { it.id }) { def ->
                val lv = meta.labLevels[def.id] ?: 0
                val cost = def.costForNext(lv)
                val maxed = lv >= def.maxLevel
                val affordable = !maxed && meta.profile.stardust >= cost
                val isSelected = def.id == selectedId

                LabNodeCard(
                    def = def,
                    level = lv,
                    nextCost = cost,
                    maxed = maxed,
                    affordable = affordable,
                    isSelected = isSelected,
                    onClick = { onSelect(def.id) }
                )
            }
        }
    }
}

@Composable
private fun LabDetailActionPanel(
    selectedDef: LabUpgradeDef,
    selectedLevel: Int,
    nextCost: Int,
    isMaxed: Boolean,
    canAfford: Boolean,
    totalInvestedLevels: Int,
    refundArmed: Boolean,
    compact: Boolean = false,
    onBuyUpgrade: () -> Unit,
    onRefundClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val catColor = categoryColor(selectedDef.categoryZh)
    val levelFrac = (selectedLevel.toFloat() / selectedDef.maxLevel.coerceAtLeast(1)).coerceIn(0f, 1f)

    DarkGlassPanel(
        modifier = modifier,
        cornerRadius = if (compact) 18.dp else 22.dp,
        borderColor = when {
            canAfford -> GoldAccent.copy(alpha = 0.85f)
            isMaxed -> GrassGreen.copy(alpha = 0.78f)
            else -> Color.White.copy(alpha = 0.18f)
        },
        borderWidth = 1.8.dp,
        contentPadding = PaddingValues(if (compact) 11.dp else 15.dp)
    ) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 10.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(if (compact) 44.dp else 52.dp)
                        .clip(CircleShape)
                        .background(catColor)
                        .border(2.dp, Color.White.copy(alpha = 0.35f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = categoryIcon(selectedDef.categoryZh),
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(if (compact) 22.dp else 26.dp)
                    )
                }
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = selectedDef.nameZh,
                            style = MaterialTheme.typography.titleLarge,
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(catColor.copy(alpha = 0.24f))
                                .border(1.dp, catColor.copy(alpha = 0.65f), RoundedCornerShape(50))
                                .padding(horizontal = 7.dp, vertical = 1.5.dp)
                        ) {
                            Text(
                                text = selectedDef.categoryZh,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = CreamSurface
                            )
                        }
                    }
                    Text(selectedDef.effectZh, style = MaterialTheme.typography.bodyMedium, color = CreamSurface.copy(alpha = 0.86f))
                }
            }

            // Progress Bar
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "当前强化进度",
                        style = MaterialTheme.typography.labelSmall,
                        color = HudDimText
                    )
                    Text(
                        text = if (isMaxed) "已满级 (${selectedDef.maxLevel}/${selectedDef.maxLevel})" else "Lv.$selectedLevel / ${selectedDef.maxLevel}",
                        style = MaterialTheme.typography.labelMedium,
                        color = if (isMaxed) GrassGreen else GoldAccent
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.14f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(levelFrac)
                            .clip(RoundedCornerShape(50))
                            .background(if (isMaxed) GrassGreen else catColor)
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ChunkyButton(
                    text = if (isMaxed) "已满级" else "升级 · $nextCost 星尘",
                    onClick = onBuyUpgrade,
                    tone = if (isMaxed) ChunkyButtonTone.GREEN else ChunkyButtonTone.ORANGE,
                    icon = if (isMaxed) Icons.Rounded.CheckCircle else Icons.Rounded.Upgrade,
                    enabled = canAfford,
                    shimmer = canAfford,
                    height = if (compact) 42.dp else 48.dp,
                    testTag = "lab_upgrade_confirm_btn",
                    modifier = Modifier.weight(1.45f)
                )
                ChunkyButton(
                    text = if (refundArmed) "确认返还" else "返还",
                    onClick = onRefundClick,
                    tone = if (refundArmed) ChunkyButtonTone.RED else ChunkyButtonTone.CREAM,
                    icon = Icons.Rounded.Refresh,
                    enabled = totalInvestedLevels > 0,
                    height = if (compact) 42.dp else 48.dp,
                    testTag = "lab_refund_btn",
                    modifier = Modifier.weight(0.85f)
                )
            }
        }
    }
}

@Composable
private fun LabNodeCard(
    def: LabUpgradeDef,
    level: Int,
    nextCost: Int,
    maxed: Boolean,
    affordable: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val catColor = categoryColor(def.categoryZh)
    val bg = when {
        isSelected -> catColor.copy(alpha = 0.24f)
        maxed -> GrassGreen.copy(alpha = 0.18f)
        level > 0 -> Color.White.copy(alpha = 0.09f)
        affordable -> Color.White.copy(alpha = 0.08f)
        else -> Color.White.copy(alpha = 0.04f)
    }
    val borderCol = when {
        isSelected -> GoldAccent
        maxed -> GrassGreen
        affordable -> GrassGreen.copy(alpha = 0.72f)
        level > 0 -> catColor.copy(alpha = 0.55f)
        else -> Color.White.copy(alpha = 0.13f)
    }
    Box(
        modifier = Modifier
            .testTag("lab_node_${def.id}")
            .minimumInteractiveComponentSize()
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .border(if (isSelected) 2.2.dp else 1.2.dp, borderCol, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(10.dp)
    ) {
        if (affordable) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .clip(RoundedCornerShape(50))
                    .background(GrassGreen)
                    .padding(horizontal = 5.dp, vertical = 1.dp)
            ) {
                Text(
                    text = "可升",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp),
                    color = EspressoDark
                )
            }
        }
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Box {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(if (level > 0 || affordable) catColor else Color.White.copy(alpha = 0.14f))
                        .border(1.8.dp, Color.White.copy(alpha = 0.28f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = categoryIcon(def.categoryZh),
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
                if (!affordable && level == 0) {
                    Icon(
                        imageVector = Icons.Rounded.Lock,
                        contentDescription = null,
                        tint = CreamSurface,
                        modifier = Modifier
                            .size(15.dp)
                            .align(Alignment.BottomEnd)
                            .clip(CircleShape)
                            .background(HudInkDark)
                            .padding(2.dp)
                    )
                }
            }
            Text(
                text = def.nameZh,
                style = MaterialTheme.typography.labelLarge,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            // Segmented level pips (up to 6 dots or compact progress bar)
            if (def.maxLevel <= 6) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    for (i in 1..def.maxLevel) {
                        Box(
                            modifier = Modifier
                                .size(width = 9.dp, height = 4.5.dp)
                                .clip(RoundedCornerShape(50))
                                .background(
                                    when {
                                        i <= level && maxed -> GrassGreen
                                        i <= level -> catColor
                                        else -> Color.White.copy(alpha = 0.18f)
                                    }
                                )
                        )
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.75f)
                        .height(4.5.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.18f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth((level.toFloat() / def.maxLevel).coerceIn(0f, 1f))
                            .clip(RoundedCornerShape(50))
                            .background(if (maxed) GrassGreen else catColor)
                    )
                }
            }
            Text(
                text = if (maxed) "MAX" else "★ $nextCost",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                color = when {
                    maxed -> GrassGreen
                    affordable -> GoldAccent
                    else -> HudDimText
                }
            )
        }
    }
}

private fun categoryIcon(cat: String): ImageVector = when (cat) {
    "战斗" -> Icons.Rounded.Bolt
    "生存" -> Icons.Rounded.Favorite
    "机动" -> Icons.Rounded.Speed
    "必杀" -> Icons.Rounded.Star
    "成长" -> Icons.Rounded.AutoAwesome
    "构筑" -> Icons.Rounded.Science
    else -> Icons.Rounded.Shield
}

private fun categoryColor(cat: String): Color = when (cat) {
    "战斗" -> WarmOrange
    "生存" -> GrassGreenDeep
    "机动" -> SkyBlue
    "必杀" -> GoldAccent
    "成长" -> Color(0xFF42B883)
    else -> EpicPurple
}
