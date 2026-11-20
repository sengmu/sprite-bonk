package com.example.ui.components

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.example.game.engine.BattleRenderState
import com.example.game.engine.BiomeZoneKind
import com.example.game.engine.BiomeZonePhase
import com.example.game.engine.BossAttackKind
import com.example.game.engine.EnemySnapshot
import com.example.game.engine.ParticleShape
import com.example.game.engine.PickupKind
import com.example.game.engine.WorldPropKind
import com.example.game.model.BiomeDef
import com.example.game.model.ElementType
import com.example.game.model.GameCatalog
import com.example.game.model.MoveArchetype
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import com.example.ui.theme.WoodenChestBrown
import com.example.ui.theme.WoodenChestGold
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

// Pre-allocated Stroke constants to keep 60fps draw passes allocation-free
private val STROKE_2_2 = Stroke(width = 2.2f)
private val STROKE_2_4 = Stroke(width = 2.4f)
private val STROKE_2_5 = Stroke(width = 2.5f)
private val STROKE_2_6 = Stroke(width = 2.6f)
private val STROKE_2_8 = Stroke(width = 2.8f)
private val STROKE_3_0 = Stroke(width = 3.0f)
private val STROKE_3_2 = Stroke(width = 3.2f)
private val STROKE_3_5 = Stroke(width = 3.5f)
private val STROKE_4_0 = Stroke(width = 4.0f)
private val STROKE_4_2 = Stroke(width = 4.2f)
private val STROKE_4_4 = Stroke(width = 4.4f)
private val STROKE_4_5 = Stroke(width = 4.5f)
private val STROKE_5_0 = Stroke(width = 5.0f)
private val STROKE_6_0 = Stroke(width = 6.0f)
private val STROKE_7_5 = Stroke(width = 7.5f)
private val STROKE_CHEVRON = Stroke(width = 4f, cap = StrokeCap.Round)
private val STROKE_MAGNET_ARC = Stroke(width = 7.2f, cap = StrokeCap.Round)

private class BattleCanvasCache {
    val terrainCache = TerrainPathCache()
    val sortPool = ArrayList<SortableWorldEntry>(160)
    val scratchPath = Path()
    val scratchPathB = Path()
    val waypointTopIdx = IntArray(4)
    val waypointTopDist = FloatArray(4)

    var cachedBiomeId: String = ""
    var cachedBiome: BiomeDef = GameCatalog.biomeById("forest")

    var cachedW: Float = -1f
    var cachedH: Float = -1f
    var vignetteBrush: Brush? = null
    var sunGlowBrush: Brush? = null

    fun resolveBiome(biomeId: String): BiomeDef {
        if (cachedBiomeId != biomeId) {
            cachedBiomeId = biomeId
            cachedBiome = GameCatalog.biomeById(biomeId)
        }
        return cachedBiome
    }

    fun ensureViewportBrushes(w: Float, h: Float) {
        if (w == cachedW && h == cachedH && vignetteBrush != null && sunGlowBrush != null) return
        cachedW = w
        cachedH = h
        val cx = w * 0.5f
        val cy = h * 0.5f
        vignetteBrush = Brush.radialGradient(
            colors = listOf(Color.Transparent, Color(0x28100A22)),
            center = Offset(cx, cy),
            radius = maxOf(w, h) * 0.78f
        )
        sunGlowBrush = Brush.radialGradient(
            colors = listOf(Color(0x22FFF3B8), Color.Transparent),
            center = Offset(w * 0.14f, h * 0.12f),
            radius = w * 0.55f
        )
    }
}

/**
 * Draw-phase driven 60fps 2.5D Battle Canvas.
 * Reads [stateProvider] exclusively inside [Canvas] DrawScope so 60Hz world updates
 * invalidate only Skia drawing — triggering ZERO Compose recompositions or layout passes.
 * Decomposed into focused draw helpers so ART JIT compiles rapidly with minimal memory.
 */
@Composable
fun BattleCanvas(
    stateProvider: () -> BattleRenderState,
    modifier: Modifier = Modifier
) {
    val fillPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
    }
    val strokePaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            style = Paint.Style.STROKE
            strokeJoin = Paint.Join.ROUND
            color = Color(0xFF1A1030).toArgb()
        }
    }
    val promptPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = 21f
            color = EspressoDark.toArgb()
        }
    }
    val cache = remember { BattleCanvasCache() }

    Canvas(modifier = modifier.fillMaxSize()) {
        val state = stateProvider()
        val biome = cache.resolveBiome(state.biomeId)
        val cx = size.width * 0.5f
        val cy = size.height * 0.5f
        val shakeX = if (state.screenShakeMagnitude > 0.3f) sin(state.frameTick * 1.9f) * state.screenShakeMagnitude else 0f
        val shakeY = if (state.screenShakeMagnitude > 0.3f) cos(state.frameTick * 2.3f) * state.screenShakeMagnitude else 0f
        val camX = state.cameraX - cx + shakeX
        val camY = state.cameraY - cy + shakeY

        drawProceduralBiomeTerrain(biome, state, camX, camY, cache.terrainCache)
        drawBiomeEcoZones(state, camX, camY, cache)
        drawWorldProps(state, camX, camY, cache, promptPaint)
        drawWorldPickups(state, camX, camY, cache)
        drawCombatRingsAndArcs(state, camX, camY)
        drawDashGhosts(state, camX, camY)
        drawSortedWorldEntities(biome, state, camX, camY, cache)
        drawForegroundHeroGrass(biome, state, camX, camY, cache.terrainCache)
        drawProjectilesAndBeams(state, camX, camY)
        drawCombatParticles(state, camX, camY)
        drawAmbientBiomeMotes(biome.id, state.elapsedSec)
        drawAtmosphericOverlay(biome.id, cache)
        drawOffScreenWaypoints(state, camX, camY, cache)
        drawFloatingNumbers(state, camX, camY, strokePaint, fillPaint)
    }
}

