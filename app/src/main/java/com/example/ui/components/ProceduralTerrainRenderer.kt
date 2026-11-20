package com.example.ui.components

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import com.example.game.engine.BattleRenderState
import com.example.game.engine.ExpandingRingSnapshot
import com.example.game.engine.TerrainObstacle
import com.example.game.engine.TerrainObstacleKind
import com.example.game.engine.TerrainPlateau
import com.example.game.model.BiomeDef
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Reusable Path & scalar scratch buffers allocated once per BattleCanvas composition
 * to keep procedural terrain, 2.5D plateaus, obstacles, and grass rendering ultra-fast
 * and allocation-free (targeting < 8ms draw time even on software/emulator EGL).
 */
class TerrainPathCache {
    val pathRibbonA = Path()
    val pathRibbonB = Path()
    val shapeScratch = Path()
    val facetScratch = Path()
    val visiblePlateaus = ArrayList<TerrainPlateau>(8)

    // Reusable scalar outputs for grass tuft physics (zero Pair boxing)
    var tmpSway: Float = 0f
    var tmpDipY: Float = 0f
}

private val TRAIL_STROKE_OUTER = Stroke(width = 86f, cap = StrokeCap.Round, join = StrokeJoin.Round)
private val TRAIL_STROKE_MID = Stroke(width = 62f, cap = StrokeCap.Round, join = StrokeJoin.Round)
private val TRAIL_STROKE_INNER = Stroke(width = 36f, cap = StrokeCap.Round, join = StrokeJoin.Round)
private val CLIFF_SHADOW_STROKE = Stroke(width = 8f, cap = StrokeCap.Round)
private val CLIFF_OUTLINE_STROKE = Stroke(width = 3.2f)
private val TERRACE_HIGHLIGHT_STROKE = Stroke(width = 3.2f, cap = StrokeCap.Round)
private val TERRACE_OUTLINE_STROKE = Stroke(width = 2.6f)
private val RAMP_OUTLINE_STROKE = Stroke(width = 2.4f, join = StrokeJoin.Round)
private val DESERT_DUNE_STROKE = Stroke(width = 2.2f, cap = StrokeCap.Round)
private val BOULDER_OUTLINE_STROKE = Stroke(width = 3.2f, join = StrokeJoin.Round)
private val TRUNK_OUTLINE_STROKE = Stroke(width = 2.8f, join = StrokeJoin.Round)
private val PALM_CORE_STROKE = Stroke(width = 2.4f)
private val CANOPY_OUTLINE_26 = Stroke(width = 2.6f)
private val CANOPY_OUTLINE_28 = Stroke(width = 2.8f)
private val ARENA_BORDER_OUTER = Stroke(width = 16f)
private val ARENA_BORDER_INNER = Stroke(width = 3.5f)
private val PERIMETER_BUSH_STROKE = Stroke(width = 2.4f)

private data class BiomeFoliagePalette(
    val sunlitWash: Color,
    val shadeWash: Color,
    val terraceTop: Color,
    val terraceRim: Color,
    val cliffLight: Color,
    val cliffMid: Color,
    val cliffDark: Color,
    val rampWood: Color,
    val pathEdge: Color,
    val pathCenter: Color,
    val bladeShadow: Color,
    val bladeBack: Color,
    val bladeMid: Color,
    val bladeHighlight: Color,
    val flowerA: Color,
    val flowerB: Color,
    val borderDark: Color,
    val borderMid: Color,
    val borderLight: Color,
    val trunkDark: Color,
    val trunkLight: Color,
    val rockShadow: Color,
    val rockMid: Color,
    val rockLight: Color,
    val rockAccent: Color
)

private val FOREST_PALETTE = BiomeFoliagePalette(
    sunlitWash = Color(0xFFB3E674),
    shadeWash = Color(0xFF539642),
    terraceTop = Color(0xFF93D66F),
    terraceRim = Color(0xFF4D8A3C),
    cliffLight = Color(0xFFA67B52),
    cliffMid = Color(0xFF835B3A),
    cliffDark = Color(0xFF593B25),
    rampWood = Color(0xFFC99B63),
    pathEdge = Color(0xFFB89E6C),
    pathCenter = Color(0xFFE0C896),
    bladeShadow = Color(0xFF3E722E),
    bladeBack = Color(0xFF478936),
    bladeMid = Color(0xFF63AE4A),
    bladeHighlight = Color(0xFFA2DF66),
    flowerA = Color(0xFFFFF5A8),
    flowerB = Color(0xFFFFD4E2),
    borderDark = Color(0xFF2B5926),
    borderMid = Color(0xFF417D35),
    borderLight = Color(0xFF72B552),
    trunkDark = Color(0xFF5A3923),
    trunkLight = Color(0xFF8B5D3B),
    rockShadow = Color(0xFF666E68),
    rockMid = Color(0xFF8D968E),
    rockLight = Color(0xFFB8C1B6),
    rockAccent = Color(0xFF6BB44E)
)

private val GRAVEYARD_PALETTE = BiomeFoliagePalette(
    sunlitWash = Color(0xFF7A94A3),
    shadeWash = Color(0xFF3A4752),
    terraceTop = Color(0xFF687C87),
    terraceRim = Color(0xFF3A4854),
    cliffLight = Color(0xFF5C6673),
    cliffMid = Color(0xFF414954),
    cliffDark = Color(0xFF282E38),
    rampWood = Color(0xFF788492),
    pathEdge = Color(0xFF545F69),
    pathCenter = Color(0xFF828E99),
    bladeShadow = Color(0xFF2B353E),
    bladeBack = Color(0xFF384752),
    bladeMid = Color(0xFF4F6470),
    bladeHighlight = Color(0xFF85A5B2),
    flowerA = Color(0xFF9BF2FF),
    flowerB = Color(0xFFC8B6FF),
    borderDark = Color(0xFF212933),
    borderMid = Color(0xFF354352),
    borderLight = Color(0xFF5C7587),
    trunkDark = Color(0xFF343844),
    trunkLight = Color(0xFF565E6E),
    rockShadow = Color(0xFF3A424D),
    rockMid = Color(0xFF586370),
    rockLight = Color(0xFF8594A3),
    rockAccent = Color(0xFF80E5FF)
)

private val DESERT_PALETTE = BiomeFoliagePalette(
    sunlitWash = Color(0xFFF5D892),
    shadeWash = Color(0xFFB78A47),
    terraceTop = Color(0xFFEAC780),
    terraceRim = Color(0xFFB8843F),
    cliffLight = Color(0xFFC98A48),
    cliffMid = Color(0xFFA66B32),
    cliffDark = Color(0xFF764820),
    rampWood = Color(0xFFD8A762),
    pathEdge = Color(0xFFA7783A),
    pathCenter = Color(0xFFD2A45E),
    bladeShadow = Color(0xFF8D6630),
    bladeBack = Color(0xFF7C8B3E),
    bladeMid = Color(0xFF9BAA4F),
    bladeHighlight = Color(0xFFD8C66A),
    flowerA = Color(0xFFFFF0A8),
    flowerB = Color(0xFFFF9E7D),
    borderDark = Color(0xFF7D5224),
    borderMid = Color(0xFFA67036),
    borderLight = Color(0xFFD19A54),
    trunkDark = Color(0xFF7D5029),
    trunkLight = Color(0xFFB47B46),
    rockShadow = Color(0xFF945D30),
    rockMid = Color(0xFFC48247),
    rockLight = Color(0xFFE7B274),
    rockAccent = Color(0xFF7DA346)
)

private val VOLCANO_PALETTE = BiomeFoliagePalette(
    sunlitWash = Color(0xFF7E524C),
    shadeWash = Color(0xFF38272A),
    terraceTop = Color(0xFF6B4E52),
    terraceRim = Color(0xFF39262A),
    cliffLight = Color(0xFF573B3E),
    cliffMid = Color(0xFF3B2629),
    cliffDark = Color(0xFF231518),
    rampWood = Color(0xFF784B40),
    pathEdge = Color(0xFF59312A),
    pathCenter = Color(0xFF864B3B),
    bladeShadow = Color(0xFF2A1C1F),
    bladeBack = Color(0xFF473135),
    bladeMid = Color(0xFF6B3E3B),
    bladeHighlight = Color(0xFFFF7A3B),
    flowerA = Color(0xFFFF9B42),
    flowerB = Color(0xFFFF5936),
    borderDark = Color(0xFF24171A),
    borderMid = Color(0xFF3E282C),
    borderLight = Color(0xFF6E3D3A),
    trunkDark = Color(0xFF2A1D20),
    trunkLight = Color(0xFF4F373B),
    rockShadow = Color(0xFF261A1E),
    rockMid = Color(0xFF423036),
    rockLight = Color(0xFF684D52),
    rockAccent = Color(0xFFFF6E30)
)

