class_name Profile
extends RefCounted
## Persistent meta profile (MECHANICS §7.3 shape, local subset):
## {stardust, totalStardust, league[], captured{}, seen[], lab{}} in
## user://profile.json. Captures/league write through immediately
## (the original's keepLive rule, §8); stardust settles at run end.

const PATH := "user://profile.json"

## Lab upgrades (MECHANICS §6.2). Cost rules:
##   ke(x) = round(x*0.85/5)*5; m(base,g): level n costs ke(base*g^n);
##   h(x) one-time ke(x); Ae arrays are per-level list prices (ke'd).
## `fx` marks which effects are wired into live systems this cycle;
## the rest are stored levels whose systems don't exist yet (noted in
## DIFF cycle 7: magnet/research/archive/bag/ult have no consumer).
## Cycle 13: "ult" gained its consumer — Ult.rate() reads the level
## (+4% charge rate per level, the bundle's rate() term).
const LAB := {
	"slot-move": {"label": "招式槽+1", "max": 1, "kind": "h", "base": 1500.0, "fx": true},
	"slot-vit": {"label": "维生素槽+1", "max": 2, "kind": "ae", "list": [1200.0, 3000.0], "fx": true},
	"reroll": {"label": "重抽+1/局", "max": 6, "kind": "m", "base": 120.0, "g": 1.4, "fx": true},
	"skip": {"label": "跳过+1/局", "max": 6, "kind": "m", "base": 80.0, "g": 1.4, "fx": true},
	"banish": {"label": "放逐+1/局", "max": 6, "kind": "m", "base": 150.0, "g": 1.4, "fx": true},
	"choice4": {"label": "升级四选一", "max": 1, "kind": "h", "base": 3000.0, "fx": true},
	"dmg": {"label": "伤害+4%/级", "max": 8, "kind": "m", "base": 100.0, "g": 1.4, "fx": true},
	"hp": {"label": "最大HP+8/级", "max": 8, "kind": "m", "base": 100.0, "g": 1.4, "fx": true},
	"spd": {"label": "移速+2.5%/级", "max": 6, "kind": "m", "base": 120.0, "g": 1.45, "fx": true},
	"xp": {"label": "经验+5%/级", "max": 6, "kind": "m", "base": 120.0, "g": 1.45, "fx": true},
	"gold": {"label": "金币+8%/级", "max": 6, "kind": "m", "base": 100.0, "g": 1.45, "fx": true},
	"luck": {"label": "幸运+5/级", "max": 6, "kind": "m", "base": 140.0, "g": 1.45, "fx": true},
	"magnet": {"label": "拾取范围+0.6/级", "max": 5, "kind": "m", "base": 80.0, "g": 1.45, "fx": false},
	"regen": {"label": "再生+0.2/级", "max": 5, "kind": "m", "base": 120.0, "g": 1.45, "fx": true},
	"armor": {"label": "护甲+2/级", "max": 6, "kind": "m", "base": 120.0, "g": 1.45, "fx": true},
	"revive": {"label": "开局复活", "max": 1, "kind": "h", "base": 5000.0, "fx": true},
	"research": {"label": "研究+25%/级", "max": 4, "kind": "m", "base": 250.0, "g": 1.6, "fx": false},
	"party": {"label": "队友位 2→3", "max": 1, "kind": "h", "base": 3500.0, "fx": true},
	"archive": {"label": "档案位+5/级", "max": 4, "kind": "ae", "list": [600.0, 1200.0, 2000.0, 3000.0], "fx": true},
	"crit": {"label": "暴击+1%/级", "max": 5, "kind": "m", "base": 200.0, "g": 1.5, "fx": true},
	"atkspd": {"label": "攻速+2%/级", "max": 5, "kind": "m", "base": 220.0, "g": 1.5, "fx": true},
	"area": {"label": "范围+3%/级", "max": 5, "kind": "m", "base": 200.0, "g": 1.5, "fx": true},
	"ult": {"label": "必杀充能+4%/级", "max": 5, "kind": "m", "base": 250.0, "g": 1.5, "fx": true},
	"bag": {"label": "背包带入 2→3", "max": 1, "kind": "h", "base": 4000.0, "fx": true},
}
const LAB_ORDER := ["slot-move", "slot-vit", "choice4", "party", "reroll", "skip", "banish",
	"dmg", "hp", "spd", "xp", "gold", "luck", "regen", "armor", "crit", "atkspd", "area", "ult",
	"magnet", "research", "archive", "revive", "bag"]

static var data: Dictionary = {}
static var _loaded := false

