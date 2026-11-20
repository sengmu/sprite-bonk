package com.example.game.engine

import com.example.game.movement.MapObstacle
import com.example.game.movement.MapObstacleKind
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * A jumpable 2.5D raised terrain plateau / ledge in the battlefield.
 * Players can either walk up its sloped [rampSide] or Jump/Dash up any cliff edge.
 */
data class TerrainPlateau(
    val id: Int,
    val x: Float,
    val y: Float,
    val rx: Float,
    val ry: Float,
    val elevation: Float = 30f,
    /** 0 = South ramp, 1 = West ramp, 2 = East ramp */
    val rampSide: Int = 0
) {
    fun normalizedDistSq(px: Float, py: Float): Float {
        val nx = (px - x) / rx
        val ny = (py - y) / ry
        return nx * nx + ny * ny
    }

    fun containsPoint(px: Float, py: Float, margin: Float = 0f): Boolean {
        val effRx = (rx + margin).coerceAtLeast(10f)
        val effRy = (ry + margin).coerceAtLeast(10f)
        val nx = (px - x) / effRx
        val ny = (py - y) / effRy
        return nx * nx + ny * ny <= 1f
    }

    /**
     * Returns true when (px, py) lies along the gentle walkable slope ramp of this plateau.
     */
    fun isInRampZone(px: Float, py: Float): Boolean {
        val dx = px - x
        val dy = py - y
        val angle = atan2(dy / ry, dx / rx) // -PI..PI
        val targetAngle = when (rampSide) {
            0 -> PI.toFloat() * 0.5f   // South
            1 -> PI.toFloat()          // West
            else -> 0f                 // East
        }
        var diff = angle - targetAngle
        while (diff > PI) diff -= (2.0 * PI).toFloat()
        while (diff < -PI) diff += (2.0 * PI).toFloat()
        return abs(diff) < 0.44f
    }

    /**
     * World position just outside the walkable ramp mouth so grounded enemies can route up.
     */
    fun rampApproachPoint(offsetOutside: Float = 26f): Pair<Float, Float> = when (rampSide) {
        0 -> x to (y + ry + offsetOutside)         // South ramp
        1 -> (x - rx - offsetOutside) to y         // West ramp
        else -> (x + rx + offsetOutside) to y      // East ramp
    }
}

enum class TerrainObstacleKind {
    TALL_TREE,
    BOULDER
}

/**
 * A 2.5D vertical world obstacle (Tall Tree or Sculpted Mega-Boulder) that blocks
 * movement at its base [collisionRadius] and visually occludes entities behind it.
 */
data class TerrainObstacle(
    val id: Int,
    val kind: TerrainObstacleKind,
    val x: Float,
    val y: Float,
    val collisionRadius: Float,
    val canopyRadius: Float,
    val height: Float,
    val variant: Int,
    val groundZ: Float = 0f
) {
    /** Effective vertical altitude up to which this solid obstacle intercepts straight shots. */
    val coverBlockHeight: Float
        get() = groundZ + if (kind == TerrainObstacleKind.BOULDER) {
            (height * 0.72f).coerceIn(28f, 40f)
        } else {
            (height * 0.46f).coerceIn(34f, 48f)
        }
}

/**
 * Deterministic 2.5D terrain layout generated per biome for the arena.
 * Ensures spawn clearing and main trails remain navigable while placing
 * jumpable plateaus, occluding tall trees, and boulder cover right within sight.
 */