private fun paletteForBiome(biome: BiomeDef): BiomeFoliagePalette = when (biome.id) {
    "forest" -> FOREST_PALETTE
    "graveyard" -> GRAVEYARD_PALETTE
    "desert" -> DESERT_PALETTE
    else -> VOLCANO_PALETTE
}

/**
 * Shared ground elevation lookup for props, pickups, and highland grass tufts.
 */
fun terrainElevationAt(wx: Float, wy: Float, plateaus: List<TerrainPlateau>): Float {
    var maxElev = 0f
    for (i in plateaus.indices) {
        val p = plateaus[i]
        if (p.containsPoint(wx, wy)) {
            if (p.elevation > maxElev) maxElev = p.elevation
        }
    }
    return maxElev
}

private fun trailDistanceFactor(wx: Float, wy: Float): Float {
    val trailAY = sin(wx * 0.0021f) * 240f - 130f
    val trailBX = sin(wy * 0.0023f) * 250f + 150f
    val distA = abs(wy - trailAY)
    val distB = abs(wx - trailBX)
    return minOf(distA, distB) / 76f
}

private fun cellHash(c: Int, r: Int): Int {
    var h = (c * 374761393) xor (r * 668265263)
    h = (h xor (h ushr 13)) * 1274126177
    return (h xor (h ushr 16)) and 0x7FFFFFFF
}

private const val GRASS_CELL_SIZE = 114f

/**
 * High-performance procedural battlefield terrain & hand-painted interactive grass layer.
 * Uses zero per-frame Brush shader allocations and zero quadratic-Bézier mega-paths so
 * it maintains smooth frame pacing while delivering rich PokéBonk-style 2.5D depth.
 */
fun DrawScope.drawProceduralBiomeTerrain(
    biome: BiomeDef,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: TerrainPathCache
) {
    val palette = paletteForBiome(biome)
    val time = state.elapsedSec

    // 1. Base biome ground fill
    drawRect(color = biome.groundBase, size = size)

    // 2. Macro sunlit & shaded painterly washes (zero-allocation 2-layer soft ellipses)
    val macroCell = 360f
    val mStartCol = floor(camX / macroCell).toInt() - 1
    val mEndCol = floor((camX + size.width) / macroCell).toInt() + 1
    val mStartRow = floor(camY / macroCell).toInt() - 1
    val mEndRow = floor((camY + size.height) / macroCell).toInt() + 1
    for (mr in mStartRow..mEndRow) {
        for (mc in mStartCol..mEndCol) {
            val h = cellHash(mc, mr)
            val cx = mc * macroCell - camX + macroCell * 0.5f + ((h % 160) - 80)
            val cy = mr * macroCell - camY + macroCell * 0.5f + (((h / 173) % 160) - 80)
            val rx = 185f + (h % 95)
            val ry = rx * (0.68f + ((h / 19) % 18) * 0.01f)
            if (cx + rx < 0f || cx - rx > size.width || cy + ry < 0f || cy - ry > size.height) continue

            val baseColor = when (h % 3) {
                0 -> palette.sunlitWash
                1 -> palette.shadeWash
                else -> biome.groundAlt
            }
            val outerAlpha = when (h % 3) {
                0 -> 0.13f
                1 -> 0.11f
                else -> 0.16f
            }
            // Feathered 2-step wash mimics radial watercolor without creating Shader objects
            drawOval(
                color = baseColor.copy(alpha = outerAlpha),
                topLeft = Offset(cx - rx, cy - ry),
                size = Size(rx * 2f, ry * 2f)
            )
            drawOval(
                color = baseColor.copy(alpha = outerAlpha * 0.85f),
                topLeft = Offset(cx - rx * 0.62f, cy - ry * 0.62f),
                size = Size(rx * 1.24f, ry * 1.24f)
            )
        }
    }

    // Pre-cull visible 2.5D plateaus once per frame so grass & cliff passes only inspect 1-3 on-screen plateaus
    cache.visiblePlateaus.clear()
    val allPlateaus = state.terrainPlateaus
    for (i in allPlateaus.indices) {
        val p = allPlateaus[i]
        val sx = p.x - camX
        val sy = p.y - camY
        if (sx + p.rx + 64f >= 0f && sx - p.rx - 64f <= size.width &&
            sy + p.ry + 64f >= 0f && sy - p.ry - p.elevation - 48f <= size.height
        ) {
            cache.visiblePlateaus.add(p)
        }
    }

    // 3. Continuous Hand-Painted Meandering Dirt Trails (clipped cleanly to viewport)
    drawMeanderingTrails(palette, camX, camY, cache)

    // 4. Lowland Procedural Hand-Painted Grass Field (Wind Waves + Hero & Shockwave Parting)
    drawInteractiveGrassField(
        biome = biome,
        palette = palette,
        state = state,
        camX = camX,
        camY = camY,
        time = time,
        cache = cache,
        highlandOnly = false
    )

    // 5. Playable 2.5D Jumpable Elevation Plateaus with Cliff Drop-Offs & Walkable Ramps
    if (cache.visiblePlateaus.isNotEmpty()) {
        drawJumpableElevationPlateaus(
            biome = biome,
            palette = palette,
            plateaus = cache.visiblePlateaus,
            camX = camX,
            camY = camY,
            cache = cache
        )

        // 6. Highland Grass Tufts sitting atop visible raised 2.5D plateaus (tight per-plateau bounds!)
        drawHighlandPlateauGrass(
            biome = biome,
            palette = palette,
            state = state,
            camX = camX,
            camY = camY,
            time = time,
            cache = cache
        )
    }

    // 7. Slow-Drifting Canopy Sunbeams & Cloud Shadow Dapples (zero Brush allocation)
    for (i in 0 until 3) {
        val driftX = ((i * 520f + time * 18f - camX * 0.35f) % (size.width + 640f) + (size.width + 640f)) % (size.width + 640f) - 320f
        val driftY = ((i * 390f + time * 8f - camY * 0.35f) % (size.height + 520f) + (size.height + 520f)) % (size.height + 520f) - 260f
        val isSunbeam = i % 2 == 0
        val col = if (isSunbeam) {
            palette.sunlitWash.copy(alpha = if (biome.id == "forest" || biome.id == "desert") 0.08f else 0.045f)
        } else {
            palette.shadeWash.copy(alpha = 0.065f)
        }
        drawCircle(color = col, radius = 210f, center = Offset(driftX, driftY))
        drawCircle(color = col, radius = 125f, center = Offset(driftX, driftY))
    }

    // 8. Stylized Arena Perimeter Treeline / Cliff Rim (bHalf = 1450f)
    drawStylizedArenaBorder(palette, camX, camY, time)
}

/**
 * Draws the playable 2.5D raised terrain plateaus with unmistakable height drop-offs:
 * cast ground shadow, vertical striated rock cliff facade, overhanging turf rim,
 * sunlit elevated meadow top, and a clearly readable walkable ramp on [TerrainPlateau.rampSide].
 */
