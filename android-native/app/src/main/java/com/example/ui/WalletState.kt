package com.example.ui

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

enum class WalletSource(val label: String) {
    NONE("未连接"),
    SAVED("已保存地址"),
    AUTHORIZED("已授权钱包")
}

data class WalletUiState(
    val address: String = "",
    val source: WalletSource = WalletSource.NONE,
    val isConnecting: Boolean = false,
    val isLoadingBalance: Boolean = false,
    val balanceSol: Double? = null,
    val errorMessage: String? = null,
    val balanceError: String? = null
) {
    val isConnected: Boolean get() = address.isNotBlank()

    fun shortAddress(): String {
        val trimmed = address.trim()
        return if (trimmed.length >= 10) {
            "${trimmed.take(4)}…${trimmed.takeLast(4)}"
        } else {
            trimmed
        }
    }
}

internal object SolanaMainnetBalanceClient {
    private const val RPC_ENDPOINT = "https://api.mainnet-beta.solana.com"
    private const val LAMPORTS_PER_SOL = 1_000_000_000.0

    suspend fun fetchBalanceSol(address: String): Double = withContext(Dispatchers.IO) {
        val payload = JSONObject()
            .put("jsonrpc", "2.0")
            .put("id", 1)
            .put("method", "getBalance")
            .put(
                "params",
                JSONArray()
                    .put(address)
                    .put(JSONObject().put("commitment", "confirmed"))
            )
            .toString()

        val connection = (URL(RPC_ENDPOINT).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            instanceFollowRedirects = false
            connectTimeout = 6_000
            readTimeout = 10_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
        }
        try {
            connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException("RPC HTTP $status")
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            if (json.has("error")) {
                val msg = json.optJSONObject("error")?.optString("message").orEmpty()
                throw IOException(msg.ifBlank { "RPC 查询失败" })
            }
            val lamports = json.getJSONObject("result").getLong("value")
            lamports / LAMPORTS_PER_SOL
        } finally {
            connection.disconnect()
        }
    }
}