class ArenaTerrainLayout(
    val plateaus: List<TerrainPlateau>,
    val obstacles: List<TerrainObstacle>,
    val ecoZones: List<BiomeEcoZone> = emptyList()
) {
    val movementObstacles: List<MapObstacle> = obstacles.map { obs ->
        MapObstacle(
            id = obs.id,
            x = obs.x,
            y = obs.y,
            radius = obs.collisionRadius,
            kind = if (obs.kind == TerrainObstacleKind.TALL_TREE) {
                MapObstacleKind.TREE
            } else {
                MapObstacleKind.BOULDER
            }
        )
    }

    /**
     * Computes terrain ground elevation beneath (px, py).
     */
    fun groundElevationAt(px: Float, py: Float): Float {
        var maxElev = 0f
        for (i in plateaus.indices) {
            val p = plateaus[i]
            if (p.containsPoint(px, py)) {
                if (p.elevation > maxElev) maxElev = p.elevation
            }
        }
        return maxElev
    }

    /**
     * Returns the highest raised plateau currently supporting (px, py), or null if at ground level.
     */
    fun plateauAt(px: Float, py: Float): TerrainPlateau? {
        var best: TerrainPlateau? = null
        for (i in plateaus.indices) {
            val p = plateaus[i]
            if (p.containsPoint(px, py)) {
                if (best == null || p.elevation > best.elevation) best = p
            }
        }
        return best
    }

    /**
     * Resolves 2.5D cliff wall collisions when a grounded entity tries to walk straight
     * into a raised plateau without jumping and outside its walkable ramp zone.
     * Returns adjusted (x, y).
     */
    fun resolveLedgeCollision(
        px: Float,
        py: Float,
        currentZ: Float,
        entityRadius: Float
    ): Pair<Float, Float> {
        var outX = px
        var outY = py
        for (i in plateaus.indices) {
            val p = plateaus[i]
            // Already high enough to step/land onto this plateau? Allow freely!
            if (currentZ >= p.elevation - 10f) continue
            // Approaching via the walkable ramp side? Allow smooth ascent!
            if (p.isInRampZone(outX, outY)) continue

            val effRx = p.rx + entityRadius * 0.72f
            val effRy = p.ry + entityRadius * 0.72f
            val nx = (outX - p.x) / effRx
            val ny = (outY - p.y) / effRy
            val nDistSq = nx * nx + ny * ny
            if (nDistSq < 1f) {
                val nDist = sqrt(nDistSq).coerceAtLeast(0.001f)
                outX = p.x + (nx / nDist) * effRx
                outY = p.y + (ny / nDist) * effRy
            }
        }
        return outX to outY
    }

    /**
     * Computes a smooth tangential obstacle-avoidance direction around boulders & tree trunks
     * so pursuing enemies curve naturally around cover instead of pinning behind rocks.
     */
    fun steerAroundObstacles(
        px: Float,
        py: Float,
        dirX: Float,
        dirY: Float,
        entityRadius: Float
    ): Pair<Float, Float> {
        var outX = dirX
        var outY = dirY
        for (i in obstacles.indices) {
            val obs = obstacles[i]
            val toObsX = obs.x - px
            val toObsY = obs.y - py
            val avoidR = obs.collisionRadius + entityRadius + 24f
            val lookAhead = avoidR + 54f
            val distSq = toObsX * toObsX + toObsY * toObsY
            if (distSq > lookAhead * lookAhead || distSq < 0.01f) continue

            // Only steer away if the obstacle lies in front of our desired travel direction
            val forwardDot = toObsX * dirX + toObsY * dirY
            if (forwardDot <= 0f) continue

            // Signed perpendicular offset of obstacle relative to travel ray
            val cross = dirX * toObsY - dirY * toObsX
            val perpDist = abs(cross)
            if (perpDist < avoidR) {
                val dist = sqrt(distSq)
                val urgency = ((lookAhead - dist) / lookAhead).coerceIn(0.15f, 1f) *
                    ((avoidR - perpDist) / avoidR).coerceIn(0.2f, 1f)
                // Choose the tangent side pointing away from the obstacle center
                val side = if (cross >= 0f) -1f else 1f
                val tangX = -dirY * side
                val tangY = dirX * side
                outX += tangX * urgency * 1.65f
                outY += tangY * urgency * 1.65f
            }
        }
        val mag = hypot(outX, outY).coerceAtLeast(0.001f)
        return (outX / mag) to (outY / mag)
    }

    /**
     * Checks whether a projectile at (px, py, projZ) impacts a solid 2.5D boulder or tree trunk.
     * High-ground projectiles flying above [TerrainObstacle.coverBlockHeight] clear low cover cleanly.
     */
    fun findProjectileObstacleImpact(
        px: Float,
        py: Float,
        projRadius: Float,
        projZ: Float
    ): TerrainObstacle? {
        for (i in obstacles.indices) {
            val obs = obstacles[i]
            if (projZ > obs.coverBlockHeight) continue
            val hitR = obs.collisionRadius * 0.90f + projRadius * 0.45f
            val dx = px - obs.x
            val dy = py - obs.y
            if (dx * dx + dy * dy <= hitR * hitR) {
                return obs
            }
        }
        return null
    }

    /**
     * Clips a straight beam segment from (startX, startY) to (endX, endY) at altitude [beamZ]
     * against solid 2.5D cover obstacles. Returns the clipped (endX, endY, hitObstacle).
     */
    fun clipBeamToObstacles(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        beamZ: Float
    ): Triple<Float, Float, TerrainObstacle?> {
        val segX = endX - startX
        val segY = endY - startY
        val segLen = hypot(segX, segY)
        if (segLen < 1f) return Triple(endX, endY, null)
        val dirX = segX / segLen
        val dirY = segY / segLen

        var bestT = segLen
        var hitObs: TerrainObstacle? = null
        for (i in obstacles.indices) {
            val obs = obstacles[i]
            if (beamZ > obs.coverBlockHeight) continue
            val relX = obs.x - startX
            val relY = obs.y - startY
            val proj = relX * dirX + relY * dirY
            if (proj <= 18f || proj >= bestT) continue
            val perp = abs(relX * (-dirY) + relY * dirX)
            val hitR = obs.collisionRadius * 0.88f
            if (perp <= hitR) {
                val impactT = (proj - sqrt((hitR * hitR - perp * perp).coerceAtLeast(0f))).coerceAtLeast(18f)
                if (impactT < bestT) {
                    bestT = impactT
                    hitObs = obs
                }
            }
        }
        return if (hitObs != null) {
            Triple(startX + dirX * bestT, startY + dirY * bestT, hitObs)
        } else {
            Triple(endX, endY, null)
        }
    }

    /**
     * Pushes an entity (e.g., an enemy) smoothly around solid tree trunks & boulders.
     */
    fun resolveObstaclePush(px: Float, py: Float, entityRadius: Float): Pair<Float, Float> {
        var outX = px
        var outY = py
        for (i in obstacles.indices) {
            val obs = obstacles[i]
            val dx = outX - obs.x
            val dy = outY - obs.y
            val minDist = obs.collisionRadius + entityRadius
            val distSq = dx * dx + dy * dy
            if (distSq < minDist * minDist) {
                val dist = sqrt(distSq).coerceAtLeast(0.001f)
                outX = obs.x + (dx / dist) * minDist
                outY = obs.y + (dy / dist) * minDist
            }
        }
        return outX to outY
    }

    fun isClearOfObstacles(px: Float, py: Float, clearance: Float): Boolean {
        for (i in obstacles.indices) {
            val obs = obstacles[i]
            if (hypot(px - obs.x, py - obs.y) < obs.collisionRadius + clearance) {
                return false
            }
        }
        return true
    }

    companion object {
        private fun hashInt(seed: Int): Int {
            var h = seed * 0x45d9f3b
            h = (h xor (h ushr 16)) * 0x45d9f3b
            return (h xor (h ushr 16)) and 0x7FFFFFFF
        }

        private fun trailClearance(wx: Float, wy: Float): Float {
            val trailAY = sin(wx * 0.0021f) * 240f - 130f
            val trailBX = sin(wy * 0.0023f) * 250f + 150f
            return minOf(abs(wy - trailAY), abs(wx - trailBX))
        }

        fun generate(biomeId: String, arenaHalfSize: Float = 1450f): ArenaTerrainLayout {
            val seedBase = biomeId.hashCode() and 0x7FFF
            val plateaus = mutableListOf<TerrainPlateau>()
            val obstacles = mutableListOf<TerrainObstacle>()
            var nextPlatId = 1
            var nextObsId = 1

            // 1. Hand-tuned showcase plateaus near spawn so players immediately see & jump onto 2.5D ledges
            val starterPlateaus = listOf(
                TerrainPlateau(nextPlatId++, x = -290f, y = -180f, rx = 132f, ry = 82f, elevation = 30f, rampSide = 0),
                TerrainPlateau(nextPlatId++, x = 340f, y = 210f, rx = 142f, ry = 88f, elevation = 32f, rampSide = 1),
                TerrainPlateau(nextPlatId++, x = -350f, y = 310f, rx = 128f, ry = 78f, elevation = 28f, rampSide = 2),
                TerrainPlateau(nextPlatId++, x = 360f, y = -280f, rx = 136f, ry = 84f, elevation = 30f, rampSide = 0)
            )
            plateaus.addAll(starterPlateaus)

            // 2. Outer-ring procedural jumpable plateaus across the open arena
            val ringAnchors = listOf(
                -860f to -760f, 0f to -820f, 840f to -740f,
                -920f to 60f, 900f to -40f,
                -820f to 820f, 40f to 860f, 860f to 780f
            )
            ringAnchors.forEachIndexed { idx, (ax, ay) ->
                val h = hashInt(seedBase + idx * 97 + 13)
                val px = (ax + ((h % 180) - 90)).coerceIn(-arenaHalfSize + 240f, arenaHalfSize - 240f)
                val py = (ay + (((h / 193) % 180) - 90)).coerceIn(-arenaHalfSize + 240f, arenaHalfSize - 240f)
                val rx = 126f + (h % 48)
                val ry = 78f + ((h / 17) % 28)
                val elev = 28f + (h % 8)
                plateaus.add(
                    TerrainPlateau(
                        id = nextPlatId++,
                        x = px,
                        y = py,
                        rx = rx,
                        ry = ry,
                        elevation = elev,
                        rampSide = h % 3
                    )
                )
            }

            fun elevationAt(wx: Float, wy: Float): Float {
                var e = 0f
                for (p in plateaus) {
                    if (p.containsPoint(wx, wy, margin = -18f)) {
                        if (p.elevation > e) e = p.elevation
                    }
                }
                return e
            }

            fun overlapsPlateauEdge(wx: Float, wy: Float, r: Float): Boolean {
                for (p in plateaus) {
                    val outer = p.containsPoint(wx, wy, margin = r + 14f)
                    val inner = p.containsPoint(wx, wy, margin = -(r + 22f))
                    if (outer && !inner) return true
                }
                return false
            }

            fun canPlaceObstacle(wx: Float, wy: Float, r: Float): Boolean {
                if (hypot(wx, wy) < 185f) return false
                if (abs(wx) > arenaHalfSize - 140f || abs(wy) > arenaHalfSize - 140f) return false
                if (trailClearance(wx, wy) < r + 52f) return false
                if (overlapsPlateauEdge(wx, wy, r)) return false
                for (o in obstacles) {
                    if (hypot(wx - o.x, wy - o.y) < r + o.collisionRadius + 108f) return false
                }
                return true
            }

            // 3. Showcase near-spawn occluding 2.5D tall trees & boulders (visible within first seconds!)
            val nearShowcase = listOf(
                Triple(-165f, -250f, TerrainObstacleKind.TALL_TREE),
                Triple(235f, -135f, TerrainObstacleKind.TALL_TREE),
                Triple(-220f, 155f, TerrainObstacleKind.BOULDER),
                Triple(200f, 250f, TerrainObstacleKind.TALL_TREE),
                Triple(45f, -310f, TerrainObstacleKind.BOULDER),
                Triple(-45f, 340f, TerrainObstacleKind.TALL_TREE)
            )
            nearShowcase.forEachIndexed { idx, (sx, sy, kind) ->
                val h = hashInt(seedBase + idx * 53 + 7)
                val r = if (kind == TerrainObstacleKind.TALL_TREE) 24f else 36f
                if (!overlapsPlateauEdge(sx, sy, r)) {
                    obstacles.add(
                        TerrainObstacle(
                            id = nextObsId++,
                            kind = kind,
                            x = sx,
                            y = sy,
                            collisionRadius = r,
                            canopyRadius = if (kind == TerrainObstacleKind.TALL_TREE) 72f + (h % 14) else 42f,
                            height = if (kind == TerrainObstacleKind.TALL_TREE) 96f + (h % 18) else 48f + (h % 12),
                            variant = h % 3,
                            groundZ = elevationAt(sx, sy)
                        )
                    )
                }
            }

            // 4. Procedural 2.5D tall trees & sculpted boulders across the full arena
            val gridStep = 265f
            val limit = arenaHalfSize - 170f
            var gx = -limit
            var rowIdx = 0
            while (gx <= limit) {
                var gy = -limit
                var colIdx = 0
                while (gy <= limit) {
                    val h = hashInt(seedBase + rowIdx * 313 + colIdx * 719 + 41)
                    if (h % 3 != 0) {
                        val wx = gx + ((h % 150) - 75)
                        val wy = gy + (((h / 157) % 150) - 75)
                        val isTree = when (biomeId) {
                            "desert" -> (h % 5) == 0 // mostly sandstone boulders + rare oasis palms/cacti
                            "volcano" -> (h % 4) == 0 // mostly obsidian crags + charred volcanic trees
                            else -> (h % 5) < 3       // lush forest & graveyard: ~60% tall trees, 40% boulders
                        }
                        val kind = if (isTree) TerrainObstacleKind.TALL_TREE else TerrainObstacleKind.BOULDER
                        val colR = if (isTree) 22f + (h % 7) else 34f + (h % 14)
                        if (canPlaceObstacle(wx, wy, colR)) {
                            obstacles.add(
                                TerrainObstacle(
                                    id = nextObsId++,
                                    kind = kind,
                                    x = wx,
                                    y = wy,
                                    collisionRadius = colR,
                                    canopyRadius = if (isTree) 66f + (h % 20) else colR + 8f,
                                    height = if (isTree) 92f + (h % 24) else 46f + (h % 16),
                                    variant = h % 3,
                                    groundZ = elevationAt(wx, wy)
                                )
                            )
                        }
                    }
                    gy += gridStep
                    colIdx++
                }
                gx += gridStep
                rowIdx++
            }

            val ecoZones = BiomeEcoRules.generateZones(
                biomeId = biomeId,
                arenaHalfSize = arenaHalfSize,
                obstacles = obstacles
            )
            return ArenaTerrainLayout(plateaus = plateaus, obstacles = obstacles, ecoZones = ecoZones)
        }
    }
}