private fun DrawScope.drawJumpableElevationPlateaus(
    biome: BiomeDef,
    palette: BiomeFoliagePalette,
    plateaus: List<TerrainPlateau>,
    camX: Float,
    camY: Float,
    cache: TerrainPathCache
) {
    for (i in plateaus.indices) {
        val p = plateaus[i]
        val sx = p.x - camX
        val sy = p.y - camY
        val rx = p.rx
        val ry = p.ry
        val elev = p.elevation

        val topY = sy - elev

        // 1. Deep south-east cast ground shadow beneath the cliff drop-off
        drawOval(
            color = Color.Black.copy(alpha = 0.24f),
            topLeft = Offset(sx - rx * 1.02f + 10f, sy - ry * 0.90f + 10f),
            size = Size(rx * 2.04f, ry * 1.92f)
        )

        // 2. Vertical 2.5D cliff rock wall (bottom ellipse + cylinder wall band)
        drawOval(
            color = palette.cliffDark,
            topLeft = Offset(sx - rx, sy - ry),
            size = Size(rx * 2f, ry * 2f)
        )
        drawRect(
            color = palette.cliffMid,
            topLeft = Offset(sx - rx, topY),
            size = Size(rx * 2f, elev)
        )
        // Lower curved south cliff face fill
        drawArc(
            color = palette.cliffMid,
            startAngle = 0f,
            sweepAngle = 180f,
            useCenter = true,
            topLeft = Offset(sx - rx, sy - ry),
            size = Size(rx * 2f, ry * 2f)
        )
        // Shadow band along the very bottom base of the cliff wall
        drawArc(
            color = palette.cliffDark.copy(alpha = 0.72f),
            startAngle = 8f,
            sweepAngle = 164f,
            useCenter = false,
            topLeft = Offset(sx - rx + 2f, sy - ry - 2f),
            size = Size((rx - 2f) * 2f, (ry - 2f) * 2f),
            style = CLIFF_SHADOW_STROKE
        )

        // Vertical sculpted rock strata ribs along the visible front (south) cliff wall
        val ribCount = 7
        for (rIdx in 0 until ribCount) {
            val angleDeg = 22f + rIdx * (136f / (ribCount - 1))
            val rad = angleDeg * (PI.toFloat() / 180f)
            val edgeX = sx + cos(rad) * (rx * 0.95f)
            val edgeBottomY = sy + sin(rad) * (ry * 0.96f)
            val edgeTopY = edgeBottomY - elev + 5f
            val isLitSide = angleDeg > 95f
            drawLine(
                color = if (isLitSide) palette.cliffLight.copy(alpha = 0.65f) else palette.cliffDark.copy(alpha = 0.72f),
                start = Offset(edgeX, edgeTopY),
                end = Offset(edgeX, edgeBottomY - 3f),
                strokeWidth = if (rIdx % 2 == 0) 4.2f else 2.6f,
                cap = StrokeCap.Round
            )
            // Subtle volcano magma crack accent on cliff faces
            if (biome.id == "volcano" && rIdx % 2 == 1) {
                drawLine(
                    color = palette.rockAccent.copy(alpha = 0.68f),
                    start = Offset(edgeX + 2f, edgeTopY + elev * 0.25f),
                    end = Offset(edgeX - 1f, edgeBottomY - elev * 0.2f),
                    strokeWidth = 1.8f,
                    cap = StrokeCap.Round
                )
            }
        }

        // Crisp dark outline along the cliff base and sides
        drawArc(
            color = EspressoDark.copy(alpha = 0.72f),
            startAngle = 0f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(sx - rx, sy - ry),
            size = Size(rx * 2f, ry * 2f),
            style = CLIFF_OUTLINE_STROKE
        )
        drawLine(
            color = EspressoDark.copy(alpha = 0.72f),
            start = Offset(sx - rx, topY),
            end = Offset(sx - rx, sy),
            strokeWidth = 3.2f
        )
        drawLine(
            color = EspressoDark.copy(alpha = 0.72f),
            start = Offset(sx + rx, topY),
            end = Offset(sx + rx, sy),
            strokeWidth = 3.2f
        )

        // 3. Overhanging lush turf rim lip casting a small under-lip shadow
        drawOval(
            color = palette.terraceRim,
            topLeft = Offset(sx - rx - 2f, topY - ry + 5.5f),
            size = Size((rx + 2f) * 2f, ry * 2f)
        )

        // 4. Sunlit Elevated Meadow Top Surface
        drawOval(
            color = palette.terraceTop,
            topLeft = Offset(sx - rx, topY - ry),
            size = Size(rx * 2f, ry * 2f)
        )
        // Soft sunlit inner patch shifted slightly toward upper-left light source
        drawOval(
            color = palette.sunlitWash.copy(alpha = 0.36f),
            topLeft = Offset(sx - rx * 0.78f, topY - ry * 0.80f),
            size = Size(rx * 1.46f, ry * 1.38f)
        )
        // Crisp upper sunlit rim highlight arc + clean plateau edge outline
        drawArc(
            color = Color.White.copy(alpha = 0.34f),
            startAngle = 196f,
            sweepAngle = 148f,
            useCenter = false,
            topLeft = Offset(sx - rx + 5f, topY - ry + 4f),
            size = Size((rx - 5f) * 2f, (ry - 4f) * 2f),
            style = TERRACE_HIGHLIGHT_STROKE
        )
        drawOval(
            color = EspressoDark.copy(alpha = 0.56f),
            topLeft = Offset(sx - rx, topY - ry),
            size = Size(rx * 2f, ry * 2f),
            style = TERRACE_OUTLINE_STROKE
        )

        // 5. Walkable Sloped Ramp on p.rampSide (0=South, 1=West, 2=East)
        drawPlateauRamp(
            sx = sx,
            sy = sy,
            topY = topY,
            rx = rx,
            ry = ry,
            rampSide = p.rampSide,
            palette = palette,
            cache = cache
        )
    }
}

private fun DrawScope.drawPlateauRamp(
    sx: Float,
    sy: Float,
    topY: Float,
    rx: Float,
    ry: Float,
    rampSide: Int,
    palette: BiomeFoliagePalette,
    cache: TerrainPathCache
) {
    val rampPath = cache.shapeScratch
    rampPath.reset()

    when (rampSide) {
        0 -> { // South walkable ramp
            val topHalfW = 28f
            val botHalfW = 36f
            val yTop = topY + ry - 8f
            val yBot = sy + ry + 14f
            rampPath.moveTo(sx - topHalfW, yTop)
            rampPath.lineTo(sx + topHalfW, yTop)
            rampPath.lineTo(sx + botHalfW, yBot)
            rampPath.lineTo(sx - botHalfW, yBot)
            rampPath.close()

            drawPath(rampPath, palette.pathCenter)
            drawPath(rampPath, EspressoDark.copy(alpha = 0.65f), style = RAMP_OUTLINE_STROKE)

            // 3 wooden/stone step planks + upward chevron guide
            for (stepIdx in 1..3) {
                val t = stepIdx / 4f
                val py = yTop + (yBot - yTop) * t
                val hw = topHalfW + (botHalfW - topHalfW) * t - 5f
                drawLine(
                    color = palette.cliffDark.copy(alpha = 0.55f),
                    start = Offset(sx - hw, py),
                    end = Offset(sx + hw, py),
                    strokeWidth = 3f,
                    cap = StrokeCap.Round
                )
            }
            // Subtle upward ramp chevron
            val cy = (yTop + yBot) * 0.52f
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(sx - 8f, cy + 4f), Offset(sx, cy - 4f), 2.8f, StrokeCap.Round)
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(sx + 8f, cy + 4f), Offset(sx, cy - 4f), 2.8f, StrokeCap.Round)
        }
        1 -> { // West walkable ramp
            val xInner = sx - rx + 10f
            val xOuter = sx - rx - 24f
            val halfH = 22f
            rampPath.moveTo(xInner, topY - halfH * 0.85f)
            rampPath.lineTo(xInner, topY + halfH * 0.85f)
            rampPath.lineTo(xOuter, sy + halfH)
            rampPath.lineTo(xOuter, sy - halfH * 0.65f)
            rampPath.close()

            drawPath(rampPath, palette.pathCenter)
            drawPath(rampPath, EspressoDark.copy(alpha = 0.65f), style = RAMP_OUTLINE_STROKE)

            for (stepIdx in 1..3) {
                val t = stepIdx / 4f
                val px = xOuter + (xInner - xOuter) * t
                val midY = sy + (topY - sy) * t
                drawLine(
                    color = palette.cliffDark.copy(alpha = 0.55f),
                    start = Offset(px, midY - 12f),
                    end = Offset(px, midY + 12f),
                    strokeWidth = 2.8f,
                    cap = StrokeCap.Round
                )
            }
            val cx = (xInner + xOuter) * 0.5f
            val cy = (topY + sy) * 0.5f
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(cx - 4f, cy - 6f), Offset(cx + 4f, cy), 2.6f, StrokeCap.Round)
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(cx - 4f, cy + 6f), Offset(cx + 4f, cy), 2.6f, StrokeCap.Round)
        }
        else -> { // East walkable ramp
            val xInner = sx + rx - 10f
            val xOuter = sx + rx + 24f
            val halfH = 22f
            rampPath.moveTo(xInner, topY - halfH * 0.85f)
            rampPath.lineTo(xOuter, sy - halfH * 0.65f)
            rampPath.lineTo(xOuter, sy + halfH)
            rampPath.lineTo(xInner, topY + halfH * 0.85f)
            rampPath.close()

            drawPath(rampPath, palette.pathCenter)
            drawPath(rampPath, EspressoDark.copy(alpha = 0.65f), style = RAMP_OUTLINE_STROKE)

            for (stepIdx in 1..3) {
                val t = stepIdx / 4f
                val px = xOuter + (xInner - xOuter) * t
                val midY = sy + (topY - sy) * t
                drawLine(
                    color = palette.cliffDark.copy(alpha = 0.55f),
                    start = Offset(px, midY - 12f),
                    end = Offset(px, midY + 12f),
                    strokeWidth = 2.8f,
                    cap = StrokeCap.Round
                )
            }
            val cx = (xInner + xOuter) * 0.5f
            val cy = (topY + sy) * 0.5f
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(cx + 4f, cy - 6f), Offset(cx - 4f, cy), 2.6f, StrokeCap.Round)
            drawLine(CreamSurface.copy(alpha = 0.72f), Offset(cx + 4f, cy + 6f), Offset(cx - 4f, cy), 2.6f, StrokeCap.Round)
        }
    }
}

