package com.example.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.evolution.EvolutionNode
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.BiomeDef
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.StarterLine
import com.example.ui.rememberCosmeticLoadout
import com.example.ui.components.AsyncDrawableImage
import com.example.ui.components.CosmeticFramePill
import com.example.ui.components.biomeBackdropRes
import com.example.ui.components.drawEvolvedHeroSprite
import com.example.ui.components.drawStarlightEntranceAura
import com.example.ui.components.withCosmeticLoadout
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.WarmOrange
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Full-bleed living biome backdrop with directional bloom, drifting motes,
 * and a light bottom gradient so floating HUD elements remain razor-sharp.
 */
@Composable
internal fun BiomeAtmosphereBackdrop(
    biome: BiomeDef,
    modifier: Modifier = Modifier
) {
    val ambientTransition = rememberInfiniteTransition(label = "menu_biome_ambient")
    val phase by ambientTransition.animateFloat(
        initialValue = 0f,
        targetValue = 6.283185f,
        animationSpec = infiniteRepeatable(tween(9000, easing = LinearEasing), RepeatMode.Restart),
        label = "biome_mote_phase"
    )

    val (topTintTarget, midTintTarget, bottomTintTarget, sunColorTarget, moteColorTarget) = when (biome.id) {
        "graveyard" -> BiomeMoodColors(
            top = Color(0x36141432),
            mid = Color(0x0E1A183A),
            bottom = Color(0x940D1020),
            glow = Color(0x428AF5FF),
            mote = Color(0xFFB59CFF)
        )
        "desert" -> BiomeMoodColors(
            top = Color(0x2C6E3E12),
            mid = Color(0x0A000000),
            bottom = Color(0x88241406),
            glow = Color(0x42FFE58A),
            mote = Color(0xFFFFE7A3)
        )
        "volcano" -> BiomeMoodColors(
            top = Color(0x38200A10),
            mid = Color(0x10300E0C),
            bottom = Color(0xA016070A),
            glow = Color(0x48FF6F2E),
            mote = Color(0xFFFF8F3D)
        )
        else -> BiomeMoodColors(
            top = Color(0x28123552),
            mid = Color(0x08000000),
            bottom = Color(0x86112111),
            glow = Color(0x40FFF6B8),
            mote = Color(0xFFFFF7BF)
        )
    }

    val topTint by animateColorAsState(topTintTarget, tween(520), label = "top_tint")
    val midTint by animateColorAsState(midTintTarget, tween(520), label = "mid_tint")
    val bottomTint by animateColorAsState(bottomTintTarget, tween(520), label = "bot_tint")
    val glowColor by animateColorAsState(sunColorTarget, tween(520), label = "glow_col")
    val moteColor by animateColorAsState(moteColorTarget, tween(520), label = "mote_col")

    Box(modifier = modifier.fillMaxSize()) {
        Crossfade(
            targetState = biome.id,
            animationSpec = tween(550),
            label = "biome_backdrop_crossfade"
        ) { targetBiomeId ->
            AsyncDrawableImage(
                resId = biomeBackdropRes(targetBiomeId),
                contentDescription = "主菜单群落氛围背景",
                maxDimPx = 960,
                preferRgb565 = true,
                contentScale = ContentScale.Crop,
                fallbackColor = HudInkDark,
                modifier = Modifier.fillMaxSize()
            )
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(listOf(topTint, midTint, bottomTint)))
        )
        Canvas(modifier = Modifier.fillMaxSize()) {
            val bloomCenter = when (biome.id) {
                "volcano" -> Offset(size.width * 0.45f, size.height * 0.80f)
                "graveyard" -> Offset(size.width * 0.35f, size.height * 0.24f)
                else -> Offset(size.width * 0.38f, size.height * 0.22f)
            }
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(glowColor, Color.Transparent),
                    center = bloomCenter,
                    radius = size.maxDimension * 0.56f
                ),
                radius = size.maxDimension * 0.56f,
                center = bloomCenter
            )

            for (i in 0 until 18) {
                val baseX = ((i * 79 + 19) % 100) / 100f * size.width
                val baseY = ((i * 53 + 11) % 100) / 100f * size.height
                val fx: Float
                val fy: Float
                when (biome.id) {
                    "volcano" -> {
                        val rise = ((phase / 6.283185f + i * 0.17f) % 1f)
                        fx = baseX + sin(phase * 1.6f + i) * 20f
                        fy = size.height * (1.05f - rise * 1.15f)
                    }
                    "desert" -> {
                        val drift = ((phase / 6.283185f + i * 0.13f) % 1f)
                        fx = size.width * drift
                        fy = baseY + sin(phase * 2.2f + i) * 10f
                    }
                    else -> {
                        fx = baseX + sin(phase + i) * 18f
                        fy = baseY + cos(phase * 1.3f + i * 2) * 14f
                    }
                }
                val alpha = 0.28f + 0.38f * (0.5f + 0.5f * sin(phase * 2f + i))
                val r = (2.6f + (i % 3) * 1.5f).dp.toPx()
                drawCircle(moteColor.copy(alpha = alpha * 0.40f), r * 2.2f, Offset(fx, fy))
                drawCircle(Color.White.copy(alpha = alpha * 0.85f), r * 0.82f, Offset(fx, fy))
            }
        }
    }
}

