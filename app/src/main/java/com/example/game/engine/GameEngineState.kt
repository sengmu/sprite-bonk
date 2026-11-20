package com.example.game.engine

import androidx.compose.ui.graphics.Color
import com.example.game.evolution.EvolutionStateSnapshot
import com.example.game.evolution.EvolutionVisualStyle
import com.example.game.model.ElementType
import com.example.game.model.ElementalBondId
import com.example.game.model.GameMode
import com.example.game.model.MoveArchetype
import com.example.game.model.Rarity

data class ActiveMoveSlot(
    val moveId: String,
    val nameZh: String,
    val element: ElementType,
    val archetype: MoveArchetype,
    val level: Int,
    val cooldownRemaining: Float,
    val cooldownTotal: Float,
    val awakened: Boolean = false
)

data class EnemySnapshot(
    val id: Int,
    val defId: String,
    val x: Float,
    val y: Float,
    val radius: Float,
    val hp: Float,
    val maxHp: Float,
    val isBoss: Boolean,
    val isElite: Boolean,
    val primaryColor: Color,
    val secondaryColor: Color,
    val hitFlash: Float,
    val slowTimer: Float,
    val burnTimer: Float,
    val telegraphProgress: Float,
    val telegraphRadius: Float,
    val animPhase: Float,
    val facingLeft: Boolean = false,
    val groundZ: Float = 0f,
    val z: Float = groundZ,
    val bossPhase: Int = 1,
    val telegraphKind: BossAttackKind = BossAttackKind.NONE,
    val chargeDirX: Float = 0f,
    val chargeDirY: Float = 0f,
    val chargeLength: Float = 0f,
    val staggerTimer: Float = 0f
)

data class ProjectileSnapshot(
    val id: Int,
    val x: Float,
    val y: Float,
    val vx: Float,
    val vy: Float,
    val radius: Float,
    val color: Color,
    val element: ElementType,
    val isBeam: Boolean = false,
    val endX: Float = 0f,
    val endY: Float = 0f,
    val lifeRatio: Float = 1f,
    val isEnemy: Boolean = false,
    val z: Float = 0f,
    val isHighGroundBoosted: Boolean = false,
    val isAwakened: Boolean = false
)

data class ExpandingRingSnapshot(
    val x: Float,
    val y: Float,
    val radius: Float,
    val maxRadius: Float,
    val color: Color,
    val alpha: Float
)

data class SlashArcSnapshot(
    val x: Float,
    val y: Float,
    val angleRad: Float,
    val radius: Float,
    val color: Color,
    val alpha: Float,
    val isAwakened: Boolean = false
)

enum class ParticleShape { DOT, SPARK, LEAF, RING_POP }

data class ParticleSnapshot(
    val x: Float,
    val y: Float,
    val size: Float,
    val color: Color,
    val alpha: Float,
    val shape: ParticleShape = ParticleShape.DOT,
    val angleRad: Float = 0f
)

data class DashGhostSnapshot(
    val x: Float,
    val y: Float,
    val alpha: Float,
    val color: Color
)

enum class PickupKind {
    XP_SMALL,
    XP_LARGE,
    COIN,
    HEART,
    ESSENCE_BLOOM,
    ESSENCE_EMBER,
    ESSENCE_TIDE,
    STARDUST_CORE,
    HYPER_SHARD
}

data class PickupSnapshot(
    val id: Int,
    val kind: PickupKind,
    val x: Float,
    val y: Float,
    val value: Int
)

enum class WorldPropKind { WOODEN_CHEST, HEAL_SHRINE, GAMBLE_SHRINE, MAGNET_OBELISK, BOSS_PORTAL, FUSION_MACHINE }

data class WorldPropSnapshot(
    val id: Int,
    val kind: WorldPropKind,
    val x: Float,
    val y: Float,
    val opened: Boolean
)

data class FloatingNumberSnapshot(
    val id: Int,
    val x: Float,
    val y: Float,
    val text: String,
    val color: Color,
    val isCrit: Boolean,
    val alpha: Float
)

enum class DraftOptionKind {
    EVOLUTION_FORM,
    SKILL_UPGRADE,
    VITAMIN_BOOST
}

data class DraftOption(
    val id: String,
    val titleZh: String,
    val subtitleZh: String,
    val detailZh: String,
    val isMove: Boolean,
    val optionKind: DraftOptionKind = if (isMove) DraftOptionKind.SKILL_UPGRADE else DraftOptionKind.VITAMIN_BOOST,
    val moveId: String? = null,
    val vitaminId: String? = null,
    val evolutionNodeId: String? = null,
    val evolutionVisualStyle: EvolutionVisualStyle? = null,
    val rarity: Rarity,
    val element: ElementType?,
    val nextLevel: Int,
    val archetype: MoveArchetype? = null,
    val synergyHintZh: String? = null
)

data class ObjectiveSnapshot(
    val titleZh: String,
    val progressText: String,
    val completed: Boolean
)

data class MoveDamageEntry(
    val moveId: String,
    val nameZh: String,
    val element: ElementType,
    val level: Int,
    val totalDamage: Int,
    val awakened: Boolean = false
)

data class BuildStatsSnapshot(
    val damagePct: Int = 100,
    val atkSpdPct: Int = 100,
    val critPct: Int = 8,
    val speedPct: Int = 100,
    val areaPct: Int = 100,
    val armor: Int = 0,
    val regenPerSec: Float = 0f,
    val moveDamages: List<MoveDamageEntry> = emptyList()
)

