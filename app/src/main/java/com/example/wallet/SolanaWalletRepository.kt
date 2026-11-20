package com.example.wallet

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class SolanaWalletRepository(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    fun loadAddress(): String = preferences.getString(KEY_ADDRESS, "").orEmpty()

    fun saveAddress(address: String) {
        preferences.edit().putString(KEY_ADDRESS, address).apply()
    }

    fun clearAddress() {
        preferences.edit().remove(KEY_ADDRESS).apply()
    }

    suspend fun fetchMainnetBalance(address: String): Double = withContext(Dispatchers.IO) {
        for (endpoint in MAINNET_ENDPOINTS) {
            ensureActive()
            try {
                return@withContext fetchBalance(endpoint, address)
            } catch (_: IOException) {
                // A public endpoint can be temporarily unreachable or rate limited.
            } catch (_: org.json.JSONException) {
                // Try the other endpoint if the response cannot be parsed.
            }
        }
        ensureActive()
        throw IOException("暂时无法连接 Solana 主网，请检查网络后重试")
    }

    private fun fetchBalance(endpoint: String, address: String): Double {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 5_000
            readTimeout = 7_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }

        try {
            val requestBody = JSONObject()
                .put("jsonrpc", "2.0")
                .put("id", 1)
                .put("method", "getBalance")
                .put("params", JSONArray().put(address).put(JSONObject().put("commitment", "confirmed")))
                .toString()

            connection.outputStream.use { output ->
                output.write(requestBody.toByteArray(Charsets.UTF_8))
            }

            val statusCode = connection.responseCode
            val responseStream = if (statusCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val responseText = responseStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (statusCode !in 200..299) {
                throw IOException("RPC 返回 $statusCode")
            }

            val response = JSONObject(responseText)
            response.optJSONObject("error")?.let { error ->
                throw IOException(error.optString("message").ifBlank { "RPC 查询失败" })
            }
            val lamports = response.getJSONObject("result").getLong("value")
            return lamports / LAMPORTS_PER_SOL
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "sprite_bonk_wallet"
        const val KEY_ADDRESS = "public_address"
        val MAINNET_ENDPOINTS = listOf(
            "https://api.mainnet-beta.solana.com",
            "https://solana-rpc.publicnode.com"
        )
        const val LAMPORTS_PER_SOL = 1_000_000_000.0
    }
}
