package com.example

import com.example.game.movement.MapObstacle
import com.example.game.movement.MapObstacleKind
import com.example.game.movement.SpriteLocomotionProfiles
import com.example.game.movement.SpriteMovementController
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class SpriteMovementSystemTest {

    @Test
    fun distinctLocomotionProfilesForCoreThreeSprites() {
        val stump = SpriteLocomotionProfiles.forStarter("stump")
        val char = SpriteLocomotionProfiles.forStarter("char")
        val shell = SpriteLocomotionProfiles.forStarter("shell")

        // Char accelerates fastest & has highest base speed among the three
        assertTrue(char.baseMaxSpeed > shell.baseMaxSpeed)
        assertTrue(char.accelerationRate > stump.accelerationRate)
        // Shell has the silkiest glide (lowest deceleration rate & highest dash carry momentum)
        assertTrue(shell.decelerationRate < stump.decelerationRate)
        assertTrue(shell.dashCarryMomentum > stump.dashCarryMomentum)
        // Stump has highest braking grip among the three
        assertTrue(stump.decelerationRate > char.decelerationRate)
    }

    @Test
    fun smoothAccelerationDecelerationAndCameraLookAhead() {
        val ctrl = SpriteMovementController(initialStarterId = "shell")
        ctrl.setAnalogInput(1f, 0f)

        var lastSpeed = 0f
        repeat(20) {
            val s = ctrl.step(1f / 60f)
            assertTrue("Speed should ramp smoothly upward", s.speed >= lastSpeed)
            lastSpeed = s.speed
        }
        val running = ctrl.step(1f / 60f)
        assertTrue(running.x > 30f)
        assertTrue(running.leanDeg > 0f)

        // Release joystick -> smooth exponential deceleration (not instant zero snap on frame 1)
        ctrl.setAnalogInput(0f, 0f)
        val afterRelease1 = ctrl.step(1f / 60f)
        assertTrue("Shell should glide smoothly after release", afterRelease1.speed > 50f)

        repeat(120) { ctrl.step(1f / 60f) }
        val stopped = ctrl.step(1f / 60f)
        assertEquals(0f, stopped.speed, 0.01f)
    }

    @Test
    fun obstacleSlidingAndWaypointArrival() {
        val ctrl = SpriteMovementController(initialStarterId = "stump", startX = 0f, startY = 0f)
        val boulder = MapObstacle(1, 80f, 0f, 36f, MapObstacleKind.BOULDER)
        ctrl.setAnalogInput(1f, 0.25f)

        repeat(45) {
            val s = ctrl.step(1f / 60f, obstacles = listOf(boulder))
            val distToBoulder = hypot(s.x - boulder.x, s.y - boulder.y)
            assertTrue("Sprite must never clip inside obstacle", distToBoulder >= boulder.radius + ctrl.spriteCollisionRadius - 0.5f)
        }

        // Switch to Char & test waypoint navigation
        ctrl.switchProfile("char")
        ctrl.reset(0f, 0f)
        ctrl.setWaypoint(220f, 120f, arenaHalfSize = 1100f)
        repeat(120) { ctrl.step(1f / 60f) }
        val arrived = ctrl.step(1f / 60f)
        val distToTarget = hypot(arrived.x - 220f, arrived.y - 120f)
        assertTrue("Char should smoothly arrive at waypoint", distToTarget < 24f)
        assertFalse("Waypoint should clear upon arrival", arrived.waypointX != null)
    }
}
