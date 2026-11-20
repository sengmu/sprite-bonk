package com.example.wallet

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.model.CosmeticCatalog
import com.example.game.model.CosmeticLoadout
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.HudInkDeep
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.math.BigDecimal

private fun displayUnits(amount: Long, decimals: Int): String =
    BigDecimal.valueOf(amount, decimals).stripTrailingZeros().toPlainString()

private fun shortKey(value: String): String =
    if (value.length >= 12) "${value.take(6)}…${value.takeLast(4)}" else value

private const val FOX_SKIN = CosmeticCatalog.ID_FOX_SKIN
private val equippedFox = MutableStateFlow<Boolean?>(null)

@Composable
internal fun devnetFoxSkinEquipped(): Boolean {
    val context = LocalContext.current
    val saved = remember(context) {
        context.getSharedPreferences("devnet_shop_receipts", Context.MODE_PRIVATE)
            .getBoolean("equipped_fox_skin", false)
    }
    return equippedFox.collectAsState().value ?: saved
}

@Composable
internal fun DevnetShopEntry(
    sender: ActivityResultSender,
    biomeId: String,
    stardust: Int,
    totalVictories: Int,
    cosmeticLoadout: CosmeticLoadout,
    onPurchaseStardustItem: (String) -> Unit,
    onToggleEquipLocal: (String) -> Unit
) {
    var opened by rememberSaveable { mutableStateOf(false) }
    val foxEquipped = devnetFoxSkinEquipped()
    Row(
        modifier = Modifier
            .testTag("menu_shop_pill")
            .minimumInteractiveComponentSize()
            .clip(RoundedCornerShape(50))
            .background(HudInkDark.copy(alpha = 0.78f))
            .border(1.4.dp, GoldAccent.copy(alpha = 0.72f), RoundedCornerShape(50))
            .clickable { opened = true }
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Icon(
            imageVector = Icons.Rounded.Storefront,
            contentDescription = "商店",
            tint = GoldAccent,
            modifier = Modifier.size(16.dp)
        )
        Text(
            text = "商店",
            style = MaterialTheme.typography.titleSmall.copy(
                fontSize = 12.5.sp,
                fontWeight = FontWeight.Bold
            ),
            color = Color.White,
            maxLines = 1
        )
    }
    if (opened) {
        DevnetCatalog(
            biomeId = biomeId,
            stardust = stardust,
            totalVictories = totalVictories,
            cosmeticLoadout = cosmeticLoadout,
            devnetFoxEquipped = foxEquipped,
            onPurchaseStardustItem = onPurchaseStardustItem,
            onToggleEquipLocal = onToggleEquipLocal,
            onClose = { opened = false }
        ) { back ->
            DevnetShopDialog(sender, back)
        }
    }
}

