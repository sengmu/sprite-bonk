class_name WalletManager
extends Node
## Solana wallet layer (Phase C — connect/read only, NO transactions).
##
## Design:
## - Guest mode is the default and needs no wallet to play.
## - "Connected" state = a validated Solana address bound to this session,
##   persisted in user://wallet.cfg. Balances are read via public JSON-RPC.
## - Android uses Mobile Wallet Adapter (MWA) for authorization. Manual
##   address entry is also available for balance lookup.
## - Token hooks for the tokenomics plan ($SPRT / Genesis NFT, see
##   goals/5000/files/sprite-bonk-tokenomics-2026-10-24.md) are stubs:
##   neither the token nor the NFT collection exists yet.

signal state_changed
signal balance_updated(sol: float)
signal balance_failed(reason: String)
signal auth_failed(reason: String)

const ERR_MWA_UNAVAILABLE := "此版本无法打开移动钱包，可输入公开地址查询余额。"

const RPC_MAINNET := "https://api.mainnet-beta.solana.com"
const RPC_DEVNET := "https://api.devnet.solana.com"
const BASE58_ALPHABET := "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

# Tokenomics hooks (stubs until TGE / Genesis mint — values intentionally unset).
const SPRT_MINT := ""  # $SPRT mint address — TBD at TGE (tokenomics §待拍板)
const GENESIS_COLLECTION := ""  # Genesis NFT collection — TBD at P1

var cluster := "mainnet-beta"
var address := ""  # empty = guest mode
var last_balance_sol := -1.0
## Cycle 18 (store checklist): the balance read used to fail
## SILENTLY (the completion handler just returned), leaving
## the UI on "…" forever — a reviewer reads that as broken.
## The read now tracks an explicit state the panel renders:
## idle / loading / ok / failed (+ a human reason).
var balance_state := "idle"
var balance_error := ""

var _http: HTTPRequest
var _adapter: Node = null

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_rpc_completed)
	_init_mwa_adapter()
	_load_saved()

func _init_mwa_adapter() -> void:
	if Engine.has_singleton("WalletAdapterAndroid") and ClassDB.class_exists("WalletAdapter"):
		_adapter = ClassDB.instantiate("WalletAdapter")
		if _adapter:
			add_child(_adapter)
			if _adapter.has_signal("connection_established"):
				_adapter.connect("connection_established", Callable(self, "_on_mwa_connected"))
			if _adapter.has_signal("connection_failed"):
				_adapter.connect("connection_failed", Callable(self, "_on_mwa_failed"))

func is_wallet_connected() -> bool:
	return address != ""

func short_address() -> String:
	if address.length() <= 10:
		return address
	return address.substr(0, 4) + "…" + address.substr(address.length() - 4, 4)

func rpc_url() -> String:
	return RPC_DEVNET if cluster == "devnet" else RPC_MAINNET

func is_mwa_available() -> bool:
	return _adapter != null and _adapter.has_method("connect_wallet")

func _on_mwa_connected() -> void:
	if _adapter and _adapter.has_method("get_connected_key"):
		var key = _adapter.call("get_connected_key")
		if key != null:
			var addr_str: String = key.to_string()
			if is_valid_address(addr_str):
				connect_with_address(addr_str)

func _on_mwa_failed() -> void:
	auth_failed.emit("MWA 授权失败或已取消")

func request_authorize() -> String:
	if is_mwa_available():
		# Android chooses the wallet through the MWA association intent.
		_adapter.call("connect_wallet")
		return ""
	return ERR_MWA_UNAVAILABLE

## Watch-only connect: validate + bind an address the user pastes/types.
## No keys, no signing — read-only by construction.
func connect_with_address(addr: String) -> bool:
	var a := addr.strip_edges()
	if not is_valid_address(a):
		auth_failed.emit("invalid Solana address")
		return false
	address = a
	_save()
	state_changed.emit()
	fetch_balance()
	return true

func disconnect_wallet() -> void:
	address = ""
	last_balance_sol = -1.0
	balance_state = "idle"
	balance_error = ""
	_save()
	state_changed.emit()

# ------------------------------------------------------------- validation
static func is_valid_address(a: String) -> bool:
	if a.length() < 32 or a.length() > 44:
		return false
	for ch in a:
		if not BASE58_ALPHABET.contains(ch):
			return false
	return _base58_decoded_len(a) == 32

static func _base58_decoded_len(a: String) -> int:
	# Big-number base58 -> bytes length (enough to verify the 32-byte size).
	var bytes: Array[int] = [0]
	for ch in a:
		var carry := BASE58_ALPHABET.find(ch)
		if carry < 0:
			return -1
		for i in range(bytes.size()):
			var v := bytes[i] * 58 + carry
			bytes[i] = v & 0xFF
			carry = v >> 8
		while carry > 0:
			bytes.append(carry & 0xFF)
			carry >>= 8
	var leading := 0
	for ch in a:
		if ch == "1":
			leading += 1
		else:
			break
	var n := bytes.size()
	while n > 0 and bytes[n - 1] == 0:
		n -= 1  # significant bytes of the numeric value (0 value -> 0 bytes)
	return leading + n

# ------------------------------------------------------------- reads
func fetch_balance() -> void:
	if not is_wallet_connected():
		return
	balance_state = "loading"
	balance_error = ""
	state_changed.emit()
	var body := JSON.stringify({
		"jsonrpc": "2.0", "id": 1, "method": "getBalance", "params": [address]
	})
	var headers := ["Content-Type: application/json"]
	if _http.request(rpc_url(), headers, HTTPClient.METHOD_POST, body) != OK:
		_fail_balance("网络请求无法发出")

func _fail_balance(reason: String) -> void:
	balance_state = "failed"
	balance_error = reason
	balance_failed.emit(reason)
	state_changed.emit()

func _on_rpc_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_balance("网络错误")
		return
	if code != 200:
		_fail_balance("RPC 返回 %d" % code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("result") and parsed["result"] is Dictionary:
		var lamports: float = float(parsed["result"].get("value", 0))
		last_balance_sol = lamports / 1_000_000_000.0
		balance_state = "ok"
		balance_error = ""
		balance_updated.emit(last_balance_sol)
		state_changed.emit()
	else:
		_fail_balance("RPC 响应无效")

# ------------------------------------------------------------- token hooks (stubs)
## $SPRT balance — stub until the token is issued at TGE.
func fetch_sprt_balance() -> float:
	return -1.0  # not issued yet (SPRT_MINT empty)

## Genesis NFT ownership — stub until the Genesis mint (P1).
func has_genesis_nft() -> bool:
	return false  # collection not minted yet (GENESIS_COLLECTION empty)

# ------------------------------------------------------------- persistence
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "address", address)
	cfg.set_value("wallet", "cluster", cluster)
	cfg.save("user://wallet.cfg")

func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://wallet.cfg") == OK:
		address = String(cfg.get_value("wallet", "address", ""))
		cluster = String(cfg.get_value("wallet", "cluster", "mainnet-beta"))
		if not is_valid_address(address):
			address = ""