private data class BiomeMoodColors(
    val top: Color,
    val mid: Color,
    val bottom: Color,
    val glow: Color,
    val mote: Color
)

/**
 * Minimal, Iconic Centerpiece Hero Stage:
 * Large open-air sprite pedestal + quick left/right chevron cycling + single clean nameplate
 * with 1-tap triggers to Hero Roster Modal and Evolution Tree. Zero dashboard clutter!
 */
@Composable
internal fun MinimalHeroShowcaseStage(
    selected: StarterLine,
    unlockedEvolutionIds: Set<String>,
    isLandscape: Boolean,
    compact: Boolean,
    onCyclePrev: () -> Unit,
    onCycleNext: () -> Unit,
    onOpenRosterModal: () -> Unit,
    onOpenEvolutionPreview: () -> Unit,
    modifier: Modifier = Modifier
) {
    val starterTree = remember(selected.id) { EvolutionRegistry.treeForStarter(selected.id) }
    val unlockedForms = remember(selected.id, unlockedEvolutionIds) {
        val base = EvolutionRegistry.baseNodeForStarter(selected.id)
        val extra = starterTree.filter { it.id != base.id && it.id in unlockedEvolutionIds }
        listOf(base) + extra
    }
    val cosmeticLoadout = rememberCosmeticLoadout()
    val devnetFoxEquipped = com.example.wallet.devnetFoxSkinEquipped()
    var previewFormIdx by remember(selected.id) { mutableIntStateOf(0) }
    val previewNode: EvolutionNode = unlockedForms.getOrElse(previewFormIdx % unlockedForms.size) {
        EvolutionRegistry.baseNodeForStarter(selected.id)
    }
    val activeNode = previewNode.copy(
        visualStyle = previewNode.visualStyle.withCosmeticLoadout(cosmeticLoadout, devnetFoxEquipped)
    )
    val selectedIndex = remember(selected.id) {
        GameCatalog.starters.indexOfFirst { it.id == selected.id }.coerceAtLeast(0)
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 8.dp)
    ) {
        // Large Open-Air 3D Pedestal Stage flanked by clean quick-cycle arrows
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .then(
                    if (isLandscape) Modifier
                    else Modifier.padding(vertical = 2.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            OpenSpritePedestalCanvas(
                node = activeNode,
                onCycleForm = {
                    if (unlockedForms.size > 1) {
                        previewFormIdx = (previewFormIdx + 1) % unlockedForms.size
                    }
                },
                starlightEntrance = cosmeticLoadout.hasStarlightEntrance,
                modifier = Modifier.fillMaxSize()
            )

            // Left / Right quick-switch arrows
            StageCycleButton(
                icon = Icons.AutoMirrored.Rounded.KeyboardArrowLeft,
                contentDesc = "切换上一只精灵",
                testTag = "hero_prev_btn",
                onClick = onCyclePrev,
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .padding(start = 4.dp)
            )
            StageCycleButton(
                icon = Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                contentDesc = "切换下一只精灵",
                testTag = "hero_next_btn",
                onClick = onCycleNext,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 4.dp)
            )
        }

        // Compact 6-dot roster position + form interaction hint (never overlaps pedestal rim)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                GameCatalog.starters.forEachIndexed { idx, s ->
                    val isCurrent = idx == selectedIndex
                    Box(
                        modifier = Modifier
                            .size(width = if (isCurrent) 16.dp else 5.5.dp, height = 5.5.dp)
                            .clip(RoundedCornerShape(50))
                            .background(if (isCurrent) s.element.color else Color.White.copy(alpha = 0.35f))
                    )
                }
            }

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(HudInkDark.copy(alpha = 0.66f))
                    .border(1.dp, activeNode.visualStyle.auraColor.copy(alpha = 0.55f), RoundedCornerShape(50))
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Text(
                    text = if (unlockedForms.size > 1) "${activeNode.nameZh} · 轻触切形态" else "形态 ${unlockedForms.size}/${starterTree.size} · 轻触互动",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                    color = CreamSurface.copy(alpha = 0.90f),
                    maxLines = 1
                )
            }
            cosmeticLoadout.equippedFrame()?.let { frame ->
                CosmeticFramePill(frame = frame)
            }
        }

        // Single Clean Floating Nameplate + 2 Focused Actions (编队 / 进化树)
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(HudInkDark.copy(alpha = 0.80f))
                .border(1.4.dp, selected.element.color.copy(alpha = 0.80f), RoundedCornerShape(50))
                .padding(start = 14.dp, end = 6.dp, top = 4.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            AnimatedContent(
                targetState = selected,
                transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(140)) },
                label = "minimal_hero_nameplate",
                modifier = Modifier.weight(1f, fill = false)
            ) { hero ->
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = hero.codeName,
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontSize = if (compact) 14.5.sp else 16.5.sp,
                                fontWeight = FontWeight.ExtraBold
                            ),
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(hero.element.color)
                                .padding(horizontal = 7.dp, vertical = 1.dp)
                        ) {
                            Text(
                                text = hero.element.zhName,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold),
                                color = EspressoDark
                            )
                        }
                    }
                    Text(
                        text = "${hero.roleZh} · ${hero.passiveNameZh}",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = CreamSurface.copy(alpha = 0.80f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // 1-Tap Hero Roster Sheet Trigger
            Row(
                modifier = Modifier
                    .testTag("open_roster_modal_btn")
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.24f), RoundedCornerShape(50))
                    .clickable(onClick = onOpenRosterModal)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Icon(Icons.Rounded.Groups, contentDescription = "打开精灵编队", tint = CreamSurface, modifier = Modifier.size(14.dp))
                Text("编队", style = MaterialTheme.typography.labelMedium.copy(fontSize = 11.sp), color = CreamSurface)
            }

            // 1-Tap Evolution Tree Trigger
            Row(
                modifier = Modifier
                    .testTag("open_evo_preview_btn")
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(50))
                    .background(Brush.horizontalGradient(listOf(WarmOrange, GoldAccent)))
                    .border(1.4.dp, DarkButtonRim, RoundedCornerShape(50))
                    .clickable(onClick = onOpenEvolutionPreview)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Icon(Icons.Rounded.AutoAwesome, contentDescription = "分支进化预览", tint = EspressoDark, modifier = Modifier.size(14.dp))
                Text(
                    text = "进化",
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = 11.sp, fontWeight = FontWeight.ExtraBold),
                    color = EspressoDark
                )
            }
        }
    }
}