private fun DrawScope.drawMeanderingTrails(
    palette: BiomeFoliagePalette,
    camX: Float,
    camY: Float,
    cache: TerrainPathCache
) {
    val step = 72f
    cache.pathRibbonA.reset()
    val startX = floor((camX - 120f) / step) * step
    val endX = camX + size.width + 120f
    var x = startX
    var firstA = true
    while (x <= endX) {
        val wy = sin(x * 0.0021f) * 240f - 130f
        val sx = x - camX
        val sy = wy - camY
        if (firstA) {
            cache.pathRibbonA.moveTo(sx, sy)
            firstA = false
        } else {
            cache.pathRibbonA.lineTo(sx, sy)
        }
        x += step
    }

    cache.pathRibbonB.reset()
    val startY = floor((camY - 120f) / step) * step
    val endY = camY + size.height + 120f
    var y = startY
    var firstB = true
    while (y <= endY) {
        val wx = sin(y * 0.0023f) * 250f + 150f
        val sx = wx - camX
        val sy = y - camY
        if (firstB) {
            cache.pathRibbonB.moveTo(sx, sy)
            firstB = false
        } else {
            cache.pathRibbonB.lineTo(sx, sy)
        }
        y += step
    }

    drawPath(cache.pathRibbonA, palette.pathEdge.copy(alpha = 0.24f), style = TRAIL_STROKE_OUTER)
    drawPath(cache.pathRibbonB, palette.pathEdge.copy(alpha = 0.24f), style = TRAIL_STROKE_OUTER)
    drawPath(cache.pathRibbonA, palette.pathCenter.copy(alpha = 0.36f), style = TRAIL_STROKE_MID)
    drawPath(cache.pathRibbonB, palette.pathCenter.copy(alpha = 0.36f), style = TRAIL_STROKE_MID)
    drawPath(cache.pathRibbonA, CreamSurface.copy(alpha = 0.16f), style = TRAIL_STROKE_INNER)
    drawPath(cache.pathRibbonB, CreamSurface.copy(alpha = 0.16f), style = TRAIL_STROKE_INNER)
}

/**
 * Ultra-fast hand-painted grass tuft layer.
 * Draws multi-tone capsule blades via hardware-friendly `drawLine(..., StrokeCap.Round)`
 * (eliminating expensive Skia quadratic-Bézier mega-path tessellation that caused emulator frame stalls).
 */
private fun DrawScope.drawInteractiveGrassField(
    biome: BiomeDef,
    palette: BiomeFoliagePalette,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    time: Float,
    cache: TerrainPathCache,
    highlandOnly: Boolean
) {
    val cellSize = GRASS_CELL_SIZE
    val startCol = floor((camX - 48f) / cellSize).toInt()
    val endCol = floor((camX + size.width + 48f) / cellSize).toInt()
    val startRow = floor((camY - 48f) / cellSize).toInt()
    val endRow = floor((camY + size.height + 80f) / cellSize).toInt()

    val heroX = state.playerX
    val heroY = state.playerY
    val heroGrounded = (state.playerZ - state.playerGroundZ) < 12f
    val heroSpeed = state.moveSpeedRatio
    val heroDirX = cos(state.facingAngle)
    val walkPhase = state.walkAnimTime * 2.3f
    val interactR = 132f
    val interactRSq = interactR * interactR

    val plateaus = cache.visiblePlateaus
    val rings = state.rings
    val isVolcano = biome.id == "volcano"
    val isDesert = biome.id == "desert"
    val isGraveyard = biome.id == "graveyard"

    val shadowCol = palette.bladeShadow.copy(alpha = 0.22f)
    val backCol = palette.bladeBack.copy(alpha = 0.78f)
    val midCol = palette.bladeMid.copy(alpha = 0.88f)
    val tipCol = palette.bladeHighlight.copy(alpha = 0.86f)

    for (r in startRow..endRow) {
        for (c in startCol..endCol) {
            val h = cellHash(c, r)
            val wx = c * cellSize + 18f + (h % 76)
            val wy = r * cellSize + 18f + ((h / 79) % 76)

            val elev = if (plateaus.isEmpty()) 0f else terrainElevationAt(wx, wy, plateaus)
            if (highlandOnly) {
                if (elev <= 0.5f) continue
            } else {
                if (elev > 0.5f) continue
            }

            val sx = wx - camX
            val sy = wy - elev - camY
            if (sx < -32f || sx > size.width + 32f || sy < -32f || sy > size.height + 32f) continue

            val trailDist = if (highlandOnly) 2f else trailDistanceFactor(wx, wy)

            // Pebbles & stepping stones along the dirt path
            if (trailDist < 0.85f) {
                if (h % 3 == 0) {
                    val stoneW = 7f + (h % 6)
                    val stoneH = stoneW * 0.62f
                    drawOval(
                        color = palette.pathEdge.copy(alpha = 0.44f),
                        topLeft = Offset(sx - stoneW * 0.5f, sy - stoneH * 0.5f + 2f),
                        size = Size(stoneW, stoneH)
                    )
                    drawOval(
                        color = palette.pathCenter.copy(alpha = 0.68f),
                        topLeft = Offset(sx - stoneW * 0.45f, sy - stoneH * 0.5f),
                        size = Size(stoneW * 0.88f, stoneH * 0.82f)
                    )
                }
                if (trailDist < 0.52f) continue
            }

            // Density control by biome
            if (isDesert || isVolcano) {
                if (h % 3 != 0) {
                    if (!highlandOnly && isDesert && h % 5 == 1) {
                        drawArc(
                            color = palette.shadeWash.copy(alpha = 0.24f),
                            startAngle = 200f,
                            sweepAngle = 140f,
                            useCenter = false,
                            topLeft = Offset(sx - 20f, sy - 6f),
                            size = Size(40f, 12f),
                            style = DESERT_DUNE_STROKE
                        )
                    } else if (!highlandOnly && isVolcano && h % 7 == 1) {
                        val glow = 0.35f + 0.32f * sin(time * 3.1f + (h % 13))
                        drawLine(
                            color = palette.bladeHighlight.copy(alpha = glow),
                            start = Offset(sx - 12f, sy - 4f),
                            end = Offset(sx + 13f, sy + 5f),
                            strokeWidth = 3.2f,
                            cap = StrokeCap.Round
                        )
                        drawLine(
                            color = GoldAccent.copy(alpha = glow * 0.65f),
                            start = Offset(sx - 6f, sy - 2f),
                            end = Offset(sx + 7f, sy + 3f),
                            strokeWidth = 1.4f,
                            cap = StrokeCap.Round
                        )
                    }
                    continue
                }
            } else {
                if (h % 7 == 0 || h % 7 == 4) {
                    if (!highlandOnly && isGraveyard && h % 14 == 0) {
                        drawOval(palette.bladeShadow.copy(alpha = 0.32f), Offset(sx - 12f, sy + 4f), Size(24f, 8f))
                        drawRoundRect(
                            palette.pathCenter.copy(alpha = 0.62f),
                            Offset(sx - 9f, sy - 15f),
                            Size(18f, 22f),
                            CornerRadius(9f, 9f)
                        )
                    } else if (!highlandOnly && biome.id == "forest" && h % 21 == 0) {
                        drawOval(palette.bladeShadow.copy(alpha = 0.24f), Offset(sx - 9f, sy + 1f), Size(18f, 7f))
                        drawOval(Color(0xFFB5B8A6).copy(alpha = 0.72f), Offset(sx - 8f, sy - 5f), Size(15f, 9f))
                        drawOval(palette.bladeMid.copy(alpha = 0.68f), Offset(sx + 2f, sy - 2f), Size(8f, 5f))
                    }
                    continue
                }
            }

            // Skip tufts directly in front of grounded hero feet — rendered in Foreground Wading Pass!
            val dxHero = wx - heroX
            val dyHero = wy - heroY
            val distSq = dxHero * dxHero + dyHero * dyHero
            if (heroGrounded && abs(elev - state.playerGroundZ) < 6f && dyHero in 4f..42f && abs(dxHero) < 54f) {
                continue
            }

            computeTuftPhysics(
                wx = wx,
                wy = wy,
                hash = h,
                time = time,
                dxHero = dxHero,
                dyHero = dyHero,
                distSq = distSq,
                interactR = interactR,
                interactRSq = interactRSq,
                heroSpeed = if (heroGrounded) heroSpeed else 0.15f,
                heroDirX = heroDirX,
                walkPhase = walkPhase,
                rings = rings,
                cache = cache
            )

            drawFastPainterlyTuft(
                sx = sx,
                sy = sy,
                hash = h,
                sway = cache.tmpSway,
                dipY = cache.tmpDipY,
                scale = if (isDesert || isVolcano) 0.86f else (0.90f + (h % 34) * 0.01f),
                shadowCol = shadowCol,
                backCol = backCol,
                midCol = midCol,
                tipCol = tipCol
            )

            // Occasional hand-painted wildflower accent on forest/graveyard tufts
            if (biome.id == "forest" && h % 5 == 0) {
                val fx = sx + ((h % 11) - 5) + cache.tmpSway * 0.55f
                val fy = sy - 8f - (h % 5) + cache.tmpDipY * 0.45f
                val petalColor = if (h % 10 == 0) palette.flowerB else palette.flowerA
                drawCircle(petalColor.copy(alpha = 0.90f), 3.3f, Offset(fx - 2.1f, fy))
                drawCircle(petalColor.copy(alpha = 0.90f), 3.3f, Offset(fx + 2.1f, fy))
                drawCircle(petalColor.copy(alpha = 0.90f), 3.1f, Offset(fx, fy - 2.0f))
                drawCircle(Color(0xFFFFB23F), 1.8f, Offset(fx, fy))
            } else if (isGraveyard && h % 9 == 0) {
                val fx = sx + cache.tmpSway * 0.5f
                val fy = sy - 9f + cache.tmpDipY * 0.4f
                drawCircle(palette.flowerA.copy(alpha = 0.24f), 6.0f, Offset(fx, fy))
                drawCircle(palette.flowerA.copy(alpha = 0.82f), 2.2f, Offset(fx, fy))
            }
        }
    }
}

