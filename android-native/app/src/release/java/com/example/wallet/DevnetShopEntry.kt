package com.example.wallet

import androidx.compose.runtime.Composable
import com.example.game.model.CosmeticLoadout
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender

@Composable
internal fun DevnetShopEntry(
    sender: ActivityResultSender,
    biomeId: String,
    stardust: Int,
    totalVictories: Int,
    cosmeticLoadout: CosmeticLoadout,
    onPurchaseStardustItem: (String) -> Unit,
    onToggleEquipLocal: (String) -> Unit
) = Unit

@Composable
internal fun devnetFoxSkinEquipped(): Boolean = false
