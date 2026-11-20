package com.example.wallet

import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.CosmeticCatalog
import com.example.game.model.CosmeticLoadout
import com.example.ui.CosmeticStore
import com.example.ui.WalletSource
import com.example.ui.WalletUiState
import com.example.ui.components.withCosmeticLoadout
import com.example.ui.components.withFoxCosmetic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WalletAndCosmeticTest {

    @Test
    fun solanaAddressEncodesAndValidates32BytePublicKeys() {
        val zeroKey = ByteArray(32) { 0 }
        val encodedZero = SolanaAddress.encode(zeroKey)
        assertEquals("1".repeat(32), encodedZero)
        assertTrue(SolanaAddress.isValid(encodedZero))

        val sampleKey = ByteArray(32) { index -> ((index * 37 + 11) and 0xFF).toByte() }
        val encodedSample = SolanaAddress.encode(sampleKey)
        assertTrue("Encoded 32-byte key must validate", SolanaAddress.isValid(encodedSample))

        assertFalse(SolanaAddress.isValid("not-a-solana-address"))
        assertFalse(SolanaAddress.isValid("0OIl" + "1".repeat(30)))
        assertFalse(SolanaAddress.isValid(""))
    }

    @Test
    fun walletUiStateFormatsShortAddressAndConnectionState() {
        val disconnected = WalletUiState()
        assertFalse(disconnected.isConnected)
        assertEquals(WalletSource.NONE, disconnected.source)

        val address = SolanaAddress.encode(ByteArray(32) { (it + 7).toByte() })
        val connected = WalletUiState(address = address, source = WalletSource.AUTHORIZED)
        assertTrue(connected.isConnected)
        val shortAddr = connected.shortAddress()
        assertTrue("Short address should contain ellipsis: $shortAddr", shortAddr.contains("…"))
        assertEquals(9, shortAddr.length)
    }

    @Test
    fun foxCosmeticAppliesOnlyToSparkStarterWhenEquipped() {
        val sparkStyle = EvolutionRegistry.baseNodeForStarter("spark").visualStyle
        val equippedSpark = sparkStyle.withFoxCosmetic(true)
        assertNotEquals(sparkStyle.primaryColor, equippedSpark.primaryColor)
        assertEquals(sparkStyle, sparkStyle.withFoxCosmetic(false))

        val charStyle = EvolutionRegistry.baseNodeForStarter("char").visualStyle
        assertEquals(charStyle, charStyle.withFoxCosmetic(true))
    }

    @Test
    fun cosmeticCatalogSupportsAllSixItemsSkinsEffectsAndFrames() {
        assertEquals(6, CosmeticCatalog.items.size)

        // Equip emerald stump skin, crimson char skin, starlight entrance, and forest frame
        var loadout = CosmeticLoadout(
            ownedIds = setOf(
                CosmeticCatalog.ID_EMERALD_STUMP,
                CosmeticCatalog.ID_CRIMSON_CHAR,
                CosmeticCatalog.ID_STARLIGHT_ENTRANCE,
                CosmeticCatalog.ID_FOREST_NAMEPLATE,
                CosmeticCatalog.ID_GENESIS_FRAME
            )
        )
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_EMERALD_STUMP, equip = true)
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_CRIMSON_CHAR, equip = true)
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_STARLIGHT_ENTRANCE, equip = true)
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_FOREST_NAMEPLATE, equip = true)

        assertTrue(loadout.hasStarlightEntrance)
        assertEquals(CosmeticCatalog.ID_FOREST_NAMEPLATE, loadout.equippedFrameId)

        val stumpBase = EvolutionRegistry.baseNodeForStarter("stump").visualStyle
        assertNotEquals(stumpBase.primaryColor, stumpBase.withCosmeticLoadout(loadout, false).primaryColor)

        val charBase = EvolutionRegistry.baseNodeForStarter("char").visualStyle
        assertNotEquals(charBase.primaryColor, charBase.withCosmeticLoadout(loadout, false).primaryColor)

        // Switching frame replaces previous frame cleanly
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_GENESIS_FRAME, equip = true)
        assertEquals(CosmeticCatalog.ID_GENESIS_FRAME, loadout.equippedFrameId)
        assertFalse(loadout.isEquipped(CosmeticCatalog.ID_FOREST_NAMEPLATE))

        // Unequipping starlight effect clears slot
        loadout = CosmeticStore.applyEquipState(loadout, CosmeticCatalog.ID_STARLIGHT_ENTRANCE, equip = false)
        assertFalse(loadout.hasStarlightEntrance)
        assertNull(loadout.equippedEntranceEffectId)
    }

    @Test
    fun genesisFrameSupportsFreeFirstVictoryClaimOrStardustUnlock() {
        val genesis = CosmeticCatalog.byId(CosmeticCatalog.ID_GENESIS_FRAME)!!
        assertFalse(CosmeticCatalog.canClaimFreeMilestone(genesis, totalVictories = 0))
        assertTrue(CosmeticCatalog.canClaimFreeMilestone(genesis, totalVictories = 1))
        assertFalse(CosmeticCatalog.canAfford(genesis, stardust = 100, totalVictories = 0))
        assertTrue(CosmeticCatalog.canAfford(genesis, stardust = 240, totalVictories = 0))
        assertTrue(CosmeticCatalog.canAfford(genesis, stardust = 0, totalVictories = 1))
        assertEquals(
            "首胜免费领",
            CosmeticCatalog.statusBadgeText(genesis, CosmeticLoadout(), totalVictories = 1, devnetFoxEquipped = false)
        )
    }
}
