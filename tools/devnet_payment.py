"""Build a single, reusable unsigned payment attempt for a Devnet order."""

import base64
import struct
import time

from devnet_orders import MEMO_PROGRAM, TOKEN_PROGRAM, rpc


def prepare_payment(db, order):
    from solders.hash import Hash
    from solders.instruction import AccountMeta, Instruction
    from solders.message import Message
    from solders.pubkey import Pubkey
    from solders.transaction import Transaction

    if order["signature"] or order["expires"] <= int(time.time()):
        raise ValueError("订单已结算或已过期")

    def existing():
        return db.execute("SELECT * FROM payment_attempts WHERE order_id=?", (order["id"],)).fetchone()

    def response(attempt):
        return {
            "transaction": attempt["payload"], "lastValidBlockHeight": attempt["last_height"],
            "feeLamports": attempt["fee"],
        }

    attempt = existing()
    if attempt:
        height = rpc("getBlockHeight", [{"commitment": "confirmed"}])
        if height > attempt["last_height"]:
            raise ValueError("付款请求已失效，请核对原订单后再创建新订单")
        return response(attempt)

    payer = Pubkey.from_string(order["payer"])
    mint = Pubkey.from_string(order["mint"])
    destination = Pubkey.from_string(order["destination"])
    accounts = rpc("getTokenAccountsByOwner", [
        str(payer), {"mint": str(mint)}, {"encoding": "jsonParsed", "commitment": "confirmed"},
    ])["value"]
    source = None
    for entry in accounts:
        account = entry["account"]
        info = account["data"]["parsed"]["info"]
        amount = info["tokenAmount"]
        if (account["owner"] == TOKEN_PROGRAM and info["state"] == "initialized"
                and entry["pubkey"] != str(destination) and int(amount["amount"]) >= order["amount"]):
            source = Pubkey.from_string(entry["pubkey"])
            decimals = amount["decimals"]
            break
    if source is None:
        raise ValueError("当前钱包没有足够的 Devnet 测试代币")

    transfer = Instruction(Pubkey.from_string(TOKEN_PROGRAM), struct.pack("<BQB", 12, order["amount"], decimals), [
        AccountMeta(source, False, True), AccountMeta(mint, False, False),
        AccountMeta(destination, False, True), AccountMeta(payer, True, False),
    ])
    memo = Instruction(Pubkey.from_string(MEMO_PROGRAM), order["id"].encode("ascii"), [])
    block = rpc("getLatestBlockhash", [{"commitment": "confirmed"}])["value"]
    message = Message.new_with_blockhash([memo, transfer], payer, Hash.from_string(block["blockhash"]))
    message_payload = base64.b64encode(bytes(message)).decode("ascii")
    fee = rpc("getFeeForMessage", [message_payload, {"commitment": "confirmed"}])["value"]
    if fee is None:
        raise ValueError("无法读取交易手续费，请重试")
    if rpc("getBalance", [str(payer), {"commitment": "confirmed"}])["value"] < fee:
        raise ValueError("当前钱包没有足够的 Devnet SOL 支付手续费")
    payload = base64.b64encode(bytes(Transaction.new_unsigned(message))).decode("ascii")
    with db:
        db.execute("INSERT OR IGNORE INTO payment_attempts VALUES (?, ?, ?, ?)",
                   (order["id"], payload, block["lastValidBlockHeight"], fee))
    return response(existing())