static func ke(x: float) -> int:
	return int(round(x * 0.85 / 5.0)) * 5

## Save-schema version (hotfix 2026-10-25): 1 = every build up to
## cycle 9 (unversioned). load_profile stamps the current version
## after a tolerant per-key coercion, so an upgrade (or a hand-
## edited / corrupted file) can never inject a wrong-typed value
## into the boot path — a bad key resets to its default instead of
## crashing a cast downstream.
const PROFILE_VERSION := 3

static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	data = {"stardust": 0, "totalStardust": 0, "league": [], "captured": {}, "seen": [], "lab": {}, "counters": {}, "items_off": [], "archive_presets": [], "archive_preset_active": -1}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var v = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				for k in v.keys():
					data[k] = v[k]
	if not (data.get("league") is Array):
		data["league"] = []
	if not (data.get("captured") is Dictionary):
		data["captured"] = {}
	if not (data.get("seen") is Array):
		data["seen"] = []
	if not (data.get("lab") is Dictionary):
		data["lab"] = {}
	if not (data.get("counters") is Dictionary):
		data["counters"] = {}
	if not (data.get("species_played") is Array):
		data["species_played"] = []
	if not (data.get("shinies") is Array):
		data["shinies"] = []
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	# Cycle 16: the daily shop's profile state (bundle fA
	# sanitization @1569144 region): bag must be a Dictionary;
	# shop survives only as {day: finite number, n: Dictionary}
	# — anything else is deleted, exactly like the original.
	if not (data.get("bag") is Dictionary):
		data["bag"] = {}
	var shp = data.get("shop")
	if not (shp is Dictionary) or not (shp.get("day") is float or shp.get("day") is int) \
			or not (shp.get("n") is Dictionary):
		data.erase("shop")
	data["stardust"] = int(data.get("stardust", 0))
	data["totalStardust"] = int(data.get("totalStardust", 0))
	# C23: old tier counters already encoded Normal clear as 1.
	if not (data.get("biomes") is Dictionary):
		data["biomes"] = {"forest": 0}
	for biome in BIOME_ORDER:
		var legacy := int(data["counters"].get("tier_" + biome, -1))
		if legacy >= 1:
			data["biomes"][biome] = maxi(int(data["biomes"].get(biome, -1)), legacy)
	data["version"] = PROFILE_VERSION

static func save_profile() -> void:
	load_profile()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func stardust() -> int:
	load_profile()
	return int(data.get("stardust", 0))

static func add_stardust(n: int) -> void:
	load_profile()
	data["stardust"] = int(data.get("stardust", 0)) + n
	data["totalStardust"] = int(data.get("totalStardust", 0)) + n
	save_profile()

static func lab_level(id: String) -> int:
	load_profile()
	return int((data.get("lab", {}) as Dictionary).get(id, 0))

static func lab_cost(id: String) -> int:
	var cfg: Dictionary = LAB[id]
	var lv := lab_level(id)
	if lv >= int(cfg["max"]):
		return -1
	match String(cfg["kind"]):
		"h":
			return ke(float(cfg["base"]))
		"m":
			return ke(float(cfg["base"]) * pow(float(cfg["g"]), float(lv)))
		"ae":
			return ke(float((cfg["list"] as Array)[lv]))
	return -1

static func lab_buy(id: String) -> bool:
	var cost := lab_cost(id)
	if cost < 0 or stardust() < cost:
		return false
	data["stardust"] = int(data["stardust"]) - cost
	var lab: Dictionary = data.get("lab", {})
	lab[id] = lab_level(id) + 1
	data["lab"] = lab
	save_profile()
	return true

static func in_league(family_id: int) -> bool:
	load_profile()
	for x in data.get("league", []):
		if int(x) == family_id:
			return true
	return false

static func join_league(family_id: int, species_key: String) -> void:
	load_profile()
	if not in_league(family_id):
		var lg: Array = data.get("league", [])
		lg.append(family_id)
		data["league"] = lg
	var cap: Dictionary = data.get("captured", {})
	cap[species_key] = Time.get_datetime_string_from_system()
	data["captured"] = cap
	count("captures", 1.0)  # original joinLeague: meta.count('captures', 1)
	save_profile()

static func mark_seen(species_key: String) -> void:
	load_profile()
	var sn: Array = data.get("seen", [])
	if not sn.has(species_key):
		sn.append(species_key)
		data["seen"] = sn
		save_profile()

