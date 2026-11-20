package com.example.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.LinkOff
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.WalletSource
import com.example.ui.WalletUiState
import com.example.ui.components.ChunkyButton
import com.example.ui.components.ChunkyButtonTone
import com.example.ui.components.DarkGlassPanel
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.GoldAccent
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
    onDismiss: () -> Unit,
    extraContent: @Composable () -> Unit = {}
) {
    BackHandler(onBack = onDismiss)
    val copyValue = state.address
    val statusBadgeColor = when (state.source) {
        WalletSource.AUTHORIZED -> GrassGreen
        WalletSource.SAVED -> SkyBlue
        WalletSource.NONE -> HudDimText
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.68f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss
            )
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        val isLandscape = (maxWidth > maxHeight && maxWidth >= 540.dp) || (maxHeight < 460.dp && maxWidth >= 540.dp)
        val isCompactH = maxHeight < 430.dp

        DarkGlassPanel(
            modifier = Modifier
                .widthIn(min = 290.dp, max = if (isLandscape) 640.dp else 440.dp)
                .fillMaxWidth()
                .testTag("wallet_modal")
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {}
                )
                .verticalScroll(rememberScrollState()),
            cornerRadius = if (isCompactH) 20.dp else 24.dp,
            borderColor = GoldAccent.copy(alpha = 0.58f),
            borderWidth = 1.8.dp,
            containerColor = HudInkDark.copy(alpha = 0.96f),
            contentPadding = PaddingValues(if (isCompactH) 14.dp else 18.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(if (isCompactH) 10.dp else 12.dp)) {
                // Header Row — matches SettingsDialogModal & MainMenuModals
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.weight(1f)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(if (isCompactH) 38.dp else 44.dp)
                                .clip(CircleShape)
                                .background(
                                    Brush.linearGradient(
                                        listOf(SkyBlue.copy(alpha = 0.30f), GoldAccent.copy(alpha = 0.24f))
                                    )
                                )
                                .border(1.5.dp, SkyBlue.copy(alpha = 0.72f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.AccountBalanceWallet,
                                contentDescription = null,
                                tint = GoldAccent,
                                modifier = Modifier.size(if (isCompactH) 20.dp else 23.dp)
                            )
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(7.dp)
                            ) {
                                Text(
                                    text = "链上钱包",
                                    style = if (isCompactH) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color.White
                                )
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(50))
                                        .background(statusBadgeColor.copy(alpha = 0.20f))
                                        .border(1.dp, statusBadgeColor.copy(alpha = 0.72f), RoundedCornerShape(50))
                                        .padding(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        text = state.source.label,
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold
                                        ),
                                        color = if (state.source == WalletSource.NONE) CreamSurface.copy(alpha = 0.78f) else statusBadgeColor
                                    )
                                }
                            }
                            Text(
                                text = "Solana 主网 · 只读余额查询",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                color = HudDimText
                            )
                        }
                    }

                    Box(
                        modifier = Modifier
                            .testTag("wallet_close_btn")
                            .minimumInteractiveComponentSize()
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.10f))
                            .border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape)
                            .clickable(onClick = onDismiss),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Close,
                            contentDescription = "关闭钱包",
                            tint = CreamSurface,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }

                extraContent()

                // Responsive Body: 2 columns in landscape, stacked in portrait
                if (isLandscape) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Column(
                            modifier = Modifier.weight(1.12f),
                            verticalArrangement = Arrangement.spacedBy(9.dp)
                        ) {
                            WalletBalanceVaultCard(
                                state = state,
                                compact = isCompactH,
                                onRetryBalance = onRetryBalance
                            )
                            if (state.isConnected) {
                                WalletAddressCard(
                                    address = state.address,
                                    onCopy = { onCopyAddress(copyValue) }
                                )
                            }
                        }
                        Column(
                            modifier = Modifier.weight(0.95f),
                            verticalArrangement = Arrangement.spacedBy(9.dp)
                        ) {
                            WalletStatusAlerts(
                                state = state,
                                onRetryBalance = onRetryBalance
                            )
                            WalletSecurityNoteCard()
                        }
                    }
                } else {
                    WalletBalanceVaultCard(
                        state = state,
                        compact = false,
                        onRetryBalance = onRetryBalance
                    )
                    if (state.isConnected) {
                        WalletAddressCard(
                            address = state.address,
                            onCopy = { onCopyAddress(copyValue) }
                        )
                    }
                    WalletStatusAlerts(
                        state = state,
                        onRetryBalance = onRetryBalance
                    )
                    WalletSecurityNoteCard()
                }

                // Footer Tactile Actions — matches all SpriteBonk ChunkyButton modals
                val primaryLabel = when {
                    state.isConnecting -> "正在处理…"
                    state.source == WalletSource.AUTHORIZED -> "撤销钱包授权"
                    state.isConnected -> "移除本地地址"
                    else -> "连接 Solana 钱包"
                }
                val primaryTone = when {
                    state.isConnecting -> ChunkyButtonTone.BLUE
                    state.isConnected -> ChunkyButtonTone.ORANGE
                    else -> ChunkyButtonTone.GREEN
                }
                val primaryIcon = when {
                    state.isConnected && !state.isConnecting -> Icons.Rounded.LinkOff
                    else -> Icons.Rounded.AccountBalanceWallet
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ChunkyButton(
                        text = primaryLabel,
                        onClick = { if (state.isConnected) onDisconnect() else onConnect() },
                        tone = primaryTone,
                        icon = primaryIcon,
                        enabled = !state.isConnecting,
                        shimmer = !state.isConnected && !state.isConnecting,
                        height = if (isCompactH) 44.dp else 48.dp,
                        testTag = "wallet_primary_action_btn",
                        modifier = Modifier.weight(1.35f)
                    )

                    if (state.isConnected) {
                        ChunkyButton(
                            text = "复制地址",
                            onClick = { onCopyAddress(copyValue) },
                            tone = ChunkyButtonTone.BLUE,
                            icon = Icons.Rounded.ContentCopy,
                            enabled = copyValue.isNotEmpty(),
                            height = if (isCompactH) 44.dp else 48.dp,
                            testTag = "wallet_copy_address_btn",
                            modifier = Modifier.weight(0.95f)
                        )
                    } else {
                        ChunkyButton(
                            text = "暂不连接",
                            onClick = onDismiss,
                            tone = ChunkyButtonTone.CREAM,
                            height = if (isCompactH) 44.dp else 48.dp,
                            testTag = "wallet_later_btn",
                            modifier = Modifier.weight(0.85f)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WalletBalanceVaultCard(
    state: WalletUiState,
    compact: Boolean,
    onRetryBalance: () -> Unit
) {
    val shape = RoundedCornerShape(18.dp)
    val borderBrush = if (state.isConnected) {
        Brush.horizontalGradient(listOf(SkyBlue.copy(alpha = 0.72f), GoldAccent.copy(alpha = 0.65f)))
    } else {
        Brush.horizontalGradient(listOf(Color.White.copy(alpha = 0.16f), Color.White.copy(alpha = 0.08f)))
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(
                        SkyBlue.copy(alpha = if (state.isConnected) 0.16f else 0.08f),
                        HudInkDeep.copy(alpha = 0.92f),
                        GoldAccent.copy(alpha = if (state.isConnected) 0.12f else 0.04f)
                    )
                )
            )
            .border(1.4.dp, borderBrush, shape)
            .padding(horizontal = 14.dp, vertical = if (compact) 11.dp else 14.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "SOL 公开余额",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = if (state.isConnected) SkyBlue else HudDimText
                )
                if (state.isConnected) {
                    Row(
                        modifier = Modifier
                            .testTag("wallet_refresh_balance_btn")
                            .clip(RoundedCornerShape(50))
                            .background(Color.White.copy(alpha = 0.09f))
                            .border(1.dp, SkyBlue.copy(alpha = 0.45f), RoundedCornerShape(50))
                            .clickable(enabled = !state.isLoadingBalance, onClick = onRetryBalance)
                            .padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        if (state.isLoadingBalance) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(12.dp),
                                strokeWidth = 1.8.dp,
                                color = SkyBlue
                            )
                            Text(
                                text = "查询中",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                color = SkyBlue
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Rounded.Refresh,
                                contentDescription = "刷新余额",
                                tint = SkyBlue,
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                text = "刷新",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
                                color = CreamSurface
                            )
                        }
                    }
                }
            }

            val balanceText = when {
                state.isLoadingBalance -> "读取链上余额…"
                state.balanceSol != null -> String.format(Locale.US, "%.4f SOL", state.balanceSol)
                state.isConnected -> "余额暂不可用"
                else -> "尚未连接钱包"
            }
            Text(
                text = balanceText,
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontSize = if (compact) 21.sp else 25.sp,
                    fontWeight = FontWeight.ExtraBold
                ),
                color = if (state.balanceSol != null) GoldAccent else CreamSurface
            )

            if (!state.isConnected) {
                Text(
                    text = "支持 Phantom、Solflare 等移动钱包，连接后即同步展示地址与余额。",
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.5.sp),
                    color = HudDimText,
                    lineHeight = 16.sp
                )
            }
        }
    }
}

