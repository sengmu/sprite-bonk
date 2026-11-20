"""Build a single, reusable unsigned payment attempt for a Devnet order."""

import base64
import logging
import struct
import time

from devnet_orders import MEMO_PROGRAM, TOKEN_PROGRAM, rpc

logger = logging.getLogger(__name__)
COMPUTE_BUDGET = "ComputeBudget111111111111111111111111111111"
MAX_PRIORITY_FEE = 10_000


def account_permissions(message):
    header = message.header
    keys = message.account_keys
    signers = header.num_required_signatures
    if len(set(keys)) != len(keys):
        raise ValueError("付款交易含重复账户")
    return {
        key: (
            index < signers,
            index < signers - header.num_readonly_signed_accounts
            if index < signers else index < len(keys) - header.num_readonly_unsigned_accounts,
        )
        for index, key in enumerate(keys)
    }


def resolved_instructions(message):
    keys = message.account_keys
    return [
        (keys[ix.program_id_index], tuple(keys[index] for index in ix.accounts), bytes(ix.data))
        for ix in message.instructions
    ]


def broadcast_payment(db, order, payload):
    from solders.pubkey import Pubkey
    from solders.transaction import Transaction

    if order["signature"]:
        return {"signature": order["signature"]}
    attempt = db.execute("SELECT payload FROM payment_attempts WHERE order_id=?", (order["id"],)).fetchone()
    if attempt is None:
        raise ValueError("订单没有付款请求")
    try:
        signed = Transaction.from_bytes(base64.b64decode(payload, validate=True))
        expected = Transaction.from_bytes(base64.b64decode(attempt["payload"]))
    except (ValueError, TypeError) as error:
        raise ValueError("钱包返回无效交易") from error
    signed.sanitize()
    if signed.verify_with_results() != [True]:
        raise ValueError("钱包返回的付款签名无法通过验证")
    actual = signed.message
    quoted = expected.message
    if actual.account_keys[0] != quoted.account_keys[0]:
        raise ValueError("钱包更换了付款账户")
    actual_permissions = account_permissions(actual)
    quoted_permissions = account_permissions(quoted)
    actual_instructions = resolved_instructions(actual)
    budget = {}
    payment_instructions = []
    for program, accounts, data in actual_instructions:
        if str(program) != COMPUTE_BUDGET:
            payment_instructions.append((program, accounts, data))
            continue
        # Only SetComputeUnitLimit and SetComputeUnitPrice are accepted.
        if accounts or not data or (data[0], len(data)) not in ((2, 5), (3, 9)) or data[0] in budget:
            raise ValueError("钱包添加了不支持的计算预算指令")
        budget[data[0]] = int.from_bytes(data[1:], "little")
        if actual_permissions.get(program) != (False, False):
            raise ValueError("计算预算程序的账户权限不正确")
    if budget:
        del actual_permissions[Pubkey.from_string(COMPUTE_BUDGET)]
    limit = budget.get(2, 1_400_000)
    priority_fee = (limit * budget.get(3, 0) + 999_999) // 1_000_000
    if not 0 < limit <= 1_400_000 or priority_fee > MAX_PRIORITY_FEE:
        raise ValueError(f"钱包请求的优先费为 {priority_fee} lamports，超过 {MAX_PRIORITY_FEE} 上限")
    quoted_permissions.pop(Pubkey.from_string(COMPUTE_BUDGET), None)
    if actual_permissions != quoted_permissions:
        actual_programs = {program for program, _, _ in resolved_instructions(actual)}
        quoted_programs = {program for program, _, _ in resolved_instructions(quoted)}
        logger.warning(
            "Payment %s account mismatch: added=%d removed=%d permission_changes=%s "
            "programs_added=%s programs_removed=%s instructions=%d vs %d blockhash_changed=%s",
            order["id"],
            len(actual_permissions.keys() - quoted_permissions.keys()),
            len(quoted_permissions.keys() - actual_permissions.keys()),
            [
                (quoted_permissions[key], actual_permissions[key])
                for key in quoted_permissions.keys() & actual_permissions.keys()
                if quoted_permissions[key] != actual_permissions[key]
            ],
            sorted(map(str, actual_programs - quoted_programs)),
            sorted(map(str, quoted_programs - actual_programs)),
            len(actual.instructions), len(quoted.instructions),
            actual.recent_blockhash != quoted.recent_blockhash,
        )
        raise ValueError("钱包更改了付款交易的账户配置")
    if payment_instructions != [
        ix for ix in resolved_instructions(quoted) if str(ix[0]) != COMPUTE_BUDGET
    ]:
        raise ValueError("钱包更改了付款交易的指令")
    if actual.recent_blockhash != quoted.recent_blockhash:
        raise ValueError("钱包更换了付款交易的区块哈希")
    signature = str(signed.signatures[0])
    rpc("sendTransaction", [payload, {"encoding": "base64", "preflightCommitment": "confirmed"}])
    return {"signature": signature}


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
            "feeLamports": attempt["fee"], "maxFeeLamports": attempt["fee"] + MAX_PRIORITY_FEE,
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
    from solders.compute_budget import set_compute_unit_limit, set_compute_unit_price

    message = Message.new_with_blockhash(
        [set_compute_unit_limit(25_000), set_compute_unit_price(0), memo, transfer],
        payer, Hash.from_string(block["blockhash"]),
    )
    message_payload = base64.b64encode(bytes(message)).decode("ascii")
    fee = rpc("getFeeForMessage", [message_payload, {"commitment": "confirmed"}])["value"]
    if fee is None:
        raise ValueError("无法读取交易手续费，请重试")
    if rpc("getBalance", [str(payer), {"commitment": "confirmed"}])["value"] < fee:
        raise ValueError("当前钱包没有足够的 Devnet SOL 支付手续费")
    payload = base64.b64encode(bytes(Transaction.new_unsigned(message))).decode("ascii")
    with db:
        db.execute("BEGIN IMMEDIATE")
        if order["expires"] <= int(time.time()):
            raise ValueError("订单已过期，请重新下单")
        db.execute("INSERT OR IGNORE INTO payment_attempts VALUES (?, ?, ?, ?)",
                   (order["id"], payload, block["lastValidBlockHeight"], fee))
    return response(existing())