/**
 * Tight per-plateau highland grass pass: scans ONLY the grid cells overlapping visible plateaus
 * instead of re-scanning the entire viewport a second time (~80% fewer grass loop checks).
 */
private fun DrawScope.drawHighlandPlateauGrass(
    biome: BiomeDef,
    palette: BiomeFoliagePalette,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    time: Float,
    cache: TerrainPathCache
) {
    val cellSize = GRASS_CELL_SIZE
    val heroX = state.playerX
    val heroY = state.playerY
    val heroGrounded = (state.playerZ - state.playerGroundZ) < 12f
    val heroSpeed = state.moveSpeedRatio
    val heroDirX = cos(state.facingAngle)
    val walkPhase = state.walkAnimTime * 2.3f
    val interactR = 132f
    val interactRSq = interactR * interactR
    val rings = state.rings
    val isVolcano = biome.id == "volcano"
    val isDesert = biome.id == "desert"
    val isGraveyard = biome.id == "graveyard"

    val shadowCol = palette.bladeShadow.copy(alpha = 0.22f)
    val backCol = palette.bladeBack.copy(alpha = 0.78f)
    val midCol = palette.bladeMid.copy(alpha = 0.88f)
    val tipCol = palette.bladeHighlight.copy(alpha = 0.86f)

    val plateaus = cache.visiblePlateaus
    for (pIdx in plateaus.indices) {
        val p = plateaus[pIdx]
        val startCol = floor((p.x - p.rx) / cellSize).toInt()
        val endCol = floor((p.x + p.rx) / cellSize).toInt()
        val startRow = floor((p.y - p.ry) / cellSize).toInt()
        val endRow = floor((p.y + p.ry) / cellSize).toInt()

        for (r in startRow..endRow) {
            for (c in startCol..endCol) {
                val h = cellHash(c, r)
                if (isDesert || isVolcano) {
                    if (h % 3 != 0) continue
                } else {
                    if (h % 7 == 0 || h % 7 == 4) continue
                }
                val wx = c * cellSize + 18f + (h % 76)
                val wy = r * cellSize + 18f + ((h / 79) % 76)
                if (!p.containsPoint(wx, wy)) continue

                val elev = p.elevation
                val sx = wx - camX
                val sy = wy - elev - camY
                if (sx < -32f || sx > size.width + 32f || sy < -32f || sy > size.height + 32f) continue

                val dxHero = wx - heroX
                val dyHero = wy - heroY
                val distSq = dxHero * dxHero + dyHero * dyHero
                if (heroGrounded && abs(elev - state.playerGroundZ) < 6f && dyHero in 4f..42f && abs(dxHero) < 54f) {
                    continue
                }

                computeTuftPhysics(
                    wx = wx,
                    wy = wy,
                    hash = h,
                    time = time,
                    dxHero = dxHero,
                    dyHero = dyHero,
                    distSq = distSq,
                    interactR = interactR,
                    interactRSq = interactRSq,
                    heroSpeed = if (heroGrounded) heroSpeed else 0.15f,
                    heroDirX = heroDirX,
                    walkPhase = walkPhase,
                    rings = rings,
                    cache = cache
                )

                drawFastPainterlyTuft(
                    sx = sx,
                    sy = sy,
                    hash = h,
                    sway = cache.tmpSway,
                    dipY = cache.tmpDipY,
                    scale = if (isDesert || isVolcano) 0.86f else (0.90f + (h % 34) * 0.01f),
                    shadowCol = shadowCol,
                    backCol = backCol,
                    midCol = midCol,
                    tipCol = tipCol
                )

                if (biome.id == "forest" && h % 5 == 0) {
                    val fx = sx + ((h % 11) - 5) + cache.tmpSway * 0.55f
                    val fy = sy - 8f - (h % 5) + cache.tmpDipY * 0.45f
                    val petalColor = if (h % 10 == 0) palette.flowerB else palette.flowerA
                    drawCircle(petalColor.copy(alpha = 0.90f), 3.3f, Offset(fx - 2.1f, fy))
                    drawCircle(petalColor.copy(alpha = 0.90f), 3.3f, Offset(fx + 2.1f, fy))
                    drawCircle(petalColor.copy(alpha = 0.90f), 3.1f, Offset(fx, fy - 2.0f))
                    drawCircle(Color(0xFFFFB23F), 1.8f, Offset(fx, fy))
                } else if (isGraveyard && h % 9 == 0) {
                    val fx = sx + cache.tmpSway * 0.5f
                    val fy = sy - 9f + cache.tmpDipY * 0.4f
                    drawCircle(palette.flowerA.copy(alpha = 0.24f), 6.0f, Offset(fx, fy))
                    drawCircle(palette.flowerA.copy(alpha = 0.82f), 2.2f, Offset(fx, fy))
                }
            }
        }
    }
}

/**
 * Foreground Depth Pass: draws the 1-4 tall grass tufts sitting directly in front of the
 * grounded hero's feet AFTER the hero sprite is drawn, creating genuine 2.5D wading-through-grass depth.
 * Automatically skipped while jumping in mid-air.
 */
fun DrawScope.drawForegroundHeroGrass(
    biome: BiomeDef,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: TerrainPathCache
) {
    // Only wade through grass when close to the ground!
    if (state.playerZ - state.playerGroundZ >= 12f) return

    val palette = paletteForBiome(biome)
    val cellSize = GRASS_CELL_SIZE
    val heroX = state.playerX
    val heroY = state.playerY
    val startCol = floor((heroX - 60f) / cellSize).toInt()
    val endCol = floor((heroX + 60f) / cellSize).toInt()
    val startRow = floor((heroY - 8f) / cellSize).toInt()
    val endRow = floor((heroY + 52f) / cellSize).toInt()

    val heroSpeed = state.moveSpeedRatio
    val heroDirX = cos(state.facingAngle)
    val walkPhase = state.walkAnimTime * 2.3f
    val interactR = 132f
    val interactRSq = interactR * interactR
    val isDesert = biome.id == "desert"
    val isVolcano = biome.id == "volcano"

    val shadowCol = Color.Transparent
    val backCol = palette.bladeBack.copy(alpha = 0.84f)
    val midCol = palette.bladeMid.copy(alpha = 0.92f)
    val tipCol = palette.bladeHighlight.copy(alpha = 0.92f)

    for (r in startRow..endRow) {
        for (c in startCol..endCol) {
            val h = cellHash(c, r)
            if (isDesert || isVolcano) {
                if (h % 3 != 0) continue
            } else {
                if (h % 7 == 0 || h % 7 == 4) continue
            }
            val wx = c * cellSize + 18f + (h % 76)
            val wy = r * cellSize + 18f + ((h / 79) % 76)
            val dxHero = wx - heroX
            val dyHero = wy - heroY
            if (dyHero !in 4f..42f || abs(dxHero) >= 54f) continue

            val elev = terrainElevationAt(wx, wy, state.terrainPlateaus)
            if (abs(elev - state.playerGroundZ) >= 6f) continue
            if (elev <= 0.5f && trailDistanceFactor(wx, wy) < 0.52f) continue

            val distSq = dxHero * dxHero + dyHero * dyHero
            computeTuftPhysics(
                wx = wx,
                wy = wy,
                hash = h,
                time = state.elapsedSec,
                dxHero = dxHero,
                dyHero = dyHero,
                distSq = distSq,
                interactR = interactR,
                interactRSq = interactRSq,
                heroSpeed = heroSpeed,
                heroDirX = heroDirX,
                walkPhase = walkPhase,
                rings = state.rings,
                cache = cache
            )

            drawFastPainterlyTuft(
                sx = wx - camX,
                sy = wy - elev - camY,
                hash = h,
                sway = cache.tmpSway,
                dipY = cache.tmpDipY,
                scale = if (isDesert || isVolcano) 0.88f else (0.94f + (h % 28) * 0.01f),
                shadowCol = shadowCol,
                backCol = backCol,
                midCol = midCol,
                tipCol = tipCol
            )
        }
    }
}

