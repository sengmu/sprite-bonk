package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.game.model.CosmeticCatalog
import com.example.ui.CosmeticStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class CosmeticAndShopRobolectricTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        CosmeticStore.reset(context)
        CosmeticStore.resetCacheForTest()
    }

    @Test
    fun `cosmetic unlock equip toggle and cold-start reload persist via SharedPreferences`() {
        CosmeticStore.load(context)
        assertTrue(CosmeticStore.loadout.value.ownedIds.isEmpty())

        // Unlock & equip starter skin, starlight entrance aura, and forest nameplate frame
        CosmeticStore.unlockAndEquip(context, CosmeticCatalog.ID_EMERALD_STUMP)
        CosmeticStore.unlockAndEquip(context, CosmeticCatalog.ID_STARLIGHT_ENTRANCE)
        CosmeticStore.unlockAndEquip(context, CosmeticCatalog.ID_FOREST_NAMEPLATE)

        val equipped = CosmeticStore.loadout.value
        assertTrue(equipped.isOwned(CosmeticCatalog.ID_EMERALD_STUMP))
        assertTrue(equipped.isEquipped(CosmeticCatalog.ID_EMERALD_STUMP))
        assertEquals(CosmeticCatalog.ID_EMERALD_STUMP, equipped.activeSkinIdFor("stump"))
        assertTrue(equipped.hasStarlightEntrance)
        assertEquals(CosmeticCatalog.ID_FOREST_NAMEPLATE, equipped.equippedFrameId)

        // Equipping Genesis Frame replaces Forest Nameplate (mutual exclusivity across frames)
        CosmeticStore.unlockAndEquip(context, CosmeticCatalog.ID_GENESIS_FRAME)
        val swapped = CosmeticStore.loadout.value
        assertTrue(swapped.isOwned(CosmeticCatalog.ID_FOREST_NAMEPLATE))
        assertFalse(swapped.isEquipped(CosmeticCatalog.ID_FOREST_NAMEPLATE))
        assertTrue(swapped.isEquipped(CosmeticCatalog.ID_GENESIS_FRAME))

        // Toggle unequip on entrance effect
        CosmeticStore.toggleEquip(context, CosmeticCatalog.ID_STARLIGHT_ENTRANCE)
        assertFalse(CosmeticStore.loadout.value.hasStarlightEntrance)
        assertTrue(CosmeticStore.loadout.value.isOwned(CosmeticCatalog.ID_STARLIGHT_ENTRANCE))

        // Simulate app process restart by clearing in-memory cache and reloading from SharedPreferences
        CosmeticStore.resetCacheForTest()
        assertTrue(CosmeticStore.loadout.value.ownedIds.isEmpty())

        CosmeticStore.load(context)
        val reloaded = CosmeticStore.loadout.value
        assertTrue(reloaded.isOwned(CosmeticCatalog.ID_EMERALD_STUMP))
        assertEquals(CosmeticCatalog.ID_EMERALD_STUMP, reloaded.activeSkinIdFor("stump"))
        assertTrue(reloaded.isOwned(CosmeticCatalog.ID_STARLIGHT_ENTRANCE))
        assertFalse(reloaded.hasStarlightEntrance)
        assertEquals(CosmeticCatalog.ID_GENESIS_FRAME, reloaded.equippedFrameId)

        // Reset wipes both memory and disk persistence
        CosmeticStore.reset(context)
        CosmeticStore.resetCacheForTest()
        CosmeticStore.load(context)
        val afterReset = CosmeticStore.loadout.value
        assertTrue(afterReset.ownedIds.isEmpty())
        assertNull(afterReset.equippedFrameId)
        assertNull(afterReset.equippedEntranceEffectId)
    }

    @Test
    fun `genesis frame milestone and stardust affordability rules behave accurately`() {
        val genesis = CosmeticCatalog.byId(CosmeticCatalog.ID_GENESIS_FRAME)!!
        val emerald = CosmeticCatalog.byId(CosmeticCatalog.ID_EMERALD_STUMP)!!
        val foxSkin = CosmeticCatalog.byId(CosmeticCatalog.ID_FOX_SKIN)!!

        // Free milestone requires >= 1 victory
        assertFalse(CosmeticCatalog.canClaimFreeMilestone(genesis, totalVictories = 0))
        assertTrue(CosmeticCatalog.canClaimFreeMilestone(genesis, totalVictories = 1))

        // Affordability checks
        assertFalse(CosmeticCatalog.canAfford(genesis, stardust = 100, totalVictories = 0))
        assertTrue(CosmeticCatalog.canAfford(genesis, stardust = 240, totalVictories = 0))
        assertTrue(CosmeticCatalog.canAfford(genesis, stardust = 0, totalVictories = 1))

        assertFalse(CosmeticCatalog.canAfford(emerald, stardust = 119, totalVictories = 5))
        assertTrue(CosmeticCatalog.canAfford(emerald, stardust = 120, totalVictories = 0))

        // Devnet token skin is never purchasable via Stardust
        assertFalse(CosmeticCatalog.canAfford(foxSkin, stardust = 9999, totalVictories = 99))
    }
}
