package com.example.wallet

import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
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
                Text("测试订单使用 Devnet。当前页面支持登录、下单和查看库存。")
                TextButton(enabled = !busy, onClick = {
                    runAction {
                        token = null
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
                    TextButton(enabled = !busy, onClick = {
                        runAction {
                            val order = client.createOrder(session)
                            orderSummary = "订单 ${order.getString("id")}\n金额 ${order.getLong("amount")} 最小单位"
                            status = "测试订单已创建"
                        }
                    }) { Text("创建测试订单") }
                    TextButton(enabled = !busy, onClick = {
                        runAction {
                            val orders = client.orders(session)
                            val items = client.inventory(session)
                            orderSummary = "订单 ${orders.length()} 笔 · 已解锁 ${items.length()} 件"
                        }
                    }) { Text("查看订单和库存") }
                }
                if (busy) Text("处理中…")
                if (status.isNotBlank()) Text(status)
                if (orderSummary.isNotBlank()) Text(orderSummary)
            }
        },
        confirmButton = { TextButton(enabled = !busy, onClick = onClose) { Text("关闭") } }
    )
}
