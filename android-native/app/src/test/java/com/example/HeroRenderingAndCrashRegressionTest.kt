package com.example

import android.graphics.Bitmap
import android.graphics.Canvas as AndroidCanvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import com.example.game.engine.GameSimulation
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.ui.components.drawEvolvedHeroSprite
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.math.PI

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class HeroRenderingAndCrashRegressionTest {

    private fun renderOnBitmap(
        widthPx: Int = 256,
        heightPx: Int = 256,
        drawSize: Size = Size(widthPx.toFloat(), heightPx.toFloat()),
        block: androidx.compose.ui.graphics.drawscope.DrawScope.() -> Unit
    ) {
        val bmp = Bitmap.createBitmap(widthPx.coerceAtLeast(1), heightPx.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(AndroidCanvas(bmp))
        val drawScope = CanvasDrawScope()
        drawScope.draw(
            density = Density(2f),
            layoutDirection = LayoutDirection.Ltr,
            canvas = canvas,
            size = drawSize,
            block = block
        )
    }

    @Test
    fun `all 30 evolution nodes render safely across extreme states including Char overdrive and low HP`() {
        val allNodes = GameCatalog.starters.flatMap { EvolutionRegistry.treeForStarter(it.id) }
        assertTrue("Expected at least 30 evolution nodes", allNodes.size >= 30)

        // animTime = PI/8 hits sin(animTime * 4f) == 1.0f (Char Overdrive peak emberPulse = 1.18f)
        val peakOverdriveTime = (PI / 8.0).toFloat()
        val blinkTime = 11.55f

        val scenarios = listOf(
            // Idle + blink
            RenderScenario(animTime = blinkTime, hpRatio = 1f),
            // Char Overdrive <50% HP at peak sine (previously crashed with alpha = 1.062 > 1.0!)
            RenderScenario(animTime = peakOverdriveTime, hpRatio = 0.45f),
            // Critical Low HP <30% + hurt + attack + dash + glide + ult + evoFx + quirk simultaneously
            RenderScenario(
                animTime = peakOverdriveTime,
                hpRatio = 0.20f,
                moveSpeedRatio = 1.4f,
                isAttacking = true,
                attackProgress = 0.50f,
                isHurt = true,
                hurtProgress = 0.92f,
                isUltActive = true,
                evolutionFxProgress = 0.85f,
                isDashing = true,
                isAirborne = true,
                isGliding = true,
                quirkProgress = 0.50f
            ),
            // Hurt recovery phase + secondary evolution burst phase
            RenderScenario(
                animTime = 4.2f,
                hpRatio = 0.25f,
                isHurt = true,
                hurtProgress = 0.45f,
                evolutionFxProgress = 0.35f,
                facingAngle = 2.6f
            )
        )

        renderOnBitmap {
            val center = Offset(128f, 128f)
            for (node in allNodes) {
                for (sc in scenarios) {
                    drawEvolvedHeroSprite(
                        style = node.visualStyle,
                        center = center,
                        baseRadius = 32f,
                        animTime = sc.animTime,
                        orbitAngle = sc.animTime * 0.8f,
                        facingAngle = sc.facingAngle,
                        moveSpeedRatio = sc.moveSpeedRatio,
                        isAttacking = sc.isAttacking,
                        isHurt = sc.isHurt,
                        isUltActive = sc.isUltActive,
                        attackProgress = sc.attackProgress,
                        hurtProgress = sc.hurtProgress,
                        evolutionFxProgress = sc.evolutionFxProgress,
                        isDashing = sc.isDashing,
                        isAirborne = sc.isAirborne,
                        isGliding = sc.isGliding,
                        hpRatio = sc.hpRatio,
                        quirkProgress = sc.quirkProgress
                    )
                }
            }
        }
    }

    @Test
    fun `drawEvolvedHeroSprite safely ignores zero size, zero radius, and NaN coordinates`() {
        val charStyle = EvolutionRegistry.baseNodeForStarter("char").visualStyle

        // 0x0 draw size
        renderOnBitmap(drawSize = Size.Zero) {
            drawEvolvedHeroSprite(
                style = charStyle,
                center = Offset.Zero,
                baseRadius = 24f,
                animTime = 1f,
                orbitAngle = 1f,
                hpRatio = 0.2f,
                isUltActive = true
            )
        }

        // Valid size with 0 radius and NaN inputs
        renderOnBitmap {
            drawEvolvedHeroSprite(
                style = charStyle,
                center = Offset(128f, 128f),
                baseRadius = 0f,
                animTime = Float.NaN,
                orbitAngle = Float.NaN,
                facingAngle = Float.NaN,
                hpRatio = 0.2f,
                quirkProgress = 0.5f
            )
            drawEvolvedHeroSprite(
                style = charStyle,
                center = Offset(Float.NaN, 128f),
                baseRadius = 28f,
                animTime = 1f,
                orbitAngle = 1f
            )
        }
    }

    @Test
    fun `all 6 starters survive battle simulation loop and render frames without crashing`() {
        val biome = GameCatalog.biomeById("forest")
        for (starter in GameCatalog.starters) {
            val sim = GameSimulation(
                starter = starter,
                biome = biome,
                gameMode = GameMode.CLASSIC,
                labLevels = emptyMap(),
                autoAimEnabled = true,
                screenShakeEnabled = true,
                onSfx = {},
                onHaptic = {}
            )
            sim.setJoystickInput(0.8f, 0.35f)
            sim.triggerDash()
            sim.triggerJump()
            var lastState = sim.step(1f / 60f)
            repeat(90) { stepIdx ->
                if (stepIdx == 15) sim.triggerJump()
                if (stepIdx == 35) sim.triggerDash()
                lastState = sim.step(1f / 60f)
            }
            val hpRatio = (lastState.hp / lastState.maxHp.coerceAtLeast(1f)).coerceIn(0f, 1f)
            renderOnBitmap {
                drawEvolvedHeroSprite(
                    style = lastState.evolutionState.currentNode.visualStyle,
                    center = Offset(128f, 128f),
                    baseRadius = 28f,
                    animTime = lastState.elapsedSec * 1.9f,
                    orbitAngle = lastState.orbitAngle,
                    facingAngle = lastState.facingAngle,
                    moveSpeedRatio = lastState.moveSpeedRatio,
                    isAttacking = lastState.attackFlashTimer > 0f,
                    isHurt = lastState.hurtFlashTimer > 0f,
                    isUltActive = lastState.ultActiveTimer > 0f,
                    leanDeg = lastState.leanDeg,
                    attackProgress = (lastState.attackFlashTimer / 0.28f).coerceIn(0f, 1f),
                    hurtProgress = (lastState.hurtFlashTimer / 0.36f).coerceIn(0f, 1f),
                    evolutionFxProgress = (lastState.evolutionFxTimer / 1.45f).coerceIn(0f, 1f),
                    walkCycle = lastState.walkAnimTime,
                    isDashing = lastState.dashActiveTimer > 0f,
                    isAirborne = lastState.isJumping,
                    isGliding = lastState.isGliding,
                    hpRatio = hpRatio
                )
            }
        }
    }

    private data class RenderScenario(
        val animTime: Float = 1f,
        val facingAngle: Float = 0.25f,
        val moveSpeedRatio: Float = 0f,
        val isAttacking: Boolean = false,
        val attackProgress: Float = 0f,
        val isHurt: Boolean = false,
        val hurtProgress: Float = 0f,
        val isUltActive: Boolean = false,
        val evolutionFxProgress: Float = 0f,
        val isDashing: Boolean = false,
        val isAirborne: Boolean = false,
        val isGliding: Boolean = false,
        val hpRatio: Float = 1f,
        val quirkProgress: Float = 0f
    )
}
