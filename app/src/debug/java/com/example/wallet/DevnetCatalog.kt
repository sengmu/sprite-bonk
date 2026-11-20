package com.example.wallet

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.view.WindowManager
import com.example.R
import com.example.game.evolution.EvolutionRegistry
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ScreenScenicBackdrop
import com.example.ui.components.withFoxCosmetic
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.HudInkDeep
import com.example.ui.theme.SkyBlue
import com.example.ui.screens.OpenSpritePedestalCanvas

private data class ShopCard(val name: String, val category: String, val icon: String, val available: Boolean = false, val portrait: Int? = null)

private val shopCards = listOf(
    ShopCard("蓝紫雷铃狐", "外观", "⚡", true),
    ShopCard("青绒林语", "外观", "🌿", portrait = R.drawable.img_starter_stump),
    ShopCard("赤焰伙伴", "外观", "🔥", portrait = R.drawable.img_starter_char),
    ShopCard("星光出场", "特效", "✦"),
    ShopCard("森林名牌", "头像框", "❖"),
    ShopCard("创世头像框", "头像框", "♛")
)

@Composable
private fun ProductArt(item: ShopCard, modifier: Modifier) {
    Box(modifier.clip(RoundedCornerShape(10.dp)).background(HudInkDeep), contentAlignment = Alignment.Center) {
        val portrait = item.portrait
        when {
            item.available -> {
                val fox = remember {
                    val base = EvolutionRegistry.baseNodeForStarter("spark")
                    base.copy(visualStyle = base.visualStyle.withFoxCosmetic(true))
                }
                OpenSpritePedestalCanvas(fox, null, Modifier.fillMaxSize())
            }
            portrait != null -> Image(painterResource(portrait), item.name, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            else -> Text(item.icon, style = MaterialTheme.typography.headlineMedium, color = GoldAccent)
        }
    }
}

@Composable
private fun ProductLabels(item: ShopCard) {
    Column {
        Text(item.name, fontWeight = FontWeight.Bold, color = Color.White)
        val status = when {
            item.available -> "1 枚测试代币"
            item.name == "创世头像框" -> "赛季奖励预览"
            else -> "预览"
        }
        Text(status, color = HudDimText, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
internal fun DevnetCatalog(biomeId: String, onClose: () -> Unit, checkout: @Composable (() -> Unit) -> Unit) {
    var category by rememberSaveable { mutableStateOf("全部") }
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    val current = shopCards.firstOrNull { it.name == selected }
    var checkoutOpen by rememberSaveable { mutableStateOf(false) }
    if (checkoutOpen && current?.available == true) {
        checkout { checkoutOpen = false }
        return
    }
    if (current == null) Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        val view = LocalView.current
        SideEffect {
            val window = (view.parent as DialogWindowProvider).window
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                window.attributes = window.attributes.apply {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
            WindowInsetsControllerCompat(window, window.decorView).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
        }
        Box(Modifier.fillMaxSize().background(HudInkDeep)) {
            ScreenScenicBackdrop(biomeId, SkyBlue)
            BoxWithConstraints(
                Modifier.fillMaxSize()
                    .windowInsetsPadding(WindowInsets.displayCutout)
                    .padding(12.dp)
            ) {
                val wide = maxWidth >= 660.dp
                val columns = if (wide) 3 else if (maxWidth >= 340.dp) 2 else 1
                Column(Modifier.fillMaxSize().padding(12.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(
                            onClick = onClose,
                            modifier = Modifier.background(HudInkDark, CircleShape)
                                .border(1.dp, CreamSurface.copy(alpha = 0.24f), CircleShape)
                        ) {
                            Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回", tint = CreamSurface)
                        }
                        Column {
                            Text("商店", color = CreamSurface, style = MaterialTheme.typography.titleLarge)
                            Text("DEVNET 测试网", color = HudDimText, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("全部", "外观", "特效", "头像框").forEach { name ->
                            FilterChip(selected = category == name, onClick = { category = name }, label = { Text(name) }, colors = FilterChipDefaults.filterChipColors(labelColor = HudDimText, containerColor = HudInkDark, selectedLabelColor = EspressoDark, selectedContainerColor = GoldAccent))
                        }
                    }
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(columns),
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(shopCards.filter { category == "全部" || it.category == category }, key = { it.name }) { item ->
                            val cardModifier = Modifier.fillMaxWidth()
                                .clip(MaterialTheme.shapes.medium)
                                .background(HudInkDark.copy(alpha = 0.94f))
                                .border(1.dp, CreamSurface.copy(alpha = 0.24f), MaterialTheme.shapes.medium)
                                .clickable { selected = item.name }
                                .padding(8.dp)
                            if (wide) {
                                Row(cardModifier, horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                    ProductArt(item, Modifier.size(76.dp))
                                    ProductLabels(item)
                                }
                            } else {
                                Column(cardModifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    ProductArt(item, Modifier.fillMaxWidth().height(88.dp))
                                    ProductLabels(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (current != null) {
        AlertDialog(
            onDismissRequest = { selected = null },
            containerColor = HudInkDeep,
            titleContentColor = CreamSurface,
            textContentColor = HudDimText,
            title = { Text(current.name) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ProductArt(current, Modifier.fillMaxWidth().height(110.dp))
                    Text(when {
                        current.available -> "1 枚测试代币 · Devnet"
                        current.name == "创世头像框" -> "创世赛季奖励预览"
                        else -> "商品预览，暂未开放购买"
                    })
                }
            },
            confirmButton = {
                if (current.available) ChunkyButton("前往购买", onClick = { checkoutOpen = true }, height = 44.dp)
                else TextButton(onClick = { selected = null }) { Text("返回商店", color = CreamSurface) }
            },
            dismissButton = {
                if (current.available) TextButton(onClick = { selected = null }) { Text("返回商店", color = CreamSurface) }
            }
        )
    }
}
