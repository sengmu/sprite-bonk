package com.example.wallet

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Transport for the loopback Devnet API exposed to the device by adb reverse. */
internal class DevnetShopClient {
    data class Challenge(val nonce: String, val message: String)

    suspend fun challenge(wallet: String): Challenge {
        val response = post("/auth/challenge", JSONObject().put("wallet", wallet))
        return Challenge(response.getString("nonce"), response.getString("message"))
    }

    suspend fun authenticate(challenge: Challenge, signature: ByteArray): String =
        post(
            "/auth/session",
            JSONObject().put("nonce", challenge.nonce)
                .put("signature", Base64.encodeToString(signature, Base64.NO_WRAP))
        ).getString("token")

    suspend fun createOrder(token: String): JSONObject = post("/orders/create", token = token)

    suspend fun orders(token: String): JSONArray =
        post("/orders/list", token = token).getJSONArray("orders")

    suspend fun preparePayment(token: String, orderId: String): JSONObject =
        post("/orders/payment", JSONObject().put("orderId", orderId), token)

    suspend fun recover(token: String, orderId: String): JSONObject =
        post("/orders/recover", JSONObject().put("orderId", orderId), token)

    suspend fun broadcast(token: String, orderId: String, signedTransaction: String): String =
        post(
            "/orders/broadcast",
            JSONObject().put("orderId", orderId)
                .put("transaction", signedTransaction),
            token
        ).getString("signature")

    suspend fun settle(token: String, orderId: String, signature: String): JSONObject =
        post("/orders/settle", JSONObject().put("orderId", orderId).put("signature", signature), token)

    suspend fun inventory(token: String): JSONArray =
        post("/inventory", token = token).getJSONArray("items")

    private suspend fun post(path: String, body: JSONObject = JSONObject(), token: String? = null): JSONObject =
        withContext(Dispatchers.IO) {
            val connection = (URL("http://localhost:8765$path").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                instanceFollowRedirects = false
                connectTimeout = 5_000
                readTimeout = 20_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                if (token != null) setRequestProperty("Authorization", "Bearer $token")
            }
            try {
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                if (status !in 200..299) {
                    val detail = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    val message = detail?.let { runCatching { JSONObject(it).optString("error") }.getOrNull() }
                    throw IOException(message?.takeIf(String::isNotBlank) ?: "Devnet shop HTTP $status")
                }
                connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
            } finally {
                connection.disconnect()
            }
        }
}
