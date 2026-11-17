class_name GameData
extends RefCounted
## Data layer over the original's own runtime JSON tables (dev-placeholder
## copies in assets/data/, mirrored from pokebonk.com/data/*.json — see
## reference/orig_assets/INVENTORY.md). Every mechanics number in
## player/enemy/world derives from these tables through the formulas in
## ~/workspace/pokebonk-rea/MECHANICS.md (cited per system in DIFF.md).
## sprites.json stays in reference/ only: species heights are already
## encoded in ModelRig from its frame metrics (DIFF §3).

const DATA_DIR := "res://assets/data/"

## Starter kits (MECHANICS §3, bundle roster data): kit[0] is the
## signature move; the rest enter through the level-up draft.
const KITS := {
	"bulbasaur": ["vine-whip", "razor-leaf", "sleep-powder", "solar-beam"],
	"charmander": ["ember", "fire-spin", "flamethrower", "fire-blast"],
	"squirtle": ["water-gun", "bubble", "rapid-spin", "hydro-pump"],
}

## Vitamins (MECHANICS §2.4): per-level effect, multiplied by the
## option's rarity pe when drafted. `acc` names the player accumulator
## the value feeds (percent points unless the key is flat: iron/hp/regen/luck).
const VITAMINS := {
	"protein": {"label": "蛋白质", "acc": "phys_pct", "per": 10.0, "fmt": "物理伤害 +%s%%"},
	"calcium": {"label": "钙片", "acc": "spec_pct", "per": 10.0, "fmt": "特殊伤害 +%s%%"},
	"iron": {"label": "钢铁", "acc": "armor_flat", "per": 5.0, "fmt": "护甲 +%s"},
	"carbos": {"label": "速度剂", "acc": "speed_pct", "per": 7.0, "fmt": "移速 +%s%%"},
	"hp-up": {"label": "HP 增强剂", "acc": "hp_flat", "per": 18.0, "fmt": "最大 HP +%s"},
	"ether": {"label": "以太", "acc": "atkspd_pct", "per": 8.0, "fmt": "攻速 +%s%%"},
	"dire-hit": {"label": "要害镜", "acc": "crit_pct", "per": 5.0, "fmt": "暴击率 +%s%%"},
	"exp-candy": {"label": "经验糖", "acc": "xp_pct", "per": 10.0, "fmt": "经验 +%s%%"},
	"nugget": {"label": "金块", "acc": "gold_pct", "per": 15.0, "fmt": "金币 +%s%%"},
	"super-potion": {"label": "超级伤药", "acc": "regen_flat", "per": 0.7, "fmt": "再生 +%s/s"},
	"star-piece": {"label": "星星碎片", "acc": "luck_flat", "per": 10.0, "fmt": "幸运 +%s"},
}
const VIT_CAP := 10  # §2.3 vitCap (the bundle's getter adds +2
	# while the player holds max-ether — player.vit_cap(), C21)
const MOVE_CAP := 8  # §2.3 moveCap (the bundle's getter adds +2
	# while the player holds tm-case — player.move_cap(), C21)

## Cycle 21: the bundle's item definitions (data chunk array
## `f`, 126 rollable defs extracted verbatim to
## assets/data/items.json: rarity / max / tags / mods; the
## display catalogue's remaining 25 keys — evolution stones,
## protein-class vitamins — carry no rollable def and are
## not items in the bundle's Gx sense). The 18 type charms
## head the array via the ae() generator (mods damage x1.03
## + a type: tag; the tag's +30% type damage is applied in
## recompute as typeBoost, bundle @812155 region).
const CHARM_TYPES := {
	"charcoal": "fire", "mystic-water": "water",
	"miracle-seed": "grass", "magnet": "electric",
	"never-melt-ice": "ice", "black-belt": "fighting",
	"poison-barb": "poison", "soft-sand": "ground",
	"sharp-beak": "flying", "twisted-spoon": "psychic",
	"silver-powder": "bug", "hard-stone": "rock",
	"spell-tag": "ghost", "dragon-fang": "dragon",
	"black-glasses": "dark", "metal-coat": "steel",
	"silk-scarf": "normal", "fairy-feather": "fairy",
}
static var _items: Dictionary = {}  # item key -> def (C21)

## Option rarity multipliers (§2.3: pe table).
const RARITY_PE := [1.0, 1.2, 1.45, 1.75, 2.1]
const RARITY_NAMES := ["普通", "优秀", "稀有", "史诗", "传说"]

