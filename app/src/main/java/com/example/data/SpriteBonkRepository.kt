package com.example.data

import com.example.game.model.GameCatalog
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map

data class MetaProgressionSnapshot(
    val profile: ProfileEntity = ProfileEntity(),
    val labLevels: Map<String, Int> = emptyMap(),
    val biomeProgress: Map<String, BiomeProgressEntity> = emptyMap(),
    val dexEntries: Map<String, DexEntryEntity> = emptyMap(),
    val recentRuns: List<RunRecordEntity> = emptyList()
) {
    fun isBiomeUnlocked(biomeId: String): Boolean {
        val biome = GameCatalog.biomeById(biomeId)
        if (biome.orderIndex == 0) return true
        val prev = GameCatalog.biomes.firstOrNull { it.orderIndex == biome.orderIndex - 1 } ?: return true
        return (biomeProgress[prev.id]?.clearedCount ?: 0) > 0
    }

    fun unlockedEvolutionSet(): Set<String> {
        return profile.unlockedEvolutionIds
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toSet()
    }
}

class SpriteBonkRepository(private val dao: SpriteBonkDao) {

    val metaSnapshot: Flow<MetaProgressionSnapshot> = combine(
        dao.observeProfile().map { it ?: ProfileEntity() },
        dao.observeLabUpgrades(),
        dao.observeBiomeProgress(),
        dao.observeDexEntries(),
        dao.observeRecentRuns()
    ) { profile, labs, biomes, dex, runs ->
        MetaProgressionSnapshot(
            profile = profile,
            labLevels = labs.associate { it.upgradeId to it.level },
            biomeProgress = biomes.associateBy { it.biomeId },
            dexEntries = dex.associateBy { it.enemyId },
            recentRuns = runs
        )
    }

    suspend fun ensureInitialized() {
        if (dao.getProfileOnce() == null) {
            dao.upsertProfile(ProfileEntity())
        }
    }

    suspend fun selectStarter(starterId: String) {
        val current = dao.getProfileOnce() ?: ProfileEntity()
        dao.upsertProfile(current.copy(selectedStarterId = starterId))
    }

    suspend fun selectBiome(biomeId: String) {
        val current = dao.getProfileOnce() ?: ProfileEntity()
        dao.upsertProfile(current.copy(selectedBiomeId = biomeId))
    }

    suspend fun selectGameMode(modeId: String) {
        val current = dao.getProfileOnce() ?: ProfileEntity()
        dao.upsertProfile(current.copy(selectedGameMode = modeId))
    }

    suspend fun unlockEvolution(nodeId: String) {
        val current = dao.getProfileOnce() ?: ProfileEntity()
        val set = current.unlockedEvolutionIds.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toMutableSet()
        if (set.add(nodeId)) {
            dao.upsertProfile(current.copy(unlockedEvolutionIds = set.joinToString(",")))
        }
    }

    suspend fun updateSettings(
        sfxEnabled: Boolean? = null,
        vibrationEnabled: Boolean? = null,
        screenShakeEnabled: Boolean? = null,
        autoAimEnabled: Boolean? = null
    ) {
        val current = dao.getProfileOnce() ?: ProfileEntity()
        dao.upsertProfile(
            current.copy(
                sfxEnabled = sfxEnabled ?: current.sfxEnabled,
                vibrationEnabled = vibrationEnabled ?: current.vibrationEnabled,
                screenShakeEnabled = screenShakeEnabled ?: current.screenShakeEnabled,
                autoAimEnabled = autoAimEnabled ?: current.autoAimEnabled
            )
        )
    }

    suspend fun purchaseLabUpgrade(upgradeId: String): Boolean {
        val def = GameCatalog.labUpgrades.firstOrNull { it.id == upgradeId } ?: return false
        val profile = dao.getProfileOnce() ?: ProfileEntity()
        val labs = dao.getLabUpgradesOnce().associate { it.upgradeId to it.level }
        val currentLvl = labs[upgradeId] ?: 0
        if (currentLvl >= def.maxLevel) return false
        val cost = def.costForNext(currentLvl)
        if (profile.stardust < cost) return false

        dao.upsertProfile(profile.copy(stardust = profile.stardust - cost))
        dao.upsertLabUpgrade(LabUpgradeEntity(upgradeId, currentLvl + 1))
        return true
    }

    suspend fun refundAllLabUpgrades(): Int {
        val profile = dao.getProfileOnce() ?: ProfileEntity()
        val labs = dao.getLabUpgradesOnce()
        var refund = 0
        for (entity in labs) {
            val def = GameCatalog.labUpgrades.firstOrNull { it.id == entity.upgradeId } ?: continue
            for (lvl in 0 until entity.level) {
                refund += def.costForNext(lvl)
            }
        }
        if (refund <= 0) return 0
        dao.clearLabUpgrades()
        dao.upsertProfile(profile.copy(stardust = profile.stardust + refund))
        return refund
    }

    suspend fun settleRun(
        starterId: String,
        biomeId: String,
        victory: Boolean,
        survivalSec: Int,
        kills: Int,
        finalLevel: Int,
        stardustEarned: Int,
        seenCounts: Map<String, Int>,
        defeatedCounts: Map<String, Int>
    ) {
        val profile = dao.getProfileOnce() ?: ProfileEntity()
        dao.upsertProfile(
            profile.copy(
                stardust = profile.stardust + stardustEarned,
                totalStardust = profile.totalStardust + stardustEarned,
                totalKills = profile.totalKills + kills,
                totalRuns = profile.totalRuns + 1,
                totalVictories = profile.totalVictories + if (victory) 1 else 0,
                bestSurvivalSec = maxOf(profile.bestSurvivalSec, survivalSec)
            )
        )

        val prevBiome = dao.getBiomeProgressOnce(biomeId)
        dao.upsertBiomeProgress(
            BiomeProgressEntity(
                biomeId = biomeId,
                clearedCount = (prevBiome?.clearedCount ?: 0) + if (victory) 1 else 0,
                bestTimeSec = maxOf(prevBiome?.bestTimeSec ?: 0, survivalSec)
            )
        )

        val allEnemyIds = (seenCounts.keys + defeatedCounts.keys)
        for (enemyId in allEnemyIds) {
            val existing = dao.getDexEntryOnce(enemyId)
            dao.upsertDexEntry(
                DexEntryEntity(
                    enemyId = enemyId,
                    seenCount = (existing?.seenCount ?: 0) + (seenCounts[enemyId] ?: 0),
                    defeatedCount = (existing?.defeatedCount ?: 0) + (defeatedCounts[enemyId] ?: 0)
                )
            )
        }

        dao.insertRunRecord(
            RunRecordEntity(
                starterId = starterId,
                biomeId = biomeId,
                victory = victory,
                survivalSec = survivalSec,
                kills = kills,
                finalLevel = finalLevel,
                stardustEarned = stardustEarned
            )
        )
    }

    suspend fun resetAllProgress() {
        dao.clearLabUpgrades()
        dao.clearBiomeProgress()
        dao.clearDexEntries()
        dao.clearRunRecords()
        dao.upsertProfile(ProfileEntity())
    }
}