data class RunSummary(
    val victory: Boolean,
    val stars: Int,
    val starterId: String,
    val biomeId: String,
    val survivalSec: Int,
    val kills: Int,
    val finalLevel: Int,
    val chestsOpened: Int,
    val coinsCollected: Int,
    val stardustEarned: Int,
    val bossDefeated: Boolean,
    val score: Int = 0,
    val maxCombo: Int = 0,
    val topMoveDamages: List<MoveDamageEntry> = emptyList()
)

data class BattleRenderState(
    val frameTick: Long = 0L,
    val starterId: String = "stump",
    val biomeId: String = "forest",
    val gameMode: GameMode = GameMode.CLASSIC,
    val evolutionStage: Int = 0,
    val playerX: Float = 0f,
    val playerY: Float = 0f,
    val playerVx: Float = 0f,
    val playerVy: Float = 0f,
    val cameraX: Float = 0f,
    val cameraY: Float = 0f,
    val facingAngle: Float = 0f,
    val leanDeg: Float = 0f,
    val moveSpeedRatio: Float = 0f,
    val attackFlashTimer: Float = 0f,
    val hurtFlashTimer: Float = 0f,
    val dashActiveTimer: Float = 0f,
    val dashCooldownRatio: Float = 0f,
    val playerZ: Float = 0f,
    val playerGroundZ: Float = 0f,
    val isOnHighGround: Boolean = false,
    val isJumping: Boolean = false,
    val isGliding: Boolean = false,
    val jumpCooldownRatio: Float = 0f,
    val hp: Float = 100f,
    val maxHp: Float = 100f,
    val xp: Float = 0f,
    val xpToNext: Float = 40f,
    val level: Int = 1,
    val kills: Int = 0,
    val coins: Int = 0,
    val chestsOpened: Int = 0,
    val elapsedSec: Float = 0f,
    val dangerTier: Int = 0,
    val ultCharge: Float = 0f,
    val ultActiveTimer: Float = 0f,
    val ultNameZh: String = "",
    val hyperCharge: Float = 0f,
    val hyperActiveTimer: Float = 0f,
    val hyperMaxDuration: Float = 12f,
    val comboCount: Int = 0,
    val comboTimerRatio: Float = 0f,
    val scoreMultiplier: Float = 1f,
    val runScore: Int = 0,
    val maxCombo: Int = 0,
    val activeMoves: List<ActiveMoveSlot> = emptyList(),
    val maxMoveSlots: Int = 4,
    val enemies: List<EnemySnapshot> = emptyList(),
    val projectiles: List<ProjectileSnapshot> = emptyList(),
    val rings: List<ExpandingRingSnapshot> = emptyList(),
    val slashArcs: List<SlashArcSnapshot> = emptyList(),
    val particles: List<ParticleSnapshot> = emptyList(),
    val dashGhosts: List<DashGhostSnapshot> = emptyList(),
    val pickups: List<PickupSnapshot> = emptyList(),
    val props: List<WorldPropSnapshot> = emptyList(),
    val floatingNumbers: List<FloatingNumberSnapshot> = emptyList(),
    val activeBossName: String? = null,
    val activeBossHpRatio: Float = 0f,
    val activeBossTag: String = "守护者",
    val activeBossPhase: Int = 1,
    val activeBossStaggered: Boolean = false,
    val nearbyInteractKind: WorldPropKind? = null,
    val nearbyPropId: Int? = null,
    val biomeBannerTimer: Float = 0f,
    val evolutionBannerText: String? = null,
    val screenShakeMagnitude: Float = 0f,
    val hitFeedback: HitFeedbackSnapshot = HitFeedbackSnapshot(),
    val revivesRemaining: Int = 0,
    val objectives: List<ObjectiveSnapshot> = emptyList(),
    val isPaused: Boolean = false,
    val isEvolutionModalOpen: Boolean = false,
    val evolutionState: EvolutionStateSnapshot = EvolutionStateSnapshot(),
    val activeSynergyCount: Int = 0,
    val nearSynergyHintZh: String? = null,
    val activeWaveEventTitleZh: String? = null,
    val activeWaveEventTimerRatio: Float = 0f,
    val buildStats: BuildStatsSnapshot = BuildStatsSnapshot(),
    val activeVitamins: List<Pair<String, Int>> = emptyList(),
    val draftOptions: List<DraftOption>? = null,
    val rerollsLeft: Int = 1,
    val skipsLeft: Int = 1,
    val banishesLeft: Int = 1,
    val banishModeArmed: Boolean = false,
    val runSummary: RunSummary? = null,
    val walkAnimTime: Float = 0f,
    val orbitAngle: Float = 0f,
    val terrainPlateaus: List<TerrainPlateau> = emptyList(),
    val terrainObstacles: List<TerrainObstacle> = emptyList(),
    val biomeZones: List<BiomeZoneSnapshot> = emptyList(),
    val activeEcoBuffZh: String? = null,
    val activeChallengeCount: Int = 0,
    val challengeStardustBonusPct: Int = 0,
    val fusedMoveCount: Int = 0,
    val overclockedMoveCount: Int = 0,
    val bossPortalEarlyBonusPct: Int = 0,
    val bossAlertBannerText: String? = null,
    val activeBonds: List<ElementalBondId> = emptyList(),
    val cameraZoom: Float = 1f
)
