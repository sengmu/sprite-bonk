package com.example.ui

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.example.game.model.CosmeticCatalog
import com.example.game.model.CosmeticCategory
import com.example.game.model.CosmeticLoadout
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Local SharedPreferences-backed store for unlocked & equipped cosmetics
 * (starter skins, starlight entrance aura, and profile/lobby avatar frames).
 */
object CosmeticStore {
    private const val PREFS_NAME = "sprite_bonk_cosmetics"
    private const val KEY_OWNED = "owned_ids"
    private const val KEY_SKINS = "equipped_skins"
    private const val KEY_EFFECT = "equipped_effect"
    private const val KEY_FRAME = "equipped_frame"

    private val _loadout = MutableStateFlow(CosmeticLoadout())
    val loadout: StateFlow<CosmeticLoadout> = _loadout.asStateFlow()

    @Volatile
    private var loaded = false

    fun load(context: Context) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val owned = prefs.getStringSet(KEY_OWNED, emptySet())?.toSet() ?: emptySet()
            val skinsRaw = prefs.getString(KEY_SKINS, "").orEmpty()
            val skins = parseSkinMap(skinsRaw)
            val effect = prefs.getString(KEY_EFFECT, null)?.takeIf { it.isNotBlank() }
            val frame = prefs.getString(KEY_FRAME, null)?.takeIf { it.isNotBlank() }
            _loadout.value = CosmeticLoadout(
                ownedIds = owned,
                equippedSkinsByStarter = skins,
                equippedEntranceEffectId = effect,
                equippedFrameId = frame
            )
            loaded = true
        }
    }

    fun unlockAndEquip(context: Context, itemId: String): CosmeticLoadout {
        val item = CosmeticCatalog.byId(itemId) ?: return _loadout.value
        val cur = _loadout.value
        val nextOwned = cur.ownedIds + itemId
        val next = applyEquipState(cur.copy(ownedIds = nextOwned), item.id, equip = true)
        persist(context, next)
        return next
    }

    fun toggleEquip(context: Context, itemId: String): CosmeticLoadout {
        val item = CosmeticCatalog.byId(itemId) ?: return _loadout.value
        val cur = _loadout.value
        if (itemId !in cur.ownedIds) return cur
        val currentlyEquipped = cur.isEquipped(itemId)
        val next = applyEquipState(cur, item.id, equip = !currentlyEquipped)
        persist(context, next)
        return next
    }

    fun reset(context: Context) {
        val empty = CosmeticLoadout()
        persist(context, empty)
    }

    internal fun resetCacheForTest() {
        synchronized(this) {
            loaded = false
            _loadout.value = CosmeticLoadout()
        }
    }

    internal fun applyEquipState(
        current: CosmeticLoadout,
        itemId: String,
        equip: Boolean
    ): CosmeticLoadout {
        val item = CosmeticCatalog.byId(itemId) ?: return current
        return when (item.category) {
            CosmeticCategory.SKIN -> {
                val starterId = item.starterId ?: return current
                val updated = current.equippedSkinsByStarter.toMutableMap()
                if (equip) updated[starterId] = itemId else if (updated[starterId] == itemId) updated.remove(starterId)
                current.copy(equippedSkinsByStarter = updated)
            }
            CosmeticCategory.EFFECT -> {
                current.copy(
                    equippedEntranceEffectId = if (equip) itemId else if (current.equippedEntranceEffectId == itemId) null else current.equippedEntranceEffectId
                )
            }
            CosmeticCategory.FRAME -> {
                current.copy(
                    equippedFrameId = if (equip) itemId else if (current.equippedFrameId == itemId) null else current.equippedFrameId
                )
            }
        }
    }

    private fun persist(context: Context, state: CosmeticLoadout) {
        _loadout.value = state
        loaded = true
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putStringSet(KEY_OWNED, state.ownedIds)
            .putString(KEY_SKINS, encodeSkinMap(state.equippedSkinsByStarter))
            .putString(KEY_EFFECT, state.equippedEntranceEffectId)
            .putString(KEY_FRAME, state.equippedFrameId)
            .apply()
    }

    private fun encodeSkinMap(map: Map<String, String>): String =
        map.entries.joinToString(",") { "${it.key}=${it.value}" }

    private fun parseSkinMap(raw: String): Map<String, String> {
        if (raw.isBlank()) return emptyMap()
        return raw.split(",")
            .mapNotNull { entry ->
                val parts = entry.split("=")
                if (parts.size == 2 && parts[0].isNotBlank() && parts[1].isNotBlank()) {
                    parts[0].trim() to parts[1].trim()
                } else null
            }
            .toMap()
    }
}

@Composable
fun rememberCosmeticLoadout(): CosmeticLoadout {
    val loadout by CosmeticStore.loadout.collectAsState()
    return loadout
}
