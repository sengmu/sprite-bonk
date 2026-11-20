package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.KeyboardDoubleArrowUp
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.GameCatalog
import com.example.game.movement.ComposeGameLoop
import com.example.game.movement.MapObstacle
import com.example.game.movement.MapObstacleKind
import com.example.game.movement.SpriteLocomotionProfiles
import com.example.game.movement.SpriteMovementController
import com.example.game.movement.SpriteMovementState
import com.example.ui.rememberCosmeticLoadout
import com.example.ui.components.StarterPortraitAvatar
import com.example.ui.components.drawEvolvedHeroSprite
import com.example.ui.components.drawStarlightEntranceAura
import com.example.ui.components.withCosmeticLoadout
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.EspressoInk
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SandstoneRim
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

private data class RoamStarOrb(
    val id: Int,
    var x: Float,
    var y: Float,
    var collectedCooldown: Float = 0f
)

private data class RoamBurstRing(
    val x: Float,
    val y: Float,
    var radius: Float,
    val maxRadius: Float,
    val color: Color,
    var life: Float,
    val maxLife: Float
)

/**
 * Interactive Compose Game-Loop Sprite Movement Playground ("自由漫游试炼场").
 * Now supports instant live-switching across ALL 6 playable sprites,
 * radial cooldown Dash button, directional radar minimap, and sleek telemetry HUD.
 */
