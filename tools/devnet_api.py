"""Loopback-only HTTP adapter for the Devnet shop prototype."""

import argparse
import base64
import hashlib
import json
import secrets
import sqlite3
import time
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

from devnet_orders import create_order, open_database, rpc, settle
from devnet_payment import prepare_payment

BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
AUTH_SCHEMA = """
CREATE TABLE IF NOT EXISTS challenges (
    nonce TEXT PRIMARY KEY, payer TEXT NOT NULL, message TEXT NOT NULL, expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    digest TEXT PRIMARY KEY, payer TEXT NOT NULL, expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS payment_attempts (
    order_id TEXT PRIMARY KEY, payload TEXT NOT NULL, last_height INTEGER NOT NULL, fee INTEGER NOT NULL
);
"""


def wallet_key(address):
    if not isinstance(address, str) or not 32 <= len(address) <= 44:
        raise ValueError("Invalid wallet address")
    number = 0
    for char in address:
        number = number * 58 + BASE58.index(char)
    key = bytes(len(address) - len(address.lstrip("1")))
    key += number.to_bytes((number.bit_length() + 7) // 8, "big")
    return Ed25519PublicKey.from_public_bytes(key)


def digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


class ApiHandler(BaseHTTPRequestHandler):
    def respond(self, status, data):
        output = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(output)))
        self.end_headers()
        self.wfile.write(output)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 4096:
                raise ValueError("Expected a JSON object up to 4096 bytes")
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise ValueError("Expected a JSON object")
            with closing(open_database(self.server.database)) as db:
                status, result = self.dispatch(db, body)
            self.respond(status, result)
        except (ValueError, KeyError, TypeError, InvalidSignature) as error:
            self.respond(400, {"error": str(error) or "Invalid signature"})
        except sqlite3.IntegrityError:
            self.respond(409, {"error": "Payment or entitlement already recorded"})
        except (OSError, sqlite3.Error):
            self.respond(503, {"error": "Devnet verification temporarily unavailable"})

    def dispatch(self, db, body):
        now = int(time.time())
        if self.path == "/auth/challenge":
            payer = body["wallet"]
            wallet_key(payer)
            nonce = secrets.token_urlsafe(24)
            expires = now + 300
            message = (
                "Sprite Bonk Devnet shop login\n"
                "Scope: local Devnet orders and inventory. No transaction approval.\n"
                f"Wallet: {payer}\nNonce: {nonce}\nExpires (Unix UTC): {expires}"
            )
            with db:
                db.execute("DELETE FROM challenges WHERE expires <= ?", (now,))
                db.execute("INSERT INTO challenges VALUES (?, ?, ?, ?)", (nonce, payer, message, expires))
            return 200, {"nonce": nonce, "message": message, "expires": expires}

        if self.path == "/auth/session":
            challenge = db.execute("SELECT * FROM challenges WHERE nonce=? AND expires>?",
                                   (body["nonce"], now)).fetchone()
            if challenge is None:
                return 401, {"error": "Challenge expired or already used"}
            signature = base64.b64decode(body["signature"], validate=True)
            wallet_key(challenge["payer"]).verify(signature, challenge["message"].encode())
            token = secrets.token_urlsafe(32)
            with db:
                consumed = db.execute("DELETE FROM challenges WHERE nonce=? AND expires>?",
                                      (challenge["nonce"], int(time.time())))
                if consumed.rowcount != 1:
                    return 401, {"error": "Challenge expired or already used"}
                db.execute("DELETE FROM sessions WHERE expires <= ?", (now,))
                db.execute("INSERT INTO sessions VALUES (?, ?, ?)", (digest(token), challenge["payer"], now + 3600))
            return 200, {"token": token, "expires": now + 3600}

        scheme, _, token = self.headers.get("Authorization", "").partition(" ")
        session = db.execute("SELECT payer FROM sessions WHERE digest=? AND expires>?",
                             (digest(token), now)).fetchone()
        if scheme != "Bearer" or session is None:
            return 401, {"error": "Wallet login required"}
        payer = session["payer"]
        if self.path == "/orders/create":
            return 201, create_order(db, payer)
        if self.path == "/orders/list":
            rows = db.execute("SELECT * FROM orders WHERE payer=? ORDER BY created DESC, id DESC", (payer,))
            return 200, {"orders": [dict(row) for row in rows]}
        if self.path == "/orders/payment":
            order = db.execute("SELECT * FROM orders WHERE id=? AND payer=?",
                               (body["orderId"], payer)).fetchone()
            if order is None:
                return 404, {"error": "Unknown order"}
            return 200, prepare_payment(db, order)
        if self.path == "/orders/settle":
            order_id = body["orderId"]
            if db.execute("SELECT 1 FROM orders WHERE id=? AND payer=?", (order_id, payer)).fetchone() is None:
                return 404, {"error": "Unknown order"}
            return 200, settle(db, order_id, body["signature"])
        if self.path == "/orders/recover":
            order_id = body["orderId"]
            order = db.execute("SELECT * FROM orders WHERE id=? AND payer=?", (order_id, payer)).fetchone()
            if order is None:
                return 404, {"error": "Unknown order"}
            if order["signature"]:
                return 200, {"status": "fulfilled", "order": order_id}
            entries = rpc("getSignaturesForAddress", [
                order["destination"], {"limit": 100, "commitment": "finalized"},
            ])
            for entry in entries:
                memo = entry.get("memo") or ""
                # RPC prefixes displayed memos with their length, e.g. "[32] …".
                if entry["err"] is None and memo in (order_id, f"[{len(order_id)}] {order_id}"):
                    try:
                        return 200, settle(db, order_id, entry["signature"])
                    except ValueError:
                        continue
            return 200, {"status": "not_found", "order": order_id}
        if self.path == "/inventory":
            rows = db.execute("SELECT product, order_id FROM inventory WHERE payer=?", (payer,))
            return 200, {"items": [dict(row) for row in rows]}
        return 404, {"error": "Unknown endpoint"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True)
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()
    with closing(open_database(args.db)) as db:
        db.executescript(AUTH_SCHEMA)
    with ThreadingHTTPServer(("127.0.0.1", args.port), ApiHandler) as server:
        server.database = args.db
        server.serve_forever()


if __name__ == "__main__":
    main()
