package com.example.game

import com.example.game.engine.ArenaTerrainLayout
import com.example.game.engine.BiomeZoneKind
import com.example.game.engine.TerrainObstacle
import com.example.game.engine.TerrainObstacleKind
import com.example.game.engine.TerrainPlateau
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.hypot

class TerrainAndCoverMechanicsTest {

    @Test
    fun `all four biomes generate plateaus, obstacles, and biome-exclusive eco zones`() {
        val expectedZones = mapOf(
            "forest" to BiomeZoneKind.FOREST_BLOOM_RING,
            "graveyard" to BiomeZoneKind.GRAVEYARD_SOUL_LANTERN,
            "desert" to BiomeZoneKind.DESERT_QUICKSAND,
            "volcano" to BiomeZoneKind.VOLCANO_LAVA_VENT
        )

        expectedZones.forEach { (biomeId, expectedKind) ->
            val layout = ArenaTerrainLayout.generate(biomeId)
            assertTrue("Biome $biomeId should have raised plateaus", layout.plateaus.size >= 4)
            assertTrue("Biome $biomeId should have cover obstacles", layout.obstacles.size >= 6)
            assertTrue("Biome $biomeId should have eco zones", layout.ecoZones.isNotEmpty())
            assertTrue(
                "Biome $biomeId eco zones must match $expectedKind",
                layout.ecoZones.all { it.kind == expectedKind }
            )
            // Spawn origin must stay clear so player never starts inside a boulder
            assertTrue("Spawn should be clear in $biomeId", layout.isClearOfObstacles(0f, 0f, 30f))
        }
    }

    @Test
    fun `resolveLedgeCollision blocks grounded cliff climb but allows ramp and high-Z jump`() {
        // Plateau centered at (0, 0) with South ramp (rampSide = 0, positive Y)
        val plateau = TerrainPlateau(
            id = 1,
            x = 0f,
            y = 0f,
            rx = 120f,
            ry = 80f,
            elevation = 30f,
            rampSide = 0
        )
        val layout = ArenaTerrainLayout(plateaus = listOf(plateau), obstacles = emptyList())

        // 1. Approaching from North cliff (y = -60, inside ellipse, NOT ramp side) while grounded (z = 0)
        val (blockedX, blockedY) = layout.resolveLedgeCollision(
            px = 0f,
            py = -60f,
            currentZ = 0f,
            entityRadius = 20f
        )
        assertTrue(
            "Grounded entity should be pushed outside north cliff wall (got y=$blockedY)",
            blockedY <= -80f
        )
        assertEquals(0f, blockedX, 0.5f)

        // 2. Approaching via South walkable ramp (y = +60, rampSide = 0) while grounded (z = 0)
        val (rampX, rampY) = layout.resolveLedgeCollision(
            px = 0f,
            py = 60f,
            currentZ = 0f,
            entityRadius = 20f
        )
        assertEquals("South ramp should allow grounded entry", 0f, rampX, 0.01f)
        assertEquals("South ramp should not push entity back", 60f, rampY, 0.01f)

        // 3. Jumping over North cliff (currentZ = 28f >= elevation - 10f)
        val (jumpX, jumpY) = layout.resolveLedgeCollision(
            px = 0f,
            py = -60f,
            currentZ = 28f,
            entityRadius = 20f
        )
        assertEquals(0f, jumpX, 0.01f)
        assertEquals("High-Z jump should clear cliff wall", -60f, jumpY, 0.01f)
    }

    @Test
    fun `projectile and beam cover checks block low shots while high-ground shots clear low boulders`() {
        val lowBoulder = TerrainObstacle(
            id = 10,
            kind = TerrainObstacleKind.BOULDER,
            x = 120f,
            y = 0f,
            collisionRadius = 36f,
            canopyRadius = 42f,
            height = 46f,
            variant = 0,
            groundZ = 0f
        )
        val layout = ArenaTerrainLayout(plateaus = emptyList(), obstacles = listOf(lowBoulder))

        // Low projectile at z = 14f hits the boulder
        val lowHit = layout.findProjectileObstacleImpact(px = 115f, py = 4f, projRadius = 10f, projZ = 14f)
        assertNotNull("Low-altitude projectile should collide with boulder cover", lowHit)

        // High-ground projectile at z = coverBlockHeight + 12f clears the boulder cleanly
        val highHit = layout.findProjectileObstacleImpact(
            px = 115f,
            py = 4f,
            projRadius = 10f,
            projZ = lowBoulder.coverBlockHeight + 12f
        )
        assertNull("High-altitude projectile should fire cleanly over boulder cover", highHit)

        // Beam clipping at low altitude stops at boulder face (< 120f)
        val (clippedX, _, beamHit) = layout.clipBeamToObstacles(
            startX = 0f,
            startY = 0f,
            endX = 300f,
            endY = 0f,
            beamZ = 16f
        )
        assertNotNull("Low beam should be blocked by boulder cover", beamHit)
        assertTrue("Beam endpoint should clip before boulder center (got $clippedX)", clippedX < 120f)

        // Beam at high altitude passes uninterrupted to x = 300f
        val (clearX, _, highBeamHit) = layout.clipBeamToObstacles(
            startX = 0f,
            startY = 0f,
            endX = 300f,
            endY = 0f,
            beamZ = lowBoulder.coverBlockHeight + 10f
        )
        assertNull("High-ground beam should pass over low boulder", highBeamHit)
        assertEquals(300f, clearX, 0.5f)
    }

    @Test
    fun `steerAroundObstacles deflects pursuing entity tangentially around head-on boulder`() {
        val boulder = TerrainObstacle(
            id = 20,
            kind = TerrainObstacleKind.BOULDER,
            x = 70f,
            y = 4f,
            collisionRadius = 34f,
            canopyRadius = 40f,
            height = 50f,
            variant = 0
        )
        val layout = ArenaTerrainLayout(plateaus = emptyList(), obstacles = listOf(boulder))

        val (steerX, steerY) = layout.steerAroundObstacles(
            px = 0f,
            py = 0f,
            dirX = 1f,
            dirY = 0f,
            entityRadius = 18f
        )
        val mag = hypot(steerX, steerY)
        assertEquals("Steered direction must stay normalized", 1f, mag, 0.01f)
        assertTrue("Steered direction should deflect laterally around boulder (got steerY=$steerY)", abs(steerY) > 0.2f)
    }
}