## ------------------------------------------------------------------
## Lifetime counters + League challenges (§3, cycles 8-9). The
## original's meta layer counts lifetime stats via meta.count(key)
## into profile.counters (bundle main: hA @1570066), and gates
## League encounters on per-species challenge completion:
## leagueReady() = roster entries with a challenge whose every part
## {counter, goal} is met (vA/yA region, main @1568236 in the old
## char-offset scheme). Counter reads are special-cased in _A
## (@1570066): 'league' = league size excluding dex 151, 'birds' =
## owned of [144,145,146], 'tier_<biome>' = biome best tier.
##
## Cycle 9 (audit §5): the challenge table is no longer a hand-kept
## 15-species subset — it is BUILT from the bundle's own roster
## (assets/data/roster.json, all 79 family entries extracted from
## the news chunk) for every species the game models. Parts whose
## counter needs a system we have not built (rock-smash
## interactables, elemental reactions, the berry economy, weather
## kills, soak status, per-biome win records) are
## flagged unsupported: they render in the unlocks screen but can
## never complete — an honest gate instead of fabricated progress.
## ------------------------------------------------------------------

const UNSUPPORTED_COUNTERS := ["rainKills", "best_rainKills", "win_forest"]
# Cycle 13: "ultimates" left this list — the ult system exists
# now (scripts/ult.gd) and the counter increments for real at
# every cast, so roster challenges gated on it can complete.
# Cycle 14: "soaked" / "reactions" / "best_reactions" left too —
# the wet layer exists (ult riders + rain + electrocute), and
# electrocutions increment the reactions counter for real
# (the other reaction kinds remain unported backlog).
# Cycle 15: "rocks" / "berries" left — the populate kinds
# are built (rock piles pay gold, berry bushes heal), and
# the remaining reactions increment 'reactions' for real.

static var _challenges: Dictionary = {}
static var _challenges_built := false

static func _fmt_goal(g: float) -> String:
	if g >= 1000.0:
		var s := str(int(g))
		var out := ""
		while s.length() > 3:
			out = "," + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		return s + out
	return str(int(g))

static func _desc_for(counter: String, goal: float) -> String:
	var g := _fmt_goal(goal)
	var biome_zh := {"forest": "森林", "graveyard": "墓园", "desert": "沙漠", "volcano": "火山"}
	if counter.begins_with("boss_"):
		return "击败 %s 名%s守护者" % [g, String(biome_zh.get(counter.trim_prefix("boss_"), ""))]
	if counter.begins_with("kills_"):
		return "在%s累计击杀 %s 只" % [String(biome_zh.get(counter.trim_prefix("kills_"), "")), g]
	if counter.begins_with("tier_"):
		return "%s区域达到 %s 阶" % [String(biome_zh.get(counter.trim_prefix("tier_"), "")), g]
	match counter:
		"runs": return "完成 %s 局对战（胜负不限）" % g
		"kills": return "累计击杀 %s 只" % g
		"dodges": return "闪避 %s 次攻击" % g
		"crits": return "累计暴击 %s 次" % g
		"best_crits": return "单局暴击 %s 次" % g
		"healed": return "累计回复 %s 点 HP" % g
		"best_healed": return "单局回复 %s 点 HP" % g
		"alphas": return "累计击败 %s 只阿尔法" % g
		"best_alphas": return "单局击败 %s 只阿尔法" % g
		"alphaCaught": return "用友情球收服 %s 只阿尔法" % g
		"burned": return "累计使 %s 只陷入灼伤" % g
		"best_burned": return "单局使 %s 只陷入灼伤" % g
		"poisoned": return "累计使 %s 只中毒" % g
		"best_poisoned": return "单局使 %s 只中毒" % g
		"slept": return "累计使 %s 只睡着" % g
		"best_slept": return "单局使 %s 只睡着" % g
		"frozen": return "累计冻结 %s 只" % g
		"best_frozen": return "单局冻结 %s 只" % g
		"paralyzed": return "累计麻痹 %s 只" % g
		"best_paralyzed": return "单局麻痹 %s 只" % g
		"confused": return "累计使 %s 只混乱" % g
		"maxLevel": return "单局达到 %s 级" % g
		"maxTime": return "单局存活 %s 秒" % g
		"bosses": return "累计击败 %s 名守护者" % g
		"gold": return "累计获得 %s 金币" % g
		"evolutions": return "累计进化 %s 次" % g
		"league": return "联盟达到 %s 名成员" % g
		"speciesPlayed": return "使用过 %s 只不同的初始伙伴" % g
		"chests": return "开启 %s 个宝箱" % g
		"rocks": return "用碎岩击破 %s 块岩石" % g
		"best_reactions", "reactions": return "触发 %s 次元素反应" % g
		"berries": return "吃掉 %s 颗树果/回复道具" % g
		"ultimates": return "释放 %s 次必杀技" % g
		"rainKills", "best_rainKills": return "雨天击杀 %s 只" % g
		"soaked": return "使 %s 只浸水" % g
		"win_forest": return "通关常磐森林 %s 次" % g
		"birds": return "三圣鸟入盟 %s 只" % g
		"legendaries": return "累计击败 %s 只传说守护者" % g
	return "%s 达到 %s" % [counter, g]