private inline fun computeTuftPhysics(
    wx: Float,
    wy: Float,
    hash: Int,
    time: Float,
    dxHero: Float,
    dyHero: Float,
    distSq: Float,
    interactR: Float,
    interactRSq: Float,
    heroSpeed: Float,
    heroDirX: Float,
    walkPhase: Float,
    rings: List<ExpandingRingSnapshot>,
    cache: TerrainPathCache
) {
    val wind = sin(time * 2.15f + wx * 0.0085f + wy * 0.0042f) * 4.0f +
        sin(time * 4.4f + (hash % 23)) * 1.15f

    var reactiveSway = 0f
    var dipY = 0f

    if (distSq < interactRSq) {
        val dist = sqrt(distSq).coerceAtLeast(1f)
        val prox = 1f - (dist / interactR)
        val falloff = prox * prox
        val partPush = (dxHero / dist) * falloff * (9.5f + heroSpeed * 7.5f)
        val strideRustle = heroSpeed * falloff * (heroDirX * 7.5f + sin(walkPhase + (hash % 11)) * 6.0f)
        reactiveSway += partPush + strideRustle
        dipY += falloff * (3.5f + heroSpeed * 5.0f)
    }

    for (i in rings.indices) {
        val ring = rings[i]
        val rdx = wx - ring.x
        val rdy = wy - ring.y
        val rDist = sqrt(rdx * rdx + rdy * rdy).coerceAtLeast(1f)
        val band = abs(rDist - ring.radius)
        if (band < 56f) {
            val wave = (1f - band / 56f) * ring.alpha
            reactiveSway += (rdx / rDist) * wave * 14f
            dipY += wave * 4f
        }
    }

    cache.tmpSway = wind + reactiveSway
    cache.tmpDipY = dipY
}

/**
 * Draws a lush 5-blade hand-painted grass tuft using fast rounded capsule strokes
 * (no quadratic Bézier triangulation -> >15x faster on Android Emulator / Skia).
 */
private fun DrawScope.drawFastPainterlyTuft(
    sx: Float,
    sy: Float,
    hash: Int,
    sway: Float,
    dipY: Float,
    scale: Float,
    shadowCol: Color,
    backCol: Color,
    midCol: Color,
    tipCol: Color
) {
    if (shadowCol.alpha > 0.01f) {
        drawOval(
            color = shadowCol,
            topLeft = Offset(sx - 11.5f * scale, sy - 2.5f * scale),
            size = Size(23f * scale, 7.2f * scale)
        )
    }

    // Back outer splayed blades (deeper shadow green)
    drawLine(
        color = backCol,
        start = Offset(sx - 4.8f * scale, sy + 0.5f),
        end = Offset(sx - (11.0f + (hash % 4)) * scale + sway * 0.90f, sy - (13.0f + (hash % 5)) * scale + dipY),
        strokeWidth = 3.8f * scale,
        cap = StrokeCap.Round
    )
    drawLine(
        color = backCol,
        start = Offset(sx + 4.8f * scale, sy + 0.5f),
        end = Offset(sx + (10.5f + ((hash / 5) % 4)) * scale + sway * 0.86f, sy - (12.2f + ((hash / 3) % 5)) * scale + dipY),
        strokeWidth = 3.7f * scale,
        cap = StrokeCap.Round
    )

    // Mid-tone painterly blades
    drawLine(
        color = midCol,
        start = Offset(sx - 2.0f * scale, sy + 1.0f),
        end = Offset(sx - (4.8f + ((hash / 7) % 3)) * scale + sway * 1.08f, sy - (17.5f + ((hash / 11) % 5)) * scale + dipY),
        strokeWidth = 4.0f * scale,
        cap = StrokeCap.Round
    )
    drawLine(
        color = midCol,
        start = Offset(sx + 2.2f * scale, sy + 1.0f),
        end = Offset(sx + (5.2f + ((hash / 13) % 3)) * scale + sway * 1.04f, sy - (16.2f + ((hash / 17) % 5)) * scale + dipY),
        strokeWidth = 3.8f * scale,
        cap = StrokeCap.Round
    )

    // Tall sunlit center highlight blade
    val tipBias = ((hash % 5) - 2) * 1.6f * scale
    drawLine(
        color = tipCol,
        start = Offset(sx + ((hash % 3) - 1) * 1.1f * scale, sy + 1.0f),
        end = Offset(sx + tipBias + sway * 1.24f, sy - (20.0f + ((hash / 19) % 5)) * scale + dipY),
        strokeWidth = 3.2f * scale,
        cap = StrokeCap.Round
    )
}

/**
 * Draws a 2.5D sight-line-occluding Tall Tree or Sculpted Mega-Boulder in the Y-sorted world pass.
 * When the hero walks behind/under a tree canopy or tall rock, the obstacle smoothly fades to
 * translucent so the player retains full combat readability while feeling genuine 2.5D occlusion.
 */
fun DrawScope.draw25DOccludingObstacle(
    biome: BiomeDef,
    obs: TerrainObstacle,
    state: BattleRenderState,
    camX: Float,
    camY: Float,
    cache: TerrainPathCache
) {
    val sx = obs.x - camX
    val sy = obs.y - obs.groundZ - camY
    val cullPad = obs.canopyRadius + obs.height + 40f
    if (sx < -cullPad || sx > size.width + cullPad || sy < -cullPad || sy > size.height + cullPad) {
        return
    }

    val palette = paletteForBiome(biome)

    // Compute smooth sight-line translucency when hero walks behind this obstacle
    val heroBehindY = state.playerY < obs.y + 4f
    val dxHero = abs(state.playerX - obs.x)
    val dyBehind = obs.y - state.playerY
    val occludeAlpha = if (obs.kind == TerrainObstacleKind.TALL_TREE) {
        if (heroBehindY && dxHero < obs.canopyRadius + 24f && dyBehind < obs.height + obs.canopyRadius * 0.72f) {
            val horizFactor = (1f - dxHero / (obs.canopyRadius + 24f)).coerceIn(0f, 1f)
            val vertFactor = (1f - (dyBehind / (obs.height + obs.canopyRadius * 0.72f)).coerceIn(0f, 1f))
            val overlap = (horizFactor * 0.75f + vertFactor * 0.25f).coerceIn(0f, 1f)
            1f - overlap * 0.56f
        } else {
            1f
        }
    } else {
        if (heroBehindY && dxHero < obs.collisionRadius + 22f && dyBehind < obs.height + 24f) {
            0.58f
        } else {
            1f
        }
    }

    when (obs.kind) {
        TerrainObstacleKind.BOULDER -> draw25DMegaBoulder(
            biome = biome,
            obs = obs,
            sx = sx,
            sy = sy,
            alpha = occludeAlpha,
            palette = palette,
            cache = cache
        )
        TerrainObstacleKind.TALL_TREE -> draw25DTallTree(
            biome = biome,
            obs = obs,
            sx = sx,
            sy = sy,
            time = state.elapsedSec,
            canopyAlpha = occludeAlpha,
            palette = palette,
            cache = cache
        )
    }
}