@Composable
private fun WalletAddressCard(
    address: String,
    onCopy: () -> Unit
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.dp, Color.White.copy(alpha = 0.14f), shape)
            .clickable(onClick = onCopy)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = "当前绑定地址",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.5.sp),
                color = HudDimText
            )
            Text(
                text = address,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace
                ),
                color = CreamSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(Modifier.size(8.dp))
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(SkyBlue.copy(alpha = 0.18f))
                .border(1.dp, SkyBlue.copy(alpha = 0.50f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Rounded.ContentCopy,
                contentDescription = "点击复制钱包地址",
                tint = SkyBlue,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun WalletStatusAlerts(
    state: WalletUiState,
    onRetryBalance: () -> Unit
) {
    AnimatedVisibility(visible = state.isConnecting, enter = fadeIn(), exit = fadeOut()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(SkyBlue.copy(alpha = 0.14f))
                .border(1.dp, SkyBlue.copy(alpha = 0.48f), RoundedCornerShape(12.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = SkyBlue
            )
            Text(
                text = if (state.isConnected) "正在向钱包请求撤销授权…" else "正在唤起设备钱包进行授权…",
                style = MaterialTheme.typography.labelMedium,
                color = CreamSurface
            )
        }
    }

    state.errorMessage?.let { err ->
        val recoveryHint = when {
            err.contains("未找到", ignoreCase = true) ->
                "请先在设备安装 Phantom 或 Solflare 等 MWA 兼容钱包。"
            err.contains("取消", ignoreCase = true) || err.contains("cancel", ignoreCase = true) ->
                "你取消了本次授权，可随时重新点击下方按钮连接。"
            else ->
                "可检查网络连接或钱包后台状态后重新尝试连接。"
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(CrimsonRed.copy(alpha = 0.15f))
                .border(1.2.dp, WarmOrange.copy(alpha = 0.60f), RoundedCornerShape(14.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top
        ) {
            Icon(
                imageVector = Icons.Rounded.ErrorOutline,
                contentDescription = null,
                tint = WarmOrange,
                modifier = Modifier.padding(top = 1.dp).size(18.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    text = err,
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = WarmOrange
                )
                Text(
                    text = recoveryHint,
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.5.sp),
                    color = CreamSurface.copy(alpha = 0.85f),
                    lineHeight = 16.sp
                )
            }
        }
    }

    state.balanceError?.let { balErr ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(WarmOrange.copy(alpha = 0.13f))
                .border(1.2.dp, WarmOrange.copy(alpha = 0.55f), RoundedCornerShape(14.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = "余额读取失败：$balErr",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = WarmOrange
                )
                Text(
                    text = "可能是 RPC 限流或网络波动，请点右侧重试。",
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                    color = CreamSurface.copy(alpha = 0.78f)
                )
            }
            Spacer(Modifier.size(8.dp))
            Box(
                modifier = Modifier
                    .testTag("wallet_retry_balance_btn")
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(50))
                    .background(GoldAccent)
                    .clickable(onClick = onRetryBalance)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "重试",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.ExtraBold),
                    color = EspressoDark
                )
            }
        }
    }
}

@Composable
private fun WalletSecurityNoteCard() {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(GrassGreen.copy(alpha = 0.08f))
            .border(1.dp, GrassGreen.copy(alpha = 0.28f), shape)
            .padding(horizontal = 12.dp, vertical = 9.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Rounded.VerifiedUser,
            contentDescription = null,
            tint = GrassGreen,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = "只读安全保障 · 仅查询公开地址余额，不请求签名或主网转账；断开即清除本地保存的地址。",
            style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.5.sp),
            color = CreamSurface.copy(alpha = 0.80f),
            lineHeight = 16.sp
        )
    }
}
