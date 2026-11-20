package com.example.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        ProfileEntity::class,
        LabUpgradeEntity::class,
        BiomeProgressEntity::class,
        DexEntryEntity::class,
        RunRecordEntity::class
    ],
    version = 2,
    exportSchema = false
)
abstract class SpriteBonkDatabase : RoomDatabase() {
    abstract fun dao(): SpriteBonkDao

    companion object {
        @Volatile
        private var INSTANCE: SpriteBonkDatabase? = null

        fun getInstance(context: Context): SpriteBonkDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    SpriteBonkDatabase::class.java,
                    "sprite_bonk_db"
                ).fallbackToDestructiveMigration(true)
                    .build().also { INSTANCE = it }
            }
        }
    }
}
