package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.WalletUiState
import com.example.ui.WalletSource
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudDimText
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.HudInkDeep
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import java.util.Locale

@Composable
fun WalletDialog(
    state: WalletUiState,
    onConnect: () -> Unit,
    onDisconnect: () -> Unit,
    onCopyAddress: (String) -> Unit,
    onRetryBalance: () -> Unit,
    onDismiss: () -> Unit
) {
    val copyValue = state.address

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = HudInkDeep,
        titleContentColor = CreamSurface,
        textContentColor = HudDimText,
        title = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(Icons.Rounded.AccountBalanceWallet, contentDescription = null, tint = SkyBlue)
                Column {
                    Text("钱包", fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                    Text("Solana 主网 · ${state.source.label}", color = HudDimText, fontSize = 12.sp)
                }
            }
        },
        text = {
            Column(
                modifier = Modifier.widthIn(max = 520.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (state.isConnected) {
                    Text("钱包地址", color = HudDimText, fontSize = 12.sp)
                    Text(state.address, color = CreamSurface, fontSize = 14.sp)
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(HudInkDark, RoundedCornerShape(16.dp))
                        .padding(horizontal = 16.dp, vertical = 13.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("SOL 余额", color = HudDimText, fontSize = 13.sp)
                        Spacer(Modifier.height(3.dp))
                        val balanceText = when {
                            state.isLoadingBalance -> "读取中…"
                            state.balanceSol != null -> String.format(Locale.US, "%.4f SOL", state.balanceSol)
                            state.isConnected -> "余额暂不可用"
                            else -> "尚未连接"
                        }
                        Text(
                            balanceText,
                            color = CreamSurface,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                    if (state.isLoadingBalance) {
                        Text("查询中", color = SkyBlue, fontSize = 12.sp)
                    }
                }

                state.errorMessage?.let {
                    Text(it, color = WarmOrange, fontSize = 13.sp)
                }
                state.balanceError?.let {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("余额读取失败：$it", color = WarmOrange, fontSize = 12.sp, modifier = Modifier.weight(1f))
                        TextButton(onClick = onRetryBalance) { Text("重试", color = SkyBlue) }
                    }
                }
                if (state.isConnecting) {
                    Text(if (state.isConnected) "正在撤销钱包授权…" else "正在打开钱包授权…", color = SkyBlue, fontSize = 13.sp)
                }
                Text(
                    "可选 · 仅查看公开余额，不签名、不交易。断开连接会清除保存的地址。",
                    color = HudDimText,
                    fontSize = 12.sp,
                    lineHeight = 17.sp
                )
            }
        },
        confirmButton = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Button(
                    onClick = { if (state.isConnected) onDisconnect() else onConnect() },
                    enabled = !state.isConnecting,
                    modifier = Modifier.weight(1.15f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (state.isConnected) WarmOrange else GrassGreen,
                        contentColor = EspressoDark,
                        disabledContainerColor = HudDimText.copy(alpha = 0.35f)
                    )
                ) {
                    Text(
                        when {
                            state.isConnecting -> "处理中"
                            state.source == WalletSource.AUTHORIZED -> "撤销授权"
                            state.isConnected -> "移除地址"
                            else -> "连接钱包"
                        },
                        maxLines = 1,
                        fontWeight = FontWeight.Bold
                    )
                }
                OutlinedButton(
                    onClick = { onCopyAddress(copyValue) },
                    enabled = copyValue.isNotEmpty(),
                    modifier = Modifier.weight(0.92f)
                ) {
                    Text("复制地址", maxLines = 1, color = if (copyValue.isEmpty()) HudDimText else SkyBlue)
                }
                TextButton(onClick = onDismiss, modifier = Modifier.weight(0.62f)) {
                    Text("关闭", maxLines = 1, textAlign = TextAlign.Center, color = CreamSurface)
                }
            }
        },
        dismissButton = {},
        icon = null
    )
}