@Composable
fun SpriteRoamScreen(
    initialStarterId: String,
    biomeId: String,
    onSelectStarterPersist: (String) -> Unit,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)

    val allStarterIds = remember { GameCatalog.starters.map { it.id } }
    var activeStarterId by remember {
        mutableStateOf(if (initialStarterId in allStarterIds) initialStarterId else allStarterIds.first())
    }
    var previewTier by remember { mutableIntStateOf(0) }
    val biome = remember(biomeId) { GameCatalog.biomeById(biomeId) }

    val worldHalfSize = 1100f
    val controller = remember { SpriteMovementController(initialStarterId = activeStarterId) }

    val obstacles = remember {
        buildList {
            var oid = 1
            add(MapObstacle(oid++, 0f, -260f, 44f, MapObstacleKind.SPEED_PAD))
            add(MapObstacle(oid++, 0f, 260f, 44f, MapObstacleKind.SPEED_PAD))
            add(MapObstacle(oid++, -300f, 0f, 44f, MapObstacleKind.SPEED_PAD))
            add(MapObstacle(oid++, 300f, 0f, 44f, MapObstacleKind.SPEED_PAD))

            val ringConfigs = listOf(
                Triple(-210f, -190f, MapObstacleKind.TREE),
                Triple(230f, -210f, MapObstacleKind.TREE),
                Triple(-240f, 210f, MapObstacleKind.BOULDER),
                Triple(220f, 220f, MapObstacleKind.POND),
                Triple(-480f, -340f, MapObstacleKind.TREE),
                Triple(460f, -360f, MapObstacleKind.POND),
                Triple(-520f, 280f, MapObstacleKind.POND),
                Triple(510f, 340f, MapObstacleKind.TREE),
                Triple(0f, -540f, MapObstacleKind.BOULDER),
                Triple(0f, 540f, MapObstacleKind.BOULDER),
                Triple(-620f, -40f, MapObstacleKind.TREE),
                Triple(620f, 60f, MapObstacleKind.TREE),
                Triple(-390f, -640f, MapObstacleKind.BOULDER),
                Triple(410f, -660f, MapObstacleKind.TREE),
                Triple(-420f, 650f, MapObstacleKind.TREE),
                Triple(420f, 640f, MapObstacleKind.BOULDER),
                Triple(-780f, -460f, MapObstacleKind.TREE),
                Triple(790f, -440f, MapObstacleKind.BOULDER),
                Triple(-760f, 460f, MapObstacleKind.BOULDER),
                Triple(760f, 490f, MapObstacleKind.POND)
            )
            for ((ox, oy, kind) in ringConfigs) {
                val r = when (kind) {
                    MapObstacleKind.TREE -> 38f
                    MapObstacleKind.BOULDER -> 34f
                    MapObstacleKind.POND -> 54f
                    MapObstacleKind.SPEED_PAD -> 44f
                }
                add(MapObstacle(oid++, ox, oy, r, kind))
            }
        }
    }

    val starOrbs = remember {
        val rng = Random(42)
        mutableStateListOf<RoamStarOrb>().apply {
            for (i in 1..16) {
                val angle = i * (2f * PI.toFloat() / 16f)
                val dist = 180f + (i % 4) * 185f
                add(
                    RoamStarOrb(
                        id = i,
                        x = cos(angle) * dist + (rng.nextFloat() - 0.5f) * 60f,
                        y = sin(angle) * dist + (rng.nextFloat() - 0.5f) * 60f
                    )
                )
            }
        }
    }

    val burstRings = remember { mutableStateListOf<RoamBurstRing>() }
    val trainingPlateau = remember { RoamHighGroundPlateau() }
    val trainingDummy = remember { TrainingDummyState() }
    val jumpPhysics = remember { RoamJumpPhysics() }
    val trainingProjectiles = remember { mutableStateListOf<RoamTrainingProjectile>() }
    val trainingFloats = remember { mutableStateListOf<RoamFloatingDamage>() }
    val damagePaints = remember { createRoamDamagePaints() }
    val trainingRng = remember { Random(1337) }

    var moveState by remember { mutableStateOf(SpriteMovementState(starterId = activeStarterId)) }
    var elapsedSec by remember { mutableFloatStateOf(0f) }
    var orbitAngle by remember { mutableFloatStateOf(0f) }
    var currentFps by remember { mutableFloatStateOf(60f) }
    var orbsCollected by remember { mutableIntStateOf(0) }
    var canvasSize by remember { mutableStateOf(IntSize(1, 1)) }

    // Training sandbox live HUD telemetry states
    var autoFireEnabled by remember { mutableStateOf(false) }
    var autoFireCooldown by remember { mutableFloatStateOf(0f) }
    var attackFlashTimer by remember { mutableFloatStateOf(0f) }
    var ultBurstFlashTimer by remember { mutableFloatStateOf(0f) }
    var evolutionFxTimer by remember { mutableFloatStateOf(0f) }
    var liveDpsDisplay by remember { mutableIntStateOf(0) }
    var peakHitDisplay by remember { mutableIntStateOf(0) }
    var comboCountDisplay by remember { mutableIntStateOf(0) }
    var heroZDisplay by remember { mutableFloatStateOf(0f) }
    var isOnHighGroundDisplay by remember { mutableStateOf(false) }
    var isJumpingDisplay by remember { mutableStateOf(false) }
    var isGlidingDisplay by remember { mutableStateOf(false) }
    var jumpCdRatioDisplay by remember { mutableFloatStateOf(0f) }

    var joyOrigin by remember { mutableStateOf<Offset?>(null) }
    var joyThumb by remember { mutableStateOf<Offset?>(null) }

    val pressedKeys = remember { mutableSetOf<Key>() }
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { focusRequester.requestFocus() }
    }

    fun syncKeyboard() {
        var kx = 0f
        var ky = 0f
        if (Key.A in pressedKeys || Key.DirectionLeft in pressedKeys) kx -= 1f
        if (Key.D in pressedKeys || Key.DirectionRight in pressedKeys) kx += 1f
        if (Key.W in pressedKeys || Key.DirectionUp in pressedKeys) ky -= 1f
        if (Key.S in pressedKeys || Key.DirectionDown in pressedKeys) ky += 1f
        controller.setKeyboardInput(kx, ky)
    }

    fun triggerDash() {
        if (controller.triggerDash()) {
            val col = SpriteLocomotionProfiles.forStarter(activeStarterId).accentTrailColor
            burstRings.add(RoamBurstRing(controller.x, controller.y, 18f, 92f, col, 0.32f, 0.32f))
        }
    }

    fun triggerJumpOrGlide() {
        when (jumpPhysics.triggerJumpOrGlide()) {
            RoamJumpPhysics.JumpActionResult.JUMPED -> {
                burstRings.add(RoamBurstRing(controller.x, controller.y, 12f, 64f, SkyBlue, 0.28f, 0.28f))
            }
            RoamJumpPhysics.JumpActionResult.GLIDE_OPENED -> {
                burstRings.add(RoamBurstRing(controller.x, controller.y - jumpPhysics.z, 10f, 56f, Color(0xFF9DF7FF), 0.24f, 0.24f))
            }
            RoamJumpPhysics.JumpActionResult.SLAM_TRIGGERED -> {
                burstRings.add(RoamBurstRing(controller.x, controller.y - jumpPhysics.z, 12f, 64f, GoldAccent, 0.24f, 0.24f))
            }
            RoamJumpPhysics.JumpActionResult.NONE -> Unit
        }
    }

    fun triggerMoveTrial() {
        attackFlashTimer = 0.24f
        fireRoamSignatureMove(
            starterId = activeStarterId,
            previewTier = previewTier,
            heroX = controller.x,
            heroY = controller.y,
            heroZ = jumpPhysics.z,
            facingAngle = moveState.facingAngle,
            dummy = trainingDummy,
            nowSec = elapsedSec,
            rng = trainingRng,
            projectiles = trainingProjectiles,
            floatingNumbers = trainingFloats,
            onRing = { rx, ry, maxR, col ->
                burstRings.add(RoamBurstRing(rx, ry, 14f, maxR, col, 0.36f, 0.36f))
            }
        )
    }

    fun triggerUltTrial() {
        attackFlashTimer = 0.36f
        ultBurstFlashTimer = 0.85f
        fireRoamUltBurst(
            starterId = activeStarterId,
            previewTier = previewTier,
            heroX = controller.x,
            heroY = controller.y,
            heroZ = jumpPhysics.z,
            dummy = trainingDummy,
            nowSec = elapsedSec,
            rng = trainingRng,
            projectiles = trainingProjectiles,
            floatingNumbers = trainingFloats,
            onRing = { rx, ry, maxR, col ->
                burstRings.add(RoamBurstRing(rx, ry, 18f, maxR, col, 0.46f, 0.46f))
            }
        )
    }

    fun switchSprite(targetId: String) {
        if (targetId == activeStarterId) return
        activeStarterId = targetId
        controller.switchProfile(targetId)
        onSelectStarterPersist(targetId)
        val col = SpriteLocomotionProfiles.forStarter(targetId).trailColor
        burstRings.add(RoamBurstRing(controller.x, controller.y, 20f, 118f, col, 0.40f, 0.40f))
    }

    ComposeGameLoop(active = true) { dt, fps ->
        elapsedSec += dt
        orbitAngle = (orbitAngle + dt * 4.2f) % (2f * PI.toFloat())
        currentFps = fps
        if (attackFlashTimer > 0f) attackFlashTimer = (attackFlashTimer - dt).coerceAtLeast(0f)
        if (ultBurstFlashTimer > 0f) ultBurstFlashTimer = (ultBurstFlashTimer - dt).coerceAtLeast(0f)
        if (evolutionFxTimer > 0f) evolutionFxTimer = (evolutionFxTimer - dt).coerceAtLeast(0f)

        val glideSpeedMult = if (jumpPhysics.isGliding) 1.24f else 1f
        val next = controller.step(
            rawDt = dt,
            speedMultiplier = glideSpeedMult,
            arenaHalfSize = worldHalfSize,
            obstacles = obstacles,
            emitTrails = true
        )
        moveState = next

        // 2.5D Jump / Air-Glide / Drop-Slam physics
        val slamDropHeight = jumpPhysics.step(dt, next.x, next.y, trainingPlateau)
        if (slamDropHeight > 0f) {
            val slamRadius = 158f + (slamDropHeight * 0.45f).coerceAtMost(54f)
            burstRings.add(RoamBurstRing(next.x, next.y, 16f, slamRadius, GoldAccent, 0.44f, 0.44f))
            burstRings.add(RoamBurstRing(next.x, next.y, 10f, slamRadius * 0.7f, SkyBlue, 0.34f, 0.34f))
            val dDummy = hypot(trainingDummy.x - next.x, trainingDummy.y - next.y)
            if (dDummy <= slamRadius + trainingDummy.radius) {
                val slamDmg = (68f + slamDropHeight * 0.9f) * (1f + previewTier * 0.35f)
                applyRoamDummyHit(
                    dummy = trainingDummy,
                    rawDamage = slamDmg,
                    accentColor = GoldAccent,
                    hitFromLeft = next.x < trainingDummy.x,
                    nowSec = elapsedSec,
                    rng = trainingRng,
                    floatingNumbers = trainingFloats,
                    forceCrit = true,
                    prefixLabel = "坠击"
                )
            }
        }

        // Auto-Fire signature move toggle for effortless DPS benchmarking
        if (autoFireEnabled) {
            autoFireCooldown -= dt
            if (autoFireCooldown <= 0f) {
                autoFireCooldown = 0.52f
                triggerMoveTrial()
            }
        }

        // Update training projectiles & collision with Training Dummy
        val pIter = trainingProjectiles.iterator()
        while (pIter.hasNext()) {
            val p = pIter.next()
            p.life -= dt
            if (!p.isBeam) {
                p.x += p.vx * dt
                p.y += p.vy * dt
                if (!p.hitDummy && hypot(p.x - trainingDummy.x, p.y - trainingDummy.y) <= p.radius + trainingDummy.radius + 6f) {
                    p.hitDummy = true
                    applyRoamDummyHit(
                        dummy = trainingDummy,
                        rawDamage = p.damage,
                        accentColor = p.color,
                        hitFromLeft = p.vx >= 0f,
                        nowSec = elapsedSec,
                        rng = trainingRng,
                        floatingNumbers = trainingFloats,
                        forceCrit = p.isUlt
                    )
                    burstRings.add(RoamBurstRing(trainingDummy.x, trainingDummy.y - 20f, 8f, 44f, p.color, 0.22f, 0.22f))
                    pIter.remove()
                    continue
                }
            }
            if (p.life <= 0f) pIter.remove()
        }

        // Update floating damage texts
        val fIter = trainingFloats.iterator()
        while (fIter.hasNext()) {
            val ft = fIter.next()
            ft.life -= dt
            ft.y -= 48f * dt
            if (ft.life <= 0f) fIter.remove()
        }

        trainingDummy.step(dt, elapsedSec)
        liveDpsDisplay = trainingDummy.liveDps
        peakHitDisplay = trainingDummy.peakHit
        comboCountDisplay = trainingDummy.comboCount
        heroZDisplay = jumpPhysics.z
        isOnHighGroundDisplay = jumpPhysics.isOnHighGround
        isJumpingDisplay = jumpPhysics.isJumping
        isGlidingDisplay = jumpPhysics.isGliding
        jumpCdRatioDisplay = (jumpPhysics.jumpCooldown / jumpPhysics.jumpCooldownTotal).coerceIn(0f, 1f)

        for (orb in starOrbs) {
            if (orb.collectedCooldown > 0f) {
                orb.collectedCooldown = (orb.collectedCooldown - dt).coerceAtLeast(0f)
            } else {
                val dist = hypot(next.x - orb.x, next.y - orb.y)
                if (dist < 42f) {
                    orb.collectedCooldown = 6.5f
                    orbsCollected++
                    burstRings.add(RoamBurstRing(orb.x, orb.y, 12f, 76f, GoldAccent, 0.36f, 0.36f))
                }
            }
        }

        val iter = burstRings.iterator()
        while (iter.hasNext()) {
            val r = iter.next()
            r.life -= dt
            val prog = 1f - (r.life / r.maxLife).coerceIn(0f, 1f)
            r.radius = r.maxRadius * prog
            if (r.life <= 0f) iter.remove()
        }
    }

    val visualNode = remember(activeStarterId, previewTier) {
        val nodes = EvolutionRegistry.treeForStarter(activeStarterId)
        nodes.firstOrNull { it.tier == previewTier } ?: EvolutionRegistry.baseNodeForStarter(activeStarterId)
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .focusRequester(focusRequester)
            .focusable()
            .onPreviewKeyEvent { event ->
                val isDown = event.type == KeyEventType.KeyDown
                val isUp = event.type == KeyEventType.KeyUp
                when (event.key) {
                    Key.W, Key.A, Key.S, Key.D,
                    Key.DirectionUp, Key.DirectionDown, Key.DirectionLeft, Key.DirectionRight -> {
                        if (isDown) pressedKeys.add(event.key)
                        if (isUp) pressedKeys.remove(event.key)
                        syncKeyboard()
                        true
                    }
                    Key.Spacebar -> {
                        if (isDown) triggerJumpOrGlide()
                        true
                    }
                    Key.ShiftLeft, Key.ShiftRight -> {
                        if (isDown) triggerDash()
                        true
                    }
                    Key.J -> {
                        if (isDown) triggerMoveTrial()
                        true
                    }
                    Key.K -> {
                        if (isDown) triggerUltTrial()
                        true
                    }
                    Key.One -> { if (isDown) allStarterIds.getOrNull(0)?.let(::switchSprite); true }
                    Key.Two -> { if (isDown) allStarterIds.getOrNull(1)?.let(::switchSprite); true }
                    Key.Three -> { if (isDown) allStarterIds.getOrNull(2)?.let(::switchSprite); true }
                    Key.Four -> { if (isDown) allStarterIds.getOrNull(3)?.let(::switchSprite); true }
                    Key.Five -> { if (isDown) allStarterIds.getOrNull(4)?.let(::switchSprite); true }
                    Key.Six -> { if (isDown) allStarterIds.getOrNull(5)?.let(::switchSprite); true }
                    else -> false
                }
            }
    ) {
        // 1. MAIN OPEN-WORLD MAP CANVAS
        val foxSkinEquipped = com.example.wallet.devnetFoxSkinEquipped()
        val cosmeticLoadout = rememberCosmeticLoadout()
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .onSizeChanged { canvasSize = it }
                .pointerInput(Unit) {
                    detectTapGestures { tapOffset ->
                        val cx = canvasSize.width / 2f
                        val cy = canvasSize.height / 2f
                        val worldX = moveState.cameraX - cx + tapOffset.x
                        val worldY = moveState.cameraY - cy + tapOffset.y
                        controller.setWaypoint(worldX, worldY, worldHalfSize)
                        burstRings.add(
                            RoamBurstRing(
                                worldX,
                                worldY,
                                8f,
                                48f,
                                moveState.profile.accentTrailColor,
                                0.35f,
                                0.35f
                            )
                        )
                    }
                }
        ) {
            val cx = size.width / 2f
            val cy = size.height / 2f
            val camX = moveState.cameraX - cx
            val camY = moveState.cameraY - cy
            fun toScreen(wx: Float, wy: Float) = Offset(wx - camX, wy - camY)

            drawRect(color = biome.groundBase, size = size)
            val tileSize = 140f
            val startCol = floor(camX / tileSize).toInt() - 1
            val endCol = floor((camX + size.width) / tileSize).toInt() + 1
            val startRow = floor(camY / tileSize).toInt() - 1
            val endRow = floor((camY + size.height) / tileSize).toInt() + 1

            for (r in startRow..endRow) {
                for (c in startCol..endCol) {
                    val tx = c * tileSize - camX
                    val ty = r * tileSize - camY
                    val hash = ((c * 73856093) xor (r * 19349663)) and 0x7FFFFFFF
                    if (hash % 3 == 0) {
                        drawOval(
                            color = biome.groundAlt.copy(alpha = 0.62f),
                            topLeft = Offset(tx - 14f, ty - 10f),
                            size = Size(tileSize * 1.16f, tileSize * 0.90f)
                        )
                    }
                    if (hash % 2 == 0) {
                        val ox = tx + (hash % 88) + 22f
                        val oy = ty + ((hash / 11) % 88) + 22f
                        val sway = sin(elapsedSec * 2.4f + (hash % 13)) * 2.5f
                        drawLine(biome.accentColor.copy(alpha = 0.65f), Offset(ox, oy), Offset(ox - 5f + sway, oy - 11f), 3f, StrokeCap.Round)
                        drawLine(biome.accentColor.copy(alpha = 0.72f), Offset(ox, oy), Offset(ox + 4f + sway, oy - 14f), 3.2f, StrokeCap.Round)
                    }
                }
            }

            val centerPt = toScreen(0f, 0f)
            drawCircle(biome.pathColor.copy(alpha = 0.36f), 280f, centerPt, style = Stroke(width = 56f))
            drawCircle(CreamSurface.copy(alpha = 0.22f), 280f, centerPt, style = Stroke(width = 4f))
            drawCircle(biome.pathColor.copy(alpha = 0.28f), 620f, centerPt, style = Stroke(width = 48f))

            val tl = toScreen(-worldHalfSize, -worldHalfSize)
            drawRect(EspressoDark.copy(alpha = 0.40f), tl, Size(worldHalfSize * 2f, worldHalfSize * 2f), style = Stroke(18f))
            drawRect(CreamSurface.copy(alpha = 0.55f), tl, Size(worldHalfSize * 2f, worldHalfSize * 2f), style = Stroke(4f))

            // Elevated High-Ground Practice Plateau (for 2.5D Jump -> Air-Glide -> Drop-Slam drills)
            drawRoamHighGroundPlateau(trainingPlateau, biome, ::toScreen)

            for (obs in obstacles) {
                val pos = toScreen(obs.x, obs.y)
                if (pos.x < -120f || pos.x > size.width + 120f || pos.y < -120f || pos.y > size.height + 120f) continue
                drawRoamObstacle(obs, pos, elapsedSec)
            }

            // Interactive Training Dummy
            drawRoamTrainingDummy(trainingDummy, elapsedSec, ::toScreen)

            for (orb in starOrbs) {
                if (orb.collectedCooldown > 0f) continue
                val pos = toScreen(orb.x, orb.y)
                if (pos.x < -60f || pos.x > size.width + 60f || pos.y < -60f || pos.y > size.height + 60f) continue
                val bob = sin(elapsedSec * 4.2f + orb.id) * 5f
                val p = Offset(pos.x, pos.y + bob)
                drawCircle(GoldAccent.copy(alpha = 0.28f), 22f, p)
                drawCircle(GoldAccent, 11f, p)
                drawCircle(Color.White.copy(alpha = 0.9f), 5f, Offset(p.x - 2f, p.y - 2f))
                drawCircle(EspressoDark, 11f, p, style = Stroke(2.2f))
            }

            val wpx = moveState.waypointX
            val wpy = moveState.waypointY
            if (wpx != null && wpy != null) {
                val wp = toScreen(wpx, wpy)
                val pulse = 18f + sin(elapsedSec * 7f) * 5f
                drawCircle(moveState.profile.accentTrailColor.copy(alpha = 0.28f), pulse * 1.5f, wp)
                drawCircle(moveState.profile.accentTrailColor, pulse, wp, style = Stroke(3.5f))
                drawCircle(Color.White, 5f, wp)
            }

            for (pt in moveState.trailPoints) {
                val pos = toScreen(pt.x, pt.y)
                when {
                    pt.isDash -> {
                        drawCircle(pt.color.copy(alpha = pt.alpha * 0.55f), pt.radius * (0.55f + 0.45f * pt.alpha), pos)
                        drawCircle(Color.White.copy(alpha = pt.alpha * 0.45f), pt.radius * 0.45f, pos)
                    }
                    activeStarterId == "shell" -> {
                        val ringR = pt.radius * (1.8f - pt.alpha * 0.8f)
                        drawCircle(pt.color.copy(alpha = pt.alpha * 0.65f), ringR, pos, style = Stroke(3.2f))
                    }
                    activeStarterId == "char" -> {
                        drawCircle(pt.color.copy(alpha = pt.alpha * 0.75f), pt.radius * pt.alpha, pos)
                        drawCircle(GoldAccent.copy(alpha = pt.alpha * 0.85f), pt.radius * pt.alpha * 0.48f, pos)
                    }
                    else -> {
                        rotate(degrees = pt.x * 0.6f, pivot = pos) {
                            drawOval(
                                pt.color.copy(alpha = pt.alpha * 0.78f),
                                topLeft = Offset(pos.x - pt.radius, pos.y - pt.radius * 0.55f),
                                size = Size(pt.radius * 2f, pt.radius * 1.1f)
                            )
                        }
                    }
                }
            }

            for (ring in burstRings) {
                val pos = toScreen(ring.x, ring.y)
                val alpha = (ring.life / ring.maxLife).coerceIn(0f, 1f)
                drawCircle(ring.color.copy(alpha = alpha * 0.85f), ring.radius, pos, style = Stroke(6.5f))
            }

            val heroGroundPos = toScreen(moveState.x, moveState.y - jumpPhysics.groundZ)
            val heroAirPos = toScreen(moveState.x, moveState.y - heroZDisplay)

            // Ground shadow when jumping or gliding
            val isHeroAirborne = heroZDisplay > jumpPhysics.groundZ + 2f
            if (isHeroAirborne) {
                val airAlt = (heroZDisplay - jumpPhysics.groundZ).coerceAtLeast(0f)
                val shadowScale = (1f - airAlt / 220f).coerceIn(0.45f, 1f)
                drawOval(
                    color = Color.Black.copy(alpha = 0.28f * shadowScale),
                    topLeft = Offset(heroGroundPos.x - 24f * shadowScale, heroGroundPos.y + 10f),
                    size = Size(48f * shadowScale, 16f * shadowScale)
                )
            }

            if (moveState.speedRatio > 0.10f) {
                val dirX = cos(moveState.facingAngle)
                val dirY = sin(moveState.facingAngle)
                val tip = Offset(heroAirPos.x + dirX * 48f, heroAirPos.y + dirY * 48f + 12f)
                val sideL = Offset(heroAirPos.x + cos(moveState.facingAngle + 0.42f) * 34f, heroAirPos.y + sin(moveState.facingAngle + 0.42f) * 34f + 12f)
                val sideR = Offset(heroAirPos.x + cos(moveState.facingAngle - 0.42f) * 34f, heroAirPos.y + sin(moveState.facingAngle - 0.42f) * 34f + 12f)
                val chevron = Path().apply {
                    moveTo(sideL.x, sideL.y)
                    lineTo(tip.x, tip.y)
                    lineTo(sideR.x, sideR.y)
                }
                drawPath(
                    chevron,
                    color = moveState.profile.accentTrailColor.copy(alpha = 0.88f),
                    style = Stroke(width = 4.8f, cap = StrokeCap.Round)
                )
            }

            if (cosmeticLoadout.hasStarlightEntrance) {
                drawStarlightEntranceAura(
                    center = heroAirPos,
                    radius = 34f,
                    animTime = elapsedSec,
                    subtle = true
                )
            }
            drawEvolvedHeroSprite(
                style = visualNode.visualStyle.withCosmeticLoadout(cosmeticLoadout, foxSkinEquipped),
                center = heroAirPos,
                baseRadius = 32f,
                animTime = elapsedSec * 1.9f,
                orbitAngle = orbitAngle,
                facingAngle = moveState.facingAngle,
                moveSpeedRatio = moveState.speedRatio,
                isAttacking = attackFlashTimer > 0f,
                isHurt = false,
                isUltActive = moveState.onSpeedPad || ultBurstFlashTimer > 0f,
                leanDeg = moveState.leanDeg,
                attackProgress = (attackFlashTimer / 0.26f).coerceIn(0f, 1f),
                evolutionFxProgress = (evolutionFxTimer / 1.35f).coerceIn(0f, 1f),
                walkCycle = moveState.walkCycle,
                isDashing = moveState.isDashing,
                isAirborne = isHeroAirborne,
                isGliding = isGlidingDisplay
            )

            // Training Move & Ult Projectiles + Floating Damage Numbers
            drawRoamTrainingProjectiles(trainingProjectiles, ::toScreen)
            drawRoamFloatingDamages(trainingFloats, ::toScreen, damagePaints.first, damagePaints.second)
        }

        // 2. FLOATING 360° ANALOG VIRTUAL JOYSTICK
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(0.55f)
                .align(Alignment.BottomStart)
                .testTag("roam_joystick_zone")
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { start ->
                            joyOrigin = start
                            joyThumb = start
                        },
                        onDrag = { change, _ ->
                            val origin = joyOrigin ?: return@detectDragGestures
                            val maxRadius = 115f
                            val dx = change.position.x - origin.x
                            val dy = change.position.y - origin.y
                            val dist = hypot(dx, dy)
                            val clamped = if (dist > maxRadius) {
                                Offset(origin.x + dx / dist * maxRadius, origin.y + dy / dist * maxRadius)
                            } else change.position
                            joyThumb = clamped
                            controller.setAnalogInput(
                                (clamped.x - origin.x) / maxRadius,
                                (clamped.y - origin.y) / maxRadius
                            )
                        },
                        onDragEnd = {
                            joyOrigin = null
                            joyThumb = null
                            controller.setAnalogInput(0f, 0f)
                        },
                        onDragCancel = {
                            joyOrigin = null
                            joyThumb = null
                            controller.setAnalogInput(0f, 0f)
                        }
                    )
                }
        ) {
            val origin = joyOrigin
            val thumb = joyThumb
            if (origin != null && thumb != null) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val accent = moveState.profile.trailColor
                    drawCircle(HudInkDark.copy(alpha = 0.34f), 112f, origin)
                    drawCircle(accent.copy(alpha = 0.72f), 112f, origin, style = Stroke(width = 4.5f))
                    drawCircle(CreamSurface.copy(alpha = 0.22f), 18f, origin, style = Stroke(width = 2f))
                    drawLine(accent.copy(alpha = 0.65f), origin, thumb, strokeWidth = 6f, cap = StrokeCap.Round)
                    drawCircle(CreamSurface.copy(alpha = 0.94f), 40f, thumb)
                    drawCircle(DarkButtonRim, 40f, thumb, style = Stroke(width = 3.5f))
                }
            }
        }

        val isLandscapeRoam = (maxWidth > maxHeight && maxWidth >= 540.dp) || maxHeight < 460.dp
        val isShortRoam = maxHeight < 420.dp
        val isCompactRoam = maxWidth < 430.dp || isShortRoam
        val roamPad = if (isCompactRoam) 10.dp else 14.dp
        val roamMapSize = when {
            isLandscapeRoam && maxHeight < 420.dp -> 60.dp
            isCompactRoam -> 64.dp
            else -> 76.dp
        }
        val roamAvatarSize = when {
            isLandscapeRoam && maxHeight < 420.dp -> 30.dp
            isCompactRoam -> 34.dp
            else -> 38.dp
        }
        val roamDashSize = when {
            isLandscapeRoam && maxHeight < 420.dp -> 58.dp
            isCompactRoam -> 62.dp
            else -> 68.dp
        }
        val roamTierSize = when {
            isLandscapeRoam && maxHeight < 420.dp -> 46.dp
            isCompactRoam -> 50.dp
            else -> 54.dp
        }

        // Safe-area HUD container matching LandscapeBattleHud edge distribution
        Box(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = roamPad, vertical = if (isLandscapeRoam) 6.dp else 10.dp)
        ) {
            // 3. TOP HUD BAR: Unified Dark-Glass Back + Telemetry Pill + Live DPS Card + Directional Radar Minimap
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .testTag("roam_back_btn")
                            .minimumInteractiveComponentSize()
                            .size(if (isCompactRoam) 40.dp else 44.dp)
                            .shadow(5.dp, CircleShape)
                            .clip(CircleShape)
                            .background(HudInkDark.copy(alpha = 0.88f))
                            .border(1.6.dp, Color.White.copy(alpha = 0.24f), CircleShape)
                            .clickable(onClick = onBack),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回主菜单", tint = Color.White)
                    }

                    Column(
                        modifier = Modifier
                            .widthIn(max = if (isLandscapeRoam) 220.dp else 280.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(HudInkDark.copy(alpha = 0.88f))
                            .border(1.8.dp, moveState.profile.trailColor.copy(alpha = 0.85f), RoundedCornerShape(16.dp))
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "${visualNode.nameZh} · 试炼场",
                                style = MaterialTheme.typography.titleSmall.copy(fontSize = if (isCompactRoam) 11.sp else 12.5.sp),
                                color = Color.White,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f, fill = false)
                            )
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(50))
                                    .background(moveState.profile.trailColor)
                                    .padding(horizontal = 5.5.dp, vertical = 1.dp)
                            ) {
                                Text(
                                    text = "${currentFps.toInt()} FPS",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp),
                                    color = EspressoDark
                                )
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                            Box(
                                modifier = Modifier
                                    .width(if (isCompactRoam) 44.dp else 62.dp)
                                    .height(5.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(Color.White.copy(alpha = 0.16f))
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(moveState.speedRatio.coerceIn(0f, 1f))
                                        .clip(RoundedCornerShape(50))
                                        .background(moveState.profile.accentTrailColor)
                                )
                            }
                            Text(
                                text = "${moveState.speed.toInt()} px/s",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = moveState.profile.accentTrailColor,
                                maxLines = 1
                            )
                            Text(
                                text = "★ $orbsCollected",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = GoldAccent,
                                maxLines = 1
                            )
                        }
                    }

                    // Landscape: inline live DPS / Peak Crit / Combo telemetry card in top bar
                    if (isLandscapeRoam) {
                        RoamDpsTelemetryCard(
                            liveDps = liveDpsDisplay,
                            peakHit = peakHitDisplay,
                            comboCount = comboCountDisplay,
                            isOnHighGround = isOnHighGroundDisplay,
                            autoFireEnabled = autoFireEnabled,
                            compact = isShortRoam,
                            onToggleAutoFire = { autoFireEnabled = !autoFireEnabled },
                            onResetStats = {
                                trainingDummy.reset()
                                liveDpsDisplay = 0
                                peakHitDisplay = 0
                                comboCountDisplay = 0
                            }
                        )
                    }
                }

                // Directional Radar Minimap (includes Training Dummy + High-Ground Plateau markers)
                Box(
                    modifier = Modifier
                        .size(roamMapSize)
                        .shadow(6.dp, CircleShape)
                        .clip(CircleShape)
                        .background(HudInkDark.copy(alpha = 0.88f))
                        .border(2.2.dp, DarkButtonRim, CircleShape)
                ) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        val c = Offset(size.width / 2f, size.height / 2f)
                        val mapR = size.width / 2f - 5f
                        val scale = mapR / worldHalfSize
                        drawCircle(Color.White.copy(alpha = 0.10f), mapR * 0.55f, c, style = Stroke(1f))
                        // High-ground plateau marker
                        drawOval(
                            color = GrassGreen.copy(alpha = 0.45f),
                            topLeft = Offset(c.x + (trainingPlateau.x - trainingPlateau.rx) * scale, c.y + (trainingPlateau.y - trainingPlateau.ry) * scale),
                            size = Size(trainingPlateau.rx * 2f * scale, trainingPlateau.ry * 2f * scale)
                        )
                        // Training Dummy marker
                        drawCircle(Color(0xFFFF4D6D), 4.2f, Offset(c.x + trainingDummy.x * scale, c.y + trainingDummy.y * scale))
                        for (obs in obstacles) {
                            val pt = Offset(c.x + obs.x * scale, c.y + obs.y * scale)
                            val col = when (obs.kind) {
                                MapObstacleKind.SPEED_PAD -> GoldAccent
                                MapObstacleKind.POND -> SkyBlue
                                else -> Color.White.copy(alpha = 0.35f)
                            }
                            drawCircle(col, if (obs.kind == MapObstacleKind.POND) 3.2f else 2.2f, pt)
                        }
                        for (orb in starOrbs) {
                            if (orb.collectedCooldown > 0f) continue
                            drawCircle(GoldAccent, 2.5f, Offset(c.x + orb.x * scale, c.y + orb.y * scale))
                        }
                        val playerPt = Offset(c.x + moveState.x * scale, c.y + moveState.y * scale)
                        val rad = moveState.facingAngle
                        val tip = Offset(playerPt.x + cos(rad) * 7.5f, playerPt.y + sin(rad) * 7.5f)
                        val left = Offset(playerPt.x + cos(rad + 2.35f) * 4.5f, playerPt.y + sin(rad + 2.35f) * 4.5f)
                        val right = Offset(playerPt.x + cos(rad - 2.35f) * 4.5f, playerPt.y + sin(rad - 2.35f) * 4.5f)
                        val arrow = Path().apply {
                            moveTo(tip.x, tip.y)
                            lineTo(left.x, left.y)
                            lineTo(right.x, right.y)
                            close()
                        }
                        drawPath(arrow, color = moveState.profile.trailColor)
                        drawCircle(Color.White, 2f, playerPt)
                    }
                }
            }

            // Portrait: DPS telemetry card cleanly docked below top bar + brief onboarding hint
            if (!isLandscapeRoam) {
                Column(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 64.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    RoamDpsTelemetryCard(
                        liveDps = liveDpsDisplay,
                        peakHit = peakHitDisplay,
                        comboCount = comboCountDisplay,
                        isOnHighGround = isOnHighGroundDisplay,
                        autoFireEnabled = autoFireEnabled,
                        compact = isCompactRoam,
                        onToggleAutoFire = { autoFireEnabled = !autoFireEnabled },
                        onResetStats = {
                            trainingDummy.reset()
                            liveDpsDisplay = 0
                            peakHitDisplay = 0
                            comboCountDisplay = 0
                        }
                    )
                    AnimatedVisibility(
                        visible = moveState.speed < 12f && elapsedSec < 6.0f && trainingDummy.totalDamage == 0L,
                        enter = fadeIn(),
                        exit = fadeOut()
                    ) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(HudInkDark.copy(alpha = 0.84f))
                                .border(1.3.dp, GoldAccent.copy(alpha = 0.72f), RoundedCornerShape(50))
                                .padding(horizontal = 12.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = "右侧试招打桩 · 左侧高台练习跳滑坠击！",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = CreamSurface
                            )
                        }
                    }
                }
            }

            // 4. BOTTOM CONTROLS: Landscape centers the 6-Sprite Dock & keeps right cluster at BottomEnd (matching Battle HUD)
            if (isLandscapeRoam) {
                // Centered bottom 6-Sprite Switcher Dock
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .widthIn(max = 420.dp)
                        .shadow(8.dp, RoundedCornerShape(18.dp))
                        .clip(RoundedCornerShape(18.dp))
                        .background(HudInkDark.copy(alpha = 0.90f))
                        .border(2.dp, DarkButtonRim, RoundedCornerShape(18.dp))
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = 6.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    for (id in allStarterIds) {
                        val starter = remember(id) { GameCatalog.starterById(id) }
                        val profile = remember(id) { SpriteLocomotionProfiles.forStarter(id) }
                        val selected = id == activeStarterId
                        Column(
                            modifier = Modifier
                                .testTag("roam_switch_$id")
                                .minimumInteractiveComponentSize()
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (selected) profile.trailColor.copy(alpha = 0.28f) else Color.Transparent)
                                .border(
                                    width = if (selected) 2.dp else 1.dp,
                                    color = if (selected) profile.trailColor else Color.White.copy(alpha = 0.16f),
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { switchSprite(id) }
                                .padding(horizontal = 6.dp, vertical = 3.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            StarterPortraitAvatar(
                                portraitRes = starter.portraitRes,
                                ringColor = if (selected) profile.trailColor else SandstoneRim,
                                size = roamAvatarSize
                            )
                            Text(
                                text = starter.codeName,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp),
                                color = if (selected) Color.White else CreamSurface.copy(alpha = 0.78f),
                                maxLines = 1
                            )
                        }
                    }
                }

                // Bottom-Right Training Action Cluster (Move Trial, Ult Burst, 2.5D Jump/Glide, Evolution Tier, Dash)
                Box(modifier = Modifier.align(Alignment.BottomEnd)) {
                    RoamActionClusterButtons(
                        previewTier = previewTier,
                        moveState = moveState,
                        isJumping = isJumpingDisplay,
                        isGliding = isGlidingDisplay,
                        jumpCooldownRatio = jumpCdRatioDisplay,
                        roamTierSize = roamTierSize,
                        roamDashSize = roamDashSize,
                        onToggleTier = {
                            previewTier = (previewTier + 1) % 3
                            evolutionFxTimer = 1.35f
                            burstRings.add(RoamBurstRing(controller.x, controller.y, 16f, 118f, GoldAccent, 0.42f, 0.42f))
                        },
                        onTriggerDash = { triggerDash() },
                        onTriggerJump = { triggerJumpOrGlide() },
                        onTriggerMoveTrial = { triggerMoveTrial() },
                        onTriggerUltTrial = { triggerUltTrial() }
                    )
                }
            } else {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 4.dp)
                        .align(Alignment.BottomCenter),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.Bottom
                ) {
                    // Scrollable 6-Sprite Switcher Dock
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .shadow(8.dp, RoundedCornerShape(20.dp))
                            .clip(RoundedCornerShape(20.dp))
                            .background(HudInkDark.copy(alpha = 0.90f))
                            .border(2.dp, DarkButtonRim, RoundedCornerShape(20.dp))
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = 7.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        for (id in allStarterIds) {
                            val starter = remember(id) { GameCatalog.starterById(id) }
                            val profile = remember(id) { SpriteLocomotionProfiles.forStarter(id) }
                            val selected = id == activeStarterId
                            Column(
                                modifier = Modifier
                                    .testTag("roam_switch_$id")
                                    .minimumInteractiveComponentSize()
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(if (selected) profile.trailColor.copy(alpha = 0.28f) else Color.Transparent)
                                    .border(
                                        width = if (selected) 2.2.dp else 1.dp,
                                        color = if (selected) profile.trailColor else Color.White.copy(alpha = 0.16f),
                                        shape = RoundedCornerShape(14.dp)
                                    )
                                    .clickable { switchSprite(id) }
                                    .padding(horizontal = 7.dp, vertical = 5.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                StarterPortraitAvatar(
                                    portraitRes = starter.portraitRes,
                                    ringColor = if (selected) profile.trailColor else SandstoneRim,
                                    size = roamAvatarSize
                                )
                                Spacer(Modifier.height(2.dp))
                                Text(
                                    text = starter.codeName,
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                                    color = if (selected) Color.White else CreamSurface.copy(alpha = 0.78f),
                                    maxLines = 1
                                )
                            }
                        }
                    }

                    RoamActionClusterButtons(
                        previewTier = previewTier,
                        moveState = moveState,
                        isJumping = isJumpingDisplay,
                        isGliding = isGlidingDisplay,
                        jumpCooldownRatio = jumpCdRatioDisplay,
                        roamTierSize = roamTierSize,
                        roamDashSize = roamDashSize,
                        onToggleTier = {
                            previewTier = (previewTier + 1) % 3
                            evolutionFxTimer = 1.35f
                            burstRings.add(RoamBurstRing(controller.x, controller.y, 16f, 118f, GoldAccent, 0.42f, 0.42f))
                        },
                        onTriggerDash = { triggerDash() },
                        onTriggerJump = { triggerJumpOrGlide() },
                        onTriggerMoveTrial = { triggerMoveTrial() },
                        onTriggerUltTrial = { triggerUltTrial() }
                    )
                }
            }
        }
    }
}