private fun DrawScope.draw25DMegaBoulder(
    biome: BiomeDef,
    obs: TerrainObstacle,
    sx: Float,
    sy: Float,
    alpha: Float,
    palette: BiomeFoliagePalette,
    cache: TerrainPathCache
) {
    val r = obs.collisionRadius
    val h = obs.height
    val skew = when (obs.variant) {
        0 -> -0.10f
        1 -> 0.12f
        else -> 0.02f
    }

    // 1. Ground cast shadow (always anchored firmly on the ground)
    drawOval(
        color = Color.Black.copy(alpha = 0.26f),
        topLeft = Offset(sx - r * 1.12f + 10f, sy - r * 0.34f + 8f),
        size = Size(r * 2.26f, r * 0.96f)
    )

    // 2. Sculpted 6-vertex low-poly 2.5D boulder silhouette
    val body = cache.shapeScratch
    body.reset()
    body.moveTo(sx - r * 1.04f, sy + r * 0.16f)
    body.lineTo(sx - r * 0.88f, sy - h * 0.56f)
    body.lineTo(sx - r * (0.28f - skew), sy - h * 1.02f)
    body.lineTo(sx + r * (0.48f + skew), sy - h * 0.88f)
    body.lineTo(sx + r * 1.06f, sy - h * 0.24f)
    body.lineTo(sx + r * 0.92f, sy + r * 0.28f)
    body.lineTo(sx - r * 0.18f, sy + r * 0.38f)
    body.close()

    drawPath(body, palette.rockMid.copy(alpha = alpha))

    // 3. Deep right/south shadow facet for strong 2.5D volume
    val shadowFacet = cache.facetScratch
    shadowFacet.reset()
    shadowFacet.moveTo(sx + r * 0.06f, sy - h * 0.34f)
    shadowFacet.lineTo(sx + r * (0.48f + skew), sy - h * 0.88f)
    shadowFacet.lineTo(sx + r * 1.06f, sy - h * 0.24f)
    shadowFacet.lineTo(sx + r * 0.92f, sy + r * 0.28f)
    shadowFacet.lineTo(sx - r * 0.18f, sy + r * 0.38f)
    shadowFacet.close()
    drawPath(shadowFacet, palette.rockShadow.copy(alpha = alpha * 0.88f))

    // 4. Sunlit upper-left bevel facet
    val lightFacet = cache.facetScratch
    lightFacet.reset()
    lightFacet.moveTo(sx - r * 0.84f, sy - h * 0.52f)
    lightFacet.lineTo(sx - r * (0.28f - skew), sy - h * 0.98f)
    lightFacet.lineTo(sx + r * (0.42f + skew), sy - h * 0.84f)
    lightFacet.lineTo(sx + r * 0.02f, sy - h * 0.34f)
    lightFacet.lineTo(sx - r * 0.68f, sy - h * 0.26f)
    lightFacet.close()
    drawPath(lightFacet, palette.rockLight.copy(alpha = alpha * 0.92f))

    // 5. Biome signature detail (moss cap, glowing runes, sandstone strata, or lava vein)
    when (biome.id) {
        "forest" -> {
            drawOval(
                color = palette.rockAccent.copy(alpha = alpha * 0.90f),
                topLeft = Offset(sx - r * 0.62f, sy - h * 0.94f),
                size = Size(r * 0.98f, h * 0.34f)
            )
            drawOval(
                color = palette.bladeHighlight.copy(alpha = alpha * 0.72f),
                topLeft = Offset(sx - r * 0.46f, sy - h * 0.90f),
                size = Size(r * 0.50f, h * 0.16f)
            )
        }
        "volcano" -> {
            drawLine(
                color = palette.rockAccent.copy(alpha = alpha * 0.92f),
                start = Offset(sx - r * 0.42f, sy - h * 0.64f),
                end = Offset(sx + r * 0.16f, sy - h * 0.18f),
                strokeWidth = 3.2f,
                cap = StrokeCap.Round
            )
            drawLine(
                color = GoldAccent.copy(alpha = alpha * 0.80f),
                start = Offset(sx - r * 0.28f, sy - h * 0.50f),
                end = Offset(sx + r * 0.06f, sy - h * 0.24f),
                strokeWidth = 1.5f,
                cap = StrokeCap.Round
            )
        }
        "graveyard" -> {
            drawCircle(
                color = palette.rockAccent.copy(alpha = alpha * 0.32f),
                radius = 10f,
                center = Offset(sx - r * 0.12f, sy - h * 0.48f)
            )
            drawLine(
                color = palette.rockAccent.copy(alpha = alpha * 0.82f),
                start = Offset(sx - r * 0.12f, sy - h * 0.64f),
                end = Offset(sx - r * 0.12f, sy - h * 0.32f),
                strokeWidth = 2.4f,
                cap = StrokeCap.Round
            )
            drawLine(
                color = palette.rockAccent.copy(alpha = alpha * 0.82f),
                start = Offset(sx - r * 0.26f, sy - h * 0.52f),
                end = Offset(sx + r * 0.02f, sy - h * 0.52f),
                strokeWidth = 2.2f,
                cap = StrokeCap.Round
            )
        }
        else -> { // desert sandstone strata lines
            drawLine(
                color = palette.rockShadow.copy(alpha = alpha * 0.48f),
                start = Offset(sx - r * 0.72f, sy - h * 0.32f),
                end = Offset(sx + r * 0.66f, sy - h * 0.22f),
                strokeWidth = 2.4f,
                cap = StrokeCap.Round
            )
        }
    }

    // 6. Crisp cel-shaded outline
    drawPath(body, EspressoDark.copy(alpha = alpha * 0.86f), style = BOULDER_OUTLINE_STROKE)
}

