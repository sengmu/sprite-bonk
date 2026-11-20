package com.example.wallet

import java.math.BigInteger

object SolanaAddress {
    private const val ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    fun isValid(address: String): Boolean {
        val value = address.trim()
        if (value.length !in 32..44 || value.any { ALPHABET.indexOf(it) < 0 }) return false

        var number = BigInteger.ZERO
        for (char in value) {
            number = number.multiply(BigInteger.valueOf(58L))
                .add(BigInteger.valueOf(ALPHABET.indexOf(char).toLong()))
        }

        val leadingZeroes = value.takeWhile { it == '1' }.length
        val encodedNumber = if (number == BigInteger.ZERO) {
            0
        } else {
            number.toByteArray().let { bytes ->
                if (bytes.firstOrNull() == 0.toByte()) bytes.size - 1 else bytes.size
            }
        }
        return leadingZeroes + encodedNumber == 32
    }

    fun encode(publicKey: ByteArray): String {
        require(publicKey.size == 32) { "Solana public keys must be 32 bytes" }
        return encodeBytes(publicKey)
    }

    internal fun encodeBytes(publicKey: ByteArray): String {

        val leadingZeroes = publicKey.takeWhile { it == 0.toByte() }.size
        var number = BigInteger(1, publicKey)
        val base = BigInteger.valueOf(58L)
        val encoded = StringBuilder()
        while (number > BigInteger.ZERO) {
            val division = number.divideAndRemainder(base)
            encoded.append(ALPHABET[division[1].toInt()])
            number = division[0]
        }
        repeat(leadingZeroes) { encoded.append('1') }
        return encoded.reverse().toString()
    }
}
