package com.example.game.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.annotation.RawRes
import com.example.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

enum class SfxType(@RawRes val rawRes: Int) {
    HIT(R.raw.sfx_hit),
    CRIT(R.raw.sfx_crit),
    HURT(R.raw.sfx_hurt),
    XP(R.raw.sfx_xp),
    LEVEL_UP(R.raw.sfx_level_up),
    DODGE(R.raw.sfx_dodge),
    ULT_READY(R.raw.sfx_ult_ready),
    ULT_FIRE(R.raw.sfx_ult_fire),
    ULT_GRASS(R.raw.sfx_ult_grass),
    ULT_WATER(R.raw.sfx_ult_water),
    EVOLVE(R.raw.sfx_evolve),
    VICTORY(R.raw.sfx_victory),
    DEFEAT(R.raw.sfx_defeat),
    START(R.raw.sfx_start),
    PANEL(R.raw.sfx_panel_open),
    CHEST(R.raw.sfx_chest),
    SHOT_FIRE(R.raw.sfx_shot_fire),
    SHOT_GRASS(R.raw.sfx_shot_grass),
    SHOT_WATER(R.raw.sfx_shot_water)
}

/**
 * Lazy, off-main-thread SoundPool manager.
 * Avoids spinning up 19 simultaneous MediaCodec (c2.android.raw.decoder) instances on cold launch;
 * decodes each SFX resource on demand off the UI thread and caches the sample ID for instant replay.
 */
class SoundEffectsManager(context: Context) {
    private val appContext = context.applicationContext
    private val loadScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var soundPool: SoundPool? = null
    private val poolLock = Any()

    private val soundIds = ConcurrentHashMap<SfxType, Int>()
    private val loadedIds = ConcurrentHashMap.newKeySet<Int>()
    private val loadingTypes = ConcurrentHashMap.newKeySet<SfxType>()
    private val pendingPlayVolume = ConcurrentHashMap<Int, Float>()

    @Volatile
    var enabled: Boolean = true
    @Volatile
    private var released: Boolean = false
    private var lastShotMs = 0L
    private var lastXpMs = 0L
    private var lastHitMs = 0L

    private fun getOrCreateSoundPool(): SoundPool? {
        if (released) return null
        soundPool?.let { return it }
        return synchronized(poolLock) {
            if (released) return@synchronized null
            soundPool ?: runCatching {
                SoundPool.Builder()
                    .setMaxStreams(8)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .build()
                    .also { pool ->
                        pool.setOnLoadCompleteListener { p, sampleId, status ->
                            if (released) return@setOnLoadCompleteListener
                            if (status == 0) {
                                loadedIds.add(sampleId)
                                val vol = pendingPlayVolume.remove(sampleId)
                                if (vol != null && enabled) {
                                    runCatching { p.play(sampleId, vol, vol, 1, 0, 1.0f) }
                                }
                            } else {
                                pendingPlayVolume.remove(sampleId)
                            }
                        }
                    }
            }.getOrNull().also { soundPool = it }
        }
    }

    fun play(type: SfxType, volume: Float = 0.72f, pitch: Float = 1.0f) {
        if (!enabled || released) return
        val safePitch = pitch.coerceIn(0.75f, 1.45f)
        val now = System.currentTimeMillis()
        when (type) {
            SfxType.SHOT_FIRE, SfxType.SHOT_GRASS, SfxType.SHOT_WATER -> {
                if (now - lastShotMs < 95L) return
                lastShotMs = now
            }
            SfxType.XP -> {
                if (now - lastXpMs < 70L) return
                lastXpMs = now
            }
            SfxType.HIT, SfxType.CRIT -> {
                if (now - lastHitMs < 65L) return
                lastHitMs = now
            }
            else -> Unit
        }
        val existingPool = soundPool
        val existingId = soundIds[type]
        if (existingPool != null && existingId != null) {
            if (loadedIds.contains(existingId)) {
                runCatching { existingPool.play(existingId, volume, volume, 1, 0, safePitch) }
            } else {
                pendingPlayVolume[existingId] = volume
            }
            return
        }

        if (loadingTypes.add(type)) {
            loadScope.launch {
                if (released) return@launch
                val pool = getOrCreateSoundPool() ?: run {
                    loadingTypes.remove(type)
                    return@launch
                }
                val sampleId = runCatching {
                    pool.load(appContext, type.rawRes, 1)
                }.getOrDefault(0)
                if (sampleId != 0) {
                    soundIds[type] = sampleId
                    if (loadedIds.contains(sampleId)) {
                        if (enabled && !released) {
                            runCatching { pool.play(sampleId, volume, volume, 1, 0, safePitch) }
                        }
                    } else {
                        pendingPlayVolume[sampleId] = volume
                    }
                } else {
                    loadingTypes.remove(type)
                }
            }
        }
    }

    fun release() {
        released = true
        loadScope.cancel()
        pendingPlayVolume.clear()
        loadedIds.clear()
        soundIds.clear()
        synchronized(poolLock) {
            runCatching { soundPool?.release() }
            soundPool = null
        }
    }
}
