package com.example.wallet

import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
import com.example.R
import com.example.game.evolution.EvolutionRegistry
import com.example.ui.components.withFoxCosmetic
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
    Box(modifier.clip(RoundedCornerShape(10.dp)).background(Color(0xFF251B38)), contentAlignment = Alignment.Center) {
        val portrait = item.portrait
        when {
            item.available -> {
                val fox = remember {
                    val base = EvolutionRegistry.baseNodeForStarter("spark")
                    base.copy(visualStyle = base.visualStyle.withFoxCosmetic(true))
                }
                OpenSpritePedestalCanvas(fox, null, Modifier.fillMaxSize())
            }
            portrait != null -> Image(painterResource(portrait), item.name, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            else -> Text(item.icon, style = MaterialTheme.typography.headlineMedium, color = Color(0xFFBBA5FF))
        }
    }
}

@Composable
internal fun DevnetCatalog(onClose: () -> Unit, checkout: @Composable (() -> Unit) -> Unit) {
    var category by remember { mutableStateOf("全部") }
    var selected by remember { mutableStateOf<ShopCard?>(null) }
    val current = selected
    var checkoutOpen by remember { mutableStateOf(false) }
    if (checkoutOpen) {
        checkout { checkoutOpen = false }
        return
    }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        BoxWithConstraints(Modifier.fillMaxSize().padding(16.dp)) {
            val columns = if (maxWidth > maxHeight) 3 else 2
            Column(Modifier.fillMaxSize().background(Color(0xFF20172F), RoundedCornerShape(20.dp)).padding(12.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("商店 · DEVNET", color = Color(0xFFFFE9BC), style = MaterialTheme.typography.titleLarge)
                    TextButton(onClick = onClose) { Text("返回", color = Color.White) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("全部", "外观", "特效", "头像框").forEach { name ->
                        FilterChip(selected = category == name, onClick = { category = name }, label = { Text(name) })
                    }
                }
                LazyVerticalGrid(
                    columns = GridCells.Fixed(columns),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(shopCards.filter { category == "全部" || it.category == category }, key = { it.name }) { item ->
                        Column(Modifier.fillMaxWidth().background(Color(0xFF35274A), RoundedCornerShape(14.dp))
                            .clickable { selected = item }.padding(12.dp)) {
                            ProductArt(item, Modifier.fillMaxWidth().height(52.dp))
                            Text(item.name, fontWeight = FontWeight.Bold, color = Color.White)
                            Text(
                                if (item.available) "1 枚测试代币" else if (item.name == "创世头像框") "赛季奖励预览" else "预览",
                                color = Color(0xFFE0CAFF)
                            )
                        }
                    }
                }
            }
        }
    }
    if (current != null) {
        AlertDialog(
            onDismissRequest = { selected = null },
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
                if (current.available) Button(onClick = { checkoutOpen = true }) { Text("前往购买") }
                else TextButton(onClick = { selected = null }) { Text("返回商店") }
            },
            dismissButton = {
                if (current.available) TextButton(onClick = { selected = null }) { Text("返回商店") }
            }
        )
    }
}
