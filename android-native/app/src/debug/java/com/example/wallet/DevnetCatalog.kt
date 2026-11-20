package com.example.wallet

import android.view.WindowManager
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.CosmeticCatalog
import com.example.game.model.CosmeticCategory
import com.example.game.model.CosmeticItem
import com.example.game.model.CosmeticLoadout
import com.example.game.model.CosmeticUnlockMethod
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.components.CosmeticArtEmblemPreview
import com.example.ui.components.ScreenScenicBackdrop
import com.example.ui.components.withCosmeticSkinId
import com.example.ui.screens.OpenSpritePedestalCanvas
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.HudInkDeep
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

@Composable
private fun CosmeticProductArt(
    item: CosmeticItem,
    animTime: Float,
    modifier: Modifier,
    detailMode: Boolean = false
) {
    Box(
        modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                Brush.radialGradient(
                    listOf(
                        item.primaryTint.copy(alpha = 0.24f),
                        HudInkDeep
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        when {
            item.category == CosmeticCategory.SKIN && item.starterId != null -> {
                val previewNode = remember(item.id) {
                    val base = EvolutionRegistry.baseNodeForStarter(item.starterId)
                    base.copy(visualStyle = base.visualStyle.withCosmeticSkinId(item.id))
                }
                OpenSpritePedestalCanvas(
                    node = previewNode,
                    onCycleForm = null,
                    modifier = Modifier.fillMaxSize()
                )
            }
            item.id == CosmeticCatalog.ID_STARLIGHT_ENTRANCE && detailMode -> {
                val showcaseNode = remember { EvolutionRegistry.baseNodeForStarter("spark") }
                OpenSpritePedestalCanvas(
                    node = showcaseNode,
                    onCycleForm = null,
                    starlightEntrance = true,
                    modifier = Modifier.fillMaxSize()
                )
            }
            else -> {
                CosmeticArtEmblemPreview(
                    item = item,
                    animTime = animTime,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}

@Composable
private fun CosmeticStatusBadge(
    item: CosmeticItem,
    loadout: CosmeticLoadout,
    totalVictories: Int,
    devnetFoxEquipped: Boolean
) {
    val equipped = loadout.isEquipped(item.id, devnetFoxEquipped)
    val owned = loadout.isOwned(item.id, devnetFoxEquipped)
    val label = CosmeticCatalog.statusBadgeText(item, loadout, totalVictories, devnetFoxEquipped)
    val (bg, fg) = when {
        equipped -> GrassGreen.copy(alpha = 0.22f) to GrassGreen
        owned -> SkyBlue.copy(alpha = 0.20f) to SkyBlue
        item.unlockMethod == CosmeticUnlockMethod.DEVNET_TOKEN -> EpicPurple.copy(alpha = 0.24f) to Color(0xFFD8C2FF)
        CosmeticCatalog.canClaimFreeMilestone(item, totalVictories) -> GrassGreen.copy(alpha = 0.22f) to GrassGreen
        else -> GoldAccent.copy(alpha = 0.18f) to GoldAccent
    }
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .border(1.dp, fg.copy(alpha = 0.55f), RoundedCornerShape(50))
            .padding(horizontal = 7.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        if (equipped) {
            Icon(
                imageVector = Icons.Rounded.CheckCircle,
                contentDescription = null,
                tint = fg,
                modifier = Modifier.size(11.dp)
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold
            ),
            color = fg,
            maxLines = 1
        )
    }
}

@Composable
private fun ProductLabels(
    item: CosmeticItem,
    loadout: CosmeticLoadout,
    totalVictories: Int,
    devnetFoxEquipped: Boolean
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = item.nameZh,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.ExtraBold),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = item.taglineZh,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
            color = HudDimText,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        CosmeticStatusBadge(
            item = item,
            loadout = loadout,
            totalVictories = totalVictories,
            devnetFoxEquipped = devnetFoxEquipped
        )
    }
}

@Composable
internal fun DevnetCatalog(
    biomeId: String,
    stardust: Int,
    totalVictories: Int,
    cosmeticLoadout: CosmeticLoadout,
    devnetFoxEquipped: Boolean,
    onPurchaseStardustItem: (String) -> Unit,
    onToggleEquipLocal: (String) -> Unit,
    onClose: () -> Unit,
    checkout: @Composable (() -> Unit) -> Unit
) {
    var category by rememberSaveable { mutableStateOf("全部") }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val current = CosmeticCatalog.items.firstOrNull { it.id == selectedId }
    var checkoutOpen by rememberSaveable { mutableStateOf(false) }

    val transition = rememberInfiniteTransition(label = "shop_cosmetic_preview")
    val animTime by transition.animateFloat(
        initialValue = 0f,
        targetValue = 12.566f,
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "shop_anim_time"
    )

    if (checkoutOpen && current?.unlockMethod == CosmeticUnlockMethod.DEVNET_TOKEN) {
        checkout { checkoutOpen = false }
        return
    }

    if (current == null) {
        Dialog(
            onDismissRequest = onClose,
            properties = DialogProperties(
                usePlatformDefaultWidth = false,
                decorFitsSystemWindows = false
            )
        ) {
            val view = LocalView.current
            SideEffect {
                val window = (view.parent as? DialogWindowProvider)?.window ?: return@SideEffect
                if (android.os.Build.VERSION.SDK_INT >= 28) {
                    window.attributes = window.attributes.apply {
                        layoutInDisplayCutoutMode =
                            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    }
                }
                WindowInsetsControllerCompat(window, window.decorView).apply {
                    systemBarsBehavior =
                        WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    hide(WindowInsetsCompat.Type.systemBars())
                }
            }
            Box(Modifier.fillMaxSize().background(HudInkDeep)) {
                ScreenScenicBackdrop(biomeId, SkyBlue)
                BoxWithConstraints(
                    Modifier
                        .fillMaxSize()
                        .windowInsetsPadding(WindowInsets.displayCutout)
                        .padding(12.dp)
                ) {
                    val wide = maxWidth >= 660.dp
                    val columns = if (wide) 3 else if (maxWidth >= 340.dp) 2 else 1
                    val filteredItems = remember(category) {
                        if (category == "全部") CosmeticCatalog.items
                        else CosmeticCatalog.items.filter { it.category.labelZh == category }
                    }
                    Column(
                        modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // Top Header Bar
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                IconButton(
                                    onClick = onClose,
                                    modifier = Modifier
                                        .testTag("devnet_shop_back_btn")
                                        .minimumInteractiveComponentSize()
                                        .background(HudInkDark.copy(alpha = 0.88f), CircleShape)
                                        .border(1.2.dp, CreamSurface.copy(alpha = 0.28f), CircleShape)
                                ) {
                                    Icon(
                                        Icons.AutoMirrored.Rounded.ArrowBack,
                                        contentDescription = "返回",
                                        tint = CreamSurface
                                    )
                                }
                                Column {
                                    Text(
                                        text = "外观商店",
                                        color = CreamSurface,
                                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold)
                                    )
                                    Text(
                                        text = "星尘解锁 · Devnet 链上限定同步穿戴",
                                        color = HudDimText,
                                        style = MaterialTheme.typography.labelSmall
                                    )
                                }
                            }
                            Row(
                                modifier = Modifier
                                    .testTag("shop_stardust_balance_pill")
                                    .clip(RoundedCornerShape(50))
                                    .background(HudInkDark.copy(alpha = 0.86f))
                                    .border(1.4.dp, GoldAccent.copy(alpha = 0.72f), RoundedCornerShape(50))
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Rounded.AutoAwesome,
                                    contentDescription = "星尘余额",
                                    tint = GoldAccent,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(
                                    text = "$stardust 星尘",
                                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.ExtraBold),
                                    color = Color.White,
                                    maxLines = 1
                                )
                            }
                        }

                        // Category Filter Strip
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            listOf("全部", "外观", "特效", "头像框").forEach { name ->
                                val count = if (name == "全部") CosmeticCatalog.items.size
                                else CosmeticCatalog.items.count { it.category.labelZh == name }
                                FilterChip(
                                    selected = category == name,
                                    onClick = { category = name },
                                    label = { Text("$name ($count)") },
                                    colors = FilterChipDefaults.filterChipColors(
                                        labelColor = HudDimText,
                                        containerColor = HudInkDark.copy(alpha = 0.86f),
                                        selectedLabelColor = EspressoDark,
                                        selectedContainerColor = GoldAccent
                                    )
                                )
                            }
                        }

                        // Responsive Grid of Cosmetic Cards
                        LazyVerticalGrid(
                            columns = GridCells.Fixed(columns),
                            modifier = Modifier.weight(1f),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(filteredItems, key = { it.id }) { item ->
                                val equipped = cosmeticLoadout.isEquipped(item.id, devnetFoxEquipped)
                                val rarityBorder = if (equipped) GrassGreen else CosmeticCatalog.rarityBorderColor(item.rarity)
                                val cardModifier = Modifier
                                    .testTag("shop_item_${item.id}")
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(HudInkDark.copy(alpha = 0.92f))
                                    .border(
                                        width = if (equipped) 2.dp else 1.2.dp,
                                        color = rarityBorder.copy(alpha = if (equipped) 0.90f else 0.52f),
                                        shape = RoundedCornerShape(16.dp)
                                    )
                                    .clickable { selectedId = item.id }
                                    .padding(10.dp)
                                if (wide) {
                                    Row(
                                        cardModifier,
                                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        CosmeticProductArt(item, animTime, Modifier.size(84.dp))
                                        Box(Modifier.weight(1f)) {
                                            ProductLabels(item, cosmeticLoadout, totalVictories, devnetFoxEquipped)
                                        }
                                    }
                                } else {
                                    Column(cardModifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                        CosmeticProductArt(item, animTime, Modifier.fillMaxWidth().height(98.dp))
                                        ProductLabels(item, cosmeticLoadout, totalVictories, devnetFoxEquipped)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (current != null) {
        val isDevnetToken = current.unlockMethod == CosmeticUnlockMethod.DEVNET_TOKEN
        val owned = cosmeticLoadout.isOwned(current.id, devnetFoxEquipped)
        val equipped = cosmeticLoadout.isEquipped(current.id, devnetFoxEquipped)
        val freeClaim = CosmeticCatalog.canClaimFreeMilestone(current, totalVictories)
        val canAfford = CosmeticCatalog.canAfford(current, stardust, totalVictories)
        val rarityBorder = CosmeticCatalog.rarityBorderColor(current.rarity)

        AlertDialog(
            onDismissRequest = { selectedId = null },
            containerColor = HudInkDeep,
            titleContentColor = CreamSurface,
            textContentColor = HudDimText,
            title = {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = current.nameZh,
                            fontWeight = FontWeight.ExtraBold,
                            color = CreamSurface
                        )
                        Text(
                            text = "${current.category.labelZh} · ${current.rarity.zhName}",
                            style = MaterialTheme.typography.labelSmall,
                            color = rarityBorder
                        )
                    }
                    CosmeticStatusBadge(
                        item = current,
                        loadout = cosmeticLoadout,
                        totalVictories = totalVictories,
                        devnetFoxEquipped = devnetFoxEquipped
                    )
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    CosmeticProductArt(
                        item = current,
                        animTime = animTime,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(148.dp)
                            .border(1.4.dp, rarityBorder.copy(alpha = 0.55f), RoundedCornerShape(12.dp)),
                        detailMode = true
                    )
                    Text(
                        text = current.descZh,
                        style = MaterialTheme.typography.bodyMedium,
                        color = CreamSurface.copy(alpha = 0.90f)
                    )
                    val unlockHint = when {
                        isDevnetToken -> "通过 Solana Devnet 测试网钱包验证并解锁，装备后对雷铃狐全形态生效。"
                        equipped -> "当前已穿戴生效，随时可切换或恢复默认。"
                        owned -> "已永久解锁，可一键装备或随时卸下。"
                        freeClaim -> "已达成首胜里程碑，可直接免费领取并装备！"
                        !canAfford -> "当前星尘 $stardust / 需要 ${current.stardustCost} 星尘（参与冒险即可获取星尘）。"
                        else -> "消耗 ${current.stardustCost} 星尘永久解锁并立即穿戴。"
                    }
                    Text(
                        text = unlockHint,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (!isDevnetToken && !owned && !canAfford) WarmOrange else HudDimText
                    )
                }
            },
            confirmButton = {
                when {
                    isDevnetToken -> {
                        ChunkyButton(
                            text = if (equipped) "管理 Devnet 订单" else "前往购买",
                            onClick = { checkoutOpen = true },
                            tone = ChunkyButtonTone.GREEN,
                            height = 44.dp,
                            testTag = "devnet_shop_checkout_btn"
                        )
                    }
                    owned -> {
                        ChunkyButton(
                            text = if (equipped) "卸下外观" else "立即装备",
                            onClick = { onToggleEquipLocal(current.id) },
                            tone = if (equipped) ChunkyButtonTone.ORANGE else ChunkyButtonTone.GREEN,
                            height = 44.dp,
                            testTag = "shop_toggle_equip_btn"
                        )
                    }
                    else -> {
                        ChunkyButton(
                            text = if (freeClaim) "首胜免费领取" else "解锁 (${current.stardustCost}★)",
                            onClick = { onPurchaseStardustItem(current.id) },
                            tone = ChunkyButtonTone.GREEN,
                            enabled = canAfford,
                            height = 44.dp,
                            testTag = "shop_unlock_stardust_btn"
                        )
                    }
                }
            },
            dismissButton = {
                TextButton(onClick = { selectedId = null }) {
                    Text("返回商店", color = CreamSurface)
                }
            }
        )
    }
}
