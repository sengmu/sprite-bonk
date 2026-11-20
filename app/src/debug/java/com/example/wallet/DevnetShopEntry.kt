package com.example.wallet

import android.net.Uri
import android.util.Base64
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import java.math.BigDecimal

private fun displayUnits(amount: Long, decimals: Int): String =
    BigDecimal.valueOf(amount, decimals).stripTrailingZeros().toPlainString()

private const val FOX_SKIN = "railing-fox-shop-skin"
private val equippedFox = MutableStateFlow<Boolean?>(null)

@Composable
internal fun devnetFoxSkinEquipped(): Boolean {
    val context = LocalContext.current
    val saved = remember(context) {
        context.getSharedPreferences("devnet_shop_receipts", android.content.Context.MODE_PRIVATE)
            .getBoolean("equipped_fox_skin", false)
    }
    return equippedFox.collectAsState().value ?: saved
}

@Composable
internal fun DevnetShopEntry(sender: ActivityResultSender) {
    var opened by rememberSaveable { mutableStateOf(false) }
    TextButton(onClick = { opened = true }) { Text("商店", color = androidx.compose.ui.graphics.Color(0xFF241B35)) }
    if (opened) DevnetCatalog(onClose = { opened = false }) { back ->
        DevnetShopDialog(sender, back)
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
    var orderSummary by remember { mutableStateOf("") }
    var order by remember { mutableStateOf<org.json.JSONObject?>(null) }
    var quote by remember { mutableStateOf<org.json.JSONObject?>(null) }
    var signature by remember { mutableStateOf<String?>(null) }
    var paymentRequested by remember { mutableStateOf(false) }
    var ownsFox by remember { mutableStateOf(false) }
    var walletAddress by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val receipts = remember(context) {
        context.getSharedPreferences("devnet_shop_receipts", android.content.Context.MODE_PRIVATE)
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
        scope.launch {
            try {
                action()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                status = error.message ?: "操作失败，请重试"
            } finally {
                busy = false
            }
        }
    }

    AlertDialog(
        onDismissRequest = { if (!busy) onClose() },
        title = { Text("购买雷铃狐外观") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text("DEVNET 测试网")
                TextButton(enabled = !busy, onClick = {
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
                            val signature = signed.messages.single().signatures.single()
                            payer to client.authenticate(challenge, signature)
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
                            }
                            is TransactionResult.Failure -> status = "登录未完成：${result.message}"
                            is TransactionResult.NoWalletFound -> status = "未找到兼容钱包"
                        }
                    }
                }) { Text(if (token == null) "连接钱包" else "切换钱包") }
                token?.let { session ->
                    TextButton(enabled = !busy && order == null && !ownsFox, onClick = {
                        runAction {
                            val orders = client.orders(session)
                            val pending = (0 until orders.length()).asSequence()
                                .map { orders.getJSONObject(it) }
                                .firstOrNull {
                                    it.isNull("signature") && it.optInt("closed_unpaid") == 0 &&
                                        it.optInt("expired_without_payment") == 0
                                }
                            selectOrder(pending ?: client.createOrder(session))
                            status = if (pending == null) "测试订单已创建" else "已恢复原订单"
                        }
                    }) { Text("继续购买") }
                    TextButton(enabled = !busy, onClick = {
                        runAction {
                            val orders = client.orders(session)
                            val count = refreshInventory(session, checkNotNull(walletAddress))
                            orderSummary = "订单 ${orders.length()} 笔 · 已解锁 $count 件"
                        }
                    }) { Text("查看订单和库存") }
                    if (ownsFox) {
                        val equipped = devnetFoxSkinEquipped()
                        Text("已拥有 · 雷铃狐外观")
                        TextButton(enabled = !busy, onClick = {
                            val next = !equipped
                            receipts.edit().putBoolean("equipped_fox_skin", next)
                                .putString("equipped_fox_wallet", if (next) walletAddress else null).apply()
                            equippedFox.value = next
                            status = if (next) "已装备，回首页选择雷铃狐查看" else "已恢复默认外观"
                        }) { Text(if (equipped) "恢复默认外观" else "装备雷铃狐外观") }
                    }
                    order?.let { selected ->
                        val id = selected.getString("id")
                        Text("订单号 $id")
                        Text("收款账户 ${selected.getString("destination")}")
                        if (signature == null) {
                            TextButton(enabled = !busy && !paymentRequested, onClick = {
                                runAction { quote = client.preparePayment(session, id) }
                            }) { Text("查看付款金额和费用") }
                            quote?.let { prepared ->
                                Text("支付 ${displayUnits(selected.getLong("amount"), prepared.getInt("tokenDecimals"))} 枚测试代币")
                                Text("预计网络费 ${displayUnits(prepared.getLong("feeLamports"), 9)} Devnet SOL")
                                Text("最高网络费 ${displayUnits(prepared.getLong("maxFeeLamports"), 9)} Devnet SOL")
                                TextButton(enabled = !busy && !paymentRequested, onClick = {
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
                                                status = "已提交，请查验到账"
                                            }
                                            is TransactionResult.Failure -> status = "付款未确认：${result.message}"
                                            is TransactionResult.NoWalletFound -> status = "未找到兼容钱包"
                                        }
                                    }
                                }) { Text("打开钱包确认付款") }
                            }
                            if (paymentRequested) {
                                Text("结果待核对，请先查验原订单。")
                                TextButton(enabled = !busy, onClick = {
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
                                }) { Text("查找原订单付款") }
                            }
                        }
                        signature?.let { saved ->
                            TextButton(enabled = !busy, onClick = {
                                runAction {
                                    val result = client.settle(session, id, saved)
                                    status = if (result.getString("status") == "fulfilled") {
                                        selectOrder(null)
                                        refreshInventory(session, checkNotNull(walletAddress))
                                        "已到账，外观已发放"
                                    } else {
                                        "链上确认中，请稍后查验"
                                    }
                                }
                            }) { Text("查验到账") }
                        }
                    }
                }
                if (busy) Text("处理中…")
                if (status.isNotBlank()) Text(status)
                if (orderSummary.isNotBlank()) Text(orderSummary)
            }
        },
        confirmButton = { TextButton(enabled = !busy, onClick = onClose) { Text("关闭") } }
    )
}