## The challenge table (species key -> {rank, parts[]}), built once
## from the roster for every modelled encounter species.
static func challenges() -> Dictionary:
	if _challenges_built:
		return _challenges
	_challenges_built = true
	for key in GameData.roster_species_keys():
		var e := GameData.roster_for_species(String(key))
		if e.is_empty():
			continue
		var parts: Array = []
		for p in e.get("challenge", []):
			var c := String(p["counter"])
			var part := {"counter": c, "goal": float(p["goal"]),
				"desc": _desc_for(c, float(p["goal"]))}
			if UNSUPPORTED_COUNTERS.has(c):
				part["unsupported"] = true
			parts.append(part)
		if not parts.is_empty():
			_challenges[String(key)] = {"rank": String(e.get("rank", "")), "parts": parts}
	return _challenges

## Display order for the unlocks screen: roster-id order.
static func challenge_order() -> Array:
	var keys: Array = challenges().keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return GameData.roster_id_for_species(a) < GameData.roster_id_for_species(b))
	return keys

static func _counters() -> Dictionary:
	load_profile()
	if not data.has("counters") or not (data["counters"] is Dictionary):
		data["counters"] = {}
	return data["counters"]

## Additive lifetime counter (original count(key, n), 'add' mode).
## Mutates memory only; milestone saves (run end / capture / Lab
## buy) flush it — the original's keepLive policy persists at the
## events that matter rather than on every kill.
static func count(counter: String, n: float = 1.0) -> void:
	var c := _counters()
	c[counter] = float(c.get(counter, 0.0)) + n

## Best-of counter ('max' mode: maxTime, best_* single-run records).
static func count_max(counter: String, v: float) -> void:
	var c := _counters()
	c[counter] = maxf(float(c.get(counter, 0.0)), v)

## Counter read with the original's special cases (_A @1570066).
static func counter_value(counter: String) -> float:
	load_profile()
	if counter.begins_with("tier_"):
		return float(maxi(0, biome_tier(counter.trim_prefix("tier_"))))
	if counter in ["hard", "night"]:
		var total := 0
		for biome in BIOME_ORDER:
			if biome_tier(biome) >= (2 if counter == "hard" else 3):
				total += 1
		return float(total)
	if counter == "league":
		var n := 0
		for f in data.get("league", []):
			if int(f) != 151:
				n += 1
		return float(n)
	if counter == "birds":
		# Cycle 20.1 (audit N2): the league array loads from
		# JSON as FLOATS and Array.has() is type-strict, so
		# .has(int) never matched birds joined in earlier
		# sessions — the legendary challenge goal birds>=3
		# (roster) could never complete. Tolerant compare,
		# exactly like in_league() above.
		var n := 0
		for b in [144, 145, 146]:
			for f in data.get("league", []):
				if int(f) == b:
					n += 1
					break
		return float(n)
	if counter == "speciesPlayed":
		return float((data.get("species_played", []) as Array).size())
	return float(_counters().get(counter, 0.0))

## Distinct starter species ever played (roster 'speciesPlayed'
## counter — recorded at run start, the original's semantics).
static func record_species_played(species_key: String) -> void:
	load_profile()
	var arr: Array = data.get("species_played", [])
	if not arr.has(species_key):
		arr.append(species_key)
		data["species_played"] = arr
		save_profile()