@Composable
private fun StageCycleButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDesc: String,
    testTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .testTag(testTag)
            .minimumInteractiveComponentSize()
            .size(38.dp)
            .clip(CircleShape)
            .background(HudInkDark.copy(alpha = 0.56f))
            .border(1.2.dp, Color.White.copy(alpha = 0.22f), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, contentDescription = contentDesc, tint = Color.White, modifier = Modifier.size(22.dp))
    }
}

@Composable
internal fun OpenSpritePedestalCanvas(
    node: EvolutionNode,
    onCycleForm: (() -> Unit)?,
    modifier: Modifier = Modifier,
    starlightEntrance: Boolean = false
) {
    val style = node.visualStyle
    val transition = rememberInfiniteTransition(label = "menu_stage_loop")
    val animTime by transition.animateFloat(
        initialValue = 0f,
        targetValue = 12.566371f,
        animationSpec = infiniteRepeatable(tween(6400, easing = LinearEasing), RepeatMode.Restart),
        label = "menu_sprite_anim"
    )
    val orbitAngle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 6.2831855f,
        animationSpec = infiniteRepeatable(tween(3800, easing = LinearEasing), RepeatMode.Restart),
        label = "menu_sprite_orbit"
    )

    var tapCount by remember(node.starterId) { mutableIntStateOf(0) }
    val bounceScale = remember { Animatable(1f) }
    val burstAlpha = remember { Animatable(0f) }
    val quirkAnim = remember(node.starterId) { Animatable(0f) }

    // Track 5: Periodic species personality quirk every ~7.2s while idling on the pedestal
    LaunchedEffect(node.starterId) {
        quirkAnim.snapTo(0f)
        while (true) {
            delay(7200L)
            quirkAnim.snapTo(1f)
            quirkAnim.animateTo(0f, tween(780, easing = LinearEasing))
        }
    }

    LaunchedEffect(tapCount) {
        if (tapCount > 0) {
            coroutineScope {
                launch {
                    bounceScale.snapTo(0.92f)
                    bounceScale.animateTo(1.06f, spring(dampingRatio = 0.48f, stiffness = 540f))
                    bounceScale.animateTo(1f, spring(dampingRatio = 0.68f, stiffness = 380f))
                }
                launch {
                    burstAlpha.snapTo(1f)
                    burstAlpha.animateTo(0f, tween(340, easing = LinearEasing))
                }
                launch {
                    quirkAnim.snapTo(1f)
                    quirkAnim.animateTo(0f, tween(740, easing = LinearEasing))
                }
            }
        }
    }

    Box(
        modifier = modifier
            .testTag("menu_live_hero_stage")
            .scale(bounceScale.value)
            .then(
                if (onCycleForm == null) Modifier else Modifier.clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) {
                    tapCount++
                    onCycleForm()
                }
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val cx = size.width * 0.5f

            // Density-independent coupled sizing: sprite feet anchor directly at pedestal top center!
            val visualR = (size.height * 0.235f)
                .coerceAtMost(size.width * 0.19f)
                .coerceAtLeast(18.dp.toPx())
            val safeScale = style.scaleFactor.coerceAtLeast(0.85f)
            val baseRadius = visualR / safeScale

            // Pedestal top-deck center sits cleanly in the lower third; sprite feet stand squarely ON it
            val pedCenterY = size.height * 0.74f
            val spriteCenterY = pedCenterY - visualR * 1.00f
            val spriteCenter = Offset(cx, spriteCenterY)

            val pedW = visualR * 3.55f
            val pedH = visualR * 0.94f
            val pedDepth = visualR * 0.32f
            val pedTopY = pedCenterY - pedH * 0.5f

            // 1. Soft atmospheric hero spotlight behind sprite & pedestal
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(
                        style.auraColor.copy(alpha = 0.36f),
                        style.auraColor.copy(alpha = 0.10f),
                        Color.Transparent
                    ),
                    center = Offset(cx, spriteCenterY + visualR * 0.15f),
                    radius = visualR * 2.55f
                ),
                radius = visualR * 2.55f,
                center = Offset(cx, spriteCenterY + visualR * 0.15f)
            )

            // 2. Ground cast shadow under the 3D pedestal base
            drawOval(
                color = Color.Black.copy(alpha = 0.42f),
                topLeft = Offset(cx - pedW * 0.54f, pedTopY + pedDepth + pedH * 0.14f),
                size = Size(pedW * 1.08f, pedH * 1.04f)
            )

            // 3. 3D Sculpted Pedestal Base (lower plinth wall + rim for tangible elevation)
            drawOval(
                brush = Brush.horizontalGradient(
                    colors = listOf(
                        Color(0xFF141826),
                        Color(0xFF2B344D),
                        Color(0xFF1A2033)
                    ),
                    startX = cx - pedW * 0.5f,
                    endX = cx + pedW * 0.5f
                ),
                topLeft = Offset(cx - pedW * 0.5f, pedTopY + pedDepth),
                size = Size(pedW, pedH)
            )
            drawRect(
                brush = Brush.horizontalGradient(
                    colors = listOf(
                        Color(0xFF141826),
                        Color(0xFF2E3852),
                        Color(0xFF171C2C)
                    ),
                    startX = cx - pedW * 0.5f,
                    endX = cx + pedW * 0.5f
                ),
                topLeft = Offset(cx - pedW * 0.5f, pedCenterY),
                size = Size(pedW, pedDepth)
            )
            drawArc(
                color = style.auraColor.copy(alpha = 0.42f),
                startAngle = 0f,
                sweepAngle = 180f,
                useCenter = false,
                topLeft = Offset(cx - pedW * 0.5f, pedTopY + pedDepth),
                size = Size(pedW, pedH),
                style = Stroke(width = 1.6.dp.toPx(), cap = StrokeCap.Round)
            )

            // 4. Luminous Pedestal Top Deck (where the sprite's feet stand!)
            drawOval(
                brush = Brush.radialGradient(
                    colors = listOf(
                        style.auraColor.copy(alpha = 0.52f),
                        Color(0xFF28324B).copy(alpha = 0.94f),
                        Color(0xFF171D2E).copy(alpha = 0.98f)
                    ),
                    center = Offset(cx, pedCenterY),
                    radius = pedW * 0.55f
                ),
                topLeft = Offset(cx - pedW * 0.5f, pedTopY),
                size = Size(pedW, pedH)
            )
            // Outer illuminated bevel rim
            drawOval(
                color = style.auraColor.copy(alpha = 0.86f),
                topLeft = Offset(cx - pedW * 0.5f, pedTopY),
                size = Size(pedW, pedH),
                style = Stroke(width = 2.2.dp.toPx())
            )
            // Inner standing pad ring directly beneath the sprite's feet
            drawOval(
                color = Color.White.copy(alpha = 0.22f),
                topLeft = Offset(cx - pedW * 0.32f, pedTopY + pedH * 0.18f),
                size = Size(pedW * 0.64f, pedH * 0.64f),
                style = Stroke(width = 1.2.dp.toPx())
            )
            // Orbiting elemental rune arcs hugging the pedestal top deck
            drawArc(
                color = GoldAccent.copy(alpha = 0.94f),
                startAngle = orbitAngle * 57.29578f,
                sweepAngle = 112f,
                useCenter = false,
                topLeft = Offset(cx - pedW * 0.44f, pedTopY + pedH * 0.08f),
                size = Size(pedW * 0.88f, pedH * 0.84f),
                style = Stroke(width = 2.6.dp.toPx(), cap = StrokeCap.Round)
            )
            if (starlightEntrance) {
                drawStarlightEntranceAura(
                    center = spriteCenter,
                    radius = visualR * 1.05f,
                    animTime = animTime,
                    subtle = false
                )
            }
            drawArc(
                color = Color.White.copy(alpha = 0.72f),
                startAngle = orbitAngle * 57.29578f + 180f,
                sweepAngle = 76f,
                useCenter = false,
                topLeft = Offset(cx - pedW * 0.44f, pedTopY + pedH * 0.08f),
                size = Size(pedW * 0.88f, pedH * 0.84f),
                style = Stroke(width = 1.8.dp.toPx(), cap = StrokeCap.Round)
            )

            // 5. Rising elemental sparkles around the pedestal (harmonic 0.5x = 100% seamless loop)
            for (i in 0 until 8) {
                val a = orbitAngle + i * 0.7853982f
                val px = cx + cos(a) * (pedW * 0.46f)
                val py = pedCenterY - (visualR * 2.1f) * ((sin(animTime * 0.5f + i) + 1f) * 0.5f)
                drawCircle(style.auraColor.copy(alpha = 0.44f), 3.6.dp.toPx(), Offset(px, py))
                drawCircle(Color.White.copy(alpha = 0.88f), 1.5.dp.toPx(), Offset(px, py))
            }

            // 6. Tap shockwave burst expanding along the pedestal plane
            if (burstAlpha.value > 0.02f) {
                val ringScale = 0.45f + (1f - burstAlpha.value) * 0.65f
                drawOval(
                    color = GoldAccent.copy(alpha = burstAlpha.value * 0.92f),
                    topLeft = Offset(cx - pedW * 0.5f * ringScale, pedCenterY - pedH * 0.5f * ringScale),
                    size = Size(pedW * ringScale, pedH * ringScale),
                    style = Stroke(width = 3.dp.toPx())
                )
            }

            // 7. Hero Sprite planted squarely on top of the pedestal!
            // Calm grounded breathing + periodic personality quirks; tapping triggers showcase strike & quirk!
            drawEvolvedHeroSprite(
                style = style,
                center = spriteCenter,
                baseRadius = baseRadius,
                animTime = animTime,
                orbitAngle = orbitAngle,
                facingAngle = sin(animTime * 0.5f) * 0.36f,
                moveSpeedRatio = 0f,
                isAttacking = burstAlpha.value > 0.02f,
                attackProgress = burstAlpha.value,
                quirkProgress = quirkAnim.value
            )
        }
    }
}

