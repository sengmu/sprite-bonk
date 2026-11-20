package com.example.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "player_profile")
data class ProfileEntity(
    @PrimaryKey val id: Int = 1,
    val stardust: Int = 180,
    val totalStardust: Int = 180,
    val totalKills: Int = 0,
    val totalRuns: Int = 0,
    val totalVictories: Int = 0,
    val bestSurvivalSec: Int = 0,
    val selectedStarterId: String = "stump",
    val selectedBiomeId: String = "forest",
    val selectedGameMode: String = "classic",
    val unlockedEvolutionIds: String = "stump_base,char_base,shell_base,spark_base,wisp_base,drake_base",
    val sfxEnabled: Boolean = true,
    val vibrationEnabled: Boolean = true,
    val screenShakeEnabled: Boolean = true,
    val autoAimEnabled: Boolean = true
)

@Entity(tableName = "lab_upgrades")
data class LabUpgradeEntity(
    @PrimaryKey val upgradeId: String,
    val level: Int
)

@Entity(tableName = "biome_progress")
data class BiomeProgressEntity(
    @PrimaryKey val biomeId: String,
    val clearedCount: Int,
    val bestTimeSec: Int
)

@Entity(tableName = "dex_entries")
data class DexEntryEntity(
    @PrimaryKey val enemyId: String,
    val seenCount: Int,
    val defeatedCount: Int
)

@Entity(tableName = "run_records")
data class RunRecordEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val starterId: String,
    val biomeId: String,
    val victory: Boolean,
    val survivalSec: Int,
    val kills: Int,
    val finalLevel: Int,
    val stardustEarned: Int,
    val timestampMs: Long = System.currentTimeMillis()
)