## Settings (bundle defaults @1566819: shakeOn true, screenShake 1).
## Only shakeOn has a menu toggle in our build; screenShake is
## stored and honoured by World.add_trauma (DIFF cycle 9).
const SETTING_DEFAULTS := {"shakeOn": true, "screenShake": 1.0,
	# Cycle 13: bundle defaults (@1567334 region): autoUlt off,
	# ultPose on. autoUlt also makes casts "quiet" (no pose /
	# hitstop / cut-in) since quiet = ultQuiet ?? autoUlt.
	"autoUlt": false, "ultPose": true,
	# Cycle 16: the sound tab (bundle uA @1566804; settings UI
	# @1963535 — four sliders 0-1 step .05 + the muteHidden
	# toggle). silentPlay is iOS-only in the bundle
	# (navigator.audioSession) and is not stored here.
	"master": 0.8, "music": 0.5, "sfx": 0.7, "cries": 0.6,
	"muteHidden": true,
	# Cycle 18: gfx / controls / HUD sections (bundle settings
	# keys @1970253 region — hudScale/hudOpacity/bossOpacity/
	# minimapScale/touchScale exist there; fpsCap/camSpeed/
	# invertY/fixedStick are our names for the bundle's fps
	# segmented cap, sensitivity, Y-invert and fixed-stick
	# toggles, each wired to a real system in this build).
	"hudScale": 1.0, "hudOpacity": 1.0, "bossOpacity": 1.0,
	"minimapScale": 1.0, "touchScale": 1.0, "fpsCap": 0,
	"camSpeed": 1.0, "invertY": false, "fixedStick": false,
	"camAssist": false, "camDist": 11.0,
	# UI-mobile P3 (plan D6): the phone HUD's classic layout
	# (the 21.3.2 geometry) — off = the new layout (default).
	"classicLayout": false}

static func setting(key: String):
	load_profile()
	var s: Dictionary = data.get("settings", {})
	if s.has(key):
		return s[key]
	return SETTING_DEFAULTS.get(key)

static func set_setting(key: String, v) -> void:
	load_profile()
	var s: Dictionary = data.get("settings", {})
	s[key] = v
	data["settings"] = s
	save_profile()

## Challenge parts with live values (vA: value clamped to goal).
static func challenge_parts(species_key: String) -> Array:
	var out: Array = []
	var ch := challenges()
	if not ch.has(species_key):
		return out
	for p in ch[species_key]["parts"]:
		var d: Dictionary = (p as Dictionary).duplicate()
		d["value"] = minf(counter_value(String(d["counter"])), float(d["goal"]))
		out.append(d)
	return out

## yA: every part at goal. Unsupported parts never complete.
static func challenge_done(species_key: String) -> bool:
	var ch := challenges()
	if not ch.has(species_key):
		return false
	for p in ch[species_key]["parts"]:
		var pd := p as Dictionary
		if bool(pd.get("unsupported", false)):
			return false
		if counter_value(String(pd["counter"])) < float(pd["goal"]):
			return false
	return true

## ------------------------------------------------------------------
## Cycle 16: the META daily shop （星尘商店）. Verdict from the
## bundle: it EXISTS — distinct from the in-run Meowth gold shop
## (cycle 15 OUT). Spec in DIFF cycle 16: catalog $e (news chunk
## @83481) is FIXED; prices escalate within the day (nt @83738,
## et = .5); quotas reset at UTC midnight (day fn Ve @82215,
## anchor x = Date.UTC(2026,9,12) @85403); buy logic wA (main
## @1571186) with counts via CA (@1571123). Item names/descs are
## this build's Chinese renderings of the ur table entries
## (news chunk; rare-candy @54951 et al).
## ------------------------------------------------------------------

## Cycle 18 CORRECTION: the cycle-16 descs below were this
## build's own inventions ("+15% XP", "+20% gold", "+1.5 pickup",
## "+15% damage & area", "+25% damage") — the bundle's item
## table Ye (news chunk @~82731) says otherwise, and its
## applyBoosts (main @1444306) pins the mechanics:
##   rare-candy  start the run at level +2 (2 pending drafts)
##   lucky-egg   tempMod {xpGain, x1.25} for the whole run
##   amulet-coin tempMod {gold, x1.5} for the whole run
##   honey       one extra alpha event per zone (t=240, @852778)
##   shiny-stone a shiny is guaranteed in zone 1 (@1049061)
##   master-ball the run's first capture (alpha/league) is sure
## The descs now render Ye faithfully.
const SHOP_ITEMS := [
	{"id": "rare-candy", "price": 150, "daily": 4, "tier": 1, "name": "神奇糖果",
		"desc": "开局等级 +2，并获得 2 次升级选择"},
	{"id": "lucky-egg", "price": 250, "daily": 4, "tier": 1, "name": "幸运蛋",
		"desc": "整局经验 +25%"},
	{"id": "amulet-coin", "price": 250, "daily": 4, "tier": 1, "name": "护符金币",
		"desc": "整局金币 +50%"},
	{"id": "honey", "price": 450, "daily": 3, "tier": 2, "name": "甜甜蜜",
		"desc": "每一区额外出现 1 只阿尔法"},
	{"id": "shiny-stone", "price": 900, "daily": 2, "tier": 3, "name": "闪光之石",
		"desc": "第 1 区必定出现 1 只闪光宝可梦"},
	{"id": "master-ball", "price": 1800, "daily": 1, "tier": 4, "name": "大师球",
		"desc": "本局第一次收服（阿尔法或联盟）必定成功"},
]
const SHOP_BAG_CAP := 9          # wA: bag[t] >= 9 -> full
const SHOP_PRICE_STEP := 0.5     # nt: price x (1 + .5 x bought)