@Composable
private fun RoamActionClusterButtons(
    previewTier: Int,
    moveState: SpriteMovementState,
    isJumping: Boolean,
    isGliding: Boolean,
    jumpCooldownRatio: Float,
    roamTierSize: androidx.compose.ui.unit.Dp,
    roamDashSize: androidx.compose.ui.unit.Dp,
    onToggleTier: () -> Unit,
    onTriggerDash: () -> Unit,
    onTriggerJump: () -> Unit,
    onTriggerMoveTrial: () -> Unit,
    onTriggerUltTrial: () -> Unit
) {
    val subSize = roamTierSize
    Column(
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        // Row 1: Evolution Form Tier + 2.5D Jump/Glide/Slam + Ult Burst Trial
        Row(
            horizontalArrangement = Arrangement.spacedBy(7.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .testTag("roam_tier_toggle_btn")
                    .minimumInteractiveComponentSize()
                    .size(subSize)
                    .shadow(6.dp, CircleShape)
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(listOf(WarmOrange, GoldAccent)))
                    .border(2.2.dp, DarkButtonRim, CircleShape)
                    .clickable(onClick = onToggleTier),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.AutoAwesome, contentDescription = "切换形态", tint = EspressoDark, modifier = Modifier.size(15.dp))
                    Text("${previewTier + 1}阶", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = EspressoDark)
                }
            }

            val jumpReady = isJumping || jumpCooldownRatio <= 0.01f
            val jumpColors = when {
                isGliding -> listOf(Color(0xFFFFC857), WarmOrange)
                isJumping -> listOf(Color(0xFF9DF7FF), GoldAccent)
                else -> listOf(Color(0xFF7BE8FF), SkyBlue)
            }
            Box(
                modifier = Modifier
                    .testTag("roam_jump_btn")
                    .minimumInteractiveComponentSize()
                    .size(subSize)
                    .shadow(6.dp, CircleShape)
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(jumpColors))
                    .border(2.2.dp, if (isJumping) CreamSurface else DarkButtonRim, CircleShape)
                    .clickable(enabled = jumpReady, onClick = onTriggerJump),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = if (isGliding) Icons.Rounded.Bolt else Icons.Rounded.KeyboardDoubleArrowUp,
                        contentDescription = "跳跃滑翔坠击",
                        tint = EspressoDark,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = when {
                            isGliding -> "坠击"
                            isJumping -> "滑翔"
                            else -> "跳跃"
                        },
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                        color = EspressoDark
                    )
                }
            }

            Box(
                modifier = Modifier
                    .testTag("roam_ult_trial_btn")
                    .minimumInteractiveComponentSize()
                    .size(subSize)
                    .shadow(7.dp, CircleShape)
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(listOf(Color(0xFFFF5CE6), WarmOrange)))
                    .border(2.2.dp, GoldAccent, CircleShape)
                    .clickable(onClick = onTriggerUltTrial),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.Whatshot, contentDescription = "试放必杀技", tint = Color.White, modifier = Modifier.size(16.dp))
                    Text("必杀", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = Color.White)
                }
            }
        }

        // Row 2: Dash + Primary Signature Move Trial
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            val dashReady = moveState.dashCooldownRatio <= 0.01f
            val dashProgress = (1f - moveState.dashCooldownRatio).coerceIn(0f, 1f)
            Box(
                modifier = Modifier
                    .testTag("roam_dash_btn")
                    .minimumInteractiveComponentSize()
                    .size(subSize)
                    .shadow(if (dashReady) 7.dp else 3.dp, CircleShape)
                    .clip(CircleShape)
                    .background(
                        Brush.verticalGradient(
                            if (dashReady) listOf(moveState.profile.accentTrailColor, moveState.profile.trailColor)
                            else listOf(Color(0xFF3E4E47), Color(0xFF283430))
                        )
                    )
                    .border(2.4.dp, if (dashReady) DarkButtonRim else HudInkDark, CircleShape)
                    .clickable(enabled = dashReady, onClick = onTriggerDash),
                contentAlignment = Alignment.Center
            ) {
                if (!dashReady) {
                    Canvas(modifier = Modifier.fillMaxSize().padding(3.dp)) {
                        val strokeW = 3.dp.toPx()
                        drawArc(
                            color = Color.White.copy(alpha = 0.14f),
                            startAngle = -90f,
                            sweepAngle = 360f,
                            useCenter = false,
                            style = Stroke(width = strokeW, cap = StrokeCap.Round)
                        )
                        drawArc(
                            color = moveState.profile.accentTrailColor,
                            startAngle = -90f,
                            sweepAngle = 360f * dashProgress,
                            useCenter = false,
                            style = Stroke(width = strokeW, cap = StrokeCap.Round)
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = if (moveState.onSpeedPad) Icons.Rounded.Speed else Icons.AutoMirrored.Rounded.DirectionsRun,
                        contentDescription = "冲刺闪避",
                        tint = if (dashReady) EspressoDark else Color.White.copy(alpha = 0.78f),
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = if (dashReady) "冲刺" else "${"%.1f".format(moveState.dashCooldownRatio * moveState.profile.dashCooldownSec)}s",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                        color = if (dashReady) EspressoDark else CreamSurface.copy(alpha = 0.88f)
                    )
                }
            }

            // Primary Signature Move Trial Button
            Box(
                modifier = Modifier
                    .testTag("roam_move_trial_btn")
                    .minimumInteractiveComponentSize()
                    .size(roamDashSize)
                    .shadow(8.dp, CircleShape)
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(listOf(GoldAccent, WarmOrange)))
                    .border(2.8.dp, CreamSurface, CircleShape)
                    .clickable(onClick = onTriggerMoveTrial),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.Bolt, contentDescription = "释放专属试招", tint = EspressoDark, modifier = Modifier.size(22.dp))
                    Text("试招", style = MaterialTheme.typography.labelLarge.copy(fontSize = 10.5.sp), color = EspressoDark)
                }
            }
        }
    }
}

