package com.example.ui.components

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Star
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.evolution.EvolutionNode
import com.example.game.evolution.EvolutionRegistry
import com.example.game.evolution.EvolutionResourceType
import com.example.game.evolution.EvolutionStateSnapshot
import com.example.game.model.GameCatalog
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.WarmOrange

/**
 * Interactive Sprite Evolution Path & Real-Time Preview Overlay.
 * Adapts seamlessly between a compact dual-pane landscape layout (Branch Tree on Left,
 * Live Preview + Stats + CTA on Right) and a stacked portrait layout, with full
 * WindowInsets.safeDrawing support for landscape cutouts and gesture bars.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EvolutionTreeOverlay(
    starterId: String,
    inBattle: Boolean,
    playerLevel: Int,
    evoSnapshot: EvolutionStateSnapshot?,
    unlockedEvolutionIds: Set<String> = emptySet(),
    onEvolveTo: ((String) -> Unit)? = null,
    onDismiss: () -> Unit
) {
    BackHandler(onBack = onDismiss)
    val baseNode = remember(starterId) { EvolutionRegistry.baseNodeForStarter(starterId) }
    val tier1Nodes = remember(starterId) { baseNode.nextNodeIds.map { EvolutionRegistry.nodeById(it) } }
    val tier2Nodes = remember(starterId) { tier1Nodes.flatMap { it.nextNodeIds }.map { EvolutionRegistry.nodeById(it) } }

    val currentNodeId = evoSnapshot?.currentNodeId ?: baseNode.id
    val currentNode = EvolutionRegistry.nodeById(currentNodeId)

    var previewNodeId by remember(starterId, currentNodeId) {
        val firstNext = currentNode.nextNodeIds.firstOrNull()
        mutableStateOf(firstNext ?: currentNodeId)
    }
    val previewNode = EvolutionRegistry.nodeById(previewNodeId)
    val resources = evoSnapshot?.resources ?: emptyMap()

    val isReachableNext = currentNode.nextNodeIds.contains(previewNode.id)
    val levelMet = playerLevel >= previewNode.requiredLevel
    val missingRes = previewNode.resourceCost.mapNotNull { (res, need) ->
        val have = resources[res] ?: 0
        if (have < need) res to (need - have) else null
    }.toMap()
    val canEvolveNow = inBattle && isReachableNext && levelMet && missingRes.isEmpty()

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.72f))
            .clickable(onClick = onDismiss)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        val isLandscape = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
        val isCompactH = maxHeight < 420.dp

        DarkGlassPanel(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(min = 300.dp, max = if (isLandscape) 860.dp else 590.dp)
                .clickable(enabled = false) {},
            cornerRadius = if (isCompactH) 20.dp else 24.dp,
            borderColor = previewNode.visualStyle.auraColor.copy(alpha = 0.80f),
            borderWidth = 1.8.dp,
            containerColor = HudInkDark.copy(alpha = 0.96f),
            contentPadding = PaddingValues(
                horizontal = if (isCompactH) 12.dp else 16.dp,
                vertical = if (isCompactH) 10.dp else 15.dp
            )
        ) {
            if (isLandscape) {
                Column(
                    modifier = Modifier.verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(if (isCompactH) 8.dp else 10.dp)
                ) {
                    // Unified slim landscape top bar: Title + inline Resources + Close
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = if (inBattle) "进化路径 · 分支选择" else "进化路线图鉴",
                                style = if (isCompactH) MaterialTheme.typography.titleMedium else MaterialTheme.typography.headlineSmall,
                                color = Color.White,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = if (inBattle) "当前：${currentNode.nameZh} (Lv.$playerLevel)" else "点击左侧节点预览形态、必杀与属性加成",
                                style = MaterialTheme.typography.labelSmall,
                                color = HudDimText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        if (inBattle) {
                            EvolutionResourcesStrip(
                                resources = resources,
                                compact = true,
                                modifier = Modifier.widthIn(max = 360.dp)
                            )
                        }
                        EvolutionCloseButton(
                            onDismiss = onDismiss,
                            compact = isCompactH
                        )
                    }

                    // Dual-pane landscape body: Left = Branching Tree + Requirements, Right = Live Preview + Stats + Action CTA
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Column(
                            modifier = Modifier.weight(1.06f),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 6.dp else 8.dp)
                        ) {
                            EvolutionBranchTreePanel(
                                baseNode = baseNode,
                                tier1Nodes = tier1Nodes,
                                tier2Nodes = tier2Nodes,
                                currentNode = currentNode,
                                currentNodeId = currentNodeId,
                                previewNodeId = previewNodeId,
                                inBattle = inBattle,
                                playerLevel = playerLevel,
                                resources = resources,
                                evoSnapshot = evoSnapshot,
                                unlockedEvolutionIds = unlockedEvolutionIds,
                                compact = isCompactH,
                                onSelectNode = { previewNodeId = it }
                            )
                            if (previewNode.tier > 0) {
                                EvolutionRequirementsBar(
                                    previewNode = previewNode,
                                    inBattle = inBattle,
                                    levelMet = levelMet,
                                    resources = resources,
                                    compact = isCompactH
                                )
                            }
                        }

                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(if (isCompactH) 6.dp else 8.dp)
                        ) {
                            EvolutionPreviewInspectorCard(
                                previewNode = previewNode,
                                stageSize = if (isCompactH) 84.dp else 108.dp,
                                compact = isCompactH
                            )
                            EvolutionStatBonusesSection(
                                previewNode = previewNode,
                                compact = isCompactH
                            )
                            EvolutionPrimaryActionButton(
                                inBattle = inBattle,
                                onEvolveTo = onEvolveTo,
                                previewNode = previewNode,
                                currentNodeId = currentNodeId,
                                evoSnapshot = evoSnapshot,
                                isReachableNext = isReachableNext,
                                levelMet = levelMet,
                                missingRes = missingRes,
                                canEvolveNow = canEvolveNow,
                                onDismiss = onDismiss,
                                height = if (isCompactH) 40.dp else 46.dp
                            )
                        }
                    }
                }
            } else {
                // Portrait vertical layout
                Column(
                    modifier = Modifier.verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = if (inBattle) "进化路径 · 实时分支选择" else "进化路线图鉴 · 实时预览",
                                style = MaterialTheme.typography.headlineSmall,
                                color = Color.White
                            )
                            Text(
                                text = if (inBattle) "当前：${currentNode.nameZh} (Lv.$playerLevel)" else "点击任意节点预览形态外观、必杀与加成",
                                style = MaterialTheme.typography.labelMedium,
                                color = HudDimText
                            )
                        }
                        EvolutionCloseButton(onDismiss = onDismiss, compact = false)
                    }

                    if (inBattle) {
                        EvolutionResourcesStrip(
                            resources = resources,
                            compact = false,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }

                    EvolutionBranchTreePanel(
                        baseNode = baseNode,
                        tier1Nodes = tier1Nodes,
                        tier2Nodes = tier2Nodes,
                        currentNode = currentNode,
                        currentNodeId = currentNodeId,
                        previewNodeId = previewNodeId,
                        inBattle = inBattle,
                        playerLevel = playerLevel,
                        resources = resources,
                        evoSnapshot = evoSnapshot,
                        unlockedEvolutionIds = unlockedEvolutionIds,
                        compact = false,
                        onSelectNode = { previewNodeId = it }
                    )

                    EvolutionPreviewInspectorCard(
                        previewNode = previewNode,
                        stageSize = 128.dp,
                        compact = false
                    )

                    EvolutionStatBonusesSection(
                        previewNode = previewNode,
                        compact = false
                    )

                    if (previewNode.tier > 0) {
                        EvolutionRequirementsBar(
                            previewNode = previewNode,
                            inBattle = inBattle,
                            levelMet = levelMet,
                            resources = resources,
                            compact = false
                        )
                    }

                    EvolutionPrimaryActionButton(
                        inBattle = inBattle,
                        onEvolveTo = onEvolveTo,
                        previewNode = previewNode,
                        currentNodeId = currentNodeId,
                        evoSnapshot = evoSnapshot,
                        isReachableNext = isReachableNext,
                        levelMet = levelMet,
                        missingRes = missingRes,
                        canEvolveNow = canEvolveNow,
                        onDismiss = onDismiss,
                        height = 48.dp
                    )
                }
            }
        }
    }
}

@Composable
private fun EvolutionCloseButton(
    onDismiss: () -> Unit,
    compact: Boolean
) {
    Box(
        modifier = Modifier
            .testTag("evo_modal_close_btn")
            .minimumInteractiveComponentSize()
            .size(if (compact) 36.dp else 40.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.10f))
            .border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape)
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Rounded.Close,
            contentDescription = "关闭进化面板",
            tint = CreamSurface,
            modifier = Modifier.size(if (compact) 18.dp else 22.dp)
        )
    }
}

@Composable
private fun EvolutionResourcesStrip(
    resources: Map<EvolutionResourceType, Int>,
    compact: Boolean,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(if (compact) 14.dp else 16.dp))
            .background(HudInkDark.copy(alpha = 0.92f))
            .border(1.8.dp, DarkButtonRim, RoundedCornerShape(if (compact) 14.dp else 16.dp))
            .padding(horizontal = if (compact) 10.dp else 10.dp, vertical = if (compact) 5.dp else 8.dp),
        horizontalArrangement = if (compact) Arrangement.spacedBy(10.dp) else Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (res in EvolutionResourceType.entries) {
            val qty = resources[res] ?: 0
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(if (compact) 9.dp else 11.dp)
                        .clip(CircleShape)
                        .background(res.color)
                        .border(1.dp, Color.White, CircleShape)
                )
                Text(
                    text = "${res.shortZh} $qty",
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = if (compact) 10.5.sp else 11.sp),
                    color = Color.White,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun EvolutionBranchTreePanel(
    baseNode: EvolutionNode,
    tier1Nodes: List<EvolutionNode>,
    tier2Nodes: List<EvolutionNode>,
    currentNode: EvolutionNode,
    currentNodeId: String,
    previewNodeId: String,
    inBattle: Boolean,
    playerLevel: Int,
    resources: Map<EvolutionResourceType, Int>,
    evoSnapshot: EvolutionStateSnapshot?,
    unlockedEvolutionIds: Set<String>,
    compact: Boolean,
    onSelectNode: (String) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 14.dp else 18.dp))
            .background(Color.Black.copy(alpha = 0.30f))
            .border(1.2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(if (compact) 14.dp else 18.dp))
            .padding(if (compact) 8.dp else 12.dp)
    ) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val passed = evoSnapshot?.historyNodeIds.orEmpty().toSet()
            val topCenter = Offset(size.width * 0.5f, size.height * 0.16f)
            val midL = Offset(size.width * 0.25f, size.height * 0.52f)
            val midR = Offset(size.width * 0.75f, size.height * 0.52f)
            val botL = Offset(size.width * 0.25f, size.height * 0.86f)
            val botR = Offset(size.width * 0.75f, size.height * 0.86f)

            val t1LId = tier1Nodes.getOrNull(0)?.id
            val t1RId = tier1Nodes.getOrNull(1)?.id
            val t2LId = tier2Nodes.getOrNull(0)?.id
            val t2RId = tier2Nodes.getOrNull(1)?.id

            fun drawBranchCurve(start: Offset, end: Offset, targetId: String?) {
                val active = targetId != null && (passed.contains(targetId) || targetId == previewNodeId)
                val color = when {
                    targetId != null && passed.contains(targetId) -> GrassGreen
                    targetId != null && targetId == previewNodeId -> GoldAccent
                    else -> Color.White.copy(alpha = 0.22f)
                }
                val midY = (start.y + end.y) * 0.5f
                val path = Path().apply {
                    moveTo(start.x, start.y)
                    cubicTo(start.x, midY, end.x, midY, end.x, end.y)
                }
                if (active) {
                    drawPath(path, color = color.copy(alpha = 0.30f), style = Stroke(width = 10f, cap = StrokeCap.Round))
                }
                drawPath(path, color = color, style = Stroke(width = if (active) 5f else 3.4f, cap = StrokeCap.Round))
            }

            drawBranchCurve(topCenter, midL, t1LId)
            drawBranchCurve(topCenter, midR, t1RId)
            drawBranchCurve(midL, botL, t2LId)
            drawBranchCurve(midR, botR, t2RId)
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            EvolutionTreeNodeChip(
                node = baseNode,
                tierBadge = "初阶",
                isSelected = previewNodeId == baseNode.id,
                isCurrent = inBattle && currentNodeId == baseNode.id,
                isPassed = inBattle && (evoSnapshot?.historyNodeIds?.contains(baseNode.id) == true),
                isUnlockedForever = unlockedEvolutionIds.contains(baseNode.id) || baseNode.tier == 0,
                canEvolve = false,
                compact = compact,
                onClick = { onSelectNode(baseNode.id) }
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 10.dp)
            ) {
                for (node in tier1Nodes) {
                    val ready = inBattle && currentNode.nextNodeIds.contains(node.id) &&
                        playerLevel >= node.requiredLevel &&
                        node.resourceCost.all { (r, c) -> (resources[r] ?: 0) >= c }
                    EvolutionTreeNodeChip(
                        node = node,
                        tierBadge = "一阶",
                        isSelected = previewNodeId == node.id,
                        isCurrent = inBattle && currentNodeId == node.id,
                        isPassed = inBattle && (evoSnapshot?.historyNodeIds?.contains(node.id) == true),
                        isUnlockedForever = unlockedEvolutionIds.contains(node.id),
                        canEvolve = ready,
                        compact = compact,
                        onClick = { onSelectNode(node.id) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(if (compact) 7.dp else 10.dp)
            ) {
                for (node in tier2Nodes) {
                    val ready = inBattle && currentNode.nextNodeIds.contains(node.id) &&
                        playerLevel >= node.requiredLevel &&
                        node.resourceCost.all { (r, c) -> (resources[r] ?: 0) >= c }
                    EvolutionTreeNodeChip(
                        node = node,
                        tierBadge = "终阶",
                        isSelected = previewNodeId == node.id,
                        isCurrent = inBattle && currentNodeId == node.id,
                        isPassed = inBattle && (evoSnapshot?.historyNodeIds?.contains(node.id) == true),
                        isUnlockedForever = unlockedEvolutionIds.contains(node.id),
                        canEvolve = ready,
                        compact = compact,
                        onClick = { onSelectNode(node.id) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun EvolutionPreviewInspectorCard(
    previewNode: EvolutionNode,
    stageSize: Dp,
    compact: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 14.dp else 18.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.4.dp, previewNode.visualStyle.auraColor.copy(alpha = 0.60f), RoundedCornerShape(if (compact) 14.dp else 18.dp))
            .padding(if (compact) 8.dp else 10.dp),
        horizontalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        LiveEvolutionPreviewStage(
            style = previewNode.visualStyle,
            stageSize = stageSize
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(if (compact) 2.dp else 4.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(previewNode.visualStyle.auraColor)
                        .padding(horizontal = 7.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = previewNode.branchLabelZh,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.5.sp else 11.sp),
                        color = EspressoDark,
                        maxLines = 1
                    )
                }
                if (compact) {
                    Text(
                        text = previewNode.roleTagZh,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = GrassGreen,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Text(
                text = previewNode.nameZh,
                style = if (compact) MaterialTheme.typography.titleMedium else MaterialTheme.typography.headlineSmall,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (!compact) {
                Text(previewNode.roleTagZh, style = MaterialTheme.typography.labelMedium, color = GrassGreen)
            }
            Text(
                text = previewNode.descZh,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = if (compact) 11.sp else 12.sp),
                color = CreamSurface.copy(alpha = 0.80f),
                maxLines = if (compact) 2 else 3,
                overflow = TextOverflow.Ellipsis
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(Icons.Rounded.Star, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(13.dp))
                Text(
                    text = "必杀：${previewNode.ultNameZh}",
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = if (compact) 11.sp else 12.sp),
                    color = GoldAccent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            previewNode.bonusMoveId?.let { mid ->
                GameCatalog.moves[mid]?.let { mv ->
                    Text(
                        text = "习得/强化：${mv.nameZh}",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 10.sp else 11.sp),
                        color = CreamSurface.copy(alpha = 0.90f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EvolutionStatBonusesSection(
    previewNode: EvolutionNode,
    compact: Boolean
) {
    val statLines = previewNode.statDelta.summaryLines()
    if (statLines.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(if (compact) 4.dp else 6.dp)) {
        if (!compact) {
            Text("形态进化加成", style = MaterialTheme.typography.labelLarge, color = CreamSurface)
        }
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            statLines.forEach { line ->
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(9.dp))
                        .background(GrassGreen.copy(alpha = 0.20f))
                        .border(1.dp, GrassGreen.copy(alpha = 0.62f), RoundedCornerShape(9.dp))
                        .padding(horizontal = if (compact) 7.dp else 9.dp, vertical = if (compact) 3.dp else 4.dp)
                ) {
                    Text(
                        text = line,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 10.sp else 11.sp),
                        color = Color.White
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EvolutionRequirementsBar(
    previewNode: EvolutionNode,
    inBattle: Boolean,
    levelMet: Boolean,
    resources: Map<EvolutionResourceType, Int>,
    compact: Boolean
) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(if (compact) 12.dp else 14.dp))
            .padding(horizontal = if (compact) 10.dp else 12.dp, vertical = if (compact) 6.dp else 8.dp),
        horizontalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        RequirementCheckChip(
            label = "等级 Lv.${previewNode.requiredLevel}",
            met = !inBattle || levelMet,
            compact = compact
        )
        for ((res, cost) in previewNode.resourceCost) {
            val have = resources[res] ?: 0
            RequirementCheckChip(
                label = if (inBattle) "${res.shortZh} $have/$cost" else "${res.shortZh}×$cost",
                met = !inBattle || have >= cost,
                compact = compact
            )
        }
    }
}

@Composable
private fun EvolutionPrimaryActionButton(
    inBattle: Boolean,
    onEvolveTo: ((String) -> Unit)?,
    previewNode: EvolutionNode,
    currentNodeId: String,
    evoSnapshot: EvolutionStateSnapshot?,
    isReachableNext: Boolean,
    levelMet: Boolean,
    missingRes: Map<EvolutionResourceType, Int>,
    canEvolveNow: Boolean,
    onDismiss: () -> Unit,
    height: Dp
) {
    if (inBattle && onEvolveTo != null) {
        val btnLabel = when {
            previewNode.id == currentNodeId -> "当前形态"
            evoSnapshot?.historyNodeIds?.contains(previewNode.id) == true -> "已完成该阶段"
            !isReachableNext -> "需先进化前置分支"
            !levelMet -> "需要达到 Lv.${previewNode.requiredLevel}"
            missingRes.isNotEmpty() -> "收集更多精华解锁进化"
            else -> "立即进化为 ${previewNode.nameZh}!"
        }
        ChunkyButton(
            text = btnLabel,
            onClick = { onEvolveTo(previewNode.id) },
            tone = if (canEvolveNow) ChunkyButtonTone.ORANGE else ChunkyButtonTone.CREAM,
            icon = if (canEvolveNow) Icons.Rounded.AutoAwesome else Icons.AutoMirrored.Rounded.TrendingUp,
            enabled = canEvolveNow,
            shimmer = canEvolveNow,
            height = height,
            testTag = "confirm_evolve_btn",
            modifier = Modifier.fillMaxWidth()
        )
    } else {
        ChunkyButton(
            text = "关闭预览",
            onClick = onDismiss,
            tone = ChunkyButtonTone.GREEN,
            height = height,
            testTag = "close_evo_preview_btn",
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun RequirementCheckChip(label: String, met: Boolean, compact: Boolean = false) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = if (met) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel,
            contentDescription = null,
            tint = if (met) GrassGreen else CrimsonRed,
            modifier = Modifier.size(if (compact) 13.dp else 15.dp)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium.copy(fontSize = if (compact) 11.sp else 12.sp),
            color = if (met) CreamSurface else Color(0xFFFF8F96)
        )
    }
}

@Composable
private fun EvolutionTreeNodeChip(
    node: EvolutionNode,
    tierBadge: String,
    isSelected: Boolean,
    isCurrent: Boolean,
    isPassed: Boolean,
    isUnlockedForever: Boolean,
    canEvolve: Boolean,
    compact: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val borderColor = when {
        isSelected -> GoldAccent
        canEvolve -> WarmOrange
        isCurrent -> GrassGreen
        isPassed -> GrassGreen.copy(alpha = 0.72f)
        else -> Color.White.copy(alpha = 0.16f)
    }
    val bgColor = when {
        canEvolve -> WarmOrange.copy(alpha = 0.24f)
        isCurrent -> GrassGreen.copy(alpha = 0.22f)
        isSelected -> node.visualStyle.auraColor.copy(alpha = 0.22f)
        else -> HudInkDark.copy(alpha = 0.88f)
    }

    Row(
        modifier = modifier
            .testTag("evo_node_${node.id}")
            .minimumInteractiveComponentSize()
            .clip(RoundedCornerShape(if (compact) 11.dp else 14.dp))
            .background(bgColor)
            .border(
                if (isSelected || canEvolve) 2.dp else 1.2.dp,
                borderColor,
                RoundedCornerShape(if (compact) 11.dp else 14.dp)
            )
            .clickable(onClick = onClick)
            .padding(
                horizontal = if (compact) 7.dp else 10.dp,
                vertical = if (compact) 5.dp else 7.dp
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 7.dp)
    ) {
        Box(
            modifier = Modifier
                .size(if (compact) 20.dp else 24.dp)
                .clip(CircleShape)
                .background(node.visualStyle.primaryColor)
                .border(1.8.dp, node.visualStyle.accentColor, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            if (isCurrent || isPassed) {
                Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(if (compact) 12.dp else 14.dp))
            } else if (canEvolve) {
                Icon(Icons.Rounded.AutoAwesome, contentDescription = null, tint = GoldAccent, modifier = Modifier.size(if (compact) 12.dp else 14.dp))
            } else if (!isUnlockedForever && node.tier > 0) {
                Icon(Icons.Rounded.Lock, contentDescription = null, tint = Color.White.copy(alpha = 0.80f), modifier = Modifier.size(11.dp))
            }
        }
        Column(modifier = Modifier.weight(1f, fill = false)) {
            Text(
                text = node.nameZh,
                style = MaterialTheme.typography.labelLarge.copy(fontSize = if (compact) 11.sp else 12.sp),
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = when {
                    canEvolve -> "$tierBadge · 可进化!"
                    isCurrent -> "$tierBadge · 当前"
                    node.tier == 0 -> "$tierBadge · 初始"
                    else -> "$tierBadge · Lv.${node.requiredLevel}"
                },
                style = MaterialTheme.typography.labelSmall.copy(fontSize = if (compact) 9.sp else 9.5.sp),
                color = if (canEvolve) GoldAccent else HudDimText,
                maxLines = 1
            )
        }
    }
}
