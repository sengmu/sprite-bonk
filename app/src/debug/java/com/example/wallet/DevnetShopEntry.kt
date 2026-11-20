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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

@Composable
internal fun DevnetShopEntry(sender: ActivityResultSender) {
    var opened by remember { mutableStateOf(false) }
    TextButton(onClick = { opened = true }) { Text("Devnet 测试商店") }
    if (opened) DevnetShopDialog(sender) { opened = false }
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
    val context = LocalContext.current
    val receipts = remember(context) {
        context.getSharedPreferences("devnet_shop_receipts", android.content.Context.MODE_PRIVATE)
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
        title = { Text("Devnet 测试商店") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text("雷铃狐外观")
                Text("仅使用 Devnet 测试代币。")
                TextButton(enabled = !busy, onClick = {
                    runAction {
                        token = null
                        selectOrder(null)
                        orderSummary = ""
                        when (val result = adapter.transact(sender) { authorization ->
                            val key = authorization.accounts.firstOrNull()?.publicKey
                                ?: error("钱包未返回账户")
                            val challenge = client.challenge(SolanaAddress.encode(key))
                            val signed = signMessagesDetached(
                                arrayOf(challenge.message.toByteArray(Charsets.UTF_8)),
                                arrayOf(key)
                            )
                            val signature = signed.messages.single().signatures.single()
                            client.authenticate(challenge, signature)
                        }) {
                            is TransactionResult.Success -> {
                                token = result.payload
                                status = "钱包登录成功"
                            }
                            is TransactionResult.Failure -> status = "登录未完成：${result.message}"
                            is TransactionResult.NoWalletFound -> status = "未找到兼容钱包"
                        }
                    }
                }) { Text("签名登录") }
                token?.let { session ->
                    TextButton(enabled = !busy && order == null, onClick = {
                        runAction {
                            val orders = client.orders(session)
                            val pending = (0 until orders.length()).asSequence()
                                .map { orders.getJSONObject(it) }
                                .firstOrNull { it.isNull("signature") }
                            selectOrder(pending ?: client.createOrder(session))
                            status = if (pending == null) "测试订单已创建" else "已恢复原订单"
                        }
                    }) { Text("创建测试订单") }
                    TextButton(enabled = !busy, onClick = {
                        runAction {
                            val orders = client.orders(session)
                            val items = client.inventory(session)
                            orderSummary = "订单 ${orders.length()} 笔 · 已解锁 ${items.length()} 件"
                        }
                    }) { Text("查看订单和库存") }
                    order?.let { selected ->
                        val id = selected.getString("id")
                        Text("订单 $id\n测试代币 ${selected.getLong("amount")} 最小单位")
                        Text("收款账户 ${selected.getString("destination")}")
                        if (signature == null) {
                            TextButton(enabled = !busy && !paymentRequested, onClick = {
                                runAction { quote = client.preparePayment(session, id) }
                            }) { Text("准备付款") }
                            quote?.let { prepared ->
                                Text("预计网络费 ${prepared.getLong("feeLamports")} lamports")
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
                                            val sent = signAndSendTransactions(arrayOf(transaction))
                                            val encoded = SolanaAddress.encodeBytes(sent.signatures.single())
                                            check(receipts.edit().putString("signature:$id", encoded).commit()) {
                                                "付款回执保存失败，请核对钱包交易记录"
                                            }
                                            encoded
                                        }) {
                                            is TransactionResult.Success -> {
                                                signature = result.payload
                                                status = "已提交，请查验到账"
                                            }
                                            is TransactionResult.Failure -> status = "付款未确认，请核对钱包交易记录"
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
                                        status = if (result.getString("status") == "fulfilled") {
                                            selectOrder(null)
                                            "已到账，外观已发放"
                                        } else {
                                            "暂未找到已确认的付款，请稍后再次查验"
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