static func _shop_anchor_unix() -> float:
	return Time.get_unix_time_from_datetime_dict(
		{"year": 2026, "month": 10, "day": 12, "hour": 0, "minute": 0, "second": 0})

## Ve(t): the shop day number (1 = 2026-10-12 UTC).
static func shop_day_number(unix_t: float) -> int:
	return int(floor((unix_t - _shop_anchor_unix()) / 86400.0)) + 1

static func shop_now() -> float:
	return Time.get_unix_time_from_system()

## Seconds until the next UTC midnight (the shop screen's
## countdown; the bundle shows Gn(be(now)) - now).
static func shop_seconds_to_reset(unix_t: float) -> int:
	var next := _shop_anchor_unix() + float(shop_day_number(unix_t)) * 86400.0
	return maxi(0, int(ceil(next - unix_t)))

static func shop_item(id: String) -> Dictionary:
	for it in SHOP_ITEMS:
		if String(it["id"]) == id:
			return it
	return {}

## CA(profile, now): today's purchase counts ({} on a new day).
static func shop_bought_today(unix_t: float) -> Dictionary:
	load_profile()
	var shp = data.get("shop")
	if shp is Dictionary and int(shp.get("day", -1)) == shop_day_number(unix_t):
		return (shp.get("n", {}) as Dictionary).duplicate()
	return {}

static func bag_count(id: String) -> int:
	load_profile()
	return int((data.get("bag", {}) as Dictionary).get(id, 0))

## nt(def, boughtToday): the escalated price of the next copy.
static func shop_price(id: String, unix_t: float) -> int:
	var it := shop_item(id)
	if it.is_empty():
		return -1
	var bought := int(shop_bought_today(unix_t).get(id, 0))
	return int(round(float(it["price"]) * (1.0 + SHOP_PRICE_STEP * float(bought))))

## wA(profile, id, now): buy one copy into the bag. Returns ""
## on success, else the bundle's failure kind in its check
## order: "unknown" (not in the shop) -> "soldout" (today's
## quota spent) -> "bagfull" (bag holds 9) -> "poor".
static func shop_buy(id: String, unix_t: float = -1.0) -> String:
	load_profile()
	if unix_t < 0.0:
		unix_t = shop_now()
	var it := shop_item(id)
	if it.is_empty():
		return "unknown"
	var counts := shop_bought_today(unix_t)
	var bought := int(counts.get(id, 0))
	if bought >= int(it["daily"]):
		return "soldout"
	if bag_count(id) >= SHOP_BAG_CAP:
		return "bagfull"
	var price := int(round(float(it["price"]) * (1.0 + SHOP_PRICE_STEP * float(bought))))
	if stardust() < price:
		return "poor"
	data["stardust"] = int(data["stardust"]) - price
	var bag: Dictionary = data.get("bag", {})
	bag[id] = int(bag.get(id, 0)) + 1
	data["bag"] = bag
	counts[id] = bought + 1
	data["shop"] = {"day": shop_day_number(unix_t), "n": counts}
	save_profile()
	return ""

## ------------------------------------------------------------------
## Cycle 18: the bring-in consumer (the Lab 'bag' row's missing
## half). The bundle: the region screen lists the bag with the
## hint "hasta {n} · se gastan al empezar" (main @1880775) —
## up to Dn(lab) = 2 + lab.bag items may be toggled on, and
## starting the run SPENDS them (the ticket code decrements
## profile.bag per boost, main @1580295). applyBoosts
## (@1444306) is mirrored in World._apply_boosts.
## ------------------------------------------------------------------

static func bag_slots() -> int:
	return 2 + lab_level("bag")

## Spend one copy of a bag item at run start. Returns false
## (and spends nothing) when the bag holds none.
static func bag_consume(id: String) -> bool:
	load_profile()
	var bag: Dictionary = data.get("bag", {})
	var n := int(bag.get(id, 0))
	if n <= 0:
		return false
	if n == 1:
		bag.erase(id)
	else:
		bag[id] = n - 1
	data["bag"] = bag
	save_profile()
	return true