/**
 * Sleek 1-Tap Expedition Summary Card:
 * Displays ONLY the active loadout (Biome + Mode + Matchup + Challenge bonus) on the lobby screen,
 * opening the spacious [ExpeditionConfigModal] on tap.
 */
@Composable
internal fun ExpeditionSummaryCard(
    biome: BiomeDef,
    mode: GameMode,
    matchupMult: Float,
    challengeCount: Int,
    challengeDustBonusPct: Int,
    onOpenConfig: () -> Unit,
    modifier: Modifier = Modifier
) {
    val modeTint = when (mode) {
        GameMode.CLASSIC -> GrassGreenDeep
        GameMode.SURVIVAL -> WarmOrange
        GameMode.DUEL -> Color(0xFF7B4CE8)
    }
    val modeIcon = when (mode) {
        GameMode.CLASSIC -> Icons.Rounded.Flag
        GameMode.SURVIVAL -> Icons.Rounded.Whatshot
        GameMode.DUEL -> Icons.Rounded.Bolt
    }
    val shape = RoundedCornerShape(18.dp)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag("open_expedition_config_btn")
            .minimumInteractiveComponentSize()
            .shadow(8.dp, shape)
            .clip(shape)
            .background(HudInkDark.copy(alpha = 0.82f))
            .border(1.5.dp, Color.White.copy(alpha = 0.22f), shape)
            .clickable(onClick = onOpenConfig)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Scenic Biome Thumbnail Badge
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(12.dp))
                .border(1.5.dp, GoldAccent.copy(alpha = 0.85f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center
        ) {
            AsyncDrawableImage(
                resId = biomeBackdropRes(biome.id),
                contentDescription = biome.nameZh,
                maxDimPx = 192,
                preferRgb565 = true,
                contentScale = ContentScale.Crop,
                fallbackColor = biome.accentColor,
                modifier = Modifier.fillMaxSize()
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.34f))
            )
            Icon(modeIcon, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
        }

        // Active Expedition Readout
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = biome.nameZh,
                    style = MaterialTheme.typography.titleSmall.copy(fontSize = 14.sp, fontWeight = FontWeight.ExtraBold),
                    color = Color.White,
                    maxLines = 1
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(modeTint)
                        .padding(horizontal = 7.dp, vertical = 1.5.dp)
                ) {
                    Text(
                        text = mode.nameZh,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Bold),
                        color = Color.White,
                        maxLines = 1
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "守护者：${biome.bossNameZh}",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                    color = CreamSurface.copy(alpha = 0.82f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                if (matchupMult >= 1.3f) {
                    Text(
                        text = "⚡克制",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
                        color = Color(0xFF7BFF9A)
                    )
                } else if (matchupMult <= 0.9f) {
                    Text(
                        text = "受阻",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
                        color = CrimsonRed
                    )
                }
                if (challengeCount > 0) {
                    Text(
                        text = "🔥词条×$challengeCount (+$challengeDustBonusPct%)",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
                        color = GoldAccent,
                        maxLines = 1
                    )
                }
            }
        }

        // Right Action Chip
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = 0.12f))
                .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(10.dp))
                .padding(horizontal = 8.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Icon(Icons.Rounded.Tune, contentDescription = "切换出征配置", tint = GoldAccent, modifier = Modifier.size(14.dp))
            Text(
                text = "配置",
                style = MaterialTheme.typography.labelMedium.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold),
                color = CreamSurface
            )
        }
    }
}