## Move archetypes: the bundle's per-move archetype table was not
## extracted (MECHANICS §2.5), so damaging moves resolve by class with
## a hand table for the starters' kits/learnsets (INFERRED, DIFF §6).
const ARCH_STRIKE := ["tackle", "scratch", "vine-whip", "power-whip", "take-down", "rapid-spin", "slash", "fire-fang", "bite", "aqua-tail", "wave-crash", "seed-bomb"]
const ARCH_NOVA := ["sleep-powder", "poison-powder"]
const ARCH_BEAM := ["solar-beam"]
## Move cooldowns by archetype (seconds). Strike 0.8 is CONFIRMED for
## Vine Whip (League screen); the rest are INFERRED at the same scale.
const ARCH_CD := {"strike": 0.8, "projectile": 0.85, "nova": 5.0, "beam": 2.6}
const ARCH_RANGE := {"strike": 3.3, "projectile": 16.0, "nova": 6.0, "beam": 13.0}

static var _by_key: Dictionary = {}
static var _by_id: Dictionary = {}
static var _moves_key: Dictionary = {}
static var _moves_id: Dictionary = {}
static var _learn: Dictionary = {}  # species key -> Array of [move_key, level]
static var _type_names: Array = []
static var _chart: Array = []
static var _loaded := false
static var _roster: Dictionary = {}  # roster id (String) -> entry