private fun DrawScope.draw25DTallTree(
    biome: BiomeDef,
    obs: TerrainObstacle,
    sx: Float,
    sy: Float,
    time: Float,
    canopyAlpha: Float,
    palette: BiomeFoliagePalette,
    cache: TerrainPathCache
) {
    val trunkR = obs.collisionRadius * 0.62f
    val canopyR = obs.canopyRadius
    val height = obs.height
    val sway = sin(time * 1.85f + obs.id * 1.37f) * 3.8f

    // 1. Wide grounded canopy shadow oval (always crisp beneath the tree)
    drawOval(
        color = Color.Black.copy(alpha = 0.24f),
        topLeft = Offset(sx - canopyR * 0.94f + 12f, sy - canopyR * 0.28f + 10f),
        size = Size(canopyR * 1.94f, canopyR * 0.78f)
    )

    // 2. Sculpted 2.5D Tree Trunk with Root Flare (solid at base, slight fade if hero is right behind)
    val trunkAlpha = 0.65f + 0.35f * canopyAlpha
    val trunkTopY = sy - height * 0.62f
    val trunk = cache.shapeScratch
    trunk.reset()
    trunk.moveTo(sx - trunkR * 1.35f, sy + trunkR * 0.45f)
    trunk.lineTo(sx - trunkR * 0.74f, trunkTopY)
    trunk.lineTo(sx + trunkR * 0.74f, trunkTopY)
    trunk.lineTo(sx + trunkR * 1.38f, sy + trunkR * 0.45f)
    trunk.lineTo(sx + trunkR * 0.35f, sy + trunkR * 0.62f)
    trunk.lineTo(sx - trunkR * 0.35f, sy + trunkR * 0.62f)
    trunk.close()

    drawPath(trunk, palette.trunkDark.copy(alpha = trunkAlpha))
    // Left sunlit bark strip
    drawLine(
        color = palette.trunkLight.copy(alpha = trunkAlpha * 0.88f),
        start = Offset(sx - trunkR * 0.42f, sy + trunkR * 0.22f),
        end = Offset(sx - trunkR * 0.26f, trunkTopY + 4f),
        strokeWidth = trunkR * 0.55f,
        cap = StrokeCap.Round
    )
    if (biome.id == "volcano") {
        // Glowing magma fissure along charred volcano trunk
        drawLine(
            color = palette.rockAccent.copy(alpha = trunkAlpha * 0.85f),
            start = Offset(sx + 1f, sy - 6f),
            end = Offset(sx - 2f, trunkTopY + 10f),
            strokeWidth = 2.6f,
            cap = StrokeCap.Round
        )
    }
    drawPath(trunk, EspressoDark.copy(alpha = trunkAlpha * 0.85f), style = TRUNK_OUTLINE_STROKE)

    // 3. Multi-Tiered Wind-Swaying 2.5D Canopy (occludes sight-lines, smoothly turns translucent when hero passes behind)
    val crownX = sx + sway
    val crownY = sy - height * 0.82f

    if (biome.id == "desert") {
        // Oasis Palm Crown: radiating curved fronds + golden date cluster
        val frondCount = 6
        for (f in 0 until frondCount) {
            val angle = f * (2f * PI.toFloat() / frondCount) + 0.35f + sway * 0.015f
            val tipX = crownX + cos(angle) * canopyR * 1.05f
            val tipY = crownY + sin(angle) * canopyR * 0.62f + 10f
            drawLine(
                color = palette.bladeBack.copy(alpha = canopyAlpha),
                start = Offset(crownX, crownY),
                end = Offset(tipX, tipY),
                strokeWidth = 14f,
                cap = StrokeCap.Round
            )
            drawLine(
                color = palette.bladeHighlight.copy(alpha = canopyAlpha * 0.90f),
                start = Offset(crownX, crownY - 2f),
                end = Offset(crownX + cos(angle) * canopyR * 0.72f, crownY + sin(angle) * canopyR * 0.40f + 2f),
                strokeWidth = 6f,
                cap = StrokeCap.Round
            )
        }
        drawCircle(GoldAccent.copy(alpha = canopyAlpha), 8f, Offset(crownX - 5f, crownY + 8f))
        drawCircle(GoldAccent.copy(alpha = canopyAlpha), 7f, Offset(crownX + 6f, crownY + 10f))
        drawCircle(EspressoDark.copy(alpha = canopyAlpha * 0.75f), 11f, Offset(crownX, crownY), style = PALM_CORE_STROKE)
    } else {
        // Stylized 3-tier PokéBonk puffy tree canopy (Shadow Base -> Mid Clusters -> Sunlit Top)
        val leftX = crownX - canopyR * 0.44f
        val rightX = crownX + canopyR * 0.44f
        val sideY = crownY + canopyR * 0.16f

        // Tier 1: Deep underside canopy shadow puffs
        drawCircle(palette.borderDark.copy(alpha = canopyAlpha), canopyR * 0.56f, Offset(leftX, sideY + 6f))
        drawCircle(palette.borderDark.copy(alpha = canopyAlpha), canopyR * 0.54f, Offset(rightX, sideY + 6f))
        drawCircle(palette.borderDark.copy(alpha = canopyAlpha), canopyR * 0.68f, Offset(crownX, crownY + 8f))

        // Tier 2: Rich mid-tone foliage clusters
        drawCircle(palette.borderMid.copy(alpha = canopyAlpha), canopyR * 0.52f, Offset(leftX - 2f, sideY - 2f))
        drawCircle(palette.borderMid.copy(alpha = canopyAlpha), canopyR * 0.50f, Offset(rightX + 2f, sideY - 2f))
        drawCircle(palette.borderMid.copy(alpha = canopyAlpha), canopyR * 0.64f, Offset(crownX, crownY - 4f))

        // Tier 3: Sunlit upper-left crown puffs
        drawCircle(palette.borderLight.copy(alpha = canopyAlpha * 0.92f), canopyR * 0.40f, Offset(crownX - canopyR * 0.18f, crownY - canopyR * 0.24f))
        drawCircle(palette.borderLight.copy(alpha = canopyAlpha * 0.85f), canopyR * 0.26f, Offset(leftX - 4f, sideY - canopyR * 0.16f))
        drawCircle(palette.sunlitWash.copy(alpha = canopyAlpha * 0.42f), canopyR * 0.22f, Offset(crownX - canopyR * 0.24f, crownY - canopyR * 0.34f))

        // Biome-specific canopy garnish (blossoms in forest, glowing wisps in graveyard, embers in volcano)
        if (biome.id == "forest" && obs.variant != 2) {
            val dotCol = if (obs.variant == 0) palette.flowerB else palette.flowerA
            drawCircle(dotCol.copy(alpha = canopyAlpha * 0.92f), 4.5f, Offset(crownX - canopyR * 0.32f, crownY + 4f))
            drawCircle(dotCol.copy(alpha = canopyAlpha * 0.92f), 4.0f, Offset(crownX + canopyR * 0.28f, crownY - 12f))
            drawCircle(dotCol.copy(alpha = canopyAlpha * 0.92f), 3.6f, Offset(crownX + 4f, crownY + canopyR * 0.18f))
        } else if (biome.id == "graveyard") {
            drawCircle(palette.flowerA.copy(alpha = canopyAlpha * 0.72f), 3.8f, Offset(crownX - canopyR * 0.24f, crownY + 6f))
            drawCircle(palette.flowerB.copy(alpha = canopyAlpha * 0.72f), 3.4f, Offset(crownX + canopyR * 0.30f, crownY - 8f))
        } else if (biome.id == "volcano") {
            drawCircle(palette.flowerA.copy(alpha = canopyAlpha * 0.88f), 4.8f, Offset(crownX - canopyR * 0.18f, crownY + 4f))
            drawCircle(palette.flowerB.copy(alpha = canopyAlpha * 0.85f), 4.2f, Offset(crownX + canopyR * 0.22f, crownY - 10f))
        }

        // Crisp stylized cel-shaded crown contour
        val outlineCol = EspressoDark.copy(alpha = canopyAlpha * 0.74f)
        drawCircle(outlineCol, canopyR * 0.56f, Offset(leftX, sideY + 6f), style = CANOPY_OUTLINE_26)
        drawCircle(outlineCol, canopyR * 0.54f, Offset(rightX, sideY + 6f), style = CANOPY_OUTLINE_26)
        drawCircle(outlineCol, canopyR * 0.68f, Offset(crownX, crownY + 4f), style = CANOPY_OUTLINE_28)
    }
}

/**
 * Renders a stylized PokéBonk-inspired perimeter foliage / cliff wall around the
 * arena bounds (-1450..+1450), only drawing bushes/rocks visible in the viewport.
 */
private fun DrawScope.drawStylizedArenaBorder(
    palette: BiomeFoliagePalette,
    camX: Float,
    camY: Float,
    time: Float
) {
    val bHalf = 1450f
    val tl = Offset(-bHalf - camX, -bHalf - camY)
    drawRect(
        color = EspressoDark.copy(alpha = 0.28f),
        topLeft = tl,
        size = Size(bHalf * 2f, bHalf * 2f),
        style = ARENA_BORDER_OUTER
    )
    drawRect(
        color = CreamSurface.copy(alpha = 0.38f),
        topLeft = tl,
        size = Size(bHalf * 2f, bHalf * 2f),
        style = ARENA_BORDER_INNER
    )

    val bushStep = 84f
    fun drawPerimeterCanopy(wx: Float, wy: Float, idx: Int) {
        val sx = wx - camX
        val sy = wy - camY
        if (sx < -90f || sx > size.width + 90f || sy < -90f || sy > size.height + 90f) return
        val sway = sin(time * 1.8f + idx * 0.9f) * 2.2f
        val r = 34f + (abs(idx * 17) % 16)
        drawCircle(palette.bladeShadow.copy(alpha = 0.32f), r * 1.05f, Offset(sx + 4f, sy + 10f))
        drawCircle(palette.borderDark, r, Offset(sx + sway * 0.4f, sy + 3f))
        drawCircle(palette.borderMid, r * 0.84f, Offset(sx - r * 0.14f + sway * 0.7f, sy - r * 0.10f))
        drawCircle(palette.borderLight.copy(alpha = 0.85f), r * 0.46f, Offset(sx - r * 0.26f + sway, sy - r * 0.26f))
        drawCircle(EspressoDark.copy(alpha = 0.55f), r, Offset(sx + sway * 0.4f, sy + 3f), style = PERIMETER_BUSH_STROKE)
    }

    val xStart = (floor((camX - 100f) / bushStep).toInt() * bushStep).coerceAtLeast(-bHalf)
    val xEnd = (camX + size.width + 100f).coerceAtMost(bHalf)
    if ((-bHalf - camY) in -120f..(size.height + 120f)) {
        var x = xStart
        while (x <= xEnd) {
            drawPerimeterCanopy(x, -bHalf - 16f, (x / bushStep).toInt())
            x += bushStep
        }
    }
    if ((bHalf - camY) in -120f..(size.height + 120f)) {
        var x = xStart
        while (x <= xEnd) {
            drawPerimeterCanopy(x, bHalf + 18f, (x / bushStep).toInt() + 101)
            x += bushStep
        }
    }

    val yStart = (floor((camY - 100f) / bushStep).toInt() * bushStep).coerceAtLeast(-bHalf)
    val yEnd = (camY + size.height + 100f).coerceAtMost(bHalf)
    if ((-bHalf - camX) in -120f..(size.width + 120f)) {
        var y = yStart
        while (y <= yEnd) {
            drawPerimeterCanopy(-bHalf - 16f, y, (y / bushStep).toInt() + 203)
            y += bushStep
        }
    }
    if ((bHalf - camX) in -120f..(size.width + 120f)) {
        var y = yStart
        while (y <= yEnd) {
            drawPerimeterCanopy(bHalf + 16f, y, (y / bushStep).toInt() + 307)
            y += bushStep
        }
    }
}