## ------------------------------------------------------------------
## Archive (cycle 19; bundle TA @1571588, meta.archiveItem
## @1578563, capacity fe @ news-BfmMIm3P 68516, lab row
## `archive` @ news 66352, UI @1902048, presets UP/VP
## @1765590/@1765401). REVERSED VERDICT: a first mining pass
## read this as dead developer code; a second pass with
## byte evidence showed a live player feature — itemsOff
## is a profile ARRAY of item keys the player shelves so
## they stop rolling (chest roll Gx @1074187 and shop stock
## built from it filter through itemInPool @1577629 /
## Ie @ news 68516). Capacity = 5 per level of the archive
## lab row (max 4 -> 20; level 0 = locked). Cycle 21: the
## catalogue is the bundle's real item-def set (126 keys,
## assets/data/items.json) — the vitamin-pool mapping it
## replaced through C20 is retired (DIFF §21). Stale
## vitamin keys in an old items_off list never match a
## roll and stay removable.
## ------------------------------------------------------------------

static func archive_capacity() -> int:
	return 5 * lab_level("archive")

static func archived_items() -> Array:
	load_profile()
	return (data.get("items_off", []) as Array).duplicate()

static func is_archived(key: String) -> bool:
	load_profile()
	return (data.get("items_off", []) as Array).has(key)

## Ie: a key stays in the roll pool iff it is not archived.
static func item_in_pool(key: String) -> bool:
	return not is_archived(key)

## TA: archive (off=true) / unarchive (off=false). False on
## an unknown key, on already being in the target state, or
## on a full archive. No per-use cost, no delete.
static func archive_item(key: String, off: bool) -> bool:
	load_profile()
	# Cycle 21: archiving validates against the item defs;
	# unarchiving only needs list membership (stale keys
	# from the vitamin era stay removable).
	if off and GameData.item_def(key).is_empty():
		return false
	var off_list: Array = data.get("items_off", [])
	if off:
		if off_list.has(key) or off_list.size() >= archive_capacity():
			return false
		off_list.append(key)
	else:
		if not off_list.has(key):
			return false
		off_list.erase(key)
	data["items_off"] = off_list
	save_profile()
	return true

## Archive presets: up to 3 named snapshots of the archived
## set (the bundle keeps them in localStorage beside the
## profile; ours is a single local store, so they live in
## the profile). Applying one unarchives everything not in
## it and archives everything in it, and returns how many
## keys did not fit (VP's miss count); -1 on a bad index.
const ARCHIVE_PRESET_MAX := 3

static func archive_presets() -> Array:
	load_profile()
	return (data.get("archive_presets", []) as Array).duplicate()

static func archive_preset_active() -> int:
	load_profile()
	return int(data.get("archive_preset_active", -1))

static func archive_preset_save(preset_name: String) -> bool:
	load_profile()
	var presets: Array = data.get("archive_presets", [])
	if presets.size() >= ARCHIVE_PRESET_MAX:
		return false
	presets.append({"name": preset_name, "keys": archived_items()})
	data["archive_presets"] = presets
	save_profile()
	return true

static func archive_preset_delete(idx: int) -> void:
	load_profile()
	var presets: Array = data.get("archive_presets", [])
	if idx < 0 or idx >= presets.size():
		return
	presets.remove_at(idx)
	data["archive_presets"] = presets
	if archive_preset_active() == idx:
		data["archive_preset_active"] = -1
	save_profile()

static func archive_preset_apply(idx: int) -> int:
	load_profile()
	var presets: Array = data.get("archive_presets", [])
	if idx < 0 or idx >= presets.size():
		return -1
	var keys: Array = (presets[idx] as Dictionary).get("keys", [])
	for k in archived_items():
		if not keys.has(k):
			archive_item(String(k), false)
	var missed := 0
	for k in keys:
		if not is_archived(String(k)) and not archive_item(String(k), true):
			missed += 1
	data["archive_preset_active"] = idx
	save_profile()
	return missed

## Shiny collection (bundle profile.shinies): species keys of
## shiny encounters captured, in capture order.
static func record_shiny(species_key: String) -> void:
	load_profile()
	var sh: Array = data.get("shinies", [])
	if not sh.has(species_key):
		sh.append(species_key)
		data["shinies"] = sh
		# Cycle 20: crossing the ladder's top rung RECORDS the
		# shiny-ally unlock (shinyBond @1579133: from 15 unique
		# shiny species the shiny ally joins at Bond 2).
		if sh.size() >= 15:
			data["shiny_bond"] = true
		save_profile()