## Cycle 9: the bundle's League roster (news chunk arrays j/jn/Mn/Nn/
## Pn/Fn, byte offsets 99430-118600, extracted verbatim to
## assets/data/roster.json): 79 family entries {passive, kit[4],
## rank, challenge parts}. Kits and passives for EVERY species come
## from here — cycle 8 only had the three starters' kits hardcoded
## and no passives at all (audit §5).
static func _load_roster() -> void:
	if not _roster.is_empty():
		return
	var f := FileAccess.open(DATA_DIR + "roster.json", FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open roster.json")
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_roster = v

static func roster_entry(roster_id: int) -> Dictionary:
	_load_roster()
	return _roster.get(str(roster_id), {})

## The roster entry governing a species: the entry whose id IS the
## species (base forms), else the entry of its family (evolutions).
static func roster_for_species(key: String) -> Dictionary:
	_load()
	var sp: Dictionary = _by_key.get(key, {})
	if sp.is_empty():
		return {}
	var e := roster_entry(int(sp.get("id", -1)))
	if not e.is_empty():
		return e
	return roster_entry(int(sp.get("family", -1)))

static func passive_for_species(key: String) -> String:
	var e := roster_for_species(key)
	return String(e.get("passive", ""))

static var _abilities: Dictionary = {}
static var _abilities_loaded := false

## Passive ability definitions (assets/data/abilities.json, extracted
## from the bundle's ability table — name/desc/mods per passive;
## stat mods are applied by Player.recalc).
static func passive_mods(passive_id: String) -> Array:
	if not _abilities_loaded:
		_abilities_loaded = true
		var f := FileAccess.open(DATA_DIR + "abilities.json", FileAccess.READ)
		if f != null:
			var v = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_abilities = v
	var e: Dictionary = _abilities.get(passive_id, {})
	return e.get("mods", [])

## The full passive entry {name, desc, mods, hooks} (cycle 18:
## the loadout hero detail shows name + desc).
static func passive_entry(passive_id: String) -> Dictionary:
	passive_mods(passive_id)  # ensures the table is loaded
	return _abilities.get(passive_id, {})

## The passive's hook fields (lowHp / typeBoost / dmgTaken /
## fullHp / contact / tick...) from the same table.
static func passive_hooks(passive_id: String) -> Dictionary:
	passive_mods(passive_id)  # ensures the table is loaded
	var e: Dictionary = _abilities.get(passive_id, {})
	return e.get("hooks", {})

## The roster id governing a species (its own dex id when a base
## form, else its family id) — 0 when it has no roster entry.
static func roster_id_for_species(key: String) -> int:
	_load()
	_load_roster()
	var sp: Dictionary = _by_key.get(key, {})
	if sp.is_empty():
		return 0
	if not roster_entry(int(sp.get("id", -1))).is_empty():
		return int(sp["id"])
	if not roster_entry(int(sp.get("family", -1))).is_empty():
		return int(sp["family"])
	return 0

## Species keys the League encounter pool can draw (cycle 9, audit
## §5): for every roster entry, the modelled species whose dex id IS
## the entry id (base forms), falling back to the lowest-id modelled
## member of that family (entry 32 -> nidoking). Zone-independent —
## the original's pool is global (leagueReady().filter(e=>e!==150),
## bundle @1049619); dex 150 is excluded by the same filter (and is
## not modelled anyway).
static func roster_species_keys() -> Array:
	_load()
	_load_roster()
	var out: Array = []
	for sid in _roster.keys():
		var rid := int(sid)
		if rid == 150:
			continue
		var sp: Dictionary = _by_id.get(rid, {})
		if not sp.is_empty() and ModelRig.SPECIES.has(String(sp.get("key", ""))):
			out.append(String(sp["key"]))
			continue
		var fam_key := species_key_for_family(rid)
		if fam_key != "" and not out.has(fam_key):
			out.append(fam_key)
	return out

## Ally attack status by the ally's first type (bundle J_ table,
## @721249), mapped onto the statuses our engine carries. Types
## whose J_ status has no engine counterpart (wet/root/curse/
## healblock/knock/charm) yield "" — logged in DIFF cycle 9.
const ALLY_STATUS := {
	"fire": "burn", "electric": "paralysis", "ice": "freeze",
	"poison": "poison", "psychic": "confusion", "rock": "stun",
	"ground": "stun", "bug": "poison",
	# Cycle 14: the bundle's J_ type->status map (@721176) sends
	# water -> wet; the wet layer exists now (parallel timer).
	"water": "wet",
}

static func ally_status_for(type_: String) -> String:
	return String(ALLY_STATUS.get(type_, ""))

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var pk: Array = _read_json(DATA_DIR + "pokemon.json")
	for p in pk:
		_by_key[String(p["key"])] = p
		_by_id[int(p["id"])] = p
	var mv: Array = _read_json(DATA_DIR + "moves.json")
	for m in mv:
		_moves_key[String(m["key"])] = m
		_moves_id[int(m["id"])] = m
	var ls: Dictionary = _read_json_dict(DATA_DIR + "learnsets.json")
	for sid in ls.keys():
		var sp: Dictionary = _by_id.get(int(sid), {})
		if sp.is_empty():
			continue
		var arr: Array = []
		for pair in ls[sid]:
			var mm: Dictionary = _moves_id.get(int(pair[0]), {})
			if not mm.is_empty():
				arr.append([String(mm["key"]), int(pair[1])])
		_learn[String(sp["key"])] = arr
	var tj: Dictionary = _read_json_dict(DATA_DIR + "types.json")
	_type_names = tj.get("types", [])
	_chart = tj.get("chart", [])
	_items = _read_json_dict(DATA_DIR + "items.json")

static func item_def(key: String) -> Dictionary:
	_load()
	return _items.get(key, {})

static func item_keys() -> Array:
	_load()
	return _items.keys()

static func item_max(key: String) -> int:
	var d := item_def(key)
	return int(d.get("max", 10)) if not d.is_empty() else 0

static func item_rarity(key: String) -> int:
	var d := item_def(key)
	return int(d.get("rarity", 0)) if not d.is_empty() else 0

static func _read_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open " + path)
		return []
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Array else []

static func _read_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open " + path)
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

static func species(key: String) -> Dictionary:
	_load()
	return _by_key.get(key, {})

static func species_by_id(id: int) -> Dictionary:
	_load()
	return _by_id.get(id, {})

static func move(key: String) -> Dictionary:
	_load()
	return _moves_key.get(key, {})

## Cycle 8: the playable species key for a League family id — the
## base form (id == family) when we model it, else the lowest-id
## modelled member of that family (e.g. family 240 = Magby's line,
## whose modelled member is Magmar 126).
static func species_key_for_family(family_id: int) -> String:
	_load()
	var best := ""
	var best_id := 1 << 30
	for key in _by_key.keys():
		var sp: Dictionary = _by_key[key]
		if int(sp.get("family", -1)) != family_id:
			continue
		if not ModelRig.SPECIES.has(key):
			continue
		var sid := int(sp.get("id", 0))
		if sid == family_id:
			return key
		if sid < best_id:
			best_id = sid
			best = key
	return best

static func learnset(key: String) -> Array:
	_load()
	return _learn.get(key, [])

static func kit(key: String) -> Array:
	# Cycle 9: kits come from the roster entry for the species'
	# family (all 79 entries carry kit[4]); the hardcoded starter
	# table remains only as a fallback if roster data is missing.
	var e := roster_for_species(key)
	if not e.is_empty() and (e.get("kit", []) as Array).size() > 0:
		return e["kit"]
	return KITS.get(key, [])

## The species this one evolves into (evoFrom == this species' id), or {}.
static func evo_target(key: String) -> Dictionary:
	_load()
	var me: Dictionary = _by_key.get(key, {})
	if me.is_empty():
		return {}
	for p in _by_key.values():
		if p.get("evoFrom") != null and int(p["evoFrom"]) == int(me["id"]):
			return p
	return {}

## Evolution level for the current form (MECHANICS §1.2 runEvolution):
##   a = target.evoLevel ?? (cur.evoStage == 0 ? 20 : 34)
##   target can evolve further -> clamp(round(8 + a), 16, 30)
##   target is final form      -> clamp(round(22 + a*0.6), 36, 50)
## Returns -1 when there is no evolution.
static func evo_level_for(key: String) -> int:
	_load()
	var me: Dictionary = _by_key.get(key, {})
	var tgt: Dictionary = evo_target(key)
	if me.is_empty() or tgt.is_empty():
		return -1
	# Cycle 9: no evolution into a species we don't model (no GLB) —
	# Player.evolve carries the same guard.
	if not ModelRig.SPECIES.has(String(tgt.get("key", ""))):
		return -1
	var a := 20.0 if int(me["evoStage"]) == 0 else 34.0
	if tgt.get("evoLevel") != null:
		a = float(tgt["evoLevel"])
	if not evo_target(String(tgt["key"])).is_empty():
		return clampi(int(round(8.0 + a)), 16, 30)
	return clampi(int(round(22.0 + a * 0.6)), 36, 50)

## Type effectiveness of an attacking move type against a defender's
## types (types.json chart, attacker row x defender columns).
static func type_mult(move_type: String, def_types: Array) -> float:
	_load()
	var ai := _type_names.find(move_type)
	if ai < 0 or _chart.is_empty():
		return 1.0
	var out := 1.0
	for t in def_types:
		var di := _type_names.find(String(t))
		if di >= 0:
			out *= float(_chart[ai][di])
	return out

static func archetype(move_key: String) -> String:
	if ARCH_STRIKE.has(move_key):
		return "strike"
	if ARCH_NOVA.has(move_key):
		return "nova"
	if ARCH_BEAM.has(move_key):
		return "beam"
	var m: Dictionary = move(move_key)
	if String(m.get("cls", "")) == "physical":
		return "strike"
	return "projectile"

## A learnset/kit move may enter the draft when it deals damage or
## carries an implemented ailment (sleep/poison novas).
static func move_is_draftable(move_key: String) -> bool:
	var m: Dictionary = move(move_key)
	if m.is_empty():
		return false
	if m.get("power") != null and int(m["power"]) > 0:
		return true
	return ARCH_NOVA.has(move_key)

## Rarity roll for one draft option (MECHANICS §2.3 Bx):
##   a = luck/100; o = level + luck/8 + (stage-1)*12
##   w = [70/(1+a), 24*(1+.5a), 5*(1+a)^2*s(3,10), .9*(1+a)^3*s(8,18),
##        .12*(1+a)^4*s(14,26)], s(x,y) = clamp((o-x)/(y-x), 0, 1)
static func roll_rarity(level: int, luck: float, stage: int, rng: RandomNumberGenerator) -> int:
	var a := luck / 100.0
	var o := float(level) + luck / 8.0 + float(stage - 1) * 12.0
	var s := func(x: float, y: float) -> float: return clampf((o - x) / (y - x), 0.0, 1.0)
	var w := [
		70.0 / (1.0 + a),
		24.0 * (1.0 + 0.5 * a),
		5.0 * pow(1.0 + a, 2.0) * s.call(3.0, 10.0),
		0.9 * pow(1.0 + a, 3.0) * s.call(8.0, 18.0),
		0.12 * pow(1.0 + a, 4.0) * s.call(14.0, 26.0),
	]
	var total := 0.0
	for x in w:
		total += x
	var r := rng.randf() * total
	for i in range(w.size()):
		r -= w[i]
		if r <= 0.0:
			return i
	return 0