private fun DrawScope.drawBiomeEcoZones(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache
) {
    val zones = state.biomeZones
    if (zones.isEmpty()) return
    val time = state.elapsedSec
    val scratch = cache.scratchPath
    for (i in zones.indices) {
        val z = zones[i]
        val zx = z.x - camX
        val zy = z.y - z.groundZ - camY
        val r = z.radius
        if (zx + r < -24f || zx - r > size.width + 24f || zy + r < -24f || zy - r > size.height + 24f) continue
        val center = Offset(zx, zy)
        val pulse = 1f + 0.05f * sin(time * 3.4f + z.id)

        when (z.kind) {
            BiomeZoneKind.FOREST_BLOOM_RING -> {
                drawCircle(GrassGreen.copy(alpha = 0.12f), r * pulse, center)
                drawCircle(Color(0xFFA8FF78).copy(alpha = 0.56f), r * pulse, center, style = STROKE_3_0)
                drawCircle(GoldAccent.copy(alpha = 0.22f), r * 0.62f, center, style = STROKE_2_2)
                for (k in 0 until 6) {
                    val a = time * 0.9f + k * (PI.toFloat() / 3f)
                    val px = zx + cos(a) * (r * 0.86f)
                    val py = zy + sin(a) * (r * 0.86f)
                    drawCircle(Color(0xFFFFF4A8), 6.2f, Offset(px, py))
                    drawCircle(GrassGreen, 3.2f, Offset(px, py))
                }
            }
            BiomeZoneKind.GRAVEYARD_SOUL_LANTERN -> {
                drawCircle(Color(0xFF5AF2E8).copy(alpha = 0.13f), r * pulse, center)
                drawCircle(Color(0xFF7BE8FF).copy(alpha = 0.60f), r * pulse, center, style = STROKE_2_8)
                drawCircle(Color(0xFFC25AFF).copy(alpha = 0.24f), r * 0.52f, center, style = STROKE_2_2)
                // Lantern beacon post at zone center
                drawOval(Color.Black.copy(alpha = 0.28f), Offset(zx - 16f, zy + 4f), Size(32f, 10f))
                drawRoundRect(Color(0xFF2B2242), Offset(zx - 5f, zy - 26f), Size(10f, 34f), CornerRadius(3f, 3f))
                drawCircle(Color(0xFF5AF2E8).copy(alpha = 0.35f), 20f * pulse, Offset(zx, zy - 24f))
                drawCircle(Color(0xFF9BF8FF), 9f, Offset(zx, zy - 24f))
                drawCircle(Color.White, 4.2f, Offset(zx, zy - 24f))
            }
            BiomeZoneKind.DESERT_QUICKSAND -> {
                drawCircle(Color(0xFFC98B3B).copy(alpha = 0.22f), r, center)
                drawCircle(Color(0xFF8F571C).copy(alpha = 0.26f), r * 0.68f, center)
                drawCircle(Color(0xFF5A310B).copy(alpha = 0.34f), r * 0.34f, center)
                val rotDeg = time * 54f + z.id * 40f
                for (ring in 0 until 3) {
                    val rr = r * (0.36f + ring * 0.28f)
                    val tl = Offset(zx - rr, zy - rr)
                    val sz = Size(rr * 2f, rr * 2f)
                    drawArc(
                        color = Color(0xFFFFD891).copy(alpha = 0.50f - ring * 0.08f),
                        startAngle = rotDeg + ring * 95f,
                        sweepAngle = 120f,
                        useCenter = false,
                        topLeft = tl,
                        size = sz,
                        style = STROKE_3_0
                    )
                    drawArc(
                        color = Color(0xFFFFD891).copy(alpha = 0.45f - ring * 0.08f),
                        startAngle = rotDeg + ring * 95f + 180f,
                        sweepAngle = 110f,
                        useCenter = false,
                        topLeft = tl,
                        size = sz,
                        style = STROKE_2_4
                    )
                }
            }
            BiomeZoneKind.VOLCANO_LAVA_VENT -> {
                when (z.phase) {
                    BiomeZonePhase.DORMANT -> {
                        drawCircle(Color(0xFF2B1717).copy(alpha = 0.42f), r * 0.82f, center)
                        drawCircle(Color(0xFF6B2818).copy(alpha = 0.55f), r * 0.82f, center, style = STROKE_2_4)
                        drawCircle(WarmOrange.copy(alpha = 0.28f), r * 0.26f, center)
                    }
                    BiomeZonePhase.WARNING -> {
                        val p = z.phaseProgress.coerceIn(0f, 1f)
                        drawCircle(WarmOrange.copy(alpha = 0.14f + p * 0.22f), r, center)
                        drawCircle(CrimsonRed.copy(alpha = 0.78f), r * p.coerceAtLeast(0.12f), center, style = STROKE_4_5)
                        drawCircle(GoldAccent.copy(alpha = 0.85f), r, center, style = STROKE_3_0)
                        drawCircle(Color(0xFFFFC845).copy(alpha = 0.45f + p * 0.35f), r * 0.32f, center)
                    }
                    BiomeZonePhase.ERUPTING -> {
                        val flicker = 0.94f + 0.10f * sin(time * 22f + z.id)
                        drawCircle(CrimsonRed.copy(alpha = 0.36f), r * flicker, center)
                        drawCircle(WarmOrange.copy(alpha = 0.56f), r * 0.72f * flicker, center)
                        drawCircle(Color(0xFFFFF08A).copy(alpha = 0.78f), r * 0.36f * flicker, center)
                        drawCircle(GoldAccent.copy(alpha = 0.92f), r * flicker, center, style = STROKE_4_5)
                        scratch.reset()
                        for (k in 0 until 6) {
                            val a = time * 4f + k * (PI.toFloat() / 3f)
                            val fx = zx + cos(a) * (r * 0.75f)
                            val fy = zy + sin(a) * (r * 0.75f)
                            drawCircle(Color(0xFFFFE57F), 5.5f, Offset(fx, fy))
                        }
                    }
                    else -> Unit
                }
            }
        }
    }
}