@Composable
private fun CheckoutStepperBar(activeStep: Int) {
    val steps = listOf("钱包", "订单", "付款", "发放")
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(HudInkDark)
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .padding(horizontal = 8.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        steps.forEachIndexed { idx, label ->
            val stepNum = idx + 1
            val done = stepNum < activeStep
            val current = stepNum == activeStep
            val badgeBg = when {
                done -> GrassGreen
                current -> GoldAccent
                else -> Color.White.copy(alpha = 0.12f)
            }
            val textColor = when {
                done -> GrassGreen
                current -> GoldAccent
                else -> HudDimText.copy(alpha = 0.65f)
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(badgeBg),
                    contentAlignment = Alignment.Center
                ) {
                    if (done) {
                        Icon(
                            imageVector = Icons.Rounded.CheckCircle,
                            contentDescription = null,
                            tint = EspressoDark,
                            modifier = Modifier.size(13.dp)
                        )
                    } else {
                        Text(
                            text = "$stepNum",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black,
                            color = if (current) EspressoDark else CreamSurface
                        )
                    }
                }
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 10.5.sp,
                        fontWeight = if (current || done) FontWeight.Bold else FontWeight.Medium
                    ),
                    color = textColor,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun DevnetShopDialog(sender: ActivityResultSender, onClose: () -> Unit) {
    val client = remember { DevnetShopClient() }
    val adapter = remember {
        MobileWalletAdapter(
            ConnectionIdentity(
                Uri.parse("https://github.com/sengmu/sprite-bonk"),
                Uri.parse("icon.png"),
                "Sprite Bonk Devnet"
            )
        ).apply { blockchain = Solana.Devnet }
    }
    val scope = rememberCoroutineScope()
    var token by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var statusIsError by remember { mutableStateOf(false) }
    var orderSummary by remember { mutableStateOf("") }
    var order by remember { mutableStateOf<org.json.JSONObject?>(null) }
    var quote by remember { mutableStateOf<org.json.JSONObject?>(null) }
    var signature by remember { mutableStateOf<String?>(null) }
    var paymentRequested by remember { mutableStateOf(false) }
    var ownsFox by remember { mutableStateOf(false) }
    var walletAddress by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val receipts = remember(context) {
        context.getSharedPreferences("devnet_shop_receipts", Context.MODE_PRIVATE)
    }

    suspend fun refreshInventory(session: String, payer: String): Int {
        val items = client.inventory(session)
        ownsFox = (0 until items.length()).any { items.getJSONObject(it).optString("product") == FOX_SKIN }
        val owner = receipts.getString("equipped_fox_wallet", null)
        val keepEquipped = ownsFox && (owner == null || owner == payer) &&
            receipts.getBoolean("equipped_fox_skin", false)
        receipts.edit().putBoolean("equipped_fox_skin", keepEquipped)
            .putString("equipped_fox_wallet", if (keepEquipped) payer else null).apply()
        equippedFox.value = keepEquipped
        return items.length()
    }

    fun selectOrder(value: org.json.JSONObject?) {
        order = value
        quote = null
        val id = value?.getString("id")
        signature = id?.let { receipts.getString("signature:$it", null) }
        paymentRequested = id?.let { receipts.getBoolean("requested:$it", false) } ?: false
    }

    fun runAction(action: suspend () -> Unit) {
        if (busy) return
        busy = true
        status = ""
        statusIsError = false
        scope.launch {
            try {
                action()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                status = error.message ?: "操作失败，请重试"
                statusIsError = true
            } finally {
                busy = false
            }
        }
    }

    val connectWalletAction: () -> Unit = {
        runAction {
            token = null
            walletAddress = null
            ownsFox = false
            selectOrder(null)
            orderSummary = ""
            when (val result = adapter.transact(sender) { authorization ->
                val key = authorization.accounts.firstOrNull()?.publicKey
                    ?: error("钱包未返回账户")
                val payer = SolanaAddress.encode(key)
                val challenge = client.challenge(payer)
                val signed = signMessagesDetached(
                    arrayOf(challenge.message.toByteArray(Charsets.UTF_8)),
                    arrayOf(key)
                )
                val signedSig = signed.messages.single().signatures.single()
                payer to client.authenticate(challenge, signedSig)
            }) {
                is TransactionResult.Success -> {
                    val (payer, session) = result.payload
                    walletAddress = payer
                    token = session
                    val equippedOwner = receipts.getString("equipped_fox_wallet", null)
                    if (equippedOwner != null && equippedOwner != payer) {
                        receipts.edit().remove("equipped_fox_wallet")
                            .putBoolean("equipped_fox_skin", false).apply()
                        equippedFox.value = false
                    }
                    val count = refreshInventory(session, payer)
                    orderSummary = "已解锁 $count 件"
                    status = "钱包登录成功"
                    statusIsError = false
                }
                is TransactionResult.Failure -> {
                    status = "登录未完成：${result.message}"
                    statusIsError = true
                }
                is TransactionResult.NoWalletFound -> {
                    status = "未找到兼容钱包"
                    statusIsError = true
                }
            }
        }
    }

    val activeStep = when {
        token == null -> 1
        ownsFox -> 5
        order == null -> 2
        signature == null && !paymentRequested -> 3
        else -> 4
    }

    AlertDialog(
        onDismissRequest = { if (!busy) onClose() },
        containerColor = HudInkDeep,
        titleContentColor = CreamSurface,
        textContentColor = HudDimText,
        title = {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "蓝紫雷铃狐 · Devnet 结账",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold),
                    color = CreamSurface
                )
                Text(
                    text = "SOLANA DEVNET 测试网 · 1 枚测试代币",
                    style = MaterialTheme.typography.labelSmall,
                    color = GoldAccent
                )
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .widthIn(max = 520.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                CheckoutStepperBar(activeStep = activeStep)

                // Step 1 Card: Wallet Session
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(HudInkDark)
                        .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(14.dp))
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.AccountBalanceWallet,
                                contentDescription = null,
                                tint = SkyBlue,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = walletAddress?.let { "已连接 ${shortKey(it)}" } ?: "步骤 1 · 连接测试网钱包",
                                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                color = CreamSurface
                            )
                        }
                        if (token != null) {
                            TextButton(enabled = !busy, onClick = connectWalletAction) {
                                Text("切换", color = SkyBlue, fontSize = 12.sp)
                            }
                        }
                    }

                    if (token == null) {
                        ChunkyButton(
                            text = "连接钱包登录",
                            onClick = connectWalletAction,
                            tone = ChunkyButtonTone.BLUE,
                            enabled = !busy,
                            height = 44.dp,
                            testTag = "devnet_connect_wallet_btn",
                            modifier = Modifier.fillMaxWidth()
                        )
                    } else {
                        val session = token!!
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedButton(
                                enabled = !busy,
                                onClick = {
                                    runAction {
                                        val orders = client.orders(session)
                                        val count = refreshInventory(session, checkNotNull(walletAddress))
                                        orderSummary = "订单 ${orders.length()} 笔 · 已解锁 $count 件"
                                        status = "已同步最新订单与库存"
                                    }
                                },
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(Icons.Rounded.Refresh, contentDescription = null, tint = SkyBlue, modifier = Modifier.size(15.dp))
                                Text(" 刷新订单与库存", color = SkyBlue, fontSize = 12.sp, maxLines = 1)
                            }
                        }
                        if (orderSummary.isNotBlank()) {
                            Text(orderSummary, style = MaterialTheme.typography.labelSmall, color = HudDimText)
                        }
                    }
                }

                // Ownership Card (Step Complete)
                if (ownsFox) {
                    val equipped = devnetFoxSkinEquipped()
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(GrassGreen.copy(alpha = 0.14f))
                            .border(1.4.dp, GrassGreen.copy(alpha = 0.72f), RoundedCornerShape(14.dp))
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = GrassGreen, modifier = Modifier.size(18.dp))
                            Text(
                                text = "已拥有 · 蓝紫雷铃狐外观",
                                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.ExtraBold),
                                color = GrassGreen
                            )
                        }
                        ChunkyButton(
                            text = if (equipped) "恢复默认外观" else "立即装备雷铃狐外观",
                            onClick = {
                                val next = !equipped
                                receipts.edit().putBoolean("equipped_fox_skin", next)
                                    .putString("equipped_fox_wallet", if (next) walletAddress else null).apply()
                                equippedFox.value = next
                                status = if (next) "已装备，主页展台、战斗与训练场已同步更新" else "已恢复默认外观"
                                statusIsError = false
                            },
                            tone = if (equipped) ChunkyButtonTone.ORANGE else ChunkyButtonTone.GREEN,
                            enabled = !busy,
                            height = 44.dp,
                            testTag = "devnet_toggle_fox_equip_btn",
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                // Step 2-4 Order & Payment Card
                token?.let { session ->
                    if (!ownsFox) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(14.dp))
                                .background(HudInkDark)
                                .border(1.dp, GoldAccent.copy(alpha = 0.28f), RoundedCornerShape(14.dp))
                                .padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            if (order == null) {
                                Text(
                                    text = "步骤 2 · 创建或恢复测试订单",
                                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                    color = CreamSurface
                                )
                                ChunkyButton(
                                    text = "继续购买 / 创建订单",
                                    onClick = {
                                        runAction {
                                            val orders = client.orders(session)
                                            val pending = (0 until orders.length()).asSequence()
                                                .map { orders.getJSONObject(it) }
                                                .firstOrNull {
                                                    it.isNull("signature") && it.optInt("closed_unpaid") == 0 &&
                                                        it.optInt("expired_without_payment") == 0
                                                }
                                            selectOrder(pending ?: client.createOrder(session))
                                            status = if (pending == null) "测试订单已创建" else "已恢复未完成订单"
                                        }
                                    },
                                    tone = ChunkyButtonTone.GREEN,
                                    enabled = !busy,
                                    height = 44.dp,
                                    testTag = "devnet_create_order_btn",
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }

                            order?.let { selected ->
                                val id = selected.getString("id")
                                Text(
                                    text = "订单信息",
                                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                    color = GoldAccent
                                )
                                Text(
                                    text = "订单号：${shortKey(id)}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = CreamSurface,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    text = "收款账户：${shortKey(selected.getString("destination"))}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = HudDimText,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )

                                if (signature == null) {
                                    if (quote == null && !paymentRequested) {
                                        ChunkyButton(
                                            text = "查看付款金额和网络费",
                                            onClick = {
                                                runAction { quote = client.preparePayment(session, id) }
                                            },
                                            tone = ChunkyButtonTone.BLUE,
                                            enabled = !busy,
                                            height = 44.dp,
                                            testTag = "devnet_prepare_payment_btn",
                                            modifier = Modifier.fillMaxWidth()
                                        )
                                    }

                                    quote?.let { prepared ->
                                        Column(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clip(RoundedCornerShape(10.dp))
                                                .background(HudInkDeep)
                                                .border(1.dp, SkyBlue.copy(alpha = 0.35f), RoundedCornerShape(10.dp))
                                                .padding(10.dp),
                                            verticalArrangement = Arrangement.spacedBy(4.dp)
                                        ) {
                                            Text(
                                                text = "支付金额：${displayUnits(selected.getLong("amount"), prepared.getInt("tokenDecimals"))} 枚测试代币",
                                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                                color = GoldAccent
                                            )
                                            Text(
                                                text = "预计网络费：${displayUnits(prepared.getLong("feeLamports"), 9)} Devnet SOL",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = CreamSurface
                                            )
                                            Text(
                                                text = "最高网络费上限：${displayUnits(prepared.getLong("maxFeeLamports"), 9)} Devnet SOL",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = HudDimText
                                            )
                                        }
                                        if (!paymentRequested) {
                                            ChunkyButton(
                                                text = "打开钱包确认付款",
                                                onClick = {
                                                    runAction {
                                                        val transaction = Base64.decode(prepared.getString("transaction"), Base64.DEFAULT)
                                                        when (val result = adapter.transact(sender) { authorization ->
                                                            val key = authorization.accounts.firstOrNull()?.publicKey
                                                                ?: error("钱包未返回账户")
                                                            check(SolanaAddress.encode(key) == selected.getString("payer")) {
                                                                "请使用下单时的钱包账号"
                                                            }
                                                            check(receipts.edit().putBoolean("requested:$id", true).commit()) {
                                                                "无法保存付款状态"
                                                            }
                                                            paymentRequested = true
                                                            @Suppress("DEPRECATION")
                                                            val signed = signTransactions(arrayOf(transaction)).signedPayloads.single()
                                                            val encoded = client.broadcast(session, id, Base64.encodeToString(signed, Base64.NO_WRAP))
                                                            check(receipts.edit().putString("signature:$id", encoded).commit()) {
                                                                "付款回执保存失败，请核对钱包交易记录"
                                                            }
                                                            encoded
                                                        }) {
                                                            is TransactionResult.Success -> {
                                                                signature = result.payload
                                                                status = "交易已广播，请点击下方查验到账"
                                                                statusIsError = false
                                                            }
                                                            is TransactionResult.Failure -> {
                                                                status = "付款未确认：${result.message}"
                                                                statusIsError = true
                                                            }
                                                            is TransactionResult.NoWalletFound -> {
                                                                status = "未找到兼容钱包"
                                                                statusIsError = true
                                                            }
                                                        }
                                                    }
                                                },
                                                tone = ChunkyButtonTone.GREEN,
                                                enabled = !busy,
                                                height = 46.dp,
                                                testTag = "devnet_confirm_payment_btn",
                                                modifier = Modifier.fillMaxWidth()
                                            )
                                        }
                                    }

                                    if (paymentRequested) {
                                        Text(
                                            text = "付款结果待核对，请先查验原订单再决定是否重下。",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = WarmOrange
                                        )
                                        ChunkyButton(
                                            text = "查找原订单付款",
                                            onClick = {
                                                runAction {
                                                    val result = client.recover(session, id)
                                                    status = when (result.getString("status")) {
                                                        "fulfilled" -> {
                                                            selectOrder(null)
                                                            refreshInventory(session, checkNotNull(walletAddress))
                                                            "已到账，外观已发放"
                                                        }
                                                        "closed_unpaid" -> {
                                                            selectOrder(null)
                                                            "原付款已失效且未到账，可以重新下单"
                                                        }
                                                        else -> "暂未找到已确认的付款，请稍后再次查验"
                                                    }
                                                }
                                            },
                                            tone = ChunkyButtonTone.ORANGE,
                                            enabled = !busy,
                                            height = 44.dp,
                                            testTag = "devnet_recover_order_btn",
                                            modifier = Modifier.fillMaxWidth()
                                        )
                                    }
                                }

                                signature?.let { saved ->
                                    ChunkyButton(
                                        text = "查验链上到账并领取",
                                        onClick = {
                                            runAction {
                                                val result = client.settle(session, id, saved)
                                                status = if (result.getString("status") == "fulfilled") {
                                                    selectOrder(null)
                                                    refreshInventory(session, checkNotNull(walletAddress))
                                                    "已到账，外观已发放"
                                                } else {
                                                    "链上确认中，请稍后再次查验"
                                                }
                                            }
                                        },
                                        tone = ChunkyButtonTone.GREEN,
                                        enabled = !busy,
                                        height = 46.dp,
                                        testTag = "devnet_settle_order_btn",
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            }
                        }
                    }
                }

                // Live Status / Progress Banner
                if (busy || status.isNotBlank()) {
                    val bannerColor = when {
                        busy -> SkyBlue
                        statusIsError -> WarmOrange
                        else -> GrassGreen
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(bannerColor.copy(alpha = 0.14f))
                            .border(1.dp, bannerColor.copy(alpha = 0.50f), RoundedCornerShape(10.dp))
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = if (busy) "正在与钱包 / Devnet 节点通信…" else status,
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                            color = bannerColor
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(enabled = !busy, onClick = onClose) {
                Text("返回商店", color = CreamSurface)
            }
        }
    )
}