private fun DrawScope.drawRoamObstacle(obs: MapObstacle, pos: Offset, time: Float) {
    when (obs.kind) {
        MapObstacleKind.SPEED_PAD -> {
            val pulse = 0.88f + 0.14f * sin(time * 6f + obs.id)
            val padRadius = (obs.radius * 1.45f * pulse).coerceAtLeast(1f)
            drawCircle(
                Brush.radialGradient(listOf(GoldAccent.copy(alpha = 0.52f), Color.Transparent), pos, padRadius),
                radius = padRadius,
                center = pos
            )
            drawCircle(Color(0xFF283A4E).copy(alpha = 0.85f), obs.radius, pos)
            drawCircle(GoldAccent, obs.radius, pos, style = Stroke(4f))
            for (k in -1..1 step 2) {
                val yOff = k * 8f + sin(time * 8f) * 3f
                val p = Path().apply {
                    moveTo(pos.x - 14f, pos.y + yOff + 6f)
                    lineTo(pos.x, pos.y + yOff - 8f)
                    lineTo(pos.x + 14f, pos.y + yOff + 6f)
                }
                drawPath(p, GoldAccent, style = Stroke(4f, cap = StrokeCap.Round))
            }
        }
        MapObstacleKind.TREE -> {
            drawOval(Color.Black.copy(alpha = 0.24f), Offset(pos.x - obs.radius * 0.95f, pos.y + obs.radius * 0.45f), Size(obs.radius * 1.9f, obs.radius * 0.65f))
            drawRoundRect(Color(0xFF7A4B2A), Offset(pos.x - 11f, pos.y - 6f), Size(22f, obs.radius * 0.95f), CornerRadius(6f, 6f))
            val sway = sin(time * 2.2f + obs.id) * 3f
            drawCircle(GrassGreenDeep, obs.radius * 0.98f, Offset(pos.x + sway, pos.y - obs.radius * 0.35f))
            drawCircle(GrassGreen, obs.radius * 0.78f, Offset(pos.x - 6f + sway, pos.y - obs.radius * 0.55f))
            drawCircle(EspressoDark, obs.radius * 0.98f, Offset(pos.x + sway, pos.y - obs.radius * 0.35f), style = Stroke(3f))
        }
        MapObstacleKind.BOULDER -> {
            drawOval(Color.Black.copy(alpha = 0.22f), Offset(pos.x - obs.radius, pos.y + obs.radius * 0.36f), Size(obs.radius * 2f, obs.radius * 0.6f))
            drawCircle(Color(0xFF8C929C), obs.radius, pos)
            drawCircle(Color(0xFFB5BCC7), obs.radius * 0.64f, Offset(pos.x - obs.radius * 0.2f, pos.y - obs.radius * 0.22f))
            drawCircle(EspressoDark, obs.radius, pos, style = Stroke(3f))
        }
        MapObstacleKind.POND -> {
            val ripple = 0.94f + 0.06f * sin(time * 3.2f + obs.id)
            drawCircle(Color(0xFF3CA8DB).copy(alpha = 0.85f), obs.radius, pos)
            drawCircle(Color(0xFF8FE9FF).copy(alpha = 0.45f), obs.radius * 0.68f * ripple, pos, style = Stroke(3.5f))
            drawCircle(Color(0xFFE9D8B0), obs.radius, pos, style = Stroke(5.5f))
            drawCircle(EspressoDark, obs.radius + 2.5f, pos, style = Stroke(2.5f))
        }
    }
}
