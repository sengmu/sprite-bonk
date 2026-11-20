package com.example.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SpriteBonkDao {
    @Query("SELECT * FROM player_profile WHERE id = 1")
    fun observeProfile(): Flow<ProfileEntity?>

    @Query("SELECT * FROM player_profile WHERE id = 1")
    suspend fun getProfileOnce(): ProfileEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertProfile(profile: ProfileEntity)

    @Query("SELECT * FROM lab_upgrades")
    fun observeLabUpgrades(): Flow<List<LabUpgradeEntity>>

    @Query("SELECT * FROM lab_upgrades")
    suspend fun getLabUpgradesOnce(): List<LabUpgradeEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertLabUpgrade(entity: LabUpgradeEntity)

    @Query("DELETE FROM lab_upgrades")
    suspend fun clearLabUpgrades()

    @Query("SELECT * FROM biome_progress")
    fun observeBiomeProgress(): Flow<List<BiomeProgressEntity>>

    @Query("SELECT * FROM biome_progress WHERE biomeId = :biomeId")
    suspend fun getBiomeProgressOnce(biomeId: String): BiomeProgressEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertBiomeProgress(entity: BiomeProgressEntity)

    @Query("DELETE FROM biome_progress")
    suspend fun clearBiomeProgress()

    @Query("SELECT * FROM dex_entries")
    fun observeDexEntries(): Flow<List<DexEntryEntity>>

    @Query("SELECT * FROM dex_entries WHERE enemyId = :enemyId")
    suspend fun getDexEntryOnce(enemyId: String): DexEntryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertDexEntry(entity: DexEntryEntity)

    @Query("DELETE FROM dex_entries")
    suspend fun clearDexEntries()

    @Query("SELECT * FROM run_records ORDER BY timestampMs DESC LIMIT 20")
    fun observeRecentRuns(): Flow<List<RunRecordEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRunRecord(record: RunRecordEntity)

    @Query("DELETE FROM run_records")
    suspend fun clearRunRecords()
}