private fun DrawScope.drawWorldProps(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache,
    promptPaint: Paint
) {
    val props = state.props
    val plateaus = cache.terrainCache.visiblePlateaus
    for (i in props.indices) {
        val prop = props[i]
        if (prop.opened) continue
        val propZ = if (plateaus.isEmpty()) 0f else terrainElevationAt(prop.x, prop.y, plateaus)
        val px = prop.x - camX
        val py = prop.y - propZ - camY
        if (px < -100f || px > size.width + 100f || py < -100f || py > size.height + 100f) continue
        val pos = Offset(px, py)
        val isNearby = state.nearbyPropId == prop.id
        val pulse = 1f + 0.14f * sin(state.elapsedSec * 5.2f + prop.id)

        when (prop.kind) {
            WorldPropKind.WOODEN_CHEST -> {
                val glowR = (if (isNearby) 60f else 46f) * pulse
                val glowA = if (isNearby) 0.24f else 0.14f
                drawCircle(GoldAccent.copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(GoldAccent.copy(alpha = glowA * 1.15f), glowR * 0.62f, pos)
                drawCircle(GoldAccent.copy(alpha = if (isNearby) 0.72f else 0.34f), 34f * pulse, pos, style = STROKE_2_2)
                drawOval(Color.Black.copy(alpha = 0.28f), Offset(px - 28f, py + 14f), Size(56f, 17f))
                drawRoundRect(WoodenChestBrown, Offset(px - 26f, py - 20f), Size(52f, 38f), CornerRadius(9f, 9f))
                drawRoundRect(Color(0xFFE09A58), Offset(px - 26f, py - 20f), Size(52f, 17f), CornerRadius(9f, 9f))
                drawRoundRect(Color.White.copy(alpha = 0.24f), Offset(px - 22f, py - 17f), Size(44f, 5f), CornerRadius(3f, 3f))
                drawRect(WoodenChestGold, Offset(px - 16f, py - 19f), Size(6.5f, 36f))
                drawRect(WoodenChestGold, Offset(px + 9.5f, py - 19f), Size(6.5f, 36f))
                drawRoundRect(GoldAccent, Offset(px - 6.5f, py - 6f), Size(13f, 14f), CornerRadius(3.5f, 3.5f))
                drawRoundRect(
                    if (isNearby) GoldAccent else EspressoDark,
                    Offset(px - 26f, py - 20f),
                    Size(52f, 38f),
                    CornerRadius(9f, 9f),
                    style = if (isNearby) STROKE_4_2 else STROKE_3_2
                )
            }
            WorldPropKind.HEAL_SHRINE -> {
                val glowR = (if (isNearby) 62f else 48f) * pulse
                val glowA = if (isNearby) 0.25f else 0.14f
                drawCircle(Color(0xFFC25AFF).copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(Color(0xFFC25AFF).copy(alpha = glowA * 1.15f), glowR * 0.62f, pos)
                drawCircle(Color(0xFFD896FF).copy(alpha = if (isNearby) 0.76f else 0.36f), 32f * pulse, pos, style = STROKE_2_2)
                drawOval(Color.Black.copy(alpha = 0.26f), Offset(px - 26f, py + 15f), Size(52f, 15f))
                drawCircle(Color(0xFFF3EAFF), 25f, pos)
                drawCircle(Color(0xFF9A6AFF), 17.5f, pos)
                drawLine(Color.White, Offset(px - 9f, py), Offset(px + 9f, py), 5f, StrokeCap.Round)
                drawLine(Color.White, Offset(px, py - 9f), Offset(px, py + 9f), 5f, StrokeCap.Round)
                drawCircle(if (isNearby) GoldAccent else EspressoDark, 25f, pos, style = if (isNearby) STROKE_4_2 else STROKE_3_2)
            }
            WorldPropKind.GAMBLE_SHRINE -> {
                val glowR = (if (isNearby) 64f else 50f) * pulse
                val glowA = if (isNearby) 0.26f else 0.15f
                drawCircle(CrimsonRed.copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(CrimsonRed.copy(alpha = glowA * 1.15f), glowR * 0.62f, pos)
                drawCircle(WarmOrange.copy(alpha = if (isNearby) 0.78f else 0.36f), 34f * pulse, pos, style = STROKE_2_2)
                drawOval(Color.Black.copy(alpha = 0.28f), Offset(px - 28f, py + 16f), Size(56f, 16f))
                val pillar = cache.scratchPath
                pillar.reset()
                pillar.moveTo(px, py - 33f)
                pillar.lineTo(px + 21f, py - 5f)
                pillar.lineTo(px + 16f, py + 21f)
                pillar.lineTo(px - 16f, py + 21f)
                pillar.lineTo(px - 21f, py - 5f)
                pillar.close()
                drawPath(pillar, Color(0xFF471526))
                val sigil = cache.scratchPathB
                sigil.reset()
                sigil.moveTo(px, py - 19f)
                sigil.lineTo(px + 9.5f, py)
                sigil.lineTo(px, py + 13f)
                sigil.lineTo(px - 9.5f, py)
                sigil.close()
                drawPath(sigil, GoldAccent)
                drawCircle(CrimsonRed, 4.5f, Offset(px, py - 1f))
                drawPath(pillar, if (isNearby) GoldAccent else EspressoDark, style = if (isNearby) STROKE_4_2 else STROKE_3_2)
            }
            WorldPropKind.MAGNET_OBELISK -> {
                val glowR = (if (isNearby) 62f else 48f) * pulse
                val glowA = if (isNearby) 0.26f else 0.15f
                drawCircle(SkyBlue.copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(SkyBlue.copy(alpha = glowA * 1.15f), glowR * 0.62f, pos)
                drawCircle(Color(0xFF72F2FF).copy(alpha = if (isNearby) 0.78f else 0.36f), 32f * pulse, pos, style = STROKE_2_2)
                drawOval(Color.Black.copy(alpha = 0.26f), Offset(px - 26f, py + 16f), Size(52f, 15f))
                drawRoundRect(Color(0xFF1F3859), Offset(px - 17f, py - 7f), Size(34f, 27f), CornerRadius(7f, 7f))
                drawArc(
                    color = Color(0xFF5CF6FF),
                    startAngle = 180f,
                    sweepAngle = 180f,
                    useCenter = false,
                    topLeft = Offset(px - 15f, py - 28f),
                    size = Size(30f, 30f),
                    style = STROKE_MAGNET_ARC
                )
                drawCircle(CrimsonRed, 4.8f, Offset(px - 15f, py - 10f))
                drawCircle(GoldAccent, 4.8f, Offset(px + 15f, py - 10f))
                drawRoundRect(
                    if (isNearby) GoldAccent else EspressoDark,
                    Offset(px - 17f, py - 7f),
                    Size(34f, 27f),
                    CornerRadius(7f, 7f),
                    style = if (isNearby) STROKE_4_0 else STROKE_3_0
                )
            }
            WorldPropKind.BOSS_PORTAL -> {
                val glowR = (if (isNearby) 74f else 58f) * pulse
                val glowA = if (isNearby) 0.30f else 0.18f
                drawCircle(CrimsonRed.copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(Color(0xFF9C27B0).copy(alpha = glowA), glowR * 0.62f, pos)
                drawOval(Color.Black.copy(alpha = 0.34f), Offset(px - 34f, py + 18f), Size(68f, 18f))
                // Obsidian portal arch & crimson vortex core
                drawOval(Color(0xFF22122E), Offset(px - 28f, py - 34f), Size(56f, 58f))
                drawOval(Color(0xFF5D1234), Offset(px - 21f, py - 27f), Size(42f, 44f))
                drawOval(CrimsonRed.copy(alpha = 0.85f), Offset(px - 13f * pulse, py - 19f * pulse), Size(26f * pulse, 28f * pulse))
                drawCircle(GoldAccent.copy(alpha = 0.90f), 6.5f * pulse, Offset(px, py - 5f))
                // Orbiting crimson/gold seal arcs
                val spinDeg = (state.elapsedSec * 110f) % 360f
                drawArc(
                    color = GoldAccent.copy(alpha = 0.92f),
                    startAngle = spinDeg,
                    sweepAngle = 115f,
                    useCenter = false,
                    topLeft = Offset(px - 33f, py - 39f),
                    size = Size(66f, 68f),
                    style = STROKE_3_2
                )
                drawArc(
                    color = CrimsonRed,
                    startAngle = spinDeg + 180f,
                    sweepAngle = 115f,
                    useCenter = false,
                    topLeft = Offset(px - 33f, py - 39f),
                    size = Size(66f, 68f),
                    style = STROKE_3_2
                )
                drawOval(
                    if (isNearby) GoldAccent else EspressoDark,
                    Offset(px - 28f, py - 34f),
                    Size(56f, 58f),
                    style = if (isNearby) STROKE_4_2 else STROKE_3_2
                )
            }
            WorldPropKind.FUSION_MACHINE -> {
                val glowR = (if (isNearby) 68f else 54f) * pulse
                val glowA = if (isNearby) 0.28f else 0.16f
                drawCircle(Color(0xFF5CF6FF).copy(alpha = glowA * 0.65f), glowR, pos)
                drawCircle(GoldAccent.copy(alpha = glowA * 0.95f), glowR * 0.56f, pos)
                drawOval(Color.Black.copy(alpha = 0.28f), Offset(px - 30f, py + 16f), Size(60f, 16f))
                // Reactor chassis & cyan-gold dual-helix core
                drawRoundRect(Color(0xFF1A2D42), Offset(px - 22f, py - 24f), Size(44f, 44f), CornerRadius(11f, 11f))
                drawRoundRect(Color(0xFF284866), Offset(px - 16f, py - 18f), Size(32f, 32f), CornerRadius(8f, 8f))
                val coreSpin = state.elapsedSec * 5.2f
                val h1 = Offset(px + cos(coreSpin) * 8.5f, py - 2f + sin(coreSpin) * 6.5f)
                val h2 = Offset(px - cos(coreSpin) * 8.5f, py - 2f - sin(coreSpin) * 6.5f)
                drawCircle(Color(0xFF5CF6FF), 7.5f, h1)
                drawCircle(GoldAccent, 7.5f, h2)
                drawCircle(Color.White, 3.2f, h1)
                drawCircle(Color.White, 3.2f, h2)
                drawCircle(Color(0xFF5CF6FF).copy(alpha = if (isNearby) 0.85f else 0.45f), 34f * pulse, pos, style = STROKE_2_2)
                drawRoundRect(
                    if (isNearby) GoldAccent else EspressoDark,
                    Offset(px - 22f, py - 24f),
                    Size(44f, 44f),
                    CornerRadius(11f, 11f),
                    style = if (isNearby) STROKE_4_2 else STROKE_3_2
                )
            }
        }

        if (isNearby) {
            val bobY = py - 42f + sin(state.elapsedSec * 7f) * 3.5f
            val label = when (prop.kind) {
                WorldPropKind.WOODEN_CHEST -> "点击右侧开箱"
                WorldPropKind.HEAL_SHRINE -> "点击右侧祈福"
                WorldPropKind.GAMBLE_SHRINE -> "点击右侧试炼"
                WorldPropKind.MAGNET_OBELISK -> "点击右侧磁吸"
                WorldPropKind.BOSS_PORTAL -> "点击右侧迎战"
                WorldPropKind.FUSION_MACHINE -> "点击右侧融合"
            }
            drawRoundRect(CreamSurface, Offset(px - 67f, bobY - 15f), Size(134f, 26f), CornerRadius(13f, 13f))
            drawRoundRect(WarmOrange, Offset(px - 67f, bobY - 15f), Size(134f, 26f), CornerRadius(13f, 13f), style = STROKE_2_6)
            drawContext.canvas.nativeCanvas.drawText(label, px, bobY + 5f, promptPaint)
        }
    }
}

private fun DrawScope.drawWorldPickups(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache
) {
    val pickups = state.pickups
    val plateaus = cache.terrainCache.visiblePlateaus
    val scratch = cache.scratchPath
    val time = state.elapsedSec
    for (i in pickups.indices) {
        val pk = pickups[i]
        val pkZ = if (plateaus.isEmpty()) 0f else terrainElevationAt(pk.x, pk.y, plateaus)
        val px = pk.x - camX
        val py = pk.y - pkZ - camY
        if (px < -40f || px > size.width + 40f || py < -40f || py > size.height + 40f) continue
        val bobY = py + sin(time * 6f + pk.id) * 2.5f
        val pPos = Offset(px, bobY)

        when (pk.kind) {
            PickupKind.XP_SMALL, PickupKind.XP_LARGE -> {
                val r = if (pk.kind == PickupKind.XP_LARGE) 12.5f else 8.5f
                val col = if (pk.kind == PickupKind.XP_LARGE) Color(0xFF5CF6FF) else Color(0xFF66F27E)
                drawCircle(col.copy(alpha = 0.28f), r * 1.75f, pPos)
                scratch.reset()
                scratch.moveTo(px, bobY - r)
                scratch.lineTo(px + r * 0.78f, bobY)
                scratch.lineTo(px, bobY + r)
                scratch.lineTo(px - r * 0.78f, bobY)
                scratch.close()
                drawPath(scratch, col)
                drawCircle(Color.White.copy(alpha = 0.75f), r * 0.28f, Offset(px - 2f, bobY - r * 0.3f))
                drawPath(scratch, EspressoDark, style = STROKE_2_2)
            }
            PickupKind.COIN -> {
                drawCircle(GoldAccent.copy(alpha = 0.26f), 14f, pPos)
                drawCircle(GoldAccent, 9f, pPos)
                drawCircle(Color(0xFFFFF4B8), 4.8f, Offset(px - 1.5f, bobY - 1.5f))
                drawCircle(EspressoDark, 9f, pPos, style = STROKE_2_2)
            }
            PickupKind.HEART -> {
                drawCircle(CrimsonRed.copy(alpha = 0.28f), 16f, pPos)
                drawCircle(CrimsonRed, 10f, pPos)
                drawCircle(Color.White.copy(alpha = 0.7f), 3.2f, Offset(px - 3f, bobY - 3f))
                drawCircle(EspressoDark, 10f, pPos, style = STROKE_2_2)
            }
            PickupKind.ESSENCE_BLOOM, PickupKind.ESSENCE_EMBER, PickupKind.ESSENCE_TIDE, PickupKind.STARDUST_CORE -> {
                val col = when (pk.kind) {
                    PickupKind.ESSENCE_BLOOM -> GrassGreen
                    PickupKind.ESSENCE_EMBER -> WarmOrange
                    PickupKind.ESSENCE_TIDE -> SkyBlue
                    else -> GoldAccent
                }
                val r = if (pk.kind == PickupKind.STARDUST_CORE) 13.5f else 11f
                drawCircle(col.copy(alpha = 0.36f), r * 2.1f, pPos)
                scratch.reset()
                for (k in 0 until 6) {
                    val a = time * 2.2f + k * (PI.toFloat() / 3f)
                    val hx = px + cos(a) * r
                    val hy = bobY + sin(a) * r
                    if (k == 0) scratch.moveTo(hx, hy) else scratch.lineTo(hx, hy)
                }
                scratch.close()
                drawPath(scratch, col)
                drawCircle(Color.White.copy(alpha = 0.9f), r * 0.36f, pPos)
                drawPath(scratch, EspressoDark, style = STROKE_2_2)
            }
            PickupKind.HYPER_SHARD -> {
                val r = 13f
                drawCircle(Color(0xFFFF66E5).copy(alpha = 0.32f), r * 2.1f, pPos)
                drawCircle(Color(0xFF5CF6FF).copy(alpha = 0.28f), r * 1.45f, pPos)
                rotate(degrees = time * 120f + pk.id * 25f, pivot = pPos) {
                    scratch.reset()
                    scratch.moveTo(px, bobY - r * 1.25f)
                    scratch.lineTo(px + r * 0.85f, bobY)
                    scratch.lineTo(px, bobY + r * 1.25f)
                    scratch.lineTo(px - r * 0.85f, bobY)
                    scratch.close()
                    drawPath(scratch, Color(0xFFFF66E5))
                    drawCircle(GoldAccent, r * 0.56f, pPos)
                    drawPath(scratch, EspressoDark, style = STROKE_2_2)
                }
                drawCircle(Color.White, r * 0.32f, pPos)
            }
        }
    }
}

private fun DrawScope.drawCombatRingsAndArcs(
    state: BattleRenderState,
    camX: Float,
    camY: Float
) {
    val rings = state.rings
    for (i in rings.indices) {
        val ring = rings[i]
        val rx = ring.x - camX
        val ry = ring.y - camY
        val rad = ring.radius.coerceAtLeast(1f)
        if (rx + rad < -16f || rx - rad > size.width + 16f || ry + rad < -16f || ry - rad > size.height + 16f) continue
        val pos = Offset(rx, ry)
        drawCircle(color = ring.color.copy(alpha = ring.alpha * 0.14f), radius = rad, center = pos)
        drawCircle(color = ring.color.copy(alpha = ring.alpha * 0.92f), radius = rad, center = pos, style = STROKE_7_5)
    }

    val arcs = state.slashArcs
    for (i in arcs.indices) {
        val arc = arcs[i]
        val ax = arc.x - camX
        val ay = arc.y - camY
        val r = arc.radius
        if (ax + r < -30f || ax - r > size.width + 30f || ay + r < -30f || ay - r > size.height + 30f) continue
        val deg = arc.angleRad * (180f / PI.toFloat())
        val sweep = if (arc.isAwakened) 138f else 115f
        val tl = Offset(ax - r, ay - r)
        val sz = Size(r * 2f, r * 2f)
        if (arc.isAwakened) {
            drawArc(
                color = GoldAccent.copy(alpha = arc.alpha * 0.56f),
                startAngle = deg - sweep * 0.5f - 6f,
                sweepAngle = sweep + 12f,
                useCenter = false,
                topLeft = tl,
                size = sz,
                style = Stroke(width = 32f * arc.alpha, cap = StrokeCap.Round)
            )
        }
        drawArc(
            color = arc.color.copy(alpha = arc.alpha * 0.42f),
            startAngle = deg - sweep * 0.5f,
            sweepAngle = sweep,
            useCenter = false,
            topLeft = tl,
            size = sz,
            style = Stroke(width = 24f * arc.alpha, cap = StrokeCap.Round)
        )
        drawArc(
            color = Color.White.copy(alpha = arc.alpha * 0.92f),
            startAngle = deg - sweep * 0.5f + 8f,
            sweepAngle = sweep - 16f,
            useCenter = false,
            topLeft = tl,
            size = sz,
            style = Stroke(width = if (arc.isAwakened) 9.5f * arc.alpha else 7f * arc.alpha, cap = StrokeCap.Round)
        )
    }
}

private fun DrawScope.drawDashGhosts(
    state: BattleRenderState,
    camX: Float,
    camY: Float
) {
    val ghosts = state.dashGhosts
    if (ghosts.isEmpty()) return
    val plateaus = state.terrainPlateaus
    for (i in ghosts.indices) {
        val ghost = ghosts[i]
        val gz = terrainElevationAt(ghost.x, ghost.y, plateaus)
        val gx = ghost.x - camX
        val gy = ghost.y - gz - camY
        if (gx < -40f || gx > size.width + 40f || gy < -40f || gy > size.height + 40f) continue
        val gp = Offset(gx, gy)
        drawCircle(ghost.color.copy(alpha = ghost.alpha * 0.7f), 25f, gp)
        drawCircle(Color.White.copy(alpha = ghost.alpha * 0.45f), 15f, gp)
    }
}

private fun DrawScope.drawSortedWorldEntities(
    biome: BiomeDef,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache
) {
    val sortPool = cache.sortPool
    var sortCount = 0
    fun addSortEntry(kind: Int, index: Int, sortY: Float) {
        if (sortCount >= sortPool.size) {
            sortPool.add(SortableWorldEntry(kind, index, sortY))
        } else {
            val e = sortPool[sortCount]
            e.kind = kind
            e.index = index
            e.sortY = sortY
        }
        sortCount++
    }

    val enemies = state.enemies
    for (i in enemies.indices) {
        val e = enemies[i]
        val sx = e.x - camX
        val sy = e.y - e.groundZ - camY
        if (sx < -150f || sx > size.width + 150f || sy < -150f || sy > size.height + 150f) continue
        addSortEntry(SORT_KIND_ENEMY, i, e.y)
    }

    val obstacles = state.terrainObstacles
    for (i in obstacles.indices) {
        val obs = obstacles[i]
        val sx = obs.x - camX
        val sy = obs.y - obs.groundZ - camY
        val pad = obs.canopyRadius + obs.height + 40f
        if (sx < -pad || sx > size.width + pad || sy < -pad || sy > size.height + pad) continue
        addSortEntry(SORT_KIND_OBSTACLE, i, obs.y)
    }

    addSortEntry(SORT_KIND_HERO, 0, state.playerY)

    // In-place insertion sort on pooled list (zero allocation, fast for 10..80 entries)
    for (i in 1 until sortCount) {
        val key = sortPool[i]
        val keyY = key.sortY
        var j = i - 1
        while (j >= 0 && sortPool[j].sortY > keyY) {
            sortPool[j + 1] = sortPool[j]
            j--
        }
        sortPool[j + 1] = key
    }

    for (sIdx in 0 until sortCount) {
        val entry = sortPool[sIdx]
        when (entry.kind) {
            SORT_KIND_ENEMY -> {
                val e = enemies[entry.index]
                drawStylizedEnemy(
                    e = e,
                    groundPos = Offset(e.x - camX, e.y - e.groundZ - camY),
                    bodyPos = Offset(e.x - camX, e.y - e.z - camY),
                    time = state.elapsedSec,
                    scratch = cache.scratchPath
                )
            }
            SORT_KIND_OBSTACLE -> {
                draw25DOccludingObstacle(
                    biome = biome,
                    obs = obstacles[entry.index],
                    state = state,
                    camX = camX,
                    camY = camY,
                    cache = cache.terrainCache
                )
            }
            SORT_KIND_HERO -> {
                drawHeroComposite(state, camX, camY, cache)
            }
        }
    }
}

private fun DrawScope.drawHeroComposite(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache
) {
    val groundPos = Offset(state.playerX - camX, state.playerY - state.playerGroundZ - camY)
    val heroPos = Offset(state.playerX - camX, state.playerY - state.playerZ - camY)
    val jumpAlt = (state.playerZ - state.playerGroundZ).coerceAtLeast(0f)
    val isHyperActive = state.hyperActiveTimer > 0f

    // High-Ground golden tactical aura ring pinned to terrain surface
    if (state.isOnHighGround) {
        val hgPulse = 1f + 0.07f * sin(state.elapsedSec * 6.5f)
        drawOval(
            color = GoldAccent.copy(alpha = 0.20f),
            topLeft = Offset(groundPos.x - 42f * hgPulse, groundPos.y + 4f - 14f * hgPulse),
            size = Size(84f * hgPulse, 28f * hgPulse)
        )
        drawOval(
            color = GoldAccent.copy(alpha = 0.82f),
            topLeft = Offset(groundPos.x - 36f * hgPulse, groundPos.y + 6f - 11f * hgPulse),
            size = Size(72f * hgPulse, 22f * hgPulse),
            style = STROKE_2_6
        )
    }

    // Grounded jump drop-shadow & landing ring
    val shadowScale = (1f - jumpAlt * 0.0055f).coerceIn(0.45f, 1f)
    val shadowAlpha = (0.30f - jumpAlt * 0.0018f).coerceIn(0.11f, 0.30f)
    drawOval(
        color = Color.Black.copy(alpha = shadowAlpha),
        topLeft = Offset(groundPos.x - 28f * shadowScale, groundPos.y + 18f - 8f * shadowScale),
        size = Size(56f * shadowScale, 17f * shadowScale)
    )
    if (jumpAlt > 8f) {
        drawOval(
            color = CreamSurface.copy(alpha = (0.42f * shadowScale).coerceIn(0.14f, 0.42f)),
            topLeft = Offset(groundPos.x - 24f * shadowScale, groundPos.y + 18f - 6.5f * shadowScale),
            size = Size(48f * shadowScale, 14f * shadowScale),
            style = STROKE_2_2
        )
    }

    // Subtle ground heading chevron while moving
    if (state.moveSpeedRatio > 0.14f) {
        val dirX = cos(state.facingAngle)
        val dirY = sin(state.facingAngle)
        val tipX = groundPos.x + dirX * 42f
        val tipY = groundPos.y + dirY * 42f + 12f
        val sideLX = groundPos.x + cos(state.facingAngle + 0.42f) * 30f
        val sideLY = groundPos.y + sin(state.facingAngle + 0.42f) * 30f + 12f
        val sideRX = groundPos.x + cos(state.facingAngle - 0.42f) * 30f
        val sideRY = groundPos.y + sin(state.facingAngle - 0.42f) * 30f + 12f
        val chevron = cache.terrainCache.shapeScratch
        chevron.reset()
        chevron.moveTo(sideLX, sideLY)
        chevron.lineTo(tipX, tipY)
        chevron.lineTo(sideRX, sideRY)
        drawPath(
            path = chevron,
            color = CreamSurface.copy(alpha = (state.moveSpeedRatio * 0.65f).coerceIn(0.2f, 0.72f)),
            style = STROKE_CHEVRON
        )
    }

    // Orbiting Blades (follow hero's 2.5D altitude)
    val moves = state.activeMoves
    for (i in moves.indices) {
        val slot = moves[i]
        if (slot.archetype == MoveArchetype.ORBIT) {
            val bladeCount = 2 + (slot.level / 2)
            val orbitR = 148f
            drawCircle(slot.element.color.copy(alpha = 0.16f), orbitR, heroPos, style = STROKE_5_0)
            for (b in 0 until bladeCount) {
                val a = state.orbitAngle + (b * 2f * PI.toFloat() / bladeCount)
                val bp = Offset(heroPos.x + cos(a) * orbitR, heroPos.y + sin(a) * orbitR)
                drawCircle(slot.element.color.copy(alpha = 0.35f), 26f, bp)
                drawCircle(slot.element.color, 14f, bp)
                drawCircle(Color.White, 6f, bp)
                drawCircle(EspressoDark, 14f, bp, style = STROKE_2_2)
            }
        }
    }

    // Hyper-Awakening Prismatic Aura & Orbiting Energy Stars (zero Brush allocation)
    if (isHyperActive) {
        val auraPulse = 1f + 0.08f * sin(state.elapsedSec * 10f)
        val auraR = 54f * auraPulse
        drawCircle(Color(0x285CF6FF), auraR * 1.42f, heroPos)
        drawCircle(Color(0x36FF66E5), auraR * 1.08f, heroPos)
        drawCircle(Color(0xFFFF66E5), auraR, heroPos, style = STROKE_4_5)
        drawCircle(GoldAccent.copy(alpha = 0.85f), auraR * 0.90f, heroPos, style = STROKE_2_2)
        for (k in 0 until 4) {
            val a = state.elapsedSec * 4.5f + k * (PI.toFloat() * 0.5f)
            val sp = Offset(heroPos.x + cos(a) * auraR, heroPos.y + sin(a) * auraR)
            drawCircle(GoldAccent, 5.5f, sp)
            drawCircle(Color.White, 2.5f, sp)
        }
    }

    // 2.5D Air Glide luminous wings + upward air-draft rings (zero allocations)
    if (state.isGliding) {
        val wingFlap = sin(state.elapsedSec * 18f) * 6f
        val wingSpan = 46f
        val leftWing = cache.scratchPath
        leftWing.reset()
        leftWing.moveTo(heroPos.x - 10f, heroPos.y - 2f)
        leftWing.lineTo(heroPos.x - wingSpan, heroPos.y - 18f + wingFlap)
        leftWing.lineTo(heroPos.x - wingSpan * 0.72f, heroPos.y + 12f + wingFlap * 0.5f)
        leftWing.close()
        drawPath(leftWing, Color(0x997BE8FF))
        drawPath(leftWing, GoldAccent.copy(alpha = 0.85f), style = STROKE_2_2)

        val rightWing = cache.scratchPathB
        rightWing.reset()
        rightWing.moveTo(heroPos.x + 10f, heroPos.y - 2f)
        rightWing.lineTo(heroPos.x + wingSpan, heroPos.y - 18f + wingFlap)
        rightWing.lineTo(heroPos.x + wingSpan * 0.72f, heroPos.y + 12f + wingFlap * 0.5f)
        rightWing.close()
        drawPath(rightWing, Color(0x997BE8FF))
        drawPath(rightWing, GoldAccent.copy(alpha = 0.85f), style = STROKE_2_2)

        val draftPulse = 1f + 0.12f * sin(state.elapsedSec * 14f)
        drawOval(
            color = Color(0x997BE8FF),
            topLeft = Offset(heroPos.x - 32f * draftPulse, heroPos.y + 16f),
            size = Size(64f * draftPulse, 14f * draftPulse),
            style = STROKE_2_2
        )
    }

    // Evolved Hero Sprite lifted by playerZ
    val jumpScale = 1f + (jumpAlt * 0.0024f).coerceAtMost(0.22f)
    drawEvolvedHeroSprite(
        style = state.evolutionState.currentNode.visualStyle,
        center = heroPos,
        baseRadius = (if (isHyperActive) 36f else 30f) * jumpScale,
        animTime = if (state.moveSpeedRatio > 0.1f) state.walkAnimTime else state.elapsedSec * 3.4f,
        orbitAngle = state.orbitAngle,
        facingAngle = state.facingAngle,
        moveSpeedRatio = state.moveSpeedRatio,
        isAttacking = state.attackFlashTimer > 0f,
        isHurt = state.hurtFlashTimer > 0f,
        isUltActive = state.ultActiveTimer > 0f || isHyperActive,
        leanDeg = state.leanDeg
    )
}

private fun DrawScope.drawProjectilesAndBeams(
    state: BattleRenderState,
    camX: Float,
    camY: Float
) {
    val projectiles = state.projectiles
    for (i in projectiles.indices) {
        val p = projectiles[i]
        val zLift = p.z * 0.72f
        val px = p.x - camX
        val py = p.y - zLift - camY
        val pos = Offset(px, py)
        if (p.isBeam) {
            val endPos = Offset(p.endX - camX, p.endY - zLift * 0.55f - camY)
            if (p.isAwakened) {
                drawLine(Color(0xFFFF66E5).copy(alpha = 0.36f * p.lifeRatio), pos, endPos, p.radius * 3.4f, StrokeCap.Round)
                drawLine(GoldAccent.copy(alpha = 0.55f * p.lifeRatio), pos, endPos, p.radius * 2.75f, StrokeCap.Round)
            } else if (p.isHighGroundBoosted) {
                drawLine(GoldAccent.copy(alpha = 0.45f * p.lifeRatio), pos, endPos, p.radius * 2.8f, StrokeCap.Round)
            }
            drawLine(p.color.copy(alpha = 0.34f * p.lifeRatio), pos, endPos, p.radius * 2.4f, StrokeCap.Round)
            drawLine(p.color.copy(alpha = 0.95f * p.lifeRatio), pos, endPos, p.radius * 1.25f, StrokeCap.Round)
            drawLine(Color.White.copy(alpha = 0.92f * p.lifeRatio), pos, endPos, p.radius * 0.48f, StrokeCap.Round)
            continue
        }
        val pad = p.radius * 2.4f + 36f
        if (px < -pad || px > size.width + pad || py < -pad || py > size.height + pad) continue

        if (p.isEnemy) {
            val tail = Offset(px - p.vx * 0.042f, py - p.vy * 0.042f)
            drawLine(Color(0xFFFF3A78).copy(alpha = 0.48f), tail, pos, p.radius * 1.35f, StrokeCap.Round)
            drawCircle(Color(0xFFFF2466).copy(alpha = 0.30f), p.radius * 1.85f, pos)
            drawCircle(Color(0xFF420B24), p.radius * 1.12f, pos)
            drawCircle(Color(0xFFFF3B6B), p.radius * 0.88f, pos)
            drawCircle(Color(0xFFFFE082), p.radius * 0.42f, pos)
            drawCircle(Color(0xFFFFA0C4), p.radius * 1.18f, pos, style = STROKE_2_2)
        } else {
            val tail = Offset(px - p.vx * 0.035f, py - p.vy * 0.035f)
            if (p.isAwakened) {
                drawLine(GoldAccent.copy(alpha = 0.56f), tail, pos, p.radius * 1.95f, StrokeCap.Round)
                drawCircle(Color(0xFFFF66E5).copy(alpha = 0.30f), p.radius * 2.15f, pos)
                drawCircle(GoldAccent.copy(alpha = 0.82f), p.radius * 1.48f, pos, style = STROKE_2_2)
            } else if (p.isHighGroundBoosted) {
                drawLine(GoldAccent.copy(alpha = 0.48f), tail, pos, p.radius * 1.65f, StrokeCap.Round)
                drawCircle(GoldAccent.copy(alpha = 0.38f), p.radius * 1.85f, pos)
            }
            drawLine(p.color.copy(alpha = 0.42f), tail, pos, p.radius * 1.35f, StrokeCap.Round)
            drawCircle(p.color.copy(alpha = 0.32f), p.radius * 1.55f, pos)
            if (p.element == ElementType.GRASS) {
                val deg = atan2(p.vy, p.vx) * (180f / PI.toFloat())
                rotate(degrees = deg, pivot = pos) {
                    drawOval(p.color, Offset(px - p.radius * 1.2f, py - p.radius * 0.65f), Size(p.radius * 2.4f, p.radius * 1.3f))
                    drawLine(Color(0xFFDDFCA5), Offset(px - p.radius * 0.8f, py), Offset(px + p.radius * 0.8f, py), 2.5f, StrokeCap.Round)
                    drawOval(
                        if (p.isAwakened || p.isHighGroundBoosted) GoldAccent else EspressoDark,
                        Offset(px - p.radius * 1.2f, py - p.radius * 0.65f),
                        Size(p.radius * 2.4f, p.radius * 1.3f),
                        style = if (p.isAwakened) STROKE_2_8 else STROKE_2_2
                    )
                }
            } else {
                drawCircle(p.color, p.radius, pos)
                drawCircle(Color.White.copy(alpha = 0.88f), p.radius * 0.45f, Offset(px - 2f, py - 2f))
                drawCircle(
                    if (p.isAwakened || p.isHighGroundBoosted) GoldAccent else EspressoDark,
                    p.radius,
                    pos,
                    style = if (p.isAwakened || p.isHighGroundBoosted) STROKE_2_8 else STROKE_2_2
                )
            }
        }
    }
}

private fun DrawScope.drawCombatParticles(
    state: BattleRenderState,
    camX: Float,
    camY: Float
) {
    val particles = state.particles
    for (i in particles.indices) {
        val pt = particles[i]
        val px = pt.x - camX
        val py = pt.y - camY
        if (px < -30f || px > size.width + 30f || py < -30f || py > size.height + 30f) continue
        val pos = Offset(px, py)
        when (pt.shape) {
            ParticleShape.DOT -> drawCircle(pt.color.copy(alpha = pt.alpha), pt.size, pos)
            ParticleShape.SPARK -> {
                val s = pt.size * 1.25f
                drawLine(pt.color.copy(alpha = pt.alpha), Offset(px - s, py), Offset(px + s, py), 3.2f, StrokeCap.Round)
                drawLine(pt.color.copy(alpha = pt.alpha), Offset(px, py - s), Offset(px, py + s), 3.2f, StrokeCap.Round)
                drawCircle(Color.White.copy(alpha = pt.alpha * 0.85f), pt.size * 0.42f, pos)
            }
            ParticleShape.LEAF -> {
                rotate(degrees = pt.angleRad * 57.3f, pivot = pos) {
                    drawOval(pt.color.copy(alpha = pt.alpha), Offset(px - pt.size, py - pt.size * 0.5f), Size(pt.size * 2f, pt.size))
                }
            }
            ParticleShape.RING_POP -> drawCircle(pt.color.copy(alpha = pt.alpha), pt.size, pos, style = STROKE_2_5)
        }
    }
}

private fun DrawScope.drawAtmosphericOverlay(
    biomeId: String,
    cache: BattleCanvasCache
) {
    cache.ensureViewportBrushes(size.width, size.height)
    cache.vignetteBrush?.let { drawRect(brush = it, size = size) }
    if (biomeId == "forest" || biomeId == "desert") {
        cache.sunGlowBrush?.let {
            drawCircle(
                brush = it,
                radius = size.width * 0.55f,
                center = Offset(size.width * 0.14f, size.height * 0.12f)
            )
        }
    }
}

private fun DrawScope.drawFloatingNumbers(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    strokePaint: Paint,
    fillPaint: Paint
) {
    val floats = state.floatingNumbers
    val nativeCanvas = drawContext.canvas.nativeCanvas
    for (i in floats.indices) {
        val ft = floats[i]
        val fx = ft.x - camX
        val fy = ft.y - camY
        if (fx < -80f || fx > size.width + 80f || fy < -60f || fy > size.height + 60f) continue
        val popScale = if (ft.alpha > 0.78f) 1.0f + (ft.alpha - 0.78f) * 1.1f else 1.0f
        val baseSize = if (ft.isCrit) 42f else 30f
        val textSizePx = baseSize * popScale
        val alphaInt = (ft.alpha * 255).toInt().coerceIn(0, 255)
        strokePaint.textSize = textSizePx
        strokePaint.strokeWidth = if (ft.isCrit) 9f else 6.5f
        strokePaint.alpha = alphaInt
        fillPaint.textSize = textSizePx
        fillPaint.color = ft.color.toArgb()
        fillPaint.alpha = alphaInt
        nativeCanvas.drawText(ft.text, fx, fy, strokePaint)
        nativeCanvas.drawText(ft.text, fx, fy, fillPaint)
    }
}

private fun DrawScope.drawOffScreenWaypoints(
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: BattleCanvasCache
) {
    val cx = size.width * 0.5f
    val cy = size.height * 0.5f
    val marginX = 48f
    val marginTop = 96f
    val marginBottom = 92f
    val arrow = cache.scratchPath

    fun drawPointer(wx: Float, wy: Float, color: Color, isBoss: Boolean) {
        val sx = wx - camX
        val sy = wy - camY
        if (sx in 24f..(size.width - 24f) && sy in 24f..(size.height - 24f)) return
        val dx = sx - cx
        val dy = sy - cy
        val angle = atan2(dy, dx)
        val halfW = (cx - marginX).coerceAtLeast(40f)
        val halfH = (cy - maxOf(marginTop, marginBottom)).coerceAtLeast(40f)
        val cosA = cos(angle)
        val sinA = sin(angle)
        val scaleX = if (abs(cosA) > 0.001f) halfW / abs(cosA) else Float.MAX_VALUE
        val scaleY = if (abs(sinA) > 0.001f) halfH / abs(sinA) else Float.MAX_VALUE
        val distScale = minOf(scaleX, scaleY)
        val px = (cx + cosA * distScale).coerceIn(marginX, size.width - marginX)
        val py = (cy + sinA * distScale).coerceIn(marginTop, size.height - marginBottom)
        val pulse = 1f + 0.14f * sin(state.elapsedSec * (if (isBoss) 8f else 5f))
        val r = (if (isBoss) 16f else 12.5f) * pulse
        val pt = Offset(px, py)

        drawCircle(color.copy(alpha = 0.28f), r * 1.65f, pt)
        rotate(degrees = angle * (180f / PI.toFloat()), pivot = pt) {
            arrow.reset()
            arrow.moveTo(px + r * 1.15f, py)
            arrow.lineTo(px - r * 0.72f, py - r * 0.82f)
            arrow.lineTo(px - r * 0.32f, py)
            arrow.lineTo(px - r * 0.72f, py + r * 0.82f)
            arrow.close()
            drawPath(arrow, color)
            drawPath(arrow, EspressoDark, style = STROKE_2_6)
        }
        drawCircle(Color.White.copy(alpha = 0.9f), if (isBoss) 4.2f else 3f, pt)
    }

    // Off-screen Guardian Boss gets top priority
    val enemies = state.enemies
    for (i in enemies.indices) {
        val e = enemies[i]
        if (e.isBoss) {
            drawPointer(e.x, e.y, CrimsonRed, isBoss = true)
            break
        }
    }

    // Zero-allocation top-4 nearest unopened world props
    val topIdx = cache.waypointTopIdx
    val topDist = cache.waypointTopDist
    var count = 0
    val props = state.props
    for (i in props.indices) {
        val prop = props[i]
        if (prop.opened) continue
        val d = hypot(prop.x - state.playerX, prop.y - state.playerY)
        var pos = count
        if (count < 4) {
            count++
        } else if (d >= topDist[3]) {
            continue
        } else {
            pos = 3
        }
        while (pos > 0 && d < topDist[pos - 1]) {
            topDist[pos] = topDist[pos - 1]
            topIdx[pos] = topIdx[pos - 1]
            pos--
        }
        topDist[pos] = d
        topIdx[pos] = i
    }
    // Prioritize Boss Portal beacon so players can always locate early challenge gate
    for (i in props.indices) {
        val prop = props[i]
        if (!prop.opened && prop.kind == WorldPropKind.BOSS_PORTAL) {
            drawPointer(prop.x, prop.y, CrimsonRed, isBoss = true)
        }
    }
    for (k in 0 until count) {
        val prop = props[topIdx[k]]
        if (prop.kind == WorldPropKind.BOSS_PORTAL) continue
        val col = when (prop.kind) {
            WorldPropKind.WOODEN_CHEST -> GoldAccent
            WorldPropKind.HEAL_SHRINE -> Color(0xFFC25AFF)
            WorldPropKind.GAMBLE_SHRINE -> CrimsonRed
            WorldPropKind.MAGNET_OBELISK -> SkyBlue
            WorldPropKind.FUSION_MACHINE -> Color(0xFF5CF6FF)
            WorldPropKind.BOSS_PORTAL -> CrimsonRed
        }
        drawPointer(prop.x, prop.y, col, isBoss = false)
    }
}

private fun DrawScope.drawAmbientBiomeMotes(biomeId: String, time: Float) {
    val moteColor = when (biomeId) {
        "forest" -> Color(0xFFFFF8C2)
        "graveyard" -> Color(0xFF9BF2FF)
        "desert" -> Color(0xFFFFE4A3)
        else -> Color(0xFFFF7A30)
    }
    val spanW = size.width + 60f
    val spanH = size.height + 60f
    val speedX = if (biomeId == "desert") 44f else 14f
    val speedY = if (biomeId == "volcano") -36f else -10f
    for (i in 0 until 12) {
        val rawX = ((i * 173.3f + time * speedX) % spanW + spanW) % spanW - 30f
        val rawY = ((i * 239.7f + time * speedY + sin(time * 1.4f + i) * 18f) % spanH + spanH) % spanH - 30f
        val alpha = 0.25f + 0.35f * (0.5f + 0.5f * sin(time * 2.4f + i * 1.7f))
        val r = (2.8f + (i % 3) * 1.6f)
        val pt = Offset(rawX, rawY)
        drawCircle(moteColor.copy(alpha = alpha * 0.45f), r * 2.1f, pt)
        drawCircle(moteColor.copy(alpha = alpha), r, pt)
    }
}

private fun DrawScope.drawStylizedEnemy(
    e: EnemySnapshot,
    groundPos: Offset,
    bodyPos: Offset,
    time: Float,
    scratch: Path
) {
    // Multi-Phase Boss telegraphs pinned to terrain surface
    if (e.isBoss && e.telegraphProgress > 0.01f) {
        val prog = e.telegraphProgress.coerceIn(0f, 1f)
        when (e.telegraphKind) {
            BossAttackKind.LINE_CHARGE -> {
                val len = e.chargeLength.coerceAtLeast(240f)
                val endPt = Offset(groundPos.x + e.chargeDirX * len, groundPos.y + e.chargeDirY * len)
                val fillEnd = Offset(groundPos.x + e.chargeDirX * len * prog, groundPos.y + e.chargeDirY * len * prog)
                drawLine(CrimsonRed.copy(alpha = 0.24f), groundPos, endPt, e.radius * 1.7f, StrokeCap.Round)
                drawLine(CrimsonRed.copy(alpha = 0.65f), groundPos, fillEnd, e.radius * 1.4f, StrokeCap.Round)
                drawLine(GoldAccent.copy(alpha = 0.88f), groundPos, endPt, 4f, StrokeCap.Round)
            }
            BossAttackKind.RADIAL_BURST -> {
                val rays = if (e.bossPhase >= 3) 12 else 8
                val rayLen = 140f + 50f * prog
                drawCircle(Color(0xFFFF4DA6).copy(alpha = 0.16f + prog * 0.18f), rayLen * 0.55f, groundPos)
                for (k in 0 until rays) {
                    val a = k * (2f * PI.toFloat() / rays) + time * 0.8f
                    drawLine(
                        color = GoldAccent.copy(alpha = 0.72f),
                        start = groundPos,
                        end = Offset(groundPos.x + cos(a) * rayLen, groundPos.y + sin(a) * rayLen),
                        strokeWidth = 3.2f,
                        cap = StrokeCap.Round
                    )
                }
                drawCircle(CrimsonRed.copy(alpha = 0.88f), rayLen * 0.55f * prog, groundPos, style = STROKE_4_5)
            }
            BossAttackKind.SUMMON_GUARD -> {
                val ringR = 165f
                drawCircle(Color(0xFFC25AFF).copy(alpha = 0.16f + prog * 0.20f), ringR, groundPos)
                drawCircle(Color(0xFFE09AFF).copy(alpha = 0.90f), ringR * prog, groundPos, style = STROKE_5_0)
                drawCircle(GoldAccent.copy(alpha = 0.72f), ringR, groundPos, style = STROKE_2_8)
            }
            else -> {
                drawCircle(CrimsonRed.copy(alpha = 0.14f + prog * 0.22f), e.telegraphRadius, groundPos)
                drawCircle(CrimsonRed.copy(alpha = 0.9f), e.telegraphRadius * prog, groundPos, style = STROKE_6_0)
                drawCircle(GoldAccent.copy(alpha = 0.7f), e.telegraphRadius, groundPos, style = STROKE_3_0)
            }
        }
    }

    val leapAlt = (e.z - e.groundZ).coerceAtLeast(0f)
    val hop = if (leapAlt > 3f) 0f else -abs(sin(e.animPhase)) * (if (e.isBoss) 5f else 4f)
    val cx = bodyPos.x
    val cy = bodyPos.y + hop
    val c = Offset(cx, cy)
    val r = e.radius * (1f + (leapAlt * 0.0022f).coerceAtMost(0.16f))

    // Ground shadow anchored to terrain elevation, shrinking smoothly when leaping onto a plateau
    val shadowScale = (1f - leapAlt * 0.006f).coerceIn(0.45f, 1f)
    val shadowAlpha = (0.25f - leapAlt * 0.0015f).coerceIn(0.10f, 0.25f)
    drawOval(
        Color.Black.copy(alpha = shadowAlpha),
        Offset(groundPos.x - e.radius * 0.88f * shadowScale, groundPos.y + e.radius * 0.66f),
        Size(e.radius * 1.76f * shadowScale, e.radius * 0.52f * shadowScale)
    )

    // Elite or Boss ground aura (zero Brush shader allocation)
    if (e.isBoss) {
        val phaseCol = when {
            e.staggerTimer > 0f -> Color(0xFF66F6FF)
            e.bossPhase >= 3 -> Color(0xFFFF2A8A)
            e.bossPhase == 2 -> WarmOrange
            else -> CrimsonRed
        }
        drawCircle(phaseCol.copy(alpha = 0.18f), r * 1.72f, groundPos)
        drawCircle(phaseCol.copy(alpha = 0.28f), r * 1.18f, groundPos)
        if (e.bossPhase >= 2 || e.staggerTimer > 0f) {
            drawCircle(phaseCol.copy(alpha = 0.82f), r * 1.38f, groundPos, style = STROKE_3_2)
        }
        if (e.staggerTimer > 0f) {
            for (k in 0 until 3) {
                val a = time * 5.2f + k * (2f * PI.toFloat() / 3f)
                val sx = cx + cos(a) * (r * 0.72f)
                val sy = cy - r * 1.12f + sin(a) * 10f
                drawCircle(GoldAccent, 6f, Offset(sx, sy))
                drawCircle(Color.White, 2.6f, Offset(sx, sy))
            }
        }
    } else if (e.isElite) {
        drawCircle(GoldAccent.copy(alpha = 0.82f), r + 6f, c, style = STROKE_3_5)
    }

    val bodyColor = when {
        e.hitFlash > 0.35f -> Color.White
        e.slowTimer > 0f -> Color(0xFF7BE8FF)
        else -> e.primaryColor
    }
    val accentColor = if (e.hitFlash > 0.35f) Color.White else e.secondaryColor

    // Distinct cel-shaded creature silhouettes by defId family (zero Path/List/Brush allocation)
    when {
        e.defId.contains("shroom") -> {
            drawRoundRect(
                Color(0xFFF6E6C8),
                Offset(cx - r * 0.54f, cy - r * 0.08f),
                Size(r * 1.08f, r * 0.94f),
                CornerRadius(r * 0.38f, r * 0.38f)
            )
            drawArc(
                bodyColor,
                180f,
                180f,
                true,
                Offset(cx - r * 1.12f, cy - r * 1.12f),
                Size(r * 2.24f, r * 1.92f)
            )
            drawArc(
                accentColor.copy(alpha = 0.65f),
                195f,
                115f,
                true,
                Offset(cx - r * 0.98f, cy - r * 1.02f),
                Size(r * 1.68f, r * 1.38f)
            )
            drawCircle(Color(0xFFFFF6DE).copy(alpha = 0.92f), r * 0.23f, Offset(cx - r * 0.44f, cy - r * 0.56f))
            drawCircle(Color(0xFFFFF6DE).copy(alpha = 0.90f), r * 0.18f, Offset(cx + r * 0.46f, cy - r * 0.46f))
            drawCircle(Color.White.copy(alpha = 0.42f), r * 0.13f, Offset(cx - r * 0.06f, cy - r * 0.84f))
            drawArc(EspressoDark, 180f, 180f, true, Offset(cx - r * 1.12f, cy - r * 1.12f), Size(r * 2.24f, r * 1.92f), style = STROKE_2_8)
            drawRoundRect(EspressoDark, Offset(cx - r * 0.54f, cy - r * 0.08f), Size(r * 1.08f, r * 0.94f), CornerRadius(r * 0.38f, r * 0.38f), style = STROKE_2_6)
        }
        e.defId.contains("wisp") || e.defId.contains("wraith") -> {
            val hemSway = sin(time * 5.2f + e.id) * (r * 0.12f)
            scratch.reset()
            scratch.moveTo(cx - r, cy + r * 0.72f)
            scratch.quadraticTo(cx - r, cy - r * 1.04f, cx, cy - r * 1.04f)
            scratch.quadraticTo(cx + r, cy - r * 1.04f, cx + r, cy + r * 0.72f)
            scratch.lineTo(cx + r * 0.48f + hemSway, cy + r * 0.46f)
            scratch.lineTo(cx + hemSway * 0.6f, cy + r * 0.92f)
            scratch.lineTo(cx - r * 0.48f + hemSway, cy + r * 0.46f)
            scratch.close()
            drawPath(scratch, bodyColor.copy(alpha = 0.90f))
            drawCircle(accentColor.copy(alpha = 0.52f), r * 0.62f, Offset(cx - r * 0.14f, cy - r * 0.30f))
            drawCircle(Color.White.copy(alpha = 0.36f), r * 0.38f, Offset(cx, cy - r * 0.16f))
            drawPath(scratch, EspressoDark, style = if (e.isBoss) STROKE_4_2 else STROKE_2_8)
        }
        e.defId.contains("bug") || e.defId.contains("beetle") || e.defId.contains("scorp") || e.defId.contains("scarab") -> {
            val legWiggle = sin(e.animPhase * 1.5f) * (r * 0.14f)
            for (sIdx in 0..1) {
                val side = if (sIdx == 0) -1f else 1f
                drawLine(EspressoDark, Offset(cx + side * r * 0.86f, cy - r * 0.10f), Offset(cx + side * r * 1.24f, cy - r * 0.24f + legWiggle * side), 3.0f, StrokeCap.Round)
                drawLine(EspressoDark, Offset(cx + side * r * 0.86f, cy + r * 0.32f), Offset(cx + side * r * 1.24f, cy + r * 0.46f - legWiggle * side), 3.0f, StrokeCap.Round)
                drawLine(EspressoDark, Offset(cx + side * r * 0.42f, cy - r * 0.72f), Offset(cx + side * r * 0.82f, cy - r * 1.28f), 3.2f, StrokeCap.Round)
                drawCircle(accentColor, r * 0.12f, Offset(cx + side * r * 0.82f, cy - r * 1.28f))
            }
            drawOval(bodyColor, Offset(cx - r * 1.08f, cy - r * 0.86f), Size(r * 2.16f, r * 1.72f))
            drawOval(accentColor.copy(alpha = 0.58f), Offset(cx - r * 0.90f, cy - r * 0.72f), Size(r * 1.48f, r * 1.12f))
            drawLine(EspressoDark.copy(alpha = 0.55f), Offset(cx, cy - r * 0.82f), Offset(cx, cy + r * 0.80f), 2.2f)
            drawOval(Color.White.copy(alpha = 0.34f), Offset(cx - r * 0.64f, cy - r * 0.58f), Size(r * 0.52f, r * 0.22f))
            drawOval(EspressoDark, Offset(cx - r * 1.08f, cy - r * 0.86f), Size(r * 2.16f, r * 1.72f), style = if (e.isBoss) STROKE_4_2 else STROKE_2_8)
        }
        else -> {
            if (e.isBoss || e.isElite) {
                val hornScale = if (e.isBoss) 1.0f else 0.72f
                val hornStroke = if (e.isBoss) STROKE_3_5 else STROKE_2_4
                for (sIdx in 0..1) {
                    val side = if (sIdx == 0) -1f else 1f
                    scratch.reset()
                    scratch.moveTo(cx + side * r * 0.58f, cy - r * 0.55f)
                    scratch.lineTo(cx + side * r * (0.96f * hornScale), cy - r * (1.36f * hornScale))
                    scratch.lineTo(cx + side * r * 0.22f, cy - r * 0.84f)
                    scratch.close()
                    drawPath(scratch, GoldAccent)
                    drawPath(scratch, EspressoDark, style = hornStroke)
                }
            }
            drawCircle(bodyColor, r, c)
            drawCircle(accentColor.copy(alpha = 0.56f), r * 0.72f, Offset(cx - r * 0.16f, cy - r * 0.18f))
            drawOval(Color.White.copy(alpha = 0.28f), Offset(cx - r * 0.56f, cy - r * 0.64f), Size(r * 0.56f, r * 0.24f))
            drawCircle(EspressoDark, r, c, style = if (e.isBoss) STROKE_4_4 else STROKE_2_8)
        }
    }

    // Expressive eyes + fierce brows for Elites & Bosses
    val eyeShiftX = if (e.facingLeft) -r * 0.10f else r * 0.10f
    val eyeR = (r * 0.17f).coerceIn(3.4f, 9.5f)
    val eyeY = if (e.defId.contains("shroom")) cy + r * 0.28f else cy - r * 0.04f
    val leftEyePos = Offset(cx - r * 0.27f + eyeShiftX, eyeY)
    val rightEyePos = Offset(cx + r * 0.27f + eyeShiftX, eyeY)
    drawCircle(EspressoDark, eyeR, leftEyePos)
    drawCircle(EspressoDark, eyeR, rightEyePos)
    val glintColor = if (e.isBoss) GoldAccent else Color.White
    drawCircle(glintColor, eyeR * 0.46f, Offset(leftEyePos.x - eyeR * 0.24f, leftEyePos.y - eyeR * 0.24f))
    drawCircle(glintColor, eyeR * 0.46f, Offset(rightEyePos.x - eyeR * 0.24f, rightEyePos.y - eyeR * 0.24f))
    if (e.isBoss || e.isElite) {
        drawLine(EspressoDark, Offset(leftEyePos.x - eyeR * 1.3f, leftEyePos.y - eyeR * 1.3f), Offset(leftEyePos.x + eyeR * 1.1f, leftEyePos.y - eyeR * 0.65f), 3.0f, StrokeCap.Round)
        drawLine(EspressoDark, Offset(rightEyePos.x + eyeR * 1.3f, rightEyePos.y - eyeR * 1.3f), Offset(rightEyePos.x - eyeR * 1.1f, rightEyePos.y - eyeR * 0.65f), 3.0f, StrokeCap.Round)
    }

    // Burn flame ember indicator
    if (e.burnTimer > 0f) {
        val fOff = sin(time * 14f + e.id) * 2.5f
        val flamePos = Offset(cx + r * 0.56f, cy - r * 0.68f + fOff)
        drawCircle(WarmOrange, 6.5f, flamePos)
        drawCircle(GoldAccent, 3.2f, flamePos)
    }

    // Mini HP bar for damaged non-boss enemies
    if (!e.isBoss && e.hp < e.maxHp) {
        val bw = r * 1.85f
        val bh = 5.5f
        val bx = bodyPos.x - bw * 0.5f
        val by = bodyPos.y - r - 14f
        drawRoundRect(EspressoDark, Offset(bx, by), Size(bw, bh), CornerRadius(3f, 3f))
        drawRoundRect(
            CrimsonRed,
            Offset(bx + 1f, by + 1f),
            Size((bw - 2f) * (e.hp / e.maxHp).coerceIn(0f, 1f), bh - 2f),
            CornerRadius(2f, 2f)
        )
    }
}

private const val SORT_KIND_ENEMY = 0
private const val SORT_KIND_HERO = 1
private const val SORT_KIND_OBSTACLE = 2

private class SortableWorldEntry(
    var kind: Int = 0,
    var index: Int = 0,
    var sortY: Float = 0f
)