static func has_shiny(species_key: String) -> bool:
	load_profile()
	return (data.get("shinies", []) as Array).has(species_key)

static func shiny_count() -> int:
	load_profile()
	return (data.get("shinies", []) as Array).size()

## Cycle 20 (DIFF §7 correction): Be(count) is a PERK LADDER
## over ladder array lt (data chunk @84375) on n UNIQUE
## shiny species — NOT the gold factor cycle 19 shipped
## (that factor does not exist in the bundle; wB has no
## shiny consumer). Consumers (main chunk): labStats
## @1578843 (the stat rungs, summed into the permanent stat
## block), hasShinyCharm @1579006, shinyRate @1579031,
## shinyFlee @1579088, shinyBond @1579133.
##   n=2 -> +3 Luck (all runs)     n=4 -> +4% XP
##   n=6 -> Shiny Charm            n=10 -> +3% damage
##   n=15 -> shiny ally unlocks at Bond 2
static func shiny_luck_bonus() -> float:
	return 3.0 if shiny_count() >= 2 else 0.0

## Cycle 20.1 (audit N10): the bundle's labStats ADDS the
## rungs into the stat block (e[stat] = (e[stat] ?? 0) +
## t.add, main @1578843): xpGain +0.04 at n>=4, damage
## +0.03 at n>=10. They are additive bonuses, NOT the
## x1.04 / x1.03 multipliers cycle 20 shipped.
static func shiny_xp_bonus() -> float:
	return 0.04 if shiny_count() >= 4 else 0.0

static func has_shiny_charm() -> bool:
	return shiny_count() >= 6

## shinyRate @1579031: every shiny probability x1.5 with
## the Shiny Charm.
static func shiny_rate() -> float:
	return 1.5 if has_shiny_charm() else 1.0

## shinyFlee @1579088: the encounter flee clock — 120 s,
## 150 s with the Shiny Charm.
static func shiny_flee_time() -> float:
	return 150.0 if has_shiny_charm() else 120.0

static func shiny_damage_bonus() -> float:
	return 0.03 if shiny_count() >= 10 else 0.0

## shinyBond @1579133: from n = 15 the shiny ally unlocks
## at Bond 2. record_shiny() persists the unlock when the
## rung is crossed; the count arm covers profiles that
## reached 15 before the flag existed. (The ally swap
## modal itself is staged tail — DIFF cycle 20.)
static func shiny_bond_unlocked() -> bool:
	load_profile()
	return bool(data.get("shiny_bond", false)) or shiny_count() >= 15

## Family ids (the GameData family field) with at least one
## shiny species recorded — the spawn pick prefers families
## NOT in this set (spawnShiny @1051777).
static func shiny_families() -> Dictionary:
	load_profile()
	var fams: Dictionary = {}
	for k in (data.get("shinies", []) as Array):
		fams[int(GameData.species(String(k)).get("family", 0))] = true
	return fams

## Account section: full progress wipe (the bundle's account
## tab danger ops run through a two-step confirm; the caller
## owns the confirm, this owns the wipe).
static func reset_all() -> void:
	_loaded = true
	data = {"stardust": 0, "totalStardust": 0, "league": [], "captured": {},
		"seen": [], "lab": {}, "counters": {}, "species_played": [],
		"settings": {}, "bag": {}, "shinies": [], "shiny_bond": false, "items_off": [], "biomes": {"forest":0},
		"archive_presets": [], "archive_preset_active": -1,
		"version": PROFILE_VERSION}
	save_profile()

# C23 pack §1.2: stored clear record; chain unlock is a separate reader.
const BIOME_ORDER := ["forest", "graveyard", "desert", "volcano"]

static func biome_tier(biome: String) -> int:
	load_profile()
	return int(data.get("biomes", {}).get(biome, -1))

static func biome_unlocked(biome: String) -> bool:
	var i := BIOME_ORDER.find(biome)
	return biome_tier(biome) >= 0 or (i > 0 and biome_tier(BIOME_ORDER[i-1]) >= 1)

static func biome_tier_cap(biome: String) -> int:
	return mini(2, maxi(0, biome_tier(biome)))

static func record_biome_clear(biome: String, tier: int) -> void:
	load_profile()
	if not (data.get("biomes") is Dictionary):
		data["biomes"] = {}
	data["biomes"][biome] = maxi(biome_tier(biome), clampi(tier, 0, 2) + 1)
	save_profile()
