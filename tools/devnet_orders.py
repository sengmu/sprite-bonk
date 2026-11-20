"""Local Devnet operator CLI for the first Sprite Bonk shop item."""

import argparse
import json
import os
import secrets
import sqlite3
import time
from pathlib import Path
from urllib.request import Request, urlopen

RPC = "https://api.devnet.solana.com"
PRODUCT = "railing-fox-shop-skin"
MEMO_PROGRAM = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr"


def rpc(method, params):
    body = json.dumps(dict(jsonrpc="2.0", id=1, method=method, params=params))
    request = Request(RPC, body.encode(), {"Content-Type": "application/json"})
    with urlopen(request, timeout=15) as response:
        result = json.load(response)
    if "error" in result:
        raise ValueError("Devnet RPC rejected the request")
    return result["result"]


def open_database(path):
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE IF NOT EXISTS orders (
            id TEXT PRIMARY KEY, payer TEXT NOT NULL, product TEXT NOT NULL,
            mint TEXT NOT NULL, destination TEXT NOT NULL, amount INTEGER NOT NULL,
            created INTEGER NOT NULL, expires INTEGER NOT NULL, signature TEXT UNIQUE
        );
        CREATE TABLE IF NOT EXISTS inventory (
            payer TEXT NOT NULL, product TEXT NOT NULL, order_id TEXT NOT NULL,
            PRIMARY KEY (payer, product)
        );
    """)
    return db


def create_order(db, payer):
    if db.execute("SELECT 1 FROM inventory WHERE payer=? AND product=?", (payer, PRODUCT)).fetchone():
        raise ValueError("This wallet already owns the item")
    mint = os.environ["SPRITEBONK_DEVNET_MINT"]
    destination = os.environ["SPRITEBONK_DEVNET_TOKEN_ACCOUNT"]
    amount = int(os.environ["SPRITEBONK_DEVNET_AMOUNT"])
    if amount <= 0:
        raise ValueError("Amount must be a positive integer in token base units")
    now = int(time.time())
    order = (secrets.token_hex(16), payer, PRODUCT, mint, destination, amount, now, now + 900)
    with db:
        db.execute("INSERT INTO orders VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)", order)
    return dict(db.execute("SELECT * FROM orders WHERE id=?", (order[0],)).fetchone())


def verify_payment(order, tx):
    meta = tx["meta"]
    message = tx["transaction"]["message"]
    keys = message["accountKeys"]
    if meta is None or meta["err"] is not None:
        raise ValueError("Transaction failed")
    if not order["created"] <= (tx.get("blockTime") or 0) <= order["expires"]:
        raise ValueError("Payment landed outside the order window")
    if not any(key["signer"] and key["pubkey"] == order["payer"] for key in keys):
        raise ValueError("Expected payer did not sign")

    instructions = message["instructions"]
    if not any(ix.get("programId") == MEMO_PROGRAM and ix.get("parsed") == order["id"]
               for ix in instructions):
        raise ValueError("Order memo does not match")
    transfers = []
    for ix in instructions:
        parsed = ix.get("parsed")
        if not isinstance(parsed, dict) or parsed.get("type") != "transferChecked":
            continue
        info = parsed["info"]
        if ix.get("program") in ("spl-token", "spl-token-2022") and info.get("destination") == order["destination"]:
            transfers.append(info)
    if len(transfers) != 1:
        raise ValueError("Expected exactly one checked token transfer to the merchant")
    transfer = transfers[0]
    if (transfer["mint"] != order["mint"] or transfer["authority"] != order["payer"]
            or int(transfer["tokenAmount"]["amount"]) != order["amount"]):
        raise ValueError("Invalid mint, transfer authority, or amount")

    def balance(entries):
        return sum(int(entry["uiTokenAmount"]["amount"]) for entry in entries
                   if entry["mint"] == order["mint"]
                   and keys[entry["accountIndex"]]["pubkey"] == order["destination"])

    if balance(meta.get("postTokenBalances", [])) - balance(meta.get("preTokenBalances", [])) != order["amount"]:
        raise ValueError("Merchant balance change does not match the order")


def settle(db, order_id, signature):
    order = db.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone()
    if order is None:
        raise ValueError("Unknown order")
    if order["signature"] == signature:
        return {"status": "fulfilled", "order": order_id}
    tx = rpc("getTransaction", [signature, {
        "encoding": "jsonParsed", "commitment": "finalized", "maxSupportedTransactionVersion": 0,
    }])
    if tx is None:
        return {"status": "awaiting_finality", "order": order_id}
    verify_payment(order, tx)
    with db:
        updated = db.execute("UPDATE orders SET signature=? WHERE id=? AND signature IS NULL",
                             (signature, order_id))
        if updated.rowcount == 0:
            existing = db.execute("SELECT signature FROM orders WHERE id=?", (order_id,)).fetchone()
            if existing["signature"] != signature:
                raise ValueError("Order already paid with a different transaction")
        else:
            db.execute("INSERT INTO inventory VALUES (?, ?, ?)",
                       (order["payer"], order["product"], order_id))
    return {"status": "fulfilled", "order": order_id}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("create").add_argument("payer")
    payment = commands.add_parser("settle")
    payment.add_argument("order_id")
    payment.add_argument("signature")
    commands.add_parser("inventory").add_argument("payer")
    args = parser.parse_args()
    with open_database(args.db) as db:
        if args.command == "create":
            result = create_order(db, args.payer)
        elif args.command == "settle":
            result = settle(db, args.order_id, args.signature)
        else:
            result = [dict(row) for row in db.execute("SELECT * FROM inventory WHERE payer=?", (args.payer,))]
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, sqlite3.Error) as error:
        raise SystemExit(str(error)) from None
