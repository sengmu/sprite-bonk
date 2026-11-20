package com.example.game.engine

import kotlin.math.abs
import kotlin.math.hypot

/**
 * Distinct multi-phase attack telegraphs executed by Guardian Bosses.
 */
enum class BossAttackKind {
    NONE,
    RING_SLAM,      // Phase 1+: Expanding circular seismic slam
    LINE_CHARGE,    // Phase 2+: Telegraphed high-speed directional charge (leaves Boss staggered on miss!)
    RADIAL_BURST,   // Phase 2+: 8-12 projectile spiral/ring barrage
    SUMMON_GUARD    // Phase 3: Summons biome elite/escort guards + shockwave
}

/**
 * Biome-exclusive ecological arena zones that reward tactical positioning and 2.5D mobility.
 */
enum class BiomeZoneKind(
    val titleZh: String,
    val effectHintZh: String
) {
    FOREST_BLOOM_RING("风花灵阵", "移速 +18% · 持续回血"),
    GRAVEYARD_SOUL_LANTERN("幽魂灯柱", "必杀充能加速 · 弱化范围内敌怪"),
    DESERT_QUICKSAND("流沙漩涡", "牵引减速敌我 · 跳跃冲刺可脱困"),
    VOLCANO_LAVA_VENT("熔岩喷口", "间歇预警喷发 · 高额范围灼伤")
}

/**
 * Lifecycle state for periodic zones like Volcano Lava Vents.
 */
enum class BiomeZonePhase {
    ACTIVE,     // Always-on ecological aura (Forest bloom, Graveyard lantern, Desert quicksand)
    DORMANT,    // Volcano vent cooling down
    WARNING,    // Volcano vent glowing & cracking before eruption
    ERUPTING    // Volcano vent actively dealing high AoE fire damage
}

/**
 * Static anchor definition generated per biome in [ArenaTerrainLayout].
 */
data class BiomeEcoZone(
    val id: Int,
    val kind: BiomeZoneKind,
    val x: Float,
    val y: Float,
    val radius: Float,
    val cycleOffsetSec: Float = 0f
)

/**
 * Per-frame renderable snapshot of an ecological arena zone.
 */
data class BiomeZoneSnapshot(
    val id: Int,
    val kind: BiomeZoneKind,
    val x: Float,
    val y: Float,
    val radius: Float,
    val phase: BiomeZonePhase,
    val phaseProgress: Float,
    val groundZ: Float = 0f
)

object BiomeEcoRules {
    const val VOLCANO_DORMANT_SEC = 4.6f
    const val VOLCANO_WARNING_SEC = 2.1f
    const val VOLCANO_ERUPT_SEC = 2.5f
    const val VOLCANO_CYCLE_SEC = VOLCANO_DORMANT_SEC + VOLCANO_WARNING_SEC + VOLCANO_ERUPT_SEC

    fun zoneKindForBiome(biomeId: String): BiomeZoneKind = when (biomeId) {
        "forest" -> BiomeZoneKind.FOREST_BLOOM_RING
        "graveyard" -> BiomeZoneKind.GRAVEYARD_SOUL_LANTERN
        "desert" -> BiomeZoneKind.DESERT_QUICKSAND
        else -> BiomeZoneKind.VOLCANO_LAVA_VENT
    }

    /**
     * Evaluates deterministic periodic phase & normalized progress (0..1) for a [BiomeEcoZone].
     */
    fun evaluatePhase(zone: BiomeEcoZone, elapsedSec: Float): Pair<BiomeZonePhase, Float> {
        if (zone.kind != BiomeZoneKind.VOLCANO_LAVA_VENT) {
            return BiomeZonePhase.ACTIVE to ((elapsedSec * 0.45f + zone.cycleOffsetSec) % 1f)
        }
        val t = ((elapsedSec + zone.cycleOffsetSec) % VOLCANO_CYCLE_SEC + VOLCANO_CYCLE_SEC) % VOLCANO_CYCLE_SEC
        return when {
            t < VOLCANO_DORMANT_SEC -> BiomeZonePhase.DORMANT to (t / VOLCANO_DORMANT_SEC)
            t < VOLCANO_DORMANT_SEC + VOLCANO_WARNING_SEC ->
                BiomeZonePhase.WARNING to ((t - VOLCANO_DORMANT_SEC) / VOLCANO_WARNING_SEC)
            else ->
                BiomeZonePhase.ERUPTING to ((t - VOLCANO_DORMANT_SEC - VOLCANO_WARNING_SEC) / VOLCANO_ERUPT_SEC)
        }
    }

    fun generateZones(
        biomeId: String,
        arenaHalfSize: Float,
        obstacles: List<TerrainObstacle>
    ): List<BiomeEcoZone> {
        val kind = zoneKindForBiome(biomeId)
        val radius = when (kind) {
            BiomeZoneKind.FOREST_BLOOM_RING -> 108f
            BiomeZoneKind.GRAVEYARD_SOUL_LANTERN -> 122f
            BiomeZoneKind.DESERT_QUICKSAND -> 126f
            BiomeZoneKind.VOLCANO_LAVA_VENT -> 102f
        }
        // Balanced ring of 6 iconic landmarks: 2 near spawn (immediately discoverable) + 4 mid-arena
        val candidateAnchors = listOf(
            -190f to 240f,
            260f to -195f,
            -640f to -420f,
            660f to 430f,
            -580f to 580f,
            590f to -590f
        )
        val result = mutableListOf<BiomeEcoZone>()
        var nextId = 1
        val limit = arenaHalfSize - 190f
        candidateAnchors.forEachIndexed { idx, (ax, ay) ->
            var zx = ax.coerceIn(-limit, limit)
            var zy = ay.coerceIn(-limit, limit)
            // Nudge slightly if overlapping a boulder/tree base so the zone center stays walkable
            for (o in obstacles) {
                val dx = zx - o.x
                val dy = zy - o.y
                val d = hypot(dx, dy)
                val minClear = o.collisionRadius + 46f
                if (d < minClear) {
                    val safeD = d.coerceAtLeast(1f)
                    zx = (o.x + (dx / safeD) * minClear).coerceIn(-limit, limit)
                    zy = (o.y + (dy / safeD) * minClear).coerceIn(-limit, limit)
                }
            }
            if (abs(zx) <= limit && abs(zy) <= limit) {
                result.add(
                    BiomeEcoZone(
                        id = nextId++,
                        kind = kind,
                        x = zx,
                        y = zy,
                        radius = radius,
                        cycleOffsetSec = idx * 1.75f
                    )
                )
            }
        }
        return result
    }
}
