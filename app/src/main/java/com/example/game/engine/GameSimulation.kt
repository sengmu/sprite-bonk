package com.example.game.engine

import androidx.compose.ui.graphics.Color
import com.example.game.audio.SfxType
import com.example.game.evolution.EvolutionNode
import com.example.game.evolution.EvolutionPathController
import com.example.game.evolution.EvolutionRegistry
import com.example.game.evolution.EvolutionResourceType
import com.example.game.movement.SpriteMovementController
import com.example.game.movement.SpriteMovementState
import com.example.game.model.BiomeDef
import com.example.game.model.ChallengeModifier
import com.example.game.model.ElementType
import com.example.game.model.ElementalBondId
import com.example.game.model.ElementalBondSystem
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryBonuses
import com.example.game.model.MetaMasteryCalculator
import com.example.game.model.MoveArchetype
import com.example.game.model.MoveDef
import com.example.game.model.Rarity
import com.example.game.model.StarterLine
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

class GameSimulation(
    private val starter: StarterLine,
    private val biome: BiomeDef,
    private val gameMode: GameMode = GameMode.CLASSIC,
    private val labLevels: Map<String, Int>,
    var autoAimEnabled: Boolean,
    var screenShakeEnabled: Boolean,
    private val onSfx: (SfxType) -> Unit,
    private val onHaptic: () -> Unit,
    private val onHitHaptic: (Float) -> Unit = { onHaptic() },
    private val masteryBonuses: MetaMasteryBonuses = MetaMasteryBonuses(),
    private val challengeModifiers: Set<ChallengeModifier> = emptySet(),
    private val onSfxPitch: (SfxType, Float) -> Unit = { type, _ -> onSfx(type) }
) {
    private val rng = Random(System.currentTimeMillis())
    private var nextId = 1
    private val globalHitTrigger = GlobalHitFeedbackTrigger(
        onHitTriggered = { intensity -> onHitHaptic(intensity) }
    )
    private val challengeEnemyHpMult = challengeModifiers.fold(1f) { acc, m -> acc * m.enemyHpMult }
    private val challengeEnemySpeedMult = challengeModifiers.fold(1f) { acc, m -> acc * m.enemySpeedMult }
    private val challengeSpawnRateMult = challengeModifiers.fold(1f) { acc, m -> acc * m.spawnRateMult }
    private val challengePlayerDmgMult = challengeModifiers.fold(1f) { acc, m -> acc * m.playerDmgMult }
    private val challengePlayerTakenMult = challengeModifiers.fold(1f) { acc, m -> acc * m.playerTakenMult }
    private val challengeEliteBonus = challengeModifiers.fold(0f) { acc, m -> acc + m.eliteChanceBonus }
    private val challengeStardustBonusPct = MetaMasteryCalculator.combinedChallengeStardustBonusPct(challengeModifiers)

    val arenaHalfSize = 1450f
    private val terrainLayout = ArenaTerrainLayout.generate(biome.id, arenaHalfSize)

    // Player smooth locomotion & 2.5D vertical jump / plateau elevation state
    private val movementController = SpriteMovementController(initialStarterId = starter.id)
    private var movementState = SpriteMovementState(starterId = starter.id)
    private var playerX = 0f
    private var playerY = 0f
    private var playerZ = 0f
    private var playerGroundZ = 0f
    private var playerVz = 0f
    private var airbornePeakZ = 0f
    private var takeoffGroundZ = 0f
    private var jumpCooldown = 0f
    private val jumpCooldownTotal = 0.72f
    private var isGliding = false
    private var glideTimer = 0f
    private val glideMaxDuration = 1.25f
    private var coverBlockFloatCooldown = 0f
    private var highGroundFloatCooldown = 0f
    private var facingAngle = 0f
    private var walkAnimTime = 0f
    private var orbitAngle = 0f

    // Combat & growth stats
    private var hp = 100f
    private var maxHp = 100f
    private var armor = 0f
    private var speedMult = 1f
    private var damageMult = 1f
    private var atkSpdMult = 1f
    private var areaMult = 1f
    private var critChance = 0.08f
    private var xpMult = 1f
    private var goldMult = 1f
    private var regenPerSec = 0f
    private var luck = 0f
    private var magnetRadius = 115f
    private var ultRateMult = 1f
    private var revivesRemaining = 0

    private val evolutionController = EvolutionPathController(starter.id)
    private var level = 1
    private var evolutionStage = 0
    private var isEvolutionModalOpen = false
    private var lastReadyEvoCount = 0
    val unlockedEvolutionsThisRun = mutableSetOf(evolutionController.currentNodeId)
    private var xp = 0f
    private var xpToNext = 38f
    private var kills = 0
    private var coins = 0
    private var chestsOpened = 0
    private var elapsedSec = 0f

    // Timers
    private var invulnTimer = 0f
    private var hurtFlashTimer = 0f
    private var attackFlashTimer = 0f
    private var dashActiveTimer = 0f
    private var dashGhostEmitTimer = 0f
    private var dashCooldown = 0f
    private val dashCooldownTotal: Float = if (starter.id == "spark") 1.65f else 2.4f
    private var dashDirX = 1f
    private var dashDirY = 0f
    private var biomeBannerTimer = 2.8f
    private var evolutionBannerText: String? = null
    private var evolutionBannerTimer = 0f
    private var screenShakeMagnitude = 0f

    // Pillar 2: Micro-Hitstop & Dynamic Camera Zoom tension + Pillar 1: Biome Eco state
    private var hitstopTimer = 0f
    private var hitstopCooldown = 0f
    private var cameraZoom = 1f
    private var targetCameraZoom = 1f
    private var activeEcoBuffZh: String? = null
    private var ecoSpeedMult = 1f
    private var ecoFloatCooldown = 0f
    private var lavaHitCooldown = 0f

    // Ult controller
    private var ultCharge = 0.25f
    private var ultActiveTimer = 0f
    private var ultWaveCooldown = 0f
    private var ultWavesRemaining = 0
    private var ultReadyAnnounced = false
    private var killRoom = 0.032f

    // Hyper-Awakening (Prismatic Mega-style burst fueled by Hyper Shards)
    private var hyperCharge = 0.20f
    private var hyperActiveTimer = 0f
    private val hyperMaxDuration = 12f
    private var hyperReadyAnnounced = false

    // Risk-vs-Reward Shrine & Magnet Obelisk state
    private var gambleDamageBonus = 0f
    private var magnetVacuumTimer = 0f

    // Combo & Score Multiplier
    private var comboCount = 0
    private var comboTimer = 0f
    private val comboWindowSec = 3.6f
    private var maxCombo = 0
    private var runScore = 0

    // Draft utilities, Lab Expansions, Fusion Overclock & Synergies
    private val maxMoveSlots: Int = 4 + (labLevels["move_slot"] ?: 0).coerceIn(0, 1)
    private val vitAmpMult: Float = 1f + (labLevels["vit_amp"] ?: 0) * 0.12f
    private var rerollsLeft = 1
    private var skipsLeft = 1
    private var banishesLeft = 1
    private var banishModeArmed = false
    private val banishedIds = mutableSetOf<String>()
    private val vitaminLevels = mutableMapOf<String, Int>()
    private val moveSlots = mutableListOf<InternalMoveSlot>()
    private val awakenedMoveIds = mutableSetOf<String>()
    private val fusedMoveIds = mutableSetOf<String>()
    private val overclockedMoveIds = mutableSetOf<String>()
    private var activeBonds: List<ElementalBondId> = emptyList()
    private var electroChainCooldown = 0f
    private var bossPortalEarlyBonusPct = 0
    private var bossAlertBannerText: String? = null
    private var bossAlertBannerTimer = 0f
    private var pendingDraftCount = 0
    private var draftOptions: List<DraftOption>? = null
    private var isPaused = false
    private var runSummary: RunSummary? = null

    // Wave / Spawner / Boss / Dynamic Events
    private var spawnTimer = 0.4f
    private var propSpawnTimer = 6f
    private var bossSpawned = false
    private var bossDefeated = false
    private var nextBossTimeSec = 68f
    private var bossesClearedCount = 0
    private var nextWaveEventSec = 24f
    private var waveEventIndex = 0
    private var activeWaveEventKind = -1 // 0=Swarm, 1=Gold, 2=Dual-Elite, 3=Stardust Mimic, 4=Risk Altar
    private var activeWaveEventTitleZh: String? = null
    private var activeWaveEventTimer = 0f
    private val activeWaveEventDuration = 16f
    private var ultTotalDamageDealt = 0f

    val seenEnemyCounts = mutableMapOf<String, Int>()
    val defeatedEnemyCounts = mutableMapOf<String, Int>()

    private val enemies = mutableListOf<InternalEnemy>()
    private val projectiles = mutableListOf<InternalProjectile>()
    private val rings = mutableListOf<InternalRing>()
    private val slashArcs = mutableListOf<InternalSlashArc>()
    private val particles = mutableListOf<InternalParticle>()
    private val dashGhosts = mutableListOf<InternalDashGhost>()
    private val pickups = mutableListOf<InternalPickup>()
    private val props = mutableListOf<InternalProp>()
    private val floatingNumbers = mutableListOf<InternalFloatText>()
    private var frameTick = 0L

    private class InternalMoveSlot(
        val def: MoveDef,
        var level: Int,
        var cooldown: Float,
        var totalDamageDealt: Float = 0f
    )

    private class InternalEnemy(
        val id: Int,
        val defId: String,
        var x: Float,
        var y: Float,
        val radius: Float,
        var hp: Float,
        val maxHp: Float,
        val speed: Float,
        val contactDamage: Float,
        val xpValue: Int,
        val isBoss: Boolean,
        val isElite: Boolean,
        val primaryColor: Color,
        val secondaryColor: Color,
        var hitFlash: Float = 0f,
        var slowTimer: Float = 0f,
        var burnTimer: Float = 0f,
        var burnTick: Float = 0f,
        var vxKnock: Float = 0f,
        var vyKnock: Float = 0f,
        var telegraphTimer: Float = 0f,
        var telegraphCooldown: Float = 5.5f,
        var animPhase: Float = 0f,
        var facingLeft: Boolean = false,
        var groundZ: Float = 0f,
        var z: Float = groundZ,
        var vz: Float = 0f,
        var leapCooldown: Float = 1.6f,
        var rangedCooldown: Float = 2.8f,
        var bossPhase: Int = 1,
        var telegraphKind: BossAttackKind = BossAttackKind.NONE,
        var telegraphDuration: Float = 1.15f,
        var chargeDirX: Float = 0f,
        var chargeDirY: Float = 0f,
        var chargeActiveTimer: Float = 0f,
        var chargeHitPlayer: Boolean = false,
        var staggerTimer: Float = 0f,
        var bossAttackCycle: Int = 0,
        var lanternVulnerableTimer: Float = 0f
    )

    private class InternalProjectile(
        val id: Int,
        var x: Float,
        var y: Float,
        val vx: Float,
        val vy: Float,
        val radius: Float,
        val damage: Float,
        val color: Color,
        val element: ElementType,
        val knockback: Float,
        val burns: Boolean,
        val slows: Boolean,
        var life: Float,
        val maxLife: Float,
        val isBeam: Boolean = false,
        val endX: Float = 0f,
        val endY: Float = 0f,
        val pierce: Int = 1,
        val sourceMoveId: String? = null,
        val isEnemy: Boolean = false,
        val z: Float = 0f,
        val isHighGroundBoosted: Boolean = false,
        val isAwakened: Boolean = false,
        val hitSet: MutableSet<Int> = mutableSetOf()
    )

    private class InternalRing(
        val x: Float,
        val y: Float,
        var radius: Float,
        val maxRadius: Float,
        val color: Color,
        var life: Float,
        val maxLife: Float
    )

    private class InternalSlashArc(
        val x: Float,
        val y: Float,
        val angleRad: Float,
        val radius: Float,
        val color: Color,
        var life: Float,
        val maxLife: Float,
        val isAwakened: Boolean = false
    )

    private class InternalParticle(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        var size: Float,
        val color: Color,
        var life: Float,
        val maxLife: Float,
        val shape: ParticleShape = ParticleShape.DOT,
        var angleRad: Float = 0f
    )

    private class InternalDashGhost(
        val x: Float,
        val y: Float,
        var life: Float,
        val maxLife: Float,
        val color: Color
    )

    private class InternalPickup(
        val id: Int,
        val kind: PickupKind,
        var x: Float,
        var y: Float,
        val value: Int
    )

    private class InternalProp(
        val id: Int,
        val kind: WorldPropKind,
        val x: Float,
        val y: Float,
        var opened: Boolean = false
    )

    private class InternalFloatText(
        val id: Int,
        var x: Float,
        var y: Float,
        val text: String,
        val color: Color,
        val isCrit: Boolean,
        var life: Float,
        val maxLife: Float
    )

    init {
        recomputeStats(resetHp = true)
        rerollsLeft = 1 + (labLevels["reroll"] ?: 0)
        skipsLeft = 1 + (labLevels["skip"] ?: 0)
        banishesLeft = 1 + (labLevels["banish"] ?: 0)
        revivesRemaining = labLevels["revive"] ?: 0

        val firstMoveId = starter.signatureMoves.first()
        GameCatalog.moves[firstMoveId]?.let { def ->
            moveSlots.add(InternalMoveSlot(def, level = 1, cooldown = 0.25f))
        }

        if (gameMode == GameMode.DUEL) {
            level = 4
            xpToNext = 38f + level * 18f + level * level * 1.4f
            ultCharge = 0.65f
            bossAlertBannerText = "⚔ 1v1 守护者决斗 · 双轮构筑即刻开战"
            bossAlertBannerTimer = 3.2f
            spawnPropNearPlayer(WorldPropKind.HEAL_SHRINE, 320f, 460f)
            spawnPropNearPlayer(WorldPropKind.FUSION_MACHINE, 360f, 520f)
            repeat(2) { spawnEnemy(forceElite = false) }
            pendingDraftCount = 1
            openDraftModal()
        } else {
            spawnPropNearPlayer(WorldPropKind.WOODEN_CHEST, 250f, 360f)
            spawnPropNearPlayer(WorldPropKind.WOODEN_CHEST, 460f, 640f)
            spawnPropNearPlayer(WorldPropKind.HEAL_SHRINE, 390f, 560f)
            spawnPropNearPlayer(WorldPropKind.GAMBLE_SHRINE, 420f, 620f)
            spawnPropNearPlayer(WorldPropKind.MAGNET_OBELISK, 500f, 680f)
            if (gameMode == GameMode.CLASSIC) {
                spawnPropNearPlayer(WorldPropKind.BOSS_PORTAL, 540f, 740f)
                spawnPropNearPlayer(WorldPropKind.FUSION_MACHINE, 460f, 660f)
            } else {
                spawnPropNearPlayer(WorldPropKind.FUSION_MACHINE, 480f, 680f)
            }
            repeat(5) { spawnEnemy(forceElite = false) }
        }
        onSfx(SfxType.START)
    }

    private fun recomputeStats(resetHp: Boolean = false) {
        val prevMax = maxHp
        val labDmg = (labLevels["dmg"] ?: 0) * 0.06f
        val labHp = (labLevels["hp"] ?: 0) * 14f
        val labSpd = (labLevels["spd"] ?: 0) * 0.035f
        val labAtkSpd = (labLevels["atkspd"] ?: 0) * 0.04f
        val labCrit = (labLevels["crit"] ?: 0) * 0.025f
        val labArea = (labLevels["area"] ?: 0) * 0.05f
        val labArmor = (labLevels["armor"] ?: 0) * 3f
        val labRegen = (labLevels["regen"] ?: 0) * 0.4f
        val labUlt = (labLevels["ult"] ?: 0) * 0.08f
        val labXp = (labLevels["xp"] ?: 0) * 0.08f
        val labGold = (labLevels["gold"] ?: 0) * 0.10f
        val labMagnet = (labLevels["magnet"] ?: 0) * 0.18f
        val labLuck = (labLevels["luck"] ?: 0) * 8f

        val evoDelta = evolutionController.cumulativeStatDelta()
        val vitDmg = (vitaminLevels["protein"] ?: 0) * 0.12f * vitAmpMult
        val vitArmor = (vitaminLevels["iron"] ?: 0) * 5f * vitAmpMult
        val vitSpd = (vitaminLevels["carbos"] ?: 0) * 0.08f * vitAmpMult
        val vitHp = (vitaminLevels["hp_up"] ?: 0) * 22f * vitAmpMult
        val vitAtkSpd = (vitaminLevels["ether"] ?: 0) * 0.10f * vitAmpMult
        val vitCrit = (vitaminLevels["dire_hit"] ?: 0) * 0.07f * vitAmpMult
        val vitXp = (vitaminLevels["exp_candy"] ?: 0) * 0.15f * vitAmpMult
        val vitGold = (vitaminLevels["nugget"] ?: 0) * 0.18f * vitAmpMult
        val vitRegen = (vitaminLevels["super_potion"] ?: 0) * 1.0f * vitAmpMult
        val vitLuck = (vitaminLevels["star_piece"] ?: 0) * 12f * vitAmpMult

        maxHp = starter.baseHp + labHp + vitHp + evoDelta.maxHpFlat + masteryBonuses.maxHpFlatBonus
        if (resetHp) {
            hp = maxHp
        } else if (maxHp > prevMax) {
            hp = min(maxHp, hp + (maxHp - prevMax))
        }
        val isHyper = hyperActiveTimer > 0f
        armor = starter.baseArmor + labArmor + vitArmor + evoDelta.armorFlat + if (starter.id == "shell") 8f else 0f
        speedMult = (1f + labSpd + vitSpd + evoDelta.speedPct + if (starter.id == "spark") 0.14f else 0f) * if (isHyper) 1.22f else 1f
        damageMult = starter.baseDamage * (1f + labDmg + vitDmg + evoDelta.damagePct + masteryBonuses.damageBonusPct + gambleDamageBonus + if (starter.id == "drake") 0.10f else 0f) * challengePlayerDmgMult * if (isHyper) 1.45f else 1f
        atkSpdMult = (1f + labAtkSpd + vitAtkSpd) * if (isHyper) 1.35f else 1f
        areaMult = (1f + labArea + evoDelta.areaPct + if (starter.id == "stump" || starter.id == "drake") 0.12f else 0f) * if (isHyper) 1.25f else 1f
        critChance = 0.08f + labCrit + vitCrit + evoDelta.critPct + masteryBonuses.critBonusPct + when (starter.id) {
            "char" -> 0.10f
            "spark" -> 0.12f
            else -> 0f
        }
        xpMult = 1f + labXp + vitXp + if (starter.id == "drake") 0.12f else 0f
        goldMult = 1f + labGold + vitGold
        regenPerSec = labRegen + vitRegen + evoDelta.regenFlat + if (starter.id == "stump") 1.2f else 0f
        luck = labLuck + vitLuck
        magnetRadius = 120f * (1f + labMagnet)
        ultRateMult = 1f + labUlt + evoDelta.ultChargePct + masteryBonuses.ultChargeBonusPct + if (starter.id == "wisp") 0.18f else 0f
    }

    fun setJoystickInput(dx: Float, dy: Float) {
        movementController.setAnalogInput(dx, dy)
    }

    fun setKeyboardInput(dx: Float, dy: Float) {
        movementController.setKeyboardInput(dx, dy)
    }

    fun togglePause() {
        if (runSummary != null || draftOptions != null || isEvolutionModalOpen) return
        isPaused = !isPaused
        onSfx(SfxType.PANEL)
    }

    fun resume() {
        isPaused = false
    }

    fun openEvolutionModal() {
        if (runSummary != null || draftOptions != null) return
        isEvolutionModalOpen = true
        onSfx(SfxType.PANEL)
    }

    fun closeEvolutionModal() {
        isEvolutionModalOpen = false
    }

    fun evolveToBranch(targetNodeId: String): EvolutionNode? {
        val evolved = evolutionController.evolveTo(targetNodeId, level) ?: return null
        applyEvolutionSuccess(evolved)
        isEvolutionModalOpen = false
        return evolved
    }

    private fun applyEvolutionSuccess(evolved: EvolutionNode) {
        evolutionStage = evolved.tier
        unlockedEvolutionsThisRun.add(evolved.id)
        recomputeStats(resetHp = false)
        hp = min(maxHp, hp + maxHp * 0.28f)

        evolved.bonusMoveId?.let { moveId ->
            val existing = moveSlots.firstOrNull { it.def.id == moveId }
            if (existing != null) {
                existing.level = (existing.level + 1).coerceAtMost(8)
            } else if (moveSlots.size < maxMoveSlots) {
                GameCatalog.moves[moveId]?.let { def ->
                    moveSlots.add(InternalMoveSlot(def, level = 1, cooldown = 0.2f))
                }
            }
        }

        evolutionBannerText = "分支进化：${evolved.nameZh}!"
        evolutionBannerTimer = 3.4f
        rings.add(InternalRing(playerX, playerY, 24f, 270f, evolved.visualStyle.auraColor, 0.7f, 0.7f))
        emitBurst(playerX, playerY, 30, evolved.visualStyle.auraColor, ParticleShape.SPARK, 340f)
        triggerShake(11f)
        onSfx(SfxType.EVOLVE)
        onHaptic()
        lastReadyEvoCount = evolutionController.readyNextNodes(level).size
    }

    fun triggerDash() {
        if (isPaused || isEvolutionModalOpen || draftOptions != null || runSummary != null) return
        if (!movementController.triggerDash(speedMultiplier = speedMult, baseSpeedOverride = starter.baseSpeed)) return
        dashActiveTimer = movementController.dashActiveTimer
        dashGhostEmitTimer = 0f
        dashCooldown = movementController.dashCooldownTimer
        invulnTimer = maxOf(invulnTimer, 0.34f)
        facingAngle = movementController.facingAngle
        // Slight vault hop during dash so dashing smoothly clears low ledges too
        if (playerZ <= playerGroundZ + 2f) {
            takeoffGroundZ = playerGroundZ
            airbornePeakZ = playerZ
            playerVz = maxOf(playerVz, 225f)
        }
        rings.add(InternalRing(playerX, playerY, 18f, 78f, starter.element.color, 0.28f, 0.28f))
        emitBurst(playerX, playerY, 10, starter.element.color, ParticleShape.SPARK, 180f)
        onSfx(SfxType.DODGE)
        onHaptic()
    }

    /**
     * 2.5D Jump -> Air Glide -> Drop Slam triad:
     * 1) Grounded tap launches into a 2.5D jump arc onto plateaus / over hazards.
     * 2) Second tap while airborne deploys luminous Air Glide wings (+24% air speed, soft float).
     * 3) Third tap while gliding cancels wings into a fast Drop Slam dive!
     */
    fun triggerJump() {
        if (isPaused || isEvolutionModalOpen || draftOptions != null || runSummary != null) return
        val isGrounded = playerZ <= playerGroundZ + 3f && playerVz <= 0f
        if (isGrounded) {
            if (jumpCooldown > 0f) return
            takeoffGroundZ = playerGroundZ
            airbornePeakZ = playerZ
            playerVz = 315f
            jumpCooldown = jumpCooldownTotal
            isGliding = false
            glideTimer = glideMaxDuration
            invulnTimer = maxOf(invulnTimer, 0.22f)
            emitBurst(playerX, playerY + 10f, 8, biome.pathColor, ParticleShape.LEAF, 125f)
            rings.add(InternalRing(playerX, playerY + 8f, 12f, 54f, Color(0xFFFFF4D6), 0.22f, 0.22f))
            onSfx(SfxType.DODGE)
            onHaptic()
        } else if (playerZ > playerGroundZ + 8f) {
            if (!isGliding && glideTimer > 0.10f) {
                isGliding = true
                playerVz = maxOf(playerVz, -35f)
                invulnTimer = maxOf(invulnTimer, 0.20f)
                rings.add(InternalRing(playerX, playerY - playerZ + 6f, 14f, 68f, Color(0xFF7BE8FF), 0.26f, 0.26f))
                emitBurst(playerX, playerY - playerZ + 4f, 10, Color(0xFF7BE8FF), ParticleShape.SPARK, 155f)
                onSfxPitch(SfxType.DODGE, 1.28f)
                onHaptic()
            } else if (isGliding) {
                isGliding = false
                playerVz = -480f
                emitBurst(playerX, playerY - playerZ, 8, GoldAccent, ParticleShape.SPARK, 170f)
                onSfxPitch(SfxType.DODGE, 0.85f)
            }
        }
    }

    fun triggerUlt() {
        if (isPaused || isEvolutionModalOpen || draftOptions != null || runSummary != null) return
        if (ultCharge < 1f) return
        ultCharge = 0f
        ultReadyAnnounced = false
        ultActiveTimer = 2.1f
        ultWavesRemaining = 3
        ultWaveCooldown = 0.05f
        invulnTimer = maxOf(invulnTimer, 0.9f)
        triggerShake(14f)
        onHaptic()
        emitBurst(playerX, playerY, 22, GoldAccent, ParticleShape.SPARK, 320f)
        when (starter.element) {
            ElementType.GRASS, ElementType.GHOST -> {
                onSfx(SfxType.ULT_GRASS)
                hp = min(maxHp, hp + maxHp * 0.25f)
                spawnFloat(playerX, playerY - 34f, "+${(maxHp * 0.25f).toInt()} HP", GrassGreen, isCrit = true)
            }
            ElementType.FIRE, ElementType.ELECTRIC -> onSfx(SfxType.ULT_FIRE)
            ElementType.WATER, ElementType.STAR -> onSfx(SfxType.ULT_WATER)
            else -> onSfx(SfxType.ULT_GRASS)
        }
    }

    private fun currentScoreMultiplier(): Float = when {
        comboCount >= 60 -> 5.0f
        comboCount >= 40 -> 4.0f
        comboCount >= 25 -> 3.0f
        comboCount >= 12 -> 2.0f
        comboCount >= 5 -> 1.5f
        else -> 1.0f
    }

    private fun addHyperCharge(amount: Float) {
        if (hyperActiveTimer > 0f) return
        hyperCharge = min(1f, hyperCharge + amount)
        if (hyperCharge >= 1f && !hyperReadyAnnounced) {
            hyperReadyAnnounced = true
            evolutionBannerText = "⚡ 超觉醒充能满载！点击左上解放!"
            evolutionBannerTimer = 2.8f
            rings.add(InternalRing(playerX, playerY, 20f, 190f, Color(0xFFFF66E5), 0.55f, 0.55f))
            onSfx(SfxType.ULT_READY)
        }
    }

    fun triggerHyperAwakening() {
        if (isPaused || isEvolutionModalOpen || draftOptions != null || runSummary != null) return
        if (hyperCharge < 1f || hyperActiveTimer > 0f) return
        hyperCharge = 0f
        hyperReadyAnnounced = false
        hyperActiveTimer = hyperMaxDuration
        recomputeStats(resetHp = false)
        invulnTimer = maxOf(invulnTimer, 1.2f)
        val healAmt = maxHp * 0.20f
        hp = min(maxHp, hp + healAmt)

        val blastRadius = 290f
        val blastDmg = 56f * damageMult
        for (ei in enemies.lastIndex downTo 0) {
            if (ei >= enemies.size) continue
            val e = enemies[ei]
            val d = hypot(e.x - playerX, e.y - playerY)
            if (d <= blastRadius + e.radius) {
                val a = atan2(e.y - playerY, e.x - playerX)
                damageEnemy(e, blastDmg, isUlt = true, knockAngle = a, knockForce = 260f, burn = false, slow = true)
            }
        }
        rings.add(InternalRing(playerX, playerY, 24f, blastRadius, Color(0xFFFF66E5), 0.65f, 0.65f))
        rings.add(InternalRing(playerX, playerY, 16f, blastRadius * 0.78f, Color(0xFF5CF6FF), 0.50f, 0.50f))
        emitBurst(playerX, playerY, 32, Color(0xFFFFD84D), ParticleShape.SPARK, 360f)
        evolutionBannerText = "⚡ 超觉醒解放！全属性暴涨 12 秒!"
        evolutionBannerTimer = 3.0f
        spawnFloat(playerX, playerY - 40f, "超觉醒 +${healAmt.toInt()} HP!", Color(0xFFFF7AF6), isCrit = true)
        triggerShake(13f)
        onSfx(SfxType.EVOLVE)
        onHaptic()
    }

    fun triggerInteract() {
        if (isPaused || isEvolutionModalOpen || draftOptions != null || runSummary != null) return
        val prop = findNearbyProp() ?: return
        prop.opened = true
        when (prop.kind) {
            WorldPropKind.WOODEN_CHEST -> {
                chestsOpened++
                val bonusCoins = (28 + level * 6)
                coins += (bonusCoins * goldMult).toInt()
                runScore += (120 * currentScoreMultiplier()).toInt()
                // Burst out collectible evolution essences + stardust core + hyper shard!
                val primaryEssence = pickupKindForResource(EvolutionRegistry.resourceForElement(starter.element))
                val altRes = EvolutionResourceType.entries
                    .filter { it != EvolutionResourceType.STARDUST_CORE }
                    .random(rng)
                pickups.add(InternalPickup(nextId++, primaryEssence, prop.x - 24f, prop.y + 18f, 1))
                pickups.add(InternalPickup(nextId++, pickupKindForResource(altRes), prop.x + 26f, prop.y + 16f, 1))
                pickups.add(InternalPickup(nextId++, PickupKind.STARDUST_CORE, prop.x, prop.y - 26f, 1))
                pickups.add(InternalPickup(nextId++, PickupKind.HYPER_SHARD, prop.x + 22f, prop.y - 18f, 1))

                onSfx(SfxType.CHEST)
                onHaptic()
                rings.add(InternalRing(prop.x, prop.y, 20f, 138f, GoldAccent, 0.45f, 0.45f))
                emitBurst(prop.x, prop.y, 20, GoldAccent, ParticleShape.SPARK, 260f)
                spawnFloat(prop.x, prop.y - 26f, "宝箱 +$bonusCoins 金币 & 星核!", GoldAccent, isCrit = true)
                openDraftModal()
            }
            WorldPropKind.HEAL_SHRINE -> {
                val heal = maxHp * 0.45f
                hp = min(maxHp, hp + heal)
                ultCharge = min(1f, ultCharge + 0.25f)
                addHyperCharge(0.15f)
                val primaryRes = EvolutionRegistry.resourceForElement(starter.element)
                evolutionController.addResource(primaryRes, 1)
                evolutionController.addResource(EvolutionResourceType.STARDUST_CORE, 1)
                checkEvolutionReadyHint()
                onSfx(SfxType.LEVEL_UP)
                onHaptic()
                rings.add(InternalRing(prop.x, prop.y, 20f, 150f, Color(0xFFC25AFF), 0.5f, 0.5f))
                emitBurst(prop.x, prop.y, 18, Color(0xFF7AFF8A), ParticleShape.SPARK, 220f)
                spawnFloat(prop.x, prop.y - 26f, "圣坛回复 +${heal.toInt()} HP & 进化星核!", Color(0xFF7AFF8A), isCrit = true)
            }
            WorldPropKind.GAMBLE_SHRINE -> {
                // High-risk, high-reward shrine: ambush wave in exchange for permanent DMG, coins, hyper charge & instant draft!
                repeat(6) { idx ->
                    spawnAmbushEnemyAround(prop.x, prop.y, forceElite = idx < 2)
                }
                gambleDamageBonus += 0.18f
                recomputeStats(resetHp = false)
                addHyperCharge(0.40f)
                val rewardCoins = (85 * goldMult).toInt()
                coins += rewardCoins
                runScore += (260 * currentScoreMultiplier()).toInt()
                onSfx(SfxType.CHEST)
                onHaptic()
                triggerShake(10f)
                rings.add(InternalRing(prop.x, prop.y, 24f, 220f, CrimsonRed, 0.55f, 0.55f))
                rings.add(InternalRing(prop.x, prop.y, 16f, 160f, GoldAccent, 0.42f, 0.42f))
                emitBurst(prop.x, prop.y, 24, CrimsonRed, ParticleShape.SPARK, 290f)
                spawnFloat(prop.x, prop.y - 30f, "试炼祭坛！攻击+18% · +$rewardCoins 金币!", GoldAccent, isCrit = true)
                openDraftModal()
            }
            WorldPropKind.MAGNET_OBELISK -> {
                magnetVacuumTimer = 3.2f
                addHyperCharge(0.20f)
                runScore += (120 * currentScoreMultiplier()).toInt()
                onSfx(SfxType.ULT_READY)
                onHaptic()
                rings.add(InternalRing(prop.x, prop.y, 22f, 280f, SkyBlue, 0.6f, 0.6f))
                emitBurst(prop.x, prop.y, 22, Color(0xFF66F4FF), ParticleShape.SPARK, 260f)
                spawnFloat(prop.x, prop.y - 28f, "磁吸脉冲！全图战利品聚拢!", Color(0xFF66F4FF), isCrit = true)
            }
            WorldPropKind.BOSS_PORTAL -> {
                if (!bossSpawned) {
                    bossSpawned = true
                    bossPortalEarlyBonusPct = 20
                    val heal = maxHp * 0.30f
                    hp = min(maxHp, hp + heal)
                    ultCharge = min(1f, ultCharge + 0.25f)
                    addHyperCharge(0.20f)
                    runScore += (320 * currentScoreMultiplier()).toInt()
                    rings.add(InternalRing(prop.x, prop.y, 24f, 280f, CrimsonRed, 0.65f, 0.65f))
                    rings.add(InternalRing(prop.x, prop.y, 18f, 210f, GoldAccent, 0.50f, 0.50f))
                    emitBurst(prop.x, prop.y, 28, CrimsonRed, ParticleShape.SPARK, 310f)
                    spawnBoss()
                    evolutionBannerText = "传送门启封！先手迎战守护者 · 星尘+20%"
                    evolutionBannerTimer = 3.4f
                    spawnFloat(prop.x, prop.y - 34f, "先手挑战！回复+${heal.toInt()} · 星尘+20%", GoldAccent, isCrit = true)
                    openDraftModal()
                } else {
                    ultCharge = min(1f, ultCharge + 0.35f)
                    addHyperCharge(0.25f)
                    val bonusCoins = (65 * goldMult).toInt()
                    coins += bonusCoins
                    onSfx(SfxType.ULT_READY)
                    onHaptic()
                    rings.add(InternalRing(prop.x, prop.y, 20f, 200f, GoldAccent, 0.50f, 0.50f))
                    emitBurst(prop.x, prop.y, 18, GoldAccent, ParticleShape.SPARK, 240f)
                    spawnFloat(prop.x, prop.y - 28f, "传送门共鸣！必杀+35% · +$bonusCoins 金币", GoldAccent, isCrit = true)
                }
            }
            WorldPropKind.FUSION_MACHINE -> {
                val unfusedSlot = moveSlots
                    .filter { !fusedMoveIds.contains(it.def.id) }
                    .maxByOrNull { it.level }
                val targetSlot = unfusedSlot
                    ?: moveSlots.filter { !overclockedMoveIds.contains(it.def.id) }.maxByOrNull { it.level }
                    ?: moveSlots.maxByOrNull { it.level }
                if (targetSlot != null) {
                    val isTierTwoOverclock = fusedMoveIds.contains(targetSlot.def.id)
                    if (isTierTwoOverclock) {
                        overclockedMoveIds.add(targetSlot.def.id)
                        targetSlot.level = (targetSlot.level + 1).coerceAtMost(9)
                    } else {
                        fusedMoveIds.add(targetSlot.def.id)
                        targetSlot.level = (targetSlot.level + 1).coerceAtMost(8)
                    }
                    val fusedName = if (isTierTwoOverclock) {
                        GameCatalog.overclockFusionTitle(targetSlot.def.id)
                    } else {
                        GameCatalog.fusedMoveTitle(targetSlot.def.id)
                    }
                    val shockDmg = (if (isTierTwoOverclock) 118f else 75f) * damageMult
                    val shockRadius = if (isTierTwoOverclock) 310f else 260f
                    for (ei in enemies.lastIndex downTo 0) {
                        if (ei >= enemies.size) continue
                        val e = enemies[ei]
                        if (hypot(e.x - prop.x, e.y - prop.y) <= shockRadius + e.radius) {
                            val ka = atan2(e.y - prop.y, e.x - prop.x)
                            damageEnemy(e, shockDmg, isUlt = false, knockAngle = ka, knockForce = 260f, burn = isTierTwoOverclock, slow = true)
                        }
                    }
                    addHyperCharge(if (isTierTwoOverclock) 0.35f else 0.25f)
                    runScore += ((if (isTierTwoOverclock) 440 else 280) * currentScoreMultiplier()).toInt()
                    triggerShake(if (isTierTwoOverclock) 13f else 10f)
                    triggerHitstop(if (isTierTwoOverclock) 0.042f else 0.032f, 0.042f)
                    rings.add(InternalRing(prop.x, prop.y, 22f, shockRadius, Color(0xFF5CF6FF), 0.65f, 0.65f))
                    rings.add(InternalRing(prop.x, prop.y, 16f, shockRadius * 0.78f, GoldAccent, 0.52f, 0.52f))
                    emitBurst(prop.x, prop.y, if (isTierTwoOverclock) 34 else 28, if (isTierTwoOverclock) GoldAccent else Color(0xFF5CF6FF), ParticleShape.SPARK, 340f)
                    evolutionBannerText = if (isTierTwoOverclock) {
                        "✧二阶超频融合：$fusedName 究极解放!"
                    } else {
                        "✦奇术融合：$fusedName 超频觉醒！"
                    }
                    evolutionBannerTimer = 3.5f
                    spawnFloat(
                        prop.x,
                        prop.y - 34f,
                        if (isTierTwoOverclock) "✧二阶超频：$fusedName!" else "✦融合超频：$fusedName!",
                        if (isTierTwoOverclock) GoldAccent else Color(0xFF7BE8FF),
                        isCrit = true
                    )
                    refreshElementalBonds(announceNew = true)
                    onSfx(SfxType.EVOLVE)
                    onHaptic()
                }
            }
        }
    }

    fun selectDraftOption(optionId: String): EvolutionNode? {
        val options = draftOptions ?: return null
        val chosen = options.firstOrNull { it.id == optionId } ?: return null
        if (banishModeArmed && banishesLeft > 0) {
            // Evolution form cards cannot be banished so players never lock out evolution
            if (chosen.optionKind == DraftOptionKind.EVOLUTION_FORM) {
                banishModeArmed = false
                onSfx(SfxType.PANEL)
                return null
            }
            banishesLeft--
            banishModeArmed = false
            banishedIds.add(chosen.moveId ?: chosen.vitaminId ?: chosen.id)
            draftOptions = generateDraftOptions()
            onSfx(SfxType.PANEL)
            return null
        }

        var unlockedEvo: EvolutionNode? = null
        when (chosen.optionKind) {
            DraftOptionKind.EVOLUTION_FORM -> {
                val evoId = chosen.evolutionNodeId
                if (evoId != null) {
                    val evolved = evolutionController.evolveFromLevelUpReward(evoId)
                    if (evolved != null) {
                        applyEvolutionSuccess(evolved)
                        unlockedEvo = evolved
                    }
                }
            }
            DraftOptionKind.SKILL_UPGRADE -> {
                val moveId = chosen.moveId
                if (moveId != null) {
                    val existing = moveSlots.firstOrNull { it.def.id == moveId }
                    if (existing != null) {
                        existing.level++
                    } else if (moveSlots.size < maxMoveSlots) {
                        GameCatalog.moves[moveId]?.let { def ->
                            moveSlots.add(InternalMoveSlot(def, level = 1, cooldown = 0.2f))
                        }
                    }
                }
            }
            DraftOptionKind.VITAMIN_BOOST -> {
                val vitId = chosen.vitaminId
                if (vitId != null) {
                    val bonusLevels = if (chosen.rarity == Rarity.LEGENDARY) 2 else 1
                    vitaminLevels[vitId] = (vitaminLevels[vitId] ?: 0) + bonusLevels
                    recomputeStats(resetHp = false)
                }
            }
        }

        draftOptions = null
        banishModeArmed = false
        checkMoveSynergies()
        if (unlockedEvo == null) {
            emitBurst(playerX, playerY, 14, GoldAccent, ParticleShape.SPARK, 210f)
            onSfx(SfxType.PANEL)
        }
        advancePostDraftFlow()
        return unlockedEvo
    }

    private fun advancePostDraftFlow() {
        if (pendingDraftCount > 0) {
            pendingDraftCount--
            openDraftModal()
        } else if (gameMode == GameMode.DUEL && !bossSpawned) {
            bossSpawned = true
            spawnBoss()
        }
    }

    private fun checkMoveSynergies() {
        for (slot in moveSlots) {
            if (awakenedMoveIds.contains(slot.def.id)) continue
            if (slot.level < 2) continue
            val syn = GameCatalog.synergyForMove(slot.def.id) ?: continue
            if ((vitaminLevels[syn.vitaminId] ?: 0) >= 1) {
                awakenedMoveIds.add(slot.def.id)
                evolutionBannerText = "协同觉醒：${syn.evolvedNameZh}!"
                evolutionBannerTimer = 3.2f
                rings.add(InternalRing(playerX, playerY, 22f, 240f, GoldAccent, 0.6f, 0.6f))
                emitBurst(playerX, playerY, 24, GoldAccent, ParticleShape.SPARK, 300f)
                onSfx(SfxType.EVOLVE)
                onHaptic()
            }
        }
        refreshElementalBonds(announceNew = true)
    }

    private fun refreshElementalBonds(announceNew: Boolean) {
        val prev = activeBonds.toSet()
        val updated = ElementalBondSystem.evaluateActiveBonds(
            moveElements = moveSlots.map { it.def.type },
            moveLevels = moveSlots.map { it.level },
            vitaminLevels = vitaminLevels,
            awakenedCount = awakenedMoveIds.size,
            fusedCount = fusedMoveIds.size + overclockedMoveIds.size
        )
        activeBonds = updated
        if (announceNew) {
            val newlyUnlocked = updated.firstOrNull { it !in prev }
            if (newlyUnlocked != null) {
                if (evolutionBannerText == null) {
                    evolutionBannerText = "✦元素羁绊激活：${newlyUnlocked.titleZh}!"
                    evolutionBannerTimer = 3.2f
                }
                rings.add(InternalRing(playerX, playerY, 18f, 220f, newlyUnlocked.accentColor, 0.55f, 0.55f))
                emitBurst(playerX, playerY, 18, newlyUnlocked.accentColor, ParticleShape.SPARK, 260f)
                spawnFloat(playerX, playerY - 48f, "${newlyUnlocked.shortBadgeZh} 激活!", newlyUnlocked.accentColor, isCrit = true)
                onSfx(SfxType.LEVEL_UP)
            }
        }
    }

    fun rerollDraft() {
        if (draftOptions == null || rerollsLeft <= 0) return
        rerollsLeft--
        banishModeArmed = false
        draftOptions = generateDraftOptions()
        onSfx(SfxType.PANEL)
    }

    fun skipDraft() {
        if (draftOptions == null || skipsLeft <= 0) return
        skipsLeft--
        banishModeArmed = false
        draftOptions = null
        xp += xpToNext * 0.25f
        onSfx(SfxType.PANEL)
        advancePostDraftFlow()
    }

    fun toggleBanishMode() {
        if (draftOptions == null || banishesLeft <= 0) return
        banishModeArmed = !banishModeArmed
        onSfx(SfxType.PANEL)
    }

    fun abandonRun(): RunSummary = finishRun(victory = false)

    private fun triggerHitstop(durationSec: Float, zoomBoost: Float = 0.024f) {
        targetCameraZoom = maxOf(targetCameraZoom, (1f + zoomBoost).coerceAtMost(1.052f))
        if (hitstopCooldown <= 0f) {
            hitstopTimer = maxOf(hitstopTimer, durationSec.coerceAtMost(0.052f))
            hitstopCooldown = 0.24f
        }
    }

    private fun comboPitch(): Float = (0.96f + comboCount * 0.014f).coerceIn(0.96f, 1.32f)

    fun step(rawDt: Float): BattleRenderState {
        val dt = rawDt.coerceIn(0.001f, 0.05f)
        frameTick++
        if (!isPaused && !isEvolutionModalOpen && draftOptions == null) {
            globalHitTrigger.step(dt)
            if (hitstopCooldown > 0f) hitstopCooldown = (hitstopCooldown - dt).coerceAtLeast(0f)
            if (runSummary == null) {
                if (hitstopTimer > 0f) {
                    hitstopTimer = (hitstopTimer - dt).coerceAtLeast(0f)
                } else {
                    simulate(dt)
                }
            }
            cameraZoom += (targetCameraZoom - cameraZoom) * min(1f, dt * 16f)
            targetCameraZoom += (1f - targetCameraZoom) * min(1f, dt * 6.5f)
            if (abs(cameraZoom - 1f) < 0.0005f && abs(targetCameraZoom - 1f) < 0.0005f) {
                cameraZoom = 1f
                targetCameraZoom = 1f
            }
        }
        return buildSnapshot()
    }

    private fun simulate(dt: Float) {
        elapsedSec += dt
        orbitAngle = (orbitAngle + dt * 4.5f) % (2f * PI.toFloat())
        if (biomeBannerTimer > 0f) biomeBannerTimer = (biomeBannerTimer - dt).coerceAtLeast(0f)
        if (bossAlertBannerTimer > 0f) {
            bossAlertBannerTimer = (bossAlertBannerTimer - dt).coerceAtLeast(0f)
            if (bossAlertBannerTimer <= 0f) bossAlertBannerText = null
        }
        if (electroChainCooldown > 0f) electroChainCooldown = (electroChainCooldown - dt).coerceAtLeast(0f)
        if (evolutionBannerTimer > 0f) {
            evolutionBannerTimer = (evolutionBannerTimer - dt).coerceAtLeast(0f)
            if (evolutionBannerTimer <= 0f) evolutionBannerText = null
        }
        if (invulnTimer > 0f) invulnTimer = (invulnTimer - dt).coerceAtLeast(0f)
        if (hurtFlashTimer > 0f) hurtFlashTimer = (hurtFlashTimer - dt).coerceAtLeast(0f)
        if (attackFlashTimer > 0f) attackFlashTimer = (attackFlashTimer - dt).coerceAtLeast(0f)
        if (dashCooldown > 0f) dashCooldown = (dashCooldown - dt).coerceAtLeast(0f)
        if (jumpCooldown > 0f) jumpCooldown = (jumpCooldown - dt).coerceAtLeast(0f)
        if (screenShakeMagnitude > 0f) screenShakeMagnitude = (screenShakeMagnitude - dt * 36f).coerceAtLeast(0f)

        if (regenPerSec > 0f && hp < maxHp) {
            hp = min(maxHp, hp + regenPerSec * dt)
        }

        val astralUltBoost = if (ElementalBondId.ASTRAL_OVERLOAD in activeBonds) 1.25f else 1f
        killRoom = min(0.032f, killRoom + 0.032f * dt)
        if (ultCharge < 1f && ultActiveTimer <= 0f) {
            ultCharge = min(1f, ultCharge + (dt / 52f) * ultRateMult * astralUltBoost)
            if (ultCharge >= 1f && !ultReadyAnnounced) {
                ultReadyAnnounced = true
                onSfx(SfxType.ULT_READY)
            }
        }

        if (ultActiveTimer > 0f) {
            ultActiveTimer = (ultActiveTimer - dt).coerceAtLeast(0f)
            ultWaveCooldown -= dt
            if (ultWaveCooldown <= 0f && ultWavesRemaining > 0) {
                ultWavesRemaining--
                ultWaveCooldown = 0.45f
                fireUltWave()
            }
        }

        if (hyperActiveTimer > 0f) {
            hyperActiveTimer = (hyperActiveTimer - dt).coerceAtLeast(0f)
            if (hyperActiveTimer <= 0f) {
                recomputeStats(resetHp = false)
                spawnFloat(playerX, playerY - 34f, "超觉醒结束", Color(0xFFFFB2F2), isCrit = false)
            }
        }
        if (magnetVacuumTimer > 0f) {
            magnetVacuumTimer = (magnetVacuumTimer - dt).coerceAtLeast(0f)
        }
        if (comboTimer > 0f) {
            comboTimer = (comboTimer - dt).coerceAtLeast(0f)
            if (comboTimer <= 0f) {
                comboCount = 0
            }
        }
        if (activeWaveEventTimer > 0f) {
            activeWaveEventTimer = (activeWaveEventTimer - dt).coerceAtLeast(0f)
            if (activeWaveEventTimer <= 0f) {
                if (activeWaveEventKind == 3) {
                    // Stardust Mimic escapes if not defeated in time
                    val escaped = enemies.removeAll { it.defId == "stardust_mimic" }
                    if (escaped) {
                        spawnFloat(playerX, playerY - 44f, "星尘宝箱怪遁逃了...", GoldAccent, isCrit = false)
                    }
                }
                activeWaveEventKind = -1
                activeWaveEventTitleZh = null
            }
        } else if (gameMode != GameMode.DUEL && elapsedSec >= nextWaveEventSec) {
            triggerDynamicWaveEvent()
            nextWaveEventSec += if (gameMode == GameMode.SURVIVAL) 28f else 34f
        }

        // Smooth Physics-Based Movement / Dash / Glide + Solid 2.5D Tree/Boulder Obstacles
        val moveSnap = movementController.step(
            rawDt = dt,
            speedMultiplier = speedMult * ecoSpeedMult * if (isGliding) 1.24f else 1f,
            arenaHalfSize = arenaHalfSize,
            obstacles = terrainLayout.movementObstacles,
            baseSpeedOverride = starter.baseSpeed,
            emitTrails = false
        )
        movementState = moveSnap
        // Resolve 2.5D plateau cliff ledges (must Jump or use walkable ramp to climb up!)
        val (resolvedX, resolvedY) = terrainLayout.resolveLedgeCollision(
            px = moveSnap.x,
            py = moveSnap.y,
            currentZ = playerZ,
            entityRadius = 22f
        )
        if (resolvedX != moveSnap.x || resolvedY != moveSnap.y) {
            movementController.clampWorldPosition(resolvedX, resolvedY)
        }
        playerX = resolvedX
        playerY = resolvedY

        // 2.5D Vertical Jump, Air Glide, Plateau Elevation Gravity & High-Ground Drop Slam Physics
        if (coverBlockFloatCooldown > 0f) coverBlockFloatCooldown = (coverBlockFloatCooldown - dt).coerceAtLeast(0f)
        if (highGroundFloatCooldown > 0f) highGroundFloatCooldown = (highGroundFloatCooldown - dt).coerceAtLeast(0f)
        val prevGroundZ = playerGroundZ
        val wasAirborne = playerZ > prevGroundZ + 2f
        val newGroundZ = terrainLayout.groundElevationAt(playerX, playerY)
        playerGroundZ = newGroundZ
        if (!wasAirborne && (playerZ > playerGroundZ + 2f || playerVz > 0f)) {
            takeoffGroundZ = prevGroundZ
            airbornePeakZ = playerZ
            if (glideTimer <= 0f) glideTimer = glideMaxDuration
        }
        if (playerZ > playerGroundZ || playerVz > 0f) {
            if (isGliding && glideTimer > 0f) {
                glideTimer = (glideTimer - dt).coerceAtLeast(0f)
                if (playerVz < 20f) {
                    playerVz = (playerVz - 140f * dt).coerceAtLeast(-52f)
                } else {
                    playerVz -= 780f * dt
                }
                if (frameTick % 3L == 0L) {
                    val wingSide = if (frameTick % 6L == 0L) -18f else 18f
                    emitParticle(
                        playerX + wingSide,
                        playerY - playerZ + 6f,
                        -cos(facingAngle) * 35f,
                        18f,
                        5.2f,
                        if (frameTick % 6L == 0L) Color(0xFF7BE8FF) else GoldAccent,
                        0.28f,
                        ParticleShape.SPARK
                    )
                }
                if (glideTimer <= 0f) isGliding = false
            } else {
                playerVz -= 780f * dt
            }
            playerZ += playerVz * dt
            if (playerZ > airbornePeakZ) airbornePeakZ = playerZ
            if (playerZ <= playerGroundZ) {
                val dropHeight = (airbornePeakZ - playerGroundZ).coerceAtLeast(0f)
                val droppedFromPlateau = takeoffGroundZ > 8f && playerGroundZ < takeoffGroundZ - 10f
                val landedFromDrop = wasAirborne && playerVz < -110f
                playerZ = playerGroundZ
                playerVz = 0f
                isGliding = false
                glideTimer = 0f
                if ((droppedFromPlateau && dropHeight >= 22f) || dropHeight >= 76f) {
                    triggerHighGroundDropSlam(dropHeight = dropHeight, peakZ = airbornePeakZ)
                } else if (landedFromDrop) {
                    emitBurst(playerX, playerY + 10f, 8, biome.pathColor, ParticleShape.DOT, 110f)
                    rings.add(InternalRing(playerX, playerY + 10f, 10f, 48f, Color(0xFFFFF4D6), 0.20f, 0.20f))
                }
                airbornePeakZ = playerGroundZ
                takeoffGroundZ = playerGroundZ
            }
        } else {
            // Smoothly follow walkable ramp elevation transitions
            playerZ = playerGroundZ
            playerVz = 0f
            isGliding = false
            airbornePeakZ = playerGroundZ
            takeoffGroundZ = playerGroundZ
        }

        facingAngle = moveSnap.facingAngle
        walkAnimTime = moveSnap.walkCycle
        dashActiveTimer = moveSnap.dashActiveTimer
        dashCooldown = movementController.dashCooldownTimer

        if (moveSnap.isDashing) {
            dashGhostEmitTimer -= dt
            if (dashGhostEmitTimer <= 0f) {
                dashGhostEmitTimer = 0.042f
                dashGhosts.add(InternalDashGhost(playerX, playerY, 0.24f, 0.24f, starter.element.color))
            }
        } else if (moveSnap.speedRatio > 0.16f && frameTick % 6L == 0L) {
            val backX = -cos(facingAngle)
            val backY = -sin(facingAngle)
            val dustShape = when (starter.id) {
                "stump" -> ParticleShape.LEAF
                "char" -> ParticleShape.SPARK
                "shell" -> ParticleShape.RING_POP
                else -> ParticleShape.DOT
            }
            val dustColor = when (starter.id) {
                "stump" -> GrassGreen.copy(alpha = 0.72f)
                "char" -> WarmOrange.copy(alpha = 0.78f)
                "shell" -> SkyBlue.copy(alpha = 0.72f)
                else -> biome.pathColor.copy(alpha = 0.75f)
            }
            emitParticle(
                playerX + backX * 14f + (rng.nextFloat() - 0.5f) * 10f,
                playerY + 14f,
                backX * 28f, backY * 28f - 8f,
                if (starter.id == "shell") 7.5f else 5.5f,
                dustColor,
                0.34f,
                dustShape
            )
        }

        updateBiomeEcoZones(dt)
        updateMoveSlots(dt)
        updateSpawning(dt)
        updateEnemies(dt)
        updateProjectiles(dt)
        updatePickups(dt)
        updateVfx(dt)
    }

    private fun updateBiomeEcoZones(dt: Float) {
        ecoSpeedMult = 1f
        activeEcoBuffZh = null
        if (ecoFloatCooldown > 0f) ecoFloatCooldown = (ecoFloatCooldown - dt).coerceAtLeast(0f)
        if (lavaHitCooldown > 0f) lavaHitCooldown = (lavaHitCooldown - dt).coerceAtLeast(0f)

        val playerGrounded = playerZ <= playerGroundZ + 4f
        for (zone in terrainLayout.ecoZones) {
            val (phase, _) = BiomeEcoRules.evaluatePhase(zone, elapsedSec)
            val dxP = zone.x - playerX
            val dyP = zone.y - playerY
            val distP = hypot(dxP, dyP)
            val playerInside = distP <= zone.radius

            when (zone.kind) {
                BiomeZoneKind.FOREST_BLOOM_RING -> {
                    if (playerInside) {
                        ecoSpeedMult = maxOf(ecoSpeedMult, 1.18f)
                        if (hp < maxHp) {
                            hp = min(maxHp, hp + 4.2f * dt)
                        }
                        activeEcoBuffZh = "风花灵阵 · 移速+18% 治愈"
                        if (frameTick % 14L == 0L) {
                            emitParticle(playerX + (rng.nextFloat() - 0.5f) * 24f, playerY - playerZ - 8f, 0f, -26f, 5f, GrassGreen, 0.35f, ParticleShape.LEAF)
                        }
                    }
                }
                BiomeZoneKind.GRAVEYARD_SOUL_LANTERN -> {
                    if (playerInside) {
                        if (ultCharge < 1f && ultActiveTimer <= 0f) {
                            ultCharge = min(1f, ultCharge + 0.045f * ultRateMult * dt)
                            if (ultCharge >= 1f && !ultReadyAnnounced) {
                                ultReadyAnnounced = true
                                onSfx(SfxType.ULT_READY)
                            }
                        }
                        activeEcoBuffZh = "幽魂灯柱 · 必杀充能加速"
                    }
                    for (e in enemies) {
                        if (hypot(e.x - zone.x, e.y - zone.y) <= zone.radius + e.radius * 0.5f) {
                            e.slowTimer = maxOf(e.slowTimer, 0.35f)
                            e.lanternVulnerableTimer = 0.45f
                        }
                    }
                }
                BiomeZoneKind.DESERT_QUICKSAND -> {
                    if (playerInside && playerGrounded && dashActiveTimer <= 0f) {
                        ecoSpeedMult = min(ecoSpeedMult, 0.68f)
                        if (distP > 14f) {
                            val pull = 44f * dt
                            val nx = playerX + (dxP / distP) * pull
                            val ny = playerY + (dyP / distP) * pull
                            playerX = nx
                            playerY = ny
                            movementController.clampWorldPosition(nx, ny)
                        }
                        activeEcoBuffZh = "流沙漩涡 · 跳跃/冲刺脱困"
                    }
                    for (e in enemies) {
                        if (e.isBoss) continue
                        val ex = zone.x - e.x
                        val ey = zone.y - e.y
                        val ed = hypot(ex, ey)
                        if (ed <= zone.radius && e.z <= e.groundZ + 4f) {
                            e.slowTimer = maxOf(e.slowTimer, 0.35f)
                            if (ed > 16f) {
                                e.x += (ex / ed) * 32f * dt
                                e.y += (ey / ed) * 32f * dt
                            }
                        }
                    }
                }
                BiomeZoneKind.VOLCANO_LAVA_VENT -> {
                    if (playerInside) {
                        if (phase == BiomeZonePhase.WARNING) {
                            activeEcoBuffZh = "熔岩预警 · 准备跳跃避险"
                        } else if (phase == BiomeZonePhase.ERUPTING) {
                            activeEcoBuffZh = "熔岩喷发 · 跳跃规避灼伤"
                            if (playerZ <= playerGroundZ + 12f && lavaHitCooldown <= 0f) {
                                lavaHitCooldown = 0.72f
                                damagePlayer(13f)
                                emitBurst(playerX, playerY - playerZ, 8, WarmOrange, ParticleShape.SPARK, 180f)
                            }
                        }
                    }
                    if (phase == BiomeZonePhase.ERUPTING) {
                        for (ei in enemies.lastIndex downTo 0) {
                            if (ei >= enemies.size) continue
                            val e = enemies[ei]
                            if (hypot(e.x - zone.x, e.y - zone.y) <= zone.radius + e.radius * 0.4f) {
                                e.hp -= 24f * dt
                                e.burnTimer = maxOf(e.burnTimer, 1.8f)
                                if (e.hp <= 0f) {
                                    enemies.removeAt(ei)
                                    handleEnemyDeath(e, isUlt = false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun updateVfx(dt: Float) {
        val ringIter = rings.iterator()
        while (ringIter.hasNext()) {
            val r = ringIter.next()
            r.life -= dt
            val progress = 1f - (r.life / r.maxLife).coerceIn(0f, 1f)
            r.radius = r.maxRadius * progress
            if (r.life <= 0f) ringIter.remove()
        }

        val arcIter = slashArcs.iterator()
        while (arcIter.hasNext()) {
            val a = arcIter.next()
            a.life -= dt
            if (a.life <= 0f) arcIter.remove()
        }

        val partIter = particles.iterator()
        while (partIter.hasNext()) {
            val p = partIter.next()
            p.life -= dt
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vx *= (1f - min(1f, dt * 4.5f))
            p.vy *= (1f - min(1f, dt * 4.5f))
            p.angleRad += dt * 5f
            if (p.life <= 0f) partIter.remove()
        }

        val ghostIter = dashGhosts.iterator()
        while (ghostIter.hasNext()) {
            val g = ghostIter.next()
            g.life -= dt
            if (g.life <= 0f) ghostIter.remove()
        }

        val ftIter = floatingNumbers.iterator()
        while (ftIter.hasNext()) {
            val f = ftIter.next()
            f.life -= dt
            f.y -= 44f * dt
            if (f.life <= 0f) ftIter.remove()
        }
    }

    private fun emitParticle(
        x: Float,
        y: Float,
        vx: Float,
        vy: Float,
        size: Float,
        color: Color,
        life: Float,
        shape: ParticleShape
    ) {
        if (particles.size >= 110) particles.removeAt(0)
        particles.add(InternalParticle(x, y, vx, vy, size, color, life, life, shape, rng.nextFloat() * 6.28f))
    }

    private fun emitBurst(
        x: Float,
        y: Float,
        count: Int,
        color: Color,
        shape: ParticleShape,
        speed: Float
    ) {
        repeat(count) {
            val a = rng.nextFloat() * 2f * PI.toFloat()
            val spd = speed * (0.4f + rng.nextFloat() * 0.75f)
            emitParticle(
                x = x,
                y = y,
                vx = cos(a) * spd,
                vy = sin(a) * spd,
                size = 5f + rng.nextFloat() * 6f,
                color = color,
                life = 0.28f + rng.nextFloat() * 0.25f,
                shape = shape
            )
        }
    }

    private fun fireUltWave() {
        val ultRange = 340f * areaMult
        val stageMult = when (evolutionStage) {
            0 -> 1.0f
            1 -> 1.6f
            else -> 2.3f
        }
        val baseDmg = 68f * stageMult * damageMult
        val ringColor = when (starter.element) {
            ElementType.GRASS -> GrassGreen
            ElementType.FIRE -> WarmOrange
            ElementType.WATER -> SkyBlue
            else -> GoldAccent
        }
        val shape = if (starter.element == ElementType.GRASS) ParticleShape.LEAF else ParticleShape.SPARK
        rings.add(InternalRing(playerX, playerY, 28f, ultRange, ringColor, 0.52f, 0.52f))
        emitBurst(playerX, playerY, 18, ringColor, shape, 380f)
        triggerShake(10f)
        triggerHitstop(0.030f, 0.036f)
        for (ei in enemies.lastIndex downTo 0) {
            if (ei >= enemies.size) continue
            val e = enemies[ei]
            val d = hypot(e.x - playerX, e.y - playerY)
            if (d <= ultRange + e.radius) {
                val angle = atan2(e.y - playerY, e.x - playerX)
                val knock = if (starter.element == ElementType.WATER) 240f else 170f
                if (e.isBoss && (e.telegraphTimer > 0f || e.chargeActiveTimer > 0f)) {
                    e.telegraphTimer = 0f
                    e.telegraphKind = BossAttackKind.NONE
                    e.chargeActiveTimer = 0f
                    e.staggerTimer = maxOf(e.staggerTimer, 2.4f)
                    spawnFloat(e.x, e.y - e.z - e.radius - 18f, "必杀打断 · 破防!", Color(0xFF66F6FF), isCrit = true)
                }
                damageEnemy(e, baseDmg, isUlt = true, knockAngle = angle, knockForce = knock, burn = starter.element == ElementType.FIRE, slow = starter.element != ElementType.FIRE)
            }
        }
    }

    private fun triggerHighGroundDropSlam(dropHeight: Float, peakZ: Float) {
        val hasSkybreaker = ElementalBondId.SKYBREAKER in activeBonds
        val slamRadius = (146f + (dropHeight * 0.45f).coerceAtMost(50f)) * areaMult * if (hasSkybreaker) 1.35f else 1f
        val slamDamage = (32f + dropHeight * 0.48f) * damageMult * if (hasSkybreaker) 1.45f else 1f
        rings.add(InternalRing(playerX, playerY + 8f, 18f, slamRadius, GoldAccent, 0.46f, 0.46f))
        rings.add(InternalRing(playerX, playerY + 8f, 10f, slamRadius * 0.72f, if (hasSkybreaker) SkyBlue else starter.element.color, 0.36f, 0.36f))
        emitBurst(playerX, playerY + 8f, if (hasSkybreaker) 24 else 18, GoldAccent, ParticleShape.SPARK, 280f)
        emitBurst(playerX, playerY + 8f, 10, biome.pathColor, ParticleShape.DOT, 170f)
        triggerShake(if (hasSkybreaker) 10.5f else 8.5f)
        triggerHitstop(if (hasSkybreaker) 0.040f else 0.032f, 0.038f)
        onSfxPitch(SfxType.CRIT, comboPitch())
        onHaptic()
        var hitCount = 0
        for (ei in enemies.lastIndex downTo 0) {
            if (ei >= enemies.size) continue
            val e = enemies[ei]
            val d = hypot(e.x - playerX, e.y - playerY)
            if (d <= slamRadius + e.radius) {
                val a = atan2(e.y - playerY, e.x - playerX)
                if (hasSkybreaker && !e.isBoss) {
                    e.staggerTimer = maxOf(e.staggerTimer, 1.4f)
                }
                if (e.isBoss && (e.telegraphTimer > 0f || e.chargeActiveTimer > 0f)) {
                    e.telegraphTimer = 0f
                    e.telegraphKind = BossAttackKind.NONE
                    e.chargeActiveTimer = 0f
                    e.staggerTimer = maxOf(e.staggerTimer, 2.4f)
                    spawnFloat(e.x, e.y - e.z - e.radius - 18f, "震击打断 · 破防!", Color(0xFF66F6FF), isCrit = true)
                }
                damageEnemy(
                    e = e,
                    rawDamage = slamDamage,
                    isUlt = false,
                    knockAngle = a,
                    knockForce = if (hasSkybreaker) 310f else 265f,
                    burn = starter.element == ElementType.FIRE,
                    slow = true,
                    attackElement = starter.element,
                    attackerZ = peakZ
                )
                hitCount++
            }
        }
        val prefix = if (hasSkybreaker) "✦苍穹震地" else "高台震击"
        val callout = if (hitCount > 0) "$prefix! ×$hitCount" else "$prefix!"
        spawnFloat(playerX, playerY - 46f, callout, if (hasSkybreaker) SkyBlue else GoldAccent, isCrit = true)
    }

    private fun updateMoveSlots(dt: Float) {
        val onHighGround = playerGroundZ > 6f || playerZ >= 24f
        val nearest = findNearestEnemy(maxDist = if (onHighGround) 760f else 620f)
        for (slot in moveSlots) {
            val isSynergyAwakened = awakenedMoveIds.contains(slot.def.id)
            val isFused = fusedMoveIds.contains(slot.def.id)
            val isOverclocked = overclockedMoveIds.contains(slot.def.id)
            val isAwakened = isSynergyAwakened || isFused || isOverclocked
            val awakeRate = (if (isSynergyAwakened) 1.28f else 1f) *
                (if (isFused) 1.35f else 1f) *
                (if (isOverclocked) 1.18f else 1f)
            slot.cooldown -= dt * atkSpdMult * awakeRate
            if (slot.cooldown > 0f) continue
            val levelDmgBoost = 1f + (slot.level - 1) * 0.24f
            val awakeDmgBoost = (if (isSynergyAwakened) 1.48f else 1f) *
                (if (isFused) 1.50f else 1f) *
                (if (isOverclocked) 1.35f else 1f)
            val lowHpFireBoost = if (starter.id == "char" && hp < maxHp * 0.5f && slot.def.type == ElementType.FIRE) 1.3f else 1f
            val rawDamage = slot.def.baseDamage * levelDmgBoost * awakeDmgBoost * damageMult * lowHpFireBoost

            when (slot.def.archetype) {
                MoveArchetype.STRIKE -> {
                    val range = slot.def.rangeWorld * areaMult * (1f + (slot.level - 1) * 0.08f)
                    val target = findNearestEnemy(range + 45f) ?: continue
                    slot.cooldown = slot.def.cooldownSec
                    attackFlashTimer = 0.22f
                    val dirAngle = atan2(target.y - playerY, target.x - playerX)
                    slashArcs.add(InternalSlashArc(playerX, playerY, dirAngle, range * 0.92f, slot.def.type.color, 0.24f, 0.24f, isAwakened = isAwakened))
                    emitBurst(
                        playerX + cos(dirAngle) * range * 0.55f,
                        playerY + sin(dirAngle) * range * 0.55f,
                        if (isAwakened) 10 else 7, if (isAwakened) GoldAccent else slot.def.type.color, ParticleShape.LEAF, 150f
                    )
                    playShotSfx(slot.def.type)
                    for (ei in enemies.lastIndex downTo 0) {
                        if (ei >= enemies.size) continue
                        val e = enemies[ei]
                        if (hypot(e.x - playerX, e.y - playerY) <= range + e.radius) {
                            val ea = atan2(e.y - playerY, e.x - playerX)
                            damageEnemy(
                                e = e,
                                rawDamage = rawDamage,
                                isUlt = false,
                                knockAngle = ea,
                                knockForce = slot.def.knockback,
                                burn = slot.def.burnsEnemy,
                                slow = slot.def.slowsEnemy,
                                attackElement = slot.def.type,
                                sourceMoveId = slot.def.id,
                                attackerZ = playerZ
                            )
                        }
                    }
                }
                MoveArchetype.PROJECTILE -> {
                    val aimAngle = if (autoAimEnabled && nearest != null) {
                        atan2(nearest.y - playerY, nearest.x - playerX)
                    } else {
                        facingAngle
                    }
                    if (autoAimEnabled && nearest == null) continue
                    slot.cooldown = slot.def.cooldownSec
                    attackFlashTimer = 0.2f
                    playShotSfx(slot.def.type)
                    val count = 1 + (slot.level / 2) + if (isFused) 1 else 0
                    val spread = 0.17f
                    val hgSpdMult = if (onHighGround) 1.18f else 1f
                    val hgLifeMult = if (onHighGround) 1.18f else 1f
                    val projZ = playerZ + 18f
                    for (i in 0 until count) {
                        val offset = (i - (count - 1) / 2f) * spread
                        val a = aimAngle + offset
                        val spd = 560f * hgSpdMult
                        val lifeSec = 0.95f * hgLifeMult
                        projectiles.add(
                            InternalProjectile(
                                id = nextId++,
                                x = playerX + cos(a) * 24f,
                                y = playerY + sin(a) * 24f,
                                vx = cos(a) * spd,
                                vy = sin(a) * spd,
                                radius = 12f * areaMult,
                                damage = rawDamage,
                                color = slot.def.type.color,
                                element = slot.def.type,
                                knockback = slot.def.knockback,
                                burns = slot.def.burnsEnemy,
                                slows = slot.def.slowsEnemy,
                                life = lifeSec,
                                maxLife = lifeSec,
                                pierce = 1 + (slot.level / 3),
                                sourceMoveId = slot.def.id,
                                isEnemy = false,
                                z = projZ,
                                isHighGroundBoosted = onHighGround,
                                isAwakened = isAwakened
                            )
                        )
                    }
                }
                MoveArchetype.NOVA -> {
                    if (nearest == null) continue
                    val range = slot.def.rangeWorld * areaMult * (1f + (slot.level - 1) * 0.1f) * if (onHighGround) 1.12f else 1f
                    slot.cooldown = slot.def.cooldownSec
                    attackFlashTimer = 0.24f
                    playShotSfx(slot.def.type)
                    rings.add(InternalRing(playerX, playerY, 24f, range, slot.def.type.color, 0.42f, 0.42f))
                    emitBurst(playerX, playerY, 12, slot.def.type.color, ParticleShape.DOT, 210f)
                    for (ei in enemies.lastIndex downTo 0) {
                        if (ei >= enemies.size) continue
                        val e = enemies[ei]
                        val d = hypot(e.x - playerX, e.y - playerY)
                        if (d <= range + e.radius) {
                            val a = atan2(e.y - playerY, e.x - playerX)
                            damageEnemy(e, rawDamage, isUlt = false, knockAngle = a, knockForce = slot.def.knockback, burn = slot.def.burnsEnemy, slow = slot.def.slowsEnemy, attackElement = slot.def.type, sourceMoveId = slot.def.id, attackerZ = playerZ)
                        }
                    }
                }
                MoveArchetype.BEAM -> {
                    val target = nearest ?: continue
                    slot.cooldown = slot.def.cooldownSec
                    attackFlashTimer = 0.28f
                    playShotSfx(slot.def.type)
                    val a = atan2(target.y - playerY, target.x - playerX)
                    val rawBeamLen = slot.def.rangeWorld * areaMult * if (onHighGround) 1.25f else 1f
                    val rawEx = playerX + cos(a) * rawBeamLen
                    val rawEy = playerY + sin(a) * rawBeamLen
                    val beamZ = playerZ + 18f
                    val (ex, ey, hitObs) = terrainLayout.clipBeamToObstacles(playerX, playerY, rawEx, rawEy, beamZ)
                    val beamLen = hypot(ex - playerX, ey - playerY)
                    if (hitObs != null) {
                        val chipColor = if (hitObs.kind == TerrainObstacleKind.TALL_TREE) GrassGreen else Color(0xFFD6C8B4)
                        emitBurst(ex, ey - beamZ * 0.65f, 7, chipColor, ParticleShape.SPARK, 175f)
                    }
                    projectiles.add(
                        InternalProjectile(
                            id = nextId++,
                            x = playerX,
                            y = playerY,
                            vx = 0f,
                            vy = 0f,
                            radius = (if (isFused) 34f else 24f) * areaMult,
                            damage = rawDamage,
                            color = slot.def.type.color,
                            element = slot.def.type,
                            knockback = slot.def.knockback,
                            burns = slot.def.burnsEnemy,
                            slows = slot.def.slowsEnemy,
                            life = 0.26f,
                            maxLife = 0.26f,
                            isBeam = true,
                            endX = ex,
                            endY = ey,
                            sourceMoveId = slot.def.id,
                            isEnemy = false,
                            z = beamZ,
                            isHighGroundBoosted = onHighGround,
                            isAwakened = isAwakened
                        )
                    )
                    emitBurst(playerX + cos(a) * 32f, playerY + sin(a) * 32f, 8, slot.def.type.color, ParticleShape.SPARK, 220f)
                    val dx = cos(a)
                    val dy = sin(a)
                    val beamHitWidth = (if (isFused) 38f else 28f) * areaMult
                    for (ei in enemies.lastIndex downTo 0) {
                        if (ei >= enemies.size) continue
                        val e = enemies[ei]
                        val relX = e.x - playerX
                        val relY = e.y - playerY
                        val proj = relX * dx + relY * dy
                        if (proj in 0f..beamLen) {
                            val perp = abs(relX * (-dy) + relY * dx)
                            if (perp <= e.radius + beamHitWidth) {
                                damageEnemy(e, rawDamage, isUlt = false, knockAngle = a, knockForce = slot.def.knockback, burn = slot.def.burnsEnemy, slow = slot.def.slowsEnemy, attackElement = slot.def.type, sourceMoveId = slot.def.id, attackerZ = beamZ)
                            }
                        }
                    }
                }
                MoveArchetype.ORBIT -> {
                    val orbitDist = slot.def.rangeWorld * areaMult
                    slot.cooldown = slot.def.cooldownSec
                    val bladeCount = 2 + (slot.level / 2) + if (isFused) 1 else 0
                    var hitAny = false
                    for (b in 0 until bladeCount) {
                        val a = orbitAngle + (b * 2f * PI.toFloat() / bladeCount)
                        val bx = playerX + cos(a) * orbitDist
                        val by = playerY + sin(a) * orbitDist
                        for (ei in enemies.lastIndex downTo 0) {
                            if (ei >= enemies.size) continue
                            val e = enemies[ei]
                            if (hypot(e.x - bx, e.y - by) <= e.radius + 36f * areaMult) {
                                val ka = atan2(e.y - playerY, e.x - playerX)
                                damageEnemy(e, rawDamage, isUlt = false, knockAngle = ka, knockForce = slot.def.knockback, burn = slot.def.burnsEnemy, slow = slot.def.slowsEnemy, attackElement = slot.def.type, sourceMoveId = slot.def.id)
                                hitAny = true
                            }
                        }
                    }
                    if (hitAny) playShotSfx(slot.def.type)
                }
            }
        }
    }

    private fun playShotSfx(type: ElementType) {
        when (type) {
            ElementType.FIRE -> onSfx(SfxType.SHOT_FIRE)
            ElementType.WATER -> onSfx(SfxType.SHOT_WATER)
            else -> onSfx(SfxType.SHOT_GRASS)
        }
    }

    private fun triggerDynamicWaveEvent() {
        val kind = waveEventIndex % 5
        waveEventIndex++
        activeWaveEventKind = kind
        activeWaveEventTimer = activeWaveEventDuration
        when (kind) {
            0 -> {
                activeWaveEventTitleZh = "⚡ 极速敌潮 · 经验 +35%"
                repeat(8) { spawnEnemy(forceElite = false) }
                rings.add(InternalRing(playerX, playerY, 24f, 250f, WarmOrange, 0.55f, 0.55f))
                spawnFloat(playerX, playerY - 52f, "极速敌潮来袭！经验+35%", WarmOrange, isCrit = true)
            }
            1 -> {
                activeWaveEventTitleZh = "💰 黄金掠夺 · 金币爆率飙升"
                repeat(3) { spawnAmbushEnemyAround(playerX, playerY, forceElite = true) }
                rings.add(InternalRing(playerX, playerY, 24f, 250f, GoldAccent, 0.55f, 0.55f))
                spawnFloat(playerX, playerY - 52f, "黄金掠夺时刻！击败精英爆金币", GoldAccent, isCrit = true)
            }
            2 -> {
                activeWaveEventTitleZh = "🔥 双精英突袭 · 必掉晶核与宝箱"
                repeat(2) { spawnAmbushEnemyAround(playerX, playerY, forceElite = true) }
                spawnPropNearPlayer(WorldPropKind.WOODEN_CHEST, 210f, 340f)
                rings.add(InternalRing(playerX, playerY, 24f, 260f, Color(0xFFFF66E5), 0.58f, 0.58f))
                spawnFloat(playerX, playerY - 52f, "双精英词条突袭！宝箱已空投", Color(0xFFFF7AF6), isCrit = true)
            }
            3 -> {
                activeWaveEventTitleZh = "🎁 星尘宝箱怪出没 · 限时拦截!"
                spawnStardustMimic()
                rings.add(InternalRing(playerX, playerY, 24f, 260f, GoldAccent, 0.60f, 0.60f))
                spawnFloat(playerX, playerY - 52f, "星尘宝箱怪现身！快拦住它!", GoldAccent, isCrit = true)
            }
            else -> {
                activeWaveEventTitleZh = "⛩ 风险祭坛降临 · 奇遇抉择"
                val propKind = if (rng.nextFloat() < 0.55f) WorldPropKind.GAMBLE_SHRINE else WorldPropKind.FUSION_MACHINE
                spawnPropNearPlayer(propKind, 200f, 330f)
                rings.add(InternalRing(playerX, playerY, 22f, 250f, Color(0xFF5CF6FF), 0.58f, 0.58f))
                val msg = if (propKind == WorldPropKind.FUSION_MACHINE) {
                    "奇术融合仪空降！超频招式!"
                } else {
                    "风险祭坛降临！血契换取强力祝福!"
                }
                spawnFloat(playerX, playerY - 52f, msg, Color(0xFF7BE8FF), isCrit = true)
            }
        }
        onSfx(SfxType.ULT_READY)
    }

    private fun spawnStardustMimic() {
        val def = GameCatalog.enemies["stardust_mimic"] ?: return
        val angle = rng.nextFloat() * 2f * PI.toFloat()
        val dist = 260f
        val sx = (playerX + cos(angle) * dist).coerceIn(-arenaHalfSize + 80f, arenaHalfSize - 80f)
        val sy = (playerY + sin(angle) * dist).coerceIn(-arenaHalfSize + 80f, arenaHalfSize - 80f)
        val finalHp = def.baseHp * (1f + elapsedSec / 75f) * biome.difficultyScale
        val spawnZ = terrainLayout.groundElevationAt(sx, sy)
        enemies.add(
            InternalEnemy(
                id = nextId++,
                defId = def.id,
                x = sx,
                y = sy,
                radius = def.radius,
                hp = finalHp,
                maxHp = finalHp,
                speed = def.speed,
                contactDamage = def.contactDamage,
                xpValue = def.xpValue,
                isBoss = false,
                isElite = true,
                primaryColor = def.primaryColor,
                secondaryColor = def.secondaryColor,
                animPhase = 0f,
                groundZ = spawnZ,
                z = spawnZ
            )
        )
        seenEnemyCounts[def.id] = (seenEnemyCounts[def.id] ?: 0) + 1
        rings.add(InternalRing(sx, sy, 14f, 130f, GoldAccent, 0.50f, 0.50f))
        emitBurst(sx, sy, 16, GoldAccent, ParticleShape.SPARK, 220f)
    }

    private fun updateSpawning(dt: Float) {
        if (gameMode == GameMode.DUEL) {
            spawnTimer -= dt
            val escortCount = enemies.count { !it.isBoss }
            if (spawnTimer <= 0f && escortCount < 4) {
                spawnTimer = 11f
                spawnEnemy(forceElite = false)
            }
            if (!bossSpawned && draftOptions == null) {
                bossSpawned = true
                spawnBoss()
            }
            return
        }

        spawnTimer -= dt
        val maxConcurrent = ((18 + (elapsedSec / 7f).toInt()) * challengeSpawnRateMult).toInt().coerceAtMost(56)
        if (spawnTimer <= 0f && enemies.size < maxConcurrent) {
            val baseInterval = (1.15f - elapsedSec * 0.006f).coerceIn(0.32f, 1.15f) / challengeSpawnRateMult
            spawnTimer = if (activeWaveEventKind == 0) baseInterval * 0.72f else baseInterval
            val burst = if (elapsedSec > 45f) 2 else 1
            repeat(burst) {
                val eliteChance = (if (activeWaveEventKind == 2) 0.22f else 0.09f) + challengeEliteBonus
                val isElite = (elapsedSec > 25f || challengeEliteBonus > 0f) && rng.nextFloat() < eliteChance
                spawnEnemy(forceElite = isElite)
            }
        }

        propSpawnTimer -= dt
        if (propSpawnTimer <= 0f && props.count { !it.opened } < 6) {
            propSpawnTimer = 16f
            val roll = rng.nextFloat()
            val hasFusionMachine = props.any { !it.opened && it.kind == WorldPropKind.FUSION_MACHINE }
            val kind = when {
                roll < 0.38f -> WorldPropKind.WOODEN_CHEST
                roll < 0.58f -> WorldPropKind.HEAL_SHRINE
                roll < 0.74f -> WorldPropKind.GAMBLE_SHRINE
                roll < 0.88f -> WorldPropKind.MAGNET_OBELISK
                !hasFusionMachine -> WorldPropKind.FUSION_MACHINE
                else -> WorldPropKind.WOODEN_CHEST
            }
            spawnPropNearPlayer(kind, 320f, 600f)
        }

        if (gameMode == GameMode.CLASSIC) {
            if (!bossSpawned && elapsedSec >= nextBossTimeSec) {
                bossSpawned = true
                for (p in props) {
                    if (p.kind == WorldPropKind.BOSS_PORTAL && !p.opened) p.opened = true
                }
                spawnBoss()
            }
        } else {
            if (elapsedSec >= nextBossTimeSec && enemies.none { it.isBoss }) {
                bossSpawned = true
                spawnBoss()
                nextBossTimeSec += 68f
            }
        }
    }

    private fun spawnEnemy(forceElite: Boolean) {
        val pool = biome.enemyPool
        val defId = pool[rng.nextInt(pool.size)]
        val def = GameCatalog.enemies[defId] ?: return
        val angle = rng.nextFloat() * 2f * PI.toFloat()
        val dist = 480f + rng.nextFloat() * 140f
        val sx = (playerX + cos(angle) * dist).coerceIn(-arenaHalfSize + 40f, arenaHalfSize - 40f)
        val sy = (playerY + sin(angle) * dist).coerceIn(-arenaHalfSize + 40f, arenaHalfSize - 40f)
        val timeScale = 1f + (elapsedSec / 65f) * 0.7f
        val eliteMult = if (forceElite) 2.5f else 1f
        val finalHp = def.baseHp * biome.difficultyScale * timeScale * eliteMult * challengeEnemyHpMult
        val spawnZ = terrainLayout.groundElevationAt(sx, sy)
        enemies.add(
            InternalEnemy(
                id = nextId++,
                defId = def.id,
                x = sx,
                y = sy,
                radius = def.radius * if (forceElite) 1.32f else 1f,
                hp = finalHp,
                maxHp = finalHp,
                speed = def.speed * challengeEnemySpeedMult * if (forceElite) 1.12f else 1f,
                contactDamage = def.contactDamage * biome.difficultyScale * if (forceElite) 1.35f else 1f,
                xpValue = def.xpValue * if (forceElite) 3 else 1,
                isBoss = false,
                isElite = forceElite,
                primaryColor = def.primaryColor,
                secondaryColor = def.secondaryColor,
                animPhase = rng.nextFloat() * 6.28f,
                groundZ = spawnZ,
                z = spawnZ,
                leapCooldown = 1.2f + rng.nextFloat() * 1.4f,
                rangedCooldown = 2.0f + rng.nextFloat() * 2.0f
            )
        )
        seenEnemyCounts[def.id] = (seenEnemyCounts[def.id] ?: 0) + 1
    }

    private fun spawnAmbushEnemyAround(cx: Float, cy: Float, forceElite: Boolean) {
        val pool = biome.enemyPool
        val defId = pool[rng.nextInt(pool.size)]
        val def = GameCatalog.enemies[defId] ?: return
        val angle = rng.nextFloat() * 2f * PI.toFloat()
        val dist = 165f + rng.nextFloat() * 75f
        val sx = (cx + cos(angle) * dist).coerceIn(-arenaHalfSize + 40f, arenaHalfSize - 40f)
        val sy = (cy + sin(angle) * dist).coerceIn(-arenaHalfSize + 40f, arenaHalfSize - 40f)
        val timeScale = 1f + (elapsedSec / 65f) * 0.7f
        val eliteMult = if (forceElite) 2.3f else 1f
        val finalHp = def.baseHp * biome.difficultyScale * timeScale * eliteMult * challengeEnemyHpMult
        val spawnZ = terrainLayout.groundElevationAt(sx, sy)
        enemies.add(
            InternalEnemy(
                id = nextId++,
                defId = def.id,
                x = sx,
                y = sy,
                radius = def.radius * if (forceElite) 1.30f else 1f,
                hp = finalHp,
                maxHp = finalHp,
                speed = def.speed * challengeEnemySpeedMult * if (forceElite) 1.12f else 1.04f,
                contactDamage = def.contactDamage * biome.difficultyScale * if (forceElite) 1.3f else 1f,
                xpValue = def.xpValue * if (forceElite) 3 else 1,
                isBoss = false,
                isElite = forceElite,
                primaryColor = def.primaryColor,
                secondaryColor = def.secondaryColor,
                animPhase = rng.nextFloat() * 6.28f,
                groundZ = spawnZ,
                z = spawnZ,
                leapCooldown = 1.1f + rng.nextFloat() * 1.3f,
                rangedCooldown = 1.8f + rng.nextFloat() * 1.8f
            )
        )
        seenEnemyCounts[def.id] = (seenEnemyCounts[def.id] ?: 0) + 1
    }

    private fun spawnBoss() {
        val def = GameCatalog.enemies[biome.bossId] ?: return
        val angle = facingAngle
        val sx = (playerX + cos(angle) * 420f).coerceIn(-arenaHalfSize + 80f, arenaHalfSize - 80f)
        val sy = (playerY + sin(angle) * 420f).coerceIn(-arenaHalfSize + 80f, arenaHalfSize - 80f)
        val finalHp = def.baseHp * biome.difficultyScale * challengeEnemyHpMult
        val spawnZ = terrainLayout.groundElevationAt(sx, sy)
        enemies.add(
            InternalEnemy(
                id = nextId++,
                defId = def.id,
                x = sx,
                y = sy,
                radius = def.radius,
                hp = finalHp,
                maxHp = finalHp,
                speed = def.speed * challengeEnemySpeedMult,
                contactDamage = def.contactDamage * biome.difficultyScale,
                xpValue = def.xpValue,
                isBoss = true,
                isElite = false,
                primaryColor = def.primaryColor,
                secondaryColor = def.secondaryColor,
                groundZ = spawnZ,
                z = spawnZ,
                telegraphCooldown = 3.2f,
                rangedCooldown = 2.4f
            )
        )
        seenEnemyCounts[def.id] = (seenEnemyCounts[def.id] ?: 0) + 1
        rings.add(InternalRing(sx, sy, 20f, 220f, CrimsonRed, 0.6f, 0.6f))
        rings.add(InternalRing(sx, sy, 12f, 165f, GoldAccent, 0.48f, 0.48f))
        triggerShake(12f)
        triggerHitstop(0.042f, 0.046f)
        onSfx(SfxType.ULT_READY)
        bossAlertBannerText = "⚠ 群落守护者降临 · ${def.nameZh}"
        bossAlertBannerTimer = 3.2f
        spawnFloat(playerX, playerY - 60f, "守护者降临：${def.nameZh}!", CrimsonRed, isCrit = true)
    }

    private fun spawnPropNearPlayer(kind: WorldPropKind, minDist: Float, maxDist: Float) {
        var chosenX = (playerX + minDist).coerceIn(-arenaHalfSize + 100f, arenaHalfSize - 100f)
        var chosenY = playerY.coerceIn(-arenaHalfSize + 100f, arenaHalfSize - 100f)
        for (attempt in 0 until 8) {
            val angle = rng.nextFloat() * 2f * PI.toFloat()
            val dist = minDist + rng.nextFloat() * (maxDist - minDist)
            val px = (playerX + cos(angle) * dist).coerceIn(-arenaHalfSize + 100f, arenaHalfSize - 100f)
            val py = (playerY + sin(angle) * dist).coerceIn(-arenaHalfSize + 100f, arenaHalfSize - 100f)
            if (terrainLayout.isClearOfObstacles(px, py, clearance = 38f)) {
                chosenX = px
                chosenY = py
                break
            }
        }
        props.add(InternalProp(nextId++, kind, chosenX, chosenY))
    }

    private fun isRangedEnemy(e: InternalEnemy): Boolean {
        if (e.isBoss || e.isElite) return true
        return e.defId.contains("wisp") ||
            e.defId.contains("wraith") ||
            e.defId.contains("shroom") ||
            e.defId.contains("scorp") ||
            e.defId.contains("ember")
    }

    private fun fireEnemyVolley(e: InternalEnemy, aimAngle: Float, activeHostileCount: Int): Int {
        if (activeHostileCount >= 14) return 0
        val elem = GameCatalog.enemies[e.defId]?.element ?: ElementType.GHOST
        val shots = if (e.isBoss) 3 else 1
        val spread = 0.24f
        val spd = if (e.isBoss) 295f else 245f
        val projRadius = if (e.isBoss) 11.5f else 9f
        val projDmg = e.contactDamage * if (e.isBoss) 0.95f else 0.78f
        val launchZ = e.z + 12f
        for (i in 0 until shots) {
            val offset = (i - (shots - 1) / 2f) * spread
            val a = aimAngle + offset
            projectiles.add(
                InternalProjectile(
                    id = nextId++,
                    x = e.x + cos(a) * (e.radius + 8f),
                    y = e.y + sin(a) * (e.radius + 8f),
                    vx = cos(a) * spd,
                    vy = sin(a) * spd,
                    radius = projRadius,
                    damage = projDmg,
                    color = CrimsonRed,
                    element = elem,
                    knockback = 0f,
                    burns = false,
                    slows = false,
                    life = 2.0f,
                    maxLife = 2.0f,
                    pierce = 1,
                    isEnemy = true,
                    z = launchZ
                )
            )
        }
        emitBurst(e.x, e.y - e.z, 5, Color(0xFFFF5A8A), ParticleShape.SPARK, 130f)
        return shots
    }

    private fun updateEnemies(dt: Float) {
        val playerPlateau = if (playerGroundZ > 6f) terrainLayout.plateauAt(playerX, playerY) else null
        var activeHostileProjCount = 0
        for (pi in projectiles.indices) {
            if (projectiles[pi].isEnemy) activeHostileProjCount++
        }
        val pendingBossSummons = mutableListOf<Triple<Float, Float, Boolean>>()
        val iter = enemies.iterator()
        while (iter.hasNext()) {
            val e = iter.next()
            e.animPhase += dt * 6.5f
            if (e.hitFlash > 0f) e.hitFlash = (e.hitFlash - dt * 5.2f).coerceAtLeast(0f)
            if (e.slowTimer > 0f) e.slowTimer = (e.slowTimer - dt).coerceAtLeast(0f)
            if (e.lanternVulnerableTimer > 0f) e.lanternVulnerableTimer = (e.lanternVulnerableTimer - dt).coerceAtLeast(0f)
            if (e.staggerTimer > 0f) e.staggerTimer = (e.staggerTimer - dt).coerceAtLeast(0f)
            if (e.leapCooldown > 0f) e.leapCooldown = (e.leapCooldown - dt).coerceAtLeast(0f)
            if (e.rangedCooldown > 0f) e.rangedCooldown = (e.rangedCooldown - dt).coerceAtLeast(0f)
            if (e.burnTimer > 0f) {
                e.burnTimer = (e.burnTimer - dt).coerceAtLeast(0f)
                e.burnTick -= dt
                if (e.burnTick <= 0f) {
                    e.burnTick = 0.55f
                    val burnDmg = 9f * damageMult
                    e.hp -= burnDmg
                    emitParticle(e.x, e.y - e.z - e.radius * 0.4f, 0f, -45f, 6f, WarmOrange, 0.3f, ParticleShape.DOT)
                    spawnFloat(e.x, e.y - e.z - e.radius, "${burnDmg.toInt()}", WarmOrange, isCrit = false)
                    if (e.hp <= 0f) {
                        handleEnemyDeath(e, isUlt = false)
                        iter.remove()
                        continue
                    }
                }
            }

            val dxToPlayer = playerX - e.x
            val dyToPlayer = playerY - e.y
            e.facingLeft = dxToPlayer < 0f
            val distToPlayer = hypot(dxToPlayer, dyToPlayer).coerceAtLeast(1f)

            if (e.isBoss) {
                val hpRatio = (e.hp / e.maxHp).coerceIn(0f, 1f)
                if (e.bossPhase == 1 && hpRatio <= 0.75f) {
                    e.bossPhase = 2
                    e.telegraphCooldown = min(e.telegraphCooldown, 1.4f)
                    bossAlertBannerText = "⚠ 守护者狂暴 · 进入第 2 阶段!"
                    bossAlertBannerTimer = 2.8f
                    evolutionBannerText = "守护者狂暴 · 进入第 2 阶段！"
                    evolutionBannerTimer = 2.6f
                    rings.add(InternalRing(e.x, e.y - e.z, 22f, 240f, WarmOrange, 0.52f, 0.52f))
                    emitBurst(e.x, e.y - e.z, 22, WarmOrange, ParticleShape.SPARK, 300f)
                    triggerShake(11f)
                    triggerHitstop(0.042f, 0.045f)
                    onSfx(SfxType.ULT_READY)
                }
                if (e.bossPhase < 3 && hpRatio <= 0.48f) {
                    e.bossPhase = 3
                    e.telegraphCooldown = min(e.telegraphCooldown, 1.2f)
                    bossAlertBannerText = "☠ 守护者终焉形态 · 进入第 3 阶段!"
                    bossAlertBannerTimer = 3.0f
                    evolutionBannerText = "守护者终焉形态 · 进入第 3 阶段！"
                    evolutionBannerTimer = 2.8f
                    rings.add(InternalRing(e.x, e.y - e.z, 26f, 280f, CrimsonRed, 0.58f, 0.58f))
                    rings.add(InternalRing(e.x, e.y - e.z, 14f, 210f, GoldAccent, 0.44f, 0.44f))
                    emitBurst(e.x, e.y - e.z, 28, CrimsonRed, ParticleShape.SPARK, 330f)
                    triggerShake(13f)
                    triggerHitstop(0.048f, 0.050f)
                    onSfx(SfxType.EVOLVE)
                    pendingBossSummons.add(Triple(e.x, e.y, true))
                    pendingBossSummons.add(Triple(e.x, e.y, false))
                }

                if (e.chargeActiveTimer > 0f) {
                    e.chargeActiveTimer = (e.chargeActiveTimer - dt).coerceAtLeast(0f)
                    val chargeSpd = 540f * if (e.bossPhase >= 3) 1.12f else 1f
                    e.x = (e.x + e.chargeDirX * chargeSpd * dt).coerceIn(-arenaHalfSize + 60f, arenaHalfSize - 60f)
                    e.y = (e.y + e.chargeDirY * chargeSpd * dt).coerceIn(-arenaHalfSize + 60f, arenaHalfSize - 60f)
                    if (frameTick % 2L == 0L) {
                        emitParticle(e.x, e.y - e.z, -e.chargeDirX * 60f, -e.chargeDirY * 60f, 9f, CrimsonRed, 0.24f, ParticleShape.SPARK)
                    }
                    if (hypot(playerX - e.x, playerY - e.y) <= e.radius + 26f && abs(playerZ - e.z) < 34f) {
                        damagePlayer(e.contactDamage * 1.45f)
                        e.chargeHitPlayer = true
                    }
                    if (e.chargeActiveTimer <= 0f) {
                        if (!e.chargeHitPlayer) {
                            e.staggerTimer = 2.5f
                            rings.add(InternalRing(e.x, e.y - e.z, 18f, 130f, Color(0xFF66F6FF), 0.40f, 0.40f))
                            emitBurst(e.x, e.y - e.z, 14, GoldAccent, ParticleShape.SPARK, 210f)
                            spawnFloat(e.x, e.y - e.z - e.radius - 14f, "闪避成功 · 破防 易伤+35%!", Color(0xFF66F6FF), isCrit = true)
                            onSfx(SfxType.CRIT)
                        }
                    }
                } else if (e.telegraphTimer > 0f) {
                    e.telegraphTimer -= dt
                    if (e.telegraphTimer <= 0f) {
                        when (e.telegraphKind) {
                            BossAttackKind.LINE_CHARGE -> {
                                e.chargeActiveTimer = 0.50f
                                e.chargeHitPlayer = false
                                emitBurst(e.x, e.y - e.z, 14, CrimsonRed, ParticleShape.SPARK, 260f)
                                onSfx(SfxType.DODGE)
                            }
                            BossAttackKind.RADIAL_BURST -> {
                                val count = if (e.bossPhase >= 3) 12 else 8
                                val baseAng = atan2(dyToPlayer, dxToPlayer)
                                val elem = GameCatalog.enemies[e.defId]?.element ?: ElementType.GHOST
                                for (k in 0 until count) {
                                    val a = baseAng + (k * 2f * PI.toFloat() / count)
                                    val spd = if (e.bossPhase >= 3) 275f else 245f
                                    projectiles.add(
                                        InternalProjectile(
                                            id = nextId++,
                                            x = e.x + cos(a) * (e.radius + 6f),
                                            y = e.y + sin(a) * (e.radius + 6f),
                                            vx = cos(a) * spd,
                                            vy = sin(a) * spd,
                                            radius = 10.5f,
                                            damage = e.contactDamage * 0.92f,
                                            color = if (e.bossPhase >= 3) Color(0xFFFF4DA6) else CrimsonRed,
                                            element = elem,
                                            knockback = 0f,
                                            burns = false,
                                            slows = false,
                                            life = 2.2f,
                                            maxLife = 2.2f,
                                            pierce = 1,
                                            isEnemy = true,
                                            z = e.z + 12f
                                        )
                                    )
                                }
                                rings.add(InternalRing(e.x, e.y - e.z, 18f, 165f, Color(0xFFFF5A8A), 0.36f, 0.36f))
                                triggerShake(7.5f)
                                onSfx(SfxType.SHOT_FIRE)
                            }
                            BossAttackKind.SUMMON_GUARD -> {
                                pendingBossSummons.add(Triple(e.x, e.y, true))
                                pendingBossSummons.add(Triple(e.x, e.y, false))
                                rings.add(InternalRing(e.x, e.y - e.z, 22f, 210f, Color(0xFFC25AFF), 0.48f, 0.48f))
                                emitBurst(e.x, e.y - e.z, 18, Color(0xFFC25AFF), ParticleShape.SPARK, 250f)
                                spawnFloat(e.x, e.y - e.z - e.radius - 14f, "守护者召唤亲卫!", Color(0xFFE09AFF), isCrit = true)
                                onSfx(SfxType.ULT_READY)
                            }
                            else -> {
                                val slamRadius = when (e.bossPhase) {
                                    1 -> 175f
                                    2 -> 195f
                                    else -> 215f
                                }
                                rings.add(InternalRing(e.x, e.y - e.z, 20f, slamRadius, CrimsonRed, 0.36f, 0.36f))
                                emitBurst(e.x, e.y - e.z, 16, CrimsonRed, ParticleShape.SPARK, 280f)
                                triggerShake(9f)
                                if (hypot(playerX - e.x, playerY - e.y) <= slamRadius && abs(playerZ - e.z) < 42f) {
                                    damagePlayer(e.contactDamage * 1.4f)
                                }
                            }
                        }
                        e.telegraphKind = BossAttackKind.NONE
                    }
                } else if (e.staggerTimer <= 0f) {
                    e.telegraphCooldown -= dt
                    if (e.telegraphCooldown <= 0f && distToPlayer < 440f) {
                        val nextKind = when (e.bossPhase) {
                            1 -> BossAttackKind.RING_SLAM
                            2 -> when (e.bossAttackCycle % 3) {
                                0 -> BossAttackKind.LINE_CHARGE
                                1 -> BossAttackKind.RADIAL_BURST
                                else -> BossAttackKind.RING_SLAM
                            }
                            else -> when (e.bossAttackCycle % 4) {
                                0 -> BossAttackKind.LINE_CHARGE
                                1 -> BossAttackKind.RADIAL_BURST
                                2 -> BossAttackKind.SUMMON_GUARD
                                else -> BossAttackKind.RING_SLAM
                            }
                        }
                        e.bossAttackCycle++
                        if (nextKind == BossAttackKind.RING_SLAM && distToPlayer > 270f) {
                            // If player is far away when Ring Slam comes up, pivot to Line Charge in P2+
                            e.telegraphKind = if (e.bossPhase >= 2) BossAttackKind.LINE_CHARGE else BossAttackKind.RING_SLAM
                        } else {
                            e.telegraphKind = nextKind
                        }
                        if (e.telegraphKind == BossAttackKind.LINE_CHARGE) {
                            e.chargeDirX = dxToPlayer / distToPlayer
                            e.chargeDirY = dyToPlayer / distToPlayer
                            e.telegraphDuration = 1.05f
                        } else if (e.telegraphKind == BossAttackKind.RADIAL_BURST) {
                            e.telegraphDuration = 0.95f
                        } else {
                            e.telegraphDuration = 1.12f
                        }
                        e.telegraphTimer = e.telegraphDuration
                        e.telegraphCooldown = when (e.bossPhase) {
                            1 -> 4.8f
                            2 -> 3.9f
                            else -> 3.2f
                        }
                    }
                }
            }

            // Hostile ranged volleys for Bosses, Elites & ranged species so players can use boulder/tree cover!
            if (isRangedEnemy(e) && e.telegraphTimer <= 0f && e.chargeActiveTimer <= 0f && e.staggerTimer <= 0f && e.rangedCooldown <= 0f) {
                val minRange = if (e.isBoss) 140f else 170f
                val maxRange = if (e.isBoss) 520f else 410f
                if (distToPlayer in minRange..maxRange) {
                    activeHostileProjCount += fireEnemyVolley(e, atan2(dyToPlayer, dxToPlayer), activeHostileProjCount)
                    e.rangedCooldown = if (e.isBoss) (if (e.bossPhase >= 3) 2.5f else 3.2f) else 3.4f + rng.nextFloat() * 1.4f
                }
            }

            // Plateau Ramp Routing & 2.5D Cliff-Leap Pursuit AI
            var navX = playerX
            var navY = playerY
            val isGrounded = e.z <= e.groundZ + 2f && e.vz <= 0f
            if (!e.isBoss && playerPlateau != null && playerGroundZ > e.groundZ + 8f) {
                val nearCliff = playerPlateau.containsPoint(e.x, e.y, margin = e.radius + 42f)
                val inRamp = playerPlateau.isInRampZone(e.x, e.y)
                if (nearCliff && !inRamp && isGrounded) {
                    if (e.leapCooldown <= 0f) {
                        // Vault directly up onto the raised plateau!
                        e.vz = 285f + rng.nextFloat() * 35f
                        e.leapCooldown = 2.6f + rng.nextFloat() * 1.4f
                        emitBurst(e.x, e.y - e.groundZ + 6f, 6, biome.pathColor, ParticleShape.DOT, 95f)
                        rings.add(InternalRing(e.x, e.y - e.groundZ + 6f, 8f, 34f, Color(0xFFFFF4D6), 0.18f, 0.18f))
                    } else {
                        // Flank smoothly toward the plateau's walkable ramp mouth while leap is on cooldown
                        val (rampX, rampY) = playerPlateau.rampApproachPoint(28f)
                        navX = rampX
                        navY = rampY
                    }
                } else if (!nearCliff && isGrounded) {
                    val (rampX, rampY) = playerPlateau.rampApproachPoint(28f)
                    val distToRamp = hypot(rampX - e.x, rampY - e.y)
                    if (distToRamp < distToPlayer * 1.15f) {
                        navX = rampX
                        navY = rampY
                    }
                }
            }

            val isMimic = e.defId == "stardust_mimic"
            val navDx = if (isMimic) (e.x - playerX) else (navX - e.x)
            val navDy = if (isMimic) (e.y - playerY) else (navY - e.y)
            val navDist = hypot(navDx, navDy).coerceAtLeast(1f)
            var rawDirX = navDx / navDist
            var rawDirY = navDy / navDist
            if (isMimic) {
                // Fleeing sprite curves tangentially around arena rim and drops golden glitter
                val tangentX = -rawDirY * 0.52f
                val tangentY = rawDirX * 0.52f
                val mixLen = hypot(rawDirX + tangentX, rawDirY + tangentY).coerceAtLeast(1f)
                rawDirX = (rawDirX + tangentX) / mixLen
                rawDirY = (rawDirY + tangentY) / mixLen
                if (frameTick % 4L == 0L) {
                    emitParticle(e.x, e.y - e.z, 0f, -16f, 5.5f, GoldAccent, 0.36f, ParticleShape.SPARK)
                }
            }
            val (moveDirX, moveDirY) = if (!e.isBoss) {
                terrainLayout.steerAroundObstacles(e.x, e.y, rawDirX, rawDirY, e.radius * 0.85f)
            } else {
                rawDirX to rawDirY
            }

            val slowFactor = if (e.slowTimer > 0f) 0.52f else 1f
            val leapBoost = if (e.z > e.groundZ + 4f) 1.18f else 1f
            val phaseSpeedMult = if (e.isBoss) (1f + (e.bossPhase - 1) * 0.14f) else 1f
            val moveSpd = when {
                e.chargeActiveTimer > 0f -> 0f
                e.staggerTimer > 0f -> e.speed * 0.16f
                e.telegraphTimer > 0f -> e.speed * 0.18f
                else -> e.speed * slowFactor * leapBoost * phaseSpeedMult
            }
            e.x += moveDirX * moveSpd * dt + e.vxKnock * dt
            e.y += moveDirY * moveSpd * dt + e.vyKnock * dt
            e.vxKnock *= (1f - min(1f, dt * 8f))
            e.vyKnock *= (1f - min(1f, dt * 8f))

            // Solid 2.5D tree/boulder & plateau cliff ledge collision for non-boss enemies
            if (!e.isBoss) {
                val (pushedX, pushedY) = terrainLayout.resolveObstaclePush(e.x, e.y, e.radius * 0.85f)
                val (ledgedX, ledgedY) = terrainLayout.resolveLedgeCollision(pushedX, pushedY, e.z, e.radius * 0.76f)
                e.x = ledgedX
                e.y = ledgedY
            }

            // 2.5D Vertical Gravity & Plateau Elevation Physics for Enemies
            val targetEZ = terrainLayout.groundElevationAt(e.x, e.y)
            e.groundZ = targetEZ
            if (e.z > e.groundZ || e.vz > 0f) {
                val wasMidAir = e.z > e.groundZ + 4f
                e.vz -= 780f * dt
                e.z += e.vz * dt
                if (e.z <= e.groundZ) {
                    val hardLand = wasMidAir && e.vz < -120f
                    e.z = e.groundZ
                    e.vz = 0f
                    if (hardLand) {
                        emitBurst(e.x, e.y - e.groundZ + 6f, 5, biome.pathColor, ParticleShape.DOT, 85f)
                    }
                }
            } else {
                e.z += (e.groundZ - e.z) * min(1f, dt * 12f)
                e.vz = 0f
            }

            // Jumping high overhead or holding altitude difference prevents unfair ground contact hits
            val heightGap = abs(playerZ - e.z)
            if (distToPlayer < e.radius + 22f && heightGap < 26f) {
                damagePlayer(e.contactDamage)
            }
        }
        for ((sx, sy, elite) in pendingBossSummons) {
            if (enemies.size < 54) {
                spawnAmbushEnemyAround(sx, sy, forceElite = elite)
            }
        }
    }

    private fun updateProjectiles(dt: Float) {
        val iter = projectiles.iterator()
        while (iter.hasNext()) {
            val p = iter.next()
            p.life -= dt
            if (p.life <= 0f) {
                iter.remove()
                continue
            }
            if (p.isBeam) continue
            p.x += p.vx * dt
            p.y += p.vy * dt

            // 2.5D Solid Obstacle Cover Interception (Boulders & Tall Tree Trunks block low shots; High-Ground clears low cover!)
            val hitObs = terrainLayout.findProjectileObstacleImpact(p.x, p.y, p.radius, p.z)
            if (hitObs != null) {
                val chipColor = if (hitObs.kind == TerrainObstacleKind.TALL_TREE) GrassGreen else Color(0xFFD6C8B4)
                val chipShape = if (hitObs.kind == TerrainObstacleKind.TALL_TREE) ParticleShape.LEAF else ParticleShape.SPARK
                val impactScreenY = p.y - p.z * 0.7f
                emitBurst(p.x, impactScreenY, 7, chipColor, chipShape, 165f)
                rings.add(InternalRing(p.x, impactScreenY, 6f, 28f, if (p.isEnemy) Color(0xFF72F2FF) else chipColor, 0.20f, 0.20f))
                if (p.isEnemy) {
                    val distPlayerToCover = hypot(playerX - hitObs.x, playerY - hitObs.y)
                    if (distPlayerToCover <= hitObs.collisionRadius + 165f && coverBlockFloatCooldown <= 0f) {
                        coverBlockFloatCooldown = 0.85f
                        spawnFloat(hitObs.x, hitObs.y - hitObs.groundZ - hitObs.height * 0.45f, "掩体格挡", Color(0xFF72F2FF), isCrit = false)
                        onSfx(SfxType.DODGE)
                    }
                }
                iter.remove()
                continue
            }

            if (frameTick % 3L == 0L) {
                val shape = if (p.isEnemy) ParticleShape.SPARK else if (p.element == ElementType.GRASS) ParticleShape.LEAF else ParticleShape.DOT
                emitParticle(p.x, p.y - p.z * 0.7f, -p.vx * 0.08f, -p.vy * 0.08f, p.radius * 0.52f, p.color, 0.22f, shape)
            }

            if (p.isEnemy) {
                val dPlayer = hypot(playerX - p.x, playerY - p.y)
                if (dPlayer <= p.radius + 19f && abs(playerZ - p.z) < 28f) {
                    damagePlayer(p.damage)
                    emitBurst(p.x, p.y - p.z * 0.7f, 6, CrimsonRed, ParticleShape.SPARK, 150f)
                    iter.remove()
                }
                continue
            }

            for (ei in enemies.lastIndex downTo 0) {
                if (ei >= enemies.size) continue
                val e = enemies[ei]
                if (p.hitSet.contains(e.id)) continue
                if (hypot(e.x - p.x, e.y - p.y) <= e.radius + p.radius) {
                    p.hitSet.add(e.id)
                    val a = atan2(p.vy, p.vx)
                    damageEnemy(
                        e = e,
                        rawDamage = p.damage,
                        isUlt = false,
                        knockAngle = a,
                        knockForce = p.knockback,
                        burn = p.burns,
                        slow = p.slows,
                        attackElement = p.element,
                        sourceMoveId = p.sourceMoveId,
                        attackerZ = p.z
                    )
                    if (p.hitSet.size >= p.pierce) {
                        iter.remove()
                        break
                    }
                }
            }
        }
    }

    private fun damageEnemy(
        e: InternalEnemy,
        rawDamage: Float,
        isUlt: Boolean,
        knockAngle: Float,
        knockForce: Float,
        burn: Boolean,
        slow: Boolean,
        attackElement: ElementType = starter.element,
        sourceMoveId: String? = null,
        attackerZ: Float = playerZ
    ) {
        val enemyElem = GameCatalog.enemies[e.defId]?.element ?: ElementType.GROUND
        val typeMult = ElementalMatchup.multiplier(attackElement, enemyElem)
        val isSuperEffective = typeMult >= 1.3f
        val isHighGroundAdvantage = attackerZ >= e.z + 12f
        val highGroundMult = if (isHighGroundAdvantage) 1.20f else 1.0f
        val staggerMult = if (e.staggerTimer > 0f) 1.35f else 1.0f
        val lanternMult = if (e.lanternVulnerableTimer > 0f) 1.18f else 1.0f
        val isCrit = rng.nextFloat() < critChance
        val critMult = if (ElementalBondId.ASTRAL_OVERLOAD in activeBonds) 1.95f else 1.65f
        val dmg = rawDamage * typeMult * highGroundMult * staggerMult * lanternMult * if (isCrit) critMult else 1.0f
        e.hp -= dmg
        e.hitFlash = 1f
        if (isUlt) {
            ultTotalDamageDealt += dmg
        } else if (sourceMoveId != null) {
            moveSlots.firstOrNull { it.def.id == sourceMoveId }?.let { it.totalDamageDealt += dmg }
        }
        val kbScale = if (e.isBoss) 0.15f else 1f
        e.vxKnock += cos(knockAngle) * knockForce * kbScale
        e.vyKnock += sin(knockAngle) * knockForce * kbScale
        if (burn) {
            e.burnTimer = 2.6f
            e.burnTick = 0.5f
        }
        if (slow) {
            e.slowTimer = 2.4f
        }
        val sparkCount = when {
            isCrit && isSuperEffective -> 10
            isCrit || isSuperEffective || isHighGroundAdvantage || e.staggerTimer > 0f -> 7
            else -> 4
        }
        val sparkColor = when {
            e.staggerTimer > 0f -> Color(0xFF66F6FF)
            isSuperEffective -> Color(0xFF66F6FF)
            isCrit || isHighGroundAdvantage -> GoldAccent
            else -> e.secondaryColor
        }
        emitBurst(e.x, e.y - e.z, sparkCount, sparkColor, ParticleShape.SPARK, if (isCrit || isSuperEffective) 220f else 145f)
        val showHighGroundTag = isHighGroundAdvantage && highGroundFloatCooldown <= 0f
        if (showHighGroundTag) highGroundFloatCooldown = 0.65f
        val label = when {
            e.staggerTimer > 0f && isCrit -> "${dmg.toInt()}! 破防"
            e.staggerTimer > 0f -> "${dmg.toInt()} 破防"
            isSuperEffective && isCrit -> "${dmg.toInt()}! 克制"
            isSuperEffective -> "${dmg.toInt()} 克制"
            showHighGroundTag -> "${dmg.toInt()} ▲高地"
            isCrit -> "${dmg.toInt()}!"
            isHighGroundAdvantage -> "${dmg.toInt()}▲"
            else -> "${dmg.toInt()}"
        }
        val numColor = when {
            e.staggerTimer > 0f -> Color(0xFF66F6FF)
            isCrit || showHighGroundTag -> GoldAccent
            isSuperEffective -> Color(0xFF66F6FF)
            isHighGroundAdvantage -> Color(0xFFFFE58F)
            else -> Color.White
        }
        spawnFloat(
            e.x + (rng.nextFloat() - 0.5f) * 18f,
            e.y - e.z - e.radius - 6f,
            label,
            numColor,
            isCrit = isCrit || isSuperEffective || showHighGroundTag || e.staggerTimer > 0f
        )
        if ((isCrit && (e.isBoss || e.isElite)) || (isCrit && isSuperEffective)) {
            triggerHitstop(0.024f, 0.024f)
        }
        onSfxPitch(if (isCrit || isSuperEffective) SfxType.CRIT else SfxType.HIT, comboPitch())

        // Hydro-Volt Elemental Bond: Water or Electric hits chain lightning to up to 2 nearby enemies
        if (ElementalBondId.HYDRO_VOLT in activeBonds &&
            electroChainCooldown <= 0f &&
            (attackElement == ElementType.WATER || attackElement == ElementType.ELECTRIC)
        ) {
            electroChainCooldown = 0.36f
            val arcDmg = (dmg * 0.22f).coerceAtLeast(6f)
            var chained = 0
            for (other in enemies) {
                if (other.id == e.id || other.hp <= 0f) continue
                val d = hypot(other.x - e.x, other.y - e.y)
                if (d <= 215f) {
                    other.hp -= arcDmg
                    other.hitFlash = 0.85f
                    other.slowTimer = maxOf(other.slowTimer, 1.1f)
                    projectiles.add(
                        InternalProjectile(
                            id = nextId++,
                            x = e.x,
                            y = e.y - e.z,
                            vx = 0f,
                            vy = 0f,
                            radius = 4.5f,
                            damage = 0f,
                            color = Color(0xFF4BF0FF),
                            element = ElementType.ELECTRIC,
                            knockback = 0f,
                            burns = false,
                            slows = false,
                            life = 0.16f,
                            maxLife = 0.16f,
                            pierce = 0,
                            isBeam = true,
                            endX = other.x,
                            endY = other.y - other.z
                        )
                    )
                    emitBurst(other.x, other.y - other.z, 4, Color(0xFF4BF0FF), ParticleShape.SPARK, 130f)
                    spawnFloat(other.x, other.y - other.z - other.radius, "⚡${arcDmg.toInt()}", Color(0xFF4BF0FF), isCrit = false)
                    chained++
                    if (chained >= 2) break
                }
            }
        }

        if (e.hp <= 0f) {
            if (e.isBoss) {
                triggerHitstop(0.050f, 0.050f)
            } else if (e.isElite) {
                triggerHitstop(0.028f, 0.026f)
            }
            enemies.remove(e)
            handleEnemyDeath(e, isUlt = isUlt)
        }
    }

    private fun handleEnemyDeath(e: InternalEnemy, isUlt: Boolean) {
        kills++
        comboCount++
        if (comboCount > maxCombo) maxCombo = comboCount
        comboTimer = comboWindowSec
        val scoreMult = currentScoreMultiplier()
        val basePoints = when {
            e.isBoss -> 600
            e.isElite -> 120
            else -> 25
        }
        runScore += (basePoints * scoreMult).toInt()

        defeatedEnemyCounts[e.defId] = (defeatedEnemyCounts[e.defId] ?: 0) + 1
        if (starter.id == "wisp" && kills % 6 == 0 && hp < maxHp) {
            hp = min(maxHp, hp + 4f)
            spawnFloat(playerX, playerY - 24f, "+4 魂火", Color(0xFF5AF2E8), isCrit = false)
        }
        emitBurst(e.x, e.y, if (e.isBoss) 28 else if (e.isElite) 14 else 9, e.primaryColor, ParticleShape.SPARK, if (e.isBoss) 320f else 190f)
        rings.add(InternalRing(e.x, e.y, 6f, e.radius * 1.9f, e.secondaryColor, 0.25f, 0.25f))

        if (!isUlt && ultCharge < 1f) {
            val credit = min(killRoom, if (e.isElite) 0.025f else 0.012f)
            killRoom -= credit
            ultCharge = min(1f, ultCharge + credit * ultRateMult)
            if (ultCharge >= 1f && !ultReadyAnnounced) {
                ultReadyAnnounced = true
                onSfx(SfxType.ULT_READY)
            }
        }
        pickups.add(
            InternalPickup(
                id = nextId++,
                kind = if (e.isElite || e.isBoss) PickupKind.XP_LARGE else PickupKind.XP_SMALL,
                x = e.x,
                y = e.y,
                value = e.xpValue
            )
        )
        val coinChance = if (activeWaveEventKind == 1) 0.85f else if (e.isElite) 0.85f else 0.26f
        if (rng.nextFloat() < coinChance) {
            val baseCoin = if (e.isElite) 12 else 4
            val coinVal = if (activeWaveEventKind == 1) (baseCoin * 1.5f).toInt() else baseCoin
            pickups.add(InternalPickup(nextId++, PickupKind.COIN, e.x + 14f, e.y - 10f, coinVal))
        }
        if (e.isElite && rng.nextFloat() < 0.45f) {
            pickups.add(InternalPickup(nextId++, PickupKind.HEART, e.x - 14f, e.y + 12f, 22))
        }
        // Drop Hyper-Awakening Shards (guaranteed on Elite/Boss, higher during Elite Hunt)
        val shardChance = if (activeWaveEventKind == 2) 0.24f else 0.08f
        if (e.isBoss || e.isElite || rng.nextFloat() < shardChance) {
            val shardCount = if (e.isBoss || (e.isElite && activeWaveEventKind == 2)) 2 else 1
            pickups.add(InternalPickup(nextId++, PickupKind.HYPER_SHARD, e.x + 8f, e.y - 18f, shardCount))
        }
        // Drop collectible evolution essences & stardust cores!
        val enemyDef = GameCatalog.enemies[e.defId]
        val elemRes = if (enemyDef != null) {
            EvolutionRegistry.resourceForElement(enemyDef.element)
        } else {
            EvolutionRegistry.resourceForElement(starter.element)
        }
        if (e.isElite || e.isBoss) {
            pickups.add(InternalPickup(nextId++, pickupKindForResource(elemRes), e.x - 16f, e.y - 12f, if (e.isBoss) 3 else 2))
            if (e.isBoss || rng.nextFloat() < 0.65f) {
                pickups.add(InternalPickup(nextId++, PickupKind.STARDUST_CORE, e.x + 18f, e.y + 14f, 1))
            }
        } else if (rng.nextFloat() < 0.36f) {
            // 65% enemy's element essence, 35% starter's elemental essence for smooth progression across biomes
            val dropRes = if (rng.nextFloat() < 0.65f) elemRes else EvolutionRegistry.resourceForElement(starter.element)
            pickups.add(InternalPickup(nextId++, pickupKindForResource(dropRes), e.x - 12f, e.y + 10f, 1))
        }
        // Verdant Blaze Elemental Bond: Burning enemies explode on defeat and spread scorch AoE
        if (ElementalBondId.VERDANT_BLAZE in activeBonds && e.burnTimer > 0f) {
            val scorchRadius = 138f * areaMult
            val scorchDmg = 24f * damageMult
            rings.add(InternalRing(e.x, e.y, 12f, scorchRadius, WarmOrange, 0.34f, 0.34f))
            emitBurst(e.x, e.y, 12, GrassGreen, ParticleShape.LEAF, 200f)
            for (other in enemies) {
                if (other.id == e.id || other.hp <= 0f) continue
                if (hypot(other.x - e.x, other.y - e.y) <= scorchRadius + other.radius) {
                    other.hp -= scorchDmg
                    other.burnTimer = maxOf(other.burnTimer, 2.2f)
                    other.burnTick = min(other.burnTick, 0.45f)
                    other.hitFlash = 0.8f
                }
            }
        }

        // Stardust Mimic Treasure Jackpot!
        if (e.defId == "stardust_mimic") {
            repeat(3) { idx ->
                val ang = idx * 2.09f
                pickups.add(InternalPickup(nextId++, PickupKind.COIN, e.x + cos(ang) * 24f, e.y + sin(ang) * 24f, 22))
            }
            pickups.add(InternalPickup(nextId++, PickupKind.STARDUST_CORE, e.x - 20f, e.y - 16f, 2))
            pickups.add(InternalPickup(nextId++, PickupKind.HEART, e.x + 20f, e.y + 12f, 30))
            rings.add(InternalRing(e.x, e.y, 16f, 190f, GoldAccent, 0.50f, 0.50f))
            emitBurst(e.x, e.y, 24, GoldAccent, ParticleShape.SPARK, 280f)
            spawnFloat(e.x, e.y - 34f, "★ 宝箱怪击败！丰厚星尘掉落!", GoldAccent, isCrit = true)
            onSfx(SfxType.CHEST)
            activeWaveEventTimer = 0f
            activeWaveEventKind = -1
            activeWaveEventTitleZh = null
        }

        if (e.isBoss) {
            bossesClearedCount++
            bossDefeated = true
            if (gameMode == GameMode.CLASSIC || gameMode == GameMode.DUEL) {
                finishRun(victory = true)
            } else {
                // Survival Mode: celebrate & keep going endlessly!
                props.add(InternalProp(nextId++, WorldPropKind.WOODEN_CHEST, e.x, e.y))
                evolutionBannerText = "已击败守护者 ×$bossesClearedCount！无尽波次升级!"
                evolutionBannerTimer = 3.2f
                onSfx(SfxType.VICTORY)
            }
        }
    }

    private fun damagePlayer(rawDmg: Float) {
        if (invulnTimer > 0f) return
        val scaledRaw = rawDmg * challengePlayerTakenMult
        val mitigated = (scaledRaw * (100f / (100f + armor * 2.2f))).coerceAtLeast(3f)
        hp -= mitigated
        invulnTimer = 0.55f
        hurtFlashTimer = 0.35f
        triggerShake(6f)
        triggerHitstop(0.022f, 0.018f)
        globalHitTrigger.triggerHit(
            damageAmount = mitigated,
            maxHp = maxHp,
            screenShakeEnabled = screenShakeEnabled
        )
        emitBurst(playerX, playerY, 8, CrimsonRed, ParticleShape.SPARK, 170f)
        onSfx(SfxType.HURT)
        spawnFloat(playerX, playerY - 30f, "-${mitigated.toInt()}", CrimsonRed, isCrit = false)

        if (starter.id == "shell") {
            rings.add(InternalRing(playerX, playerY, 20f, 155f, SkyBlue, 0.32f, 0.32f))
            for (e in enemies) {
                val d = hypot(e.x - playerX, e.y - playerY)
                if (d < 155f) {
                    val a = atan2(e.y - playerY, e.x - playerX)
                    e.vxKnock += cos(a) * 260f
                    e.vyKnock += sin(a) * 260f
                }
            }
        }

        if (hp <= 0f) {
            if (revivesRemaining > 0) {
                revivesRemaining--
                hp = maxHp * 0.65f
                invulnTimer = 2.0f
                rings.add(InternalRing(playerX, playerY, 25f, 240f, GoldAccent, 0.6f, 0.6f))
                emitBurst(playerX, playerY, 24, GoldAccent, ParticleShape.SPARK, 280f)
                spawnFloat(playerX, playerY - 46f, "星尘复生!", GoldAccent, isCrit = true)
                onSfx(SfxType.EVOLVE)
            } else {
                hp = 0f
                finishRun(victory = false)
            }
        }
    }

    private fun updatePickups(dt: Float) {
        val iter = pickups.iterator()
        val comboYieldBonus = 1f + (currentScoreMultiplier() - 1f) * 0.08f
        while (iter.hasNext()) {
            val pk = iter.next()
            val dx = playerX - pk.x
            val dy = playerY - pk.y
            val dist = hypot(dx, dy)
            if (magnetVacuumTimer > 0f) {
                val pull = 880f
                pk.x += (dx / dist.coerceAtLeast(1f)) * pull * dt
                pk.y += (dy / dist.coerceAtLeast(1f)) * pull * dt
            } else if (dist < magnetRadius) {
                val pull = 440f + (magnetRadius - dist) * 2.2f
                pk.x += (dx / dist.coerceAtLeast(1f)) * pull * dt
                pk.y += (dy / dist.coerceAtLeast(1f)) * pull * dt
            }
            if (dist < 30f) {
                when (pk.kind) {
                    PickupKind.XP_SMALL, PickupKind.XP_LARGE -> {
                        val swarmXpBoost = if (activeWaveEventKind == 0) 1.35f else 1f
                        xp += pk.value * xpMult * comboYieldBonus * swarmXpBoost
                        emitBurst(playerX, playerY, 4, Color(0xFF72FF96), ParticleShape.DOT, 110f)
                        onSfxPitch(SfxType.XP, comboPitch())
                        checkLevelUp()
                    }
                    PickupKind.COIN -> {
                        coins += (pk.value * goldMult * comboYieldBonus).toInt().coerceAtLeast(1)
                        emitBurst(playerX, playerY, 4, GoldAccent, ParticleShape.SPARK, 120f)
                        onSfxPitch(SfxType.XP, (comboPitch() + 0.08f).coerceAtMost(1.38f))
                    }
                    PickupKind.HEART -> {
                        hp = min(maxHp, hp + pk.value)
                        emitBurst(playerX, playerY, 7, GrassGreen, ParticleShape.SPARK, 140f)
                        spawnFloat(playerX, playerY - 26f, "+${pk.value} HP", GrassGreen, isCrit = false)
                        onSfx(SfxType.LEVEL_UP)
                    }
                    PickupKind.ESSENCE_BLOOM -> collectEssence(EvolutionResourceType.ESSENCE_BLOOM, pk.value)
                    PickupKind.ESSENCE_EMBER -> collectEssence(EvolutionResourceType.ESSENCE_EMBER, pk.value)
                    PickupKind.ESSENCE_TIDE -> collectEssence(EvolutionResourceType.ESSENCE_TIDE, pk.value)
                    PickupKind.STARDUST_CORE -> collectEssence(EvolutionResourceType.STARDUST_CORE, pk.value)
                    PickupKind.HYPER_SHARD -> {
                        addHyperCharge(0.18f * pk.value)
                        emitBurst(playerX, playerY, 9, Color(0xFFFF66E5), ParticleShape.SPARK, 165f)
                        spawnFloat(playerX, playerY - 30f, "+${18 * pk.value}% 超觉醒", Color(0xFFFF7AF6), isCrit = true)
                        onSfx(SfxType.XP)
                    }
                }
                iter.remove()
            }
        }
    }

    private fun pickupKindForResource(res: EvolutionResourceType): PickupKind = when (res) {
        EvolutionResourceType.ESSENCE_BLOOM -> PickupKind.ESSENCE_BLOOM
        EvolutionResourceType.ESSENCE_EMBER -> PickupKind.ESSENCE_EMBER
        EvolutionResourceType.ESSENCE_TIDE -> PickupKind.ESSENCE_TIDE
        EvolutionResourceType.STARDUST_CORE -> PickupKind.STARDUST_CORE
    }

    private fun collectEssence(res: EvolutionResourceType, amount: Int) {
        evolutionController.addResource(res, amount)
        emitBurst(playerX, playerY, 7, res.color, ParticleShape.SPARK, 155f)
        spawnFloat(playerX, playerY - 28f, "+$amount ${res.shortZh}", res.color, isCrit = res == EvolutionResourceType.STARDUST_CORE)
        onSfx(SfxType.XP)
        checkEvolutionReadyHint()
    }

    private fun checkEvolutionReadyHint() {
        val ready = evolutionController.readyNextNodes(level)
        if (ready.size > lastReadyEvoCount && ready.isNotEmpty()) {
            evolutionBannerText = "进化就绪！点击左上进化徽章选择分支"
            evolutionBannerTimer = 3.2f
            rings.add(InternalRing(playerX, playerY, 18f, 190f, GoldAccent, 0.5f, 0.5f))
            onSfx(SfxType.ULT_READY)
        }
        lastReadyEvoCount = ready.size
    }

    private fun checkLevelUp() {
        if (xp < xpToNext) return
        xp -= xpToNext
        level++
        xpToNext = (38f + level * 18f + level * level * 1.4f)
        rings.add(InternalRing(playerX, playerY, 16f, 180f, GoldAccent, 0.45f, 0.45f))
        emitBurst(playerX, playerY, 16, GoldAccent, ParticleShape.SPARK, 230f)
        onSfx(SfxType.LEVEL_UP)
        onHaptic()
        checkEvolutionReadyHint()
        openDraftModal()
    }

    private fun openDraftModal() {
        draftOptions = generateDraftOptions()
    }

    private fun generateDraftOptions(): List<DraftOption> {
        val count = if ((labLevels["choice4"] ?: 0) >= 1) 4 else 3
        val evoPool = mutableListOf<DraftOption>()
        val eligibleEvos = evolutionController.levelEligibleNextNodes(level)
        for (node in eligibleEvos) {
            val statParts = buildList {
                if (node.statDelta.maxHpFlat > 0f) add("生命+${node.statDelta.maxHpFlat.toInt()}")
                if (node.statDelta.damagePct > 0f) add("攻击+${(node.statDelta.damagePct * 100).toInt()}%")
                if (node.statDelta.speedPct > 0f) add("移速+${(node.statDelta.speedPct * 100).toInt()}%")
                if (node.statDelta.armorFlat > 0f) add("护甲+${node.statDelta.armorFlat.toInt()}")
                if (node.statDelta.critPct > 0f) add("暴击+${(node.statDelta.critPct * 100).toInt()}%")
                if (node.statDelta.areaPct > 0f) add("范围+${(node.statDelta.areaPct * 100).toInt()}%")
            }.take(3).joinToString(" · ")
            val tierTag = if (node.tier == 1) "一阶进化形态" else "二阶终极进化"
            val bonusMoveName = node.bonusMoveId?.let { GameCatalog.moves[it]?.nameZh }
            val perkHint = when {
                bonusMoveName != null -> "★ 解锁形态并习得【$bonusMoveName】· 必杀：${node.ultNameZh}"
                else -> "★ 必杀觉醒：${node.ultNameZh}"
            }
            evoPool.add(
                DraftOption(
                    id = "evo_${node.id}",
                    titleZh = node.nameZh,
                    subtitleZh = "$tierTag · ${node.roleTagZh}",
                    detailZh = statParts.ifEmpty { node.descZh },
                    isMove = false,
                    optionKind = DraftOptionKind.EVOLUTION_FORM,
                    evolutionNodeId = node.id,
                    evolutionVisualStyle = node.visualStyle,
                    rarity = if (node.tier >= 2) Rarity.LEGENDARY else Rarity.EPIC,
                    element = starter.element,
                    nextLevel = node.tier,
                    archetype = null,
                    synergyHintZh = perkHint
                )
            )
        }

        val pool = mutableListOf<DraftOption>()
        val bossElement = GameCatalog.enemies[biome.bossId]?.element
        val candidateMoves = (starter.signatureMoves + GameCatalog.moves.keys).distinct()
        for (moveId in candidateMoves) {
            if (banishedIds.contains(moveId)) continue
            val def = GameCatalog.moves[moveId] ?: continue
            val existing = moveSlots.firstOrNull { it.def.id == moveId }
            if (existing == null && moveSlots.size >= maxMoveSlots) continue
            if (existing != null && existing.level >= 8) continue
            val nextLv = (existing?.level ?: 0) + 1
            val rarity = rollRarity(isSignature = starter.signatureMoves.contains(moveId))
            val syn = GameCatalog.synergyForMove(moveId)
            val countersBoss = bossElement != null && ElementalMatchup.isSuperEffective(def.type, bossElement)
            val currentElements = moveSlots.map { it.def.type }.toSet()
            val bondHint = ElementalBondSystem.bondUnlockHintForElement(currentElements, def.type)
            val synHint = when {
                syn != null && !awakenedMoveIds.contains(moveId) -> {
                    val vitName = GameCatalog.vitamins.firstOrNull { it.id == syn.vitaminId }?.nameZh ?: ""
                    if ((vitaminLevels[syn.vitaminId] ?: 0) >= 1 && nextLv >= 2) {
                        "★ 立即协同觉醒：${syn.evolvedNameZh}!"
                    } else {
                        "协同配方：配【$vitName】→ ${syn.evolvedNameZh}"
                    }
                }
                bondHint != null -> bondHint
                countersBoss -> "⚡ 属性克制本群落守护者 (${biome.bossNameZh}) · 1.45×"
                else -> null
            }
            val moveTitle = when {
                overclockedMoveIds.contains(moveId) -> GameCatalog.overclockFusionTitle(moveId)
                fusedMoveIds.contains(moveId) -> GameCatalog.fusedMoveTitle(moveId)
                awakenedMoveIds.contains(moveId) -> syn?.evolvedNameZh ?: def.nameZh
                else -> def.nameZh
            }
            pool.add(
                DraftOption(
                    id = "move_$moveId",
                    titleZh = moveTitle,
                    subtitleZh = if (existing == null) "新招式 · ${def.type.zhName}" else "招式强化 Lv.${existing.level}→$nextLv",
                    detailZh = def.descZh,
                    isMove = true,
                    optionKind = DraftOptionKind.SKILL_UPGRADE,
                    moveId = moveId,
                    rarity = rarity,
                    element = def.type,
                    nextLevel = nextLv,
                    archetype = def.archetype,
                    synergyHintZh = synHint
                )
            )
        }
        for (vit in GameCatalog.vitamins) {
            if (banishedIds.contains(vit.id)) continue
            val cur = vitaminLevels[vit.id] ?: 0
            if (cur >= 10) continue
            val rarity = rollRarity(isSignature = false)
            val matchingSyn = GameCatalog.synergiesForVitamin(vit.id).firstOrNull { syn ->
                !awakenedMoveIds.contains(syn.moveId) && moveSlots.any { it.def.id == syn.moveId }
            }
            val synHint = matchingSyn?.let { syn ->
                val moveSlot = moveSlots.first { it.def.id == syn.moveId }
                if (moveSlot.level >= 2) "★ 立即触发【${syn.evolvedNameZh}】协同觉醒!"
                else "协同搭配：【${moveSlot.def.nameZh}】Lv.2 解锁 ${syn.evolvedNameZh}"
            }
            pool.add(
                DraftOption(
                    id = "vit_${vit.id}",
                    titleZh = vit.nameZh,
                    subtitleZh = "属性强化 Lv.$cur→${cur + 1}",
                    detailZh = vit.shortEffectZh,
                    isMove = false,
                    optionKind = DraftOptionKind.VITAMIN_BOOST,
                    vitaminId = vit.id,
                    rarity = rarity,
                    element = null,
                    nextLevel = cur + 1,
                    archetype = null,
                    synergyHintZh = synHint
                )
            )
        }

        val shuffledEvos = evoPool.shuffled(rng)
        val shuffledStandard = pool.shuffled(rng)
        val picked = mutableListOf<DraftOption>()

        // When evolution forms are available at this level, guarantee at least 1 evolution branch (randomly 1 or 2)
        if (shuffledEvos.isNotEmpty()) {
            val evoSlots = if (shuffledEvos.size >= 2 && rng.nextFloat() < 0.48f) 2 else 1
            for (evo in shuffledEvos.take(evoSlots)) {
                if (picked.size < count) picked.add(evo)
            }
        }

        val sigMove = shuffledStandard.firstOrNull { it.isMove && it.moveId in starter.signatureMoves }
        if (sigMove != null && picked.size < count && picked.none { it.id == sigMove.id }) {
            picked.add(sigMove)
        }
        for (item in shuffledStandard) {
            if (picked.size >= count) break
            if (picked.none { it.id == item.id }) picked.add(item)
        }

        // Place an Evolution Form card cleanly in the spotlight center slot if present
        if (picked.size >= 3) {
            val evoIdx = picked.indexOfFirst { it.optionKind == DraftOptionKind.EVOLUTION_FORM }
            val mid = picked.size / 2
            if (evoIdx >= 0 && evoIdx != mid) {
                val tmp = picked[mid]
                picked[mid] = picked[evoIdx]
                picked[evoIdx] = tmp
            }
        }
        return picked
    }

    private fun rollRarity(isSignature: Boolean): Rarity {
        val roll = rng.nextFloat() * 100f + luck * 0.45f + if (isSignature) 8f else 0f
        return when {
            roll >= 97f -> Rarity.LEGENDARY
            roll >= 85f -> Rarity.EPIC
            roll >= 66f -> Rarity.RARE
            roll >= 40f -> Rarity.UNCOMMON
            else -> Rarity.COMMON
        }
    }

    private fun finishRun(victory: Boolean): RunSummary {
        val survivalSec = elapsedSec.toInt()
        val baseDust = (kills * 1.4f + coins * 0.7f + survivalSec * 0.6f).toInt()
        val clearBonus = when {
            !victory -> 0
            gameMode == GameMode.DUEL -> (biome.stardustBonus * 0.75f).toInt()
            else -> biome.stardustBonus
        }
        val metaAndChallengeMult = 1f + masteryBonuses.stardustBonusPct + ((challengeStardustBonusPct + bossPortalEarlyBonusPct) / 100f)
        val totalDust = ((baseDust + clearBonus) * goldMult * metaAndChallengeMult).toInt().coerceAtLeast(15)
        val stars = when {
            victory && hp >= maxHp * 0.5f -> 3
            victory -> 2
            survivalSec >= 45 || kills >= 35 -> 1
            else -> 0
        }
        val summary = RunSummary(
            victory = victory,
            stars = stars,
            starterId = starter.id,
            biomeId = biome.id,
            survivalSec = survivalSec,
            kills = kills,
            finalLevel = level,
            chestsOpened = chestsOpened,
            coinsCollected = coins,
            stardustEarned = totalDust,
            bossDefeated = bossDefeated,
            score = runScore,
            maxCombo = maxCombo,
            topMoveDamages = buildMoveDamageEntries().take(4)
        )
        runSummary = summary
        onSfx(if (victory) SfxType.VICTORY else SfxType.DEFEAT)
        return summary
    }

    private fun buildMoveDamageEntries(): List<MoveDamageEntry> {
        val list = moveSlots.map { slot ->
            val overclocked = overclockedMoveIds.contains(slot.def.id)
            val fused = fusedMoveIds.contains(slot.def.id)
            val awakened = awakenedMoveIds.contains(slot.def.id) || fused || overclocked
            val displayName = when {
                overclocked -> GameCatalog.overclockFusionTitle(slot.def.id)
                fused -> GameCatalog.fusedMoveTitle(slot.def.id)
                awakenedMoveIds.contains(slot.def.id) -> GameCatalog.synergyForMove(slot.def.id)?.evolvedNameZh ?: slot.def.nameZh
                else -> slot.def.nameZh
            }
            MoveDamageEntry(
                moveId = slot.def.id,
                nameZh = displayName,
                element = slot.def.type,
                level = slot.level,
                totalDamage = slot.totalDamageDealt.toInt(),
                awakened = awakened
            )
        }.toMutableList()
        if (ultTotalDamageDealt >= 1f) {
            list.add(
                MoveDamageEntry(
                    moveId = "ult_burst",
                    nameZh = evolutionController.currentNode.ultNameZh,
                    element = starter.element,
                    level = evolutionStage + 1,
                    totalDamage = ultTotalDamageDealt.toInt(),
                    awakened = true
                )
            )
        }
        return list.sortedByDescending { it.totalDamage }
    }

    private fun findNearestEnemy(maxDist: Float): InternalEnemy? {
        var best: InternalEnemy? = null
        var bestD = maxDist
        for (e in enemies) {
            val d = hypot(e.x - playerX, e.y - playerY)
            if (d < bestD) {
                bestD = d
                best = e
            }
        }
        return best
    }

    private fun findNearbyProp(): InternalProp? {
        return props.firstOrNull { !it.opened && hypot(it.x - playerX, it.y - playerY) <= 105f }
    }

    private fun spawnFloat(x: Float, y: Float, text: String, color: Color, isCrit: Boolean) {
        if (floatingNumbers.size > 26) floatingNumbers.removeAt(0)
        var fx = x
        var fy = y
        // Keep pickups & notifications clear of the hero sprite's face
        if (hypot(fx - playerX, fy - playerY) < 42f) {
            fx += (rng.nextFloat() - 0.5f) * 34f
            fy = min(fy, playerY - 48f)
        }
        // Light de-clumping when multiple numbers pop in the same spot
        var attempts = 0
        while (attempts < 4 && floatingNumbers.any { hypot(it.x - fx, it.y - fy) < 28f }) {
            fx += if (attempts % 2 == 0) 22f else -24f
            fy -= 16f
            attempts++
        }
        floatingNumbers.add(InternalFloatText(nextId++, fx, fy, text, color, isCrit, 0.72f, 0.72f))
    }

    private fun triggerShake(amount: Float) {
        if (screenShakeEnabled) {
            screenShakeMagnitude = maxOf(screenShakeMagnitude, amount)
        }
    }

    private fun computeDangerTier(): Int {
        val score = (elapsedSec / 18f) + if (bossSpawned && !bossDefeated) 1.5f else 0f
        return when {
            score >= 7.0f -> 6
            score >= 5.5f -> 5
            score >= 4.0f -> 4
            score >= 3.0f -> 3
            score >= 2.0f -> 2
            score >= 1.0f -> 1
            else -> 0
        }
    }

    private fun buildSnapshot(): BattleRenderState {
        val activeBoss = enemies.firstOrNull { it.isBoss }
        val nearbyProp = findNearbyProp()
        val objectives = listOf(
            ObjectiveSnapshot(
                titleZh = when (gameMode) {
                    GameMode.CLASSIC -> "击败 ${biome.bossNameZh}"
                    GameMode.DUEL -> "决斗 · 击败 ${biome.bossNameZh}"
                    GameMode.SURVIVAL -> "无尽生存 · 击退守护者"
                },
                progressText = if (gameMode == GameMode.SURVIVAL) {
                    "已击退 $bossesClearedCount 次"
                } else if (bossDefeated) {
                    "已完成"
                } else if (bossSpawned) {
                    "战斗中"
                } else if (gameMode == GameMode.DUEL) {
                    "完成构筑立即开战"
                } else {
                    "${(nextBossTimeSec - elapsedSec).coerceAtLeast(0f).toInt()}s 后降临"
                },
                completed = (gameMode == GameMode.CLASSIC || gameMode == GameMode.DUEL) && bossDefeated
            ),
            ObjectiveSnapshot(
                titleZh = "开启木纹宝箱",
                progressText = "$chestsOpened / 2",
                completed = chestsOpened >= 2
            ),
            ObjectiveSnapshot(
                titleZh = "收集精华完成分支进化",
                progressText = "${evolutionController.currentNode.nameZh} (${evolutionStage + 1}/3)",
                completed = evolutionStage >= 2
            )
        )

        val evoSnap = evolutionController.snapshot(level)
        val nearSynergyHint = computeNearSynergyHint()
        return BattleRenderState(
            frameTick = frameTick,
            starterId = starter.id,
            biomeId = biome.id,
            gameMode = gameMode,
            evolutionStage = evolutionStage,
            playerX = playerX,
            playerY = playerY,
            playerVx = movementState.vx,
            playerVy = movementState.vy,
            cameraX = movementState.cameraX,
            cameraY = movementState.cameraY,
            facingAngle = facingAngle,
            leanDeg = movementState.leanDeg,
            moveSpeedRatio = movementState.speedRatio,
            attackFlashTimer = attackFlashTimer,
            hurtFlashTimer = hurtFlashTimer,
            dashActiveTimer = dashActiveTimer,
            dashCooldownRatio = movementState.dashCooldownRatio,
            playerZ = playerZ,
            playerGroundZ = playerGroundZ,
            isOnHighGround = playerGroundZ > 6f,
            isJumping = playerZ > playerGroundZ + 3f,
            isGliding = isGliding,
            jumpCooldownRatio = (jumpCooldown / jumpCooldownTotal).coerceIn(0f, 1f),
            hp = hp,
            maxHp = maxHp,
            xp = xp,
            xpToNext = xpToNext,
            level = level,
            kills = kills,
            coins = coins,
            chestsOpened = chestsOpened,
            elapsedSec = elapsedSec,
            dangerTier = computeDangerTier(),
            ultCharge = ultCharge,
            ultActiveTimer = ultActiveTimer,
            ultNameZh = evolutionController.currentNode.ultNameZh,
            hyperCharge = hyperCharge,
            hyperActiveTimer = hyperActiveTimer,
            hyperMaxDuration = hyperMaxDuration,
            comboCount = comboCount,
            comboTimerRatio = (comboTimer / comboWindowSec).coerceIn(0f, 1f),
            scoreMultiplier = currentScoreMultiplier(),
            runScore = runScore,
            maxCombo = maxCombo,
            activeMoves = moveSlots.map {
                val overclocked = overclockedMoveIds.contains(it.def.id)
                val fused = fusedMoveIds.contains(it.def.id)
                val awakened = awakenedMoveIds.contains(it.def.id) || fused || overclocked
                val displayName = when {
                    overclocked -> GameCatalog.overclockFusionTitle(it.def.id)
                    fused -> GameCatalog.fusedMoveTitle(it.def.id)
                    awakenedMoveIds.contains(it.def.id) -> GameCatalog.synergyForMove(it.def.id)?.evolvedNameZh ?: it.def.nameZh
                    else -> it.def.nameZh
                }
                ActiveMoveSlot(
                    moveId = it.def.id,
                    nameZh = displayName,
                    element = it.def.type,
                    archetype = it.def.archetype,
                    level = it.level,
                    cooldownRemaining = it.cooldown.coerceAtLeast(0f),
                    cooldownTotal = it.def.cooldownSec,
                    awakened = awakened
                )
            },
            maxMoveSlots = maxMoveSlots,
            enemies = enemies.map {
                EnemySnapshot(
                    id = it.id,
                    defId = it.defId,
                    x = it.x,
                    y = it.y,
                    radius = it.radius,
                    hp = it.hp,
                    maxHp = it.maxHp,
                    isBoss = it.isBoss,
                    isElite = it.isElite,
                    primaryColor = it.primaryColor,
                    secondaryColor = it.secondaryColor,
                    hitFlash = it.hitFlash,
                    slowTimer = it.slowTimer,
                    burnTimer = it.burnTimer,
                    telegraphProgress = if (it.telegraphTimer > 0f) (1f - (it.telegraphTimer / it.telegraphDuration.coerceAtLeast(0.1f))).coerceIn(0f, 1f) else 0f,
                    telegraphRadius = when (it.bossPhase) {
                        1 -> 175f
                        2 -> 195f
                        else -> 215f
                    },
                    animPhase = it.animPhase,
                    facingLeft = it.facingLeft,
                    groundZ = it.groundZ,
                    z = it.z,
                    bossPhase = it.bossPhase,
                    telegraphKind = it.telegraphKind,
                    chargeDirX = it.chargeDirX,
                    chargeDirY = it.chargeDirY,
                    chargeLength = if (it.telegraphKind == BossAttackKind.LINE_CHARGE) 285f else 0f,
                    staggerTimer = it.staggerTimer
                )
            },
            projectiles = projectiles.map {
                ProjectileSnapshot(
                    id = it.id,
                    x = it.x,
                    y = it.y,
                    vx = it.vx,
                    vy = it.vy,
                    radius = it.radius,
                    color = it.color,
                    element = it.element,
                    isBeam = it.isBeam,
                    endX = it.endX,
                    endY = it.endY,
                    lifeRatio = (it.life / it.maxLife).coerceIn(0f, 1f),
                    isEnemy = it.isEnemy,
                    z = it.z,
                    isHighGroundBoosted = it.isHighGroundBoosted,
                    isAwakened = it.isAwakened
                )
            },
            rings = rings.map {
                ExpandingRingSnapshot(
                    x = it.x,
                    y = it.y,
                    radius = it.radius,
                    maxRadius = it.maxRadius,
                    color = it.color,
                    alpha = (it.life / it.maxLife).coerceIn(0f, 1f)
                )
            },
            slashArcs = slashArcs.map {
                SlashArcSnapshot(
                    x = it.x,
                    y = it.y,
                    angleRad = it.angleRad,
                    radius = it.radius,
                    color = it.color,
                    alpha = (it.life / it.maxLife).coerceIn(0f, 1f),
                    isAwakened = it.isAwakened
                )
            },
            particles = particles.map {
                ParticleSnapshot(
                    x = it.x,
                    y = it.y,
                    size = it.size * (0.45f + 0.55f * (it.life / it.maxLife).coerceIn(0f, 1f)),
                    color = it.color,
                    alpha = (it.life / it.maxLife).coerceIn(0f, 1f),
                    shape = it.shape,
                    angleRad = it.angleRad
                )
            },
            dashGhosts = dashGhosts.map {
                DashGhostSnapshot(
                    x = it.x,
                    y = it.y,
                    alpha = (it.life / it.maxLife).coerceIn(0f, 1f) * 0.5f,
                    color = it.color
                )
            },
            pickups = pickups.map { PickupSnapshot(it.id, it.kind, it.x, it.y, it.value) },
            props = props.map { WorldPropSnapshot(it.id, it.kind, it.x, it.y, it.opened) },
            floatingNumbers = floatingNumbers.map {
                FloatingNumberSnapshot(
                    id = it.id,
                    x = it.x,
                    y = it.y,
                    text = it.text,
                    color = it.color,
                    isCrit = it.isCrit,
                    alpha = (it.life / it.maxLife).coerceIn(0f, 1f)
                )
            },
            activeBossName = activeBoss?.let { GameCatalog.enemies[it.defId]?.nameZh },
            activeBossHpRatio = activeBoss?.let { (it.hp / it.maxHp).coerceIn(0f, 1f) } ?: 0f,
            activeBossTag = "群落守护者",
            activeBossPhase = activeBoss?.bossPhase ?: 1,
            activeBossStaggered = (activeBoss?.staggerTimer ?: 0f) > 0f,
            nearbyInteractKind = nearbyProp?.kind,
            nearbyPropId = nearbyProp?.id,
            biomeBannerTimer = biomeBannerTimer,
            evolutionBannerText = evolutionBannerText,
            screenShakeMagnitude = screenShakeMagnitude,
            hitFeedback = globalHitTrigger.snapshot(),
            revivesRemaining = revivesRemaining,
            objectives = objectives,
            isPaused = isPaused,
            isEvolutionModalOpen = isEvolutionModalOpen,
            evolutionState = evoSnap,
            activeSynergyCount = awakenedMoveIds.size,
            nearSynergyHintZh = nearSynergyHint,
            activeWaveEventTitleZh = activeWaveEventTitleZh,
            activeWaveEventTimerRatio = (activeWaveEventTimer / activeWaveEventDuration).coerceIn(0f, 1f),
            buildStats = BuildStatsSnapshot(
                damagePct = (damageMult * 100f).toInt(),
                atkSpdPct = (atkSpdMult * 100f).toInt(),
                critPct = (critChance * 100f).toInt(),
                speedPct = (speedMult * 100f).toInt(),
                areaPct = (areaMult * 100f).toInt(),
                armor = armor.toInt(),
                regenPerSec = regenPerSec,
                moveDamages = buildMoveDamageEntries()
            ),
            activeVitamins = vitaminLevels.entries.mapNotNull { (vid, lv) ->
                val name = GameCatalog.vitamins.firstOrNull { it.id == vid }?.nameZh?.take(2) ?: return@mapNotNull null
                name to lv
            },
            draftOptions = draftOptions,
            rerollsLeft = rerollsLeft,
            skipsLeft = skipsLeft,
            banishesLeft = banishesLeft,
            banishModeArmed = banishModeArmed,
            runSummary = runSummary,
            walkAnimTime = walkAnimTime,
            orbitAngle = orbitAngle,
            terrainPlateaus = terrainLayout.plateaus,
            terrainObstacles = terrainLayout.obstacles,
            biomeZones = terrainLayout.ecoZones.map { z ->
                val (phase, prog) = BiomeEcoRules.evaluatePhase(z, elapsedSec)
                BiomeZoneSnapshot(
                    id = z.id,
                    kind = z.kind,
                    x = z.x,
                    y = z.y,
                    radius = z.radius,
                    phase = phase,
                    phaseProgress = prog,
                    groundZ = terrainLayout.groundElevationAt(z.x, z.y)
                )
            },
            activeEcoBuffZh = activeEcoBuffZh,
            activeChallengeCount = challengeModifiers.size,
            challengeStardustBonusPct = challengeStardustBonusPct,
            cameraZoom = cameraZoom,
            fusedMoveCount = fusedMoveIds.size,
            overclockedMoveCount = overclockedMoveIds.size,
            bossPortalEarlyBonusPct = bossPortalEarlyBonusPct,
            bossAlertBannerText = bossAlertBannerText,
            activeBonds = activeBonds
        )
    }

    internal fun forceSpawnBossForTest() {
        if (enemies.none { it.isBoss }) {
            bossSpawned = true
            spawnBoss()
        }
    }

    internal fun damageBossForTest(amount: Float) {
        val boss = enemies.firstOrNull { it.isBoss } ?: return
        boss.hp = (boss.hp - amount).coerceAtLeast(1f)
    }

    internal fun teleportPlayerForTest(x: Float, y: Float) {
        playerX = x
        playerY = y
        movementController.clampWorldPosition(x, y)
    }

    internal fun grantSynergySetupForTest(moveId: String, vitaminId: String) {
        val existing = moveSlots.firstOrNull { it.def.id == moveId }
        if (existing != null) {
            existing.level = maxOf(existing.level, 2)
        } else {
            GameCatalog.moves[moveId]?.let { def ->
                moveSlots.add(InternalMoveSlot(def, level = 2, cooldown = 0f))
            }
        }
        vitaminLevels[vitaminId] = (vitaminLevels[vitaminId] ?: 0) + 1
        recomputeStats(resetHp = false)
        checkMoveSynergies()
    }

    internal fun getTerrainLayoutForTest(): ArenaTerrainLayout = terrainLayout

    internal fun addKillsForTest(count: Int) {
        kills += count
    }

    internal fun spawnPropForTest(kind: WorldPropKind, x: Float, y: Float) {
        props.add(InternalProp(nextId++, kind, x, y))
    }

    internal fun grantMoveForTest(moveId: String, level: Int = 2) {
        val existing = moveSlots.firstOrNull { it.def.id == moveId }
        if (existing != null) {
            existing.level = maxOf(existing.level, level)
        } else {
            GameCatalog.moves[moveId]?.let { def ->
                moveSlots.add(InternalMoveSlot(def, level = level, cooldown = 0f))
            }
        }
        refreshElementalBonds(announceNew = false)
    }

    internal fun triggerDynamicEventForTest(kindOverride: Int? = null) {
        if (kindOverride != null) {
            waveEventIndex = kindOverride
        }
        triggerDynamicWaveEvent()
    }

    private fun computeNearSynergyHint(): String? {
        // Priority 1: Player owns move (any lv) + matching vitamin -> just needs move Lv.2!
        for (syn in GameCatalog.moveSynergies) {
            if (awakenedMoveIds.contains(syn.moveId)) continue
            val slot = moveSlots.firstOrNull { it.def.id == syn.moveId }
            val hasVit = (vitaminLevels[syn.vitaminId] ?: 0) >= 1
            if (slot != null && hasVit && slot.level < 2) {
                return "升【${slot.def.nameZh}】Lv.2 → ${syn.evolvedNameZh}"
            }
        }
        // Priority 2: Player owns move -> needs matching vitamin
        for (syn in GameCatalog.moveSynergies) {
            if (awakenedMoveIds.contains(syn.moveId)) continue
            val slot = moveSlots.firstOrNull { it.def.id == syn.moveId } ?: continue
            val hasVit = (vitaminLevels[syn.vitaminId] ?: 0) >= 1
            if (!hasVit) {
                val vitName = GameCatalog.vitamins.firstOrNull { it.id == syn.vitaminId }?.nameZh ?: continue
                return "协同：${slot.def.nameZh}+${vitName} → ${syn.evolvedNameZh}"
            }
        }
        // Priority 3: Player owns vitamin -> needs matching move
        for (syn in GameCatalog.moveSynergies) {
            if (awakenedMoveIds.contains(syn.moveId)) continue
            val hasVit = (vitaminLevels[syn.vitaminId] ?: 0) >= 1
            val hasMove = moveSlots.any { it.def.id == syn.moveId }
            if (hasVit && !hasMove) {
                val moveName = GameCatalog.moves[syn.moveId]?.nameZh ?: continue
                val vitName = GameCatalog.vitamins.firstOrNull { it.id == syn.vitaminId }?.nameZh ?: continue
                return "协同：${vitName}+${moveName} → ${syn.evolvedNameZh}"
            }
        }
        return null
    }
}
