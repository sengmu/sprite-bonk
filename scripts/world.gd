extends Node3D
## SpriteBonk 3D — world rebuilt against the original's mined parameters:
## 360x360 heightfield world, play clamp +/-168 (no walls), Ld ground palette,
## fog #bfe3ff 40-160, sky #5aa8ff -> #d8f0ff, sun #fff1d6 from (60,120,40),
## camera FOV 70 / pitch 0.45 / dist 9 / focus +1.5 / lookAt +1.8 (see DIFF.md).

const UiBadge = preload("res://scripts/ui_badge.gd")
const Fossils = preload("res://scripts/fossils.gd")

const BOUND := 168.0
const ZONE_TIME := 600.0
const ALTAR_XZ := Vector2(0, -30)
# UI-mobile P1.1: the menu's controls line, keyboard and
# touch forms (the touch form omits camera dragging — plan
# §B4 P1.1; two-thumb rotation is pending device check).
const MENU_HINT_KBD := "WASD 移动 · 自动攻击 · Shift 滑铲（空中=俯冲） · 空格跳跃 · 按住鼠标拖动转镜头 · 滚轮缩放\n到北边祭坛按 E 召唤守护者，击败它开启传送门"
const MENU_HINT_TOUCH := "左半屏拖动移动 · 自动攻击 · 右下：互动 · ↑ 跳跃 · 风 冲刺（空中=俯冲） · 必 大招 · 点小地图开大地图\n到北边祭坛点互动召唤守护者，击败它开启传送门"
const MENU_HINT_COMPACT := "拖动移动 · 自动攻击 · 点击互动"
const SPAWN_XZ := Vector2(0, 6)
const GUARDIAN_TRIO := ["scyther", "pinsir", "nidoking"]
const GUARDIAN_HP_MULT := 25.0  # legacy; cycle 7 uses the live DPS budget below
const ESCORT_HP_MULT := 4.5     # elite flag multiplier (bundle)

# Cycle 7 stage tables (MECHANICS §4.2/§4.5): hpCurve base + quadratic
# rate per stage, damage stage factor, guardian budget seconds
# (xb.guardian [40,50,60]; stage-4 sanctuary legendary = 60) and
# BOSS_ZONE_HP [0.8, 0.55, 0.5, 0.5]. Guardian HP = player DPS x
# seconds x BOSS_ZONE_HP (the original's DPS-budget rule).
const STAGE_HP_BASE := [1.0, 5.5, 13.0, 20.0]
const STAGE_HP_R := [0.15, 0.07, 0.05, 0.05]
const STAGE_DMG := [1.0, 2.0, 3.1, 3.4]
const GUARDIAN_SECS := [40.0, 50.0, 60.0, 60.0]
const BOSS_ZONE_HP := [0.8, 0.55, 0.5, 0.5]
# Cycle 14: Eb damage-cap divisors wb.guardian [25, 30, 35]
# (@995239) — capRate = guardian maxHp / (divisor x roar mult).
const BOSS_CAP_DIV := [25.0, 30.0, 35.0]
# Cycle 14: ZC altar tier table (@~1235800) — color / unown count /
# charge seconds / radius / drain seconds / min offer tier /
# offers / picks / wave count / wave minutes floor / seal seconds.
# Cycle 15: tier 4 (comet) appended — event-spawned in the
# bundle (spawnComet @1245186), never populated.
const ALTAR_CFG := [
	{"color": Color8(46, 200, 224), "unown": 1, "charge": 8.0, "r": 6.0, "drain": 6.0, "min": 0, "offers": 3, "picks": 1, "wave": 0, "floor": 0.0, "seal": 0.0},
	{"color": Color8(90, 216, 122), "unown": 2, "charge": 14.0, "r": 5.5, "drain": 5.0, "min": 1, "offers": 3, "picks": 1, "wave": 0, "floor": 0.0, "seal": 0.0},
	{"color": Color8(192, 112, 255), "unown": 3, "charge": 22.0, "r": 5.0, "drain": 4.0, "min": 2, "offers": 3, "picks": 1, "wave": 4, "floor": 3.0, "seal": 0.0},
	{"color": Color8(255, 210, 58), "unown": 5, "charge": 35.0, "r": 4.5, "drain": 3.0, "min": 3, "offers": 4, "picks": 2, "wave": 6, "floor": 5.0, "seal": 90.0},
	{"color": Color8(74, 168, 255), "unown": 0, "charge": 10.0, "r": 6.5, "drain": 3.0, "min": 1, "offers": 3, "picks": 1, "wave": 2, "floor": 0.0, "seal": 0.0},
]
const ALTAR_NAMES := ["古石祭坛", "稀有古石祭坛", "史诗古石祭坛", "黄金古石祭坛", "彗星祭坛"]
# Cycle 14: the 12 blessing generators (Xx @1075554) — label
# numbers round like the bundle's; the MODS use the exact power.
# mode mul -> mod {mul: 1 + per*e}; mode add -> {add: per*e};
# "pct" displays round(per*e*100) for an add (critChance).
const BLESSING_PE := [1.0, 1.2, 1.45, 1.75, 2.1]
const BLESSING_DEFS := [
	{"stat": "damage", "mode": "mul", "per": 0.12, "label": "+%d%% 伤害"},
	{"stat": "attackSpeed", "mode": "mul", "per": 0.10, "label": "+%d%% 攻击速度"},
	{"stat": "maxHp", "mode": "add", "per": 20.0, "label": "+%d 最大生命"},
	{"stat": "moveSpeed", "mode": "mul", "per": 0.08, "label": "+%d%% 移动速度"},
	{"stat": "critChance", "mode": "add", "per": 0.06, "label": "+%d%% 暴击率", "pct": true},
	{"stat": "area", "mode": "mul", "per": 0.12, "label": "+%d%% 范围"},
	{"stat": "xpGain", "mode": "mul", "per": 0.15, "label": "+%d%% 经验获取"},
	{"stat": "regen", "mode": "add", "per": 0.8, "label": "+%s 回复/秒", "dec": true},
	{"stat": "armor", "mode": "add", "per": 8.0, "label": "+%d 护甲"},
	{"stat": "luck", "mode": "add", "per": 15.0, "label": "+%d 幸运"},
	{"stat": "duration", "mode": "mul", "per": 0.2, "label": "+%d%% 状态持续"},
	{"stat": "statusChance", "mode": "mul", "per": 0.2, "label": "+%d%% 状态概率"},
]
const ALPHA_TIMES := [150.0, 330.0, 480.0]  # §4.3 classic timeline

## Four zones chained by portals (task mapping of the captured biome
## sets). Zone 1 guardians CONFIRMED (§4.5 forest [123,127,34]); zone 3
## CONFIRMED (§4.5 desert [28,105,149]). Cycle 21 de-INFER: the bundle's
## biome table (data chunk) names zone 2 `graveyard` / "Torre Lavanda"
## with bosses [94, 110, 97] and zone 4 `volcano` / "Isla Volcán" with
## bosses [126, 78, 6] — the cn/en names and trios below are those
## values (the tiles ids already matched: graveyard / volcano).
## Palettes: vertex tints around each biome's own captured tiles;
## grass gains are measured (forest's calibrated gain x
## forest-tile-avg / zone-tile-avg per channel).
const ZONES := [
	{"cn": "青苔林", "en": "Viridian Forest", "tiles": "forest",
		"pool": ["rattata", "pidgey", "sandshrew", "geodude"], "weights": [0.34, 0.26, 0.24, 0.16],
		"guardians": ["scyther", "pinsir", "nidoking"],
		"gain": Vector3(0.09, 0.63, 0.50), "fog": Color(0.749, 0.89, 1.0),
		"pal": {"moss_a": Color(0.059, 0.343, 0.042), "moss_b": Color(0.039, 0.261, 0.034),
			"earth_a": Color(0.30, 0.24, 0.12), "earth_b": Color(0.36, 0.26, 0.17),
			"light": Color(0.45, 0.45, 0.18), "earth_dark": Color(0.22, 0.15, 0.12), "cliff": Color(0.50, 0.42, 0.24)},
		"leaf": [Color(0.15, 0.34, 0.09), Color(0.19, 0.42, 0.11), Color(0.23, 0.48, 0.12)],
		# Cycle 11 (bundle biome table, news block): relief/water/scatter/deco.
		"levels": 5, "massifs": 2, "prop_density": 1.0, "water": "ponds",
		"water_col": Color(0.227, 0.69, 1.0, 0.72),
		"scatter": ["tree", "tree", "pine", "bush", "rock", "mushroom"],
		"deco": [0, 1, 2, 3, 0, 1, 4, 5, 6, 10, 11, 12, 7],
		"deco_top": Color(0.525, 0.847, 0.384), "deco_accent": Color(1.0, 0.478, 0.659),
		"scol": {"leaf": Color(0.243, 0.604, 0.267), "leaf_alt": Color(0.31, 0.68, 0.34),
			"bark": Color(0.478, 0.322, 0.212), "rock": Color(0.604, 0.588, 0.557),
			"cap": Color(0.91, 0.286, 0.227), "stem": Color(0.941, 0.886, 0.784)},
		# Cycle 12: biome weather candidates (news chunk @31433).
		"weather": ["clear", "clear", "rain"]},
	{"cn": "雾钟塔", "en": "Lavender Tower", "tiles": "graveyard",
		"pool": ["gastly", "zubat", "cubone", "geodude"], "weights": [0.3, 0.26, 0.24, 0.2],
		"guardians": ["gengar", "weezing", "hypno"],
		"gain": Vector3(0.65, 0.65, 0.65), "fog": Color(0.72, 0.74, 0.85),
		"pal": {"moss_a": Color(0.10, 0.10, 0.17), "moss_b": Color(0.07, 0.07, 0.12),
			"earth_a": Color(0.20, 0.18, 0.22), "earth_b": Color(0.24, 0.22, 0.27),
			"light": Color(0.30, 0.30, 0.38), "earth_dark": Color(0.12, 0.11, 0.15), "cliff": Color(0.33, 0.31, 0.38)},
		"leaf": [Color(0.13, 0.15, 0.22), Color(0.17, 0.18, 0.27), Color(0.21, 0.22, 0.33)],
		"levels": 4, "massifs": 0, "prop_density": 0.9, "water": "plane",
		"water_col": Color(0.30, 0.32, 0.42, 0.75),
		"scatter": ["grave", "grave", "deadtree", "pillar", "mushroom"],
		"deco": [0, 1, 9, 13, 6, 8, 2],
		"deco_top": Color(0.431, 0.557, 0.416), "deco_accent": Color(0.69, 0.478, 1.0),
		"scol": {"leaf": Color(0.29, 0.353, 0.282), "leaf_alt": Color(0.35, 0.42, 0.34),
			"bark": Color(0.29, 0.243, 0.227), "rock": Color(0.478, 0.455, 0.533),
			"cap": Color(0.604, 0.373, 0.973), "stem": Color(0.85, 0.83, 0.78)},
		# Cycle 12: biome weather candidates (news chunk @38798).
		"weather": ["fog", "clear", "rain"]},
	{"cn": "岩石沙漠", "en": "Rock Desert", "tiles": "desert",
		"pool": ["sandshrew", "diglett", "cubone", "rhyhorn"], "weights": [0.3, 0.24, 0.24, 0.22],
		"guardians": ["sandslash", "marowak", "dragonite"],
		"gain": Vector3(0.40, 0.40, 0.40), "fog": Color(0.98, 0.90, 0.75),
		"pal": {"moss_a": Color(0.42, 0.33, 0.16), "moss_b": Color(0.35, 0.26, 0.12),
			"earth_a": Color(0.38, 0.28, 0.14), "earth_b": Color(0.44, 0.34, 0.18),
			"light": Color(0.52, 0.42, 0.22), "earth_dark": Color(0.28, 0.20, 0.11), "cliff": Color(0.46, 0.36, 0.21)},
		"leaf": [Color(0.30, 0.34, 0.10), Color(0.36, 0.38, 0.12), Color(0.26, 0.30, 0.09)],
		"levels": 4, "massifs": 0, "prop_density": 0.7, "water": "none",
		"water_col": Color(0.3, 0.5, 0.7, 0.7),
		"scatter": ["cactus", "rock", "rock", "deadtree", "pillar"],
		"deco": [7, 13, 9, 7, 13, 3],
		"deco_top": Color(0.965, 0.855, 0.627), "deco_accent": Color(1.0, 0.604, 0.29),
		"scol": {"leaf": Color(0.35, 0.62, 0.30), "leaf_alt": Color(0.42,0.68,0.36),
			"bark": Color(0.604, 0.439, 0.282), "rock": Color(0.753, 0.525, 0.353),
			"cap": Color(0.9, 0.6, 0.3), "stem": Color(0.9, 0.85, 0.75)},
		# Cycle 12: biome weather candidates (news chunk @33298).
		"weather": ["clear", "sand", "sun"]},
	{"cn": "火山岛", "en": "Volcano Island", "tiles": "volcano",
		"pool": ["growlithe", "ponyta", "magmar", "rhyhorn"], "weights": [0.3, 0.26, 0.24, 0.2],
		"guardians": ["magmar", "rapidash", "charizard"],
		"gain": Vector3(0.75, 0.75, 0.75), "fog": Color(0.95, 0.80, 0.70),
		"pal": {"moss_a": Color(0.17, 0.105, 0.08), "moss_b": Color(0.115, 0.07, 0.06),
			"earth_a": Color(0.30, 0.15, 0.08), "earth_b": Color(0.36, 0.19, 0.10),
			"light": Color(0.50, 0.26, 0.11), "earth_dark": Color(0.16, 0.09, 0.07), "cliff": Color(0.32, 0.17, 0.11)},
		"leaf": [Color(0.30, 0.13, 0.08), Color(0.36, 0.17, 0.10), Color(0.26, 0.11, 0.07)],
		"levels": 4, "massifs": 0, "prop_density": 0.8, "water": "lava",
		"water_col": Color(1.0, 0.42, 0.10, 1.0),
		"scatter": ["lavarock", "rock", "deadtree", "crystal"],
		"deco": [14, 7, 13, 8, 14, 9],
		"deco_top": Color(0.431, 0.361, 0.329), "deco_accent": Color(1.0, 0.478, 0.165),
		"scol": {"leaf": Color(0.353, 0.416, 0.227), "leaf_alt": Color(0.42, 0.48, 0.28),
			"bark": Color(0.227, 0.165, 0.141), "rock": Color(0.29, 0.235, 0.22),
			"cap": Color(1.0, 0.478, 0.227), "stem": Color(0.6, 0.5, 0.45)},
		# Cycle 12: biome weather candidates (news chunk @39600).
		"weather": ["ash", "sun", "clear"]},
]

## HUD type chips (name + color) for the generic species panel.
const TYPE_HUD := {
	"normal": ["普通", Color(0.62, 0.62, 0.58)], "fire": ["火", Color(0.94, 0.5, 0.25)],
	"water": ["水", Color(0.3, 0.58, 0.9)], "grass": ["草", Color(0.48, 0.78, 0.35)],
	"electric": ["电", Color(0.95, 0.8, 0.25)], "ice": ["冰", Color(0.5, 0.8, 0.88)],
	"fighting": ["格斗", Color(0.8, 0.4, 0.3)], "poison": ["毒", Color(0.64, 0.42, 0.78)],
	"ground": ["地面", Color(0.8, 0.65, 0.35)], "flying": ["飞行", Color(0.55, 0.7, 0.95)],
	"psychic": ["超能", Color(0.95, 0.45, 0.65)], "bug": ["虫", Color(0.55, 0.75, 0.3)],
	"rock": ["岩石", Color(0.62, 0.54, 0.4)], "ghost": ["幽灵", Color(0.5, 0.45, 0.75)],
	"dragon": ["龙", Color(0.45, 0.4, 0.92)], "dark": ["恶", Color(0.4, 0.35, 0.35)],
	"steel": ["钢", Color(0.68, 0.7, 0.75)], "fairy": ["妖精", Color(0.95, 0.6, 0.75)],
}
## Chinese display names for the moves a run can draft.
const MOVE_ZH := {
	"tackle": "撞击", "scratch": "抓", "vine-whip": "藤鞭", "razor-leaf": "飞叶快刀",
	"sleep-powder": "催眠粉", "solar-beam": "阳光烈焰", "seed-bomb": "种子炸弹",
	"take-down": "猛撞", "power-whip": "强力鞭打", "poison-powder": "毒粉",
	"ember": "火花", "fire-spin": "火焰旋涡", "flamethrower": "喷射火焰",
	"fire-blast": "大字爆炎", "dragon-breath": "龙息", "fire-fang": "火焰牙",
	"slash": "劈开", "inferno": "炼狱", "flare-blitz": "闪焰冲锋",
	"water-gun": "水枪", "bubble": "泡沫", "rapid-spin": "高速旋转",
	"hydro-pump": "水炮", "bite": "咬住", "water-pulse": "水之波动",
	"aqua-tail": "水流尾", "wave-crash": "波涛冲锋",
}

# Ground palette: Ld values from the bundle's forest shader, rescaled x0.32
# for Godot's light units (calibrated against in-game samples #389243/#40a03d).
# Cycle 5: moss deepened (net x0.61 / x1.20 / x0.90 vs the cycle-2
# values) to compensate the detail-texture terms + grade so the sampled
# ground median lands on the original's #389243 (see DIFF cycle-5 log).
const MOSS_A := Color(0.059, 0.343, 0.042)
const MOSS_B := Color(0.039, 0.261, 0.034)
const EARTH_A := Color(0.30, 0.24, 0.12)
const EARTH_B := Color(0.36, 0.26, 0.17)
const LIGHT_C := Color(0.45, 0.45, 0.18)
const EARTH_DARK := Color(0.22, 0.15, 0.12)
const CLIFF_C := Color(0.50, 0.42, 0.24)  # sampled in-game cliff face, rescaled

const STARTER_HUD := {
	"bulbasaur": {"name": "妙蛙种子", "en": "Bulbasaur", "medal": Color(0.35, 0.71, 0.41), "glyph": "妙", "types": [["草", Color(0.48, 0.78, 0.35)], ["毒", Color(0.64, 0.42, 0.78)]], "evo": "› 24级成长", "move": "藤鞭", "ult": "Furious Roots"},
	"charmander": {"name": "小火龙", "en": "Charmander", "medal": Color(0.94, 0.54, 0.24), "glyph": "火", "types": [["火", Color(0.94, 0.5, 0.25)]], "evo": "› 成长未解锁", "move": "火花", "ult": "Rising Blaze"},
	"squirtle": {"name": "杰尼龟", "en": "Squirtle", "medal": Color(0.29, 0.56, 0.85), "glyph": "杰", "types": [["水", Color(0.3, 0.58, 0.9)]], "evo": "› 成长未解锁", "move": "水枪", "ult": "Shell Whirlpool"},
}

var state := "menu"  # menu / playing / guardian / portal / draft / victory / dead
var running := false
var player: Player
var guardian: Enemy
var kills := 0
var elapsed := 0.0
# Cycle 7 run/meta state.
var zone := 1
var gold := 0.0
var run_time := 0.0
var damage_dealt := 0.0
var bosses := 0
var captured := 0
var revive_used := false
var banished_keys: Array = []
var rerolls_left := 2
var skips_left := 2
var banishes_left := 1
var _pre_draft_state := "playing"
var _draft_options: Array = []
var _league_e: Enemy = null
var _league_spawn_at := 80.0
var _league_escape := 0.0
var _league_done := false
# Cycle 8: camera trauma (bundle shake() @1446581: trauma value,
# decay 2/s, offset = trauma^2 * 0.3 at ~26 Hz) and per-run event
# counts that merge into Profile's best_* lifetime counters at run
# end (burned / poisoned / slept applications, alphas defeated).
var trauma := 0.0
var run_counts := {}
var _run_alphas := 0
# Cycle 14 run state: Rhydon shrine roars (run-scoped, zy
# @~866030), the bossSpawned latch for the totem deny/labels,
# the electrocute reaction cooldown (global 0.25 s per key,
# reactions @733583), and the combat meter (B_ @720250) that
# budgets guardian HP.
var run_roars := 0
var boss_spawned := false
var _elec_t := -1.0
# Cycle 15 run state: reaction cooldown keys beyond electrocute
# (canReact @733151 — one global 0.25 s map), the comet event
# (updateComet — _E initial timer 75 s @1349051), generic
# delayed callbacks (bundle t.later), the chest economy
# (chestsBought drives BC/VC), the carried egg, the slots
# run fields, and the generic choice modal (Porygon trades /
# paid-chest picks share it with the blessing panel idiom).
var _react_cd: Dictionary = {}
var _comet: Dictionary = {}
var _comet_t := 75.0
var _timers: Array = []
var _chests_bought := 0
var _egg: Dictionary = {}
var _egg_node: Node3D = null
var _slot_spins := 0
var _slot_prizes: Dictionary = {}
var _slot_spent := 0
var _slots_prop: Dictionary = {}
var _choice_open := false
var _choice_return := "playing"
var _choice_on_pick: Callable
var _choice_on_close: Callable
var _choice_panel: PanelContainer
var _choice_title: Label
var _choice_sub: Label
var _choice_opts_box: HBoxContainer
var _choice_foot: Button
var _meter_win := {}
var _meter_best := 0.0
var _meter_hist: Array = []
var _meter_acc := 0.0
# Cycle 9 channels (audit §2/§8): hitstop timer (bundle hitstop(e):
# hitstopT = max(hitstopT, e) @1448302 — slam 0.04+0.05o, boss kill
# 0.5), camera kick = the renderer's chromatic-aberration punch
# (kick(e): chromaAmt = min(0.012, chromaAmt + e) @108253 — hurt
# 0.006, slam 0.008+0.012o), ui.damageFlash overlay alpha, floating
# text (dodge "-"), guardian chests, evolution-morph shake timer,
# and the photosynthesis leech throttle (photoT, 0.2 s).
var _hitstop_t := 0.0
var _chroma := 0.0
var _dmg_flash := 0.0
var _dmg_flash_rect: ColorRect = null
var _hud_root: Control = null  # cycle 17: hidden while in menu
var _vignette_mat: ShaderMaterial = null
var _floaters: Array = []  # {node: Label3D, t: float}
var _chests: Array = []     # {node: Node3D, opened: bool}
var _evo_fx_t := 0.0
var _photo_t := 0.0
var _alpha_idx := 0
var _pal: Dictionary = {}
var _env: Environment = null
var _sun: DirectionalLight3D = null      # cycle 12: weather light scale
var _sky_mat: ProceduralSkyMaterial = null  # cycle 12: weather sky bottom
var _terrain_mi: MeshInstance3D = null
var _dress_root: Node3D = null
var cam_yaw := 0.0
var cam_pitch := 0.45
var cam_dist := 9.0
var altar_pos := Vector3(0, 0, -30)
var portal_node: Node3D = null

var _cam: Camera3D
var _cam_focus := Vector3.ZERO
var _cam_lift := 0.0
var _cam_fov := 70.0

## Exponential damp, the original's Ic(a, b, rate, dt) form.
static func _damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))

func _dress_add(n: Node) -> void:
	(_dress_target if _dress_target else _dress_root).add_child(n)

func _cull_subtree(n: Node) -> void:
	if n is MultiMeshInstance3D:
		return  # cycle 11: map-wide instanced fields must never range-cull
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.visibility_range_end = 100.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		_cull_subtree(c)
var _crystal: Node3D
var _crystal_base_y := 0.0
var _ring: MeshInstance3D
var _spawn_t := 0.0
var _e_prev := false
var _banner_t := 0.0
# UI-mobile P1.4 (plan §B3 I6): the banner is a FIFO queue,
# not a single overwritten channel. Entries [text, secs];
# cap 4 (oldest dropped), same text de-duplicated. The
# current line's clock (and the queue) freeze while a
# modal owns the screen.
var _banner_q: Array = []
var _banner_shown_t := 0.0
var _banner_secs := 0.0
# UI-mobile P1 addendum: the touch id driving the camera
# (a drag that started on no GUI control — never the
# joystick's id). -1 = none.
var _cam_touch_id := -1
# UI-mobile P1.1: last applied touch-wording state
# (-1 = never applied) — build-time texts are re-synced
# whenever _touch_wanted() flips (first real touch).
var _touch_text_on := -1
var _kbd_caps: Array = []
var _draft_team_btn: Button
var _blessing_team_btn: Button
var _menu_hint: Label
var _pause_quit_btn: Button
var _pause_quit_armed_ms := -1
var _swarm := false
var _swarm_announced := false
var _projectiles: Array = []
var _proj_mats := {}
var _effects: Array = []
var _particles: Array = []  # cycle 11 sprite particles {node, mat, vel, t, life, s0, s1, grav, drag, a0}
var _ring_mesh: Mesh = null
var _beam_shader: Shader = null
var _tex_disc: Texture2D = null
var _tex_star: Texture2D = null
var _tex_leaf: Texture2D = null
var _cast_parity := 0
var _props: Array = []  # Vector3(x, z, collision radius)
var _rng := RandomNumberGenerator.new()
var _spawn_h := 0.0
var _altar_h := 0.0

var minimap_baked: Texture2D

var _font: Font
var _font_display: Font
var _banner: Label
var _banner_back: Panel      # cycle 19: stageIntro backing band
var _modal_scrim: ColorRect  # cycle 19: shared modal dim
var _prompt: Label
var _timer_label: Label
var _elapsed_label: Label
var _dust_label: Label
var _gold_label: Label
var _ball_price_label: Label  # cycle 21: next-ball price (bundle wl-ball)
var _kills_label: Label
var _danger_segs: Array = []
var _danger_name: Label
var _wx_label: Label
var _wx_icon: UiBadge
var _pips: Array = []
var _medal_panel: UiMedallion
var _move_slot: Panel
var _move_slot_icon: UiIcon  # cycle 19: first move's type icon
var _move_slot_sig := ""     # cycle 19: icon refresh signature
var _medal_glyph: Label
var _hud_name: Label
var _hud_chips: HBoxContainer
var _hud_evo: Label
## UI-mobile P2 (plan §B4 P2): the top-band pieces the phone
## content version moves or hides (refs the build kept local),
## the minimap's tap badge, the weather chip's touch hit area,
## and the applied-state latch (-1 = never applied).
var _hud_hp_track: Panel
var _hud_name_full := ""
var _zone_chip: Panel
var _tier_chip: Panel
var _wx_chip: Panel
var _wallet_pill: Panel
var _dust_icon: UiIcon
var _coin_icon: UiIcon
var _ball_icon: UiIcon
var _mm_expand: UiIcon
var _wx_hit: Control
var _wx_tap_ms := -100000
var _p2_on := -1
var _p2_font_sig := ""
var _pw_last: Array = []      # last _pw_defs() texts (stat toast)
# UI-mobile P3 (plan §B4 P3): objective pill + drawer (D4),
# portrait pause (D1), layout mode (D6 classic switch).
var _p3_on := -1              # 1 = new phone layout, 0 = classic / desktop
var _p3_s_col := 1.0          # last right-column scale (font fit)
var _obj_pill: PanelContainer
var _obj_dot: Panel
var _obj_title: Label
var _obj_sub: Label
var _obj_badge: Panel
var _obj_badge_label: Label
var _kills_badge: Panel
var _kills_badge_label: Label
var _obj_hit: Control
var _obj_total := 0
var _obj_sig := ""
var _obj_folded := false
var _obj_drawer: PanelContainer
var _obj_drawer_scroll: ScrollContainer
var _obj_drawer_box: VBoxContainer
var _obj_drawer_all: Button
var _obj_drawer_t := 0.0
var _obj_drawer_sig := ""
var _obj_drawer_shape := ""
var _obj_drawer_refs := {}
var _obj_drawer_settle := 0
var _portrait_hit: Control
var _pause_badge: Panel
var _p3_tap_ms := -100000
var _unlock_from_pause := false
var _unlock_close_btn: Button
var _move_name_label: Label  # cycle 19: the slot's Lv strip
var _ult_circle: UltGauge
var _ult_name_label: Label
## Cycle 13: the ultimate controller (scripts/ult.gd) + its
## presentation channels (cut-in band, ultLook tint overlay).
var ult: Ult
var _cutin_panel: Panel
var _cutin_name: Label
var _cutin_t := 0.0
var _ult_look_rect: ColorRect
var _ult_look_t := 0.0
var _ult_look_dur := 1.0
var wallet: WalletManager
const TouchControls := preload("res://scripts/touch_controls.gd")
var touch_controls  # TouchControls instance (preloaded const above; untyped for dynamic access)
var _touch_forced := false  # harness / first-real-touch latch
var _wallet_status: Label
var _wallet_panel: PanelContainer
var _wallet_edit: LineEdit
var _wallet_balance: Label
var _wallet_retry: Button
var _menu_panel: Control
var _menu_intro_items: Array = []  # cycle 19: stagger set
var _menu_badges := {}             # cycle 19: mm-badge chips
var _menu_hero: PanelContainer     # cycle 19: menu hero card
var _menu_hero_box: VBoxContainer
var _menu_hero_sp := ""
var _first_starter_card: Button
var _result_panel: PanelContainer
var _result_wrap: VBoxContainer  # U5 fix6: P5 modal stack (panel + actions below); null on desktop
var _result_title: Label
var _result_body: Label
var _result_core: VBoxContainer  # U5: P5 summary rows + payout pill, always visible (not scrolled)
var _result_stars: Array = []  # U5: the three star TextureRects (filled by _fill_result per state)
var _altar_label: Label3D
var _hud_t := 0.0
var _lv_label: Label
# Cycle 10 HUD bars (bundle .bar.hpbar @2000723 / .bossbar
# @2003931): player HP under the info panel, guardian boss bar
# top-center. Lag ghosts follow the bundle's per-bar math.
var _hud_hp_lag: Panel
var _hud_hp_fill: Panel
var _hud_hp_num: Label
var _hud_shield_fill: Panel
var _php_lag := 1.0
var _php_lag_hold := 0.0
var _php_band := -1
var _lab_selected := "dmg"
var _lab_detail: VBoxContainer
var _boss_card: Panel
var _boss_name_label: Label
var _boss_tag_label: Label
var _boss_tag_chip: Panel  # U1 1:1 round 4: cream chip behind the tag
var _boss_hp_lag: Panel
var _boss_hp_fill: Panel
var _boss_hp_num: Label
var _boss_lag := 1.0
var _boss_lag_hold := 0.0
var _boss_key := ""
var _boss_shown := false
var _zone_cn: Label
var _zone_en: Label
var _top_card: Panel  # cycle 18: kept for the plate-overlap shift
var _hero_cluster: Control  # cycle 19 hotfix: TL cluster as ONE unit
var _hero_plate: Panel  # U1 1:1 round 5: dark pill backplate unifying the cluster
var _hero_info: Panel       # cycle 19 hotfix: plate (gate reads it)
var _bl_cluster: Control    # cycle 19 hotfix: BL cluster as ONE unit
# UI-mobile P4 (plan §B4 P4): the phone BL two-row slots —
# moves row (every learned move) over vitamins row; the
# legacy row (4 empty slots, first-move card, lock) hides.
var _bl_rows: Control
var _bl_strip: Panel  # U1 1:1 round 6: dark band behind the move row only (rect set in _p4_layout_bl)
var _bl_move_slots: Array = []  # {panel, lv, key, sweep}
var _bl_vit_slots: Array = []   # {panel, lv, key}
var _bl_lock: Panel  # first lock slot (kept for the P4 checks)
var _bl_locks: Array = []  # U1 1:1 round 4: extra lock slots (2nd..nth)
var _bl_legacy: Array = []
var _bl_sig := ""
var _bl_font_sig := ""
var _p4_on := -1
var _p4_prompt_last := ""
var _p4_bars_seen := -1
var _prompt_tri: Polygon2D  # bubble pointer toward the ❗ button
# UI-mobile P5 (plan §B3 M0 + §B4 P5): the phone modal family.
# _p5_on = phone factor (> 1.01), read at build (one phone form
# in both layouts — D6 classic is a HUD arrangement); _p5_spec:
# panel -> Vector2(W_max, H_design); _p5_dirty: a Control joined
# the tree (modal content rebuilt) -> refit the open modals.
var _p5_on := false
var _p5_spec: Dictionary = {}
var _p5_dirty := false
var _p5_vis_sig := -1
var _menu_design: Control   # the main menu's design surface (plan §B3 G1-G6)
var _menu_starters: ScrollContainer
var _shop_gold_l: Label  # phone meowth head: the gold, big
var _ls_team_hint: Label
## Test seam (Test/phonehud.gd): when >= 0, _phone_factor()
## returns this instead of probing the platform — the gate
## feeds it the value the formula yields for a 2400x1080
## ~420 dpi phone panel, so the REAL scaler + layout code
## runs exactly as on device. Production always leaves -1.
var debug_phone_factor := -1.0
## Test seam (cycle 21.3, audit F6): when x >= 0,
## _safe_insets() returns this Vector4 (L,T,R,B, logical px)
## instead of probing DisplayServer — the phonehud gate
## feeds simulated punch-hole / nav-bar insets through it.
## Production always leaves the -1 sentinel.
var debug_safe_insets := Vector4(-1, -1, -1, -1)
## Cycle 21.3 (audit F3): the centre-stack span the last
## phone _layout_hud computed (x = span_l, y = span_r, in
## _ui_root space). Exposed for the phonehud gate.
var _dbg_span := Vector2.ZERO
var _zone_chip_label: Label
var _tier_chip_label: Label
var _meta_status: Label
var _minimap: Minimap
var _draft_panel: PanelContainer
var _draft_opts_box: HBoxContainer
var _draft_title: Label
var _draft_mini: HBoxContainer
var _draft_rb: Button
var _draft_sb: Button
var _draft_bb: Button
var _draft_card_btns: Array = []
var _draft_card_accents: Array = []
var _draft_card_rars: Array = []
var _draft_featured_fx: Control = null  # U3: gold rim+glow overlay on the featured draft card
var _draft_shines: Array = []   # cycle 19: rarity>=2 shine sweeps
var _shine_tex: Texture2D       # cycle 19: shared shine gradient
var _gold_glow_tex: Texture2D  # U3: cached radial gold glow for the featured draft card
var _draft_banish_mode := false
var _draft_banish_target := -1  # cycle 18 (audit §4.1): two-step banish
var _draft_opened_msec := 0     # cycle 18 (audit §4.7): the 600 ms modal guard
var _draft_closed_msec := -100000
var _blessing_opened_msec := 0
# Cycle 14 interactables + blessing modal state.
var _blessing_panel: PanelContainer
var _blessing_title: Label
var _blessing_sub: Label
var _blessing_opts_box: HBoxContainer
var _blessing_queue: Array = []
var _blessing_open := false
var _blessing_offers: Array = []
var _blessing_picks_left := 0
var _blessing_return := "playing"
var _bless_rng := RandomNumberGenerator.new()
var _inter_state := {}  # zone -> {"altars": [...], "totem": {...}}
var _inter_target: Node3D = null  # prebuild holder (like _dress_target)
var _stone_mat: StandardMaterial3D = null
var _stone_dark_mat: StandardMaterial3D = null
var _ring_mat: StandardMaterial3D = null
var _lab_panel: PanelContainer
var _lab_list: VBoxContainer
var _lab_info: Label
var _lab_mode := "upgrades"  # cycle 19: lab | items tabs
var _lab_items_list: VBoxContainer
var _lab_tab_upgrades: Button
var _lab_tab_items: Button
var _unlock_panel: PanelContainer
var _unlock_list: VBoxContainer
var _unlock_info: Label
var _starter_unlock_box: BoxContainer
# Cycle 16: audio (scripts/audio.gd) + the meta daily shop panel
# + the sound settings panel.
var audio: GameAudio
var _shop_panel: PanelContainer
var _shop_list: VBoxContainer
var _shop_info: Label
var _shop_countdown: Label
var _sound_panel: PanelContainer
# Cycle 18: UI round 2 + the bag bring-in.
var _ui_root: Control              # safe-area inset layer (all UI but touch)
var _ui_scale_nodes: Array = []     # registered for the kR-style scaler
var _party_row: HBoxContainer
var _party_sig := ""
var _pw_row: HBoxContainer
var _goal_card: PanelContainer
var _goal_pic: TextureRect
var _goal_name: Label
var _goal_bar_fill: Panel
var _goal_next: Label
var _goal_count: Label  # cycle 21.3 (§5): the progress count, own right-aligned label
var _goal_track: Panel  # cycle 21.3 (F1): hidden when the stack budget sheds the bar
var _goal_species := ""
var _pill_box: VBoxContainer
var _pill_badge: Panel  # cycle 21.3 (F1): "+N" badge for budget-collapsed pills
var _pill_badge_label: Label
var _pill_sig := ""
var _prompt_back: Panel  # cycle 21.3 (§5/F5): ink-glass backing behind the prompt
var _boss_pic: TextureRect
var _boss_foot: Label
var _boss_ticks: Array = []  # cycle 21: phase ticks (kit bosses only)
var _mini_bars: Array = []          # [{panel, name, fill, lagfill, lag, lag_hold, key}]
var _pause_panel: PanelContainer
var _pause_pages: Dictionary = {}
var _pause_moves_box: VBoxContainer
var _pause_sub: Label
var _pre_pause_state := "playing"
var _pause_peek_return := ""  # cycle 19: team view over draft/blessing
var _settings_tab_now := "sound"
var _settings_page: VBoxContainer
var _settings_tabs: Dictionary = {}
var _settings_return := ""          # "pause" when opened from pause
var _bigmap_panel: PanelContainer
var _bigmap: BigMap
var _bigmap_list: VBoxContainer
var _pre_bigmap_state := "playing"
var _map_pins: Array = []           # Vector3, max 3 (bundle: <=3 pins)
var _fog := PackedByteArray()       # 48x48 visited cells, zone-local
var _fog_t := 0.0
var _result_box: VBoxContainer
var _loadout_panel: Control
var _ls_species := "bulbasaur"      # species shown in the detail pane
var _ls_hero := "bulbasaur"         # species the run starts with
var _ls_boosts: Array = []          # selected bag item ids
var _ls_detail: VBoxContainer
var _ls_grid: GridContainer
var _ls_team: HBoxContainer
var _ls_bagrow: HBoxContainer
var _ls_cap_label: Label
var _ls_archive_row: HBoxContainer  # cycle 19: presets
var _ls_start_btn: Button
# Run-summary feeds (results screen).
var run_move_dmg: Dictionary = {}
var run_ally_dmg: Dictionary = {}
var run_captures: Array = []
var run_blessings: Array = []
var run_evos := 0
var _snap_done: Dictionary = {}
var _snap_seen := 0
var _snap_captured := 0
var _snap_league := 0
# Bag boosts live in this run.
var _boost_honey := false
var _honey_at := -1.0
var _master_ball := false
var _classic_at := INF
var _classic_e: Enemy = null
var _classic_escape := 0.0
var _shiny_ally: Enemy = null
var _pending_shiny_ally: Enemy = null
var _shiny_serial := 0
var _shiny_at := INF  # cycle 20: stage-clock fire time; INF = the stage roll failed (no shiny)
var _shiny_spawned := false  # per-stage director latch (shinySpawned)
var _shiny_e: Enemy = null
var _shiny_escape := 0.0
var _takeover_e: Enemy = null  # cycle 21: shiny-boss takeover target
var _run_music := ""        # this run's ingame track (Oc draw)
var _music_t := 0.0         # music director re-assert timer
var _kill_chain := 0        # xp()/streak() pitch ladder chain
var _kill_chain_t := -10.0

func _ready() -> void:
	_rng.seed = 7
	GameProfile.load_profile()
	_pal = ZONES[0]["pal"]
	# Cycle 17: the UI font stacks live in UiTheme (Fredoka /
	# Smiley display, Nunito / Noto-Heavy body); _font keeps its
	# role as the font every _mk_label call site draws with.
	UiTheme.load_fonts()
	_font = UiTheme.body_font()
	_font_display = UiTheme.display_font()
	_gen_terrain()
	altar_pos = Vector3(ALTAR_XZ.x, height_at(ALTAR_XZ.x, ALTAR_XZ.y), ALTAR_XZ.y)
	_build_environment()
	_build_terrain()
	_build_water()
	_bake_minimap()
	_build_mountains()
	# All biome dressing lives under one root so a zone change can free
	# and rebuild it (cycle 7). Android perf: cull beyond 100 u.
	_dress_root = Node3D.new()
	_dress_root.name = "Dressing"
	add_child(_dress_root)
	_build_props()
	_build_set_dressing()
	_cull_subtree(_dress_root)
	_build_altar()
	# Cycle 14: zone 1's interactables ride the same hand-assembled
	# first cache entry as the rest of the boot scene.
	var iroot1 := _build_interactables(1)
	# Cycle 16: the audio engine (buses/players created in its
	# _ready) + the profile's sound settings applied, menu music.
	audio = GameAudio.new()
	add_child(audio)
	_apply_audio_settings()
	audio.play_track("menu")
	wallet = WalletManager.new()
	add_child(wallet)
	wallet.state_changed.connect(_refresh_wallet_ui)
	wallet.balance_updated.connect(func(_s: float) -> void: _refresh_wallet_ui())
	wallet.balance_failed.connect(func(_r: String) -> void: _refresh_wallet_ui())
	_build_hud()
	_cam_focus = Vector3(SPAWN_XZ.x, height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)
	# Cycle 12: zone 1's scene is the first cache entry (live form);
	# zones 2-4 generate on worker threads and prebuild behind the
	# menu (see DIFF cycle 12, item 1).
	_scene_cache[1] = {"terrain_mi": _terrain_mi, "dress_nodes": [],
		"water_nodes": [], "props": _props.duplicate(), "minimap": minimap_baked,
		"inter_root": iroot1}
	_live_zone = 1
	_zone_fog_base = ZONES[0]["fog"]
	_weather_rng.seed = 20261
	_kick_terrain_precompute()
	_prebuild_scenes()

# ------------------------------------------------------------------ terrain
## Cycle 11: terrain generation ported from the bundle's `of` class —
## generate() @238277 (main bundle byte offsets), isFlatOpen @248564,
## planPonds @246400. A seeded simplex fbm field is quantized into
## XD = 4.6 terraces whose riser width is noise-modulated; 4-6 random-
## walk paths from the origin smooth the terraces along their course;
## forest adds two massif plateaus (spiral outlines join the path
## set) and terrace-level ponds; no-relief water biomes carve
## lakebeds below field 0.17 with a shared water plane at
## 0.17 * levels * XD - 0.9; spawn sits on a shelf at exactly XD; a
## rim rises past the play bound; one 3x3 smoothing pass finishes.
## Heights live on a grid read bilinearly, like the original's
## height() (theirs cell 1.12, ours 1.5). The RNG streams differ, so
## layouts are distribution-equivalent, not bit-identical.
## connectPlateaus (relief-only post pass) was NOT ported.

const XD := 4.6           # terrace step height (bundle Xd)
## Per-zone layout seed rolls (cycle 11 tuning): the bundle's world
## seed is fixed but unrecoverable (their RNG stream differs), so
## ours is chosen by an openness metric around the spawn shelf —
## the original's spawn reads as an open glade, and these rolls are
## the picks from Test/probe_c11 rolls (see DIFF cycle 11).
const ZONE_SEED_ROLL := [11, 1, 2, 11]
const GRID_N := 240       # height grid res; cell = 360/240 = 1.5
const AREA_MUL := 1.6533  # (360/280)^2: the bundle's areaMul at world 360
var _grid := PackedFloat32Array()
var _mask_grid := PackedFloat32Array()
var _ponds: Array = []    # {x, z, r, h, level, seed} (active zone, mirrored)
var _water_level := -99.0
var _levels := 4
var _carve_water := false
var _paths: Array = []    # active gen's paths (mirror; tooling reads)
var _lat_e := PackedFloat32Array()  # gate lattices (mirrors; scatter/deco)
var _lat_h := PackedFloat32Array()
var _water_root: Node3D = null
var _seed_roll_override := -1  # probe hook: force a layout seed roll
var _path_mask_tex: Texture2D = null

## Cycle 12: the generator itself lives in scripts/terrain_gen.gd
## (pure GDScript, safe on worker threads — see DIFF cycle 12).
## The world caches one TerrainGen per zone and mirrors its outputs
## into the members above; placement gates forward to the active
## gen's scratch fields, so their code is unchanged.
const TerrainGen := preload("res://scripts/terrain_gen.gd")
var _gen = null             # active zone's TerrainGen
var _terrain_cache := {}    # zone -> TerrainGen (data ready)
var _terrain_tasks := {}    # zone -> WorkerThreadPool task id
var _terrain_results := {}  # zone -> TerrainGen (finished, unmerged)

## Cycle 12 scene cache: a zone's built scene (terrain mesh, water
## nodes, dressing nodes, collider list, minimap texture) is built
## once, then parked (detached, not freed) and restored on switch —
## a warm portal switch is a state swap + reparent, ~ms. Scenes for
## zones 2-4 prebuild behind the menu (see _prebuild_scenes).
var _scene_cache := {}      # zone -> {terrain_mi, dress_nodes, water_nodes, props, minimap}
var _live_zone := 0         # zone whose scene is in the tree (0 = none)
var _dress_target: Node3D = null  # prebuild: dress into a detached holder
var _water_target: Node3D = null  # prebuild: water into a detached holder
var _slice_builds := false  # prebuild only: hog loops yield per budget
var _prebuild_running := false
var _prebuild_abort := false
var _switch_pending := 0    # uncached portal target: build after 1 frame (loading banner)

func _bilinear(arr: PackedFloat32Array, x: float, z: float, cell: float, maxi: int) -> float:
	var gx := clampf((x + 180.0) / cell, 0.0, float(maxi))
	var gz := clampf((z + 180.0) / cell, 0.0, float(maxi))
	var i0 := int(floorf(gx))
	var j0 := int(floorf(gz))
	var i1 := mini(i0 + 1, maxi)
	var j1 := mini(j0 + 1, maxi)
	var fx := gx - float(i0)
	var fz := gz - float(j0)
	var w := maxi + 1
	var a := arr[j0 * w + i0]
	var b := arr[j0 * w + i1]
	var c := arr[j1 * w + i0]
	var d := arr[j1 * w + i1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)

func _path_dist(x: float, z: float) -> float:
	return _gen._path_dist(x, z)

func _field_h(x: float, z: float) -> float:
	return _gen._field_h(x, z)

func _field_h_fast(x: float, z: float) -> float:
	return _gen._field_h_fast(x, z)

## Worker-thread body: generate one zone's data into a result slot.
## Touches only its own TerrainGen + the results dict (single write
## as the last action; readers merge only after task completion).
func _terrain_task(z: int) -> void:
	var g = TerrainGen.new()
	g.generate(ZONES[z - 1], z, int(ZONE_SEED_ROLL[z - 1]), ALTAR_XZ)
	_terrain_results[z] = g

func _kick_terrain_precompute() -> void:
	for z in range(2, 5):
		if not _terrain_cache.has(z) and not _terrain_tasks.has(z):
			_terrain_tasks[z] = WorkerThreadPool.add_task(Callable(self, "_terrain_task").bind(z))

## Data for zone z, generating synchronously if no thread result is
## available yet. A probe roll override always generates fresh and
## is never cached.
func _zone_data(z: int):
	if _seed_roll_override >= 0:
		var gf = TerrainGen.new()
		gf.generate(ZONES[z - 1], z, _seed_roll_override, ALTAR_XZ)
		return gf
	if _terrain_cache.has(z):
		return _terrain_cache[z]
	if _terrain_tasks.has(z):
		WorkerThreadPool.wait_for_task_completion(int(_terrain_tasks[z]))
		_terrain_tasks.erase(z)
	if _terrain_results.has(z):
		var gr = _terrain_results[z]
		_terrain_results.erase(z)
		_terrain_cache[z] = gr
		return gr
	var g = TerrainGen.new()
	g.generate(ZONES[z - 1], z, int(ZONE_SEED_ROLL[z - 1]), ALTAR_XZ)
	_terrain_cache[z] = g
	return g

## Make a generated zone's data the live member state.
func _apply_zone_data(g) -> void:
	_gen = g
	_grid = g._grid
	_mask_grid = g._mask_grid
	_ponds = g._ponds
	_paths = g._paths
	_levels = g._levels
	_carve_water = g._carve_water
	_water_level = g._water_level
	_lat_e = g._lat_e
	_lat_h = g._lat_h
	if g.mask_tex == null:
		var img := Image.create(g.mask_n, g.mask_n, false, Image.FORMAT_R8)
		img.set_data(g.mask_n, g.mask_n, false, Image.FORMAT_R8, g.mask_bytes)
		g.mask_tex = ImageTexture.create_from_image(img)
	_path_mask_tex = g.mask_tex

func _gen_terrain() -> void:
	_apply_zone_data(_zone_data(zone))

func height_at(x: float, z: float) -> float:
	return _bilinear(_grid, x, z, 360.0 / float(GRID_N), GRID_N)

func _mask_at(x: float, z: float) -> float:
	return _bilinear(_mask_grid, x, z, 360.0 / float(GRID_N), GRID_N)

func water_at(x: float, z: float) -> float:
	var w := _water_level
	for pn in _ponds:
		var dx := x - float(pn["x"])
		var dz := z - float(pn["z"])
		var r := float(pn["r"])
		if dx * dx + dz * dz < r * r:
			w = maxf(w, float(pn["level"]))
	return w

func surface_at(x: float, z: float) -> float:
	# Bundle surface(): actors stand on the water plane when it is
	# above the bed.
	return maxf(height_at(x, z), water_at(x, z))

func _flat_open(x: float, z: float) -> bool:
	# Bundle isFlatOpen @248564: slope normal.y > 0.94 (probed at
	# +-0.5 there, +-0.75 here) and the ground is not submerged.
	if height_at(x, z) < water_at(x, z) + 0.25:
		return false
	return _terrain_normal(x, z, 0.75).y > 0.94

func _build_water() -> void:
	var wroot: Node3D = _water_target if _water_target else _water_root
	if wroot == null:
		_water_root = Node3D.new()
		_water_root.name = "Water"
		add_child(_water_root)
		wroot = _water_root
	for c in wroot.get_children():
		c.queue_free()
	var zc: Dictionary = ZONES[zone - 1]
	var wmode := String(zc["water"])
	var wcol: Color = zc["water_col"]
	if wmode == "ponds":
		for pn in _ponds:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = float(pn["r"]) * 1.02
			cm.bottom_radius = float(pn["r"]) * 1.02
			cm.height = 0.1
			cm.radial_segments = 24
			mi.mesh = cm
			var m := StandardMaterial3D.new()
			m.albedo_color = wcol
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = m
			mi.position = Vector3(float(pn["x"]), float(pn["level"]), float(pn["z"]))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wroot.add_child(mi)
	elif wmode == "plane" or wmode == "lava":
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(360, 360)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = wcol
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if wmode == "plane":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = Vector3(0, _water_level, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wroot.add_child(mi)

func _terrain_normal(x: float, z: float, s: float) -> Vector3:
	var hl := height_at(x - s, z)
	var hr := height_at(x + s, z)
	var hu := height_at(x, z - s)
	var hd := height_at(x, z + s)
	return Vector3(hl - hr, 2.0 * s, hu - hd).normalized()

func _hash2(x: float, z: float) -> float:
	var s := sin(x * 127.1 + z * 311.7) * 43758.5453
	return s - floor(s)

func _vnoise(x: float, z: float) -> float:
	var xi: float = floorf(x)
	var zi: float = floorf(z)
	var xf: float = x - xi
	var zf: float = z - zi
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = zf * zf * (3.0 - 2.0 * zf)
	return lerpf(
		lerpf(_hash2(xi, zi), _hash2(xi + 1.0, zi), u),
		lerpf(_hash2(xi, zi + 1.0), _hash2(xi + 1.0, zi + 1.0), u), v)

func _terrain_color(x: float, z: float, h: float, ny: float) -> Color:
	# Cycle 7: palette comes from the active zone config (ZONES.pal);
	# the forest entry holds the exact cycle-2..6 constants.
	var moss_a: Color = _pal.get("moss_a", MOSS_A)
	var moss_b: Color = _pal.get("moss_b", MOSS_B)
	var earth_a: Color = _pal.get("earth_a", EARTH_A)
	var earth_b: Color = _pal.get("earth_b", EARTH_B)
	var light_c: Color = _pal.get("light", LIGHT_C)
	var earth_dark: Color = _pal.get("earth_dark", EARTH_DARK)
	var cliff_c: Color = _pal.get("cliff", CLIFF_C)
	var col := moss_b.lerp(moss_a, _vnoise(x * 0.08, z * 0.08))
	var fine := _vnoise(x * 0.55 + 31.0, z * 0.55)
	col = col.lerp(Color(col.r * 1.14, col.g * 1.14, col.b * 1.1), fine * 0.45)
	var patch := _vnoise(x * 0.03 + 40.0, z * 0.03 - 17.0)
	if patch > 0.66:
		col = col.lerp(light_c * 0.9, clampf((patch - 0.66) * 2.0, 0.0, 0.45))
	# Cycle 11: faint path tint in the vertex color too (the minimap
	# bake reads vertex colors, so paths show on the map as well).
	var pmask := _mask_at(x, z)
	if pmask > 0.02:
		col = col.lerp(earth_b * 1.04, pmask * 0.35)
	if ny < 0.88:
		var t := clampf((0.88 - ny) / 0.22, 0.0, 1.0)
		var rock := cliff_c.lerp(earth_dark, _vnoise(x * 0.3, z * 0.3))
		# Cycle 5: stronger strata banding — the original's cliff faces
		# show clear horizontal sedimentary layers (orig_11/13).
		var strata := 0.90 + 0.10 * sin(h * 5.5) + 0.03 * sin(h * 16.0)
		rock = Color(rock.r * strata, rock.g * strata, rock.b * strata)
		col = col.lerp(rock, t)
	col = col.lerp(light_c * 0.85, clampf((h - 6.0) / 30.0, 0.0, 0.3))
	var da := Vector2(x - ALTAR_XZ.x, z - ALTAR_XZ.y).length()
	if da < 13.0:
		col = col.lerp(earth_a, clampf(1.0 - da / 13.0, 0.0, 0.8))
	return col

## Push a moving circle (actor at `next`, given radius) out of prop colliders.
func collide_circle(next: Vector3, radius: float) -> Vector3:
	for p in _props:
		var pv := p as Vector3
		var dx := next.x - pv.x
		var dz := next.z - pv.y
		var rr := radius + pv.z
		var d2 := dx * dx + dz * dz
		if d2 < rr * rr and d2 > 0.000001:
			var d := sqrt(d2)
			next.x = pv.x + dx / d * rr
			next.z = pv.y + dz / d * rr
	return next

## Cycle 5: bake the minimap's terrain once from the same height/color
## functions the world mesh uses — the original's minimap is a rendered
## zone map, not schematic dots. Disc + red ring are baked into the
## texture (transparent corners); markers stay dynamic in minimap.gd.
## Map is absolute: image px (0,0) = world (-170,-170), north (-Z) up.
func _bake_minimap() -> void:
	var sz := 168
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for j in range(sz):
		if _slice_builds and j % 12 == 11:
			await get_tree().process_frame
			if _prebuild_abort:
				return
		for i in range(sz):
			var dx := float(i) - sz * 0.5 + 0.5
			var dy := float(j) - sz * 0.5 + 0.5
			var rr := sqrt(dx * dx + dy * dy)
			if rr > sz * 0.5:
				img.set_pixel(i, j, Color(0, 0, 0, 0))
				continue
			# 定稿小地图外缘无红色像素圈，交由 MinimapFrame 暖金灰圆框包裹，仅作柔和内阴影过渡
			var wx := (float(i) / float(sz - 1) * 2.0 - 1.0) * 170.0
			var wz := (float(j) / float(sz - 1) * 2.0 - 1.0) * 170.0
			var h := height_at(wx, wz)
			var n := _terrain_normal(wx, wz, 2.0)
			var col := _terrain_color(wx, wz, h, n.y)
			# 提亮至柔和暖草坪色调，契合定稿 U1_final.jpg 暖黄草地纹理
			var meadow := Color(0.74, 0.88, 0.44)
			col = col.lerp(meadow, 0.45)
			var lift := 1.05 + clampf(h, 0.0, 8.0) / 8.0 * 0.50
			col = Color(minf(col.r * lift, 1.0), minf(col.g * lift, 1.0), minf(col.b * lift, 1.0), 1)
			if rr > sz * 0.5 - 5.0:
				col = Color(col.r * 0.86, col.g * 0.86, col.b * 0.86, 1)
			img.set_pixel(i, j, col)
	minimap_baked = ImageTexture.create_from_image(img)

# -------------------------------------------------------------- environment
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	_sky_mat = psm
	psm.sky_top_color = Color(0.353, 0.659, 1.0)       # #5aa8ff
	psm.sky_horizon_color = Color(0.847, 0.941, 1.0)   # #d8f0ff
	psm.ground_bottom_color = Color(0.16, 0.22, 0.18)
	psm.ground_horizon_color = Color(0.847, 0.941, 1.0)
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR  # original: toneMapping = 0
	# Fog: #bfe3ff, near 40, far 160 (linear depth fog in the original).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.749, 0.89, 1.0)
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 160.0
	env.fog_sky_affect = 0.35
	# Bloom (original: 0.8 / threshold 0.92).
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	# Color grade (cycle 5): the original's post chain grades the frame —
	# punchy and saturated. Gentle values so the measured terrain palette
	# (matched in cycle 2 without a grade) stays within tolerance; the
	# median is re-measured in the cycle-5 log.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12
	we.environment = env
	_env = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.light_color = Color(1.0, 0.945, 0.839)  # #fff1d6
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.shadow_bias = 0.15
	sun.shadow_normal_bias = 2.5
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	sun.look_at_from_position(Vector3(60, 120, 40), Vector3.ZERO, Vector3.UP)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	_build_vignette()

## Vignette (cycle 5): the last pass of the original's post chain. A
## clip-space fullscreen quad parented to the camera: it renders inside
## the 3D pass (so the canvas HUD stays clean, like the original's DOM
## HUD over its WebGL vignette), darkening the frame corners.
func _build_vignette() -> void:
	var vsh := Shader.new()
	vsh.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float chroma = 0.0;
varying vec2 q;
void vertex() {
	q = VERTEX.xy;
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}
void fragment() {
	float d = length(vec2(q.x * 1.25, q.y));
	float v = smoothstep(1.02, 1.68, d);
	vec3 col = vec3(0.02, 0.05, 0.02);
	float a = v * 0.40;
	if (chroma > 0.0005) {
		// Camera kick (cycle 9): the original's kick() is a
		// chromatic-aberration punch on its post chain (renderer
		// @108253). Ours splits the sampled framebuffer by the
		// same amount and lays the fringe over the vignette.
		vec2 off = q * chroma * 0.6;
		float r = texture(screen_tex, SCREEN_UV + off).r;
		float g = texture(screen_tex, SCREEN_UV).g;
		float b = texture(screen_tex, SCREEN_UV - off).b;
		col = vec3(r, g, b);
		a = clamp(v * 0.40 + chroma * 22.0, 0.0, 0.85);
	}
	ALBEDO = col;
	ALPHA = a;
}
"""
	var vmat := ShaderMaterial.new()
	vmat.shader = vsh
	vmat.render_priority = 100
	_vignette_mat = vmat
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var vq := MeshInstance3D.new()
	vq.mesh = quad
	vq.material_override = vmat
	vq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vq.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	_cam.add_child(vq)

func _build_terrain() -> void:
	var size := 360.0
	var seg := 240  # cycle 11: matches the height grid cell (1.5)
	var step := size / float(seg)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in range(seg + 1):
		if _slice_builds and j % 16 == 15:
			await get_tree().process_frame
			if _prebuild_abort:
				return
		for i in range(seg + 1):
			var x := -size * 0.5 + i * step
			var z := -size * 0.5 + j * step
			var h := height_at(x, z)
			var n := _terrain_normal(x, z, step)
			verts.append(Vector3(x, h, z))
			normals.append(n)
			cols.append(_terrain_color(x, z, h, n.y))
	for j in range(seg):
		if _slice_builds and j % 32 == 31:
			await get_tree().process_frame
			if _prebuild_abort:
				return
		for i in range(seg):
			var a := j * (seg + 1) + i
			var b := a + 1
			var c := a + seg + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 grass_gain = vec3(1.0);
uniform float flat_test = 0.0;
uniform sampler2D path_mask_tex;
uniform float cliff_gain = 0.78;
uniform float path_gain = 0.45;
varying vec3 wp;
varying vec3 wn;
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = NORMAL; }
void fragment() {
	// Cycle 6 (final form): the original's ground IS one saturated
	// texture — so the base grass here is the original's own tile
	// (env/forest/ground.png) under a single per-channel gain, NOT a
	// vertex-moss x tile-ratio chain (that chain's medians chased
	// their own tail for six harness runs: heterogeneous field,
	// threshold-selected sampler population). Vertex colour survives
	// only as gentle large-scale variation + the pad mask in R.
	vec3 gt = texture(ground_tex, wp.xz / 5.5).rgb;
	float n1 = vnoise(wp.xz * 0.11);
	float n2 = hash12(floor(wp.xz * 11.0));
	vec3 col = gt * grass_gain;
	col *= 0.90 + 0.20 * n1;
	col *= 0.85 + dot(COLOR.rgb, vec3(1.0, 1.0, 1.0)) * 0.35;
	// Authored bare-earth pads (uniform list, soft edge). Vertex
	// colour cannot carry this mask: cliff/worn tints share its R
	// range and painted half the field tan in the first c6 frames.
	vec3 pt = texture(path_tex, wp.xz / 4.5).rgb * path_gain * (0.85 + n2 * 0.3);
	// Cycle 11: the path tile follows the generator's pathMask grid
	// (the original lays paths along its smoothed corridors the same
	// way); the old authored pads are gone with the formula terrain.
	float padm = texture(path_mask_tex, (wp.xz + vec2(180.0)) / 360.0).r;
	col = mix(col, pt, padm * 0.85);
	// Cycle-5 glyph richness on top (tuft strokes + sparkles).
	vec3 det = texture(detail_tex, wp.xz / 2.3).rgb;
	vec3 det2 = texture(detail_tex, wp.xz / 11.0 + vec2(0.37, 0.61)).rgb;
	col *= 1.0 - det.r * 0.22;
	col *= 1.0 - det2.r * 0.10;
	// NOTE: no additive terms from the detail texture — its G/B
	// channels are broadly mid-grey (not sparse masks), so the old
	// cycle-5 "light blades / sparkles" adds washed the whole field
	// with a constant R/B floor (measured: effective +0.04 albedo).
	col += vec3(0.85, 0.80, 0.45) * pow(det.g, 6.0) * 0.35;
	float sp = step(0.972, hash12(floor(wp.xz * 14.0) + 7.0));
	col *= 1.0 - sp * 0.15;
	// Worn dirt patches (rare; authored pads carry the big areas).
	float pn = vnoise(wp.xz * 0.045 + 13.1);
	float patch = smoothstep(0.74, 0.82, pn);
	float rim = smoothstep(0.70, 0.74, pn) - patch;
	col = mix(col, pt, patch * 0.5);
	col *= 1.0 - rim * 0.14;
	// Strata cliffs on steep faces: the original's cliff tile
	// (rounded stone courses, env/forest/cliff.png), triplanar-lite.
	float cf = smoothstep(0.16, 0.30, 1.0 - wn.y);
	if (cf > 0.001) {
		vec2 cuv = abs(wn.x) > abs(wn.z) ? wp.zy : wp.xy;
		vec3 ct = texture(cliff_tex, cuv / 3.4).rgb * cliff_gain;
		ct *= 0.82 + 0.36 * vnoise(wp.xz * 0.3 + wp.yy * 0.2);
		col = mix(col, ct, cf * 0.88);
	}
	ALBEDO = col;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	# Cycle 7: tile set + gain from the active zone (zone 1 = the
	# original forest files/gain calibrated in cycle 6).
	var zc: Dictionary = ZONES[zone - 1]
	var tiles := String(zc["tiles"])
	var suffix := "" if tiles == "forest" else "_" + tiles
	sm.set_shader_parameter("detail_tex", load("res://assets/textures/grass_detail.png"))
	sm.set_shader_parameter("ground_tex", load("res://assets/textures/orig_ground" + suffix + ".png"))
	sm.set_shader_parameter("cliff_tex", load("res://assets/textures/orig_cliff" + suffix + ".png"))
	sm.set_shader_parameter("path_tex", load("res://assets/textures/orig_path" + suffix + ".png"))
	# Cycle 6 median correction: 0.68 global (the tile-median factor
	# measured on the first c6 frame) x the channel trim that pulls
	# the cycle-5 median (#498c47) toward the original's #389243 —
	# red down hard, green held, blue down slightly (see DIFF cycle 6).
	# Inverted from the target through the measured chain (light ~2.56x
	# + sRGB encode): median albedo product must land near
	# (0.017, 0.117, 0.021) for the screen median to read #389243.
	var gain: Vector3 = zc["gain"]
	sm.set_shader_parameter("grass_gain", gain)
	sm.set_shader_parameter("path_mask_tex", _path_mask_tex)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = sm
	add_child(mi)
	_terrain_mi = mi

func _build_mountains() -> void:
	# Fog-exempt flat silhouettes: the original shows blue mountain shapes
	# through the fog (its backdrop layer ignores scene fog).
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, fog_disabled;
void fragment() { ALBEDO = vec3(0.52, 0.64, 0.80); }
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for i in range(10):
		var ang := TAU * float(i) / 10.0 + _rng.randf_range(-0.15, 0.15)
		var r := _rng.randf_range(205.0, 255.0)
		var h := _rng.randf_range(30.0, 50.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = _rng.randf_range(30.0, 55.0)
		cone.height = h
		cone.radial_segments = 7
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(ang) * r, h * 0.5 - 6.0, sin(ang) * r)
		add_child(mi)

func _slope_ok(x: float, z: float) -> bool:
	return _terrain_normal(x, z, 1.5).y > 0.78

func _clear_of(x: float, z: float, spawn_d: float, altar_d: float) -> bool:
	if Vector2(x - SPAWN_XZ.x, z - SPAWN_XZ.y).length() < spawn_d:
		return false
	if Vector2(x - ALTAR_XZ.x, z - ALTAR_XZ.y).length() < altar_d:
		return false
	return Vector2(x, z).length() < 172.0

func _build_props() -> void:
	# Cycle 11: the scattered environment is now the bundle's own two
	# systems, instanced — scatterProps (@262019: floor(560 *
	# propDensity * areaMul) gated placements of mf-geometry props,
	# @268632) and buildDecorations (@262019: round(7000 * areaMul)
	# crossed-quad pixel sprites from the Md atlas generator,
	# @219470). They replace the old hand-counted node scatter and
	# the 900-clump tuft field. Prop colors are each biome's tex
	# table values (news block); sizes/counts/gates follow the bundle.
	_scatter_meshes.clear()
	_build_scatter()
	_build_deco()

# ------------------------------------------------------- cycle 11 scatter
var _scatter_meshes: Dictionary = {}  # kind -> ArrayMesh (this zone)
const SCATTER_COLLIDERS := {"tree": 0.8, "pine": 0.7, "rock": 1.3, "grave": 0.6,
	"mushroom": 0.6, "bush": 0.0, "pillar": 1.0, "cactus": 0.55, "deadtree": 0.5,
	"crystal": 0.8, "lavarock": 1.3}

func _part(mesh: Mesh, pos: Vector3, scl: Vector3, col: Color, rot := Vector3.ZERO) -> Dictionary:
	var b := Basis.from_euler(rot).scaled(scl)
	return {"mesh": mesh, "xf": Transform3D(b, pos), "col": col}

func _ball(r: float, w := 12, h := 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = w
	m.rings = h
	return m

func _cyl(rt: float, rb: float, h: float, seg := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	return m

func _boxm(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

func _octa(r: float) -> ArrayMesh:
	var t := Vector3(0, r, 0)
	var b := Vector3(0, -r, 0)
	var e := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var base := 0
	for k in range(4):
		var e1: Vector3 = e[k]
		var e2: Vector3 = e[(k + 1) % 4]
		for tri in [[t, e2, e1], [b, e1, e2]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			var nrm := (p1 - p0).cross(p2 - p0).normalized()
			verts.append(p0)
			verts.append(p1)
			verts.append(p2)
			normals.append(nrm)
			normals.append(nrm)
			normals.append(nrm)
			idx.append(base)
			idx.append(base + 1)
			idx.append(base + 2)
			base += 3
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return am

func _bake_parts(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var base := 0
	for part in parts:
		var mesh: Mesh = part["mesh"]
		var xf: Transform3D = part["xf"]
		var col: Color = part["col"]
		var arr := mesh.surface_get_arrays(0)
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for vi in range(pv.size()):
			verts.append(xf * pv[vi])
			normals.append((xf.basis * pn[vi]).normalized())
			colors.append(col)
		if pi.is_empty():
			for vi in range(pv.size()):
				idx.append(base + vi)
		else:
			for ix in pi:
				idx.append(base + ix)
		base += pv.size()
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return am

func _scatter_kind_mesh(kind: String) -> ArrayMesh:
	# Geometry follows the bundle's mf factory (@268632): same part
	# shapes/sizes/offsets; colors from the biome tex table (theirs
	# are canvas textures washed from the same base colors).
	if _scatter_meshes.has(kind):
		return _scatter_meshes[kind]
	var sc: Dictionary = ZONES[zone - 1]["scol"]
	var leaf: Color = sc["leaf"]
	var leaf2: Color = sc["leaf_alt"]
	var bark: Color = sc["bark"]
	var rock: Color = sc["rock"]
	var parts: Array = []
	match kind:
		"tree":
			parts.append(_part(_cyl(0.28, 0.45, 3.2, 8), Vector3(0, 1.6, 0), Vector3.ONE, bark))
			parts.append(_part(_ball(2.1, 14, 9), Vector3(0, 4.3, 0), Vector3.ONE, leaf))
			parts.append(_part(_ball(1.5, 12, 8), Vector3(1.1, 5.4, 0), Vector3.ONE, leaf2))
			parts.append(_part(_ball(1.3, 12, 8), Vector3(-1.0, 5.2, 0.3), Vector3.ONE, leaf))
		"pine":
			parts.append(_part(_cyl(0.22, 0.34, 2.2, 8), Vector3(0, 1.1, 0), Vector3.ONE, bark))
			parts.append(_part(_cyl(0.0, 2.0, 3.2, 10), Vector3(0, 3.2, 0), Vector3.ONE, leaf))
			parts.append(_part(_cyl(0.0, 1.45, 2.6, 10), Vector3(0, 5.1, 0), Vector3.ONE, leaf2))
		"bush":
			parts.append(_part(_ball(1.0, 12, 8), Vector3(0, 0.55, 0), Vector3(1.3, 0.8, 1.3), leaf))
			parts.append(_part(_ball(0.7, 10, 7), Vector3(0.5, 0.75, 0.2), Vector3.ONE, leaf2))
		"rock":
			parts.append(_part(_ball(1.35, 12, 8), Vector3(0, 0.5, 0), Vector3(1, 0.75, 1), rock))
		"mushroom":
			parts.append(_part(_cyl(0.22, 0.3, 1.1, 8), Vector3(0, 0.55, 0), Vector3.ONE, sc["stem"]))
			parts.append(_part(_ball(0.8, 12, 6), Vector3(0, 1.05, 0), Vector3(1, 0.55, 1), sc["cap"]))
		"grave":
			parts.append(_part(_boxm(Vector3(1.0, 1.4, 0.3)), Vector3(0, 0.7, 0), Vector3.ONE, rock))
			parts.append(_part(_ball(0.5, 10, 5), Vector3(0, 1.4, 0), Vector3(1, 0.6, 0.6), rock))
		"pillar":
			parts.append(_part(_cyl(0.85, 0.95, 5.0, 10), Vector3(0, 2.5, 0), Vector3.ONE, rock))
			parts.append(_part(_boxm(Vector3(2.1, 0.5, 2.1)), Vector3(0, 5.1, 0), Vector3.ONE, rock))
		"cactus":
			parts.append(_part(_cyl(0.5, 0.5, 2.2, 10), Vector3(0, 1.6, 0), Vector3.ONE, leaf))
			parts.append(_part(_ball(0.5, 10, 6), Vector3(0, 2.7, 0), Vector3.ONE, leaf))
			parts.append(_part(_ball(0.5, 10, 6), Vector3(0, 0.5, 0), Vector3.ONE, leaf))
			parts.append(_part(_cyl(0.18, 0.18, 1.1, 7), Vector3(0.75, 1.9, 0), Vector3.ONE, leaf, Vector3(0, 0, PI / 2)))
			parts.append(_part(_cyl(0.18, 0.18, 0.9, 7), Vector3(1.15, 2.3, 0), Vector3.ONE, leaf))
			parts.append(_part(_cyl(0.16, 0.16, 0.9, 7), Vector3(-0.68, 1.6, 0), Vector3.ONE, leaf, Vector3(0, 0, PI / 2)))
			parts.append(_part(_cyl(0.16, 0.16, 0.7, 7), Vector3(-1.0, 1.9, 0), Vector3.ONE, leaf))
		"deadtree":
			parts.append(_part(_cyl(0.16, 0.38, 4.2, 8), Vector3(0, 2.1, 0), Vector3.ONE, bark))
			parts.append(_part(_cyl(0.05, 0.14, 2.2, 6), Vector3(0.75, 3.9, 0), Vector3.ONE, bark, Vector3(0, 0, -0.8)))
		"crystal":
			parts.append(_part(_octa(1.0), Vector3(0, 0.9, 0), Vector3(0.8, 1.3, 0.8), sc["cap"]))
			parts.append(_part(_octa(0.62), Vector3(0.55, 0.5, 0.2), Vector3(0.7, 1.0, 0.7), sc["cap"], Vector3(0.3, 0, 0.2)))
		"lavarock":
			parts.append(_part(_ball(1.35, 12, 8), Vector3(0, 0.5, 0), Vector3(1, 0.75, 1), Color(0.16, 0.12, 0.11)))
			parts.append(_part(_ball(0.5, 10, 6), Vector3(0.5, 0.85, 0.3), Vector3.ONE, Color(1.0, 0.45, 0.12)))
	var mesh := _bake_parts(parts)
	_scatter_meshes[kind] = mesh
	return mesh

func _build_scatter() -> void:
	# scatterProps (@262019): uniform attempts over +/-(play-3),
	# gated by origin distance, isFlatOpen, reserves and the path
	# mask, thinned by a low-frequency noise mask into groves and
	# clearings; kinds drawn from the biome's weighted props table.
	var zc: Dictionary = ZONES[zone - 1]
	var kinds: Array = zc["scatter"]
	var attempts := int(560.0 * float(zc["prop_density"]) * AREA_MUL)
	var rng := RandomNumberGenerator.new()
	rng.seed = (5000 + zone * 131) ^ 11259375  # bundle: seed ^ 11259375
	var per_kind: Dictionary = {}
	for t in range(attempts):
		if _slice_builds and t % 256 == 255:
			await get_tree().process_frame
			if _prebuild_abort:
				return
		var x := rng.randf_range(-BOUND + 3.0, BOUND - 3.0)
		var z := rng.randf_range(-BOUND + 3.0, BOUND - 3.0)
		if Vector2(x, z).length() < 20.0:
			continue
		if not _flat_open(x, z):
			continue
		if not _clear_of(x, z, 20.0, 14.0):
			continue
		if _mask_at(x, z) > 0.25:
			continue
		if _bilinear(_lat_h, x, z, 3.0, 120) < -0.2 and rng.randf() < 0.8:
			continue
		var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
		var sc := rng.randf_range(0.85, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		var xf := Transform3D(basis, Vector3(x, height_at(x, z) - 0.1, z))
		if not per_kind.has(kind):
			per_kind[kind] = []
		per_kind[kind].append(xf)
		var cr := float(SCATTER_COLLIDERS.get(kind, 0.0))
		if cr > 0.0:
			_props.append(Vector3(x, z, cr * sc))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var counts := {}
	for kind in per_kind:
		var xfs: Array = per_kind[kind]
		counts[kind] = xfs.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _scatter_kind_mesh(kind)
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.custom_aabb = AABB(Vector3(-190, -40, -190), Vector3(380, 120, 380))
		if kind == "bush" or kind == "mushroom":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dress_add(mmi)
	print("C11 scatter zone ", zone, ": ", counts, " of ", attempts, " attempts")

# --------------------------------------------------------- cycle 11 deco
func _deco_atlas(top: Color, accent: Color) -> ImageTexture:
	# Port of the bundle's Md atlas generator (@219470): a 128x32
	# canvas of 16x16 pixel sprites — grass blades, flowers, a
	# mushroom, pebbles, a fern, a skull, tall grass, a moss mound,
	# a twig, an ember, a snow mound — washed from the biome's
	# top[1] and accent colors.
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var light := Color(minf(top.r * 1.3, 1.0), minf(top.g * 1.3, 1.0), minf(top.b * 1.3, 1.0))
	var dark := top * 0.65
	var rng := RandomNumberGenerator.new()
	rng.seed = 4660 * 7 + zone
	for cell in range(16):
		var ox := (cell % 8) * 16
		var oy := (cell / 8) * 16
		match cell:
			0, 1, 2, 3, 10, 11:
				var blades := (4 + cell) if cell < 10 else 9
				var hmax := 14 if cell >= 10 else 11
				for b in range(blades):
					var x0 := 3 + rng.randi_range(0, 9)
					var h := rng.randi_range(5, hmax)
					var lean := rng.randi_range(-1, 1)
					for r in range(h + 1):
						var xx := x0 + (lean if r >= 3 and r % 4 == 3 else 0)
						var c: Color = light if r > h - 3 else (dark if r < 2 else top)
						img.set_pixel(ox + clampi(xx, 0, 15), oy + 15 - r, c)
			4, 5:
				var petal := Color(1, 1, 1) if cell == 4 else accent
				for e in range(7):
					img.set_pixel(ox + 7, oy + 15 - e, dark)
				img.set_pixel(ox + 6, oy + 12, top)
				img.set_pixel(ox + 8, oy + 11, top)
				img.set_pixel(ox + 6, oy + 7, petal)
				img.set_pixel(ox + 8, oy + 7, petal)
				img.set_pixel(ox + 7, oy + 6, petal)
				img.set_pixel(ox + 7, oy + 8, petal)
				img.set_pixel(ox + 7, oy + 7, Color(1.0, 0.86, 0.31))
				img.set_pixel(ox + 3, oy + 15, dark)
				img.set_pixel(ox + 3, oy + 14, top)
				img.set_pixel(ox + 11, oy + 15, dark)
				img.set_pixel(ox + 12, oy + 14, top)
			6:
				for sx in [7, 8]:
					for sy in range(5, 16):
						img.set_pixel(ox + sx, oy + sy, Color(0.96, 0.93, 0.85) if sx == 7 else Color(0.85, 0.80, 0.70))
				for sy in range(7, 11):
					for sx in range(16):
						if absf(float(sx) - 7.5) + float(10 - sy) * 1.2 < 6.0:
							var c := Color(0.89, 0.24, 0.24)
							if (sx + sy) % 5 == 0:
								c = Color(1, 1, 1)
							img.set_pixel(ox + sx, oy + sy, c)
			7:
				for ell in [[5.0, 13.0, 2.5, 1.5], [10.0, 14.0, 2.0, 1.2], [12.0, 11.5, 1.5, 1.0]]:
					for sx in range(16):
						for sy in range(8, 16):
							var q := pow((float(sx) - ell[0]) / ell[2], 2.0) + pow((float(sy) - ell[1]) / ell[3], 2.0)
							if q < 1.0:
								img.set_pixel(ox + sx, oy + sy, Color(0.75, 0.73, 0.69) if float(sy) < ell[1] else Color(0.55, 0.53, 0.50))
			8:
				var alight := Color(minf(accent.r * 1.3, 1.0), minf(accent.g * 1.3, 1.0), minf(accent.b * 1.3, 1.0))
				for sy in range(4, 16):
					var halfw := mini(3, (sy - 3) / 2)
					for dx in range(-halfw, halfw + 1):
						img.set_pixel(ox + 7 + dx, oy + sy, alight if dx < 0 else accent)
			9:
				for sx in range(3, 13):
					for sy in range(8, 16):
						var q := pow((float(sx) - 7.5) / 4.0, 2.0) + pow((float(sy) - 11.5) / 3.0, 2.0)
						if q < 1.0:
							img.set_pixel(ox + sx, oy + sy, Color(0.92, 0.90, 0.84))
				img.set_pixel(ox + 6, oy + 11, Color(0.16, 0.12, 0.20))
				img.set_pixel(ox + 9, oy + 11, Color(0.16, 0.12, 0.20))
				img.set_pixel(ox + 7, oy + 14, Color(0.45, 0.42, 0.40))
				img.set_pixel(ox + 8, oy + 14, Color(0.45, 0.42, 0.40))
			12:
				for sx in range(1, 15):
					for sy in range(6, 16):
						var q := pow((float(sx) - 7.5) / 5.5, 2.0) + pow((float(sy) - 11.0) / 4.5, 2.0)
						if q < 1.0:
							img.set_pixel(ox + sx, oy + sy, light if (sx + sy) % 3 == 0 else top)
				img.set_pixel(ox + 5, oy + 9, Color(0.31, 0.47, 1.0))
				img.set_pixel(ox + 10, oy + 11, Color(0.31, 0.47, 1.0))
				img.set_pixel(ox + 8, oy + 8, Color(0.31, 0.47, 1.0))
			13:
				for sy in range(4, 16):
					var sx := 7 + ((9 - sy) / 2 if sy < 9 else 0)
					img.set_pixel(ox + sx, oy + sy, Color(0.43, 0.33, 0.24))
				img.set_pixel(ox + 5, oy + 8, Color(0.43, 0.33, 0.24))
				img.set_pixel(ox + 4, oy + 7, Color(0.43, 0.33, 0.24))
			14:
				for sx in range(3, 13):
					for sy in range(11, 16):
						if pow(float(sx) - 7.5, 2.0) + pow(float(sy) - 15.0, 2.0) < 14.0:
							img.set_pixel(ox + sx, oy + sy, Color(1.0, 0.63, 0.16) if sy < 13 else Color(0.78, 0.24, 0.08))
			15:
				for sx in range(1, 15):
					for sy in range(10, 16):
						var q := pow((float(sx) - 7.5) / 5.5, 2.0) + pow((float(sy) - 16.0) / 4.7, 2.0)
						if q < 1.0:
							img.set_pixel(ox + sx, oy + sy, Color(1, 1, 1) if sy < 12 else Color(0.82, 0.88, 0.94))
	return ImageTexture.create_from_image(img)

func _deco_quad_mesh(cell: int) -> ArrayMesh:
	# Two crossed 1x1 quads, base at y=0, UV-mapped into the atlas
	# cell (buildDecorations @262019).
	var u0 := float(cell % 8) / 8.0
	var v0 := float(cell / 8) / 2.0
	var cw := 1.0 / 8.0
	var ch := 1.0 / 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var base := 0
	for rot in [0.0, PI * 0.5]:
		var cs := cos(rot)
		var sn := sin(rot)
		var corners := [
			[Vector3(-0.5, 0, 0), Vector2(u0, v0 + ch)],
			[Vector3(0.5, 0, 0), Vector2(u0 + cw, v0 + ch)],
			[Vector3(0.5, 1, 0), Vector2(u0 + cw, v0)],
			[Vector3(-0.5, 1, 0), Vector2(u0, v0)],
		]
		for cn in corners:
			var p: Vector3 = cn[0]
			verts.append(Vector3(p.x * cs, 0, -p.x * sn))
			normals.append(Vector3(sn, 0, cs))
			uvs.append(cn[1])
		idx.append(base)
		idx.append(base + 1)
		idx.append(base + 2)
		idx.append(base)
		idx.append(base + 2)
		idx.append(base + 3)
		base += 4
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return am

func _build_deco() -> void:
	# buildDecorations (@262019): round(7000 * areaMul) sprites,
	# attempts capped at 3x, gated by isFlatOpen, the path mask and
	# a mid-frequency noise mask. (The bundle draws them at scale 1;
	# ours vary 0.8-1.25 for the same reason our scatter varies
	# 0.85-1.3 — noted in DIFF.)
	var zc: Dictionary = ZONES[zone - 1]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _deco_atlas(zc["deco_top"], zc["deco_accent"])
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var slots: Array = zc["deco"]
	var target := int(round(7000.0 * AREA_MUL))
	var rng := RandomNumberGenerator.new()
	rng.seed = (5000 + zone * 131) ^ 4660  # bundle: seed ^ 4660
	var per_type: Dictionary = {}
	var accepted := 0
	var tries := 0
	while accepted < target and tries < target * 3:
		tries += 1
		if _slice_builds and tries % 4096 == 0:
			await get_tree().process_frame
			if _prebuild_abort:
				return
		var x := rng.randf_range(-BOUND, BOUND)
		var z := rng.randf_range(-BOUND, BOUND)
		if not _flat_open(x, z):
			continue
		if _mask_at(x, z) > 0.4:
			continue
		if _bilinear(_lat_e, x, z, 3.0, 120) < -0.05:
			continue
		var ty := int(slots[rng.randi_range(0, slots.size() - 1)])
		var sc := rng.randf_range(0.8, 1.25)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		var xf := Transform3D(basis, Vector3(x, height_at(x, z) - 0.05, z))
		if not per_type.has(ty):
			per_type[ty] = []
		per_type[ty].append(xf)
		accepted += 1
	for ty in per_type:
		var xfs: Array = per_type[ty]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _deco_quad_mesh(ty)
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.custom_aabb = AABB(Vector3(-190, -40, -190), Vector3(380, 120, 380))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dress_add(mmi)
	print("C11 deco zone ", zone, ": accepted ", accepted, " of ", target, " (tries ", tries, ")")

## ------------------------------------------------------- cycle 6 set dressing
## 3D prop kit styled directly on the original's forest atlas art
## (reference/orig_assets/env/forest/atlas.png): the same subjects —
## flower beds, red-cap mushrooms, berry bushes, sunflowers, stumps,
## logs, mossy boulders, fern shrubs, the big oak, a stone arch — as
## outlined, saturated low-poly pieces, placed in authored clusters so
## zone 1 reads as the same dressed diorama (counts in DIFF cycle 6).
var _pk: Dictionary = {}

func _pk_mat(c: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m

func _pk_init() -> void:
	if not _pk.is_empty():
		return
	var hull := StandardMaterial3D.new()
	hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull.albedo_color = Color(0.045, 0.065, 0.035)
	hull.cull_mode = BaseMaterial3D.CULL_FRONT
	_pk["hull"] = hull
	# Cycle 7: leaf palette follows the zone (leaf[0..2] dark->light,
	# dark derived by scaling, matching the forest ratios roughly).
	var zl: Array = ZONES[zone - 1]["leaf"]
	var zbase: Color = zl[1]
	_pk["leaf_light"] = _pk_mat(zl[2])
	_pk["leaf_mid"] = _pk_mat(zbase)
	_pk["leaf_dark"] = _pk_mat(Color(zbase.r * 0.66, zbase.g * 0.72, zbase.b * 0.8))
	_pk["sakura"] = _pk_mat(Color(0.82, 0.44, 0.56))
	_pk["pine"] = _pk_mat(Color(0.10, 0.32, 0.12))
	_pk["bark"] = _pk_mat(Color(0.36, 0.23, 0.11))
	_pk["wood"] = _pk_mat(Color(0.55, 0.38, 0.19))
	_pk["cap_red"] = _pk_mat(Color(0.72, 0.14, 0.10))
	_pk["cap_blue"] = _pk_mat(Color(0.30, 0.62, 0.78), 0.35)
	_pk["cream"] = _pk_mat(Color(0.85, 0.75, 0.55))
	_pk["white"] = _pk_mat(Color(0.92, 0.92, 0.88), 0.25)
	_pk["rock"] = _pk_mat(Color(0.36, 0.37, 0.38))
	_pk["moss"] = _pk_mat(Color(0.25, 0.48, 0.14))
	_pk["berry"] = _pk_mat(Color(0.85, 0.12, 0.12), 0.3)
	_pk["sun_y"] = _pk_mat(Color(0.95, 0.72, 0.15), 0.2)
	_pk["sun_c"] = _pk_mat(Color(0.35, 0.20, 0.08))
	_pk["pink"] = _pk_mat(Color(0.95, 0.45, 0.65), 0.3)
	_pk["blue_f"] = _pk_mat(Color(0.40, 0.60, 1.0), 0.3)
	_pk["yellow_f"] = _pk_mat(Color(1.0, 0.82, 0.25), 0.3)
	# Cycle 8 zone-dressing materials (zones 2-4 have their own mixes:
	# graveyard stone/bone, desert sandstone/cactus, volcano
	# obsidian/lava/char — subjects read off each biome's env atlas).
	_pk["stone_lt"] = _pk_mat(Color(0.60, 0.60, 0.64))
	_pk["bone"] = _pk_mat(Color(0.88, 0.85, 0.76))
	_pk["sand_rock"] = _pk_mat(Color(0.72, 0.58, 0.40))
	_pk["cactus"] = _pk_mat(Color(0.24, 0.52, 0.29))
	# Cycle 9 signature-subject materials (audit §6).
	_pk["grave_purple"] = _pk_mat(Color(0.45, 0.32, 0.55))
	_pk["grave_purple_d"] = _pk_mat(Color(0.30, 0.20, 0.40))
	_pk["agave"] = _pk_mat(Color(0.35, 0.55, 0.50))
	_pk["gold"] = _pk_mat(Color(0.85, 0.65, 0.25), 0.3)
	_pk["flame"] = _pk_mat(Color(1.0, 0.75, 0.30), 1.2)
	_pk["char"] = _pk_mat(Color(0.10, 0.09, 0.09))
	_pk["lava"] = _pk_mat(Color(1.0, 0.42, 0.08), 1.5)
	var obs := StandardMaterial3D.new()
	obs.albedo_color = Color(0.07, 0.07, 0.11)
	obs.metallic = 0.35
	obs.roughness = 0.35
	_pk["obsidian"] = obs
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 12
	blob.rings = 6
	_pk["blob"] = blob
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 8
	dot.rings = 4
	_pk["dot"] = dot
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 0.8
	cone.radial_segments = 6
	_pk["cone"] = cone

func _pk_hull(mi: MeshInstance3D, grow: float = 1.07) -> void:
	var h := MeshInstance3D.new()
	h.mesh = mi.mesh
	h.material_override = _pk["hull"]
	h.scale = Vector3.ONE * grow
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(h)

func _pk_part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3, hull: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	if hull:
		_pk_hull(mi)
	return mi

func _mk_flower_bed(mats: Array) -> Node3D:
	var n := Node3D.new()
	var mound_mesh := CylinderMesh.new()
	mound_mesh.top_radius = 1.02
	mound_mesh.bottom_radius = 1.15
	mound_mesh.height = 0.24
	mound_mesh.radial_segments = 12
	_pk_part(n, mound_mesh, _pk["leaf_dark"], Vector3(0, 0.10, 0), Vector3.ONE)
	var cnt := _rng.randi_range(10, 14)
	for i in range(cnt):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 0.85
		var s := _rng.randf_range(0.09, 0.14)
		_pk_part(n, _pk["dot"], mats[i % mats.size()],
			Vector3(cos(a) * r, 0.26 + _rng.randf_range(0.0, 0.08), sin(a) * r), Vector3.ONE * s)
	return n

func _mk_mushrooms(cap_mat: Material) -> Node3D:
	var n := Node3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.075
	stem_mesh.bottom_radius = 0.10
	stem_mesh.height = 0.36
	stem_mesh.radial_segments = 7
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.0
	cap_mesh.height = 2.0
	cap_mesh.radial_segments = 10
	cap_mesh.rings = 5
	# Spot positions sit ON the unit cap sphere (upper hemisphere).
	var spots := [Vector3(0, 0.97, 0.1), Vector3(0.52, 0.80, 0.28), Vector3(-0.48, 0.83, -0.24), Vector3(0.30, 0.84, -0.46)]
	for k in range(_rng.randi_range(3, 5)):
		var ox := _rng.randf_range(-0.42, 0.42)
		var oz := _rng.randf_range(-0.42, 0.42)
		var cs := _rng.randf_range(0.20, 0.34)
		_pk_part(n, stem_mesh, _pk["cream"], Vector3(ox, 0.17, oz), Vector3(1, _rng.randf_range(0.8, 1.25), 1))
		var cap := _pk_part(n, cap_mesh, cap_mat, Vector3(ox, 0.36, oz), Vector3(cs, cs * 0.55, cs), k == 0)
		for sp in spots:
			if _rng.randf() < 0.3:
				continue
			_pk_part(cap, _pk["dot"], _pk["white"], sp * 0.92, Vector3.ONE * 0.30)
	return n

func _mk_berry_bush() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["leaf_dark"], Vector3(0, 0.52, 0), Vector3(0.78, 0.58, 0.78), true)
	_pk_part(n, _pk["blob"], _pk["leaf_mid"], Vector3(0.5, 0.38, 0.25), Vector3(0.5, 0.4, 0.5))
	_pk_part(n, _pk["blob"], _pk["leaf_mid"], Vector3(-0.48, 0.40, -0.2), Vector3(0.46, 0.38, 0.46))
	for i in range(13):
		var a := _rng.randf() * TAU
		var e := _rng.randf_range(0.15, 1.1)
		var rr := 0.72
		var pos := Vector3(cos(a) * cos(e) * rr, 0.52 + sin(e) * 0.5, sin(a) * cos(e) * rr)
		_pk_part(n, _pk["dot"], _pk["berry"], pos, Vector3.ONE * 0.075)
	return n

func _mk_sunflowers() -> Node3D:
	var n := Node3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.035
	stem_mesh.bottom_radius = 0.05
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 6
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.19
	disc_mesh.bottom_radius = 0.19
	disc_mesh.height = 0.06
	disc_mesh.radial_segments = 10
	for k in range(_rng.randi_range(3, 5)):
		var ox := _rng.randf_range(-0.5, 0.5)
		var oz := _rng.randf_range(-0.5, 0.5)
		var h := _rng.randf_range(0.95, 1.35)
		var stem := _pk_part(n, stem_mesh, _pk["leaf_mid"], Vector3(ox, h * 0.5, oz), Vector3(1, h, 1))
		stem.rotation.z = _rng.randf_range(-0.1, 0.1)
		var head := Node3D.new()
		head.position = Vector3(ox, h + 0.05, oz)
		head.rotation.x = _rng.randf_range(-0.35, -0.1)
		head.rotation.y = _rng.randf() * TAU
		n.add_child(head)
		_pk_part(head, disc_mesh, _pk["sun_y"], Vector3.ZERO, Vector3.ONE)
		_pk_part(head, _pk["dot"], _pk["sun_c"], Vector3(0, 0.045, 0), Vector3(0.11, 0.05, 0.11))
	return n

func _mk_stump() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.40
	trunk_mesh.bottom_radius = 0.50
	trunk_mesh.height = 0.52
	trunk_mesh.radial_segments = 10
	_pk_part(n, trunk_mesh, _pk["bark"], Vector3(0, 0.26, 0), Vector3.ONE, true)
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.40
	top_mesh.bottom_radius = 0.40
	top_mesh.height = 0.05
	top_mesh.radial_segments = 10
	_pk_part(n, top_mesh, _pk["wood"], Vector3(0, 0.53, 0), Vector3.ONE)
	return n

func _mk_log() -> Node3D:
	var n := Node3D.new()
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.26
	log_mesh.bottom_radius = 0.26
	log_mesh.height = 1.5
	log_mesh.radial_segments = 9
	var log := _pk_part(n, log_mesh, _pk["bark"], Vector3(0, 0.27, 0), Vector3.ONE, true)
	log.rotation.z = PI * 0.5
	var end_mesh := CylinderMesh.new()
	end_mesh.top_radius = 0.24
	end_mesh.bottom_radius = 0.24
	end_mesh.height = 0.04
	end_mesh.radial_segments = 9
	for sx in [-0.76, 0.76]:
		var e := _pk_part(n, end_mesh, _pk["wood"], Vector3(sx, 0.27, 0), Vector3.ONE)
		e.rotation.z = PI * 0.5
	_pk_part(n, _pk["blob"], _pk["moss"], Vector3(0.1, 0.5, 0.05), Vector3(0.34, 0.14, 0.3))
	return n

func _mk_boulder(mat: Material = null) -> Node3D:
	var n := Node3D.new()
	var m: Material = mat if mat != null else _pk["rock"]
	_pk_part(n, _pk["blob"], m, Vector3(0, 0.42, 0), Vector3(0.85, 0.62, 0.8), true)
	if mat == null:
		_pk_part(n, _pk["blob"], _pk["moss"], Vector3(0.12, 0.88, 0.08), Vector3(0.5, 0.22, 0.45))
	_pk_part(n, _pk["blob"], m, Vector3(0.72, 0.22, 0.3), Vector3(0.38, 0.3, 0.36))
	return n

# --- Cycle 8 zone prop makers (zones 2-4; subjects from each
# biome's env atlas: graveyard = dead trees/tombstones, desert =
# cacti/sandstone/bones, volcano = charred trunks/obsidian/lava).

func _mk_tombstone() -> Node3D:
	var n := Node3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.95, 0.18, 0.55)
	_pk_part(n, base_mesh, _pk["stone_lt"], Vector3(0, 0.09, 0), Vector3.ONE)
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(0.68, 0.78, 0.15)
	_pk_part(n, slab_mesh, _pk["stone_lt"], Vector3(0, 0.55, 0), Vector3.ONE, true)
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.34
	cap_mesh.bottom_radius = 0.34
	cap_mesh.height = 0.15
	cap_mesh.radial_segments = 12
	var cap := _pk_part(n, cap_mesh, _pk["stone_lt"], Vector3(0, 0.94, 0), Vector3.ONE)
	cap.rotation.x = PI * 0.5
	return n

func _mk_dead_tree() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.20
	trunk_mesh.height = 2.3
	trunk_mesh.radial_segments = 7
	var trunk := _pk_part(n, trunk_mesh, _pk["char"], Vector3(0, 1.15, 0), Vector3.ONE, true)
	trunk.rotation.z = _rng.randf_range(-0.10, 0.10)
	for k in range(3):
		var br := _pk_part(n, _pk["cone"], _pk["char"],
			Vector3(_rng.randf_range(-0.3, 0.3), 1.7 + 0.35 * float(k), _rng.randf_range(-0.3, 0.3)),
			Vector3(0.55, _rng.randf_range(1.1, 1.7), 0.55))
		br.rotation.z = _rng.randf_range(0.6, 1.1) * (1.0 if k % 2 == 0 else -1.0)
		br.rotation.y = _rng.randf() * TAU
	return n

func _mk_bones() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["dot"], _pk["bone"], Vector3(0, 0.16, 0), Vector3(0.24, 0.19, 0.26), true)
	_pk_part(n, _pk["dot"], _pk["char"], Vector3(0.10, 0.20, 0.20), Vector3.ONE * 0.045)
	_pk_part(n, _pk["dot"], _pk["char"], Vector3(-0.10, 0.20, 0.20), Vector3.ONE * 0.045)
	var rib_mesh := CylinderMesh.new()
	rib_mesh.top_radius = 0.035
	rib_mesh.bottom_radius = 0.035
	rib_mesh.height = 1.1
	rib_mesh.radial_segments = 6
	for sx in [-0.45, 0.45]:
		var rib := _pk_part(n, rib_mesh, _pk["bone"], Vector3(sx, 0.05, -0.25), Vector3.ONE)
		rib.rotation.z = PI * 0.5
		rib.rotation.y = _rng.randf_range(-0.3, 0.3)
	return n

func _mk_cactus() -> Node3D:
	var n := Node3D.new()
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.20
	col_mesh.bottom_radius = 0.24
	col_mesh.height = 1.35
	col_mesh.radial_segments = 9
	_pk_part(n, col_mesh, _pk["cactus"], Vector3(0, 0.68, 0), Vector3.ONE, true)
	_pk_part(n, _pk["dot"], _pk["cactus"], Vector3(0, 1.38, 0), Vector3(0.20, 0.16, 0.20))
	_pk_part(n, _pk["dot"], _pk["pink"], Vector3(0, 1.52, 0), Vector3.ONE * 0.07)
	var arm_h := CylinderMesh.new()
	arm_h.top_radius = 0.07
	arm_h.bottom_radius = 0.07
	arm_h.height = 0.42
	arm_h.radial_segments = 7
	var arm_v := CylinderMesh.new()
	arm_v.top_radius = 0.075
	arm_v.bottom_radius = 0.075
	arm_v.height = 0.55
	arm_v.radial_segments = 7
	for side in [-1.0, 1.0]:
		var hy: float = 0.75 + 0.25 * (0.5 + 0.5 * float(side))
		var hseg := _pk_part(n, arm_h, _pk["cactus"], Vector3(side * 0.38, hy, 0), Vector3.ONE)
		hseg.rotation.z = PI * 0.5
		_pk_part(n, arm_v, _pk["cactus"], Vector3(side * 0.58, hy + 0.24, 0), Vector3.ONE)
		_pk_part(n, _pk["dot"], _pk["cactus"], Vector3(side * 0.58, hy + 0.52, 0), Vector3.ONE * 0.075)
	return n

func _mk_dry_shrub() -> Node3D:
	var n := Node3D.new()
	for i in range(5):
		var a := TAU * float(i) / 5.0 + _rng.randf_range(-0.25, 0.25)
		var blade := _pk_part(n, _pk["cone"], _pk["bark"] if i % 2 == 0 else _pk["char"],
			Vector3(cos(a) * 0.20, 0.26, sin(a) * 0.20), Vector3(0.6, _rng.randf_range(0.6, 0.95), 0.6))
		blade.rotation.x = sin(a) * 0.5
		blade.rotation.z = -cos(a) * 0.5
	return n

func _mk_obsidian() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["obsidian"], Vector3(0, 0.62, 0), Vector3(0.62, 1.05, 0.62), true)
	_pk_part(n, _pk["blob"], _pk["obsidian"], Vector3(0.62, 0.34, 0.25), Vector3(0.34, 0.55, 0.34))
	_pk_part(n, _pk["blob"], _pk["obsidian"], Vector3(-0.55, 0.22, -0.2), Vector3(0.26, 0.36, 0.26))
	return n

func _mk_lava_rock() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["char"], Vector3(0, 0.40, 0), Vector3(0.85, 0.60, 0.8), true)
	_pk_part(n, _pk["blob"], _pk["char"], Vector3(0.7, 0.20, 0.3), Vector3(0.36, 0.28, 0.34))
	for k in range(3):
		var a := _rng.randf() * TAU
		_pk_part(n, _pk["dot"], _pk["lava"],
			Vector3(cos(a) * 0.4, 0.86 + _rng.randf_range(-0.06, 0.04), sin(a) * 0.36),
			Vector3(0.16, 0.05, 0.13))
	return n

func _mk_charstump() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.38
	trunk_mesh.bottom_radius = 0.48
	trunk_mesh.height = 0.55
	trunk_mesh.radial_segments = 10
	_pk_part(n, trunk_mesh, _pk["char"], Vector3(0, 0.27, 0), Vector3.ONE, true)
	var spike := _pk_part(n, _pk["cone"], _pk["char"], Vector3(0.12, 0.72, 0.05), Vector3(0.8, 1.1, 0.8))
	spike.rotation.z = 0.25
	return n

func _mk_shrub() -> Node3D:
	var n := Node3D.new()
	for i in range(6):
		var a := TAU * float(i) / 6.0 + _rng.randf_range(-0.2, 0.2)
		var blade := _pk_part(n, _pk["cone"], _pk["leaf_mid"] if i % 2 == 0 else _pk["leaf_dark"],
			Vector3(cos(a) * 0.22, 0.34, sin(a) * 0.22), Vector3(1.15, _rng.randf_range(0.85, 1.2), 1.15))
		blade.rotation.x = sin(a) * 0.38
		blade.rotation.z = -cos(a) * 0.38
	_pk_part(n, _pk["cone"], _pk["leaf_light"], Vector3(0, 0.44, 0), Vector3(1.3, 1.35, 1.3))
	return n

func _mk_sign() -> Node3D:
	var n := Node3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.05, 0.14)
	_pk_part(n, post_mesh, _pk["bark"], Vector3(0, 0.52, 0), Vector3.ONE)
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(0.95, 0.44, 0.09)
	var plank := _pk_part(n, plank_mesh, _pk["wood"], Vector3(0.05, 0.92, 0), Vector3.ONE, true)
	plank.rotation.z = 0.05
	return n

func _mk_arch() -> Node3D:
	var n := Node3D.new()
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.55, 2.3, 0.55)
	for sx in [-1.6, 1.6]:
		_pk_part(n, pillar_mesh, _pk["rock"], Vector3(sx, 1.15, 0), Vector3.ONE, true)
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(3.9, 0.55, 0.6)
	_pk_part(n, lintel_mesh, _pk["rock"], Vector3(0, 2.55, 0), Vector3.ONE, true)
	_pk_part(n, _pk["blob"], _pk["leaf_mid"], Vector3(-1.2, 2.95, 0), Vector3(0.7, 0.35, 0.6))
	_pk_part(n, _pk["blob"], _pk["leaf_light"], Vector3(0.9, 3.0, 0.1), Vector3(0.8, 0.38, 0.65))
	return n

# --- Cycle 9 signature subjects (audit §6): each zone dresses
# from ITS OWN biome atlas — graveyard: obelisk/shrine candles/
# urn/purple trees/bellflowers; desert: hoodoo/Joshua tree/agave/
# prickly pear; volcano: lava crystals/fireflowers. ---
func _mk_obelisk() -> Node3D:
	var n := Node3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.1, 0.3, 1.1)
	_pk_part(n, base_mesh, _pk["stone_lt"], Vector3(0, 0.15, 0), Vector3.ONE, true)
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.30
	col_mesh.bottom_radius = 0.48
	col_mesh.height = 2.3
	col_mesh.radial_segments = 4
	var col := _pk_part(n, col_mesh, _pk["stone_lt"], Vector3(0, 1.45, 0), Vector3.ONE, true)
	col.rotation.y = PI * 0.25
	_pk_part(n, _pk["dot"], _pk["gold"], Vector3(0, 2.75, 0), Vector3.ONE * 0.16)
	return n

func _mk_urn() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["cream"], Vector3(0, 0.34, 0), Vector3(0.34, 0.42, 0.34), true)
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.30
	rim_mesh.bottom_radius = 0.24
	rim_mesh.height = 0.16
	rim_mesh.radial_segments = 10
	_pk_part(n, rim_mesh, _pk["cream"], Vector3(0, 0.72, 0), Vector3.ONE)
	_pk_part(n, _pk["dot"], _pk["stone_lt"], Vector3(0, 0.88, 0), Vector3.ONE * 0.13)
	return n

func _mk_candles() -> Node3D:
	var n := Node3D.new()
	for k in range(3):
		var h: float = [0.55, 0.38, 0.72][k]
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.065
		cm.height = h
		cm.radial_segments = 7
		var px: float = [0.0, 0.22, -0.20][k]
		var pz: float = [0.0, 0.14, 0.10][k]
		_pk_part(n, cm, _pk["cream"], Vector3(px, h * 0.5, pz), Vector3.ONE)
		_pk_part(n, _pk["dot"], _pk["flame"], Vector3(px, h + 0.07, pz), Vector3(0.045, 0.075, 0.045))
	return n

func _mk_purpletree() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.20
	trunk_mesh.height = 1.9
	trunk_mesh.radial_segments = 7
	_pk_part(n, trunk_mesh, _pk["char"], Vector3(0, 0.95, 0), Vector3.ONE, true)
	_pk_part(n, _pk["blob"], _pk["grave_purple"], Vector3(0, 2.15, 0), Vector3(0.85, 0.62, 0.85))
	_pk_part(n, _pk["blob"], _pk["grave_purple_d"], Vector3(0.55, 1.8, 0.2), Vector3(0.5, 0.4, 0.5))
	_pk_part(n, _pk["blob"], _pk["grave_purple_d"], Vector3(-0.5, 1.9, -0.25), Vector3(0.45, 0.36, 0.45))
	return n

func _mk_willow() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = 2.6
	trunk_mesh.radial_segments = 7
	var trunk := _pk_part(n, trunk_mesh, _pk["char"], Vector3(0, 1.3, 0), Vector3.ONE, true)
	trunk.rotation.z = 0.08
	_pk_part(n, _pk["blob"], _pk["grave_purple_d"], Vector3(0, 2.8, 0), Vector3(1.05, 0.5, 1.05))
	for i in range(7):
		var a := TAU * float(i) / 7.0
		var drop := _pk_part(n, _pk["cone"], _pk["grave_purple"],
			Vector3(cos(a) * 0.85, 2.05, sin(a) * 0.85), Vector3(0.8, 1.5, 0.8))
		drop.rotation.x = PI + sin(a) * 0.25
		drop.rotation.z = -cos(a) * 0.25
	return n

func _mk_bellflowers() -> Node3D:
	var n := Node3D.new()
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.02
	bell_mesh.bottom_radius = 0.10
	bell_mesh.height = 0.18
	bell_mesh.radial_segments = 7
	for i in range(6):
		var a := TAU * float(i) / 6.0 + _rng.randf_range(-0.3, 0.3)
		var px := cos(a) * _rng.randf_range(0.1, 0.35)
		var pz := sin(a) * _rng.randf_range(0.1, 0.35)
		var h := _rng.randf_range(0.4, 0.65)
		var stem := _pk_part(n, _pk["cone"], _pk["leaf_dark"], Vector3(px, h * 0.5, pz), Vector3(0.22, h / 0.8, 0.22))
		stem.rotation.x = sin(a) * 0.2
		_pk_part(n, bell_mesh, _pk["grave_purple"], Vector3(px, h + 0.05, pz), Vector3.ONE)
	return n

func _mk_hoodoo() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["sand_rock"], Vector3(0, 0.5, 0), Vector3(0.62, 0.55, 0.58), true)
	_pk_part(n, _pk["blob"], _pk["sand_rock"], Vector3(0.08, 1.25, 0), Vector3(0.44, 0.48, 0.42))
	_pk_part(n, _pk["blob"], _pk["sand_rock"], Vector3(-0.05, 1.9, 0.05), Vector3(0.55, 0.34, 0.5))
	return n

func _mk_joshua() -> Node3D:
	var n := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 1.6
	trunk_mesh.radial_segments = 7
	var trunk := _pk_part(n, trunk_mesh, _pk["bark"], Vector3(0, 0.8, 0), Vector3.ONE, true)
	trunk.rotation.z = 0.12
	for k in range(3):
		var a := TAU * float(k) / 3.0 + 0.5
		var hx := cos(a) * 0.35
		var hz := sin(a) * 0.35
		_pk_part(n, _pk["cone"], _pk["cactus"], Vector3(hx, 1.85, hz), Vector3(1.0, 0.9, 1.0))
		_pk_part(n, _pk["dot"], _pk["cactus"], Vector3(hx, 1.62, hz), Vector3.ONE * 0.17)
	return n

func _mk_agave() -> Node3D:
	var n := Node3D.new()
	for i in range(9):
		var a := TAU * float(i) / 9.0 + _rng.randf_range(-0.15, 0.15)
		var leaf := _pk_part(n, _pk["cone"], _pk["agave"],
			Vector3(cos(a) * 0.24, 0.22, sin(a) * 0.24), Vector3(0.75, _rng.randf_range(0.75, 1.05), 0.75))
		leaf.rotation.x = sin(a) * 0.85
		leaf.rotation.z = -cos(a) * 0.85
	_pk_part(n, _pk["cone"], _pk["agave"], Vector3(0, 0.3, 0), Vector3(0.8, 0.9, 0.8))
	return n

func _mk_pricklypear() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["cactus"], Vector3(0, 0.34, 0), Vector3(0.34, 0.42, 0.14), true)
	_pk_part(n, _pk["blob"], _pk["cactus"], Vector3(0.3, 0.72, 0.05), Vector3(0.26, 0.34, 0.12))
	_pk_part(n, _pk["blob"], _pk["cactus"], Vector3(-0.28, 0.66, -0.04), Vector3(0.24, 0.30, 0.11))
	_pk_part(n, _pk["dot"], _pk["pink"], Vector3(0.3, 1.0, 0.05), Vector3.ONE * 0.06)
	_pk_part(n, _pk["dot"], _pk["sun_y"], Vector3(-0.28, 0.92, -0.04), Vector3.ONE * 0.05)
	return n

func _mk_lavacrystal() -> Node3D:
	var n := Node3D.new()
	_pk_part(n, _pk["blob"], _pk["char"], Vector3(0, 0.18, 0), Vector3(0.55, 0.3, 0.5), true)
	for k in range(3):
		var a := TAU * float(k) / 3.0 + 0.4
		var cr := _pk_part(n, _pk["cone"], _pk["obsidian"],
			Vector3(cos(a) * 0.22, float([1.0, 0.7, 0.55][k]), sin(a) * 0.22),
			Vector3(1.5, float([2.4, 1.7, 1.3][k]), 1.5))
		cr.rotation.x = sin(a) * 0.3
		cr.rotation.z = -cos(a) * 0.3
	_pk_part(n, _pk["dot"], _pk["lava"], Vector3(0, 0.42, 0), Vector3(0.14, 0.08, 0.14))
	return n

func _mk_fireflowers() -> Node3D:
	var n := Node3D.new()
	for i in range(6):
		var a := TAU * float(i) / 6.0 + _rng.randf_range(-0.3, 0.3)
		var px := cos(a) * _rng.randf_range(0.08, 0.3)
		var pz := sin(a) * _rng.randf_range(0.08, 0.3)
		var h := _rng.randf_range(0.45, 0.7)
		_pk_part(n, _pk["cone"], _pk["char"], Vector3(px, h * 0.5, pz), Vector3(0.2, h / 0.8, 0.2))
		_pk_part(n, _pk["dot"], _pk["flame"] if i % 2 == 0 else _pk["lava"], Vector3(px, h + 0.06, pz), Vector3.ONE * 0.075)
	return n

func _place_dressing(kind: String, x: float, z: float, sc: float, collider: float) -> void:
	var node: Node3D
	match kind:
		"flowersA":
			node = _mk_flower_bed([_pk["white"], _pk["yellow_f"]])
		"flowersB":
			node = _mk_flower_bed([_pk["pink"], _pk["blue_f"], _pk["yellow_f"], _pk["white"]])
		"mushrooms":
			node = _mk_mushrooms(_pk["cap_red"])
		"glowshrooms":
			node = _mk_mushrooms(_pk["cap_blue"])
		"berry":
			node = _mk_berry_bush()
		"sunflowers":
			node = _mk_sunflowers()
		"stump":
			node = _mk_stump()
		"log":
			node = _mk_log()
		"boulder":
			node = _mk_boulder()
		"sandboulder":
			node = _mk_boulder(_pk["sand_rock"])
		"shrub":
			node = _mk_shrub()
		"sign":
			node = _mk_sign()
		"arch":
			node = _mk_arch()
		"tombstone":
			node = _mk_tombstone()
		"deadtree":
			node = _mk_dead_tree()
		"bones":
			node = _mk_bones()
		"cactus":
			node = _mk_cactus()
		"dryshrub":
			node = _mk_dry_shrub()
		"obsidian":
			node = _mk_obsidian()
		"lavarock":
			node = _mk_lava_rock()
		"charstump":
			node = _mk_charstump()
		"obelisk":
			node = _mk_obelisk()
		"urn":
			node = _mk_urn()
		"candles":
			node = _mk_candles()
		"purpletree":
			node = _mk_purpletree()
		"willow":
			node = _mk_willow()
		"bellflowers":
			node = _mk_bellflowers()
		"hoodoo":
			node = _mk_hoodoo()
		"joshua":
			node = _mk_joshua()
		"agave":
			node = _mk_agave()
		"pricklypear":
			node = _mk_pricklypear()
		"lavacrystal":
			node = _mk_lavacrystal()
		"fireflowers":
			node = _mk_fireflowers()
		_:
			return
	node.name = kind
	node.set_meta("kind", kind)  # sibling name uniquification hides dupes; meta is the reliable tag
	node.position = Vector3(x, height_at(x, z) - 0.03, z)
	node.rotation.y = _rng.randf() * TAU
	node.scale = Vector3.ONE * sc
	_dress_add(node)
	if collider > 0.0:
		_props.append(Vector3(x, z, collider * sc))

## Authored clusters tiling zone 1 (spawn basin rim, corridor sides,
## altar ring, bluff feet) + a density fill — positions mirror the
## original's spawn-frame arrangement (cliff west, pads NE, beds and
## bushes ringing the basin). Exact spawn/altar clearings stay clean.
func _build_set_dressing() -> void:
	_pk_init()
	# Cycle 8: each zone dresses from its OWN prop mix (the cycle-7
	# residual was one shared "common" set in all four zones). Zone
	# 1's authored list below is the frozen cycle-6 set; zones 2-4
	# reuse the same proven positions with biome-appropriate kinds
	# (subjects from each biome's env atlas).
	if zone != 1:
		_build_set_dressing_zone()
		return
	var set_list := [
		# spawn basin rim
		["flowersB", -7.5, 13.5, 1.1, 0.0], ["mushrooms", -11.0, 2.0, 1.1, 0.0],
		["boulder", -12.5, 10.0, 1.1, 0.8], ["stump", -9.0, -1.0, 1.0, 0.45],
		["berry", 8.5, 12.0, 1.1, 0.0], ["sign", 4.5, -1.5, 1.0, 0.25],
		["flowersA", 11.0, 4.0, 1.1, 0.0], ["shrub", -5.0, 15.5, 1.2, 0.0],
		["shrub", 6.0, 17.5, 1.1, 0.0], ["sunflowers", 13.0, 9.0, 1.1, 0.0],
		["log", 12.5, -2.0, 1.0, 0.7],
		# corridor sides (altar approach)
		["flowersB", -6.5, -9.0, 1.0, 0.0], ["berry", 7.0, -12.0, 1.05, 0.0],
		["shrub", -7.5, -15.0, 1.2, 0.0], ["mushrooms", 6.0, -18.0, 1.0, 0.0],
		["stump", -6.0, -21.0, 1.0, 0.45], ["sunflowers", 7.5, -24.0, 1.05, 0.0],
		["flowersA", 6.5, -27.5, 1.0, 0.0], ["berry", -7.0, -28.0, 1.05, 0.0],
		["arch", 0.0, -19.0, 1.0, 0.0],
		# altar ring
		["mushrooms", -11.0, -37.0, 1.1, 0.0], ["berry", 10.5, -22.5, 1.1, 0.0],
		["boulder", 14.0, -24.0, 1.0, 0.8], ["shrub", -14.0, -34.0, 1.2, 0.0],
		["glowshrooms", -12.0, -20.0, 1.0, 0.0],
		# west bluff feet + pad rims
		["boulder", -13.0, -14.0, 1.2, 0.85], ["shrub", -12.5, -6.0, 1.2, 0.0],
		["shrub", -12.8, 24.0, 1.1, 0.0], ["sunflowers", 19.5, -9.5, 1.0, 0.0],
		["boulder", 23.5, -20.5, 1.0, 0.8],
	]
	for e in set_list:
		_place_dressing(String(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4]))
	# Arch pillars collide (the arch itself stands over the path).
	_props.append(Vector3(-1.6, -19.0, 0.55))
	_props.append(Vector3(1.6, -19.0, 0.55))
	# Density fill: small set pieces across the inner zone so any camera
	# position in zone 1 holds ~a dozen dressed objects in frame.
	var kinds := ["shrub", "shrub", "flowersA", "flowersB", "berry", "mushrooms", "shrub", "flowersB"]
	var placed_pos: Array = []
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 1500:
		tries += 1
		var a := _rng.randf() * TAU
		var r := 14.0 + 42.0 * sqrt(_rng.randf())
		var x := SPAWN_XZ.x + cos(a) * r
		var z := SPAWN_XZ.y + sin(a) * r - 8.0
		if not _clear_of(x, z, 6.5, 12.0) or not _slope_ok(x, z):
			continue
		var ok := true
		for pp in placed_pos:
			if Vector2(x - pp.x, z - pp.y).length() < 2.4:
				ok = false
				break
		if not ok:
			continue
		placed_pos.append(Vector2(x, z))
		_place_dressing(kinds[placed % kinds.size()], x, z, _rng.randf_range(0.85, 1.25), 0.0)
		placed += 1

## Zones 2-4 set dressing (cycle 8): same placement skeleton as
## zone 1 (spawn rim / corridor / altar ring / bluff feet), biome
## kinds. The stone arch stays as the corridor gate in the
## graveyard; the desert and volcano go without it.
const ZONE_SETS := {
	# Cycle 9 (audit §6): forest leaks REMOVED from zones 2-4 —
	# no sign, no log, no vine arch, no spiky shrub, and no bones
	# in the graveyard (the audit flagged bones there explicitly;
	# desert bones are the atlas's skull/ribcage and stay). Each
	# zone gains its atlas signatures: graveyard obelisk/candles/
	# urn/purple tree/willow/bellflowers; desert hoodoo/Joshua/
	# agave/prickly pear; volcano lava crystal/fireflowers.
	2: [
		["glowshrooms", -7.5, 13.5, 1.1, 0.0], ["tombstone", -11.0, 2.0, 1.1, 0.35],
		["boulder", -12.5, 10.0, 1.1, 0.8], ["deadtree", -9.0, -1.0, 1.0, 0.45],
		["candles", 8.5, 12.0, 1.1, 0.0], ["tombstone", 4.5, -1.5, 1.0, 0.35],
		["glowshrooms", 11.0, 4.0, 1.1, 0.0], ["deadtree", -5.0, 15.5, 1.2, 0.4],
		["purpletree", 6.0, 17.5, 1.1, 0.4], ["tombstone", 13.0, 9.0, 1.1, 0.35],
		["urn", 12.5, -2.0, 1.0, 0.0],
		["tombstone", -6.5, -9.0, 1.0, 0.35], ["bellflowers", 7.0, -12.0, 1.05, 0.0],
		["deadtree", -7.5, -15.0, 1.2, 0.4], ["glowshrooms", 6.0, -18.0, 1.0, 0.0],
		["deadtree", -6.0, -21.0, 1.0, 0.45], ["tombstone", 7.5, -24.0, 1.05, 0.35],
		["glowshrooms", 6.5, -27.5, 1.0, 0.0], ["candles", -7.0, -28.0, 1.05, 0.0],
		["tombstone", -2.2, -19.0, 1.15, 0.4], ["tombstone", 2.2, -19.0, 1.15, 0.4],
		["obelisk", -11.0, -37.0, 1.1, 0.6], ["urn", 10.5, -22.5, 1.1, 0.0],
		["boulder", 14.0, -24.0, 1.0, 0.8], ["willow", -14.0, -34.0, 1.2, 0.45],
		["glowshrooms", -12.0, -20.0, 1.0, 0.0],
		["boulder", -13.0, -14.0, 1.2, 0.85], ["deadtree", -12.5, -6.0, 1.2, 0.4],
		["purpletree", -12.8, 24.0, 1.1, 0.4], ["tombstone", 19.5, -9.5, 1.0, 0.35],
		["boulder", 23.5, -20.5, 1.0, 0.8],
	],
	3: [
		["cactus", -7.5, 13.5, 1.1, 0.4], ["sandboulder", -11.0, 2.0, 1.1, 0.8],
		["sandboulder", -12.5, 10.0, 1.1, 0.8], ["dryshrub", -9.0, -1.0, 1.0, 0.0],
		["bones", 8.5, 12.0, 1.1, 0.0], ["joshua", 4.5, -1.5, 1.0, 0.4],
		["agave", 11.0, 4.0, 1.1, 0.0], ["cactus", -5.0, 15.5, 1.2, 0.4],
		["dryshrub", 6.0, 17.5, 1.1, 0.0], ["cactus", 13.0, 9.0, 1.1, 0.4],
		["hoodoo", 12.5, -2.0, 1.0, 0.8],
		["dryshrub", -6.5, -9.0, 1.0, 0.0], ["bones", 7.0, -12.0, 1.05, 0.0],
		["cactus", -7.5, -15.0, 1.2, 0.4], ["sandboulder", 6.0, -18.0, 1.0, 0.8],
		["pricklypear", -6.0, -21.0, 1.0, 0.0], ["cactus", 7.5, -24.0, 1.05, 0.4],
		["dryshrub", 6.5, -27.5, 1.0, 0.0], ["bones", -7.0, -28.0, 1.05, 0.0],
		["hoodoo", -11.0, -37.0, 1.1, 0.8], ["bones", 10.5, -22.5, 1.1, 0.0],
		["sandboulder", 14.0, -24.0, 1.0, 0.8], ["joshua", -14.0, -34.0, 1.2, 0.4],
		["bones", -12.0, -20.0, 1.0, 0.0],
		["sandboulder", -13.0, -14.0, 1.2, 0.85], ["dryshrub", -12.5, -6.0, 1.2, 0.0],
		["agave", -12.8, 24.0, 1.1, 0.0], ["cactus", 19.5, -9.5, 1.0, 0.4],
		["sandboulder", 23.5, -20.5, 1.0, 0.8],
	],
	4: [
		["obsidian", -7.5, 13.5, 1.1, 0.7], ["lavarock", -11.0, 2.0, 1.1, 0.8],
		["lavarock", -12.5, 10.0, 1.1, 0.8], ["charstump", -9.0, -1.0, 1.0, 0.45],
		["obsidian", 8.5, 12.0, 1.1, 0.7], ["lavacrystal", 4.5, -1.5, 1.0, 0.5],
		["fireflowers", 11.0, 4.0, 1.1, 0.0], ["obsidian", -5.0, 15.5, 1.2, 0.7],
		["fireflowers", 6.0, 17.5, 1.1, 0.0], ["lavarock", 13.0, 9.0, 1.1, 0.8],
		["charstump", 12.5, -2.0, 1.0, 0.45],
		["lavarock", -6.5, -9.0, 1.0, 0.8], ["obsidian", 7.0, -12.0, 1.05, 0.7],
		["charstump", -7.5, -15.0, 1.2, 0.45], ["lavarock", 6.0, -18.0, 1.0, 0.8],
		["dryshrub", -6.0, -21.0, 1.0, 0.0], ["obsidian", 7.5, -24.0, 1.05, 0.7],
		["lavarock", 6.5, -27.5, 1.0, 0.8], ["charstump", -7.0, -28.0, 1.05, 0.45],
		["lavacrystal", -11.0, -37.0, 1.1, 0.5], ["lavarock", 10.5, -22.5, 1.1, 0.8],
		["lavarock", 14.0, -24.0, 1.0, 0.8], ["charstump", -14.0, -34.0, 1.2, 0.45],
		["obsidian", -12.0, -20.0, 1.0, 0.7],
		["lavarock", -13.0, -14.0, 1.2, 0.85], ["dryshrub", -12.5, -6.0, 1.2, 0.0],
		["fireflowers", -12.8, 24.0, 1.1, 0.0], ["obsidian", 19.5, -9.5, 1.0, 0.7],
		["lavarock", 23.5, -20.5, 1.0, 0.8],
	],
}
const ZONE_FILLS := {
	2: ["tombstone", "glowshrooms", "bellflowers", "purpletree", "candles", "urn", "tombstone", "glowshrooms"],
	3: ["cactus", "dryshrub", "sandboulder", "bones", "agave", "cactus", "pricklypear", "bones"],
	4: ["obsidian", "lavarock", "charstump", "fireflowers", "lavarock", "obsidian", "lavacrystal", "lavarock"],
}

func _build_set_dressing_zone() -> void:
	for e in ZONE_SETS[zone]:
		_place_dressing(String(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4]))
	# Cycle 9: the graveyard's old arch colliders are gone with the
	# arch — zone 2's corridor gate is now two tombstones whose
	# colliders ride their ZONE_SETS entries.
	var kinds: Array = ZONE_FILLS[zone]
	var placed_pos: Array = []
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 1500:
		tries += 1
		var a := _rng.randf() * TAU
		var r := 14.0 + 42.0 * sqrt(_rng.randf())
		var x := SPAWN_XZ.x + cos(a) * r
		var z := SPAWN_XZ.y + sin(a) * r - 8.0
		if not _clear_of(x, z, 6.5, 12.0) or not _slope_ok(x, z):
			continue
		var ok := true
		for pp in placed_pos:
			if Vector2(x - pp.x, z - pp.y).length() < 2.4:
				ok = false
				break
		if not ok:
			continue
		placed_pos.append(Vector2(x, z))
		_place_dressing(String(kinds[placed % kinds.size()]), x, z, _rng.randf_range(0.85, 1.25), 0.0)
		placed += 1

## Cycle 5: instanced grass-tuft field (MultiMesh, one draw call). The
## original dresses the whole visible field with spiky tuft clumps; the
## per-node cones above (~200) are too sparse at gameplay distance. 900
## instanced tufts, denser inside the play area, give the silhouette
## layer on top of the shader's painted tuft pattern.
# ---------------------------------------------------------------- altar etc
func _build_altar() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.48, 0.52)
	var pedestal := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 1.9
	pc.bottom_radius = 2.4
	pc.height = 1.1
	pedestal.mesh = pc
	pedestal.material_override = stone
	pedestal.position = altar_pos + Vector3(0, 0.55, 0)
	add_child(pedestal)
	_props.append(Vector3(ALTAR_XZ.x, ALTAR_XZ.y, 2.7))

	_crystal = Node3D.new()
	_crystal.position = altar_pos + Vector3(0, 2.6, 0)
	_crystal_base_y = _crystal.position.y
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.3, 0.95, 0.9)
	cmat.emission_enabled = true
	cmat.emission = Color(0.3, 0.95, 0.9)
	cmat.emission_energy_multiplier = 1.6
	for j in range(2):
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.75
		cm.height = 1.5
		cone.mesh = cm
		cone.material_override = cmat
		cone.position.y = 0.75 if j == 0 else -0.75
		if j == 1:
			cone.rotation_degrees.x = 180.0
		_crystal.add_child(cone)
	add_child(_crystal)

	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.7
	tm.outer_radius = 3.15
	_ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.6, 0.15)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.55, 0.1)
	rmat.emission_energy_multiplier = 1.2
	_ring.material_override = rmat
	_ring.rotation_degrees.x = 90.0
	_ring.position = altar_pos + Vector3(0, 0.07, 0)
	add_child(_ring)

	_altar_label = Label3D.new()
	_altar_label.text = "Boss 祭坛 · 按 E 召唤守护者"  # P1.1: _touch_text_sync
	_altar_label.font = _font_display
	_altar_label.font_size = 72
	_altar_label.modulate = Color(1.0, 0.85, 0.4)
	_altar_label.outline_size = 10
	_altar_label.outline_modulate = Color(UiTheme.INK_DEEP.r, UiTheme.INK_DEEP.g, UiTheme.INK_DEEP.b, 0.95)
	_altar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_altar_label.position = altar_pos + Vector3(0, 5.0, 0)
	add_child(_altar_label)

func _open_portal() -> void:
	var pxz := ALTAR_XZ + Vector2(0, 6.5)
	var py := height_at(pxz.x, pxz.y)
	portal_node = Node3D.new()
	portal_node.position = Vector3(pxz.x, py + 1.9, pxz.y)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.95
	ring.mesh = tm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.75, 0.4, 1.0)
	pm.emission_enabled = true
	pm.emission = Color(0.7, 0.35, 1.0)
	pm.emission_energy_multiplier = 2.2
	ring.material_override = pm
	portal_node.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.4, 1.0)
	light.light_energy = 1.6
	light.omni_range = 9.0
	portal_node.add_child(light)
	add_child(portal_node)

# ---------------------------------------------------------------------- HUD
## U1 1:1 (dark HUD): `dark` keeps an authored dark face — the
## cream substitution below is the menu language, not the HUD's.
func _style(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0, dark: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg if dark else (UiTheme.CREAM if UiTheme.luminance(bg) < 0.32 and bg.a > 0.4 else bg)
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	return s

func _panel(parent: Node, pos: Vector2, sz: Vector2, bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0, dark: bool = false) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", _style(bg, radius, border, bw, dark))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _mk_label(parent: Node, text: String, size: int, color: Color = Color.WHITE, raw: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	# U1 1:1 (dark HUD): `raw` keeps an authored light color —
	# text_color() would turn it into dark ink for cream faces.
	l.add_theme_color_override("font_color", color if raw else UiTheme.text_color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Cycle 17: display-face label (Fredoka / Smiley stack) for
## titles, big numbers and card headings.
func _mk_dlabel(parent: Node, text: String, size: int, color: Color = Color.WHITE, raw: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_display)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color if raw else UiTheme.text_color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Cycle 17: blessing-stat -> icon name (UiIcon set).
func _stat_icon(stat: String) -> String:
	match stat:
		"damage": return "sword"
		"attackSpeed": return "wind"
		"maxHp": return "heart"
		"moveSpeed": return "speed"
		"critChance": return "crit"
		"area": return "area"
		"xpGain": return "up"
		"regen": return "plus"
		"armor": return "shield"
		"luck": return "luck"
		"duration": return "hourglass"
		"statusChance": return "spark"
	return "spark"

## Cycle 17: move-type -> icon name for draft card top zones.
func _type_icon(t: String) -> String:
	match t:
		"fire": return "flame"
		"water": return "drop"
		"grass": return "leaf"
		"electric": return "bolt"
	return "spark"

## Icon order 2: the move tile for a type (badges/move_<type>.png,
## one per type, S08 style). Unknown types fall back to normal.
func _move_icon(t: String) -> String:
	var k := t.to_lower()
	if k == "" or not ResourceLoader.exists("res://assets/ui/badges/move_%s.png" % k):
		k = "normal"
	return "move_" + k

func _label_in(parent: Node, text: String, pos: Vector2, sz: Vector2, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, raw: bool = false) -> Label:
	var l := _mk_label(parent, text, size, color, raw)
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _make_chip(text: String, bg: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(46, 20)
	p.add_theme_stylebox_override("panel", _style(bg, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cycle 19 (audit punch #10): ink text on light faces.
	var l := _mk_label(p, text, 12, UiTheme.readable_fg(bg))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return p

func _build_hud() -> void:
	# UI-mobile P5: the modal family's phone form is chosen at
	# build (the builders switch container parameters on it).
	_p5_on = _phone_factor() > 1.01
	if _p5_on:
		get_tree().node_added.connect(_p5_node_added)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# Cycle 18: the adaptation layer. Everything built below
	# hangs on _ui_root (inset by the display safe area, §2.11);
	# only the touch layer stays on the outer root and takes
	# the same insets directly (its joystick math is
	# viewport-space).
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ui_root)
	var outer_root := root
	root = _ui_root
	# ui.damageFlash (cycle 9, audit §2): the original flashes a red
	# overlay when the player is hurt (@821025). A fullscreen rect
	# under everything else in the HUD; alpha is driven in _process.
	_dmg_flash_rect = ColorRect.new()
	_dmg_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_flash_rect.color = Color(0.85, 0.08, 0.05, 0.0)
	_dmg_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dmg_flash_rect)
	# Cycle 13: ultLook atmosphere grade (@1453942) — a fullscreen
	# tint toward the ult's colour for active + .3 s; our
	# approximation of their graded post pass.
	_ult_look_rect = ColorRect.new()
	_ult_look_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ult_look_rect.color = Color(1, 1, 1, 0)
	_ult_look_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ult_look_rect)
	# Cycle 13: the ult cut-in band (ui.ultCutIn @2011156): the
	# starter's medal + "必杀技！" + the ult's name in the type
	# colour, auto-removed after 1.3 s.
	_cutin_panel = Panel.new()
	_cutin_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cutin_panel.offset_left = -230
	_cutin_panel.offset_right = 230
	_cutin_panel.offset_top = 120
	_cutin_panel.offset_bottom = 184
	_cutin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_panel.visible = false
	# Cycle 17: the cut-in band gets a real glass stylebox (it
	# shipped as a bare default-gray Panel through cycle 16).
	# 对齐定稿 S23_v1.jpg：必杀切入横幅改用深翠青发光圆角大胶囊＋对称装饰嫩叶＋居中粗白立体标题
	_cutin_panel.add_theme_stylebox_override("panel", UiTheme.dark_glass(32, 0.92, Color("48e2c4"), 2, 0))
	root.add_child(_cutin_panel)
	var cl_l := UiTheme.art("leaf_sprig", Vector2(28, 28))
	cl_l.position = Vector2(24, 18)
	cl_l.flip_h = true
	cl_l.modulate = Color("64f5cc")
	cl_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_panel.add_child(cl_l)
	var cl_r := UiTheme.art("leaf_sprig", Vector2(28, 28))
	cl_r.position = Vector2(408, 18)
	cl_r.modulate = Color("64f5cc")
	cl_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_panel.add_child(cl_r)
	var cutin_t := _label_in(_cutin_panel, "必杀技！", Vector2(0, 4), Vector2(460, 28), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	cutin_t.add_theme_font_override("font", _font_display)
	cutin_t.add_theme_color_override("font_shadow_color", Color(0.02, 0.16, 0.18, 0.85))
	cutin_t.add_theme_constant_override("shadow_offset_y", 2)
	_cutin_name = _label_in(_cutin_panel, "", Vector2(0, 32), Vector2(460, 28), 19, Color("72ffe2"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_cutin_name.add_theme_font_override("font", _font_display)
	_cutin_name.add_theme_color_override("font_shadow_color", Color(0.02, 0.16, 0.18, 0.85))
	_cutin_name.add_theme_constant_override("shadow_offset_y", 2)

	# --- top-left: portrait medallion + glass info panel ---
	# Cycle 17 (UI_SPEC §2.3 tl-medal): the medallion carries
	# the species' baked portrait disc with the XP RING swept
	# around it (the cycle-7 78x7 sliver is gone); the glyph
	# label remains as the no-portrait fallback. The info
	# plate joins the one deep-ink glass language — the
	# pre-17 white card contradicted every other panel.
	# Cycle 19 hotfix (device overlap): the top-left pieces
	# (medallion, info plate, HP track, party + power rows)
	# were SIBLINGS the scaler grew one by one about their
	# own corners while their positions stayed in design
	# px — at phone factors they grew INTO each other and
	# under the top card. They now live in ONE cluster
	# container at (12,10); children keep design-relative
	# positions, the cluster scales as a unit, and the
	# layout pass (_layout_hud) fits the whole top row.
	_hero_cluster = Control.new()
	_hero_cluster.position = Vector2(12, 10)
	_hero_cluster.size = Vector2(454, 216)
	_hero_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hero_cluster)
	# U1 1:1 round 5: one dark pill behind medallion + Lv badge
	# + HP track (reference U1_final.jpg) — the medallion stays
	# proud of the pill's left edge; phone-only, sized in
	# _p2_hero_box; desktop keeps the bare cluster.
	_hero_plate = Panel.new()
	_hero_plate.position = Vector2(56, 22)
	_hero_plate.size = Vector2(182, 62)
	_hero_plate.add_theme_stylebox_override("panel", UiTheme.hud_glass(31, 0.78, Color(0.88, 0.94, 1.0, 0.62), 2, 0))
	_hero_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_cluster.add_child(_hero_plate)
	_medal_panel = UiMedallion.new()
	_medal_panel.position = Vector2(0, 0)
	# U1 1:1 round 14 (coordinator): medallion 86 -> 108 — at
	# the cluster's true ~2.0 draw scale the 86 disc read
	# 0.073 of frame width against the reference's 0.093.
	_medal_panel.size = Vector2(108, 108)
	_medal_panel.medal = STARTER_HUD["bulbasaur"]["medal"]
	_medal_panel.portrait = UiTheme.portrait("bulbasaur")
	_hero_cluster.add_child(_medal_panel)
	_medal_glyph = _label_in(_medal_panel, "妙", Vector2(0, 0), Vector2(108, 108), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_medal_glyph.visible = _medal_panel.portrait == null
	# UI-mobile P3 (plan H1 / D1): on phone a tap on the
	# portrait pauses — the plan put a small "‖" badge on the
	# Lv badge's diagonal (top-left) to say so. U1 1:1 round
	# 10 (main-controller ruling): the reference U1_final.jpg
	# has no such badge, and it is persistent UI in the new
	# phone layout — removed. The node stays (hidden) so the
	# portrait-tap pause itself is untouched.
	_pause_badge = _panel(_medal_panel, Vector2(-2, -2), Vector2(22, 22), Color(0.10, 0.07, 0.20, 0.92), 11, Color(1, 1, 1, 0.45), 1, true)
	_pause_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb_ic := UiIcon.new("pause", Color(1, 1, 1, 0.92), 12)
	pb_ic.position = Vector2(5, 5)
	pb_ic.size = Vector2(12, 12)
	pb_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_badge.add_child(pb_ic)
	_pause_badge.visible = false
	# U1 1:1 round 10 (main-controller ruling): the Lv badge is
	# the reference's DARK chip with white text — round 6's
	# "cream chip" read of U1_final.jpg was wrong (the cream
	# chip under a learned skill slot is the reference's, this
	# one is not). Same rect (61,4,56,26), colours flipped.
	# U1 1:1 round 15 (coordinator): badge (61,4) -> (72,0) so it
	# straddles the grown medallion's top-right rim the way the
	# reference's does, instead of sitting inside the disc.
	# 等级小胶囊：紧贴奖章右肩，深灰蓝磨砂底配亮银细边框（r+g+b < 0.9 兼容 P3 校验）
	var lv_badge := _panel(_hero_cluster, Vector2(72, 2), Vector2(56, 24), Color(0.18, 0.22, 0.28, 0.88), 12, Color(0.88, 0.94, 1.0, 0.72), 1.5, true)
	_lv_label = _label_in(lv_badge, "1级", Vector2(0, 0), Vector2(56, 24), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	var info := Panel.new()
	_hero_info = info
	info.position = Vector2(94, 4)
	info.size = Vector2(232, 80)
	info.add_theme_stylebox_override("panel", UiTheme.dark_glass(16, 0.92))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_cluster.add_child(info)
	_hud_name = _label_in(info, "妙蛙种子 Bulbasaur", Vector2(14, 6), Vector2(210, 27), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_hud_name.add_theme_font_override("font", _font_display)
	_hud_chips = HBoxContainer.new()
	_hud_chips.position = Vector2(14, 36)
	_hud_chips.size = Vector2(210, 22)
	_hud_chips.add_theme_constant_override("separation", 6)
	_hud_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_hud_chips)
	# Cycle 21.3 (audit §5): 13 px muted grey on glass was
	# near-illegible — font 14, colour at full alpha
	# (MUTED is Color8, a = 1.0 >= the audit's 0.8 floor).
	_hud_evo = _label_in(info, "› 24级成长", Vector2(14, 58), Vector2(210, 18), 14, UiTheme.HUD_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	# Player HP bar (cycle 10): the original's .bar.hpbar lives in
	# the plate's under-row (@2000723) — instant fill + lag ghost
	# (hold 0.4 s, drain 0.9/s, update @2023679) + ceil(hp) number.
	# Driven per-frame in _update_hud_bars.
	var hp_track := _panel(_hero_cluster, Vector2(94, 90), Vector2(232, 15), Color(0.10, 0.14, 0.20, 0.88), 9, Color(0.86, 0.92, 1.0, 0.28), 1, true)
	_hud_hp_track = hp_track
	_hud_hp_lag = _panel(hp_track, Vector2(1, 1), Vector2(230, 13), Color(0.9, 0.97, 0.9, 0.75), 8)
	_hud_hp_fill = _panel(hp_track, Vector2(1, 1), Vector2(230, 13), Color(0.32, 0.90, 0.48), 8)
	# 顶部晶莹玻璃高光层，随填充宽度自动伸缩打造立体果冻绿血条
	var hp_hi := _panel(_hud_hp_fill, Vector2(2, 1), Vector2(226, 4), Color(1, 1, 1, 0.32), 2)
	hp_hi.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hp_hi.offset_left = 3
	hp_hi.offset_right = -3
	hp_hi.offset_top = 1
	hp_hi.offset_bottom = 5
	_hud_shield_fill = _panel(hp_track, Vector2(1, 1), Vector2(0, 13), Color(0.4, 0.78, 1.0, 0.8), 8)
	_hud_hp_num = _label_in(hp_track, "", Vector2(0, 0), Vector2(232, 15), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_hud_hp_num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_hud_hp_num.add_theme_constant_override("shadow_offset_x", 1)
	_hud_hp_num.add_theme_constant_override("shadow_offset_y", 1)
	# U1 1:1 round 14 (coordinator): on phone the HP track's
	# left end tucks BEHIND the medallion (reference: the bar
	# emerges from behind the portrait disc) — move the track
	# to just above the plate, below the medallion. Desktop
	# geometry has no overlap, so this changes nothing there.
	_hero_cluster.move_child(hp_track, _hero_plate.get_index() + 1)
	# Cycle 18: party portrait row (.party @2002233 — a disc +
	# mini HP track per ally) and the pw-row of live power
	# chips (.topbar .pw / cpw @2004105) under the HP track.
	_party_row = HBoxContainer.new()
	_party_row.position = Vector2(94, 111)
	_party_row.size = Vector2(300, 44)
	_party_row.add_theme_constant_override("separation", 6)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_cluster.add_child(_party_row)
	_pw_row = HBoxContainer.new()
	# y 206, not 171: the centered stage banner's line sits
	# at ~168-198 and overprinted the chips (ui18 shots).
	_pw_row.position = Vector2(94, 196)
	_pw_row.size = Vector2(360, 20)
	_pw_row.add_theme_constant_override("separation", 5)
	_pw_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_cluster.add_child(_pw_row)

	# --- top-center cluster (cycle 17, UI_SPEC §2.3 hud-top) ---
	# One glass card: left ht-l (zone name bold + stage pips +
	# zone/tier/weather chips), center ht-c (big timer + the
	# 7-segment danger meter), right ht-r (run clock + the
	# wallet pill). The pre-17 white card, text-dot pips, CALM
	# squares and the symbol counter pill are gone.
	var card := Panel.new()
	_top_card = card
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Cycle 21.3 (audit F7): design width 640 -> 726, so
	# the wallet pill (446 + 268 + 12 margin) lives INSIDE
	# the card instead of overhanging it (the gate's deep
	# rect now measures what is drawn).
	card.offset_left = -363
	card.offset_right = 363
	card.offset_top = 10
	card.offset_bottom = 94
	card.add_theme_stylebox_override("panel", UiTheme.dark_glass(16, 0.92))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	_zone_cn = _label_in(card, "青苔林", Vector2(18, 8), Vector2(170, 28), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_zone_cn.add_theme_font_override("font", _font_display)
	_zone_en = _label_in(card, "Viridian Forest", Vector2(18, 36), Vector2(170, 18), 12, UiTheme.HUD_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in range(4):
		var pip := Panel.new()
		pip.position = Vector2(18 + i * 17, 63)
		pip.size = Vector2(11, 11)
		pip.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.25), 6))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pip)
		_pips.append(pip)
	# 顶栏三枚子胶囊：对标 U1_final.jpg 翠绿「区域」＋柔暖奶油「普通」＋深蓝灰磨砂「晴」（天气保留 alpha=0.74 满足 P3 点击反馈）
	var zchip := _panel(card, Vector2(96, 57), Vector2(74, 22), Color("45b828"), 13, Color("8ae568"), 1.5, true)
	_zone_chip = zchip
	_zone_chip_label = _label_in(zchip, "区域 1/4", Vector2(0, 0), Vector2(74, 22), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	var nchip := _panel(card, Vector2(176, 57), Vector2(64, 22), Color(0.95, 0.94, 0.91, 0.96), 13, Color(1.0, 1.0, 1.0, 0.88), 1, true)
	_tier_chip = nchip
	_tier_chip_label = _label_in(nchip, "普通", Vector2(0, 0), Vector2(64, 22), 11, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	var wxchip := _panel(card, Vector2(246, 57), Vector2(64, 22), Color(0.20, 0.27, 0.36, 0.74), 13, Color(0.90, 0.96, 1.0, 0.45), 1, true)
	_wx_chip = wxchip
	_wx_icon = UiBadge.new("weather_sunny", Color(1.0, 0.9, 0.5), 14)
	_wx_icon.position = Vector2(7, 4)
	_wx_icon.size = Vector2(14, 14)
	wxchip.add_child(_wx_icon)
	_wx_label = _label_in(wxchip, "晴", Vector2(24, 0), Vector2(38, 22), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)

	_timer_label = _label_in(card, "10:00", Vector2(250, 6), Vector2(180, 40), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_timer_label.add_theme_font_override("font", _font_display)
	# Danger meter (bundle UR/WR/GR @1997817): tier name +
	# seven segments in the verified color ramp; the value is
	# driven from the nearby-threat sum in _refresh_hud.
	# Cycle 18 (audit §3.1): the tier name moves UNDER the
	# timer, centered on ht-c — at (254,54) it overprinted
	# the weather chip (246..310 x 57..79) into illegibility.
	_danger_name = _label_in(card, "平静", Vector2(250, 45), Vector2(180, 13), 12, UiTheme.DANGER_COLORS[0], HORIZONTAL_ALIGNMENT_CENTER, true)
	_danger_name.add_theme_font_override("font", _font_display)
	_danger_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_danger_name.add_theme_constant_override("shadow_offset_y", 1)
	for i in range(7):
		var seg := Panel.new()
		seg.position = Vector2(320 + i * 15, 59)
		seg.size = Vector2(13, 10)
		seg.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.16), 5))
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(seg)
		_danger_segs.append(seg)
	_elapsed_label = _label_in(card, "0:00.0", Vector2(446, 8), Vector2(176, 20), 13, UiTheme.HUD_DIM, HORIZONTAL_ALIGNMENT_RIGHT, true)
	# Wallet pill (bundle .wallet @2000510 region): stardust +
	# gold with drawn icons and display numbers. Cycle 21:
	# the third element IS the next-ball price — mining
	# settled what C17 left open: the bundle's wallet()
	# (@2086120) prices it from interactables.chestCost(),
	# the world Poké Ball (paid chest) curve; capture
	# throws themselves are free in the bundle (both
	# throwBall implementations read byte-level, DIFF §21).
	var wpill := Panel.new()
	wpill.position = Vector2(446, 42)
	wpill.size = Vector2(268, 36)
	wpill.add_theme_stylebox_override("panel", _style(Color(0.08, 0.05, 0.16, 0.85), 18, Color(0, 0, 0, 0), 0, true))
	wpill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(wpill)
	_wallet_pill = wpill
	# U1 1:1 round 13: the reference's stardust sparkle is
	# violet (sampled on U1_final.jpg ~ (196,107,226)), not
	# gold — the coin keeps GOLD, the sparkle takes violet.
	var dust_ic := UiIcon.new("spark", Color8(196, 107, 226), 18)
	dust_ic.position = Vector2(10, 9)
	dust_ic.size = Vector2(18, 18)
	wpill.add_child(dust_ic)
	_dust_icon = dust_ic
	_dust_label = _label_in(wpill, "0", Vector2(31, 0), Vector2(56, 36), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_dust_label.add_theme_font_override("font", _font_display)
	var coin_ic := UiIcon.new("coin", UiTheme.GOLD, 18)
	coin_ic.position = Vector2(94, 9)
	coin_ic.size = Vector2(18, 18)
	wpill.add_child(coin_ic)
	_coin_icon = coin_ic
	_gold_label = _label_in(wpill, "0", Vector2(115, 0), Vector2(54, 36), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_gold_label.add_theme_font_override("font", _font_display)
	# U1 1:1 round 13: "ball" draws the wooden-chest asset —
	# the old salmon tint dyed it red; the reference chest
	# reads natural wood, so the tint goes white.
	var ball_ic := UiIcon.new("ball", Color.WHITE, 18)
	ball_ic.position = Vector2(178, 9)
	ball_ic.size = Vector2(18, 18)
	wpill.add_child(ball_ic)
	_ball_icon = ball_ic
	_ball_price_label = _label_in(wpill, "0", Vector2(199, 0), Vector2(62, 36), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_ball_price_label.add_theme_font_override("font", _font_display)

	# Guardian boss bar (cycle 10; glass restyle cycle 17):
	# the original's .bossbar (@2003931) is a HUD bar — name +
	# tag + lag-ghost fill (hold 0.45 s, drain 0.6/s, @2028444)
	# + current-HP number, visible only while the boss lives.
	# Its two phase ticks are DOM-resident children in the
	# original; when they show is CSS/runtime-decided (named
	# evidence gap, UI_SPEC §2.4) — not drawn here. The
	# original also constructs 2 mini bars (.minibars
	# @2020582); ours land in UI round 2 (see the correction
	# appended to DIFF cycle 10).
	_boss_card = Panel.new()
	_boss_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# U1 1:1 round 13: the reference boss bar floats — no
	# dark backing plate (the card keeps an empty stylebox
	# and stays the children's anchor) — and the track widens
	# toward the reference's 0.364 frame fraction (card
	# 460 -> 500, track 432 -> 470).
	# U1 1:1 round 16 (coordinator): re-measured on the RAW
	# reference — the track spans 0.224..0.754 of frame width
	# (0.53, not 0.364; the 0.364 figure was eyeballed off a
	# composite). At the card's ~2.02 draw scale the track
	# goes 470 -> 614 and the card +-250 -> +-321.
	_boss_card.offset_left = -321
	_boss_card.offset_right = 321
	_boss_card.offset_top = 102
	_boss_card.offset_bottom = 148
	_boss_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_boss_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_card.visible = false
	root.add_child(_boss_card)
	# Cycle 18: constructor parity — left portrait, phase
	# ticks at 66.6%/33.3% of the track, and the foot row
	# (types · statuses · roar count; the constructor's foot
	# carries btypes/bdebuffs, UI_SPEC §2.4).
	# U1 1:1 round 4: the reference boss bar (U1_final.jpg)
	# is one row — red track + HP number + phase ticks +
	# a cream 守护者 chip at the track's right end. No
	# portrait, no name row, no static type foot: the foot
	# row now shows ONLY while a boss move is announced
	# (the 2.2 s telegraph, set in the refresh below).
	_boss_pic = TextureRect.new()
	_boss_pic.position = Vector2(10, 8)
	_boss_pic.size = Vector2(38, 38)
	_boss_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_pic.visible = false
	_boss_card.add_child(_boss_pic)
	_boss_foot = _label_in(_boss_card, "", Vector2(14, 50), Vector2(614, 16), 12, UiTheme.HUD_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	_boss_foot.hide()
	_boss_name_label = _label_in(_boss_card, "", Vector2(56, 5), Vector2(254, 22), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_boss_name_label.add_theme_font_override("font", _font_display)
	_boss_name_label.visible = false
	# Boss 条外围深灰磨砂圆角托框（对齐定稿 U1_final.jpg 厚托框 + 加粗高红条 + 硕大白字）
	var boss_frame := Panel.new()
	boss_frame.position = Vector2(8, 5)
	boss_frame.size = Vector2(626, 36)
	boss_frame.add_theme_stylebox_override("panel", UiTheme.hud_glass(16, 0.84, Color(0.88, 0.94, 1.0, 0.56), 2, 0))
	boss_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_card.add_child(boss_frame)
	var boss_track := _panel(_boss_card, Vector2(14, 10), Vector2(614, 26), Color(0.10, 0.13, 0.19, 0.92), 12, Color(0, 0, 0, 0), 0, true)
	_boss_hp_lag = _panel(boss_track, Vector2(1, 1), Vector2(612, 24), Color(1.0, 0.82, 0.78, 0.8), 11)
	_boss_hp_fill = _panel(boss_track, Vector2(1, 1), Vector2(612, 24), Color(0.95, 0.30, 0.24), 11)
	# 顶部立体果冻高光条，对齐定稿 U1_final.jpg 守护者红条玻璃反光质感
	var bhp_hi := _panel(_boss_hp_fill, Vector2(4, 2), Vector2(604, 6), Color(1, 1, 1, 0.32), 3)
	bhp_hi.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bhp_hi.offset_left = 4
	bhp_hi.offset_right = -4
	bhp_hi.offset_top = 2
	bhp_hi.offset_bottom = 8
	_boss_hp_num = _label_in(_boss_card, "", Vector2(14, 10), Vector2(614, 26), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_boss_hp_num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_boss_hp_num.add_theme_constant_override("shadow_offset_x", 1)
	_boss_hp_num.add_theme_constant_override("shadow_offset_y", 2)
	for frac in [0.666, 0.333]:
		var tick := _panel(_boss_card, Vector2(14 + 614.0 * frac - 1, 10), Vector2(2, 26), Color(1, 1, 1, 0.45), 0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_ticks.append(tick)  # cycle 21: shown only for kit bosses
	# 右端「守护者」标签牌收窄贴合、改柔暖白磨砂胶囊
	_boss_tag_chip = _panel(_boss_card, Vector2(504, 8), Vector2(124, 28), Color(0.95, 0.95, 0.94, 0.96), 14, Color(1, 1, 1, 0.85), 1, true)
	_boss_tag_label = _label_in(_boss_card, "守护者", Vector2(504, 8), Vector2(124, 28), 14, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)

	# Cycle 18: the two .bossbar.mini bars (constructor
	# @2020582 — the cycle-10 ledger correction). Feed:
	# alphas in spawn order (our secondary-boss source,
	# named in DIFF). Anatomy mirrors the main bar: name +
	# 头领 tag + lag fill + HP number, narrower.
	for mi in range(2):
		var mp := Panel.new()
		mp.set_anchors_preset(Control.PRESET_CENTER_TOP)
		mp.offset_left = -150
		mp.offset_right = 150
		mp.offset_top = 238 + mi * 46
		mp.offset_bottom = 238 + mi * 46 + 40
		mp.add_theme_stylebox_override("panel", UiTheme.hud_glass(14, 0.88, Color(0.88, 0.94, 1.0, 0.56), 2, 0))
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp.visible = false
		root.add_child(mp)
		var mnm := _label_in(mp, "", Vector2(10, 2), Vector2(200, 18), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
		mnm.add_theme_font_override("font", _font_display)
		_label_in(mp, "头领", Vector2(216, 2), Vector2(76, 18), 11, Color(1, 0.62, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, true)
		var mtr := _panel(mp, Vector2(10, 22), Vector2(280, 12), Color(0.1, 0.1, 0.16, 0.9), 6, Color(0, 0, 0, 0), 0, true)
		var mlag := _panel(mtr, Vector2(1, 1), Vector2(278, 10), Color(1.0, 0.82, 0.78, 0.8), 5, Color(0, 0, 0, 0), 0, true)
		var mfill := _panel(mtr, Vector2(1, 1), Vector2(278, 10), Color(1, 0.55, 0.16), 5, Color(0, 0, 0, 0), 0, true)
		var mnum := _label_in(mp, "", Vector2(10, 22), Vector2(280, 12), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		_mini_bars.append({"panel": mp, "name": mnm, "fill": mfill,
			"lag": mlag, "num": mnum, "lagv": 1.0, "hold": 0.0, "key": null})

	# --- top-right: minimap (framed + clickable, cycle 18) + kills pill ---
	var mm_frame := Panel.new()
	mm_frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mm_frame.offset_left = -188
	mm_frame.offset_right = -12
	mm_frame.offset_top = 10
	mm_frame.offset_bottom = 186
	# MinimapFrame 采用透明正圆无边框容器包裹圆形小地图，防止旧 badge_base 方框四角从圆盘边缘漏出
	var mm_sb := StyleBoxFlat.new()
	mm_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	mm_sb.set_corner_radius_all(999)
	mm_sb.shadow_size = 6
	mm_sb.shadow_color = Color(0.04, 0.08, 0.12, 0.28)
	mm_sb.shadow_offset = Vector2(0, 3)
	mm_frame.add_theme_stylebox_override("panel", mm_sb)
	mm_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_frame.name = "MinimapFrame"
	root.add_child(mm_frame)
	var mm := Minimap.new()
	_minimap = mm
	mm.baked = minimap_baked
	mm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mm.offset_left = -184
	mm.offset_right = -16
	mm.offset_top = 14
	mm.offset_bottom = 182
	root.add_child(mm)
	mm.world = self
	# UI-mobile P2 (plan R1): a "⤢" corner badge says the
	# minimap is tappable (phone only; _apply_top_card_phone).
	# 12 design px in the frame's bottom-right inner corner —
	# outside the disc, inside the minimap's tap rect.
	_mm_expand = UiIcon.new("expand", Color(1, 1, 1, 0.85), 12)
	_mm_expand.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mm_expand.offset_left = -20
	_mm_expand.offset_top = -20
	_mm_expand.offset_right = -8
	_mm_expand.offset_bottom = -8
	_mm_expand.visible = false
	mm_frame.add_child(_mm_expand)
	var kpill := Panel.new()
	kpill.name = "KillsPill"
	kpill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kpill.offset_left = -150
	kpill.offset_right = -16
	kpill.offset_top = 190
	kpill.offset_bottom = 218
	# 击杀胶囊改为定稿纯净雪亮奶白磨砂胶囊，基础 alpha=0.74 满足 P3 点击反馈 (+0.25) 校验
	var kills_face := _style(Color(0.99, 0.98, 0.95, 0.74), 14, Color(1.0, 1.0, 1.0, 0.94), 1.5)
	kills_face.shadow_color = Color(0.10, 0.14, 0.18, 0.28)
	kills_face.shadow_size = 4
	kills_face.shadow_offset = Vector2(0, 2)
	kpill.add_theme_stylebox_override("panel", kills_face)
	kpill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kpill)
	var kic := UiIcon.new("skull", Color("2a2d34"), 18)
	kic.set_meta("cutout_color", Color(0.94, 0.95, 0.95, 1.0))
	kic.position = Vector2(16, 5)
	kic.size = Vector2(18, 18)
	kpill.add_child(kic)
	_kills_label = _label_in(kpill, "击杀 0", Vector2(36, 0), Vector2(96, 28), 14, Color("2a2d34"), HORIZONTAL_ALIGNMENT_LEFT, true)
	# Cycle 18: goal card + event-pill stack (UI_SPEC §2.3
	# kgoal / §2.10 pills). The goal card's anatomy is the
	# constructor's (portrait + name + "n left" + bar + next
	# line); its DATA is adapted — the bundle feeds it from
	# the online season-rival ticket, which this build does
	# not have; ours tracks the next incomplete League
	# challenge (named adaptation, DIFF cycle 18).
	_goal_card = PanelContainer.new()
	_goal_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_goal_card.offset_left = -188
	_goal_card.offset_right = -12
	_goal_card.offset_top = 226
	_goal_card.offset_bottom = 312
	_goal_card.add_theme_stylebox_override("panel", UiTheme.dark_glass(16, 0.92))
	_goal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cycle 19 hotfix: the card's width is FIXED at the
	# designed 176 — a long challenge name must clip inside
	# it, never widen the panel (a content-widened rect
	# invalidated the scaler's pivot and pushed the card
	# off the phone's right edge).
	_goal_card.custom_minimum_size = Vector2(176, 0)
	_goal_card.visible = false
	root.add_child(_goal_card)
	var gvb := VBoxContainer.new()
	gvb.add_theme_constant_override("separation", 3)
	_goal_card.add_child(gvb)
	var ghb := HBoxContainer.new()
	ghb.add_theme_constant_override("separation", 6)
	gvb.add_child(ghb)
	_goal_pic = TextureRect.new()
	_goal_pic.custom_minimum_size = Vector2(32, 32)
	_goal_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_goal_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_goal_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghb.add_child(_goal_pic)
	var gvb2 := VBoxContainer.new()
	gvb2.add_theme_constant_override("separation", 0)
	ghb.add_child(gvb2)
	_goal_name = _mk_label(gvb2, "", 14, Color.WHITE, true)
	_goal_name.clip_text = true  # hotfix: never widen the card
	# clip_text zeroes the label's minimum width, which
	# would starve it inside this HBox (it rendered with
	# width 0 — an empty name line). Pin the minimum the
	# header budget affords: margins 28 + portrait 32 +
	# separation 6 + name 108 <= the card's 176.
	_goal_name.custom_minimum_size = Vector2(108, 0)
	_goal_name.add_theme_font_override("font", UiTheme.display_font())
	var gtrack := Panel.new()
	# 144, not 160: the glass stylebox's content margins
	# (2x14) ride on top — 160+28 = 188 exceeded the card's
	# designed 176 and the container grew off the right
	# edge (the device clip). 144+28 = 172 <= 176.
	gtrack.custom_minimum_size = Vector2(144, 9)
	gtrack.add_theme_stylebox_override("panel",
		UiTheme.flat_box(Color(UiTheme.INK_DEEP.r, UiTheme.INK_DEEP.g, UiTheme.INK_DEEP.b, 0.85), 4))
	gvb.add_child(gtrack)
	_goal_bar_fill = Panel.new()
	_goal_bar_fill.position = Vector2(1, 1)
	_goal_bar_fill.size = Vector2(1, 7)
	_goal_bar_fill.add_theme_stylebox_override("panel",
		UiTheme.flat_box(Color(0.35, 0.95, 0.55), 3))
	_goal_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gtrack.add_child(_goal_bar_fill)
	_goal_bar_fill.set_meta("track_w", 142.0)
	_goal_track = gtrack
	# Cycle 21.3 (audit §5): the next line's progress count
	# was clipped by clip_text ("…（胜…下限） 0/"). The count
	# now has its OWN right-aligned label that never clips;
	# the description keeps the clip.
	var gnb := HBoxContainer.new()
	gnb.add_theme_constant_override("separation", 6)
	gvb.add_child(gnb)
	_goal_next = _mk_label(gnb, "", 11, UiTheme.HUD_DIM, true)
	_goal_next.clip_text = true  # hotfix: never widen the card
	_goal_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_count = _mk_label(gnb, "", 11, Color.WHITE, true)
	_goal_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pill_box = VBoxContainer.new()
	_pill_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pill_box.offset_left = -188
	_pill_box.offset_right = -12
	_pill_box.offset_top = 320
	_pill_box.offset_bottom = 560
	_pill_box.add_theme_constant_override("separation", 6)
	_pill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pill_box)
	# Cycle 21.3 (audit F1): the "+N" badge shown when the
	# info-stack budget collapses the pills past the
	# first. A _hud_root sibling (NOT a pill-box child —
	# the VBox would lay it out as a row); positioned and
	# scaled by _layout_hud, hidden unless shedding.
	_pill_badge = Panel.new()
	_pill_badge.size = Vector2(34, 20)
	_pill_badge.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.20, 0.92), 10, Color(1, 1, 1, 0.35), 1, true))
	_pill_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_badge.visible = false
	root.add_child(_pill_badge)
	_pill_badge_label = _label_in(_pill_badge, "+0", Vector2(0, 0), Vector2(34, 20), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_build_objective(root, kpill)

	# --- bottom-left: item slots, move slot, locked slot, ult ---
	# Cycle 19 hotfix (device overlap): same disease as the
	# top-left — the slots, move card, lock and ult circle
	# were siblings growing about their own corners, so at
	# phone factors the ult NAME label drifted left across
	# the move card. One BL-anchored cluster container now
	# carries them at design-relative positions (container
	# space: x as designed, y = design-from-bottom + 118).
	_bl_cluster = Control.new()
	_bl_cluster.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bl_cluster.offset_left = 0
	_bl_cluster.offset_right = 460
	_bl_cluster.offset_top = -118
	_bl_cluster.offset_bottom = 0
	_bl_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bl_cluster)
	for i in range(4):
		var slot := Panel.new()
		slot.position = Vector2(16 + i * 52, 56)
		slot.size = Vector2(46, 46)
		slot.add_theme_stylebox_override("panel", UiTheme.badge_base())
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bl_cluster.add_child(slot)
		_bl_legacy.append(slot)
	var move := Panel.new()
	move.position = Vector2(232, 48)
	move.size = Vector2(56, 56)
	move.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.20, 0.92), 28, Color(0.35, 0.71, 0.41), 2, true))
	move.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bl_cluster.add_child(move)
	_move_slot = move
	# Cycle 19 (audit punch #15): the slot carries the first
	# move's TYPE ICON, like the original's icon slots — the
	# old face was the move's name as 15 px text ("藤鞭" /
	# "火花") crammed into 56 px. A 10 px level strip rides
	# the bottom; the full move list lives in the pause page
	# and the draft's buildMini.
	_move_slot_icon = UiIcon.new("leaf", Color.WHITE, 32)
	_move_slot_icon.position = Vector2(12, 6)
	_move_slot_icon.size = Vector2(32, 32)
	move.add_child(_move_slot_icon)
	_move_name_label = _label_in(move, "1级", Vector2(0, 38), Vector2(56, 14), 10, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true)
	var badge := _panel(move, Vector2(-5, -5), Vector2(20, 18), Color(0.12, 0.11, 0.2, 0.95), 9, Color(0, 0, 0, 0), 0, true)
	_label_in(badge, "1", Vector2(0, 0), Vector2(20, 18), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	var locked := Panel.new()
	locked.position = Vector2(296, 56)
	locked.size = Vector2(46, 46)
	locked.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.20, 0.92), 23, Color(1, 1, 1, 0.25), 1, true))
	locked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bl_cluster.add_child(locked)
	var lock_ic := UiIcon.new("lock", Color(0.85, 0.85, 0.9), 24)
	lock_ic.position = Vector2(11, 11)
	lock_ic.size = Vector2(24, 24)
	locked.add_child(lock_ic)
	_bl_legacy.append(move)
	_bl_legacy.append(locked)
	# UI-mobile P4: the phone rows live in their own container
	# (filled by _p4_refresh_slots, laid out by _p4_layout_bl).
	_bl_rows = Control.new()
	_bl_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bl_rows.visible = false
	# U1 1:1 round 6: the dark band is a bar behind the move row
	# only (reference U1_final.jpg) — it overhangs the outer
	# slots by P4_STRIP_PAD and the slots protrude above/below
	# it. Its rect is set in _p4_layout_bl (width tracks the
	# slot count); first child, so every slot draws over it.
	_bl_strip = Panel.new()
	_bl_strip.add_theme_stylebox_override("panel", UiTheme.hud_glass(40, 0.84, Color(0.92, 0.96, 1.0, 0.68), 2, 0))
	_bl_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bl_rows.add_child(_bl_strip)
	_bl_cluster.add_child(_bl_rows)
	_bl_lock = Panel.new()
	_bl_lock.size = Vector2(P4_SLOT, P4_SLOT)
	_bl_lock.add_theme_stylebox_override("panel", _style(Color(0.24, 0.27, 0.34, 0.72), 65, Color("d8dde8"), 5, true))
	_bl_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bl_rows.add_child(_bl_lock)
	var lock_ic2 := UiIcon.new("lock", Color(0.98, 0.98, 0.99, 0.95), 68)
	lock_ic2.position = Vector2(31, 31)
	lock_ic2.size = Vector2(68, 68)
	_bl_lock.add_child(lock_ic2)
	# Cycle 13: the 必 circle is a real button now (UltGauge) —
	# charge sweep, ready pulse, and touch/mouse presses feed
	# the Ult controller's trigger poll.
	_ult_circle = UltGauge.new()
	_ult_circle.position = Vector2(352, 42)
	_ult_circle.size = Vector2(62, 62)
	_ult_circle.medal = STARTER_HUD["bulbasaur"]["medal"]
	_bl_cluster.add_child(_ult_circle)
	var ult_glyph := _label_in(_ult_circle, "必", Vector2(0, 0), Vector2(62, 62), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	ult_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rbadge := _panel(_ult_circle, Vector2(42, -4), Vector2(22, 20), Color(0.12, 0.11, 0.2, 0.95), 10, Color(0, 0, 0, 0), 0, true)
	rbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rbadge_label := _label_in(rbadge, "R", Vector2(0, 0), Vector2(22, 20), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	rbadge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_circle.pressed.connect(_on_ult_button)
	_ult_name_label = Label.new()
	_ult_name_label.position = Vector2(322, 14)
	_ult_name_label.size = Vector2(122, 20)
	_ult_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_name_label.add_theme_font_override("font", _font)
	_ult_name_label.add_theme_font_size_override("font_size", 12)
	_ult_name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	_ult_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_ult_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_ult_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_ult_name_label.text = "狂怒根须"
	_bl_cluster.add_child(_ult_name_label)
	# Cycle 19 (audit punch #15): the cycle-7 learned-moves
	# text line ("招式：抓 Lv.1 …") is DELETED — it duplicated
	# the slot row as an unbacked raw label. Moves read from
	# the icon slot, the pause 招式 page, and buildMini now.

	# --- banner + prompt ---
	# Cycle 19 (audit punch #9): the stage banner gets the
	# original's stageIntro treatment — an ink-glass backing
	# band behind the gold display text (it was raw text
	# straight on the terrain). Alpha rides the banner's.
	_banner_back = Panel.new()
	_banner_back.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_back.offset_left = -446
	_banner_back.offset_right = 446
	_banner_back.offset_top = 148
	_banner_back.offset_bottom = 204
	# 对齐定稿 S23_v1.jpg：战斗通知横幅升级为圆润暖奶油金边大胶囊配深棕粗字，淘汰半透暗黑框
	var banner_sb := _style(Color(1.0, 0.985, 0.94, 0.96), 24, Color("e0be78"), 2, true)
	banner_sb.shadow_color = Color(0.18, 0.12, 0.04, 0.25)
	banner_sb.shadow_size = 6
	banner_sb.shadow_offset = Vector2(0, 3)
	_banner_back.add_theme_stylebox_override("panel", banner_sb)
	_banner_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_back.modulate.a = 0.0
	root.add_child(_banner_back)
	_banner = _mk_label(root, "", 20, UiTheme.TEXT, true)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.offset_top = 158
	_banner.offset_left = -430
	_banner.offset_right = 430
	_banner.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.86, 0.70))
	_banner.add_theme_constant_override("shadow_offset_x", 0)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.add_theme_font_override("font", _font)

	_banner.modulate.a = 0.0
	# Cycle 21.3 (audit §5 + F5): the prompt was white
	# text on bright grass protected only by an outline —
	# it gets the banner's ink-glass backing. Geometry is
	# derived from the prompt's in _layout_hud (phone
	# branch); visibility tracks the prompt text.
	_prompt_back = Panel.new()
	_prompt_back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_back.offset_left = -312
	_prompt_back.offset_right = 312
	_prompt_back.offset_top = -124
	_prompt_back.offset_bottom = 6
	# 对齐定稿 S23_v1.jpg：交互气泡改为柔和暖奶油圆角卡片配金棕细边与清晰深棕字
	_prompt_back.add_theme_stylebox_override("panel", _style(Color(1.0, 0.985, 0.945, 0.95), 14, Color("e4c78a"), 2, true))
	_prompt_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_back.visible = false
	root.add_child(_prompt_back)
	_prompt_tri = Polygon2D.new()
	_prompt_tri.color = (_prompt_back.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	_prompt_tri.visible = false
	_prompt_back.add_child(_prompt_tri)
	_prompt = _mk_label(root, "", 20, UiTheme.TEXT, true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.max_lines_visible = 2
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -118
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.add_theme_font_override("font", UiTheme.display_font())


	# Cycle 17: everything added to root up to here is run HUD
	# (medallion, cluster, minimap, slots, banner...). Regroup
	# it under one node so the menu state can hide the HUD as a
	# whole — children keep their own visibility logic (boss
	# card, cut-in) untouched. Menu + panels + touch controls
	# are added after and stay live in every state.
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_kids := root.get_children()
	root.add_child(_hud_root)
	root.move_child(_hud_root, 0)
	for k in hud_kids:
		(k as Node).reparent(_hud_root)
	_hud_root.visible = false  # boots into the menu

	# Cycle 19 (audit punch #8): ONE shared modal scrim —
	# a full-rect ink dim inserted below every modal panel
	# (all builders below add theirs after this) and above
	# the HUD root, so an open modal dims the HUD and the
	# menu behind it, and the banner (inside the HUD root)
	# stops ghosting through translucent panels. Visibility
	# is driven per-frame from _any_modal_open().
	_modal_scrim = ColorRect.new()
	_modal_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_scrim.color = Color(0.10, 0.14, 0.08, 0.56)
	_modal_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_scrim.visible = false
	root.add_child(_modal_scrim)

	_build_menu(root)
	_build_wallet_panel(root)
	_refresh_wallet_ui()
	if wallet.is_wallet_connected():
		wallet.fetch_balance()
	_build_result(root)
	_build_draft(root)
	_build_blessing(root)
	_build_choice(root)
	_build_shop(root)
	_build_lab_panel(root)
	_build_unlock_panel(root)
	_build_shop_panel(root)
	_build_sound_panel(root)
	# Cycle 18 builders: pause, big map, loadout.
	_build_pause(root)
	_build_bigmap(root)
	_build_loadout(root)
	# UI-mobile P5 (plan §B3 table): M0 design sizes (W_max, H).
	# The selected cards are 300 px tall; include the live header,
	# team row, and panel padding in the registered fit heights.
	_p5_register(_draft_panel, 985.0, 475.0)
	_p5_register(_blessing_panel, 985.0, 467.0)
	_p5_register(_choice_panel, 860.0, 360.0)
	_p5_register(_meowth_panel, 920.0, 446.0)
	_p5_register(_pause_panel, 1000.0, 430.0)
	_p5_register(_bigmap_panel, 900.0, 460.0)
	# U5 fix4/5: result fits against its nominal design height only
	# (see _p5_place_modal p5_fixed_h); the 14 px spill from its
	# live min (787 vs spec 750) is fixed by trimming the live min
	# (slim row/payout plate margins in _fill_result), not by
	# fitting against it -- the fix3 fit-against-live-min loop
	# diverged (s100 result scale 0.036).
	# U5 fix6: on phone the registered modal is the wrapper stack
	# (panel + actions below it); desktop keeps the bare panel.
	if _p5_on:
		_p5_register(_result_wrap, 867.0, 750.0)
		_result_wrap.set_meta("p5_fixed_h", true)
		# U5 re-audit #1: panel centre is 48.7% of the frame width.
		_result_wrap.set_meta("p5_frame_shift", Vector2(-0.013, 0.0))
	else:
		_p5_register(_result_panel, 900.0, 750.0)
		_result_panel.set_meta("p5_fixed_h", true)
	_p5_register(_lab_panel, 800.0, 446.0)
	_p5_register(_shop_panel, 740.0, 446.0)
	_p5_register(_unlock_panel, 900.0, 430.0)
	_p5_register(_sound_panel, 900.0, 430.0)
	_p5_register(_wallet_panel, 640.0, 430.0)
	for c in _loadout_panel.get_children():
		if c is PanelContainer:
			_p5_register(c, 4000.0, 440.0)
	# Touch controls (Android): joystick + action cluster, on
	# top of the HUD layer; visibility is managed per-frame in
	# _process. Lives on the OUTER root (see _ui_root note).
	touch_controls = TouchControls.new()
	outer_root.add_child(touch_controls)
	touch_controls.set_layout_classic(not _new_layout())
	touch_controls.ult_pressed.connect(_on_ult_button)
	cam_dist = float(GameProfile.setting("camDist"))
	touch_controls.apply_scale(float(GameProfile.setting("touchScale")))
	touch_controls.fixed_stick = bool(GameProfile.setting("fixedStick"))
	touch_controls.set_aim_state(bool(GameProfile.setting("camAssist")))
	# UI-mobile P2 (plan T6 / I1 / I2): the weather chip is
	# tappable on phone. The chip sits under the joystick
	# zone (left 52%, STOP), so its hit area lives on the
	# touch layer, AFTER the zone (input goes to it first),
	# placed over the chip each layout pass, >= 70 px.
	_wx_hit = Control.new()
	_wx_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_wx_hit.visible = false
	_wx_hit.gui_input.connect(_on_wx_hit_input)
	touch_controls.add_child(_wx_hit)
	# UI-mobile P3 (plan D1 / D4 / I1 / I2): the portrait
	# (under the joystick zone, like the weather chip) and
	# the objective pill get >= 70 px hit areas on the touch
	# layer, after the zone; placed by _layout_hud.
	_portrait_hit = Control.new()
	_portrait_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait_hit.visible = false
	_portrait_hit.gui_input.connect(func(ev: InputEvent) -> void:
		_p3_tap_input(ev, _portrait_hit, _medal_panel, _p3_portrait_tap))
	touch_controls.add_child(_portrait_hit)
	_obj_hit = Control.new()
	_obj_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_obj_hit.visible = false
	_obj_hit.gui_input.connect(func(ev: InputEvent) -> void:
		_p3_tap_input(ev, _obj_hit, _p3_obj_target(), _obj_toggle_drawer))
	touch_controls.add_child(_obj_hit)
	# Adaptation layer: register the scale set, apply safe
	# area + opacities, and re-apply on viewport changes.
	_register_ui_scale()
	_apply_safe_area()
	_apply_visibility_settings()
	_layout_top_card()
	RenderingServer.frame_pre_draw.connect(_reskin_boss_visibility)
	get_viewport().size_changed.connect(_on_viewport_resized)
	# UI-mobile P5: modals opened straight from the menu (lab /
	# shop / unlock / wallet) never pass _apply_ui_scale — place
	# the modal family and the menu once at boot.
	if _p5_on:
		var s5 := _kr() * float(GameProfile.setting("hudScale"))
		for c in _p5_spec.keys():
			_p5_place_modal(c, s5)
		_p5_layout_menu(s5)

func _move_zh(key: String) -> String:
	return String(MOVE_ZH.get(key, key.capitalize().replace("-", " ")))

## HUD info for any species: the three starters keep their curated
## cycle-1..6 panels; evolved forms get a generated equivalent from
## pokemon.json types + the rig's Chinese label (cycle 7).
func _hud_info_for(species: String) -> Dictionary:
	if STARTER_HUD.has(species):
		return STARTER_HUD[species]
	var sd: Dictionary = GameData.species(species)
	var label := String(ModelRig.SPECIES[species]["label"])
	var chips: Array = []
	for t in sd.get("types", []):
		var th: Array = TYPE_HUD.get(String(t), ["?", Color(0.6, 0.6, 0.6)])
		chips.append([String(th[0]), th[1]])
	var medal: Color = (TYPE_HUD.get(String((sd.get("types", ["normal"]) as Array)[0]), ["", Color(0.6, 0.6, 0.6)])[1] as Color)
	var evo_lv := GameData.evo_level_for(species)
	var evo_txt := "› %d级成长" % evo_lv if evo_lv > 0 else "› 成长"
	var ult := "Furious Roots"
	if player and STARTER_HUD.has(player.base_species):
		ult = String(STARTER_HUD[player.base_species]["ult"])
	return {"name": label, "en": species.capitalize(), "medal": medal,
		"glyph": label.substr(0, 1), "types": chips, "evo": evo_txt,
		"move": _move_zh(String(player.moves[0]["key"])) if player and not player.moves.is_empty() else "",
		"ult": ult}

func _apply_starter_hud(species: String) -> void:
	var info: Dictionary = _hud_info_for(species)
	_medal_panel.medal = info["medal"]
	_medal_panel.portrait = UiTheme.portrait(species)
	_medal_glyph.visible = _medal_panel.portrait == null
	_medal_glyph.text = String(info["glyph"])
	if _move_slot:
		_move_slot.add_theme_stylebox_override("panel", UiTheme.badge_base())
	_hud_name_full = "%s %s" % [String(info["name"]), String(info["en"])]
	# UI-mobile P2 (plan H4): Chinese name only on phone; the
	# EN name is on the pause status page.
	_hud_name.text = String(info["name"]) if _p2_on == 1 else _hud_name_full
	for c in _hud_chips.get_children():
		c.queue_free()
	for t in info["types"]:
		_hud_chips.add_child(_make_chip(String(t[0]), t[1]))
	_hud_evo.text = String(info["evo"])
	# UI-mobile P2: the rebuilt type chips need the phone fit.
	_p2_font_sig = ""
	if _p2_on == 1:
		_layout_hud()
	_move_slot_sig = ""  # cycle 19: the slot face is icon + Lv now
	_refresh_move_slot()
	_ult_circle.medal = info["medal"]
	# UI-mobile P1.3: the touch cluster gauge wears the same
	# medal ring (it stayed the UltGauge default grey).
	if touch_controls and touch_controls.ult_gauge:
		touch_controls.ult_gauge.medal = info["medal"]
		touch_controls.ult_gauge.queue_redraw()
	# Cycle 13: the live ult name comes from the controller
	# (def.names[form] — it changes with evolution); the HUD
	# table is only the pre-run fallback.
	_ult_name_label.text = Ult.display_name(ult.ult_name()) if ult else Ult.display_name(String(info["ult"]))

func _apply_zone_card() -> void:
	var zc: Dictionary = ZONES[zone - 1]
	_zone_cn.text = String(zc["cn"])
	_zone_en.text = String(zc["en"])
	_zone_chip_label.text = "区域 %d/4" % zone
	for i in range(_pips.size()):
		(_pips[i] as Panel).add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.95) if i < zone else Color(1, 1, 1, 0.25), 6))

func _on_player_evolved() -> void:
	if ult:
		player.ult_name = ult.ult_name()  # def.names[form] changes with the form
	# Cycle 16: evolution reveal — evolveDone + the new form's
	# cry + a music duck (the bundle ducks .2 for the morph;
	# our morph is instant, so the reveal sounds play at once).
	audio.evolve_done()
	audio.cry(player.species_id)
	audio.duck(0.2, 1.5)
	_apply_starter_hud(player.species_id)
	GameProfile.count("evolutions")
	run_evos += 1  # cycle 18: results fact grid
	add_trauma(0.6)  # bundle: evolution reveal -> shake(0.6) (@1475986)
	# Cycle 9 (audit §2): the bundle's morph runs a timed effect
	# with a continuous shake(.02) through the transformation, and
	# the evolved form lands with flash = 1 and iframes 2.6
	# (@1476150 region). Our morph is an instant rig swap, so the
	# shake window is played as a 0.9 s trauma feed in _process.
	_evo_fx_t = 0.9
	if player.rig:
		player.rig.set_flash(1.0)
	player._invuln_t = maxf(player._invuln_t, 2.6)
	count_max_level()
	show_banner("成长！变成了 %s！" % String(ModelRig.SPECIES[player.species_id]["label"]), 3.5)

## Cycle 17: one floating menu item (UI_SPEC §2.1 mm-item):
## a glass card button with an accent icon, a title, and a
## live subtitle label. Returns [button, subtitle_label];
## callers wire `pressed` and write status into the subtitle.
func _menu_item(icon: String, accent: Color, title: String, x: float, y: float) -> Array:
	# UI-mobile P5: 52 tall on phone (six fit the design column).
	var h := 48.0 if _p5_on else 64.0
	var b := UiTheme.make_button("", "ghost", "normal")
	b.custom_minimum_size = Vector2(300, h)
	b.position = Vector2(x, y)
	b.size = Vector2(300, h)
	var ic := UiBadge.new(icon, accent, 42)
	ic.position = Vector2(10, 3.0 if _p5_on else 11.0)
	ic.size = Vector2(42, 42)
	b.add_child(ic)
	var t := _mk_label(b, title, 22, UiTheme.TEXT)
	t.add_theme_font_override("font", _font_display)
	t.position = Vector2(58, 10.0 if _p5_on else 18.0)
	t.size = Vector2(232, 24)
	var s := _mk_label(b, "", 12, UiTheme.MUTED)
	s.hide()
	s.position = Vector2(58, 28.0 if _p5_on else 36.0)
	s.size = Vector2(232, 20)
	_menu_panel.add_child(b)
	return [b, s]

## Cycle 17: a starter select card (UI_SPEC §2.1/§2.2
## adapted): portrait disc, name, type chips, base stats
## (pokemon.json via GameData), and the ult line — replacing
## the pre-17 text-only button that showed none of this.
func _starter_card(sp: String, unlocked: bool, w: float) -> Button:
	var info := _hud_info_for(sp)
	var b := UiTheme.make_card(info["medal"], Vector2(110, 90 if _p5_on else 112))
	b.size = Vector2(110, 90 if _p5_on else 112)
	var portrait := TextureRect.new()
	if _p5_on and not unlocked:
		var starter_art := {"bulbasaur": "stump", "charmander": "coal", "squirtle": "shell"}
		portrait.texture = load("res://assets/menu/v2-starter-%s.svg" % starter_art.get(sp, "stump"))
	else:
		portrait.texture = UiTheme.portrait(sp)
	if _p5_on:
		b.set_meta("starter_species", sp)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(15, 5) if _p5_on else Vector2(15, 4)
	portrait.size = Vector2(80, 80)
	if _p5_on and unlocked:
		portrait.position = Vector2(25, 4)
		portrait.size = Vector2(60, 60)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(portrait)
	if _p5_on:
		# Icon order 2: the selected starter wears the shipped
		# check badge (badges/badge_check_selected.png) instead
		# of the drawn green disc + vector check.
		var mark := TextureRect.new()
		mark.name = "SelectedMark"
		mark.visible = sp == _menu_hero_sp
		mark.texture = load("res://assets/ui/badges/badge_check_selected.png")
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.position = Vector2(86, 2)
		mark.size = Vector2(22, 22)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
	if not _p5_on or unlocked:
		_label_in(b, String(info["name"]), Vector2(0, 64 if _p5_on else 82), Vector2(110, 26), 17, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	b.pressed.connect(func() -> void:
		audio.click()
		audio.cry(sp)
		_open_loadout(sp))
	b.mouse_entered.connect(func() -> void: _menu_hero_show(sp))
	b.focus_entered.connect(func() -> void: _menu_hero_show(sp))
	return b

func _build_menu(root: Control) -> void:
	# Cycle 17 (UI_SPEC §2.1): no panel — the menu floats over
	# the live 3D menu scene: title top-left, starter cards as
	# the primary items, meta items as accent icon cards in a
	# second column. (The pre-17 centered default-gray panel
	# overflowed the 720p viewport and hid its lower buttons.)
	_menu_panel = Control.new()
	_menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_menu_panel)
	if _p5_on:
		var forest := TextureRect.new()
		forest.name = "MenuForestBackground"
		forest.set_anchors_preset(Control.PRESET_FULL_RECT)
		# 左右适当宽延 80px 封死超宽刘海安全区边缘露缝，垂直严格保持 0 偏移确保萌宠与石台同中心基准
		forest.offset_left = -80.0
		forest.offset_right = 80.0
		forest.offset_top = 0.0
		forest.offset_bottom = 0.0
		forest.texture = load("res://assets/menu/v2-background.png")
		forest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		forest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		forest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_panel.add_child(forest)
	var ribbon := _panel(_menu_panel, Vector2(30, 24), Vector2(280, 72), UiTheme.CREAM, 32, Color.WHITE, 3)
	ribbon.name = "LogoRibbon"
	if _p5_on:
		ribbon.position = Vector2(8, 0)
		ribbon.size = Vector2(300, 58)
	var title := _mk_dlabel(_menu_panel, "SpriteBonk", 54, Color.WHITE)
	title.position = Vector2(52, 30)
	title.size = Vector2(600, 66)
	UiTheme.outline(title, 6)
	var sub := _mk_label(_menu_panel, "选择初始伙伴", 19, UiTheme.LILAC)
	sub.name = "StarterHeading"
	sub.position = Vector2(362, 430)
	sub.size = Vector2(400, 26)
	# UI-mobile P5 (plan §B3 G1-G6): the phone menu is laid out
	# on a 450-tall design surface scaled ~1.58 (see
	# _p5_layout_menu): title row, starter column (scrolls into
	# the league unlocks), the six items, the hero card where
	# the width allows, the touch hint along the foot.
	if _p5_on:
		ribbon.hide()
		title.hide()
		title.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
		title.add_theme_color_override("font_outline_color", Color(0.30, 0.16, 0.06))
		title.add_theme_font_size_override("font_size", 40)
		var tw := _font_display.get_string_size("SpriteBonk", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 40).x
		title.position = Vector2(8, 0)
		title.size = Vector2(tw + 12.0, 50)
		sub.position = Vector2(332, 192)
		sub.size = Vector2(300, 26)
	# Cycle 19 (audit §2.1): the subtitle was the least
	# legible text on the screen — 19 px lilac with no
	# outline, sitting on pale scenery. It gets the
	# title's outline treatment.

	if _p5_on:
		# The display face's line box at 40 (+ outline) is taller
		# than the 50 row and pushed the title's rect into the
		# starter column (gate: menu pieces disjoint) — step the
		# size down until the drawn box fits above y 56.
		var tfs := 40
		while tfs > 30 and title.get_minimum_size().y > 54.0:
			tfs -= 2
			title.add_theme_font_size_override("font_size", tfs)
		var tw2 := _font_display.get_string_size("SpriteBonk", HORIZONTAL_ALIGNMENT_LEFT, -1.0, tfs).x
		title.size = Vector2(tw2 + 12.0, title.get_minimum_size().y)
		sub.position = Vector2(340, 296)
		sub.size.x = 365
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", UiTheme.TEXT)
	var y := 146.0
	var pcol: HBoxContainer = null
	if _p5_on:
		_menu_starters = ScrollContainer.new()
		_menu_starters.position = Vector2(340, 314)
		_menu_starters.size = Vector2(355, 112)
		_menu_starters.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_menu_starters.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_menu_panel.add_child(_menu_starters)
		pcol = HBoxContainer.new()
		pcol.add_theme_constant_override("separation", 4)
		_menu_starters.add_child(pcol)
	for sp in ["bulbasaur", "charmander", "squirtle"]:
		var card := _starter_card(sp, false, 340.0 if _p5_on else 396.0)
		if _p5_on:
			pcol.add_child(card)
		else:
			card.position = Vector2(358 + ["bulbasaur", "charmander", "squirtle"].find(sp) * 124, 470)
			_menu_panel.add_child(card)
			_menu_intro_items.append(card)
		if _first_starter_card == null:
			_first_starter_card = card
		y += 116.0
	# Cycle 8: League members captured in runs become playable
	# starters (the original's roster unlock: joinLeague pushes
	# the family to profile.unlocked). Rebuilt by
	# _refresh_starter_unlocks; scrolled so a long roster can
	# never push the rest of the menu off-screen.
	_starter_unlock_box = HBoxContainer.new() if _p5_on else VBoxContainer.new()
	_starter_unlock_box.hide()
	_starter_unlock_box.add_theme_constant_override("separation", 10)
	_starter_unlock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _p5_on:
		# Phone: the unlocks continue the starter column's scroll.
		pcol.add_child(_starter_unlock_box)
	else:
		var usc := ScrollContainer.new()
		usc.position = Vector2(358, 590)
		usc.size = Vector2(360, 60)
		_menu_panel.add_child(usc)
		usc.add_child(_starter_unlock_box)
	# Cycle 19 (audit §2.2): the control hint gets a glass
	# backing (it was raw 13 px text laid over grass).
	var hint_back := Panel.new()
	hint_back.position = Vector2(44, 664)
	hint_back.size = Vector2(1192, 48)
	hint_back.add_theme_stylebox_override("panel", UiTheme.glass(10, 0.55))
	hint_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(hint_back)
	var hint := _mk_label(_menu_panel, MENU_HINT_COMPACT if _p5_on else MENU_HINT_KBD, 13, Color(0.84, 0.86, 0.94))
	_menu_hint = hint  # UI-mobile P1.1: re-texted by _touch_text_sync
	hint.position = Vector2(52, 672)
	hint.size = Vector2(1170, 40)

	hint.set_meta("back", hint_back)
	if _p5_on:
		hint_back.position = Vector2(8, 400)
		hint_back.size = Vector2(780, 48)
		var hint_style := StyleBoxFlat.new()
		hint_style.bg_color = Color(0.13, 0.21, 0.08, 0.82)
		hint_style.set_corner_radius_all(15)
		hint_style.set_border_width_all(1)
		hint_style.border_color = Color(0.67, 0.79, 0.45, 0.65)
		hint_back.add_theme_stylebox_override("panel", hint_style)
		hint.position = Vector2(43, 403)
		hint.size = Vector2(245, 42)
		hint.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86))
		hint.add_theme_font_size_override("font_size", 13)
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# --- meta column (cycle 17): mm-item cards — the wallet
	# subtitle carries the live wallet state, the Lab subtitle
	# the bundle's "{n} 萤尘" line (via _refresh_meta). ---
	var mx := 30.0
	var my := 136.0
	var mstep := 74.0
	if _p5_on:
		mx = 8.0
		my = 85.0
		mstep = 54.0
	var witem := _menu_item("ball", UiTheme.SKY, "连接钱包（可选）", mx, my)
	(witem[0] as Control).name = "MenuWallet"
	_wallet_status = witem[1]
	var menu_pill_face: StyleBox
	if _p5_on:
		((witem[0] as Button).get_child(1) as Label).add_theme_font_size_override("font_size", 16)
		menu_pill_face = UiTheme._btn_box(UiTheme.CREAM, 14, Color(1, 1, 1, 0.25), 1, 0)
		for button_state in ["normal", "hover", "pressed"]:
			(witem[0] as Button).add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
		var wallet_face := Panel.new()
		wallet_face.name = "MenuWalletFace"
		wallet_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet_face.show_behind_parent = true
		wallet_face.add_theme_stylebox_override("panel", _style(Color("fff3dd"), 10, Color("e4bd77"), 2))
		(witem[0] as Button).add_child(wallet_face)
		((witem[0] as Button).get_child(0) as Control).hide()
		var wallet_art := TextureRect.new()
		wallet_art.name = "MenuWalletArt"
		wallet_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wallet_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var wallet_atlas := AtlasTexture.new()
		wallet_atlas.atlas = load("res://assets/menu/u2-art-wallet.png")
		wallet_atlas.region = Rect2(126, 182, 995, 909)
		wallet_art.texture = wallet_atlas
		wallet_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet_art.position = Vector2(13, 3)
		wallet_art.size = Vector2(40, 40)
		(witem[0] as Button).add_child(wallet_art)
		var wallet_chip := PanelContainer.new()
		wallet_chip.name = "WalletChip"
		wallet_chip.position = Vector2(198, 9)
		wallet_chip.size = Vector2(91, 30)
		wallet_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet_chip.add_theme_stylebox_override("panel", _style(Color(0.42, 0.40, 0.34), 15))
		(witem[0] as Button).add_child(wallet_chip)
		var wallet_chip_text := _mk_label(wallet_chip, "未连接", 11, Color.WHITE)
		wallet_chip_text.name = "WalletChipText"
		wallet_chip_text.add_theme_color_override("font_color", Color.WHITE)
		wallet_chip_text.position = Vector2.ZERO
		wallet_chip_text.size = Vector2(91, 30)
		wallet_chip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wallet_chip_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(witem[0] as Button).pressed.connect(func() -> void:
		audio.click()
		_wallet_panel.visible = not _wallet_panel.visible)
	_menu_intro_items.append(witem[0])
	my += mstep
	var litem := _menu_item("flask", UiTheme.PURPLE, "实验室", mx, my)
	_meta_status = litem[1]
	(litem[0] as Button).pressed.connect(func() -> void:
		audio.click()
		_lab_panel.visible = not _lab_panel.visible
		if _lab_panel.visible:
			_lab_set_mode(_lab_mode))
	_menu_intro_items.append(litem[0])
	_menu_badges["lab"] = _menu_badge(litem[0] as Button)
	my += mstep
	var sitem := _menu_item("bag", UiTheme.GOLD, "萤尘商店", mx, my)
	(sitem[1] as Label).text = "每日背包道具 · 00:00 UTC 刷新"
	(sitem[0] as Button).pressed.connect(func() -> void:
		audio.click()
		_shop_panel.visible = not _shop_panel.visible
		if _shop_panel.visible:
			_refresh_shop())
	_menu_intro_items.append(sitem[0])
	_menu_badges["shop"] = _menu_badge(sitem[0] as Button)
	my += mstep
	var snditem := _menu_item("sound", Color8(255, 150, 60), "设置", mx, my)
	(snditem[1] as Label).text = "声音 · 图形 · 控制 · 界面 · 账户"
	(snditem[0] as Button).pressed.connect(func() -> void:
		audio.click()
		if _sound_panel.visible:
			_sound_panel.visible = false
		else:
			_open_settings())
	_menu_intro_items.append(snditem[0])
	my += mstep
	var uitem := _menu_item("trophy", Color8(90, 170, 255), "伙伴营挑战", mx, my)
	(uitem[1] as Label).text = "终身挑战进度"
	(uitem[0] as Button).pressed.connect(func() -> void:
		audio.click()
		_unlock_panel.visible = not _unlock_panel.visible
		if _unlock_panel.visible:
			_refresh_unlock_panel())
	_menu_intro_items.append(uitem[0])
	_menu_badges["unlock"] = _menu_badge(uitem[0] as Button)
	my += mstep
	# Settings (cycle 9): the bundle's shakeOn toggle (profile
	# settings, defaults shakeOn true / screenShake 1 @1566819).
	# Cycle 19: the shake glyph replaces "wind" (audit §2.3).
	if _p5_on:
		for entry in [[litem, Vector2(8, 134), "res://assets/menu/icon-lab.png", Vector2(84, 66), "MenuLab"],
				[sitem, Vector2(160, 134), "res://assets/menu/u2-art-shop.png", Vector2(91, 72), "MenuShop"],
				[uitem, Vector2(8, 240), "res://assets/menu/u2-art-league.png", Vector2(78, 68), "MenuChallenge"],
				[snditem, Vector2(160, 240), "res://assets/menu/u2-art-settings.png", Vector2(74, 64), "MenuSettings"]]:
			var item_button := entry[0][0] as Control
			item_button.name = entry[4]
			item_button.position = entry[1]
			item_button.custom_minimum_size = Vector2(144, 100)
			item_button.size = Vector2(144, 100)
			item_button.clip_contents = true
			for state in ["normal", "hover", "pressed", "focus"]:
				var tile_face := _style(Color("fff3dd"), 10, Color("e4bd77"), 2)
				item_button.add_theme_stylebox_override(state, tile_face)
			var item_icon := item_button.get_child(0) as Control
			item_icon.hide()
			var art_icon := TextureRect.new()
			art_icon.name = "MenuEntryArt"
			art_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art_icon.texture = load(entry[2]) as Texture2D
			var art_regions := {"MenuLab": Rect2(321, 236, 609, 701), "MenuShop": Rect2(395, 262, 743, 486), "MenuChallenge": Rect2(38, 228, 1178, 825), "MenuSettings": Rect2(22, 86, 1208, 1090)}
			if art_regions.has(entry[4]):
				var atlas := AtlasTexture.new()
				atlas.atlas = art_icon.texture
				atlas.region = art_regions[entry[4]]
				art_icon.texture = atlas
			art_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var art_size: Vector2 = entry[3]
			art_icon.position = Vector2((144.0 - art_size.x) * 0.5, 3.0)
			art_icon.size = Vector2(art_size.x, minf(art_size.y, 66.0))
			item_button.add_child(art_icon)
			var item_title := item_button.get_child(1) as Label
			item_title.position = Vector2(0, 70)
			item_title.size = Vector2(144, 30)
			item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_title.add_theme_font_size_override("font_size", 16)
			(entry[0][1] as Label).hide()
		for badge_key in ["lab", "shop", "unlock"]:
			(_menu_badges[badge_key] as Control).hide()
		var shake_row := _panel(_menu_panel, Vector2(8, 348), Vector2(296, 52), UiTheme.CREAM, 15, Color("e8c48a"), 2)
		shake_row.name = "MenuShake"
		var shake_icon := TextureRect.new()
		shake_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shake_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var shake_atlas := AtlasTexture.new()
		shake_atlas.atlas = load("res://assets/menu/u2-art-vibrate.png")
		shake_atlas.region = Rect2(126, 186, 995, 900)
		shake_icon.texture = shake_atlas
		shake_icon.name = "MenuShakeIcon"
		shake_icon.position = Vector2(12, 8)
		shake_icon.size = Vector2(36, 36)
		shake_row.add_child(shake_icon)
		var shake_label := _mk_label(shake_row, "画面震动", 16, UiTheme.TEXT)
		shake_label.name = "MenuShakeText"
		shake_label.position = Vector2(58, 8)
		shake_label.size = Vector2(132, 36)
		var shake_switch := UiTheme.make_switch(bool(GameProfile.setting("shakeOn")), 0.5)
		shake_switch.name = "ShakeSwitch"
		shake_switch.position = Vector2(196, 1)
		shake_row.add_child(shake_switch)
		shake_switch.pressed.connect(func() -> void:
			var enabled := not bool(GameProfile.setting("shakeOn"))
			GameProfile.set_setting("shakeOn", enabled)
			UiTheme.set_switch(shake_switch, enabled))
	# Cycle 19 (audit punch #18): the right side of the menu
	# was empty scenery — a hero detail card (the original
	# frames an ls-hero) follows starter hover/focus.
	_menu_hero = PanelContainer.new()
	_menu_hero.position = Vector2(580, 100)
	_menu_hero.size = Vector2(600, 320)
	if _p5_on:
		_menu_hero.position = Vector2(686, 80)
		_menu_hero.size = Vector2(300, 338)
	_menu_hero.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_menu_panel.add_child(_menu_hero)
	_menu_hero_box = VBoxContainer.new()
	_menu_hero_box.add_theme_constant_override("separation", 6)
	_menu_hero.add_child(_menu_hero_box)
	_menu_hero_show("bulbasaur")
	_refresh_meta()
	# UI-mobile P5: every menu piece rides one design Control
	# (desktop: full rect, scale 1 — positions unchanged; phone:
	# scaled + centred by _p5_layout_menu).
	_menu_design = Control.new()
	_menu_design.name = "MenuDesign"
	_menu_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _p5_on:
		_menu_design.size = Vector2(1000, 450)
	else:
		_menu_design.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_panel.add_child(_menu_design)
	for c in _menu_panel.get_children():
		if c != _menu_design and c.name != "MenuForestBackground":
			(c as Node).reparent(_menu_design, false)
	if _p5_on:
		var menu_logo := Control.new()
		menu_logo.name = "MenuLogo"
		menu_logo.position = Vector2(8, 0)
		menu_logo.size = Vector2(310, 85)
		menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_design.add_child(menu_logo)
		var logo_art := Control.new()
		logo_art.name = "LogoArt"
		logo_art.size = Vector2(286, 68)
		logo_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_logo.add_child(logo_art)
		var wordmark := _mk_label(logo_art, "SpriteBonk", 50, Color("fffbed"), true)
		wordmark.name = "Wordmark"
		wordmark.size = Vector2(260, 64)
		wordmark.position = Vector2(0, 2)
		wordmark.add_theme_font_override("font", UiTheme.display_font())
		wordmark.add_theme_color_override("font_outline_color", Color("4d2d1d"))
		wordmark.add_theme_constant_override("outline_size", 14)
		wordmark.add_theme_color_override("font_shadow_color", Color("4d2d1d"))
		wordmark.add_theme_constant_override("shadow_outline_size", 10)
		wordmark.add_theme_constant_override("shadow_offset_y", 3)
		var logo_leaf := UiIcon.new("brand_leaf", Color("45611f"), 36)
		logo_leaf.position = Vector2(250, -2)
		logo_leaf.size = Vector2(36, 36)
		logo_art.add_child(logo_leaf)
		var hint_pad := TextureRect.new()
		hint_pad.name = "MenuHintPad"
		hint_pad.texture = load("res://assets/menu/v2-dpad.svg") as Texture2D
		hint_pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hint_pad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hint_pad.position = Vector2(6, 3)
		hint_pad.size = Vector2(24, 24)
		hint_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_back.add_child(hint_pad)
		_menu_hero.hide()
		var hero_stone := TextureRect.new()
		hero_stone.name = "MenuHeroStone"
		hero_stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		hero_stone.texture = load("res://assets/menu/v2-stone.png")
		hero_stone.position = Vector2(312, 288)
		hero_stone.size = Vector2(400, 72)
		hero_stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_panel.add_child(hero_stone)
		_menu_panel.move_child(hero_stone, 1)
		# 萌宠脚底柔和落地接触阴影（独立挂在 _menu_panel 上与石台共缩放，不干扰 _menu_design 防重叠）
		var sh_grad := Gradient.new()
		sh_grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		sh_grad.colors = PackedColorArray([Color(0.08, 0.10, 0.03, 0.44), Color(0.10, 0.12, 0.04, 0.22), Color(0.10, 0.12, 0.04, 0.0)])
		var sh_tex := GradientTexture2D.new()
		sh_tex.gradient = sh_grad
		sh_tex.fill = GradientTexture2D.FILL_RADIAL
		sh_tex.fill_from = Vector2(0.5, 0.5)
		sh_tex.fill_to = Vector2(1.0, 0.5)
		sh_tex.width = 128
		sh_tex.height = 64
		var hero_shadow := TextureRect.new()
		hero_shadow.name = "MenuHeroShadow"
		hero_shadow.texture = sh_tex
		hero_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_shadow.stretch_mode = TextureRect.STRETCH_SCALE
		hero_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_panel.add_child(hero_shadow)
		_menu_panel.move_child(hero_shadow, 2)
		var partner_hero := TextureRect.new()
		partner_hero.name = "MenuPartnerHero"
		partner_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Icon order 2 (PM addendum): the atlas region is
		# 947x1109 — the old 315x240 STRETCH_SCALE frame
		# squashed the mascot ~1.36x horizontally. The frame
		# now keeps the region's aspect (240 tall, ~205 wide),
		# centred on the old frame's centre, feet baseline
		# unchanged (frame bottom stays at y 288).
		partner_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		partner_hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		partner_hero.texture = _menu_feature_portrait(_menu_hero_sp)
		partner_hero.custom_minimum_size = Vector2.ZERO
		partner_hero.position = Vector2(373, 48)
		partner_hero.size = Vector2(205, 240)
		partner_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_design.add_child(partner_hero)
		_menu_design.move_child(partner_hero, 2)
		var starter_back := TextureRect.new()
		starter_back.name = "StarterPanel"
		starter_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		starter_back.stretch_mode = TextureRect.STRETCH_SCALE
		starter_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		starter_back.texture = load("res://assets/menu/v2-starter-tray.svg")
		starter_back.position = Vector2(320, 290)
		starter_back.size = Vector2(420, 140)
		starter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_design.add_child(starter_back)
		_menu_design.move_child(starter_back, 3)
		for leaf_side in [false, true]:
			var leaf_art := TextureRect.new()
			leaf_art.name = "StarterLeafRight" if leaf_side else "StarterLeafLeft"
			leaf_art.texture = load("res://assets/menu/v2-leaves.svg") as Texture2D
			leaf_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			leaf_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			leaf_art.flip_h = leaf_side
			leaf_art.position = Vector2(594 if leaf_side else 430, 303)
			leaf_art.size = Vector2(25, 17)
			leaf_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_menu_design.add_child(leaf_art)
		var starter_next := UiTheme.make_button("❯", "ghost", "small")
		starter_next.name = "StarterNext"
		starter_next.position = Vector2(685, 344)
		starter_next.size = Vector2(36, 38)
		starter_next.add_theme_font_size_override("font_size", 25)
		starter_next.add_theme_color_override("font_color", UiTheme.TEXT)
		for state in ["normal", "hover", "pressed", "focus"]:
			starter_next.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		starter_next.pressed.connect(func() -> void:
			var starter_order := ["bulbasaur", "charmander", "squirtle"]
			var next_idx := (starter_order.find(_menu_hero_sp) + 1) % starter_order.size()
			_menu_hero_show(starter_order[next_idx]))
		_menu_design.add_child(starter_next)
	var start := UiTheme.make_button("开始", "orange", "big")
	start.name = "StartButton"
	start.position = Vector2(760, 554) if not _p5_on else Vector2(710, 348)
	start.size = Vector2(340, 80) if not _p5_on else Vector2(236, 88)
	start.add_theme_font_size_override("font_size", 44 if _p5_on else 32)
	if _p5_on:
		# 改用 CapsuleStyleBox 真半圆胶囊绘制橙钮，采用敦厚黑体粗白字配柔和橙棕描边对齐定稿
		var start_font := load("res://assets/fonts/NotoSC-Black-sub.ttf") as Font
		start.set_meta("u2_start_font", start_font)
		start.add_theme_font_override("font", start_font)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			start.add_theme_color_override(state, Color.WHITE)
		start.add_theme_color_override("font_outline_color", Color("963b06"))
		start.add_theme_constant_override("outline_size", 5)
		start.add_theme_color_override("font_shadow_color", Color(0.50, 0.19, 0.01, 0.65))
		start.add_theme_constant_override("shadow_offset_y", 3)
	start.pressed.connect(func() -> void: _open_loadout(_menu_hero_sp))
	_menu_design.add_child(start)
	if _p5_on:
		# StartButtonArt 隐藏保留作节点兼容，外观完全由 CapsuleStyleBox 原生渲染
		var start_back := TextureRect.new()
		start_back.name = "StartButtonArt"
		start_back.visible = false
		start_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		start_back.stretch_mode = TextureRect.STRETCH_SCALE
		start_back.texture = UiTheme.asset("textures", "button_orange")
		start_back.position = Vector2.ZERO
		start_back.size = Vector2(236, 88)
		start_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_back.show_behind_parent = true
		start.add_child(start_back)
		for leaf_side in [false, true]:
			var leaf := TextureRect.new()
			leaf.name = "StartLeafRight" if leaf_side else "StartLeafLeft"
			leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			leaf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			leaf.texture = load("res://assets/menu/v2-leaves.svg")
			leaf.flip_h = leaf_side
			leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
			start.add_child(leaf)
	if _p5_on:
		var caption_back := Panel.new()
		caption_back.name = "StartCaptionBack"
		caption_back.size = Vector2(236, 30)
		caption_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption_back.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_menu_design.add_child(caption_back)
		var start_caption := _mk_label(_menu_design, "进入出战配置", 17, Color("fffdf2"))
		start_caption.name = "StartCaption"
		start_caption.add_theme_color_override("font_color", Color("fffdf2"))
		start_caption.add_theme_color_override("font_outline_color", Color("4b2810"))
		start_caption.add_theme_constant_override("outline_size", 5)
		start_caption.add_theme_color_override("font_shadow_color", Color(0.18, 0.09, 0.02, 0.6))
		start_caption.add_theme_constant_override("shadow_offset_y", 2)
		start_caption.size = Vector2(220, 22)
		start_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_caption.add_theme_font_override("font", _font_display)
	var resources := HBoxContainer.new()
	resources.name = "Resources"
	resources.position = Vector2(820, 26) if not _p5_on else Vector2(698, 8)
	resources.add_theme_constant_override("separation", 0 if _p5_on else 10)
	for entry in [["萤尘 %d  +" % GameProfile.stardust(), "lab"], ["累计 %d  +" % int(GameProfile.data.get("totalStardust", 0)), "shop"]]:
		var pill := UiTheme.make_button(String(entry[0]), "ghost", "normal")
		var dest: String = entry[1]
		if _p5_on:
			pill.text = ""
			for button_state in ["normal", "hover", "pressed"]:
				pill.add_theme_stylebox_override(button_state, menu_pill_face)
			var pill_min_w := 142.0 if dest == "lab" else 146.0
			pill.set_meta("p5_pill_min_w", pill_min_w)
			pill.custom_minimum_size = Vector2(pill_min_w, 34)
			var resource_icon: Control
			if dest == "lab":
				resource_icon = UiIcon.new("spark", Color("aa4ace"), 24)
			else:
				var total_star := TextureRect.new()
				total_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				total_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				total_star.texture = UiTheme.asset("decorations", "star_filled")
				resource_icon = total_star
			resource_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			resource_icon.position = Vector2(14, 6)
			resource_icon.size = Vector2(22, 22)
			pill.add_child(resource_icon)
			var resource_text := _mk_label(pill, String(entry[0]), 17, UiTheme.TEXT)
			resource_text.name = "ResourceText"
			resource_text.position = Vector2(42, 2)
			resource_text.size = Vector2(96, 30)
			resource_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var text_width := resource_text.get_minimum_size().x
			resource_text.size.x = maxf(96.0, text_width)
			pill.custom_minimum_size.x = maxf(pill_min_w, 52.0 + text_width)
		pill.pressed.connect(func() -> void:
			if dest == "lab":
				_lab_panel.show()
				_refresh_lab()
			else:
				_shop_panel.show()
				_refresh_shop())
		resources.add_child(pill)
	_menu_design.add_child(resources)
	_menu_intro()
	if _p5_on:
		var starter_items: Array[Control] = []
		for child in _menu_design.get_children():
			var ctl := child as Control
			if ctl and ctl.position.x >= 320 and ctl.position.x < 710 and ctl.position.y >= 290:
				starter_items.append(ctl)
		if _menu_starters and not starter_items.has(_menu_starters):
			starter_items.append(_menu_starters)
		var selection := Control.new()
		selection.name = "StarterSelection"
		selection.position = Vector2(320, 290)
		selection.size = Vector2(420, 140)
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_design.add_child(selection)
		for ctl in starter_items:
			ctl.reparent(selection, false)
			ctl.position -= selection.position
	# 手机版主菜单左下角操作提示条常驻显示（对齐定稿 U2_final.jpg 视觉平衡），不因首次进局永久消失
	var hint_preferences := ConfigFile.new()
	hint_preferences.load("user://menu_presentation.cfg")
	var show_first_hint := true if _p5_on else not bool(hint_preferences.get_value("menu", "hint_seen", false))
	if _menu_hint:
		_menu_hint.visible = show_first_hint
		var hint_backing := _menu_hint.get_meta("back") as Control
		if hint_backing:
			hint_backing.visible = show_first_hint
	var hint_pad := hint_back.get_node_or_null("MenuHintPad") as Control
	if hint_pad:
		hint_pad.visible = show_first_hint
	start.pressed.connect(func() -> void:
		if not _p5_on:
			hint_preferences.set_value("menu", "hint_seen", true)
			hint_preferences.save("user://menu_presentation.cfg")
			if _menu_hint:
				_menu_hint.hide()
				(_menu_hint.get_meta("back") as Control).hide()
			if hint_pad:
				hint_pad.hide())
	if _first_starter_card:
		# A visible focus ring from boot (audit punch #18);
		# the card faces already carry the gold focus style.
		_first_starter_card.call_deferred("grab_focus")

## Cycle 19 (audit punch #18): menu items stagger in like
## the original's mm-item (--d = index x 0.05 s @1822478):
## a short fade + slide from +16 px, same step.
func _menu_intro() -> void:
	for i in range(_menu_intro_items.size()):
		var c := _menu_intro_items[i] as Control
		if not is_instance_valid(c):
			continue
		var base_x := c.position.x
		if not _p5_on:
			c.position.x = base_x + 16.0
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(c, "modulate:a", 1.0, 0.22)
		if not _p5_on:
			tw.parallel().tween_property(c, "position:x", base_x, 0.22)

## Cycle 19 (audit punch #18): an mm-badge count chip on a
## menu item (hidden at zero). Returns the badge panel;
## _set_badge drives it from _refresh_meta.
func _menu_badge(b: Button) -> PanelContainer:
	var chip := UiTheme.chip("0", UiTheme.RED, 11)
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.offset_left = -36
	chip.offset_right = -6
	chip.offset_top = -8
	chip.offset_bottom = 16
	chip.visible = false
	b.add_child(chip)
	return chip

func _set_badge(key: String, n: int) -> void:
	var chip := _menu_badges.get(key) as PanelContainer
	if chip == null:
		return
	chip.visible = n > 0 and not _p5_on
	if n > 0 and chip.get_child_count() > 0:
		(chip.get_child(0) as Label).text = str(n)

## Cycle 19: the menu hero card's content for one species
## (portrait, names, type chips, six base stats, ult line).
func _menu_hero_show(sp: String) -> void:
	_menu_hero_sp = sp
	if _p5_on and _menu_starters and _menu_starters.get_child_count() > 0:
		var colors := {"bulbasaur": Color("e7f0d8"), "charmander": Color("fde6bd"), "squirtle": Color("e3d1f4")}
		var rims := {"bulbasaur": Color("e8c48a"), "charmander": Color("e8c48a"), "squirtle": Color("e9c7ed")}
		for child in _menu_starters.find_children("*", "Button", true, false):
			if child is Button and child.has_meta("starter_species") and not child.is_queued_for_deletion():
				var species := String(child.get_meta("starter_species"))
				var selected := species == sp
				var face := _style(colors.get(species, UiTheme.CREAM), 16,
					UiTheme.GREEN_DEEP if selected else rims.get(species, Color("e8c48a")), 3 if selected else 2)
				for button_state in ["normal", "hover", "pressed", "focus"]:
					child.add_theme_stylebox_override(button_state, face)
				(child.get_node("SelectedMark") as Control).visible = selected
				if selected:
					_menu_starters.ensure_control_visible(child)
	if _menu_hero_box == null:
		return
	for c in _menu_hero_box.get_children():
		_menu_hero_box.remove_child(c)
		c.queue_free()
	var pt := TextureRect.new()
	pt.texture = UiTheme.portrait(sp)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pt.custom_minimum_size = Vector2(280, 280) if not _p5_on else Vector2(210, 210)
	pt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_hero_box.add_child(pt)

func _build_wallet_panel(root: Control) -> void:
	_wallet_panel = PanelContainer.new()
	_wallet_panel.set_anchors_preset(Control.PRESET_CENTER)
	_wallet_panel.offset_left = -340
	_wallet_panel.offset_right = 340
	_wallet_panel.offset_top = -210
	_wallet_panel.offset_bottom = 210
	_wallet_panel.visible = false
	_wallet_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_wallet_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_wallet_panel.add_child(vb)
	# 对齐定稿 U6_final.jpg：顶部两侧嫩绿叶簇夹粗大「钱包」，地址条配天蓝圆盘钱包徽标，三颗糖果大胶囊配洁白描边粗字
	if _p5_on:
		var title_wrap := CenterContainer.new()
		vb.add_child(title_wrap)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 10)
		title_wrap.add_child(title_row)
		var ll := UiTheme.art("leaf_sprig", Vector2(28, 28))
		ll.flip_h = true
		title_row.add_child(ll)
		var title := _mk_dlabel(title_row, "钱包", 32, UiTheme.TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lr := UiTheme.art("leaf_sprig", Vector2(28, 28))
		title_row.add_child(lr)
	else:
		var title := _mk_dlabel(vb, "钱包", 30, UiTheme.TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vb.add_child(header)
	var w_badge := UiBadge.new("wallet", Color("2ea8f0"), 60)
	w_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(w_badge)
	_wallet_edit = LineEdit.new()
	_wallet_edit.placeholder_text = "粘贴公开地址"
	_wallet_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_edit.add_theme_font_override("font", _font)
	_wallet_edit.add_theme_font_size_override("font_size", 17)
	_wallet_edit.add_theme_color_override("font_color", UiTheme.TEXT)
	_wallet_edit.add_theme_color_override("font_placeholder_color", UiTheme.MUTED)
	var edit_sb := _style(Color(1.0, 0.99, 0.955, 0.96), 24, Color("e2c68e"), 1.5, true)
	edit_sb.content_margin_left = 18
	edit_sb.content_margin_right = 18
	edit_sb.content_margin_top = 10
	edit_sb.content_margin_bottom = 10
	_wallet_edit.add_theme_stylebox_override("normal", edit_sb)
	header.add_child(_wallet_edit)
	var bal_row := HBoxContainer.new()
	bal_row.add_theme_constant_override("separation", 12)
	vb.add_child(bal_row)
	_wallet_balance = _mk_dlabel(bal_row, "尚未连接", 40 if _p5_on else 36, UiTheme.TEXT)
	_wallet_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wallet_balance.custom_minimum_size.y = 76
	_wallet_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_retry = UiTheme.make_button("重试读取余额", "ghost", "small")
	_wallet_retry.visible = false
	_wallet_retry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wallet_retry.pressed.connect(func() -> void: wallet.fetch_balance())
	bal_row.add_child(_wallet_retry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var cbtn := UiTheme.make_button("连接", "green", "big")
	cbtn.pressed.connect(func() -> void:
		if wallet.is_wallet_connected():
			wallet.disconnect_wallet()
		elif _wallet_edit.text.strip_edges() != "":
			if not wallet.connect_with_address(_wallet_edit.text):
				_wallet_balance.text = "地址无效，请重试"
		else:
			_wallet_balance.text = "正在唤起 Solana 钱包授权..."
			var err := wallet.request_authorize()
			if err != "":
				_wallet_balance.text = err
	)
	row.add_child(cbtn)
	wallet.auth_failed.connect(func(reason: String) -> void:
		if _wallet_balance:
			_wallet_balance.text = "授权未完成：%s" % reason
	)
	var copy := UiTheme.make_button("复制地址", "blue", "big")
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(wallet.address if wallet.is_wallet_connected() else _wallet_edit.text))
	row.add_child(copy)
	var xbtn := UiTheme.make_button("关闭", "orange", "big")
	xbtn.pressed.connect(func() -> void: _wallet_panel.visible = false)
	xbtn.set_meta("p5_primary", true)
	row.add_child(xbtn)
	for btn_info in [[cbtn, Color("326b08")], [copy, Color("13548c")], [xbtn, Color("8f3905")]]:
		var btn_c := btn_info[0] as Button
		btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _p5_on:
			for st in ["font_color", "font_hover_color", "font_pressed_color"]:
				btn_c.add_theme_color_override(st, Color.WHITE)
			btn_c.add_theme_color_override("font_outline_color", btn_info[1])
			btn_c.add_theme_constant_override("outline_size", 4)
	cbtn.set_meta("wallet_connect", true)
	_wallet_panel.set_meta("connect_button", cbtn)
	var note := _mk_label(vb, "可选 · 仅查看公开余额，不签名、不交易。断开连接会清除保存的地址。", 14, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _refresh_wallet_ui() -> void:
	if _wallet_status == null or wallet == null:
		return
	var connected: bool = wallet.is_wallet_connected()
	if _p5_on and _wallet_status.get_parent() is Button:
		var wallet_button := _wallet_status.get_parent() as Button
		var title := wallet_button.get_child(1) as Label
		title.text = "钱包"
		var chip := wallet_button.get_node_or_null("WalletChip") as Control
		if chip:
			chip.add_theme_stylebox_override("panel", _style(Color("78b52b") if connected else Color(0.42, 0.40, 0.34), 15))
			(chip.get_node("WalletChipText") as Label).text = "● 已连接" if connected else "未连接"
	if _wallet_balance == null:
		_wallet_status.text = wallet.short_address() if connected else "游客模式"
		return
	if _wallet_panel and _wallet_panel.has_meta("connect_button"):
		(_wallet_panel.get_meta("connect_button") as Button).text = "断开连接" if connected else "连接"
	if connected:
		var failed := wallet.balance_state == "failed"
		var bal := "读取中…"
		if wallet.last_balance_sol >= 0.0:
			bal = "%.4f SOL" % wallet.last_balance_sol
		_wallet_status.text = wallet.short_address()
		_wallet_edit.text = wallet.address
		_wallet_balance.text = "余额读取失败" if failed else bal
		_wallet_retry.visible = failed
	else:
		_wallet_status.text = "游客模式"
		_wallet_balance.text = "尚未连接"
		_wallet_edit.text = ""
		_wallet_retry.visible = false

func _refresh_meta() -> void:
	if _meta_status:
		_meta_status.text = "萤尘 %d · 伙伴营 %d 只" % [GameProfile.stardust(), (GameProfile.data.get("league", []) as Array).size()]
	# Cycle 19: mm-badge counts (audit punch #18) — Lab rows
	# buyable right now, shop quota left today, challenges
	# completed.
	if not _menu_badges.is_empty():
		var lab_n := 0
		for id in GameProfile.LAB_ORDER:
			var cst := GameProfile.lab_cost(id)
			if cst >= 0 and GameProfile.stardust() >= cst:
				lab_n += 1
		_set_badge("lab", lab_n)
		var counts := GameProfile.shop_bought_today(GameProfile.shop_now())
		var shop_n := 0
		for it in GameProfile.SHOP_ITEMS:
			shop_n += maxi(0, int(it["daily"]) - int(counts.get(String(it["id"]), 0)))
		_set_badge("shop", shop_n)
		var done_n := 0
		for key in GameProfile.challenge_order():
			if GameProfile.challenge_done(key):
				done_n += 1
		_set_badge("unlock", done_n)
	_refresh_starter_unlocks()

## League-captured species become playable starters (cycle 8).
func _refresh_starter_unlocks() -> void:
	if _starter_unlock_box == null:
		return
	_starter_unlock_box.hide()
	for c in _starter_unlock_box.get_children():
		c.queue_free()
	for fam in GameProfile.data.get("league", []):
		var key := GameData.species_key_for_family(int(fam))
		if key == "" or key in ["bulbasaur", "charmander", "squirtle"]:
			continue
		# Cycle 17: unlocks render as starter cards, like the
		# base three (portrait / types / stats / 伙伴营解锁 tag).
		_starter_unlock_box.add_child(_starter_card(key, true, 340.0 if _p5_on else 372.0))
		_starter_unlock_box.show()

# ------------------------------------------------------------- Lab (cycle 7)
func _build_lab_panel(root: Control) -> void:
	_lab_panel = PanelContainer.new()
	_lab_panel.set_anchors_preset(Control.PRESET_CENTER)
	_lab_panel.offset_left = -420
	_lab_panel.offset_right = 420
	_lab_panel.offset_top = -280
	_lab_panel.offset_bottom = 280
	_lab_panel.visible = false
	_lab_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_lab_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4 if _p5_on else 8)
	_lab_panel.add_child(vb)
	# 对齐定稿 U4_final.jpg：顶部金色月桂枝夹着粗金立体大字标题，下方纯白紫色星尘胶囊＋切换页签
	if _p5_on:
		var head_wrap := CenterContainer.new()
		vb.add_child(head_wrap)
		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 8)
		head_wrap.add_child(head_row)
		var ll := UiTheme.art("laurel_gold", Vector2(26, 30))
		ll.flip_h = true
		head_row.add_child(ll)
		var t := _mk_dlabel(head_row, "实验室 · 永久升级", 24, Color("ffe066"), true)
		t.add_theme_color_override("font_outline_color", Color("4d2d14"))
		t.add_theme_constant_override("outline_size", 4)
		t.add_theme_color_override("font_shadow_color", Color(0.25, 0.14, 0.04, 0.65))
		t.add_theme_constant_override("shadow_offset_y", 2)
		var lr := UiTheme.art("laurel_gold", Vector2(26, 30))
		head_row.add_child(lr)
		var bal_wrap := CenterContainer.new()
		vb.add_child(bal_wrap)
		var bal_pill := PanelContainer.new()
		var b_sb := _style(Color(1.0, 0.995, 0.975, 0.95), 14, Color("e5cfa0"), 1.5, true)
		b_sb.content_margin_left = 16
		b_sb.content_margin_right = 16
		b_sb.content_margin_top = 2
		b_sb.content_margin_bottom = 2
		bal_pill.add_theme_stylebox_override("panel", b_sb)
		bal_wrap.add_child(bal_pill)
		var bal_hb := HBoxContainer.new()
		bal_hb.add_theme_constant_override("separation", 6)
		bal_pill.add_child(bal_hb)
		var sp_ic := UiIcon.new("spark", Color("9a42de"), 16)
		sp_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bal_hb.add_child(sp_ic)
		_lab_info = _mk_label(bal_hb, "", 14, UiTheme.TEXT)
		_lab_info.add_theme_font_override("font", UiTheme.display_font())
		_lab_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var t := _mk_dlabel(vb, "实验室 · 永久升级", 20, UiTheme.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lab_info = _mk_label(vb, "", 14, Color("6e502f"))
		_lab_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tabrow := HBoxContainer.new()
	tabrow.add_theme_constant_override("separation", 10)
	tabrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(tabrow)
	_lab_tab_upgrades = UiTheme.make_button("升级", "ghost", "normal" if _p5_on else "small")
	_lab_tab_upgrades.custom_minimum_size = Vector2(130, 36 if _p5_on else 32)
	_lab_tab_upgrades.pressed.connect(func() -> void: _lab_set_mode("upgrades"))
	tabrow.add_child(_lab_tab_upgrades)
	_lab_tab_items = UiTheme.make_button("物品档案", "ghost", "normal" if _p5_on else "small")
	_lab_tab_items.custom_minimum_size = Vector2(130, 36 if _p5_on else 32)
	_lab_tab_items.pressed.connect(func() -> void: _lab_set_mode("items"))
	tabrow.add_child(_lab_tab_items)
	# 手机端取消外层整页套娃 ScrollContainer，让左右栏一屏完整展示不再把右侧「升级」大按钮截出画外；仅物品档案页独立滚动
	var scroll: ScrollContainer = null
	_lab_list = VBoxContainer.new()
	_lab_list.add_theme_constant_override("separation", 4)
	_lab_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab_items_list = VBoxContainer.new()
	_lab_items_list.add_theme_constant_override("separation", 6)
	_lab_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab_items_list.visible = false
	if _p5_on:
		_lab_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(_lab_list)
		var archive_scroll := ScrollContainer.new()
		archive_scroll.name = "ArchiveScroll"
		archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		archive_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		archive_scroll.visible = false
		vb.add_child(archive_scroll)
		archive_scroll.add_child(_lab_items_list)
	else:
		scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 400)
		vb.add_child(scroll)
		var lists := VBoxContainer.new()
		lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(lists)
		lists.add_child(_lab_list)
		lists.add_child(_lab_items_list)
	var xbtn := UiTheme.make_button("关闭", "ghost", "small")
	xbtn.pressed.connect(func() -> void: _lab_panel.visible = false)
	vb.add_child(xbtn)
	_p5_overlay(scroll, xbtn)
	_lab_set_mode("upgrades")

func _refresh_lab() -> void:
	if _lab_list == null:
		return
	for c in _lab_list.get_children():
		_lab_list.remove_child(c)
		c.queue_free()
	_lab_info.text = ("萤尘 %d · 累计 %d" if _p5_on else "萤尘 %d · 累计 %d") % [GameProfile.stardust(), int(GameProfile.data.get("totalStardust", 0))]
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab_list.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	var node_scroll := ScrollContainer.new()
	node_scroll.custom_minimum_size = Vector2(360 if _p5_on else 300, 200 if _p5_on else 300)
	node_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(node_scroll)
	node_scroll.add_child(grid)
	grid.draw.connect(func() -> void:
		for i in range(grid.get_child_count()):
			var node := grid.get_child(i) as Control
			var c_a := node.position + Vector2(node.size.x * 0.5, 29.0)
			for j in [i + 1 if i % 4 < 3 else -1, i + 4]:
				if j >= 0 and j < grid.get_child_count():
					var other := grid.get_child(j) as Control
					var c_b := other.position + Vector2(other.size.x * 0.5, 29.0)
					grid.draw_line(c_a, c_b, Color("b89660"), 4.5, true))
	grid.resized.connect(func() -> void: grid.queue_redraw())
	for id in GameProfile.LAB_ORDER:
		var lv := GameProfile.lab_level(id)
		# 定稿 U4_final.jpg 透明底节点按钮：圆盘居中＋下方小胶囊等级牌，消除难看的椭圆奶油底壳
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(74, 72)
		b.size = Vector2(74, 72)
		var empty_sb := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty_sb)
		b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 37, UiTheme.GOLD, 2, false))
		b.tooltip_text = String(GameProfile.LAB[id]["label"])
		var is_sel: bool = String(id) == _lab_selected
		if is_sel:
			# 选中态亮金色发光圆环（居中贴合圆盘，不越界切上格）
			var glow_ring := Panel.new()
			glow_ring.position = Vector2(8, 0)
			glow_ring.size = Vector2(58, 58)
			glow_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow_ring.add_theme_stylebox_override("panel", _style(Color(1.0, 0.84, 0.25, 0.28), 29, Color("ffb81c"), 3, false))
			b.add_child(glow_ring)
		var accent := UiTheme.GREEN_DEEP if lv > 0 else UiTheme.MUTED
		if is_sel:
			accent = UiTheme.ORANGE
		# 全部亮出对应能力的彩底圆盘图标（对齐定稿 U4_final.jpg）；仅 0 级且未选中时微柔和区分已点亮态
		var badge := UiBadge.new(_lab_icon(id), accent, 54)
		badge.position = Vector2(10, 2)
		if lv == 0 and not is_sel:
			badge.modulate = Color(0.92, 0.90, 0.86, 0.90)
		b.add_child(badge)
		var lv_pill := PanelContainer.new()
		lv_pill.position = Vector2(10, 48)
		lv_pill.size = Vector2(54, 24)
		lv_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv_pill.add_theme_stylebox_override("panel", _style(Color("fff6df") if is_sel else (Color("e8f6da") if lv > 0 else Color(1.0, 0.99, 0.96, 0.94)), 11, Color("c98b2c") if is_sel else (Color("8ec24f") if lv > 0 else Color("d8c094")), 1.5, false))
		b.add_child(lv_pill)
		var lvl_l := _label_in(lv_pill, "已满" if GameProfile.lab_cost(id) < 0 else "%d级" % lv, Vector2.ZERO, Vector2(54, 24), 14, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		lvl_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var selected: String = id
		b.pressed.connect(func() -> void:
			_lab_selected = selected
			_refresh_lab())
		grid.add_child(b)
	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(310 if _p5_on else 280, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var det_sb := _style(Color(1.0, 0.99, 0.96, 0.96), 18, Color("e5cfa0"), 1.5, true)
	det_sb.content_margin_left = 18
	det_sb.content_margin_right = 18
	det_sb.content_margin_top = 6
	det_sb.content_margin_bottom = 6
	detail.add_theme_stylebox_override("panel", det_sb)
	columns.add_child(detail)
	_lab_detail = VBoxContainer.new()
	_lab_detail.add_theme_constant_override("separation", 3)
	detail.add_child(_lab_detail)
	var cfg: Dictionary = GameProfile.LAB[_lab_selected]
	var level := GameProfile.lab_level(_lab_selected)
	var cost := GameProfile.lab_cost(_lab_selected)
	# 顶部天蓝发光方圆图标卡（对齐定稿 U4_final.jpg）
	var hero_card := PanelContainer.new()
	hero_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hc_sb := _style(Color("bfe8ff"), 14, Color("8cc8ec"), 2, true)
	hc_sb.set_content_margin_all(4)
	hero_card.add_theme_stylebox_override("panel", hc_sb)
	_lab_detail.add_child(hero_card)
	var hero := UiBadge.new(_lab_icon(_lab_selected), UiTheme.GREEN_DEEP, 38 if _p5_on else 72)
	hero_card.add_child(hero)
	var title := _mk_dlabel(_lab_detail, String(cfg["label"]), 18, UiTheme.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for stat_pair in [
		["当前等级", "%d" % level],
		["最高等级", "%d" % int(cfg["max"])],
		["升级消耗", ("%d 萤尘" % cost) if cost >= 0 else "已满级"]
	]:
		var srow := HBoxContainer.new()
		var sl_l := _mk_label(srow, String(stat_pair[0]), 15, Color("6b4f2f"))
		sl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sl_r := _mk_label(srow, String(stat_pair[1]), 15, UiTheme.TEXT)
		sl_r.add_theme_font_override("font", UiTheme.display_font())
		sl_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_lab_detail.add_child(srow)
		var sep := ColorRect.new()
		sep.color = Color("ead8b5")
		sep.custom_minimum_size.y = 1.5
		_lab_detail.add_child(sep)
	var buy_sp := Control.new()
	buy_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab_detail.add_child(buy_sp)
	var buy := UiTheme.make_button("升级" if cost >= 0 else "已满", "orange", "big")
	buy.custom_minimum_size = Vector2(200, 44)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		buy.add_theme_color_override(st, Color.WHITE)
	buy.add_theme_color_override("font_outline_color", Color("8f3905"))
	buy.add_theme_constant_override("outline_size", 4)
	buy.disabled = cost < 0 or GameProfile.stardust() < cost
	if buy.disabled:
		var gray_b := _style(Color(0.68, 0.69, 0.72, 0.92), 24, Color(0.54, 0.55, 0.58), 1.5, false)
		for st in ["normal", "hover", "pressed", "disabled"]:
			buy.add_theme_stylebox_override(st, gray_b)
		buy.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.95))
	buy.pressed.connect(func() -> void:
		if GameProfile.lab_buy(_lab_selected):
			audio.coin()
			if player and is_instance_valid(player):
				player.recalc()
			_refresh_lab()
			_refresh_meta()
		else:
			audio.deny())
	_lab_detail.add_child(buy)
	if _p5_on and _lab_panel != null and _lab_panel.visible:
		_apply_ui_scale()

## Icon order 2 — lab mapping table (a required deliverable of
## the order). The U4 art names 11 patterns for the lab's 24
## upgrade ids; unpictured ids reuse the nearest pattern family
## (documented per group). Locked (level 0) nodes draw
## lab_locked instead — see _refresh_lab. Icons only; effects,
## costs and order are untouched. The old wrong routes are gone:
## gold is no longer the wallet, archive no longer the bell,
## magnet no longer the fallback ring.
const LAB_ICON := {
	"dmg": "lab_sword", "atkspd": "lab_sword", "slot-move": "lab_sword",
	"armor": "lab_shield", "bag": "lab_shield", "party": "lab_shield",
	"hp": "lab_heart", "revive": "lab_heart",
	"spd": "lab_wing", "skip": "lab_wing",
	"ult": "lab_muscle", "gold": "lab_muscle",
	"luck": "lab_clover", "xp": "lab_clover",
	"research": "lab_hourglass", "archive": "lab_hourglass", "reroll": "lab_hourglass",
	"crit": "lab_target", "area": "lab_target", "magnet": "lab_target", "banish": "lab_target",
	"choice4": "lab_sparkle",
	"regen": "lab_potion", "slot-vit": "lab_potion",
}
func _lab_icon(id: String) -> String:
	return String(LAB_ICON.get(id, "lab_sparkle"))

## Cycle 19: Lab tab switch (the bundle's Lab screen has
## lab/items modes; SL @1897612).
func _lab_set_mode(mode: String) -> void:
	_lab_mode = mode
	if _lab_list:
		_lab_list.visible = mode == "upgrades"
	if _lab_items_list:
		_lab_items_list.visible = mode == "items"
	var arc_s := _lab_panel.find_child("ArchiveScroll", true, false) as Control if _lab_panel else null
	if arc_s:
		arc_s.visible = mode == "items"
	# 选中/未选页签视觉对比：选中亮暖金胶囊，未选纯白奶油胶囊（对齐定稿 U4_final.jpg）
	var sb_on := _style(Color("f5d27b"), 20, Color("c99636"), 2, true)
	var sb_off := _style(Color(1.0, 0.99, 0.96, 0.95), 20, Color("dec79b"), 1.5, true)
	for sb_t in [sb_on, sb_off]:
		sb_t.content_margin_left = 18
		sb_t.content_margin_right = 18
	if _lab_tab_upgrades:
		var u_on := mode == "upgrades"
		_lab_tab_upgrades.disabled = u_on
		for st in ["normal", "hover", "pressed", "disabled"]:
			_lab_tab_upgrades.add_theme_stylebox_override(st, sb_on if u_on else sb_off)
		_lab_tab_upgrades.add_theme_color_override("font_color", UiTheme.TEXT)
		_lab_tab_upgrades.add_theme_color_override("font_disabled_color", UiTheme.TEXT)
	if _lab_tab_items:
		var i_on := mode == "items"
		_lab_tab_items.disabled = i_on
		for st in ["normal", "hover", "pressed", "disabled"]:
			_lab_tab_items.add_theme_stylebox_override(st, sb_on if i_on else sb_off)
		_lab_tab_items.add_theme_color_override("font_color", UiTheme.TEXT)
		_lab_tab_items.add_theme_color_override("font_disabled_color", UiTheme.TEXT)
	if mode == "items":
		_refresh_lab_items()
	else:
		_refresh_lab()

## Cycle 19: the Archive tab. Header = the bundle's
## "Archivo {n}/{total}" counter (@1901033; at capacity 0
## it reads as an unlock hint). Preset row (UP @1765590),
## then one row per catalogue item with the per-item
## Archivar / Devolver button (@1902048) whose handler
## denies on a refused archive (@1903754).
func _refresh_lab_items() -> void:
	if _lab_items_list == null:
		return
	for c in _lab_items_list.get_children():
		c.queue_free()
	var cap := GameProfile.archive_capacity()
	var arch := GameProfile.archived_items()
	var head := _mk_label(_lab_items_list, "档案 %d/%d" % [arch.size(), cap], 16, UiTheme.TEXT)
	head.add_theme_font_override("font", UiTheme.display_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cap <= 0:
		var empty_card := PanelContainer.new()
		empty_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ec_sb := _style(Color(1.0, 0.99, 0.96, 0.94), 16, Color("e5cfa0"), 1.5, true)
		ec_sb.content_margin_left = 28
		ec_sb.content_margin_right = 28
		ec_sb.content_margin_top = 18
		ec_sb.content_margin_bottom = 18
		empty_card.add_theme_stylebox_override("panel", ec_sb)
		_lab_items_list.add_child(empty_card)
		var hint := _mk_label(empty_card, "在「升级」页购买「档案位+5/级」解锁档案。\n归档的物品不会再从宝箱中开出。", 15, Color("6e502f"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _p5_on and _lab_panel != null and _lab_panel.scale.x > 0.01:
			_p5_fit(_lab_panel, float(_lab_panel.get_meta("p5_sm", _lab_panel.scale.x)))
		return
	var hint2 := _mk_label(_lab_items_list, "归档的物品不会再从宝箱中开出。", 13, Color("6e502f"))
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Presets: save the current set (max 3), apply, delete
	# (deleting a preset never changes the Archive itself).
	var presets := GameProfile.archive_presets()
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	_lab_items_list.add_child(prow)
	var pl := _mk_label(prow, "档案预设", 14, UiTheme.TEXT)
	for i in range(presets.size()):
		var pd: Dictionary = presets[i]
		var idx := i
		var ab := UiTheme.make_button(
			String(pd.get("name", "预设")) + ("（使用中）" if GameProfile.archive_preset_active() == i else ""),
			"green", "small")
		ab.disabled = GameProfile.archive_preset_active() == i
		ab.pressed.connect(func() -> void:
			var missed := GameProfile.archive_preset_apply(idx)
			audio.click()
			if missed > 0:
				show_banner("预设应用完成，%d 件未能归档（档案已满）" % missed, 2.5)
			_refresh_lab_items())
		prow.add_child(ab)
		var db := UiTheme.make_button("删", "ghost", "small")
		db.pressed.connect(func() -> void:
			GameProfile.archive_preset_delete(idx)
			audio.click()
			_refresh_lab_items())
		prow.add_child(db)
	var sb := UiTheme.make_button("存为预设", "ghost", "small")
	sb.disabled = presets.size() >= GameProfile.ARCHIVE_PRESET_MAX
	sb.pressed.connect(func() -> void:
		if GameProfile.archive_preset_save("预设 %d" % (GameProfile.archive_presets().size() + 1)):
			audio.coin()
		else:
			audio.deny()
		_refresh_lab_items())
	prow.add_child(sb)
	var full := arch.size() >= cap
	# Cycle 21: the archive domain is the bundle's item
	# defs (126 keys), not the retired vitamin pool.
	var item_keys := GameData.item_keys()
	item_keys.sort()
	for key in item_keys:
		var k := String(key)
		var idef := GameData.item_def(k)
		var is_arch := arch.has(k)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_item_icon_rect(k, 28.0))
		var name_l := _mk_label(row, "%s【%s】" % [_item_zh_name(k),
			String(GameData.RARITY_NAMES[GameData.item_rarity(k)])], 15, UiTheme.TEXT)
		name_l.custom_minimum_size = Vector2(300, 0)
		if is_arch:
			var st := UiTheme.chip("已归档", Color(UiTheme.INK_DEEP, 0.92), 12, UiTheme.GOLD)
			st.custom_minimum_size = Vector2(64, 28)
			row.add_child(st)
		var b := UiTheme.make_button("取回" if is_arch else "归档",
			"ghost" if is_arch else "green", "small")
		b.disabled = (not is_arch) and full
		var captured: String = k
		var captured_arch: bool = is_arch
		b.pressed.connect(func() -> void:
			if GameProfile.archive_item(captured, not captured_arch):
				audio.click()
				_refresh_lab_items()
			else:
				audio.deny())
		row.add_child(b)
		_lab_items_list.add_child(row)

# ------------------------------------------------- cycle 16: audio glue
## applySettings (bundle @2146366): push the profile's four
## volumes into the engine and re-evaluate the hidden mute.
func _apply_audio_settings() -> void:
	if audio == null:
		return
	audio.set_volumes({
		"master": float(GameProfile.setting("master")),
		"music": float(GameProfile.setting("music")),
		"sfx": float(GameProfile.setting("sfx")),
		"cries": float(GameProfile.setting("cries"))})
	_update_hidden_mute()

func _update_hidden_mute() -> void:
	if audio == null:
		return
	# Their rule: (hidden || unfocused) && muteHidden.
	audio.set_hidden_mute((not _window_focused) and bool(GameProfile.setting("muteHidden")))

var _window_focused := true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		_update_hidden_mute()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
		_update_hidden_mute()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_update_hidden_mute()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true
		_update_hidden_mute()

## The music director: the bundle re-asserts
## playTrack(musicFor()) twice a second — boss track while the
## guardian lives, else the run's drawn ingame track; menus
## play the menu track (Pz @2134499).
func _music_director_tick(delta: float) -> void:
	if audio == null:
		return
	_music_t -= delta
	if _shop_panel != null and _shop_panel.visible and Engine.get_process_frames() % 30 == 0:
		_refresh_shop_countdown()
	if _music_t > 0.0:
		return
	_music_t = 0.5
	var want := "menu"
	if state != "menu" and _run_music != "":
		want = _run_music
		if guardian != null and is_instance_valid(guardian) and guardian.hp > 0.0:
			want = "boss"
	if audio.current_track != want:
		audio.play_track(want)

# ------------------------------------------------- cycle 16: daily shop
## The meta stardust shop (Profile shop API; spec in DIFF
## cycle 16). Opened from the menu's 商店 button like the Lab.
func _build_shop_panel(root: Control) -> void:
	_shop_panel = PanelContainer.new()
	_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	_shop_panel.offset_left = -300
	_shop_panel.offset_right = 300
	_shop_panel.offset_top = -252
	_shop_panel.offset_bottom = 252
	_shop_panel.visible = false
	_shop_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_shop_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	_shop_panel.add_child(vb)
	# 对齐定稿 S10_v1.jpg：顶部立体三星金黄圆角标题牌 + 两侧绿叶簇 + 纯白星尘余额胶囊
	if _p5_on:
		var title_wrap := CenterContainer.new()
		vb.add_child(title_wrap)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		title_wrap.add_child(title_row)
		var leaf_l := UiTheme.art("leaf_sprig", Vector2(36, 36))
		leaf_l.flip_h = true
		title_row.add_child(leaf_l)
		var gold_banner := PanelContainer.new()
		var g_sb := _style(Color("ffd966"), 14, Color("c98b2c"), 2, true)
		g_sb.content_margin_left = 24
		g_sb.content_margin_right = 24
		g_sb.content_margin_top = 2
		g_sb.content_margin_bottom = 4
		gold_banner.add_theme_stylebox_override("panel", g_sb)
		title_row.add_child(gold_banner)
		var g_vb := VBoxContainer.new()
		g_vb.add_theme_constant_override("separation", 0)
		gold_banner.add_child(g_vb)
		var hstars := UiTheme.art("header_stars", Vector2(84, 26))
		hstars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		g_vb.add_child(hstars)
		var t := _mk_dlabel(g_vb, "萤尘商店", 24, UiTheme.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var leaf_r := UiTheme.art("leaf_sprig", Vector2(36, 36))
		title_row.add_child(leaf_r)
		var bal_wrap := CenterContainer.new()
		vb.add_child(bal_wrap)
		var bal_pill := PanelContainer.new()
		var b_sb := _style(Color(1.0, 0.995, 0.975, 0.95), 16, Color("e5cfa0"), 1.5, true)
		b_sb.content_margin_left = 18
		b_sb.content_margin_right = 18
		b_sb.content_margin_top = 4
		b_sb.content_margin_bottom = 4
		bal_pill.add_theme_stylebox_override("panel", b_sb)
		bal_wrap.add_child(bal_pill)
		var bal_hb := HBoxContainer.new()
		bal_hb.add_theme_constant_override("separation", 6)
		bal_pill.add_child(bal_hb)
		var sp_ic := UiIcon.new("spark", Color("9a42de"), 18)
		sp_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bal_hb.add_child(sp_ic)
		_shop_info = _mk_label(bal_hb, "", 16, UiTheme.TEXT)
		_shop_info.add_theme_font_override("font", UiTheme.display_font())
		_shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var t := _mk_dlabel(vb, "萤尘商店", 22, UiTheme.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_info = _mk_label(vb, "", 15, Color("6e502f"))
		_shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_countdown = _mk_label(vb, "", 13, Color("6e502f"))
	_shop_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := _mk_label(vb, "背包道具，供接下来的对局使用。今天每多买一份，下一份越贵；名额在 00:00 UTC 刷新。", 12, Color("7a5f40"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 对齐定稿 S10_v1.jpg，手机端省略长句说明以腾出高度完整呈现三行以上大卡片
	note.visible = not _p5_on
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	var ssc: ScrollContainer = null
	if _p5_on:
		ssc = ScrollContainer.new()
		ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(ssc)
		_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ssc.add_child(_shop_list)
	else:
		vb.add_child(_shop_list)
	var xbtn := UiTheme.make_button("关闭", "green" if _p5_on else "ghost", "big" if _p5_on else "small")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			xbtn.add_theme_color_override(st, Color.WHITE)
		xbtn.add_theme_color_override("font_outline_color", Color("326b08"))
		xbtn.add_theme_constant_override("outline_size", 4)
	xbtn.pressed.connect(func() -> void:
		audio.click()
		_shop_panel.visible = false)
	vb.add_child(xbtn)
	_p5_overlay(ssc, xbtn)

func _refresh_shop_countdown() -> void:
	if _shop_countdown == null:
		return
	var secs := GameProfile.shop_seconds_to_reset(GameProfile.shop_now())
	_shop_countdown.text = "今日名额刷新倒计时：%d 小时 %d 分（00:00 UTC）" % [secs / 3600, (secs % 3600) / 60]

func _refresh_shop() -> void:
	if _shop_list == null:
		return
	for c in _shop_list.get_children():
		c.queue_free()
	var now := GameProfile.shop_now()
	var counts := GameProfile.shop_bought_today(now)
	_shop_info.text = ("萤尘 %d（累计 %d）" if _p5_on else "✦ 萤尘 %d（累计 %d）") % [GameProfile.stardust(), int(GameProfile.data.get("totalStardust", 0))]
	_refresh_shop_countdown()
	for it in GameProfile.SHOP_ITEMS:
		var id := String(it["id"])
		var bought := int(counts.get(id, 0))
		var daily := int(it["daily"])
		var in_bag := GameProfile.bag_count(id)
		var price := GameProfile.shop_price(id, now)
		# 每行包装为定稿 S10_v1.jpg 奶油白立体圆角卡片，带行首圆形实体图标与竖直分隔线
		var card := PanelContainer.new()
		var c_sb := _style(Color(1.0, 0.985, 0.945, 0.96), 16, Color("e5cfa0"), 1.5, true)
		c_sb.content_margin_left = 12
		c_sb.content_margin_right = 12
		c_sb.content_margin_top = 5
		c_sb.content_margin_bottom = 5
		card.add_theme_stylebox_override("panel", c_sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var ic_ring := PanelContainer.new()
		ic_ring.custom_minimum_size = Vector2(46, 46)
		ic_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ring_sb := _style(Color("f7e8c6"), 23, Color("e2c68e"), 1.5, false)
		ring_sb.set_content_margin_all(5)
		ic_ring.add_theme_stylebox_override("panel", ring_sb)
		ic_ring.add_child(_item_icon_rect(id, 34.0))
		row.add_child(ic_ring)
		var info_vb := VBoxContainer.new()
		info_vb.add_theme_constant_override("separation", 2)
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var title_l := _mk_label(info_vb, String(it["name"]), 16, UiTheme.TEXT)
		title_l.add_theme_font_override("font", UiTheme.display_font())
		var desc_l := _mk_label(info_vb, String(it["desc"]), 13, Color("6e502f"))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info_vb)
		var sep := ColorRect.new()
		sep.color = Color("e6d4b0")
		sep.custom_minimum_size = Vector2(1.5, 38)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sep)
		var meta_txt := "背包 %d/%d · 今日 %d/%d" % [in_bag, GameProfile.SHOP_BAG_CAP, bought, daily]
		if bought < daily and bought + 1 < daily:
			meta_txt += "\n下一份 ✦ %d" % int(round(float(it["price"]) * (1.0 + GameProfile.SHOP_PRICE_STEP * float(bought + 1))))
		elif bought < daily:
			meta_txt += "\n今日最后一份"
		var meta_l := _mk_label(row, meta_txt, 13, Color("5e4427"))
		meta_l.custom_minimum_size = Vector2(138, 0)
		meta_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := UiTheme.make_button("", "green", "normal" if _p5_on else "small")
		b.custom_minimum_size = Vector2(160, 44 if _p5_on else 34)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var is_dis := false
		if bought >= daily:
			b.text = "今日售罄"
			is_dis = true
		elif in_bag >= GameProfile.SHOP_BAG_CAP:
			b.text = "背包已满"
			is_dis = true
		elif GameProfile.stardust() < price:
			b.text = "✦ %d（萤尘不足）" % price
			is_dis = true
		else:
			b.text = "购买 ✦ %d" % price
		b.disabled = is_dis
		if is_dis:
			# 禁用/不足态统一改清晰雾灰真胶囊＋洁白文字，告别模糊浅绿条
			var gray_sb := _style(Color(0.66, 0.67, 0.70, 0.94), 22, Color(0.52, 0.53, 0.56, 0.90), 1.5, true)
			gray_sb.content_margin_left = 14
			gray_sb.content_margin_right = 14
			for st in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(st, gray_sb)
			b.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.95))
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			for st in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(st, Color.WHITE)
			b.add_theme_color_override("font_outline_color", Color("326b08"))
			b.add_theme_constant_override("outline_size", 3)
		var captured_id: String = id
		b.pressed.connect(func() -> void:
			var err := GameProfile.shop_buy(captured_id)
			if err == "":
				audio.power()
				_refresh_meta()
			else:
				audio.deny()
			_refresh_shop())
		row.add_child(b)
		_shop_list.add_child(card)
	if _p5_on and _shop_panel != null and _shop_panel.scale.x > 0.01:
		_p5_fit(_shop_panel, float(_shop_panel.get_meta("p5_sm", _shop_panel.scale.x)))

# ------------------------------------------------- cycle 16: sound panel
## The bundle's sound tab (@1963535): four volume sliders
## 0-1 step .05 + the muteHidden toggle. (silentPlay is an
## iOS-only row in the bundle; not applicable here.)
## Cycle 18: the settings screen — the bundle's six sections
## (Sonido/Gráficos/Controles/Teclas/Interfaz/Cuenta, builder
## @1959742) replace the cycle-16 sound-only panel. The panel
## node keeps the _sound_panel name (menu + harness surface).
## Every control is LIVE: audio sliders drive the buses via
## _apply_audio_settings; shake/fps/cam/touch/hud controls
## write Profile settings whose consumers read them per-frame
## or apply immediately. The keys page is a read-only kbd
## list (this build has no rebinding system — named).
func _build_sound_panel(root: Control) -> void:
	_sound_panel = PanelContainer.new()
	_sound_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sound_panel.offset_left = -370
	_sound_panel.offset_right = 370
	_sound_panel.offset_top = -285
	_sound_panel.offset_bottom = 285
	_sound_panel.visible = false
	_sound_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_sound_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_sound_panel.add_child(hb)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	rail.custom_minimum_size = Vector2(118, 0)
	hb.add_child(rail)
	if _p5_on:
		var st_head := HBoxContainer.new()
		st_head.alignment = BoxContainer.ALIGNMENT_CENTER
		st_head.add_theme_constant_override("separation", 6)
		rail.add_child(st_head)
		var sll := UiTheme.art("laurel_gold", Vector2(18, 22))
		sll.flip_h = true
		st_head.add_child(sll)
		_mk_dlabel(st_head, "设置", 24, Color("318ce7"))
		st_head.add_child(UiTheme.art("laurel_gold", Vector2(18, 22)))
	else:
		_mk_dlabel(rail, "设置", 24, UiTheme.SKY)
	for tab in [["sound", "声音"], ["gfx", "图形"], ["controls", "控制"],
			["keys", "键位"], ["hud", "界面"], ["account", "账户"]]:
		var tb := UiTheme.make_button(String(tab[1]), "ghost", "normal")
		var tid: String = tab[0]
		tb.pressed.connect(func() -> void:
			audio.click()
			_settings_show_tab(tid))
		rail.add_child(tb)
		_settings_tabs[tid] = tb
	var closeb := UiTheme.make_button("关闭", "green", "normal")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			closeb.add_theme_color_override(st, Color.WHITE)
		closeb.add_theme_color_override("font_outline_color", Color("326b08"))
		closeb.add_theme_constant_override("outline_size", 4)
	closeb.pressed.connect(func() -> void:
		audio.click()
		_close_settings())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _p5_on:
		# UI-mobile P5 (plan §B3 G11 / M0): six tabs on the rail,
		# the page scrolls in the right column, 关闭 (primary)
		# bottom-right.
		var rcol := VBoxContainer.new()
		rcol.add_theme_constant_override("separation", 8)
		rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(rcol)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rcol.add_child(scroll)
		closeb.size_flags_horizontal = Control.SIZE_SHRINK_END
		closeb.custom_minimum_size.x = 180
		closeb.set_meta("p5_primary", true)
		rcol.add_child(closeb)
	else:
		rail.add_child(closeb)
		hb.add_child(scroll)
	_settings_page = VBoxContainer.new()
	_settings_page.add_theme_constant_override("separation", 9)
	_settings_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_settings_page)
	_settings_show_tab("sound")

func _open_settings() -> void:
	_settings_return = ""
	_sound_panel.visible = true
	_settings_show_tab(_settings_tab_now)
	_apply_ui_scale()

func _close_settings() -> void:
	_sound_panel.visible = false
	if _settings_return == "pause":
		_settings_return = ""
		_pause_panel.visible = true

func _settings_show_tab(tid: String) -> void:
	_settings_tab_now = tid
	for k in _settings_tabs.keys():
		var tb := _settings_tabs[k] as Button
		var sel: bool = String(k) == tid
		UiTheme.retint_button(tb, "blue" if sel else "ghost")
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			tb.add_theme_color_override(st, Color.WHITE if sel else UiTheme.TEXT)
		tb.add_theme_color_override("font_outline_color", Color("13548c"))
		tb.add_theme_constant_override("outline_size", 3 if sel else 0)
	for c in _settings_page.get_children():
		(c as Node).queue_free()
	match tid:
		"sound": _settings_page_sound()
		"gfx": _settings_page_gfx()
		"controls": _settings_page_controls()
		"keys": _settings_page_keys()
		"hud": _settings_page_hud()
		"account": _settings_page_account()
		"legal": _settings_page_legal()

## 生成设置与状态页共用的亮天蓝圆角胶囊栏目横幅（对齐定稿 S08/S09）
func _mk_sky_banner(parent: Control, text: String, fs: int = 20, center: bool = true) -> void:
	if not _p5_on:
		_mk_dlabel(parent, text, fs, UiTheme.SKY)
		return
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _style(Color("3aaef2"), 18 if center else 12, Color("2085c4"), 1.5, true)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4 if center else 3
	sb.content_margin_bottom = 4 if center else 3
	wrap.add_theme_stylebox_override("panel", sb)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wrap)
	# 用笔画厚实的 body_font + 柔蓝投影（禁用过粗外描边内吞细笔画），确保实心纯白清晰醒目
	var lbl := _mk_label(wrap, text, fs, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_color_override("font_shadow_color", Color("14548a"))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_color_override("font_outline_color", Color("176098"))
	lbl.add_theme_constant_override("outline_size", 1)

## One st-row: label (+hint) on the left, control on the right.
func _st_row(parent: Container, label: String, hint: String = "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var lab := _mk_label(hb, label + (" — " + hint if hint != "" else ""), 14)
	lab.custom_minimum_size = Vector2(210, 0)
	if _p5_on:
		# UI-mobile P5: the label column wraps (16:9 page widths)
		# so the slider keeps its >= 360 design length.
		lab.custom_minimum_size = Vector2(170, 0)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return hb

func _st_slider(parent: Container, label: String, key: String,
		mn: float, mx: float, step: float, fmt: String,
		apply: Callable = Callable(), disp: float = 1.0) -> HSlider:
	var hb := _st_row(parent, label)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = float(GameProfile.setting(key))
	slider.custom_minimum_size = Vector2(220, 0)
	if _p5_on:
		# The pause page's quick row is narrower than the settings
		# page (tab column beside it): the plain 220 floor there,
		# EXPAND_FILL stretches it to the page.
		var in_pause := _pause_panel != null and _pause_panel.is_ancestor_of(parent)
		slider.custom_minimum_size = Vector2(220.0 if in_pause else _p5_slider_len(), 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_slider(slider)
	slider.set_meta("setting_key", key)
	var val_l := _mk_label(hb, fmt % (slider.value * disp), 14 if _p5_on else 13, UiTheme.TEXT if _p5_on else UiTheme.MUTED)
	val_l.custom_minimum_size = Vector2(56, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		GameProfile.set_setting(key, v)
		val_l.text = fmt % (v * disp)
		if apply.is_valid():
			apply.call())
	hb.remove_child(val_l)
	hb.add_child(slider)
	hb.add_child(val_l)
	return slider

## UI-mobile P5 (plan §B3 G11): sliders >= 360 design px where
## the settings page is wide enough (20:9); on 16:9 the page
## width minus the label / value columns (D7 second line).
func _p5_slider_len() -> float:
	var w := _p5_w(_sound_panel, 900.0) - 32.0 - 118.0 - 12.0 - 14.0
	return clampf(w - 170.0 - 64.0 - 16.0, 220.0, 360.0)

func _st_switch(parent: Container, label: String, key: String,
		apply: Callable = Callable()) -> Button:
	var hb := _st_row(parent, label)
	var sw := UiTheme.make_switch(bool(GameProfile.setting(key)), 0.62 if _p5_on else 1.0)
	sw.pressed.connect(func() -> void:
		audio.click()
		var nv := not bool(GameProfile.setting(key))
		GameProfile.set_setting(key, nv)
		UiTheme.set_switch(sw, nv)
		if apply.is_valid():
			apply.call())
	hb.add_child(sw)
	return sw

func _settings_page_sound() -> void:
	_mk_sky_banner(_settings_page, "声音", 20)
	for row in [["主音量", "master"], ["音乐", "music"], ["音效", "sfx"], ["叫声", "cries"]]:
		_st_slider(_settings_page, String(row[0]), String(row[1]),
			0.0, 1.0, 0.05, "%.0f%%", func() -> void: _apply_audio_settings(), 100.0)
	_st_switch(_settings_page, "后台静音", "muteHidden",
		func() -> void: _apply_audio_settings())

func _settings_page_gfx() -> void:
	_mk_sky_banner(_settings_page, "图形", 20)
	_st_switch(_settings_page, "屏幕震动", "shakeOn")
	_st_slider(_settings_page, "震动强度", "screenShake", 0.0, 2.0, 0.1, "%.1f")
	var hb := _st_row(_settings_page, "帧率上限")
	var opts := ["关", "30", "60", "90", "120"]
	var vals := [0, 30, 60, 90, 120]
	var cur := vals.find(int(GameProfile.setting("fpsCap")))
	var seg := UiTheme.make_segmented(opts, maxi(cur, 0))
	for b in seg.get_children():
		var bb := b as Button
		bb.pressed.connect(func() -> void:
			audio.click()
			var i := int(bb.get_meta("seg_i"))
			GameProfile.set_setting("fpsCap", vals[i])
			Engine.max_fps = int(vals[i])
			UiTheme.set_segmented(seg, i))
	hb.add_child(seg)

func _settings_page_controls() -> void:
	_mk_sky_banner(_settings_page, "控制", 20)
	_st_switch(_settings_page, "大招自动释放", "autoUlt")
	_st_switch(_settings_page, "大招演出姿势", "ultPose")
	_st_switch(_settings_page, "镜头辅助（瞄准）", "camAssist",
		func() -> void:
			if touch_controls:
				touch_controls.set_aim_state(bool(GameProfile.setting("camAssist"))))
	_st_switch(_settings_page, "固定摇杆", "fixedStick",
		func() -> void:
			if touch_controls:
				touch_controls.fixed_stick = bool(GameProfile.setting("fixedStick")))
	_st_slider(_settings_page, "触控按钮大小", "touchScale", 0.7, 1.5, 0.05, "%.2f",
		func() -> void:
			if touch_controls:
				touch_controls.apply_scale(float(GameProfile.setting("touchScale"))))
	_st_slider(_settings_page, "镜头距离", "camDist", 4.5, 20.0, 0.5, "%.1f",
		func() -> void: cam_dist = float(GameProfile.setting("camDist")))
	_st_slider(_settings_page, "镜头灵敏度", "camSpeed", 0.5, 2.0, 0.1, "%.1f")
	_st_switch(_settings_page, "镜头 Y 轴反转", "invertY")

func _settings_page_keys() -> void:
	# UI-mobile P1.1 (plan §B3 G11): on touch this tab is
	# "操作" — the touch reference first, the fixed key
	# table below it under "外接键盘".
	if _touch_wanted():
		_mk_sky_banner(_settings_page, "操作", 20)
		for row in [["移动", "左半屏拖动（摇杆）"], ["互动 / 邀伴", "右下「！」互动键"],
				["跳跃 · 下砸（空中）", "↑ 键"], ["冲刺 · 滑铲", "风 键"],
				["大招", "「必」键"], ["锁定最近敌人", "暂停菜单「锁定目标」"],
				["暂停", "点左上头像" if _new_layout() else "右下竖列暂停键"]]:
			var thb := _st_row(_settings_page, String(row[0]))
			_mk_label(thb, String(row[1]), 14, UiTheme.MUTED)
		_mk_dlabel(_settings_page, "外接键盘", 16, UiTheme.SKY)
	else:
		_mk_dlabel(_settings_page, "键位", 20, UiTheme.SKY)
	_mk_label(_settings_page, "固定键位 · 本构建不支持改绑", 12, UiTheme.MUTED)
	for row in [["移动", "W A S D"], ["互动 / 邀伴", "E"], ["下砸（空中）", "空格"],
			["疾跑", "Shift"], ["大招", "R"], ["暂停", "Esc / P"], ["选卡", "1 – 9"]]:
		var hb := _st_row(_settings_page, String(row[0]))
		hb.add_child(UiTheme.kbd(String(row[1])))

func _settings_page_hud() -> void:
	_mk_sky_banner(_settings_page, "界面", 20)
	_st_slider(_settings_page, "界面缩放", "hudScale", 0.8, 1.3, 0.05, "%.2f",
		func() -> void: _apply_ui_scale())
	_st_slider(_settings_page, "界面不透明度", "hudOpacity", 0.4, 1.0, 0.05, "%.0f%%",
		func() -> void: _apply_visibility_settings(), 100.0)
	_st_slider(_settings_page, "Boss 条不透明度", "bossOpacity", 0.4, 1.0, 0.05, "%.0f%%",
		func() -> void: _apply_visibility_settings(), 100.0)
	_st_slider(_settings_page, "小地图大小", "minimapScale", 0.75, 1.5, 0.05, "%.2f",
		func() -> void: _apply_visibility_settings())
	# UI-mobile P3 (plan D6): the classic layout (21.3.2 HUD
	# geometry + pause / aim column) for 1-2 versions.
	var csw := _st_switch(_settings_page, "经典布局（旧版 HUD 排布）", "classicLayout",
		func() -> void: _apply_ui_scale())
	csw.name = "ClassicLayoutSwitch"

func _settings_page_account() -> void:
	_mk_sky_banner(_settings_page, "账户", 20)
	var wstat := _mk_label(_settings_page, "", 14)
	_refresh_account_label(wstat)
	var wb := UiTheme.make_button("钱包面板", "blue", "normal")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			wb.add_theme_color_override(st, Color.WHITE)
		wb.add_theme_color_override("font_outline_color", Color("13548c"))
		wb.add_theme_constant_override("outline_size", 3)
	wb.pressed.connect(func() -> void:
		audio.click()
		_sound_panel.visible = false
		_wallet_panel.visible = true)
	_settings_page.add_child(wb)
	_mk_label(_settings_page, "危险操作", 13, Color("c44734"))
	# Two-step armed confirm (the bundle's account danger
	# pattern: the button arms for 3 s, a second press fires).
	var resetb := UiTheme.make_button("重置存档", "red", "normal")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			resetb.add_theme_color_override(st, Color.WHITE)
		resetb.add_theme_color_override("font_outline_color", Color("7a1c15"))
		resetb.add_theme_constant_override("outline_size", 3)
	var armed := [false]
	resetb.pressed.connect(func() -> void:
		audio.click()
		if not armed[0]:
			armed[0] = true
			resetb.text = "再点一次确认重置（3 秒）"
			_later(3.0, func() -> void:
				armed[0] = false
				if is_instance_valid(resetb):
					resetb.text = "重置存档")
		else:
			GameProfile.reset_all()
			get_tree().reload_current_scene())
	_settings_page.add_child(resetb)
	var legal_button := UiTheme.make_button("隐私政策与服务条款", "ghost")
	legal_button.pressed.connect(func() -> void: _settings_show_tab("legal"))
	_settings_page.add_child(legal_button)

func _settings_page_legal(doc: String = "privacy", lang: String = "zh") -> void:
	for child in _settings_page.get_children():
		_settings_page.remove_child(child)
		child.queue_free()
	var english := lang == "en"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_settings_page.add_child(row)
	for entry in [["privacy", "Privacy" if english else "隐私政策"], ["terms", "Terms" if english else "服务条款"]]:
		var button := UiTheme.make_button(String(entry[1]), "green" if doc == entry[0] else "ghost", "small")
		var selected: String = entry[0]
		button.pressed.connect(func() -> void: _settings_page_legal(selected, lang))
		row.add_child(button)
	var language := UiTheme.make_button("中文" if english else "English", "ghost", "small")
	language.pressed.connect(func() -> void: _settings_page_legal(doc, "zh" if english else "en"))
	row.add_child(language)
	var body := _mk_label(_settings_page, "", 16, UiTheme.TEXT)
	body.text = load("res://assets/legal/%s_%s.tres" % [doc, lang]).text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.x = 300
	body.text = str(load("res://assets/legal/%s_%s.tres" % [doc, lang]).get("text"))
	var online := UiTheme.make_button("Online version" if english else "在线版", "ghost", "small")
	online.pressed.connect(func() -> void: OS.shell_open("https://spritebonk-site.musen-ai-9527.workers.dev/" + doc))
	_settings_page.add_child(online)

func _refresh_account_label(l: Label) -> void:
	if wallet and wallet.is_wallet_connected():
		l.text = "钱包：已连接 %s（访客游玩不受影响）" % wallet.short_address()
	else:
		l.text = "钱包：未连接（当前以访客身份游玩）"

# ------------------------------------------------- unlocks (§3, cycle 8)
func _build_unlock_panel(root: Control) -> void:
	_unlock_panel = PanelContainer.new()
	_unlock_panel.set_anchors_preset(Control.PRESET_CENTER)
	_unlock_panel.offset_left = -330
	_unlock_panel.offset_right = 330
	_unlock_panel.offset_top = -280
	_unlock_panel.offset_bottom = 280
	_unlock_panel.visible = false
	_unlock_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_unlock_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_unlock_panel.add_child(vb)
	# 对齐定稿 S11_v1.jpg：金色月桂枝＋亮蓝白粗体标题＋高亮信息胶囊
	if _p5_on:
		var head_wrap := CenterContainer.new()
		vb.add_child(head_wrap)
		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 8)
		head_wrap.add_child(head_row)
		var ll := UiTheme.art("laurel_gold", Vector2(26, 30))
		ll.flip_h = true
		head_row.add_child(ll)
		var t := _mk_label(head_row, "伙伴营挑战 · 终身挑战", 24, Color("298ad6"), true)
		t.add_theme_color_override("font_shadow_color", Color(0.08, 0.25, 0.45, 0.45))
		t.add_theme_constant_override("shadow_offset_y", 2)
		var lr := UiTheme.art("laurel_gold", Vector2(26, 30))
		head_row.add_child(lr)
		var info_pill := PanelContainer.new()
		var i_sb := _style(Color(1.0, 0.99, 0.95, 0.95), 14, Color("e5cfa0"), 1.5, false)
		i_sb.content_margin_left = 14
		i_sb.content_margin_right = 14
		i_sb.content_margin_top = 4
		i_sb.content_margin_bottom = 4
		info_pill.add_theme_stylebox_override("panel", i_sb)
		vb.add_child(info_pill)
		_unlock_info = _mk_label(info_pill, "", 13, UiTheme.TEXT)
		_unlock_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var t := _mk_dlabel(vb, "伙伴营挑战 · 终身挑战", 20, UiTheme.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_unlock_info = _mk_label(vb, "", 14, Color("5e4427"))
		_unlock_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	vb.add_child(scroll)
	_unlock_list = VBoxContainer.new()
	_unlock_list.add_theme_constant_override("separation", 8 if _p5_on else 4)
	_unlock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_unlock_list)
	var xbtn := UiTheme.make_button("关闭", "green" if _p5_on else "ghost", "big" if _p5_on else "small")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			xbtn.add_theme_color_override(st, Color.WHITE)
		xbtn.add_theme_color_override("font_outline_color", Color("326b08"))
		xbtn.add_theme_constant_override("outline_size", 4)
	xbtn.pressed.connect(func() -> void:
		_unlock_panel.visible = false
		if _unlock_from_pause:
			_unlock_from_pause = false
			if state == "pause":
				_pause_panel.visible = true)
	vb.add_child(xbtn)
	_unlock_close_btn = xbtn
	_p5_overlay(scroll, xbtn)
	if _p5_on:
		_unlock_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _refresh_unlock_panel() -> void:
	if _unlock_list == null:
		return
	for c in _unlock_list.get_children():
		c.queue_free()
	_unlock_info.text = "伙伴营 %d 只 · 累计击杀 %d · 完成对局 %d · 头领 %d · 守护者 %d · 结伴 %d" % [
		(GameProfile.data.get("league", []) as Array).size(),
		int(GameProfile.counter_value("kills")), int(GameProfile.counter_value("runs")),
		int(GameProfile.counter_value("alphas")), int(GameProfile.counter_value("bosses")),
		int(GameProfile.counter_value("captures"))]
	const RANK_CN := {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说"}
	for key in GameProfile.challenge_order():
		var cfg: Dictionary = GameProfile.challenges()[key]
		var sd: Dictionary = GameData.species(key)
		var in_league := GameProfile.in_league(int(sd.get("family", 0)))
		var done := GameProfile.challenge_done(key)
		var status := "已加入伙伴营 ★" if in_league else ("挑战完成 · 等待遭遇 ✓" if done else "进行中")
		var rank_s := String(RANK_CN.get(String(cfg["rank"]), String(cfg["rank"])))
		# 定稿 S11_v1.jpg 奶油/淡金圆角大卡片＋圆角物种头像框
		var card := PanelContainer.new()
		var c_bg := Color("ffefb8") if (done or in_league) else Color(1.0, 0.99, 0.96, 0.96)
		var c_sb := _style(c_bg, 16, Color("dfb86c") if (done or in_league) else Color("e5cfa0"), 1.5, true)
		c_sb.content_margin_left = 12
		c_sb.content_margin_right = 12
		c_sb.content_margin_top = 8
		c_sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", c_sb)
		var chb := HBoxContainer.new()
		chb.add_theme_constant_override("separation", 12)
		card.add_child(chb)
		var pic_box := PanelContainer.new()
		pic_box.custom_minimum_size = Vector2(56, 56)
		pic_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var p_sb := _style(Color("fff8ea"), 28, Color("d8bc86"), 1.5, false)
		p_sb.set_content_margin_all(4)
		pic_box.add_theme_stylebox_override("panel", p_sb)
		var pt := TextureRect.new()
		pt.texture = UiTheme.portrait(key)
		pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic_box.add_child(pt)
		chb.add_child(pic_box)
		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 3)
		cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chb.add_child(cvb)
		var head := _mk_label(cvb, "%s（%s）· %s" % [
			String(ModelRig.SPECIES[key]["label"]), rank_s, status],
			16, UiTheme.TEXT)
		head.add_theme_font_override("font", UiTheme.display_font())
		if _p5_on:
			head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for p in GameProfile.challenge_parts(key):
			var pd := p as Dictionary
			var txt := "· %s：%d / %d" % [String(pd["desc"]), int(float(pd["value"])), int(float(pd["goal"]))]
			if bool(pd.get("unsupported", false)):
				txt += "（系统未实装）"
			_mk_label(cvb, txt, 13, Color("6e502f"))
		_unlock_list.add_child(card)
	if _p5_on and _unlock_panel != null and _unlock_panel.scale.x > 0.01:
		_p5_fit(_unlock_panel, float(_unlock_panel.get_meta("p5_sm", _unlock_panel.scale.x)))

# ------------------------------------------------------------- draft (cycle 7)
## U3: a three-leaf cluster for the banner ends (REF: a fan of
## three leaves pressing each pill end; v2-leaves.svg is a
## single leaf). The leaves share one base point at the pill
## side and fan outward; `flip` mirrors for the right end.
func _draft_leaf_cluster(flip: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(48, 48)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.z_index = 2
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load("res://assets/menu/v2-leaves.svg") as Texture2D
	var specs: Array = [
		[Vector2(34, 23), Vector2(4, 2), -0.45],
		[Vector2(30, 20), Vector2(10, 16), 0.10],
		[Vector2(24, 16), Vector2(14, 28), 0.58],
	]
	for sp in specs:
		var leaf := TextureRect.new()
		leaf.texture = tex
		leaf.size = sp[0]
		leaf.position = sp[1]
		leaf.pivot_offset = (sp[0] as Vector2) * 0.5
		leaf.rotation = float(sp[2])
		leaf.flip_h = flip
		leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		leaf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(leaf)
	if flip:
		for ch in c.get_children():
			var l := ch as TextureRect
			l.position = Vector2(48.0 - l.position.x - l.size.x, l.position.y)
			l.rotation = -l.rotation
	return c

func _build_draft(root: Control) -> void:
	_draft_panel = PanelContainer.new()
	_draft_panel.set_anchors_preset(Control.PRESET_CENTER)
	_draft_panel.offset_left = -430
	_draft_panel.offset_right = 430
	_draft_panel.offset_top = -226  # cycle 19: +team row
	_draft_panel.offset_bottom = 226
	_draft_panel.visible = false
	# 对齐定稿 U3_final.jpg：手机端去除大奶油外框，让金星横幅与三张卡片直接悬浮在虚化场景上
	if _p5_on:
		var emp := StyleBoxEmpty.new()
		emp.content_margin_left = 10
		emp.content_margin_right = 10
		emp.content_margin_top = 8
		emp.content_margin_bottom = 8
		_draft_panel.add_theme_stylebox_override("panel", emp)
	else:
		_draft_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_draft_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6 if _p5_on else 4)
	_draft_panel.add_child(vb)
	var header := CenterContainer.new()
	vb.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 0)
	header.add_child(header_row)
	header_row.add_child(_draft_leaf_cluster(false))
	var header_pill := PanelContainer.new()
	var header_style := _style(Color("fff6df"), 20, Color("e6b663"), 2.5, true)
	header_style.content_margin_left = 70
	header_style.content_margin_right = 70
	header_style.content_margin_top = -12
	header_style.content_margin_bottom = 4
	header_pill.add_theme_stylebox_override("panel", header_style)
	header_row.add_child(header_pill)
	var header_content := VBoxContainer.new()
	header_content.add_theme_constant_override("separation", 2)
	header_pill.add_child(header_content)
	var star_row := CenterContainer.new()
	header_content.add_child(star_row)
	var header_star := TextureRect.new()
	header_star.texture = load("res://assets/ui/decorations/star_filled.png") as Texture2D
	header_star.custom_minimum_size = Vector2(36, 36)
	header_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_row.add_child(header_star)
	_draft_title = _mk_dlabel(header_content, "升级！", 30 if _p5_on else 28, UiTheme.TEXT)
	_draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(_draft_leaf_cluster(true))
	_draft_opts_box = HBoxContainer.new()
	_draft_opts_box.add_theme_constant_override("separation", 14 if _p5_on else 10)
	_draft_opts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_draft_opts_box)
	# buildMini (UI_SPEC §2.5): 定稿 U3_final.jpg 不展示底部多余小豆行，手机端保留节点但隐藏以贴近纯净悬浮感
	_draft_mini = HBoxContainer.new()
	_draft_mini.add_theme_constant_override("separation", 6)
	_draft_mini.alignment = BoxContainer.ALIGNMENT_CENTER
	if _p5_on:
		var msc := ScrollContainer.new()
		msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		msc.custom_minimum_size = Vector2(0, 0)
		msc.visible = false
		vb.add_child(msc)
		_draft_mini.alignment = BoxContainer.ALIGNMENT_BEGIN
		msc.add_child(_draft_mini)
	else:
		vb.add_child(_draft_mini)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	tools.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(tools)
	_draft_rb = UiTheme.make_icon_button("reroll", "重抽", "blue", "small")
	_draft_rb.pressed.connect(_draft_reroll)
	tools.add_child(_draft_rb)
	_draft_sb = UiTheme.make_icon_button("skip", "跳过（+15 金币）", "ghost", "small")
	_draft_sb.pressed.connect(_draft_skip)
	tools.add_child(_draft_sb)
	_draft_bb = UiTheme.make_icon_button("banish", "放逐模式", "red", "small")
	_draft_bb.pressed.connect(_draft_toggle_banish)
	tools.add_child(_draft_bb)
	# U3: tool order is reroll / skip / banish (the old
	# move_child(rb, -1) had pushed reroll last). The
	# reroll face is the blue solid + white text/icon of
	# the reference (see _draft_tint_reroll); banish keeps
	# its cream face with a red icon + dark-red label, as
	# in the reference; skip stays cream + dark as built.
	_draft_tint_reroll()
	var bb_row := _draft_bb.get_child(0) as HBoxContainer
	(bb_row.get_child(0) as UiIcon).color = UiTheme.RED
	(_draft_bb.get_meta("label") as Label).add_theme_color_override(
		"font_color", UiTheme.RED.darkened(0.2))
	# Cycle 19 (audit punch #13): kbd caps on the tools
	# (the bundle's ez caps, @1999261) + the "Ver mi
	# equipo" [Tab] button the bundle appends to both card
	# modals (Yk @1552417). Keys: R 重抽 / S 跳过 / B 放逐.
	_kbd_cap(_draft_rb, "R")
	_kbd_cap(_draft_sb, "S")
	_kbd_cap(_draft_bb, "B")
	var team_b := UiTheme.make_button("查看我的队伍 [Tab]", "ghost", "small")
	team_b.pressed.connect(func() -> void:
		audio.click()
		_open_team_view())
	if _p5_on:
		# Plan §B3 M1: one tools row — spacer first so
		# reroll / skip / banish pack bottom-right, 我的队伍
		# stays at the far right (extra row, kept).
		var tsp := Control.new()
		tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(tsp)
		tools.move_child(tsp, 0)
		tools.add_child(team_b)
	else:
		var team_row := HBoxContainer.new()
		team_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(team_row)
		team_row.add_child(team_b)
	_draft_team_btn = team_b  # UI-mobile P1.1: "[Tab]" off on touch

## Learnset level of a move for the player's evolution chain — the
## original takes the chain minimum (§2.3: 成长取最小学习级).
func _learn_level_of(move_key: String) -> int:
	var best := -1
	var cur := player.base_species
	while cur != "":
		for pair in GameData.learnset(cur):
			if String(pair[0]) == move_key:
				best = int(pair[1]) if best < 0 else mini(best, int(pair[1]))
		if cur == player.species_id:
			break
		var tgt: Dictionary = GameData.evo_target(cur)
		cur = String(tgt.get("key", "")) if not tgt.is_empty() else ""
	return best

func _draft_candidates() -> Array:
	var cands: Array = []
	var p := player
	var elig := func(lv: int) -> bool: return float(p.level) * 2.6 + 10.0 >= float(lv)
	var slots_free := p.moves.size() < p.move_slots()
	# Kit moves (weight x3, §2.3) — kit-level gate via the chain
	# learnset; kit-only moves (e.g. fire-blast) get an INFERRED gate.
	var kit_moves: Array = GameData.kit(p.base_species)
	for i in range(kit_moves.size()):
		var k := String(kit_moves[i])
		if p.has_move(k) or banished_keys.has("move:" + k) or not slots_free:
			continue
		var ll := _learn_level_of(k)
		if ll < 0:
			ll = 4 + 8 * i
		if elig.call(ll):
			cands.append({"kind": "move_new", "key": k, "w": 3.0})
	# One random eligible learnset move (§2.3).
	var ls_opts: Array = []
	for pair in GameData.learnset(p.species_id):
		var k2 := String(pair[0])
		if p.has_move(k2) or kit_moves.has(k2) or banished_keys.has("move:" + k2):
			continue
		if GameData.move_is_draftable(k2) and elig.call(int(pair[1])):
			ls_opts.append(k2)
	if not ls_opts.is_empty() and slots_free:
		cands.append({"kind": "move_new", "key": String(ls_opts[_rng.randi_range(0, ls_opts.size() - 1)]), "w": 2.0})
	# Move upgrades (§2.3: each unmaxed learned move x2).
	for m in p.moves:
		var mk := String(m["key"])
		if int(m["level"]) < p.move_cap() and not banished_keys.has("move:" + mk):
			cands.append({"kind": "move_up", "key": mk, "w": 2.0})
	# Vitamins (§2.3: owned x2; new ones need a free vitamin slot).
	var vit_slots := 3 + GameProfile.lab_level("slot-vit")
	for vk in GameData.VITAMINS.keys():
		var owned := int(p.vit_levels.get(vk, 0))
		if owned >= p.vit_cap() or banished_keys.has("vit:" + vk):
			continue
		if owned == 0 and p.vit_levels.size() >= vit_slots:
			continue
		cands.append({"kind": "vitamin", "key": vk, "w": 2.0 if owned > 0 else 1.0})
	return cands

func _draft_draw(cands: Array, n: int) -> Array:
	var pool := cands.duplicate()
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += float(c["w"])
		var r := _rng.randf() * total
		var pick := 0
		for i in range(pool.size()):
			r -= float(pool[i]["w"])
			if r <= 0.0:
				pick = i
				break
		var c: Dictionary = pool[pick]
		pool.remove_at(pick)
		c = c.duplicate()
		var rar := GameData.roll_rarity(player.level, player.luck, zone, _rng)
		c["rarity"] = rar
		c["pe"] = float(GameData.RARITY_PE[rar])
		out.append(c)
	# §2.3: the first option is a move-class one when any exists.
	if out.size() > 1 and not (String(out[0]["kind"]) in ["move_new", "move_up"]):
		for i in range(1, out.size()):
			if String(out[i]["kind"]) in ["move_new", "move_up"]:
				var tmp = out[0]
				out[0] = out[i]
				out[i] = tmp
				break
	return out

func _draft_option_count() -> int:
	return 4 if GameProfile.lab_level("choice4") > 0 else 3

func _step_level_up() -> void:
	var lv := player.level - player.pending_levels + 1
	player.pending_levels -= 1
	count_max_level()  # roster 'maxLevel' counter (Abra/Bellsprout gates)
	if player.planned_evo_level() == lv:
		player.evolve()
		_refresh_hud()
		return
	if lv in [24, 44] and player.planned_evo_level() == -1:
		player.apply_growth()
		show_banner("成长阶段！伤害与体魄提升（o +0.12）", 3.0)
		_refresh_hud()
		return
	_open_draft()

func _open_draft() -> void:
	_pre_draft_state = state
	state = "draft"
	running = false
	_draft_options = _draft_draw(_draft_candidates(), _draft_option_count())
	if _draft_options.is_empty():
		# §2.3 empty-pool fallback: heal 20% + 15 gold, no panel.
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.2)
		gold += 15.0
		state = _pre_draft_state
		running = true
		return
	_render_draft()
	audio.level_up()  # cycle 16: the level-up fanfare
	_draft_panel.visible = true
	# Cycle 18 (audit §4.7): the bundle's modal() swallows
	# input for 600 ms after opening (VR=600 @1997697) —
	# 150 ms when a modal chains straight off the last one.
	_draft_opened_msec = Time.get_ticks_msec()
	_draft_banish_target = -1

func _draft_guard_ms() -> int:
	return 150 if _draft_opened_msec - _draft_closed_msec < 1000 else 600

func _draft_swallowed() -> bool:
	return Time.get_ticks_msec() - _draft_opened_msec < _draft_guard_ms()

func _close_draft() -> void:
	_draft_panel.visible = false
	_draft_banish_mode = false
	_draft_banish_target = -1
	_draft_closed_msec = Time.get_ticks_msec()
	state = _pre_draft_state
	running = true

## Cycle 19: the shared --shine gradient (diagonal white
## band, transparent at both edges).
func _shine_texture() -> Texture2D:
	if _shine_tex:
		return _shine_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.40, 0.5, 0.60, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	gt.width = 128
	gt.height = 256
	_shine_tex = gt
	return gt

## U3: radial gold glow for the featured draft card —
## transparent in the middle, gold toward the rim (drawn
## under the gold rim, clipped to the card like the shine).
func _gold_glow_texture() -> Texture2D:
	if _gold_glow_tex:
		return _gold_glow_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(1, 0.85, 0.3, 0), Color(1, 0.85, 0.3, 0),
		Color(1, 0.82, 0.25, 0.35), Color(1, 0.8, 0.2, 0.6)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_gold_glow_tex = gt
	return gt

func _fmt_num(v: float) -> String:
	return str(int(v)) if absf(v - round(v)) < 0.01 else "%.1f" % v

## One draft card (UI_SPEC §2.5): colored top zone with the
## move/vitamin icon, rarity chip (color, not bracketed text),
## title + description, and the [n] key footer. The accent
## (--rc) is the move's type color for new moves, else the
## rarity color.
func _draft_card(opt: Dictionary, idx: int) -> Button:
	var kind := String(opt["kind"])
	var key := String(opt["key"])
	var pe := float(opt["pe"])
	var rar := int(opt["rarity"])
	var rar_c := UiTheme.rarity_color(rar)
	var title := ""
	var desc := ""
	var icon := "candy"
	var cls_badge := ""
	var top_c := rar_c
	match kind:
		"move_new":
			var md: Dictionary = GameData.move(key)
			title = "新招式 · " + _move_zh(key)
			var pw := "变化" if md.get("power") == null else "威力 %d" % int(md["power"])
			# Cycle 18 (audit §7): the card face localizes like
			# the rest of the UI — type and class were leaking
			# raw EN ("dragon · special · 威力 60").
			var cls_raw := String(md.get("cls", ""))
			cls_badge = {"physical": "class_physical", "special": "class_special"}.get(cls_raw, "")
			var cls_zh := "物理" if cls_raw == "physical" else ("特殊" if cls_raw == "special" else "变化")
			var type_zh := String(md.get("type", ""))
			if TYPE_HUD.has(type_zh):
				type_zh = String((TYPE_HUD[type_zh] as Array)[0])
			desc = "%s · %s · %s" % [type_zh, cls_zh, pw]
			icon = _move_icon(String(md.get("type", "")))
			top_c = UiTheme.type_color(String(md.get("type", "")))
		"move_up":
			var md2: Dictionary = GameData.move(key)
			title = "招式强化 · " + _move_zh(key)
			desc = "%d级 → %d级\n伤害 +%s%%" % [player.move_level(key), player.move_level(key) + 1, _fmt_num(10.0 * pe)]
			icon = _move_icon(String(md2.get("type", "")))
		"vitamin":
			var vc: Dictionary = GameData.VITAMINS[key]
			icon = {"protein":"vit_protein", "calcium":"vit_calcium", "iron":"vit_iron", "carbos":"vit_carbos", "hp-up":"vit_hp_up", "ether":"vit_ether", "dire-hit":"vit_dire_hit", "exp-candy":"vit_exp_candy", "nugget":"vit_nugget", "super-potion":"vit_super_potion", "star-piece":"vit_star_piece"}.get(key, "flask")
			# 卡片展示剔除末尾冗余英文词汇，保留纯净中文或标准中文缩写
			var raw_vname := String(vc["label"])
			title = "HP 增强剂" if raw_vname.begins_with("HP") else raw_vname.get_slice(" ", 0)
			desc = String(vc["fmt"]) % _fmt_num(float(vc["per"]) * pe)
	var accent := top_c if kind == "move_new" else rar_c
	var csz := Vector2(_p5_card_w(_draft_panel, _draft_options.size(), 218.0), 296.0) \
		if _p5_on else Vector2(222, 302)
	var card := UiTheme.make_card(accent, csz, rar)
	card.clip_contents = true  # cycle 19: the shine stays in the card
	_draft_card_btns.append(card)
	_draft_card_accents.append(accent)
	_draft_card_rars.append(rar)
	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 13
	top.offset_right = -13
	top.offset_top = 14
	top.offset_bottom = 150
	var tc := top_c
	tc.a = 0.85
	var top_sb := UiTheme.flat_box(tc.lightened(0.62), 14)
	top_sb.corner_radius_top_left = 18
	top_sb.corner_radius_top_right = 18
	top.add_theme_stylebox_override("panel", top_sb)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top)
	var ic := UiBadge.new(icon, top_c, 96)
	ic.position = Vector2((csz.x - 96.0) * 0.5, 30)
	card.add_child(ic)
	# Icon order 2: the move-class mark (class_physical /
	# class_special art) rides the top zone's lower right,
	# clear of the centred main icon and the rarity chip.
	if cls_badge != "":
		var cb := UiBadge.new(cls_badge, top_c, 36)
		cb.position = Vector2(csz.x - 46.0, 104.0)
		card.add_child(cb)
	# Cycle 19 (audit §4.3): the bundle's top zone also
	# carries a KIND chip — NUEVO for a new move/vitamin,
	# MEJORA for an upgrade — and on new moves the rar chip
	# itself reads "Movimiento", the rarity riding the rim
	# and the shine. Ours: 新 / 强化 and 招式.
	var is_new := kind == "move_new" \
		or (kind == "vitamin" and int(player.vit_levels.get(key, 0)) <= 0)
	# U3: card-top pills are solid + white text in the
	# reference (REF ~62x29 design px); the old ink chips
	# read as pale cream + colored text because INK_DEEP
	# is a light tan (#dac6a2), not ink — the constant is
	# shared palette-wide, so the fix is local to these
	# chips. White is forced on the labels (the readable_fg
	# inside chip() would flip it back on the orange pill);
	# the gold legendary pill keeps dark text.
	var kchip := UiTheme.chip("新" if is_new else "强化",
		UiTheme.ORANGE, 14)
	kchip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	kchip.offset_left = 8
	kchip.offset_right = 70
	kchip.offset_top = 8
	kchip.offset_bottom = 38
	card.add_child(kchip)
	var klabel := kchip.get_child(0) as Label
	klabel.add_theme_color_override("font_color", UiTheme.WHITE)
	klabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rchip: PanelContainer
	if kind == "move_new":
		rchip = UiTheme.chip("招式", rar_c, 14)
	else:
		# Cycle 19 (audit punch #11) chose ink chips here
		# because the top zone IS the rarity color — but the
		# zone is that color lightened 0.62 (pale), so a
		# saturated solid pill still reads, as in the REF.
		rchip = UiTheme.chip(String(GameData.RARITY_NAMES[rar]),
			rar_c, 14)
	rchip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rchip.offset_left = -70
	rchip.offset_right = -8
	rchip.offset_top = 8
	rchip.offset_bottom = 38
	card.add_child(rchip)
	var rlabel := rchip.get_child(0) as Label
	if UiTheme.luminance(rar_c) < 0.75:
		rlabel.add_theme_color_override("font_color", UiTheme.WHITE)
	rlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Cycle 19 (audit punch #12): title / description /
	# footer FLOW in a column under the top zone — the
	# fixed boxes left ~60 px of void on one-line cards;
	# the footer now pins to the card foot via a spacer.
	var flow := VBoxContainer.new()
	flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	flow.offset_left = 10
	flow.offset_right = -10
	flow.offset_top = 158
	flow.offset_bottom = -8
	flow.add_theme_constant_override("separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(flow)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", UiTheme.display_font())
	tl.add_theme_font_size_override("font_size", 20)
	tl.add_theme_color_override("font_color", UiTheme.TEXT)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_pill := PanelContainer.new()
	var title_style := UiTheme.flat_box(Color("fff6df"), 18)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		title_style.set_content_margin(side, 2.0)
	title_pill.add_theme_stylebox_override("panel", title_style)
	title_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(title_pill)
	title_pill.add_child(tl)
	var divider := HBoxContainer.new()
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	divider.add_theme_constant_override("separation", 5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(divider)
	var rule_left := ColorRect.new()
	rule_left.color = Color("e8cda1")
	rule_left.custom_minimum_size = Vector2(46, 2)
	rule_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.add_child(rule_left)
	divider.add_child(UiBadge.new("leaf", Color("82b542"), 18))
	var rule_right := ColorRect.new()
	rule_right.color = rule_left.color
	rule_right.custom_minimum_size = rule_left.custom_minimum_size
	rule_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.add_child(rule_right)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_override("font", UiTheme.body_font())
	dl.add_theme_font_size_override("font_size", 15)
	dl.add_theme_color_override("font_color", UiTheme.MUTED)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(dl)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(spacer)
	var krow := HBoxContainer.new()
	krow.alignment = BoxContainer.ALIGNMENT_CENTER
	krow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(krow)
	krow.add_child(UiTheme.kbd("[%d]" % (idx + 1)))
	# UI-mobile P5 (plan §B3 M1): no key caps on touch.
	krow.visible = not _touch_wanted()
	# Cycle 19 (audit §4.3): --shine when rarity >= 2 — a
	# soft diagonal sweep across the card face, animated
	# in _process while the draft is open.
	if rar >= 2:
		var sh := TextureRect.new()
		sh.texture = _shine_texture()
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		sh.size = Vector2(120, csz.y)
		sh.position = Vector2(-140, 0)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.modulate.a = 0.55
		card.add_child(sh)
		_draft_shines.append({"rect": sh, "phase": float(idx) * 0.9})
	# U3: the featured (middle) card carries a gold rim +
	# glow overlay on top of its rarity frame — the rarity
	# rim logic is untouched; this only overlays the
	# promoted state. Toggled by _paint_draft_cards
	# (hidden while banishing).
	if idx == _draft_options.size() / 2:
		# 主推中卡采用纯正金色相框边框 + 内暖金辉光，彻底告别异色双边重叠
		if rar >= 0:
			card.add_theme_stylebox_override("normal", UiTheme.card_frame_box(4))
			card.add_theme_stylebox_override("hover", UiTheme.card_frame_box(4, true))
		var fx := Control.new()
		fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow := TextureRect.new()
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.texture = _gold_glow_texture()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.modulate = Color(1, 0.88, 0.45, 0.55)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.add_child(glow)
		var rim := Panel.new()
		rim.set_anchors_preset(Control.PRESET_FULL_RECT)
		rim.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(0, 0, 0, 0), 26, Color(1.0, 0.84, 0.25, 0.85), 3))
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.add_child(rim)
		# Gold sparkles at the free corners/edges (the top
		# corners carry the kind/rarity chips). U3 fix2:
		# anchor/offset geometry only — the free position/
		# size form rendered as one giant centred star in
		# the fix1 captures (bisect-proven 2026-11-14:
		# emptying that loop removed the star).
		var sparkle_defs: Array = [
			[Vector2(0, 1), Rect2(8, -28, 20, 20)],
			[Vector2(1, 1), Rect2(-28, -28, 20, 20)],
			[Vector2(0, 0.5), Rect2(4, -10, 20, 20)],
			[Vector2(1, 0.5), Rect2(-24, -10, 20, 20)],
		]
		for entry in sparkle_defs:
			var anch: Vector2 = entry[0]
			var ro: Rect2 = entry[1]
			var st := TextureRect.new()
			st.texture = load("res://assets/ui/decorations/star_filled.png") as Texture2D
			st.anchor_left = anch.x
			st.anchor_right = anch.x
			st.anchor_top = anch.y
			st.anchor_bottom = anch.y
			st.offset_left = ro.position.x
			st.offset_top = ro.position.y
			st.offset_right = ro.position.x + ro.size.x
			st.offset_bottom = ro.position.y + ro.size.y
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			st.modulate = UiTheme.GOLD
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fx.add_child(st)
		card.add_child(fx)
		_draft_featured_fx = fx
	card.pressed.connect(func() -> void:
		if _draft_banish_mode:
			_banish_press(idx)
		else:
			_apply_draft_option(idx))
	return card

func _render_draft() -> void:
	_draft_title.text = "%d级 · 升级！" % player.level
	for c in _draft_opts_box.get_children():
		c.queue_free()
	_draft_card_btns.clear()
	_draft_card_accents.clear()
	_draft_card_rars.clear()
	_draft_shines.clear()
	_draft_featured_fx = null
	for i in range(_draft_options.size()):
		_draft_opts_box.add_child(_draft_card(_draft_options[i], i))
	# buildMini: current moves (type color) + vitamins.
	for c in _draft_mini.get_children():
		c.queue_free()
	for m in player.moves:
		var mk := String(m["key"])
		var star := " ★" if bool(m.get("fused", false)) or bool(m.get("fusion", false)) else ""
		_draft_mini.add_child(UiTheme.chip(
			"%s %d级%s" % [_move_zh(mk), int(m["level"]), star],
			UiTheme.type_color(String(GameData.move(mk).get("type", ""))), 11))
	for vk in player.vit_levels.keys():
		_draft_mini.add_child(UiTheme.chip(
			"%s %d级" % [String(GameData.VITAMINS[vk]["label"]), int(player.vit_levels[vk])],
			Color8(106, 90, 168), 11))
	_paint_draft_cards()
	_refresh_draft_tools()

## Tools row state (UI_SPEC §2.5): counts on the buttons,
## disabled at zero; banish is a MODE toggle (red while on).
func _refresh_draft_tools() -> void:
	if _draft_rb == null:
		return
	UiTheme.set_icon_button_text(_draft_rb, "重抽（%d）" % rerolls_left)
	_draft_rb.disabled = rerolls_left <= 0
	UiTheme.set_icon_button_text(_draft_sb, "跳过（%d）" % skips_left)
	_draft_sb.disabled = skips_left <= 0
	if _draft_banish_mode and _draft_banish_target >= 0 \
			and _draft_banish_target < _draft_options.size():
		# The bundle's armed-confirm label (@2048091).
		UiTheme.set_icon_button_text(_draft_bb, "再点一次放逐 %s" %
			_draft_option_title(_draft_options[_draft_banish_target]))
	else:
		UiTheme.set_icon_button_text(_draft_bb,
			"放逐模式：开（%d）" % banishes_left if _draft_banish_mode else "放逐模式（%d）" % banishes_left)
	_draft_bb.disabled = banishes_left <= 0 and not _draft_banish_mode
	_draft_tint_reroll()

## U3: the reroll button is the blue solid primary of the
## reference (white text + white refresh icon).
## make_icon_button leaves the icon/label dark and _btn_box
## has no blue texture, so both are fixed here. Idempotent
## — re-applied by _refresh_draft_tools after state changes.
func _draft_tint_reroll() -> void:
	if _draft_rb == null:
		return
	var blue: Color = UiTheme.BTN_KINDS["blue"]
	var border := Color(0, 0, 0, 0.18)
	_draft_rb.add_theme_stylebox_override("normal",
		UiTheme.tinted_btn_box(blue, 10, border, 2, 12))
	_draft_rb.add_theme_stylebox_override("hover",
		UiTheme.tinted_btn_box(blue.lightened(0.13), 10, border, 2, 12))
	_draft_rb.add_theme_stylebox_override("pressed",
		UiTheme.tinted_btn_box(blue.darkened(0.15), 10, border, 2, 12))
	var dis := blue
	dis.a *= 0.45
	_draft_rb.add_theme_stylebox_override("disabled",
		UiTheme.tinted_btn_box(dis, 10, border, 2, 12))
	var row := _draft_rb.get_child(0) as HBoxContainer
	(row.get_child(0) as UiIcon).color = UiTheme.WHITE
	var rlab := _draft_rb.get_meta("label") as Label
	rlab.add_theme_color_override("font_color", UiTheme.WHITE)
	rlab.add_theme_color_override("font_outline_color", Color("13548c"))
	rlab.add_theme_constant_override("outline_size", 3)

func _draft_option_title(opt: Dictionary) -> String:
	match String(opt["kind"]):
		"vitamin":
			var vc: Dictionary = GameData.VITAMINS.get(String(opt["key"]), {})
			return String(vc.get("label", String(opt["key"])))
		_:
			return _move_zh(String(opt["key"]))

## Cycle 18 (audit §4.1): the bundle's banish is two-step —
## armed, the first tap on a card only TARGETS it; a second
## tap on the same card (or on the banish button, or the
## same digit key) commits. Ours banished on the first tap,
## which on a touch screen is exactly the misclick the
## original guards against.
func _banish_press(idx: int) -> void:
	if _draft_swallowed():
		return
	if banishes_left <= 0 or idx < 0 or idx >= _draft_options.size():
		return
	if _draft_banish_target == idx:
		_banish_option(idx)
		return
	_draft_banish_target = idx
	audio.click()
	_paint_draft_cards()
	_refresh_draft_tools()

## Banish-mode card treatment (UI_SPEC §1.3): the original
## outlines target cards 4px #ff4a4a and hue-shifts the deck;
## ours re-rims the cards red at 2px and warms their modulate
## (2px vs 4px + filter difference named in DIFF cycle 17).
func _paint_draft_cards() -> void:
	for i in range(_draft_card_btns.size()):
		var card := _draft_card_btns[i] as Button
		if card == null:
			continue
		if _draft_banish_mode:
			card.add_theme_stylebox_override("normal", UiTheme.card_box(UiTheme.RED))
			card.add_theme_stylebox_override("hover", UiTheme.card_box(UiTheme.RED, true))
			# The targeted card burns hotter (the bundle's
			# 4px #ff4a4a outline marks it; our rim is 2px —
			# the targeted state adds the brighter wash).
			card.modulate = Color(1.35, 0.68, 0.68) if i == _draft_banish_target \
				else Color(1.12, 0.82, 0.86)
		else:
			var acc: Color = _draft_card_accents[i]
			# Icon order 2 acceptance fix: framed cards (rar >= 0)
			# keep their rarity frame here — repainting them with
			# card_box wiped the frame make_card had set.
			var rar2: int = int(_draft_card_rars[i]) if i < _draft_card_rars.size() else -1
			if rar2 >= 0:
				card.add_theme_stylebox_override("normal", UiTheme.card_frame_box(rar2))
				card.add_theme_stylebox_override("hover", UiTheme.card_frame_box(rar2, true))
			else:
				card.add_theme_stylebox_override("normal", UiTheme.card_box(acc))
				card.add_theme_stylebox_override("hover", UiTheme.card_box(acc, true))
			card.modulate = Color.WHITE

	# U3: the gold rim+glow of the featured card is an overlay
	# on the promoted state — hidden while banishing (the red
	# banish state takes over the card faces).
	if _draft_featured_fx != null:
		_draft_featured_fx.visible = not _draft_banish_mode

func _draft_toggle_banish() -> void:
	if _draft_swallowed():
		return
	# Armed with a target, the banish button itself commits
	# (the bundle's second commit path, @2048091).
	if _draft_banish_mode and _draft_banish_target >= 0:
		_banish_option(_draft_banish_target)
		return
	if not _draft_banish_mode and banishes_left <= 0:
		audio.deny()
		return
	_draft_banish_mode = not _draft_banish_mode
	if not _draft_banish_mode:
		_draft_banish_target = -1
	audio.click()
	_paint_draft_cards()
	_refresh_draft_tools()

func _apply_draft_option(idx: int) -> void:
	if _draft_swallowed():
		return
	if idx < 0 or idx >= _draft_options.size():
		return
	audio.power()  # cycle 16: draft pick
	var opt: Dictionary = _draft_options[idx]
	var key := String(opt["key"])
	var pe := float(opt["pe"])
	match String(opt["kind"]):
		"move_new":
			player.learn_move(key)
			show_banner("学会了 %s！" % _move_zh(key), 2.5)
		"move_up":
			player.upgrade_move(key, pe)
		"vitamin":
			_grant_vitamin(key, pe)
	_close_draft()
	_refresh_hud()

func _draft_reroll() -> void:
	if _draft_swallowed():
		return
	if rerolls_left <= 0 or state != "draft":
		if state == "draft":
			audio.deny()  # cycle 16
		return
	audio.click()
	rerolls_left -= 1
	_draft_options = _draft_draw(_draft_candidates(), _draft_option_count())
	if _draft_options.is_empty():
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.2)
		gold += 15.0
		_close_draft()
		return
	_render_draft()

func _draft_skip() -> void:
	if _draft_swallowed():
		return
	if skips_left <= 0 or state != "draft":
		return
	skips_left -= 1
	gold += 15.0  # §2.3: skipping pays gold (fallback line's 15 ₽)
	audio.coin()  # cycle 16
	_close_draft()

func _banish_option(idx: int) -> void:
	if banishes_left <= 0 or idx < 0 or idx >= _draft_options.size():
		return
	banishes_left -= 1
	_draft_banish_mode = false  # one banish per mode entry
	_draft_banish_target = -1
	var opt: Dictionary = _draft_options[idx]
	var prefix := "vit:" if String(opt["kind"]) == "vitamin" else "move:"
	banished_keys.append(prefix + String(opt["key"]))
	_draft_options.remove_at(idx)
	if _draft_options.is_empty():
		_close_draft()
		return
	_render_draft()

func _build_result(root: Control) -> void:
	# U5 fix6: on phone the modal is a wrapper stack -- the cream
	# panel plus the actions row below it, on the scene (v2
	# reference: the buttons sit outside/below the card, not in
	# it). The wrapper is the registered P5 modal (placed/scaled
	# as one unit); desktop keeps the bare panel (legacy 700x580).
	if _p5_on:
		_result_wrap = VBoxContainer.new()
		# U5 re-audit #1/#4: retain ~37 logical px of visible panel/button gap.
		_result_wrap.add_theme_constant_override("separation", 21)
		_result_wrap.set_anchors_preset(Control.PRESET_CENTER)
		_result_wrap.offset_left = -433.5
		_result_wrap.offset_right = 433.5
		_result_wrap.offset_top = -375
		_result_wrap.offset_bottom = 375
		_result_wrap.visible = false
		root.add_child(_result_wrap)
		# U5 fix7: crest headroom spacer -- the crest (stars +
		# ribbon) straddles the panel top edge, so the panel must
		# sit lower in the wrapper: panel top lands ~172 screen px
		# (reference ~174), stars top ~23 screen px.
		# U5 fix8: the row-pitch residual is fixed in _fill_result
		# (pitch 82 -> ~63) with the panel held at ~500 px by the
		# bottom spacer; buttons bottom ~1014 (reference ~1018).
		var _crest_spacer := Control.new()
		# U5 re-audit #1/#4: offset the +1 wrapper gap to hold panel top.
		_crest_spacer.custom_minimum_size = Vector2(0, 96)
		_crest_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_result_wrap.add_child(_crest_spacer)
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -350
	_result_panel.offset_right = 350
	_result_panel.offset_top = -290
	_result_panel.offset_bottom = 290
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	if _p5_on:
		_result_wrap.add_child(_result_panel)
	else:
		root.add_child(_result_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var rcol := vb
	# U5 (2026-11-14): phone uses the same single column as desktop
	# (stars -> ribbon -> summary -> rows -> payout -> buttons), per
	# the v2 reference. The old two-column P5 form put the summary
	# in a 250 px column (wrapped to four lines) and the rows in a
	# scroll (gold row + payout below the fold).
	_result_panel.add_child(vb)
	# U5 fix7: on phone the crest (stars + ribbon) is an overlay
	# straddling the panel top edge (reference: stars press the
	# ribbon top, ribbon centre sits on the panel top edge), NOT
	# flow content -- flow stars+ribbon made the panel ~166 px
	# too tall and left no headroom above it. The crest is a plain
	# Control (min height 40 = ribbon tail bottom to summary top)
	# whose children are manually placed and spill above the panel
	# edge; plain Controls do not clip, so the spill draws. The
	# panel live min drops 623 -> ~500 design px. Desktop keeps
	# the old flow layout verbatim (legacy 700x580 panel).
	var ribbon: PanelContainer
	if _p5_on:
		var crest := Control.new()
		# U5 fix9: 40 -> 56 -- the fix8 225 ribbon folded tails
		# reach ~285 screen px at the sides and clipped the
		# summary glyph tops (~275); +16 design px (~23 screen px)
		# of crest headroom clears them. The ribbon is
		# crest-local, so it does not move; the bottom gap
		# shrinks by the same 16 to hold the panel at ~500.
		crest.custom_minimum_size = Vector2(0, 56)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(crest)
		var stars := HBoxContainer.new()
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# P5 crest uses a dedicated faceted material and independent x/y fit.
		# Keep the 100px centre pitch; lower the tips into the thin green band.
		stars.position = Vector2(0, -118)
		stars.add_theme_constant_override("separation", -2)
		stars.size = Vector2(872, 88)
		crest.add_child(stars)
		var star_sz := Vector2(102, 88)
		for idx_s in range(3):
			var key: String = ["star_filled", "star_filled", "star_empty"][idx_s]
			var st := UiTheme.art("p5_" + key, star_sz)
			st.stretch_mode = TextureRect.STRETCH_SCALE
			if idx_s == 1:
				# 中星微抬约 0.7%H（6 设计 px）以复现定稿拱形排布，外层占位保持 HBox 间距
				var slot := Control.new()
				slot.custom_minimum_size = star_sz
				slot.size = star_sz
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				st.position = Vector2(0, -6)
				slot.add_child(st)
				stars.add_child(slot)
			else:
				stars.add_child(st)
			_result_stars.append(st)
		ribbon = PanelContainer.new()
		ribbon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# U5 fix8: ribbon rect 225 tall centred on the panel top
		# edge (crest-local -14): the fix7 150 rect rendered a
		# ~80 screen px band (measured on the raw capture) vs
		# ~120 in the reference -- the title crowded the band
		# edges. 225 renders ~120 screen px (empirical 0.53
		# screen px per rect px); centre unchanged, so the star
		# overlap grows to ~30 screen px, inside the reference
		# range (~16-32).
		# U5 第 9 轮单项修复：保持 ribbon.size 固定为 872x225 与第 8 轮一致确保 _result_title 不折行不丢字，
		# 仅在 crest 就绪后平移 ribbon.position.x 与绘制宽度 690.0 对齐面板中心（48.65±0.2%W），
		# 其余带高 9.91%H、尾形、颜色、三星及全部保持项全冻结。
		ribbon.position = Vector2(0, -126)
		ribbon.size = Vector2(872, 225)
		crest.resized.connect(func() -> void:
			if crest.size.x > 100.0:
				ribbon.position.x = (crest.size.x - ribbon.size.x) * 0.5)
		ribbon.draw.connect(func() -> void:
			var rw := 690.0
			var extent := Vector2(rw, 225)
			ribbon.draw_texture_rect(UiTheme.asset("decorations", "p5_ribbon_green"), Rect2(Vector2((ribbon.size.x - extent.x) * 0.5, 0), extent), false))
		crest.add_child(ribbon)
		crest.move_child(stars, -1)
	else:
		var stars := HBoxContainer.new()
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(stars)
		var star_sz := Vector2(44, 44)
		for key in ["star_filled", "star_filled", "star_empty"]:
			var st := UiTheme.art(key, star_sz)
			stars.add_child(st)
			_result_stars.append(st)
		ribbon = PanelContainer.new()
		ribbon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		ribbon.custom_minimum_size.y = 54
		ribbon.draw.connect(func() -> void:
			var rw := minf(ribbon.size.x, 300.0)
			var extent := Vector2(rw, 72)
			ribbon.draw_texture_rect(UiTheme.asset("decorations", "ribbon_green"), Rect2(Vector2((ribbon.size.x - extent.x) / 2, -8), extent), false))
		vb.add_child(ribbon)
	# U5 re-audit #3: 53/40 = 1.325; includes the title’s flanking glyphs.
	_result_title = _mk_dlabel(ribbon, "", 53 if _p5_on else 34, UiTheme.WHITE)
	_result_title.add_theme_color_override("font_color", UiTheme.WHITE)
	if _p5_on:
		# 为丝带白色大标题补充深绿描边与立体制字投影
		_result_title.add_theme_color_override("font_outline_color", Color("3a740b"))
		_result_title.add_theme_constant_override("outline_size", 6)
		_result_title.add_theme_color_override("font_shadow_color", Color(0.16, 0.34, 0.04, 0.72))
		_result_title.add_theme_constant_override("shadow_offset_x", 0)
		_result_title.add_theme_constant_override("shadow_offset_y", 3)
	_result_panel.draw.connect(func() -> void:
		_result_panel.draw_texture_rect(UiTheme.asset("decorations", "confetti_strip"), Rect2(12, 4, _result_panel.size.x - 24, 64), false))

	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _p5_on:
		# U5 fix7: the P5 ribbon rect is 150 tall (crest overlay);
		# centre the title on the band instead of top-aligning it.
		_result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# U5 re-audit 2: the outer 8 px crest/summary gap is excess
		# flow headroom. Group summary/core/bottom with their existing
		# 8 px gaps, removing only the gap above the summary. The plain
		# crest Control isolates ribbon/title minima from this flow.
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(content)
		vb = content
	# Cycle 18: the sectioned summary (UI_SPEC §2.7) replaces
	# the single body label — payout chips, a 4-up fact grid,
	# per-move damage bars, pact chips, the capture grid,
	# completed-task rows and the dex lines, each section
	# present only when its system fed it (see _fill_result).
	# _result_body stays as the one-line summary under the
	# title (and as the harness/uishot compat surface).
	_result_body = _mk_label(vb, "", 14, UiTheme.MUTED)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _p5_on:
		# U5 fix9: summary in TEXT, not MUTED -- the reference
		# summary is dark brown (median 86,54,18); MUTED
		# (119,101,79) reads washed-out against the cream.
		_result_body.add_theme_color_override("font_color", UiTheme.TEXT)
		var summary_bold := FontVariation.new()
		summary_bold.base_font = load("res://assets/fonts/NotoSC-Black-sub.ttf")
		# Match the body stack's descent so rows and summary baseline stay put.
		summary_bold.spacing_bottom = 1
		_result_body.add_theme_font_override("font", summary_bold)
		# 丝带单行大标题严禁自动换行，防止 PanelContainer 在首次排版计算窄宽时折成 7 竖行撑爆到 541px 高度把文字压飞
		_result_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# U5: the four summary rows + payout pill live in their own
		# fixed box above the scroll on phone (reference: always
		# visible, never below the fold); only the extended
		# statistics scroll. Desktop keeps everything in the scroll.
		_result_core = VBoxContainer.new()
		# Keep the accepted 66.3 px pitch while centring rectangular tiles.
		_result_core.add_theme_constant_override("separation", 0)
		_result_core.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(_result_core)
		# U5 re-audit 3: trade 9 px of bottom space for payout headroom;
		# the panel bottom and action row retain their previous placement.
		var _p5_bottom_gap := Control.new()
		_p5_bottom_gap.custom_minimum_size = Vector2(0, 4)
		_p5_bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(_p5_bottom_gap)
	# U5 fix6: the extended-statistics scroll exists on desktop
	# only. On phone its viewport only ever showed a clipped
	# sliver of the fact grid (the stray "0 0 0 0" row) plus a
	# scrollbar -- the reference card has neither. _result_box
	# is still built (orphan on phone) so _fill_result's clear
	# loop keeps working; its content is skipped on phone.
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 10)
	_result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _p5_on:
		var scroll := ScrollContainer.new()
		# U5 fix5: the fix4 scroll trim (340) was a no-op -- a
		# ScrollContainer never propagates its child's min
		# anyway (probe: scroll min (291, 0) with a 708 px
		# child). The spill is fixed by the slim row/payout
		# plate margins in _fill_result instead.
		scroll.custom_minimum_size = Vector2(0, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rcol.add_child(scroll)
		scroll.add_child(_result_box)
	# The pre-18 label said 再来一局 but the button reloads
	# into the MENU (boot state) — the bundle's own primary
	# here is back-to-menu; label it truthfully.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	# U5: buttons centred below the rows (reference); the old
	# right-aligned row is gone with the two columns.
	actions.alignment = BoxContainer.ALIGNMENT_CENTER if _p5_on else BoxContainer.ALIGNMENT_END
	if _p5_on:
		_result_wrap.add_child(actions)
	else:
		rcol.add_child(actions)
	# U5: reference buttons carry icons (refresh / house); the green
	# primary is white-on-green (same whitening as the draft reroll).
	# U5 re-audit 2: a distinct P5 glyph avoids the shared reroll's
	# overlapping 270-degree arcs without changing draft/desktop icons.
	var again := UiTheme.make_icon_button("result_refresh" if _p5_on else "reroll", "再次出发", "green", "big")
	again.pressed.connect(func() -> void:
		_result_panel.hide()
		if _result_wrap != null:
			_result_wrap.hide()
		_open_loadout(_menu_hero_sp))
	actions.add_child(again)
	var b := UiTheme.make_icon_button("result_home" if _p5_on else "home", "返回菜单", "ghost", "big")
	b.pressed.connect(func() -> void: get_tree().reload_current_scene())
	actions.add_child(b)
	var arow := again.get_child(0) as HBoxContainer
	(arow.get_child(0) as UiIcon).color = UiTheme.WHITE
	# Desktop retains its existing icon sizes; P5 overrides below.
	(arow.get_child(0) as UiIcon).custom_minimum_size = Vector2(60, 60)
	again.set_meta("icon_px", 60)
	var brow := b.get_child(0) as HBoxContainer
	(brow.get_child(0) as UiIcon).custom_minimum_size = Vector2(32, 32)
	b.set_meta("icon_px", 32)
	var again_lbl := again.get_meta("label") as Label
	again_lbl.add_theme_color_override("font_color", UiTheme.WHITE)
	if _p5_on:
		# 「再次出发」白色按钮文字补充深绿描边与柔和立体投影
		again_lbl.add_theme_color_override("font_outline_color", Color("2b690c"))
		again_lbl.add_theme_constant_override("outline_size", 5)
		again_lbl.add_theme_color_override("font_shadow_color", Color(0.14, 0.34, 0.04, 0.70))
		again_lbl.add_theme_constant_override("shadow_offset_x", 0)
		again_lbl.add_theme_constant_override("shadow_offset_y", 2)
	if _p5_on:
		# U5 re-audit #4: allow for the texture's transparent borders.
		# The previous action row was 88 design px after the primary
		# floor; +20 adds ~19 logical px to its visible height.
		again.custom_minimum_size.x = 393
		again.set_meta("min_w", 393)
		b.custom_minimum_size.x = 393
		b.set_meta("min_w", 393)
		b.set_meta("p5_primary", true)
		again.custom_minimum_size.y = 108
		b.custom_minimum_size.y = 108
		# U5 re-audit 3: independent caption sizes match the two faces.
		(arow.get_child(0) as UiIcon).custom_minimum_size = Vector2(56, 56)
		again.set_meta("icon_px", 56)
		(brow.get_child(0) as UiIcon).custom_minimum_size = Vector2(58, 58)
		b.set_meta("icon_px", 58)
		for action in [again, b]:
			var action_label := action.get_meta("label") as Label
			var caption_bold := FontVariation.new()
			caption_bold.base_font = load("res://assets/fonts/NotoSC-Black-sub.ttf")
			if action == again:
				caption_bold.spacing_glyph = 8
				caption_bold.variation_transform = Transform2D(Vector2(1.18, 0), Vector2(0, 1), Vector2.ZERO)
			action_label.add_theme_font_override("font", caption_bold)
			var caption_px := 36 if action == again else 40
			action_label.add_theme_font_size_override("font_size", caption_px)
			action_label.set_meta("p5_fs0", caption_px)
			action.set_meta("fs_over", caption_px)
			UiTheme.set_icon_button_text(action, action_label.text)

# ------------------------------------------------------------------ gameplay
func _fmt_time(sec: float) -> String:
	var s := int(maxf(sec, 0.0))
	return "%d:%02d" % [s / 60, s % 60]

func _fmt_elapsed(sec: float) -> String:
	var t := int(maxf(sec, 0.0) * 10.0)
	return "%d:%02d.%d" % [t / 600, (t / 10) % 60, t % 10]

# C23 pack §1.1 [news] @89568. kills/level are deliberately data-only.
const RUN_TIER_NAMES := ["Normal", "Difícil", "Pesadilla"]
const RUN_TIER_ROWS := {
	"hp": [1.0,1.4,1.9], "dmg": [1.0,1.42,1.96], "speed": [1.0,1.08,1.16],
	"amount": [1.0,1.3,1.6], "kills": [1.0,1.25,1.5], "level": [1.0,1.5,1.8],
	"cap": [1.0,1.15,1.3], "elite": [0.0,.04,.08], "events": [1.0,1.2,1.4],
	"early": [0.0,15.0,30.0], "tele": [1.0,.92,.85], "fury": [.5,.55,.6],
	"escorts": [0.0,1.0,2.0], "wound": [4.0,5.0,6.0], "strike": [1.0,1.2,1.4],
	"late": [1.0,1.12,1.25], "alphaCap1": [.15,.25,.25],
}
var run_tier := 0

func tier_value(row: String) -> float:
	return float(RUN_TIER_ROWS[row][clampi(run_tier, 0, 2)])

func tier_name() -> String:
	return RUN_TIER_NAMES[clampi(run_tier, 0, 2)]

func tier_timeline_time(seconds: float) -> float:
	return maxf(60.0, seconds - tier_value("early"))

# C23B Sp is a hurt cap, never a director probability.
var endless := false  # data hook only; this port has no endless game mode.

func alpha_hurt_cap() -> float:
	return tier_value("alphaCap1") if zone == 1 and not endless else 0.25

func strike_options(frac: float = 0.08) -> Dictionary:
	return {"floor": frac if frac >= 0.3 else frac * tier_value("strike"), "evade": 0.5, "cap": 0.34, "source": -1}

func contact_hurt(e: Enemy) -> bool:
	if player == null or e.is_object or e.treasure or e.mode == Enemy.MODE_LEAGUE or (e.flag & 16512) != 0:
		return false
	var flags := e.flag | (4 if e.is_guardian else 0)
	var opts := {"source": e.get_instance_id(), "attacker": e, "type": String(e.types[0]) if not e.types.is_empty() else "",
		"cap": alpha_hurt_cap() if flags & 2 else (0.25 if flags & 12294 else 0.0),
		"floor": 0.05 * tier_value("strike") if flags & 4 else 0.0}
	return player.take_damage(e.out_dmg(), opts)

func hostile_reaches(pos: Vector3, radius: float) -> bool:
	if player == null:
		return false
	var offset := player.global_position - pos
	return Vector2(offset.x, offset.z).length_squared() < pow(radius + Player.RADIUS, 2.0) and absf(offset.y + 0.8) < 1.5

func hostile_hurt(dmg: float, capped: bool, alpha: bool, attack_type: String = "", attacker: Enemy = null) -> bool:
	if player == null:
		return false
	return player.take_damage(dmg, {"type": attack_type, "source": -1, "attacker": attacker,
		"cap": 0.15 if capped else (alpha_hurt_cap() if alpha else 0.0),
		"floor": 0.02 * tier_value("strike") if capped else 0.0})

# Nb/ix success is independent of HP loss; a full shield still wounds.
func miniboss_strike(e: Enemy, mul: float, floor_frac: float = 0.08) -> bool:
	if player == null or e == null or e.hp <= 0.0:
		return false
	var opts := strike_options(floor_frac)
	opts["attacker"] = e
	opts["type"] = String(e.types[0]) if not e.types.is_empty() else ""
	if not player.take_damage(e.out_dmg() * mul, opts):
		return false
	player.wound(tier_value("wound"))
	return true

# Yy uses the same qy floor but its own >=.3 cap and negative opt-out.
func legendary_hurt(e: Enemy, mul: float, frac: float = 0.0, attack_type: String = "") -> bool:
	if player == null or e == null or e.hp <= 0.0:
		return false
	var opts := strike_options(maxf(frac, 0.08)) if frac >= 0.0 else {"source": -1}
	opts["attacker"] = e
	opts["cap"] = 0.6 if frac >= 0.3 else 0.34
	opts["type"] = attack_type if attack_type != "" else (String(e.types[0]) if not e.types.is_empty() else "")
	var landed := player.take_damage(e.out_dmg() * mul, opts)
	if landed and frac >= 0.0:
		player.wound(tier_value("wound"))
	return landed

func run_score(victory: bool) -> float:
	var base: float = round(float(kills * 2) + run_time * 3.0 + damage_dealt / 200.0 + float(zone - 1) * 1500.0 + float(bosses * 800) + (6000.0 if victory else 0.0))
	return base * (1.0 + float(run_tier) * 0.5)

var pickups: Node3D
var keys := 0

func pickup_manager() -> Node3D:
	if pickups == null or not is_instance_valid(pickups):
		pickups = load("res://scripts/pickups.gd").new()
		pickups.world = self
		add_child(pickups)
	return pickups

func spawn_pickup(kind: int, pos: Vector3, value := 1.0) -> int:
	return pickup_manager().spawn(kind, pos, value)

func count_gold_pickup(value: float) -> void:
	GameProfile.count("gold", value)

func start_game(p_species: String, boosts: Array = [], requested_tier: int = 0) -> void:
	if state != "menu":
		return
	if _prebuild_running:
		# Abort the menu prebuild BEFORE anything samples terrain
		# state: the suspended coroutine may have a foreign zone's
		# data applied. It frees its partial scene on its next
		# yield; here we only restore live member state.
		_prebuild_abort = true
		zone = _live_zone
		_pal = ZONES[_live_zone - 1]["pal"]
		_apply_zone_data(_zone_data(_live_zone))
	run_tier = clampi(requested_tier, 0, GameProfile.biome_tier_cap("forest"))
	state = "playing"
	running = true
	elapsed = 0.0
	kills = 0
	# Cycle 16: the run draws its ingame track once (Oc draw,
	# bundle @1440396); the kill chain (xp/streak pitch ladder)
	# resets.
	_run_music = ["ingame1", "ingame2", "ingame3", "ingame4"][_rng.randi_range(0, 3)]
	_kill_chain = 0
	_kill_chain_t = -10.0
	_music_t = 0.0
	zone = 1
	gold = 0.0
	run_time = 0.0
	pickup_manager().clear()
	keys = 0
	damage_dealt = 0.0
	bosses = 0
	captured = 0
	trauma = 0.0
	run_counts.clear()
	_run_alphas = 0
	# Cycle 18: results-screen feeds + boost state reset.
	run_move_dmg.clear()
	run_ally_dmg.clear()
	run_captures.clear()
	run_blessings.clear()
	run_evos = 0
	_master_ball = false
	_boost_honey = false
	_honey_at = -1.0
	# Cycle 20: the stage-1 shiny roll moves to AFTER the
	# player exists (below) — the roll reads the player's
	# luck, which a fresh Player has not computed yet here.
	_shiny_at = INF
	_shiny_spawned = false
	_shiny_e = null
	_shiny_escape = 0.0
	_classic_e = null
	_classic_at = INF
	_shiny_ally = null
	_pending_shiny_ally = null
	_shiny_serial = 0
	_map_pins.clear()
	_fog = PackedByteArray()
	_fog.resize(48 * 48)
	_snap_done.clear()
	for sp in GameProfile.challenge_order():
		if GameProfile.challenge_done(sp):
			_snap_done[sp] = true
	_snap_seen = (GameProfile.data.get("seen", []) as Array).size()
	_snap_captured = (GameProfile.data.get("captured", {}) as Dictionary).size()
	_snap_league = (GameProfile.data.get("league", []) as Array).size()
	_party_sig = ""
	_pill_sig = ""
	_goal_species = ""
	# Cycle 14 resets: shrine roars + boss latch (run-scoped),
	# combat meter (run-scoped), electrocute cooldown, blessing
	# queue/modal, interactable state, blessing RNG (seeded per
	# run so harness flows stay deterministic).
	run_roars = 0
	boss_spawned = false
	_elec_t = -1.0
	# Cycle 15 resets: reaction cooldowns, chest economy,
	# the carried egg, slots run fields.
	_react_cd.clear()
	_chests_bought = 0
	# Cycle 21: Meowth shop run state.
	_shop = {}
	_shop_buys.clear()
	_shop_rerolls_run = 0
	if _shop_open:
		_shop_close()
	_egg_clear()
	_slot_spins = 0
	_slot_prizes.clear()
	_slot_spent = 0
	_slots_prop = {}
	_meter_reset()
	_blessing_queue.clear()
	if _blessing_open:
		_close_blessing()
	# Cycle 21.1: run-boundary hermeticity (suite-red closing
	# hunt). The choice modal, its deferred item-roll queue,
	# the walk-over guardian chests and the portal node are
	# all run-scoped, but none were reset here — the blessing
	# modal above was. A choice modal left open at a run's
	# end (e.g. a guardian chest opened in "portal" state and
	# never picked) survived into the next run with its
	# captured _choice_return intact: every later modal close
	# then restored THAT state ("portal"), which froze the
	# _later timers, the egg tick and the challenge watch
	# (all gated on play states) and failed the guardian
	# summon gate — one leak, seventeen red checks across
	# props/c21 in the C21 closing suite. Reset them all,
	# silently (no pick/close callbacks fire for a run that
	# no longer exists).
	_pending_item_rolls.clear()
	if _choice_open:
		_choice_panel.visible = false
		_choice_open = false
	if _draft_panel and _draft_panel.visible:
		_draft_panel.visible = false
	for c in _chests:
		var cn = c.get("node")
		if cn and is_instance_valid(cn):
			(cn as Node).queue_free()
	_chests.clear()
	if portal_node:
		portal_node.queue_free()
		portal_node = null
	_inter_reset()
	_bless_rng.seed = 14014 + int(GameProfile.data.get("counts", {}).get("runs", 0))
	revive_used = false
	# Cycle 21: stage-event state resets per run.
	_event_kind = ""
	_event_left = 0.0
	_event_done.clear()
	_event_try_t = 75.0
	_event_k = 0.0
	_event_meowth = null
	_event_coin_cd = 0.0
	_zone_t = 0.0
	_takeover_e = null
	banished_keys.clear()
	rerolls_left = 2 + GameProfile.lab_level("reroll")
	skips_left = 2 + GameProfile.lab_level("skip")
	banishes_left = 1 + GameProfile.lab_level("banish")
	_league_e = null
	_league_done = false
	_league_spawn_at = _rng.randf_range(50.0, 120.0)  # §5.2 first encounter window
	_alpha_idx = 0
	_swarm = false
	_swarm_announced = false
	_menu_panel.visible = false
	_wallet_panel.visible = false
	_lab_panel.visible = false
	_unlock_panel.visible = false
	_shop_panel.visible = false
	_sound_panel.visible = false
	if _loadout_panel:
		_loadout_panel.visible = false
	if _pause_panel:
		_pause_panel.visible = false
	if _bigmap_panel:
		_bigmap_panel.visible = false
	GameProfile.record_species_played(p_species)  # roster 'speciesPlayed' counter
	player = Player.new()
	player.process_priority = -10  # physics before the world's camera read
	add_child(player)
	player.global_position = Vector3(SPAWN_XZ.x, height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)
	player.setup(p_species, self)
	player.reset_physics_interpolation()
	player.died.connect(_on_player_died)
	player.evolved.connect(_on_player_evolved)
	# Cycle 13: a fresh ult controller per run (the bundle's ult
	# lives on the run object); charge starts at 0.
	if ult:
		ult.dispose()
	ult = Ult.new(self)
	player.ult_name = ult.ult_name()
	# Cycle 20: the stage-1 shiny director roll (the bundle's
	# setupStage rolls with the run's stats, luck included) —
	# after the player's setup/recalc, before boosts (the
	# shiny stone min()s this roll in _apply_boosts).
	_roll_shiny_director()
	_roll_classic_director()
	_apply_starter_hud(p_species)
	_apply_zone_card()
	_weather_pick(1)  # cycle 12: stage-entry base weather (+ passive override)
	_refresh_hud()
	# Cycle 18: bag bring-in — the selected boosts are SPENT
	# from the profile bag and applied (bundle applyBoosts
	# @1444306; spend-at-start @1580295). Runs after the
	# player exists and before the first draft can open.
	if not boosts.is_empty():
		_apply_boosts(boosts)
	show_banner("第一关 · 青苔林 — 去北边的祭坛召唤守护者！", 4.0)
	for i in range(4):
		_spawn_enemy()
	_cam_focus = player.global_position

## UI-mobile P1.4 (plan §B3 I6): a live line no longer gets
## overwritten — the new text queues behind it and takes
## over once the current one has shown min(secs, 1.2) s
## (or expires). Same text as the live line extends it.
func show_banner(text: String, secs: float) -> void:
	if _banner_t > 0.0 and _banner.text != "":
		if text == _banner.text:
			_banner_t = maxf(_banner_t, secs)
			_banner_secs = maxf(_banner_secs, secs)
			return
		for e in _banner_q:
			if String(e[0]) == text:
				e[1] = maxf(float(e[1]), secs)
				return
		_banner_q.append([text, secs])
		while _banner_q.size() > 4:
			_banner_q.pop_front()
		return
	_banner_show_now(text, secs)

func _banner_show_now(text: String, secs: float) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner_t = secs
	_banner_secs = secs
	_banner_shown_t = 0.0

## UI-mobile P1.1: build-time texts follow the device. Runs
## every frame, acts only when _touch_wanted() flips (the
## first real touch latches _touch_forced mid-session).
func _touch_text_sync() -> void:
	var on := 1 if _touch_wanted() else 0
	if on == _touch_text_on:
		return
	_touch_text_on = on
	if _altar_label:
		_altar_label.text = "Boss 祭坛 · " + _ik() + " 召唤守护者"
	if _menu_hint:
		_menu_hint.text = MENU_HINT_COMPACT if _p5_on else (MENU_HINT_TOUCH if on == 1 else MENU_HINT_KBD)
		_menu_hint.tooltip_text = MENU_HINT_TOUCH if on == 1 else MENU_HINT_KBD
	for k in _kbd_caps:
		if is_instance_valid(k):
			(k as Control).visible = on == 0
	for b in [_draft_team_btn, _blessing_team_btn]:
		if b != null:
			(b as Button).text = "查看我的队伍" if on == 1 else "查看我的队伍 [Tab]"
	if _settings_tabs.has("keys"):
		(_settings_tabs["keys"] as Button).text = "操作" if on == 1 else "键位"
		if _sound_panel and _sound_panel.visible and _settings_tab_now == "keys":
			_settings_show_tab("keys")

## UI-mobile P1.1 (plan §B3 I7): the interact verb on the
## live device — "点互动" (the button's name) with touch
## up, "按 E" otherwise. The plan's "点 ❗" glyph is in none
## of the bundled font subsets (it would draw as tofu).
func _ik() -> String:
	return "点互动" if _touch_wanted() else "按 E"

## The ult verb (the ready toast): the cluster gauge wears
## the 必 glyph on touch.
func _ik_ult() -> String:
	return "点「必」" if _touch_wanted() else "按 R"

## Original spawn scaling (§4.2): HP = base * hpCurve(stage, t) *
## toughness(t); hpCurve = (1 + 0.3t + i^2 * r) * base, i = max(0, t -
## (stage 1 ? 1.5 : 0)), base/r per stage. toughness (§1.3) decays
## 2.4 -> 1.35 over 8 minutes.
func _toughness_now() -> float:
	return 1.35 + 1.05 * maxf(0.0, 1.0 - elapsed / 480.0)

## hpCurve(stage, tMin) @855230: (1 + .3t + i^2 r) x base,
## i = max(0, t - (stage==1 ? 1.5 : 0)).
func _hp_curve(stage: int, minutes: float) -> float:
	var i := maxf(0.0, minutes - (1.5 if stage == 1 else 0.0))
	return (1.0 + 0.3 * minutes + i * i * float(STAGE_HP_R[stage - 1])) * float(STAGE_HP_BASE[stage - 1])

## effTime @855100: stageTime + pt[stage-1] * min(1, stageTime/20);
## pt = [0, 75, 150] (news @89269; stage 4 -> 0).
const STAGE_TIME_PT := [0.0, 75.0, 150.0, 0.0]

func _eff_minutes() -> float:
	return (elapsed + float(STAGE_TIME_PT[zone - 1]) * minf(1.0, elapsed / 20.0)) / 60.0

func _spawn_mult() -> float:
	# Standing simplification (pre-cycle-14): regular spawns use RAW
	# stage minutes; the bundle's director.hpMult uses effMin for
	# everything. The guardian path (cycle 14) uses _eff_minutes()
	# per spec; regular spawns keep the measured cycle-11 behaviour.
	# Cycle 15: hpMult carries stats.difficulty (director @855400)
	# — greed / cursed / slots-gengar temp mods land here. dmgMult
	# has NO difficulty factor in the bundle (verified).
	var dm := 1.0
	if player != null and is_instance_valid(player):
		dm = player.difficulty_mult
	return _hp_curve(zone, elapsed / 60.0) * _toughness_now() * dm

## On-screen cap (§4.1 vCap with the stage factor); 60 = local perf
## ceiling (DIFF §6).
func _enemy_cap() -> int:
	var c := (10.0 + 0.65 * elapsed + 4.5 * pow(elapsed / 60.0, 2.0)) * (1.0 + float(zone - 1) * 0.6)
	if _swarm:
		c *= 1.5
	return mini(int(round(c * tier_value("cap"))), 60)

func _spawn_enemy_at(species: String, pos: Vector3, hp_mult: float, is_guardian: bool = false, scale_mult: float = 1.0, dmg_minutes: float = -1.0) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.global_position = pos
	e.setup(species, player, self, hp_mult * tier_value("hp"), scale_mult, is_guardian)
	e.speed *= tier_value("speed")
	# §4.2 dmgMult = (1 + minutes*0.13) * stage factor (tier 0).
	# Cycle 14: altar waves pass a minutes FLOOR (director.dmgMult
	# with a floor argument, altarWave) — dmg_minutes >= 0 wins.
	var dm := elapsed / 60.0 if dmg_minutes < 0.0 else dmg_minutes
	e.dmg *= (1.0 + dm * 0.13) * float(STAGE_DMG[zone - 1]) * tier_value("dmg") * (tier_value("late") if zone >= 2 else 1.0)
	if is_guardian:
		e.killed.connect(_on_guardian_killed)
	else:
		e.killed.connect(_on_enemy_killed)
	return e

func _ring_pos(min_r: float, max_r: float) -> Vector3:
	var ang := randf() * TAU
	var rad := randf_range(min_r, max_r)
	var pos := player.global_position + Vector3(cos(ang) * rad, 0, sin(ang) * rad)
	pos.x = clamp(pos.x, -BOUND + 2.0, BOUND - 2.0)
	pos.z = clamp(pos.z, -BOUND + 2.0, BOUND - 2.0)
	pos.y = height_at(pos.x, pos.z)
	return pos

func _spawn_enemy() -> void:
	if player == null:
		return
	var zc: Dictionary = ZONES[zone - 1]
	var species_list: Array = zc["pool"]
	var weights: Array = zc["weights"]
	var r := randf()
	var acc := 0.0
	var sp: String = species_list[0]
	for i in range(species_list.size()):
		acc += float(weights[i])
		if r <= acc:
			sp = species_list[i]
			break
	# Elite roll (§4.3): none in stage 1's first 90 s.
	var elite := false
	if elapsed >= (90.0 if zone == 1 else 0.0):
		var p := 0.012 + (elapsed / 60.0) * 0.004 + float(zone - 1) * 0.03 + tier_value("elite")
		if _event_kind == "eclipse":
			p += 0.12  # cycle 21: sx eliteBonus during eclipse
		elite = randf() < p
	var e := _spawn_enemy_at(sp, _ring_pos(24.0, 36.0), _spawn_mult() * (4.5 if elite else 1.0), false, 1.35 if elite else 1.0)
	if elite:
		e.flag = 1
		e.dmg *= 1.4

## §4.3 timeline alphas: an evolved pool species (flag Alpha) at
## 150 / 330 / 480 s of each stage.
func _spawn_alpha() -> void:
	var pool: Array = ZONES[zone - 1]["pool"]
	var base_sp := String(pool[_rng.randi_range(0, pool.size() - 1)])
	var sp := base_sp
	var tgt: Dictionary = GameData.evo_target(base_sp)
	if not tgt.is_empty() and ModelRig.SPECIES.has(String(tgt["key"])):
		sp = String(tgt["key"])
	var e := _spawn_enemy_at(sp, _ring_pos(24.0, 36.0), _spawn_mult() * 22.0, false, 2.0)
	e.flag = 2
	e.dmg *= 1.8
	# Cycle 16: alpha warning (bundle @860152: alarm + cry).
	audio.alarm()
	audio.cry(sp)
	show_banner("头领 %s 出现了！打倒它后%s用结伴匣结伴" % [String(ModelRig.SPECIES[sp]["label"]), _ik()], 4.0)

## League encounter (§5.2): one roaming species whose family is not
## yet in the league; weakened (not killed) in combat, caught with E.
func _spawn_league() -> void:
	# §3 gate (cycles 8-9): the original's encounter picker draws
	# from leagueReady() GLOBALLY — `t.meta.leagueReady().filter(
	# e => e !== 150)` then a uniform pick (bundle @1049619) — NOT
	# from the current zone's wild pool. Cycle 8 filtered by zone,
	# which made pinsir/scyther/snorlax (in no zone pool) literally
	# unencounterable (audit §5). Our pool: every modelled roster
	# species whose challenge is complete and whose family is not
	# yet in the League.
	var ready: Array = []
	for sp in GameData.roster_species_keys():
		var sd: Dictionary = GameData.species(String(sp))
		if not GameProfile.in_league(int(sd.get("family", 0))) and GameProfile.challenge_done(String(sp)):
			ready.append(String(sp))
	if ready.is_empty():
		_league_done = true
		return
	var sp := String(ready[_rng.randi_range(0, ready.size() - 1)])
	var e := _spawn_enemy_at(sp, _ring_pos(25.0, 45.0), _spawn_mult() * 0.8)
	e.mode = Enemy.MODE_LEAGUE
	# Cycle 21: the legendary roll also rides roaming
	# league targets of the legendary class (bundle
	# spawnTarget @1049996). Our species data has no rarity
	# field — the class proxy is captureRate <= 45 (DIFF §21).
	if int(GameData.species(sp).get("captureRate", 255)) <= 45 \
			and _rng.randf() < 0.03 * GameProfile.shiny_rate():
		e.shiny = true
		if e.rig:
			e.rig.apply_shiny()
	_league_e = e
	_league_escape = 150.0
	# Cycle 16: encounter fanfare + the species' cry.
	audio.encounter()
	audio.cry(sp)
	GameProfile.mark_seen(sp)
	show_banner("林间出现了 %s！打倒它后靠近%s，结伴进伙伴营" % [String(ModelRig.SPECIES[sp]["label"]), _ik()], 4.0)

## Kill rewards (§4.4): XP by the enemy's own formula, gold 0.2/kill
## x the player's gold multiplier (swarm weight factor is 1 here).
func _award_kill(e: Enemy) -> void:
	# Cycle 13: every kill funnels through here (normal + guardian
	# paths) — feed the ult gauge with the bundle's flag/slot
	# rules before anything else spends the corpse's data.
	if ult:
		ult.on_kill(e.flag, e.last_hit_slot)
	# Cycle 16: kill sounds — pop + the xp() pitch ladder on a
	# 1.5 s kill chain, streak() blips on chains (the bundle's
	# streak window is its STREAK_WINDOW; ours is the chain).
	if not e.is_guardian:
		if run_time - _kill_chain_t <= 1.5:
			_kill_chain += 1
		else:
			_kill_chain = 1
		_kill_chain_t = run_time
		audio.pop()
		if _kill_chain >= 2:
			audio.streak(_kill_chain)
	kills += 1
	GameProfile.count("kills")  # §3 lifetime counter (rattata/scyther)
	GameProfile.count("kills_" + String(ZONES[zone - 1]["tiles"]))  # bundle tally(): count('kills_' + biome) (@741800)
	if e.flag == 2:
		_run_alphas += 1
		GameProfile.count("alphas")
	if player and is_instance_valid(player):
		pickup_manager().drops(e)
	if _kill_chain >= 25:
		pickup_manager().magnet_all = 4.0

func _on_enemy_killed(e: Enemy) -> void:
	# Cycle 22: bundle R.Object units (lapras pillars)
	# credit nothing — no ult, no kill count, no XP/gold.
	if e.is_object:
		return
	_award_kill(e)
	# Cycle 22: the golden meowth's death pays the
	# fountain and ends its event (events.onKilled).
	if _event_kind == "meowth" and e == _event_meowth:
		_event_meowth_killed()

func summon_guardian() -> void:
	if state != "playing":
		return
	state = "guardian"
	boss_spawned = true
	_altar_label.visible = false
	var trio_full: Array = (ZONES[zone - 1]["guardians"] as Array).duplicate()
	# Cycle 21 coverage adaptation (DIFF §21): the bundle-true
	# trios name species with no GLB in our rig (weezing,
	# hypno, rapidash); spawning one would crash rig.setup.
	# The summon draws from the modelled subset — the data
	# stays bundle-true, the missing models are the gap.
	var trio: Array = []
	for sp in trio_full:
		if ModelRig.SPECIES.has(String(sp)):
			trio.append(String(sp))
	if trio.is_empty():
		trio = trio_full.duplicate()
	trio.shuffle()
	while trio.size() < 3:
		trio.append(trio[0])
	var gpos := Vector3(ALTAR_XZ.x, 0, ALTAR_XZ.y + 5.0)
	gpos.y = height_at(gpos.x, gpos.z)
	# Cycle 14 (boss.spawn @996027): the cycle-7/9 theoretical-DPS
	# budget is REPLACED by the bundle's real pipeline —
	#   formula = baseHp x hpCurve(stage, max(floor, effMin))
	#             x BOSS_ZONE_HP x 70 (boss flag) x (1 + .3 roars)
	#   floor = 2.5 min (Sb @995138); the stage-4 legendary branch
	#   (spawnBoss @1459438) uses floor 0 and a x1.6 factor.
	#   fightSecs = GUARDIAN_SECS x (1 + .3 roars) FIRST, then the
	#   budget = meterDps x fightSecs (Cb @995145) RAISES the HP to
	#   min(budget, 4x formula) when larger (Tb @995317). Bosses
	#   skip toughness (spawn @325140).
	var roars := run_roars
	var o := 1.0 + 0.3 * float(roars)
	var legendary := zone == 4
	var curve := _hp_curve(zone, maxf(0.0 if legendary else 2.5, _eff_minutes()))
	if legendary:
		curve *= 1.6
	var secs := float(GUARDIAN_SECS[zone - 1]) * o
	var base := Enemy.base_hp(String(trio[0]))
	var formula_hp := base * curve * float(BOSS_ZONE_HP[zone - 1]) * 70.0 * o
	var budget := meter_dps() * secs
	var final_hp := formula_hp
	if budget > formula_hp:
		final_hp = minf(budget, formula_hp * 4.0)
	guardian = _spawn_enemy_at(String(trio[0]), gpos, final_hp / base, true, 2.6)
	_boss_reset()  # cycle 21: the Nb boss brain takes over
	# Cycle 21: the legendary shiny roll (bundle
	# rollLegendShiny @1053012: 3% x shinyRate, not in
	# endless — we have no endless mode). A shiny guardian
	# triggers the guaranteed-capture takeover on defeat.
	if _rng.randf() < 0.03 * GameProfile.shiny_rate():
		guardian.shiny = true
		if guardian.rig:
			guardian.rig.apply_shiny()
		show_banner("传说流光守护者 %s！击败它可必定捕获！" % String(ModelRig.SPECIES[guardian.species_id]["label"]), 4.0)
	guardian.dmg *= 2.2 * (1.0 + 0.12 * float(roars))  # boss flag x2.2 + roar damage Ry .12/roar
	guardian.roars = roars
	guardian.fight_secs = secs
	guardian.set_damage_cap(final_hp * tier_value("hp") / (float(BOSS_CAP_DIV[mini(2, zone - 1)]) * o))
	# Escorts: the standing two elites + 1 elite per roar (zy's
	# "mas escoltas elite" — our mapping; the bundle's escorts come
	# from boss-mech calls we do not port, DIFF cycle 14).
	for k in range(2 + roars):
		var ea := float(k) / float(maxi(2 + roars, 1)) * TAU + 0.7
		var epos := Vector3(ALTAR_XZ.x + cos(ea) * 4.5, 0, ALTAR_XZ.y + 2.0 + sin(ea) * 3.0)
		epos.y = height_at(epos.x, epos.z)
		var esc := _spawn_enemy_at(String(trio[1 + (k % 2)]), epos, _spawn_mult() * ESCORT_HP_MULT, false, 1.35)
		esc.flag = 1  # escorts carry the elite flag (§1.3 multipliers applied above)
		esc.dmg *= 1.4
	# Cycle 16: boss intro — bossStart + the guardian's cry,
	# music ducked under the intro (bundle duck(.25, intro)).
	audio.boss_start()
	audio.cry(String(trio[0]))
	audio.duck(0.25, 2.5)
	show_banner("守护者出现了！击败它，开启传送门！", 3.5)

func _on_guardian_killed(e: Enemy) -> void:
	# Cycle 8 correction: the guardian's killed signal connects ONLY
	# here (see _spawn_enemy_at), so rewards must be awarded here —
	# the cycle-7 comment claiming a second generic connection was
	# wrong, and guardians silently paid no XP/gold/kill credit.
	# Cycle 21: clear the boss brain's live entities.
	for h in _hostiles:
		if is_instance_valid(h["node"]):
			(h["node"] as Node).queue_free()
	_hostiles.clear()
	_boss_waves.clear()
	_boss_pools.clear()
	_boss_spiral = {}
	_boss_charge = {}
	_award_kill(e)
	bosses += 1
	GameProfile.count("bosses")
	GameProfile.count("boss_" + String(ZONES[zone - 1]["tiles"]))  # §3 boss_<biome> (cubone)
	GameProfile.record_biome_clear(String(ZONES[zone - 1]["tiles"]), run_tier)  # local guardian-clear adaptation; pack §1.2 write site unknown
	if zone == 4:
		GameProfile.count("legendaries")  # onBossKilled: final-stage guardian counts as legendary (@1460549)
	add_trauma(0.8)  # bundle: boss killed -> shake(0.8) (@1460549)
	hitstop(0.5)     # bundle: boss killed -> hitstop(.5) (@1460549)
	audio.boom(1.0)  # cycle 16: boss-kill boom + the coin reward below
	# --- Guardian reward (bundle onBossKilled @1462726, cycle 9) ---
	# 20 coin pickups of wB = ceil(5 * stage * gold) each
	# (wB @1555023). Cycle 20 (DIFF §7 correction): there is
	# NO shiny factor in wB — Be() is a perk ladder with no
	# gold consumer; the factor cycle 19 wired in here was
	# invented and is removed. C23 spawns the twenty coin entities
	# here; their gold settles when the player collects them.
	var death_pos := e.global_position
	var gm := player.gold_mult if player else 1.0
	var coin_each := int(ceil(5.0 * float(zone) * gm))
	for i in range(20):
		spawn_pickup(1, death_pos, coin_each)
	spawn_pickup(6, death_pos)
	# Free Poké Ball chests: one at (+3, +2) from the corpse, plus
	# one per roar on a 3.2 u ring (spawnChestAt @1462726). Since
	# cycle 21 they roll REAL items (rollChestItem floor 0).
	_spawn_chest(death_pos + Vector3(3.0, 0, 2.0))
	for i in range(e.roars):
		var a := float(i) / float(maxi(e.roars, 1)) * TAU + 0.6
		_spawn_chest(death_pos + Vector3(3.0 + cos(a) * 3.2, 0, 2.0 + sin(a) * 3.2))
	# Cycle 21: shiny-boss takeover (bundle takeOver
	# @1054139): a SHINY guardian does not stay dead — the
	# kill rewards above still pay (onBossKilled), and the
	# boss rises weakened at 1% HP as a capture target whose
	# throw is guaranteed (capture.sure). The portal below
	# still opens; leaving without throwing forfeits it.
	if e.shiny:
		var tk := _spawn_enemy_at(e.species_id, death_pos + Vector3(2.5, 0, 0), 1.0, false, 2.6)
		tk.mode = Enemy.MODE_LEAGUE
		tk.shiny = true
		if tk.rig:
			tk.rig.apply_shiny()
		tk.hp = tk.max_hp * 0.01
		tk.is_weakened = true
		tk.weak_t = 9999.0
		_shiny_e = tk
		_takeover_e = tk
		show_banner("流光守护者被击败了！走近%s邀伴——必定捕获！" % _ik(), 5.0)
	state = "portal"
	guardian = null
	_open_portal()
	show_banner("传送门已开启！走进传送门！", 4.0)

## ------------------------------------------------------ cycle 14
## Interactables: blessing altars (Unown) + the Rhydon roar
## totem. Spec in DIFF.md cycle 14 (populate @1240977, ZC
## @~1235800, tw @~1234800, altarUpdate @1267643, zy @~866030,
## offerBlessing @1481319, Xx @1075554, Bx @1069962). Scenes are
## built with each zone's scene and parked/restored with it;
## run state lives in _inter_state and resets in start_game.

func _stone_mats() -> void:
	if _stone_mat:
		return
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_color = Color(0.45, 0.44, 0.48)
	_stone_mat.roughness = 0.95
	_stone_dark_mat = StandardMaterial3D.new()
	_stone_dark_mat.albedo_color = Color(0.3, 0.29, 0.33)
	_stone_dark_mat.roughness = 0.95
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.vertex_color_use_as_albedo = true
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

## tw(rng, count, luckMult) port: tier blocks then the pre-shuffle
## tier-3 upgrade roll. luckMult is 1 at build time (no luck gear
## exists before a run starts) -> upgrade chance .2 (cap .3).
func _altar_tiers(count: int, rng: RandomNumberGenerator) -> Array:
	var tiers: Array = []
	var r2 := maxi(1, int(round(float(count) * 0.15))) if count >= 4 else 0
	var n1 := int(round(float(count) * 0.3))
	for i in range(count):
		tiers.append(2 if i < r2 else (1 if i < r2 + n1 else 0))
	if not tiers.is_empty() and rng.randf() < minf(0.3, 0.2 * sqrt(1.0)):
		tiers[0] = 3
	for i in range(tiers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = tiers[i]
		tiers[i] = tiers[j]
		tiers[j] = t
	return tiers

## populate's placement sampler r(): 30 uniform candidates in the
## annulus [14, play-5], keep the one maximizing the min over the
## landmark clearances and the placed interactables (x0.5 same
## kind, x0.65 same landmark class — altar/totem are both LC 1).
## Candidates failing _flat_open score -inf unless all do (the
## bundle's terrain reserves flat ground instead — DIFF).
func _inter_sample(rng: RandomNumberGenerator, placed: Array, kind: String, r: float) -> Vector2:
	var best := Vector2(60.0, 60.0)
	var best_score := -1e18
	for i in range(30):
		var a := rng.randf() * TAU
		var rad := sqrt(lerpf(14.0 * 14.0, 163.0 * 163.0, rng.randf()))
		var cand := Vector2(cos(a), sin(a)) * rad
		var score := 1e18
		for lm in [Vector3(ALTAR_XZ.x, ALTAR_XZ.y, 2.7), Vector3(SPAWN_XZ.x, SPAWN_XZ.y, 3.0)]:
			score = minf(score, cand.distance_to(Vector2(lm.x, lm.y)) - lm.z - 3.0)
		for p in placed:
			var f := 1.0
			if String(p["kind"]) == kind:
				f = 0.5
			elif int(p["lc"]) == 1:
				f = 0.65
			score = minf(score, (cand.distance_to(p["pos"]) - maxf(0.0, float(p["r"]) - 2.6)) * f)
		if not _flat_open(cand.x, cand.y):
			score = -1e17 + score * 0.001
		if score > best_score:
			best_score = score
			best = cand
	return best

func _build_interactables(z: int) -> Node3D:
	_stone_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = 30634 ^ (z * 7919)  # bundle: Tu(seed ^ 30634); ours per-zone
	var root := Node3D.new()
	root.name = "Interactables"
	var placed: Array = []
	# Cycle 21: dowsing-machine (bundle tw): +1 altar and
	# +2 free chests per stack from the next zone on (the
	# populate runs at zone start, so a mid-zone gain
	# lands next zone, exactly like the bundle).
	var dows := 0
	if player and is_instance_valid(player):
		dows = player.item_count("dowsing-machine")
	var tiers := _altar_tiers(5 + dows, rng)
	var altars: Array = []
	for i in range(tiers.size()):
		var tier := int(tiers[i])
		var cfg: Dictionary = ALTAR_CFG[tier]
		var pos := _inter_sample(rng, placed, "altar", float(cfg["r"]))
		placed.append({"kind": "altar", "lc": 1, "pos": pos, "r": float(cfg["r"])})
		var a := _make_altar(pos, tier)
		root.add_child(a["root"])
		altars.append(a)
	var tpos := _inter_sample(rng, placed, "rhydon", 3.2)
	placed.append({"kind": "rhydon", "lc": 1, "pos": tpos, "r": 3.2})
	var totem := _make_totem(tpos)
	root.add_child(totem["root"])
	# Cycle 15: the remaining populate kinds, placed AFTER the
	# altars + totem on the SAME seeded stream (their positions
	# are new draws; the cycle-14 layout prefix is unchanged).
	# Order follows populate() @1240977 minus the kinds that
	# were out of scope in cycle 15: bill, hypno,
	# magnet (meowth joined in cycle 21, ditto in cycle 22).
	# Counts are the areaMul=1 values;
	# r from add() @~1238150; LC 2 = creature props.
	var props: Array = []
	for plan in PROP_PLAN:
		var kind := String(plan[0])
		# Bundle populate: dowsing adds to the PAID chest
		# kind (`chest`), not the free one.
		var cnt := int(plan[1]) + (2 * dows if kind == "chest" else 0)
		for i in range(cnt):
			var pr := float(plan[2])
			var pos := _inter_sample(rng, placed, kind, pr)
			placed.append({"kind": kind, "lc": int(plan[3]), "pos": pos, "r": pr})
			var prop := _make_prop(kind, pos, z, rng)
			root.add_child(prop["root"])
			props.append(prop)
	_inter_state[z] = {"altars": altars, "totem": totem, "props": props, "root": root}
	(_inter_target if _inter_target else self).add_child(root)
	return root

## Cycle 15 populate plan: [kind, count, interact r, LC].
const PROP_PLAN := [
	["fossil", 1, 2.8, 1], ["greed", 1, 2.6, 0], ["challenge", 2, 3.2, 0], ["cursed", 1, 3.0, 0],
	["porygon", 1, 2.4, 2], ["nest", 1, 2.8, 2], ["meowth", 1, 2.6, 2], ["ditto", 1, 2.6, 2], ["snorlax", 2, 2.6, 2],
	["slots", 2, 2.4, 0], ["freechest", 3, 2.6, 0], ["cursedchest", 2, 2.6, 0],
	["cage", 2, 2.6, 2], ["berry", 5, 2.6, 0], ["magnet", 2, 2.6, 0], ["chest", 14, 2.6, 0],
	["rock", 14, 2.6, 0],
]
## Ambush roster for the cursed chest (RC @1234939, dex ids
## mapped to species keys; all modelled in our build).
const GHOST_ROSTER := ["gastly", "gastly", "haunter", "haunter", "gengar"]

func _make_altar(pos: Vector2, tier: int) -> Dictionary:
	var cfg: Dictionary = ALTAR_CFG[tier]
	var col: Color = cfg["color"]
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.y), pos.y)
	# Ground ring (the charge circle's base, tier colour, faint).
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = float(cfg["r"]) - 0.28
	tm.outer_radius = float(cfg["r"]) + 0.28
	tm.rings = 40
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(col, 0.16)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position = Vector3(0, 0.1, 0)
	root.add_child(ring)
	# Charge progress fan (rebuilt when the charge bucket moves).
	var prog := MeshInstance3D.new()
	prog.material_override = _ring_mat
	prog.position = Vector3(0, 0.12, 0)
	root.add_child(prog)
	# Crystal: two cones tip-to-tip on a stone plinth, per-altar
	# emissive material (tier tint; greys when sealed/used).
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = col
	cmat.emission_enabled = true
	cmat.emission = col
	cmat.emission_energy_multiplier = 0.8
	var crys := Node3D.new()
	crys.position = Vector3(0, 2.1, 0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 1.5
	cone.radial_segments = 6
	var up := MeshInstance3D.new()
	up.mesh = cone
	up.material_override = cmat
	up.position = Vector3(0, 0.75, 0)
	crys.add_child(up)
	var dn := MeshInstance3D.new()
	dn.mesh = cone
	dn.material_override = cmat
	dn.position = Vector3(0, -0.75, 0)
	dn.rotation.z = PI
	crys.add_child(dn)
	root.add_child(crys)
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.9
	pm.bottom_radius = 1.2
	pm.height = 0.7
	plinth.mesh = pm
	plinth.material_override = _stone_mat
	plinth.position = Vector3(0, 0.35, 0)
	root.add_child(plinth)
	# Four pillars at the ring's diagonals.
	for k in range(4):
		var pa := float(k) * PI * 0.5 + PI * 0.25
		var pil := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 2.2, 0.5)
		pil.mesh = bm
		pil.material_override = _stone_dark_mat
		var pr := float(cfg["r"]) * 0.55
		pil.position = Vector3(cos(pa) * pr, 1.1, sin(pa) * pr)
		root.add_child(pil)
	# Orbiting Unown shards (count = ZC.unown), tier emissive.
	var umat := StandardMaterial3D.new()
	umat.albedo_color = col
	umat.emission_enabled = true
	umat.emission = col
	umat.emission_energy_multiplier = 1.6
	var unowns: Array = []
	for k in range(int(cfg["unown"])):
		var u := MeshInstance3D.new()
		var um := BoxMesh.new()
		um.size = Vector3(0.34, 0.5, 0.12)
		u.mesh = um
		u.material_override = umat
		root.add_child(u)
		unowns.append(u)
	# Wave-tier light pillar (altarBeacon; alpha .3 while sealed).
	var beacon: MeshInstance3D = null
	if int(cfg["wave"]) > 0:
		beacon = MeshInstance3D.new()
		var bcm := CylinderMesh.new()
		bcm.top_radius = 0.9 + 0.3 * float(tier - 2)
		bcm.bottom_radius = 0.9 + 0.3 * float(tier - 2)
		bcm.height = 4.2
		beacon.mesh = bcm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(col, 0.10)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beacon.material_override = bmat
		beacon.position = Vector3(0, 2.1, 0)
		root.add_child(beacon)
	return {"tier": tier, "x": pos.x, "z": pos.y, "charge": 0.0,
		"used": false, "warned": false, "woke": false, "sealed": false,
		"wave_t": 1.5, "wave_n": 0, "out_t": 0.0, "spin": 0.0,
		"bucket": -1, "root": root, "prog": prog, "crys": crys,
		"cmat": cmat, "unowns": unowns, "beacon": beacon}

func _make_totem(pos: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.y), pos.y)
	root.rotation.y = atan2(pos.x, pos.y)  # faces the origin (zy)
	var base := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 1.7
	bcm.bottom_radius = 1.95
	bcm.height = 0.9
	base.mesh = bcm
	base.material_override = _stone_mat
	base.position = Vector3(0, 0.45, 0)
	root.add_child(base)
	var pillar := MeshInstance3D.new()
	var pbm := BoxMesh.new()
	pbm.size = Vector3(1.5, 2.4, 1.5)
	pillar.mesh = pbm
	pillar.material_override = _stone_dark_mat
	pillar.position = Vector3(0, 2.1, 0)
	root.add_child(pillar)
	var head := MeshInstance3D.new()
	var hbm := BoxMesh.new()
	hbm.size = Vector3(1.15, 0.9, 1.15)
	head.mesh = hbm
	head.material_override = _stone_mat
	head.position = Vector3(0, 3.7, 0)
	root.add_child(head)
	# The horn: a cone on a pivot at the head's front — zy spins it
	# for .9 s on every roar.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 4.0, -0.4)
	root.add_child(pivot)
	var horn := MeshInstance3D.new()
	var hcm := CylinderMesh.new()
	hcm.top_radius = 0.03
	hcm.bottom_radius = 0.5
	hcm.height = 1.7
	hcm.radial_segments = 10
	horn.mesh = hcm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.85, 0.8, 0.7)
	horn.material_override = hmat
	horn.position = Vector3(0, 0.4, -0.6)
	horn.rotation.x = -1.1
	pivot.add_child(horn)
	# Three rune stones in an arc in front; each lights at roar n.
	var rune_mats: Array = []
	for k in range(3):
		var ra := -0.5 + 0.5 * float(k)
		var rs := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		rbm.size = Vector3(0.55, 0.85, 0.3)
		rs.mesh = rbm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.4, 0.38, 0.42)
		rmat.emission_enabled = true
		rmat.emission = Color(1.0, 0.45, 0.2)
		rmat.emission_energy_multiplier = 0.0
		rs.material_override = rmat
		rs.position = Vector3(sin(ra) * 2.6, 0.42, -cos(ra) * 2.6)
		rs.rotation.y = ra
		root.add_child(rs)
		rune_mats.append(rmat)
	return {"x": pos.x, "z": pos.y, "used": false, "horn_t": 0.0,
		"runes_lit": 0, "root": root, "horn": pivot, "rune_mats": rune_mats}

## ------------------------------------------------ cycle 15 props
## Primitive visuals per populate kind (the bundle uses its
## biome prop models; ours follow the altar/totem idiom —
## stone + one emissive accent). "dim" records the accent
## materials so a spent prop greys like the bundle's used
## icons do.

func _prop_mat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m

func _prop_mesh(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi

func _prop_box(root: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _prop_mesh(root, bm, mat, pos)

func _prop_sphere(root: Node3D, r: float, mat: Material, pos: Vector3, squash := 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	var mi := _prop_mesh(root, sm, mat, pos)
	mi.scale = Vector3(1, squash, 1)
	return mi

func _make_prop(kind: String, pos: Vector2, z: int, rng: RandomNumberGenerator) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.y), pos.y)
	root.rotation.y = rng.randf() * TAU
	var dim: Array = []
	var data: Dictionary = {}
	var accent: StandardMaterial3D
	match kind:
		"fossil":
			data = Fossils.build_visual(self, root, dim)
		"magnet":
			accent = _prop_mat(Color(0.6,0.5,1.0),0.8)
			_prop_box(root,Vector3(0.35,1.1,0.35),accent,Vector3(-0.35,0.8,0))
			_prop_box(root,Vector3(0.35,1.1,0.35),accent,Vector3(0.35,0.8,0))
			_prop_box(root,Vector3(1.05,0.3,0.35),accent,Vector3(0,0.25,0))
			dim.append([accent,accent.albedo_color,0.8])
		"berry":
			var leaf := _prop_mat(Color8(46, 125, 50))
			_prop_sphere(root, 0.62, leaf, Vector3(0, 0.55, 0))
			_prop_sphere(root, 0.5, leaf, Vector3(0.55, 0.42, 0.3))
			_prop_sphere(root, 0.5, leaf, Vector3(-0.5, 0.45, -0.25))
			accent = _prop_mat(Color8(229, 57, 53), 0.7)
			for k in range(5):
				var a := float(k) * 1.7
				_prop_sphere(root, 0.13, accent, Vector3(cos(a) * 0.45, 0.85 + 0.12 * sin(a * 2.0), sin(a) * 0.45))
			dim.append([accent, accent.albedo_color, 0.7])
		"rock":
			accent = _prop_mat(Color8(120, 118, 125))
			var big := _prop_box(root, Vector3(1.15, 0.85, 0.95), accent, Vector3(0, 0.42, 0))
			big.rotation.y = 0.5
			var small := _prop_box(root, Vector3(0.6, 0.5, 0.55), accent, Vector3(0.35, 1.05, 0.1))
			small.rotation.y = 1.1
			dim.append([accent, accent.albedo_color, 0.0])
		"snorlax":
			accent = _prop_mat(Color8(38, 70, 83))
			_prop_sphere(root, 0.95, accent, Vector3(0, 0.8, 0), 0.9)
			var belly := _prop_mat(Color8(233, 220, 193))
			_prop_sphere(root, 0.62, belly, Vector3(0, 0.75, 0.42), 1.0)
			_prop_sphere(root, 0.46, belly, Vector3(0, 1.72, 0))
			dim.append([accent, accent.albedo_color, 0.0])
		"greed":
			var plinth := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.8
			pm.bottom_radius = 1.05
			pm.height = 0.6
			plinth.mesh = pm
			plinth.material_override = _stone_mat
			plinth.position = Vector3(0, 0.3, 0)
			root.add_child(plinth)
			accent = _prop_mat(Color8(255, 196, 0), 1.2)
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.42
			cone.height = 1.25
			cone.radial_segments = 6
			_prop_mesh(root, cone, accent, Vector3(0, 1.55, 0))
			var dn := _prop_mesh(root, cone, accent, Vector3(0, 0.95, 0))
			dn.rotation.z = PI
			dim.append([accent, accent.albedo_color, 1.2])
		"cursed":
			accent = _prop_mat(Color8(106, 27, 154), 0.9)
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.7
			cone.radial_segments = 6
			_prop_mesh(root, cone, accent, Vector3(0, 1.15, 0))
			var skull := _prop_mat(Color8(238, 238, 238))
			_prop_sphere(root, 0.3, skull, Vector3(0, 0.32, 0.55))
			dim.append([accent, accent.albedo_color, 0.9])
		"porygon":
			accent = _prop_mat(Color8(239, 83, 80))
			_prop_box(root, Vector3(0.95, 0.72, 0.95), accent, Vector3(0, 0.75, 0))
			var head := _prop_mat(Color8(255, 138, 128))
			_prop_box(root, Vector3(0.55, 0.45, 0.55), head, Vector3(0, 1.5, 0.1))
			var beak := CylinderMesh.new()
			beak.top_radius = 0.02
			beak.bottom_radius = 0.16
			beak.height = 0.5
			var bk := _prop_mesh(root, beak, accent, Vector3(0, 1.42, 0.55))
			bk.rotation.x = PI * 0.5
			var eye := _prop_mat(Color8(66, 165, 245), 1.0)
			_prop_sphere(root, 0.09, eye, Vector3(0.18, 1.58, 0.4))
			_prop_sphere(root, 0.09, eye, Vector3(-0.18, 1.58, 0.4))
			dim.append([accent, accent.albedo_color, 0.0])
			data["offers"] = []
		"nest":
			accent = _prop_mat(Color8(121, 85, 72))
			var tm := TorusMesh.new()
			tm.inner_radius = 0.45
			tm.outer_radius = 0.85
			tm.rings = 16
			tm.ring_segments = 8
			_prop_mesh(root, tm, accent, Vector3(0, 0.3, 0))
			var eggm := _prop_mat(Color8(255, 248, 225))
			_prop_sphere(root, 0.38, eggm, Vector3(0, 0.62, 0), 1.25)
			dim.append([accent, accent.albedo_color, 0.0])
			var pool: Array = ZONES[z - 1]["pool"]
			data["species"] = String(pool[rng.randi_range(0, pool.size() - 1)])
		"meowth":
			# Cycle 21: the visiting shopkeeper (bundle JC
			# dex 52, populate count 1). A rig on a gold
			# plinth; never consumed — E opens the shop.
			accent = _prop_mat(Color8(255, 210, 58), 0.8)
			_prop_sphere(root, 0.55, accent, Vector3(0, 0.1, 0))
			var mrig := ModelRig.new()
			root.add_child(mrig)
			mrig.position = Vector3(0, 0.16, 0)
			mrig.setup("meowth", 0.75)
			data["rig"] = mrig
			dim.append([accent, accent.albedo_color, 0.8])
		"ditto":
			# Cycle 22: the item-cloning prop (bundle JC dex
			# 132, populate count 1, LC weight 2). The bundle
			# prop is a sprite on a #c88aff ring; no ditto
			# GLB exists in our build, so — per the snorlax/
			# porygon primitive precedent — a glossy blob on
			# a ring disc in the bundle's ring colour.
			accent = _prop_mat(Color8(200, 138, 255), 0.55)
			var disc := CylinderMesh.new()
			disc.top_radius = 0.85
			disc.bottom_radius = 0.95
			disc.height = 0.14
			_prop_mesh(root, disc, accent, Vector3(0, 0.07, 0))
			var blob := _prop_mat(Color8(219, 168, 235), 0.25)
			var bb := _prop_sphere(root, 0.52, blob, Vector3(0, 0.5, 0))
			bb.scale = Vector3(1.05, 0.82, 1.0)
			var eye := _prop_mat(Color8(38, 30, 48), 0.4)
			_prop_sphere(root, 0.055, eye, Vector3(0.17, 0.62, 0.46))
			_prop_sphere(root, 0.055, eye, Vector3(-0.17, 0.62, 0.46))
			dim.append([accent, accent.albedo_color, 0.55])
			dim.append([blob, blob.albedo_color, 0.25])
		"cage":
			accent = _prop_mat(Color8(55, 58, 64))
			_prop_box(root, Vector3(1.7, 0.16, 1.7), accent, Vector3(0, 0.08, 0))
			_prop_box(root, Vector3(1.7, 0.14, 1.7), accent, Vector3(0, 1.62, 0))
			for sx in [-0.78, 0.78]:
				for sz in [-0.78, 0.78]:
					_prop_box(root, Vector3(0.1, 1.55, 0.1), accent, Vector3(sx, 0.85, sz))
			var pool: Array = ZONES[z - 1]["pool"]
			var species := String(pool[rng.randi_range(0, pool.size() - 1)])
			data["species"] = species
			var rig := ModelRig.new()
			root.add_child(rig)
			rig.position = Vector3(0, 0.16, 0)
			rig.setup(species, 0.75)
			data["rig"] = rig
			dim.append([accent, accent.albedo_color, 0.0])
		"chest", "freechest", "cursedchest":
			var top_col := Color8(183, 28, 28) if kind != "cursedchest" else Color8(74, 20, 140)
			accent = _prop_mat(top_col)
			var wh := _prop_mat(Color8(238, 238, 238)) if kind != "cursedchest" else _prop_mat(Color8(38, 38, 46))
			var t := _prop_sphere(root, 0.46, accent, Vector3(0, 0.32, 0))
			t.scale = Vector3(1, 0.62, 1)
			var b := _prop_sphere(root, 0.46, wh, Vector3(0, 0.32, 0))
			b.scale = Vector3(1, -0.62, 1)
			_prop_sphere(root, 0.12, wh, Vector3(0, 0.34, 0.42))
			dim.append([accent, accent.albedo_color, 0.0])
		"challenge":
			accent = _prop_mat(Color8(96, 95, 100))
			_prop_box(root, Vector3(0.55, 2.6, 0.55), accent, Vector3(-1.25, 1.3, 0))
			_prop_box(root, Vector3(0.55, 2.6, 0.55), accent, Vector3(1.25, 1.3, 0))
			_prop_box(root, Vector3(3.1, 0.55, 0.65), accent, Vector3(0, 2.85, 0))
			dim.append([accent, accent.albedo_color, 0.0])
			data["wave"] = []
			data["pending"] = 0
			data["done"] = false
		"slots":
			accent = _prop_mat(Color8(78, 42, 140))
			_prop_box(root, Vector3(1.35, 1.65, 0.85), accent, Vector3(0, 0.85, 0))
			var win := _prop_mat(Color8(255, 241, 118), 1.1)
			for k in range(3):
				_prop_box(root, Vector3(0.3, 0.4, 0.06), win, Vector3(-0.4 + 0.4 * float(k), 1.15, -0.46))
			var lever := _prop_box(root, Vector3(0.12, 0.95, 0.12), win, Vector3(0.85, 1.25, 0))
			lever.rotation.z = 0.4
			dim.append([accent, accent.albedo_color, 0.0])
	var r := 2.6
	for plan in PROP_PLAN:
		if String(plan[0]) == kind:
			r = float(plan[2])
	return {"kind": kind, "x": pos.x, "z": pos.y, "r": r, "used": false,
		"root": root, "data": data, "dim": dim}

func _prop_set_used(p: Dictionary) -> void:
	p["used"] = true
	for rec in p.get("dim", []):
		var m := (rec[0] as StandardMaterial3D)
		m.albedo_color = Color(0.32, 0.32, 0.35)
		if m.emission_enabled:
			m.emission_energy_multiplier = 0.0

func _prop_reset_visual(p: Dictionary) -> void:
	for rec in p.get("dim", []):
		var m := (rec[0] as StandardMaterial3D)
		m.albedo_color = rec[1]
		if m.emission_enabled:
			m.emission_energy_multiplier = float(rec[2])

func _inter_reset() -> void:
	for z in _inter_state.keys():
		var st: Dictionary = _inter_state[z]
		for a in st["altars"]:
			a["charge"] = 0.0
			a["used"] = false
			a["warned"] = false
			a["woke"] = false
			a["sealed"] = false
			a["wave_t"] = 1.5
			a["wave_n"] = 0
			a["out_t"] = 0.0
			a["bucket"] = -1
		st["totem"]["used"] = false
		st["totem"]["horn_t"] = 0.0
		# Cycle 15: props reset for the new run (slots state is
		# run-scoped on the world, reset in start_game).
		for p in st.get("props", []):
			p["used"] = false
			_prop_reset_visual(p)
			var pd: Dictionary = p["data"]
			match String(p["kind"]):
				"fossil":
					Fossils.reset_visual(p)
				"challenge":
					pd["wave"] = []
					pd["pending"] = 0
					pd["done"] = false
				"cage":
					if pd.get("rig") and is_instance_valid(pd["rig"]):
						(pd["rig"] as Node3D).visible = true
				"porygon":
					pd["offers"] = []
	# Cycle 15: the comet does not survive a run boundary;
	# its timer restarts at _E (75 s, @1349051).
	_comet_clear()
	_comet_t = 75.0
	_timers.clear()

## Per-frame interactable sim for the LIVE zone (altars charge by
## presence; called from _process while the world clock runs).
func _inter_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var st: Dictionary = _inter_state.get(zone, {})
	if st.is_empty():
		return
	var pp := player.global_position
	for a in st["altars"]:
		_altar_update(a, pp, delta)
		_altar_visual(a, delta)
	var tot: Dictionary = st["totem"]
	if float(tot["horn_t"]) > 0.0:
		tot["horn_t"] = maxf(0.0, float(tot["horn_t"]) - delta)
		var e := 1.0 - float(tot["horn_t"]) / 0.9
		(tot["horn"] as Node3D).rotation.z = e * PI * 4.0 * (1.0 - e * 0.5)
	var lit := mini(run_roars, 3)
	if int(tot["runes_lit"]) != lit:
		tot["runes_lit"] = lit
		for i in range(3):
			(tot["rune_mats"][i] as StandardMaterial3D).emission_energy_multiplier = 3.2 if i < lit else 0.0
	# Cycle 15: comet event, challenge completion, egg hatch.
	_comet_tick(delta, pp)
	for p in st.get("props", []):
		if String(p["kind"]) == "challenge":
			_challenge_watch(p)
	_egg_tick()

## ------------------------------------------------ cycle 15 comet
## updateComet @~1356838: the comet ref persists while its
## altar is in the stage (used or burnt-out comets BLOCK
## respawn until the stage changes — the ref only clears
## when the stage's list is rebuilt; ours frees on zone
## advance / run reset). cometT starts at _E = 75 s
## (@1349051) and resets to range(100,140) when it fires.

func _comet_clear() -> void:
	if not _comet.is_empty():
		var r = _comet.get("root")
		if r and is_instance_valid(r):
			(r as Node).queue_free()
		_comet = {}

func _comet_spawn(pt: Vector2) -> void:
	var a := _make_altar(pt, 4)
	a["comet"] = true
	a["life"] = 60.0
	_comet = a
	add_child(a["root"])
	spawn_nova(Vector3(pt.x, height_at(pt.x, pt.y) + 0.5, pt.y), 8.0, Color8(74, 168, 255))
	add_trauma(0.25)
	show_banner("☄ 彗星碎片坠落了！在它熄灭前为它充能", 3.5)

func _comet_burnout() -> void:
	# burnOut @1272478: used, grey splash, toast, NO payout.
	# The altar stays (dimmed by _altar_visual) and the ref
	# keeps blocking respawns this stage — bundle-true.
	_comet["used"] = true
	var p := Vector3(float(_comet["x"]), height_at(float(_comet["x"]), float(_comet["z"])) + 0.6, float(_comet["z"]))
	spawn_nova(p, 4.0, Color(0.55, 0.55, 0.6))
	show_banner("彗星碎片熄灭了…", 2.5)

func _comet_tick(delta: float, pp: Vector3) -> void:
	if not _comet.is_empty():
		var a := _comet
		# Burn-out band (iw.update @~1260597) runs before the
		# altar update: life ticks ONLY while unused and the
		# charge is still exactly 0.
		if not bool(a["used"]) and float(a["charge"]) <= 0.0:
			a["life"] = float(a["life"]) - delta
			if float(a["life"]) <= 0.0:
				_comet_burnout()
				return
		_altar_update(a, pp, delta)
		_altar_visual(a, delta)
		return
	if state != "playing" and state != "guardian":
		return
	_comet_t -= delta
	if _comet_t > 0.0:
		return
	_comet_t = _bless_rng.randf_range(100.0, 140.0)
	# (the bundle's mewtwo.active gate has no system here.)
	var fp := Vector2(pp.x, pp.z)
	var best := Vector2.ZERO
	var best_flat := false
	var found := false
	for i in range(12):
		var ang := _bless_rng.randf() * TAU
		var dist := _bless_rng.randf_range(25.0, 40.0)
		var pt := Vector2(fp.x + cos(ang) * dist, fp.y + sin(ang) * dist)
		pt.x = clampf(pt.x, -BOUND + 6.0, BOUND - 6.0)
		pt.y = clampf(pt.y, -BOUND + 6.0, BOUND - 6.0)
		if fp.distance_to(pt) < 18.0:
			continue
		found = true
		if _flat_open(pt.x, pt.y):
			best = pt
			best_flat = true
			break
		if not best_flat:
			best = pt
	if not found:
		_comet_t = 10.0
		return
	_comet_spawn(best)

## ------------------------------------------------ cycle 15 egg
## The carried egg (pp/gp @317944/319200): hatches when
## kills - from >= need while the run is in play; the baby
## is recruited at the player's side. The egg visual rides
## beside the player (hp @~318442 — an orbiting shell).

func _egg_carry(species: String, need: int) -> void:
	_egg = {"from": kills, "need": need, "species": species}
	if _egg_node and is_instance_valid(_egg_node):
		_egg_node.queue_free()
	_egg_node = Node3D.new()
	var shell := _prop_mat(Color8(255, 248, 225))
	var egg := _prop_sphere(_egg_node, 0.34, shell, Vector3.ZERO, 1.25)
	egg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_egg_node)

func _egg_tick() -> void:
	if _egg.is_empty():
		return
	if _egg_node and is_instance_valid(_egg_node) and player and is_instance_valid(player):
		var t := Time.get_ticks_msec() / 1000.0
		var anchor := player.global_position + Vector3(cos(t * 1.7) * 1.1, 1.15 + sin(t * 2.3) * 0.15, sin(t * 1.7) * 1.1)
		_egg_node.global_position = anchor
	if state != "playing":
		return
	if kills - int(_egg["from"]) < int(_egg["need"]):
		return
	var species := String(_egg["species"])
	_egg = {}
	if _egg_node and is_instance_valid(_egg_node):
		_egg_node.queue_free()
	_egg_node = null
	count_run_event("eggs")
	show_banner("🥚 蛋孵化了！%s 加入了队伍！" % String(ModelRig.SPECIES[species]["label"]), 3.0)
	# gp @319200: recruit, or — when the team is at the
	# §5.3 cap (2 + Lab party, the _throw_ball gate) — the
	# bundle's fallback rollChestItem() (one grant, floor 0).
	if _normal_ally_count() >= _team_cap():
		_chest_roll_single(0)
		return
	var pos := _ring_pos(2.5, 3.5)
	var e := _spawn_enemy_at(species, pos, _spawn_mult(), false, 1.0)
	e.make_ally()

func _egg_clear() -> void:
	_egg = {}
	if _egg_node and is_instance_valid(_egg_node):
		_egg_node.queue_free()
	_egg_node = null

## ------------------------------------------------ cycle 15 challenge
## Completion watch (iw.update @1258148): once the staggered
## spawns are all in and every wave enemy is dead, the
## shrine pays a free chest at +(2.5, 2.5).

func _challenge_watch(p: Dictionary) -> void:
	if not bool(p["used"]):
		return
	var d: Dictionary = p["data"]
	if bool(d.get("done", false)) or int(d.get("pending", 0)) > 0:
		return
	for e in d["wave"]:
		if is_instance_valid(e) and float((e as Enemy).hp) > 0.0 \
				and not (e as Enemy).is_downed and not (e as Enemy).is_weakened:
			return
	d["done"] = true
	d["wave"] = []
	count_run_event("challenges")
	show_banner("⚔ 挑战完成！宝箱出现了", 3.0)
	var st: Dictionary = _inter_state.get(zone, {})
	if st.is_empty():
		return
	var pos := Vector2(float(p["x"]) + 2.5, float(p["z"]) + 2.5)
	pos.x = clampf(pos.x, -BOUND + 3.0, BOUND - 3.0)
	pos.y = clampf(pos.y, -BOUND + 3.0, BOUND - 3.0)
	var chest := _make_prop("freechest", pos, zone, _bless_rng)
	(st["root"] as Node).add_child(chest["root"])
	(st["props"] as Array).append(chest)

## ------------------------------------------------ cycle 15 chest economy
## BC @1234939 / VC / chestCost @1237871 / qC @1077141 —
## the chest-value curve that also prices rock and snorlax
## gold (DIFF cycle 15). The e>40 / e>50 terms reuse
## (e-30) in the source; transcribed as-is.

func _bc(e: int) -> float:
	var t := 35.0 * float(e)
	if e > 10:
		t += 300.0 * float(e - 10)
	if e > 20:
		t += 550.0 * float(e - 20)
	if e > 30:
		t += 1200.0 * float(e - 30)
	if e > 40:
		t += 2400.0 * float(e - 30)
	if e > 50:
		t += 4500.0 * float(e - 30)
	return (pow(1.22, float(e)) + t / 30.0) * pow(1.12, maxf(0.0, float(e - 12)))

func _chest_value() -> float:
	return 18.0 * _bc(_chests_bought)

## Cycle 21: the ally cap = 2 + Lab party + ss-ticket.
func _team_cap() -> int:
	var t := 2 + GameProfile.lab_level("party")
	if player and is_instance_valid(player):
		t += player.item_count("ss-ticket")
	return t

## Cycle 21: gold-teeth discount (bundle tS): Meowth and
## the slots machine charge (1 - .08 x stacks), capped
## at -24% (3 stacks is also the def max).
func _teeth_mult() -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	return 1.0 - 0.08 * float(mini(3, player.item_count("gold-teeth")))

## Cycle 21: zone table accessor (the const is not
## reachable through an instance from outside scripts).
func zone_def(z: int) -> Dictionary:
	return ZONES[z - 1]

func _chest_cost() -> int:
	var luck := player.luck if player != null and is_instance_valid(player) else 0.0
	# Cycle 21: the full bundle chestCost (@1236548) —
	# CHEST_BASE x BC(chestsBought) x luck discount x the
	# big-nugget item factor (1 - min(.4, .08 x stacks)); the
	# endless curse.chest factor is 1 (no curse system).
	var nug := 0
	if player != null and is_instance_valid(player):
		nug = player.item_count("big-nugget")
	var t := 1.0 - minf(0.4, 0.08 * float(nug))
	# Cycle 22 (audit N6): the bundle clamps luck at 0 —
	# (1 - min(.25, max(0, luck)/400)) — negative luck must
	# never RAISE the price above the luck-0 price.
	return int(round(18.0 * _bc(_chests_bought) * (1.0 - minf(0.25, maxf(0.0, luck) / 400.0)) * t))

func _wc(t: float) -> float:
	return pow(t, float(mini(4, maxi(1, zone)) - 1))

func _sell_value(tier: int) -> int:
	var base: float = [10.0, 18.0, 30.0, 50.0, 90.0][tier]
	var qx: float = [80.0, 130.0, 220.0, 400.0, 750.0][tier]
	var gc: float = [0.3, 0.45, 0.65, 1.0, 1.5][tier]
	return int(round(maxf(base * float(zone), minf(0.5 * qx * _wc(float(tier)), gc * _chest_value()))))

## rollChestItem in our established vitamin mapping (DIFF
## cycle 15): one grant at rarity max(floor, Bx), power
## BLESSING_PE[tier]; presentation mirrors _open_chest.
func _vitamin_label(key: String, pe: float) -> String:
	var vd: Dictionary = GameData.VITAMINS[key]
	return String(vd["fmt"]) % _fmt_num(float(vd["per"]) * pe)

## ------------------------------------------------ cycle 21 items
## The bundle's item roll (Gx @1074187 + rollChestItem
## @1478468), replacing the cycle-9/15/19 vitamin mapping:
## chest rolls are REAL item rolls over the 126 mined defs
## (assets/data/items.json). The pool filter is the
## bundle's: meta.itemInPool (our Archive) AND the player
## below the def's max stack. Wx (tower dowsing exclusion)
## has no tower here. Banished items read our run banish
## set under the "item:" prefix (no banish source offers
## items in this chain yet — filter wired, source noted
## in DIFF).

## Bx(e, floor, 10, availability) — the item rarity roll
## (the draft's _blessing_tier_roll is the same Bx with
## luck bonus 0 and no mask).
func _item_tier_roll(floor_tier: int, avail: Array) -> int:
	var luck := player.luck if player else 0.0
	var i := maxf(0.0, luck + 10.0)
	var a := i / 100.0
	var o := float(player.level if player else 1) + i / 8.0 + float(zone - 1) * 12.0
	var s := func(lo: float, hi: float) -> float: return clampf((o - lo) / (hi - lo), 0.0, 1.0)
	var w := [70.0 / (1.0 + a), 24.0 * (1.0 + 0.5 * a),
		5.0 * pow(1.0 + a, 2.0) * s.call(3.0, 10.0),
		0.9 * pow(1.0 + a, 3.0) * s.call(8.0, 18.0),
		0.12 * pow(1.0 + a, 4.0) * s.call(14.0, 26.0)]
	var total := 0.0
	for t in range(5):
		var x := float(w[t]) * (1.0 if t >= floor_tier else 0.0001)
		if not bool(avail[t]):
			x = 0.0
		w[t] = x
		total += x
	if total <= 0.000001:
		return floor_tier
	var roll := _bless_rng.randf() * total
	for t in range(5):
		roll -= float(w[t])
		if roll <= 0.0:
			return t
	return 0

func _item_pool_keys() -> Array:
	var out: Array = []
	if player == null:
		return out
	for k in GameData.item_keys():
		var key := String(k)
		if GameProfile.item_in_pool(key) and player.item_count(key) < GameData.item_max(key):
			out.append(key)
	return out

## Gx(run, floor) -> item key or "" (the bundle returns
## null when floor >= 3 and no rarity >= floor is in pool).
func _roll_item_key(floor_tier: int) -> String:
	if player == null:
		return ""
	var pool := _item_pool_keys()
	var avail := [false, false, false, false, false]
	for key in pool:
		if not banished_keys.has("item:" + String(key)):
			avail[GameData.item_rarity(String(key))] = true
	if floor_tier >= 3:
		var any_hi := false
		for t in range(floor_tier, 5):
			any_hi = any_hi or avail[t]
		if not any_hi:
			return ""
	var tier := maxi(floor_tier, _item_tier_roll(floor_tier, avail))
	var cands: Array = []
	for key in pool:
		if GameData.item_rarity(String(key)) == tier and not banished_keys.has("item:" + String(key)):
			cands.append(String(key))
	var tt := tier - 1
	while cands.is_empty() and tt >= 0:
		for key in pool:
			if GameData.item_rarity(String(key)) == tt and not banished_keys.has("item:" + String(key)):
				cands.append(String(key))
		tt -= 1
	if cands.is_empty():
		# Bundle fallback: the full def list (archive filter
		# NOT applied), still under max.
		for k in GameData.item_keys():
			var key := String(k)
			if player.item_count(key) < GameData.item_max(key):
				cands.append(key)
	if cands.is_empty():
		return ""
	# F.weighted: x4 for a type: tag matching the player's
	# types, x0.35 for any other tag, else x1.
	var ptypes: Array = []
	if player:
		ptypes = player.types()  # cycle 22: current types (imposter copies count)
	var total := 0.0
	var ws: Array = []
	for key in cands:
		var tags: Array = GameData.item_def(String(key)).get("tags", [])
		var w := 1.0
		if not tags.is_empty():
			w = 0.35
			for tg in tags:
				var tgs := String(tg)
				if tgs.begins_with("type:") and ptypes.has(tgs.trim_prefix("type:")):
					w = 4.0
		ws.append(w)
		total += w
	var roll := _bless_rng.randf() * total
	for idx in range(cands.size()):
		roll -= float(ws[idx])
		if roll <= 0.0:
			return String(cands[idx])
	return String(cands[cands.size() - 1])

## Kx filler: pool keys not already chosen, rarity >= floor
## first (bundle order), for multi-roll choices.
func _item_fill_keys(floor_tier: int, chosen: Array) -> Array:
	var hi: Array = []
	var lo: Array = []
	for key in _item_pool_keys():
		var k := String(key)
		if chosen.has(k) or banished_keys.has("item:" + k):
			continue
		if GameData.item_rarity(k) >= floor_tier:
			hi.append(k)
		else:
			lo.append(k)
	hi.append_array(lo)
	return hi

## Icon order 2 — held-item art. The mapping rule (the order's
## required item table): file = assets/ui/items/item_<id>.png
## with the code id's hyphens turned to underscores; all 126
## CHARM_TYPES / items.json ids resolve (verified against the
## landed files). Display names keep coming from
## GameData.item_def(key).name — file names never surface.
var _item_tex_cache := {}
func _item_tex(key: String) -> Texture2D:
	if _item_tex_cache.has(key):
		return _item_tex_cache[key]
	var p := "res://assets/ui/items/item_%s.png" % key.replace("-", "_")
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_item_tex_cache[key] = tex
	return tex

func _item_icon_rect(key: String, sz: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _item_tex(key)
	tr.custom_minimum_size = Vector2.ONE * sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

const ITEM_STAT_CN := {
	"damage": "伤害", "attackSpeed": "攻速", "maxHp": "最大生命",
	"moveSpeed": "移速", "critChance": "暴击率", "critDamage": "暴击伤害",
	"area": "范围", "xpGain": "经验", "gold": "金币", "regen": "再生",
	"armor": "护甲", "luck": "幸运", "duration": "持续时间",
	"statusChance": "状态概率", "statusDamage": "状态伤害",
	"physical": "物理", "special": "特殊",
	"evasion": "闪避", "projSpeed": "弹速", "projectiles": "投射物",
	"bounces": "弹跳", "flinch": "击退", "healing": "治疗",
	"eliteDamage": "精英伤害", "superEffective": "克制伤害",
	"lifesteal": "吸血", "extraJumps": "额外跳跃", "jumpHeight": "跳跃高度",
	"pickupRange": "拾取范围", "thorns": "反伤",
	"difficulty": "难度", "enemyAmount": "敌人数量",
}
const ITEM_BESPOKE_CN := {
	"secret-key": "古石祭坛充能 +30%/层，离开时流失减半",
	"ice-heal": "击碎冻结：伤害 +60%（每多一层 +30%），碎冰溅射冻结周围",
	"rare-candy": "立即 +2 级，伤害 +5%",
	"max-revive": "复活一次（60% 生命）",
	"ss-ticket": "本局同伴上限 +1",
	"tm-case": "技能等级上限 +2（至 10）",
	"max-ether": "维生素等级上限 +2（至 12）",
	"eviolite": "可成长时：护甲 +50%，最大生命 +25%",
	"gold-teeth": "獾掌柜铺与老虎机价格 -8%/层（至 -24%）",
	"big-nugget": "付费宝箱价格 -8%/层（至 -40%）",
	"dowsing-machine": "后续区域：祭坛 +1/层，付费宝箱 +2/层",
}

## 全 126 件持有物品中性中文译名表，仅供商店与卡牌展示层读取，保持 GameData.item_def 兼容测试不动
const ITEM_NAME_ZH := {
	"charcoal": "余烬炭块", "mystic-water": "清泉滴瓶", "miracle-seed": "新芽种子", "magnet": "磁石块", "never-melt-ice": "恒冰晶",
	"black-belt": "武者腰带", "poison-barb": "紫刺针", "soft-sand": "细沙袋", "sharp-beak": "锐羽喙", "twisted-spoon": "弯折银勺",
	"silver-powder": "银鳞粉", "hard-stone": "坚岩石", "spell-tag": "幽纸符", "dragon-fang": "龙牙", "black-glasses": "墨镜",
	"metal-coat": "钢甲片", "silk-scarf": "丝绸围巾", "fairy-feather": "粉羽毛", "oran-berry": "蓝浆果", "quick-powder": "迅捷粉",
	"bright-powder": "闪光粉", "amulet-coin": "招财护符", "scope-lens": "瞄准镜片", "wide-lens": "广角镜", "zoom-lens": "望远筒",
	"soothe-bell": "安宁铃", "lax-incense": "安神香", "honey": "蜂蜜罐", "cleanse-tag": "净化符", "potion": "回复药水",
	"lucky-punch": "幸运拳套", "big-nugget": "大金块", "grip-claw": "抓钩", "berry-juice": "果汁杯", "soda-pop": "汽水瓶",
	"muscle-band": "力量护腕", "wise-glasses": "智者眼镜", "quick-claw": "疾爪", "razor-claw": "利爪", "shell-bell": "贝壳风铃",
	"leftovers": "剩饭便当", "rocky-helmet": "岩刺头盔", "light-clay": "光黏土", "air-balloon": "气球", "white-herb": "白草",
	"power-herb": "力量草", "sitrus-berry": "金柑果", "lucky-egg": "福运蛋", "big-root": "粗树根", "smoke-ball": "烟雾弹",
	"metronome": "节拍器", "flame-orb": "火焰珠", "toxic-orb": "毒雾珠", "snowball": "雪球", "binding-band": "束缚带",
	"smooth-rock": "光滑石", "white-flute": "白笛", "adrenaline-orb": "激昂珠", "repel": "驱散香囊", "metal-powder": "金属粉",
	"burn-heal": "退热膏", "ice-heal": "暖身贴", "awakening": "提神铃", "lemonade": "柠檬水", "secret-key": "古祭坛钥匙",
	"gold-teeth": "金牙套", "old-rod": "旧钓竿", "life-orb": "生命宝珠", "choice-band": "专注头带", "choice-specs": "专注眼镜",
	"choice-scarf": "专注围巾", "expert-belt": "达人腰带", "focus-band": "坚持头巾", "kings-rock": "王冠石", "assault-vest": "突击背心",
	"eviolite": "进阶晶石", "exp-share": "经验共享坠", "macho-brace": "负重护具", "black-sludge": "黑泥瓶", "star-piece": "星辰碎片",
	"stick": "芦苇杖", "razor-fang": "锐牙", "shed-shell": "蜕壳", "cell-battery": "电池", "lum-berry": "青葡果",
	"poke-doll": "布偶玩偶", "dowsing-machine": "寻宝探测器", "bicycle": "自行车", "iron-ball": "铁球", "fresh-water": "清水瓶",
	"full-heal": "全能药", "guard-spec": "护卫喷剂", "coin-case": "零钱包", "focus-sash": "不屈腰带", "pp-max": "技能精华",
	"max-elixir": "全能灵药", "shiny-stone": "曦光晶", "dusk-stone": "暮色晶", "comet-shard": "彗星碎片", "thunder-stone": "雷晶",
	"fire-stone": "火晶", "protector": "护甲板", "griseous-orb": "灰金宝珠", "reaper-cloth": "幽影布", "electirizer": "电能匣",
	"ice-stone": "冰晶", "leaf-stone": "叶晶", "revive": "复苏晶", "ss-ticket": "船票", "max-ether": "能量灵液",
	"thick-club": "粗木棒", "rage-candy-bar": "怒气糖棒", "silph-scope": "显影镜", "max-revive": "大复苏晶", "rare-candy": "成长星糖",
	"master-ball": "必得徽印", "moon-stone": "月晶", "lustrous-orb": "珍珠宝珠", "adamant-orb": "金刚宝珠", "dawn-stone": "晨曦晶",
	"sun-stone": "日晶", "soul-dew": "灵露滴", "silver-wing": "银羽", "rainbow-wing": "虹羽", "tm-case": "招式卷宗",
	"poke-flute": "唤醒长笛",
}

func _item_zh_name(key: String) -> String:
	if ITEM_NAME_ZH.has(key):
		return String(ITEM_NAME_ZH[key])
	return String(GameData.item_def(key).get("name", key))

func _item_label(key: String) -> String:
	var def := GameData.item_def(key)
	var parts: Array = []
	for m in (def.get("mods", []) as Array):
		var stat := String(m.get("stat", ""))
		var cn := String(ITEM_STAT_CN.get(stat, stat))
		if m.has("mul"):
			var pct := int(round((float(m["mul"]) - 1.0) * 100.0))
			parts.append("%s %s%d%%" % [cn, "+" if pct >= 0 else "", pct])
		elif m.has("add"):
			var av := float(m["add"])
			if stat in ["critChance", "evasion", "lifesteal"]:
				var apct := int(round(av * 100.0))
				parts.append("%s %s%d%%" % [cn, "+" if apct >= 0 else "", apct])
			else:
				parts.append("%s %s%s" % [cn, "+" if av >= 0.0 else "", _fmt_num(av)])
	if ITEM_BESPOKE_CN.has(key):
		parts.append(String(ITEM_BESPOKE_CN[key]))
	if parts.is_empty():
		parts.append("特殊物品")
	return " · ".join(parts)

func _item_card_text(key: String) -> String:
	var nm := _item_zh_name(key)
	return "%s\n%s\n【%s】 持有 %d/%d" % [nm, _item_label(key),
		String(GameData.RARITY_NAMES[GameData.item_rarity(key)]),
		player.item_count(key) if player else 0, GameData.item_max(key)]

var _pending_item_rolls: Array = []  # deferred rollChestItem queue

## rollChestItem(free, floor, count) port. `free` only fed
## the tier floor in the C15 mapping (+!!e); the bundle's
## floor argument at every call site is explicit today.
func _roll_chest_item(floor_tier: int, count: int = 1) -> void:
	if _choice_open:
		# The bundle defers via whenFree; ours queues.
		_pending_item_rolls.append([floor_tier, count])
		return
	if count <= 1:
		var key := _roll_item_key(floor_tier)
		if key == "":
			var g := _sell_value(2)
			gold += float(g)
			count_event("chests")
			show_banner("物品已全满：+%d 金币" % g, 2.5)
			spawn_floater(player.global_position + Vector3(0, 2.6, 0), "物品已全满 +%d" % g, Color(1.0, 0.8, 0.35))
			return
		count_event("chests")
		var sell := _sell_value(GameData.item_rarity(key))
		_choice_show("获得物品", "选择带走，或出售换金币", [_item_card_text(key)],
			"出售 +%d 金币" % sell,
			func(_idx: int) -> void:
				if player.add_item(key):
					show_banner("获得物品：%s" % String(GameData.item_def(key).get("name", key)), 2.5)
				else:
					gold += float(sell)
					show_banner("物品已满，自动出售：+%d 金币" % sell, 2.5),
			func() -> void:
				gold += float(sell)
				show_banner("出售了物品：+%d 金币" % sell, 2.5))
		return
	var chosen: Array = []
	var first := _roll_item_key(floor_tier)
	if first != "":
		chosen.append(first)
	var guard := 0
	while chosen.size() < count and guard < 16:
		guard += 1
		var k2 := _roll_item_key(floor_tier)
		if k2 != "" and not chosen.has(k2):
			chosen.append(k2)
	if chosen.size() < count:
		for k3 in _item_fill_keys(floor_tier, chosen):
			if chosen.size() >= count:
				break
			chosen.append(String(k3))
	if chosen.is_empty():
		var g := _sell_value(2)
		gold += float(g)
		count_event("chests")
		show_banner("物品已全满：+%d 金币" % g, 2.5)
		return
	if chosen.size() == 1:
		_roll_chest_item_single_card(chosen[0])
		return
	count_event("chests")
	var sell := 1 << 30
	for k4 in chosen:
		sell = mini(sell, _sell_value(GameData.item_rarity(String(k4))))
	var opts: Array = []
	for k5 in chosen:
		opts.append(_item_card_text(String(k5)))
	_choice_show("宝箱", "选择一件带走", opts, "全部出售 +%d 金币" % sell,
		func(idx: int) -> void:
			var key := String(chosen[idx])
			if player.add_item(key):
				show_banner("获得物品：%s" % String(GameData.item_def(key).get("name", key)), 2.5)
			else:
				gold += float(sell)
				show_banner("物品已满，自动出售：+%d 金币" % sell, 2.5),
		func() -> void:
			gold += float(sell)
			show_banner("出售了全部物品：+%d 金币" % sell, 2.5))

func _roll_chest_item_single_card(key: String) -> void:
	count_event("chests")
	var sell := _sell_value(GameData.item_rarity(key))
	_choice_show("获得物品", "选择带走，或出售换金币", [_item_card_text(key)],
		"出售 +%d 金币" % sell,
		func(_idx: int) -> void:
			if player.add_item(key):
				show_banner("获得物品：%s" % String(GameData.item_def(key).get("name", key)), 2.5)
			else:
				gold += float(sell)
				show_banner("物品已满，自动出售：+%d 金币" % sell, 2.5),
		func() -> void:
			gold += float(sell)
			show_banner("出售了物品：+%d 金币" % sell, 2.5))

func _chest_roll_single(floor_tier: int) -> void:
	_roll_chest_item(floor_tier, 1)

## ------------------------------------------------ cycle 21: Meowth shop
## openShop @1477749 / Zx @1075742 / eS / rerollCost /
## buyShopItem, mined this cycle. The shop is keyed by
## stage (ours: zone); a new stage restocks and zeroes
## the per-shop rerolls, while the run-level reroll count
## (bundle shopRerolls) drives the 1.5^x price exponent.
## shopHeat: the first 2 + floor(chestsBought/3) buys of
## the run are heat-free; every later buy multiplies
## future prices by $x[rarity] = [1.15, 1.25, 1.4, 1.6, 2].
const SHOP_QX := [80, 130, 220, 400, 750]
const SHOP_HEAT_X := [1.15, 1.25, 1.4, 1.6, 2.0]
var _shop: Dictionary = {}  # {stage, stock, rerolls}
var _shop_buys: Array = []  # rarities bought this run
var _shop_rerolls_run := 0
var _meowth_panel: PanelContainer
var _shop_title: Label
var _shop_stock_box: HBoxContainer
var _shop_sell_box: HBoxContainer
var _shop_reroll_btn: Button
var _shop_open := false
var _shop_return := "playing"
var _shop_armed_key := ""
var _shop_armed_msec := 0

func _shop_heat() -> float:
	var h := 1.0
	var free_n := 2 + _chests_bought / 3
	for i in range(free_n, _shop_buys.size()):
		h *= float(SHOP_HEAT_X[int(_shop_buys[i])])
	return h

func _shop_price(key: String) -> int:
	return int(round(float(SHOP_QX[GameData.item_rarity(key)]) * _wc(2.2) * _shop_heat() * _teeth_mult()))

func _shop_gen_stock() -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < 4 and tries < 16:
		tries += 1
		var key := _roll_item_key(0)
		if key == "":
			continue
		var dup := false
		for e in out:
			if String(e["key"]) == key:
				dup = true
		if dup:
			continue
		out.append({"key": key, "price": _shop_price(key), "sold": false})
	return out

func _shop_reroll_cost() -> int:
	return int(round(0.5 * float(SHOP_QX[0]) * _wc(2.2) * pow(1.5, float(_shop_rerolls_run)) * _teeth_mult()))

func _open_shop() -> void:
	if _shop_open:
		return
	if _shop.is_empty() or int(_shop.get("stage", -1)) != zone:
		_shop = {"stage": zone, "stock": _shop_gen_stock(), "rerolls": 0}
	_shop_return = state
	_shop_open = true
	state = "shop"
	running = false
	audio.click()
	_shop_refresh()
	_meowth_panel.visible = true

func _shop_close() -> void:
	if not _shop_open:
		return
	_meowth_panel.visible = false
	_shop_open = false
	_shop_armed_key = ""
	state = _shop_return
	running = true

func _shop_refresh() -> void:
	if _meowth_panel == null:
		return
	_shop_title.text = "商店 · %d 金币" % int(gold)
	if _shop_gold_l:
		_shop_title.text = "商店"
		_shop_gold_l.text = "%d 金币" % int(gold)
	for c in _shop_stock_box.get_children():
		c.queue_free()
	var stock: Array = _shop.get("stock", [])
	if stock.is_empty():
		var l := Label.new()
		l.text = "「你什么都有了。这里没剩什么给你了。」"
		l.add_theme_font_override("font", UiTheme.body_font())
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", UiTheme.TEXT)
		_shop_stock_box.add_child(l)
	for i in range(stock.size()):
		var e: Dictionary = stock[i]
		var key := String(e["key"])
		var price := int(e["price"])
		var sold := bool(e["sold"])
		var card_w := _p5_card_w(_meowth_panel, maxi(stock.size(), 4), 196.0) if _p5_on else 196.0
		var card_h := 238.0 if _p5_on else 160.0
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(card_w, card_h)
		b.size = Vector2(card_w, card_h)
		# 对齐定稿 S12_v1.jpg：亮紫色立体圆角卡片，彻底告别白底白字隐形灾难
		var sb_n := _style(Color("9d6ce0"), 18, Color("ebd9ff"), 2, true)
		var sb_h := _style(Color("ad7ef0"), 18, Color.WHITE, 2, true)
		var sb_p := _style(Color("8756ca"), 18, Color("d4b6ff"), 2, true)
		b.add_theme_stylebox_override("normal", sb_n)
		b.add_theme_stylebox_override("hover", sb_h)
		b.add_theme_stylebox_override("pressed", sb_p)
		b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 18, UiTheme.GOLD, 2, false))

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(margin)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 3)
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(cvb)

		var iic := _item_icon_rect(key, 60.0 if _p5_on else 44.0)
		iic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cvb.add_child(iic)

		var nm_l := Label.new()
		nm_l.text = _item_zh_name(key)
		nm_l.add_theme_font_override("font", UiTheme.display_font())
		nm_l.add_theme_font_size_override("font_size", 16)
		nm_l.add_theme_color_override("font_color", Color.WHITE)
		nm_l.add_theme_color_override("font_shadow_color", Color("481f80"))
		nm_l.add_theme_constant_override("shadow_offset_y", 2)
		nm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm_l.clip_text = true
		nm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(nm_l)

		var eff_l := Label.new()
		eff_l.text = _item_label(key)
		eff_l.add_theme_font_override("font", UiTheme.body_font())
		eff_l.add_theme_font_size_override("font_size", 13)
		eff_l.add_theme_color_override("font_color", Color("f4ebff"))
		eff_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eff_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff_l.clip_text = false
		eff_l.custom_minimum_size.y = 52
		eff_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(eff_l)

		var meta_l := Label.new()
		meta_l.text = "【%s】持有 %d/%d" % [
			String(GameData.RARITY_NAMES[GameData.item_rarity(key)]),
			player.item_count(key), GameData.item_max(key)]
		meta_l.add_theme_font_override("font", UiTheme.body_font())
		meta_l.add_theme_font_size_override("font_size", 12)
		meta_l.add_theme_color_override("font_color", Color("fff0c4"))
		meta_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(meta_l)

		var sp_push := Control.new()
		sp_push.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp_push.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(sp_push)

		# 卡底嵌入真胶囊价格标签（PanelContainer 保持 MOUSE_FILTER_IGNORE 不抢点击且完美规避小按钮检测）
		var price_pill := PanelContainer.new()
		price_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sold:
			var sold_sb := _style(Color(0.58, 0.56, 0.62, 0.90), 16, Color(0.45, 0.43, 0.48), 1, false)
			sold_sb.content_margin_left = 12
			sold_sb.content_margin_right = 12
			sold_sb.content_margin_top = 4
			sold_sb.content_margin_bottom = 4
			price_pill.add_theme_stylebox_override("panel", sold_sb)
			var sl := _mk_label(price_pill, "已售出", 14, Color.WHITE)
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			price_pill.add_theme_stylebox_override("panel", UiTheme._btn_box(UiTheme.ORANGE, 16, Color(0, 0, 0, 0.18), 1, 10))
			var phb := HBoxContainer.new()
			phb.alignment = BoxContainer.ALIGNMENT_CENTER
			phb.add_theme_constant_override("separation", 5)
			phb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price_pill.add_child(phb)
			var cic := UiIcon.new("coin", UiTheme.GOLD, 16)
			cic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			phb.add_child(cic)
			var pl := _mk_label(phb, "%d 金币" % price, 14, Color.WHITE)
			pl.add_theme_font_override("font", UiTheme.display_font())
			pl.add_theme_color_override("font_outline_color", Color("8f3905"))
			pl.add_theme_constant_override("outline_size", 3)
		cvb.add_child(price_pill)

		if sold or not player.can_hold_item(key):
			b.modulate = Color(1, 1, 1, 0.55)
		var idx := i
		b.pressed.connect(func() -> void: _shop_buy(idx))
		_shop_stock_box.add_child(b)
	var rc := _shop_reroll_cost()
	_shop_reroll_btn.text = "更新库存 · %d 金币" % rc
	_shop_reroll_btn.disabled = gold < float(rc)
	for c in _shop_sell_box.get_children():
		if c.name != "SellHead":
			c.queue_free()
	if player:
		var keys := player.items.keys()
		keys.sort()
		for k in keys:
			var key := String(k)
			var val := _sell_value(GameData.item_rarity(key))
			var sell_txt := ("确认出售 %s +%d" % [_item_zh_name(key), val]) \
				if _shop_armed_key == key else \
				("出售 %s +%d" % [_item_zh_name(key), val])
			var sb := UiTheme.make_button(sell_txt, "ghost", "small")
			sb.clip_text = false
			var sfont := sb.get_theme_font("font")
			var sfs := 15 if _p5_on else 13
			sb.add_theme_font_size_override("font_size", sfs)
			sb.custom_minimum_size.x = ceilf(sfont.get_string_size(sell_txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sfs).x) + 32.0
			sb.pressed.connect(func() -> void: _shop_sell(key))
			_shop_sell_box.add_child(sb)
	if _p5_on and _meowth_panel != null and _meowth_panel.scale.x > 0.01:
		_p5_fit(_meowth_panel, float(_meowth_panel.get_meta("p5_sm", _meowth_panel.scale.x)))

func _shop_buy(idx: int) -> void:
	var stock: Array = _shop.get("stock", [])
	if idx < 0 or idx >= stock.size():
		return
	var e: Dictionary = stock[idx]
	var key := String(e["key"])
	if bool(e["sold"]) or gold < float(int(e["price"])) or not player.can_hold_item(key):
		audio.deny()
		return
	gold -= float(int(e["price"]))
	e["sold"] = true
	stock[idx] = e
	_shop["stock"] = stock
	player.add_item(key)
	_shop_buys.append(GameData.item_rarity(key))
	audio.coin()
	_shop_refresh()

func _shop_reroll() -> void:
	var cost := _shop_reroll_cost()
	if gold < float(cost):
		audio.deny()
		return
	gold -= float(cost)
	_shop["stock"] = _shop_gen_stock()
	_shop["rerolls"] = int(_shop.get("rerolls", 0)) + 1
	_shop_rerolls_run += 1
	audio.coin()
	_shop_refresh()

## Two-tap sell (bundle showShop sell row): the first tap
## arms for 3 s, the second sells at qC(rarity).
func _shop_sell(key: String) -> void:
	var now := Time.get_ticks_msec()
	if _shop_armed_key == key and now - _shop_armed_msec <= 3000:
		_shop_armed_key = ""
		var val := _sell_value(GameData.item_rarity(key))
		player.remove_item(key)
		gold += float(val)
		audio.coin()
	else:
		_shop_armed_key = key
		_shop_armed_msec = now
		audio.click()
	_shop_refresh()

func _build_shop(root: Control) -> void:
	_meowth_panel = PanelContainer.new()
	_meowth_panel.set_anchors_preset(Control.PRESET_CENTER)
	_meowth_panel.offset_left = -430
	_meowth_panel.offset_right = 430
	_meowth_panel.offset_top = -215
	_meowth_panel.offset_bottom = 215
	_meowth_panel.visible = false
	_meowth_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_meowth_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_meowth_panel.add_child(vb)
	var mhead: Container = vb
	if _p5_on:
		# UI-mobile P5 (plan §B3 M4): head row = Meowth's line +
		# the gold in big type on the right.
		var mhb := HBoxContainer.new()
		mhb.add_theme_constant_override("separation", 12)
		vb.add_child(mhb)
		mhead = mhb
	_shop_title = _mk_dlabel(mhead, "", 28 if _p5_on else 22, UiTheme.TEXT)
	_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _p5_on:
		_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gold_box := HBoxContainer.new()
		gold_box.add_theme_constant_override("separation", 6)
		gold_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mhead.add_child(gold_box)
		var gc := UiIcon.new("coin", UiTheme.GOLD, 26)
		gc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gold_box.add_child(gc)
		_shop_gold_l = _mk_dlabel(gold_box, "", 24, UiTheme.TEXT)
		_shop_gold_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var help := _mk_label(vb, "买得太多又不开宝箱，商人下次会涨价。", 13, Color("6b4e2f"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _p5_on else HORIZONTAL_ALIGNMENT_CENTER
	_shop_stock_box = HBoxContainer.new()
	_shop_stock_box.add_theme_constant_override("separation", 10)
	_shop_stock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_shop_stock_box)
	_shop_reroll_btn = UiTheme.make_button("", "ghost", "normal" if _p5_on else "small")
	_shop_reroll_btn.pressed.connect(_shop_reroll)
	var exit_b := UiTheme.make_button("离开", "green", "big" if _p5_on else "small")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			exit_b.add_theme_color_override(st, Color.WHITE)
		exit_b.add_theme_color_override("font_outline_color", Color("326b08"))
		exit_b.add_theme_constant_override("outline_size", 4)
	exit_b.pressed.connect(_shop_close)
	_shop_sell_box = HBoxContainer.new()
	_shop_sell_box.add_theme_constant_override("separation", 6)
	_shop_sell_box.alignment = BoxContainer.ALIGNMENT_CENTER
	if _p5_on:
		# Bottom row: [更新库存] left, the sell chips scroll in the
		# middle, [离开] (primary, big green) bottom-right.
		var bot := HBoxContainer.new()
		bot.add_theme_constant_override("separation", 10)
		bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bot.alignment = BoxContainer.ALIGNMENT_END
		vb.add_child(bot)
		_shop_reroll_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		bot.add_child(_shop_reroll_btn)
		var ssc := ScrollContainer.new()
		ssc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ssc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ssc.size_flags_vertical = Control.SIZE_SHRINK_END
		bot.add_child(ssc)
		_shop_sell_box.alignment = BoxContainer.ALIGNMENT_BEGIN
		ssc.add_child(_shop_sell_box)
		var sell_head := _mk_label(_shop_sell_box, "出售你的物品：", 13, UiTheme.TEXT)
		sell_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sell_head.name = "SellHead"
		exit_b.size_flags_vertical = Control.SIZE_SHRINK_END
		exit_b.custom_minimum_size.x = 180
		exit_b.set_meta("p5_primary", true)
		bot.add_child(exit_b)
	else:
		vb.add_child(_shop_reroll_btn)
		var sell_head := _mk_label(vb, "出售你的物品：", 13, UiTheme.TEXT)
		sell_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(_shop_sell_box)
		vb.add_child(exit_b)

## ------------------------------------------------ cycle 15 choice modal
## One generic pick-1 modal in the blessing panel's idiom,
## shared by the Porygon trade and the paid chest (the
## bundle's showTrade / showItemChoice equivalents).

func _build_choice(root: Control) -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.offset_left = -430
	_choice_panel.offset_right = 430
	_choice_panel.offset_top = -190
	_choice_panel.offset_bottom = 190
	_choice_panel.visible = false
	_choice_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_choice_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_choice_panel.add_child(vb)
	var chead: Container = vb
	if _p5_on:
		# 对齐定稿 S13/S22：标题两侧配金色月桂枝，副标题同行
		var chb := HBoxContainer.new()
		chb.add_theme_constant_override("separation", 10)
		chb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(chb)
		var ll := UiTheme.art("laurel_gold", Vector2(22, 26))
		ll.flip_h = true
		chb.add_child(ll)
		_choice_title = _mk_dlabel(chb, "", 26, UiTheme.TEXT)
		var lr := UiTheme.art("laurel_gold", Vector2(22, 26))
		chb.add_child(lr)
		_choice_sub = _mk_label(chb, "", 15, Color("6e502f"))
	else:
		_choice_title = _mk_dlabel(chead, "", 24, UiTheme.TEXT)
		_choice_sub = _mk_label(chead, "", 15, Color("6e502f"))
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _p5_on:
		_choice_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_choice_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_choice_opts_box = HBoxContainer.new()
	_choice_opts_box.add_theme_constant_override("separation", 10)
	_choice_opts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_choice_opts_box)
	_choice_foot = UiTheme.make_button("", "ghost", "small")
	_choice_foot.pressed.connect(func() -> void: _choice_close(true))
	vb.add_child(_choice_foot)
	if _p5_on:
		# The primary (全部出售 / 离开) bottom-right, not full width.
		_choice_foot.size_flags_horizontal = Control.SIZE_SHRINK_END
		_choice_foot.custom_minimum_size.x = 200
		_choice_foot.set_meta("p5_primary", true)

var _choice_name_to_key: Dictionary = {}

## 根据选项文本首行名称反查物品键名，用于 S13 宝箱与 S22 拟态团在紫卡内自动挂载实体道具图标
func _choice_item_key_for_option(text: String) -> String:
	if _choice_name_to_key.is_empty():
		for k in GameData.item_keys():
			var ks := String(k)
			_choice_name_to_key[_item_zh_name(ks)] = ks
			var raw_nm := String(GameData.item_def(ks).get("name", ""))
			if raw_nm != "":
				_choice_name_to_key[raw_nm] = ks
	var first_line := text.split("\n", true, 1)[0].strip_edges()
	return String(_choice_name_to_key.get(first_line, ""))

func _choice_show(title: String, sub: String, options: Array, foot_text: String, on_pick: Callable, on_close: Callable) -> void:
	_choice_return = state
	_choice_on_pick = on_pick
	_choice_on_close = on_close
	_choice_open = true
	state = "choice"
	running = false
	_choice_title.text = title
	_choice_sub.text = sub
	for c in _choice_opts_box.get_children():
		c.queue_free()
	for i in range(options.size()):
		# 对齐定稿 S13/S21/S22：亮紫渐层圆角立体卡片＋物品大图＋深紫白字阴影，彻底消灭白底白字隐形
		var opt_text := String(options[i])
		var item_key := _choice_item_key_for_option(opt_text)
		var b := Button.new()
		b.text = ""
		var cw := _p5_card_w(_choice_panel, options.size(), 240.0) if _p5_on else 200.0
		var ch := 214.0 if _p5_on else 120.0
		b.custom_minimum_size = Vector2(cw, ch)
		b.size = Vector2(cw, ch)
		b.add_theme_stylebox_override("normal", _style(Color("9d6ce0"), 18, Color("ebd9ff"), 2, true))
		b.add_theme_stylebox_override("hover", _style(Color("ad7ef0"), 18, Color.WHITE, 2, true))
		b.add_theme_stylebox_override("pressed", _style(Color("8756ca"), 18, Color("d4b6ff"), 2, true))
		b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 18, UiTheme.GOLD, 2, false))
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(margin)
		var cvb := VBoxContainer.new()
		cvb.alignment = BoxContainer.ALIGNMENT_CENTER
		cvb.add_theme_constant_override("separation", 6)
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(cvb)
		if item_key != "":
			var ic := _item_icon_rect(item_key, 56.0 if _p5_on else 36.0)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cvb.add_child(ic)
		elif title == "流光队友" and (is_instance_valid(_shiny_ally) or is_instance_valid(_pending_shiny_ally)):
			# 对齐定稿 S24_v1.jpg：左侧「留下新队友」配新流光头像，右侧「放生新队友」配当前队伍旧流光头像
			var sp_ally := String(_pending_shiny_ally.species_id) if (i == 0 and is_instance_valid(_pending_shiny_ally)) else (String(_shiny_ally.species_id) if is_instance_valid(_shiny_ally) else "")
			if sp_ally != "" and UiTheme.portrait(sp_ally) != null:
				var ptr := TextureRect.new()
				ptr.texture = UiTheme.portrait(sp_ally)
				ptr.custom_minimum_size = Vector2(88, 88) if _p5_on else Vector2(48, 48)
				ptr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ptr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ptr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				ptr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cvb.add_child(ptr)
		var l := Label.new()
		l.text = opt_text
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_override("font", UiTheme.body_font())
		l.add_theme_font_size_override("font_size", 15 if _p5_on else 14)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_shadow_color", Color("481f80"))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(l)
		var idx := i
		b.pressed.connect(func() -> void: _choice_pick(idx))
		_choice_opts_box.add_child(b)
	_choice_foot.visible = foot_text != ""
	_choice_foot.text = foot_text
	_choice_panel.visible = true

func _choice_pick(idx: int) -> void:
	if not _choice_open:
		return
	audio.power()  # cycle 16: modal pick
	var cb := _choice_on_pick
	_choice_close(false)
	if cb.is_valid():
		cb.call(idx)

func _choice_close(via_foot: bool) -> void:
	if not _choice_open:
		return
	_choice_panel.visible = false
	_choice_open = false
	state = _choice_return
	running = true
	if via_foot and _choice_on_close.is_valid():
		_choice_on_close.call()
	# Cycle 21: deferred item rolls (bundle whenFree).
	if not _pending_item_rolls.is_empty():
		var nxt: Array = _pending_item_rolls.pop_front()
		_roll_chest_item(int(nxt[0]), int(nxt[1]))

## Cycle 21: ice-heal shatter (bundle damage() @724834):
## popup + burst, and every OTHER living enemy within
## 2.5 u takes the freeze (our chain's 2 s splash freeze,
## the same duration the shatter reaction uses).
func ice_shatter(src: Node) -> void:
	if src == null or not is_instance_valid(src):
		return
	var c: Vector3 = src.global_position
	spawn_floater(c + Vector3(0, 2.4, 0), "冰碎！", Color(0.6, 0.9, 1.0))
	spawn_nova(c + Vector3(0, 0.6, 0), 2.5, Color(0.6, 0.9, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == src or not is_instance_valid(e) or e.hp <= 0.0:
			continue
		if e.global_position.distance_to(c) <= 2.5:
			e.apply_status("freeze", 2.0)

## ------------------------------------------------ cycle 21: boss brain
## The bundle's Nb boss class (@994812-~1011000), ported
## onto the guardian: the move cycle (timer x1.35 enraged,
## alternating signature/mech slots via sigNext), enrage
## at Ze.fury (C23 run-tier ladder), mid-fight escort calls, impatience,
## the far-leap rule, and the eight generic moves with
## their bundle numbers. tk = Ze.tele[run_tier].

const BOSS_MOVE_NAMES := {"volley": "弹幕齐射", "wave": "冲击波",
	"spiral": "旋转弹幕", "meteor": "陨星坠落", "pools": "敌意领域"}
const BOSS_SIG := {
	"scyther": {"kind": "cross", "name": "十字剪", "color": 13172570},
	"pinsir": {"kind": "leap", "name": "地震", "color": 13150328},
	"sandslash": {"kind": "cross", "name": "狂暴抓", "color": 15253616},
	"marowak": {"kind": "cross", "name": "骨头回力镖", "color": 15788248},
	"dragonite": {"kind": "charge", "name": "龙之冲锋", "color": 9075455},
}
## db mech assignment (bundle fb @966257). Cycle 22
## correction: the mech dispatch (@996446) attaches the
## gb classes (gengar 94, marowak 105) ONLY when
## run.tower exists — tower is a separate game mode
## (mode==='tower' @1441046) this port does not have.
## In stage play fb() reads db, which has NO gengar and
## NO marowak entry: stage gengar fights on generic
## moves alone (no Pb entry either), and marowak runs
## its Pb signature above. Cycle 21's gengar double-team
## was the TOWER class's phase 1 misapplied to stage
## play — removed (DIFF §22; the tower classes are fully
## mined there for a future tower mode).
const BOSS_MECH := {"kingler": "kingler", "gyarados": "gyarados",
	"starmie": "starmie", "dewgong": "dewgong", "cloyster": "cloyster",
	"lapras": "lapras", "hypno": "hypno"}
const BOSS_MECH_NAMES := {"kingler": "钳之守卫", "gyarados": "漩涡·破坏光线",
	"starmie": "高速旋转", "dewgong": "冰之滑行", "cloyster": "尖刺炮",
	"lapras": "冰柱林", "hypno": "催眠摆"}
var _boss_t := 2.5
var _boss_sig_next := false
var _boss_enraged := false
var _boss_last := ""
var _boss_move_name := ""
var _boss_move_t := 0.0
var _boss_call_t := 1.5
var _boss_far_t := 0.0
var _boss_hold_t := 0.0
var _boss_charge: Dictionary = {}
var _boss_waves: Array = []
var _boss_pools: Array = []
var _boss_pool_hurt_t := 0.0
var _boss_spiral: Dictionary = {}
var _boss_mech := ""
var _boss_mech_data: Dictionary = {}
var _boss_impatient := false
var _boss_escorts: Array = []
var _hostiles: Array = []
var _hostile_mesh: SphereMesh
var _hostile_mats: Dictionary = {}

func _boss_col(c: int) -> Color:
	return Color(float((c >> 16) & 255) / 255.0, float((c >> 8) & 255) / 255.0, float(c & 255) / 255.0)

func _boss_reset() -> void:
	_boss_t = 2.5
	_boss_sig_next = false
	_boss_enraged = false
	_boss_last = ""
	_boss_move_name = ""
	_boss_move_t = 0.0
	_boss_call_t = 1.5
	_boss_far_t = 0.0
	_boss_hold_t = 0.0
	_boss_charge = {}
	_boss_waves.clear()
	_boss_pools.clear()
	_boss_spiral = {}
	_boss_impatient = false
	_boss_escorts.clear()
	_boss_mech = String(BOSS_MECH.get(guardian.species_id, "")) if guardian else ""
	_boss_mech_data = {}
	if _boss_mech == "gyarados":
		_boss_mech_data = {"next": "pool", "recharge": 0.0, "beam": {}}
	elif _boss_mech == "kingler":
		_boss_mech_data = {"guard_t": 0.0, "counter_cd": 0.0, "facing": Vector2(0, 1)}
	elif _boss_mech == "cloyster":
		# Bundle: open=false, phase=3 (first toggle at 3 s).
		_boss_mech_data = {"open": false, "phase": 3.0}
	elif _boss_mech == "starmie":
		_boss_mech_data = {"dizzy": 0.0, "path": [], "run": {}}
	elif _boss_mech == "dewgong":
		_boss_mech_data = {"slide": {}, "trails": [], "pending": 0}
	elif _boss_mech == "lapras":
		_boss_mech_data = {"pillars": [], "wave": {}}
	elif _boss_mech == "hypno":
		_boss_mech_data = {"swing": {}, "drowsy": 0.0, "dtick": 0.0}

func _boss_say(nm: String) -> void:
	_boss_move_name = nm
	_boss_move_t = 2.2

func _boss_strike(mul: float, shove_dir := Vector2.ZERO, shove_pow := 0.0, floor_frac: float = 0.08) -> bool:
	if guardian == null or not is_instance_valid(guardian) or player == null or not is_instance_valid(player):
		return false
	var landed := miniboss_strike(guardian, mul, floor_frac)
	if landed and shove_pow > 0.0 and player.hp > 0.0:
		var v: Vector3 = player.get("_vel")
		player.set("_vel", v + Vector3(shove_dir.x, 0, shove_dir.y) * shove_pow)
	return landed

func _boss_low(limit := 1.8) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return player.global_position.y - height_at(player.global_position.x, player.global_position.z) < limit

func _boss_shot(angle: float, speed: float, dmg_mul: float, life := 3.0, col := Color(1, 0.6, 0.4)) -> void:
	if guardian == null or not is_instance_valid(guardian):
		return
	if _hostile_mesh == null:
		_hostile_mesh = SphereMesh.new()
		_hostile_mesh.radius = 0.3
		_hostile_mesh.height = 0.6
		_hostile_mesh.radial_segments = 10
		_hostile_mesh.rings = 6
	var key := str(col.to_rgba32())
	if not _hostile_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.6
		_hostile_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _hostile_mesh
	mi.material_override = _hostile_mats[key]
	add_child(mi)
	var from: Vector3 = guardian.global_position + Vector3(0, 1.2, 0)
	mi.global_position = from
	_hostiles.append({"node": mi, "vel": Vector3(cos(angle), 0, sin(angle)) * speed,
		"dmg": guardian.dmg * dmg_mul, "life": life, "capped": true,
		"alpha": false, "radius": 0.6, "attacker": guardian, "type": String(guardian.types[0]) if not guardian.types.is_empty() else ""})

func _boss_telegraph_strike(pos: Vector3, radius: float, delay: float, dmg_mul: float, col: Color) -> void:
	spawn_nova(Vector3(pos.x, height_at(pos.x, pos.z) + 0.4, pos.z), radius, col)
	var g := guardian
	_later(delay, func() -> void:
		if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null or not is_instance_valid(player):
			return
		spawn_nova(Vector3(pos.x, height_at(pos.x, pos.z) + 0.4, pos.z), radius * 0.7, col)
		audio.boom()
		var d := Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z)
		if d.length() < radius and _boss_low(2.0):
			_boss_strike(dmg_mul))

func _boss_shards(n: int, col: Color, dmg_mul := 0.7) -> void:
	if guardian == null or not is_instance_valid(guardian):
		return
	for i in range(n):
		_boss_shot(float(i) / float(n) * TAU, 11.0, dmg_mul, 2.2, col)

func _boss_start_charge(dir: Vector2, speed: float, dur: float, mul: float, chain: Callable) -> void:
	_boss_charge = {"dx": dir.x, "dz": dir.y, "speed": speed, "t": dur,
		"mul": mul, "hit": false, "chain": chain}
	audio.whoosh()

## Cycle 22: ub.segDist — the player's distance to a
## ground segment (dewgong trails, lapras pump, hypno).
func _seg_dist(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var abx := bx - ax
	var abz := bz - az
	var len2 := abx * abx + abz * abz
	var t := 0.0
	if len2 > 0.001:
		t = clampf(((px - ax) * abx + (pz - az) * abz) / len2, 0.0, 1.0)
	var cx := ax + abx * t
	var cz := az + abz * t
	return Vector2(px - cx, pz - cz).length()

## Cycle 22: ub.strip — a purely visual ground telegraph
## along a segment (discs in the bundle; our nova rings
## at intervals, the same primitive _boss_telegraph_strike
## uses for spots).
func _telegraph_line(a: Vector2, b: Vector2, col: Color) -> void:
	var len := a.distance_to(b)
	var steps := maxi(1, int(len / 2.4))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		spawn_nova(Vector3(p.x, height_at(p.x, p.y) + 0.25, p.y), 1.15, col)

func _boss_line_strike(a: Vector2, b: Vector2, width: float, delay: float, dmg_mul: float, col: Color) -> void:
	var mid := (a + b) * 0.5
	spawn_nova(Vector3(mid.x, height_at(mid.x, mid.y) + 0.4, mid.y), (b - a).length() * 0.5, col)
	var g := guardian
	_later(delay, func() -> void:
		if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null or not is_instance_valid(player):
			return
		var ab := b - a
		var len2 := ab.length_squared()
		var tt := 0.0
		if len2 > 0.001:
			tt = clampf((Vector2(player.global_position.x, player.global_position.z) - a).dot(ab) / len2, 0.0, 1.0)
		var closest := a + ab * tt
		if Vector2(player.global_position.x, player.global_position.z).distance_to(closest) < width + 0.5 and _boss_low(1.8):
			_boss_strike(dmg_mul))

## The mech hitMul hook (enemy.take_damage calls this for
## the guardian). Popups ride the bundle's pop() texts.
func boss_hit_mul(_e: Enemy) -> float:
	if guardian == null or not is_instance_valid(guardian) or _boss_mech == "":
		return 1.0
	match _boss_mech:
		"kingler":
			if float(_boss_mech_data.get("guard_t", 0.0)) > 0.0 and player:
				var facing: Vector2 = _boss_mech_data.get("facing", Vector2(0, 1))
				var to_p := Vector2(player.global_position.x - guardian.global_position.x,
					player.global_position.z - guardian.global_position.z).normalized()
				var d := facing.dot(to_p)
				if d > 0.3:
					spawn_floater(guardian.global_position + Vector3(0, 3.0, 0), "格挡！", Color(0.78, 0.85, 0.91))
					return 0.15
				if d < -0.25:
					spawn_floater(guardian.global_position + Vector3(0, 3.0, 0), "背刺！", Color(1.0, 0.89, 0.23))
					return 1.6
			return 1.0
		"gyarados":
			if float(_boss_mech_data.get("recharge", 0.0)) > 0.0:
				return 1.5
			return 1.0
		"cloyster":
			return 1.9 if bool(_boss_mech_data.get("open", false)) else 0.1
		"starmie":
			return 1.8 if float(_boss_mech_data.get("dizzy", 0.0)) > 0.0 else 1.0
	return 1.0

## ---- boss moves (bundle Nb, numbers verbatim) ----
func _boss_to_player() -> Vector2:
	if guardian == null or player == null:
		return Vector2(0, 1)
	var d := Vector2(player.global_position.x - guardian.global_position.x,
		player.global_position.z - guardian.global_position.z)
	return d.normalized() if d.length() > 0.01 else Vector2(0, 1)

func _boss_move_slams() -> float:
	var enr := _boss_enraged
	var g := guardian
	var do_set := func() -> void:
		if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null:
			return
		var pv: Vector3 = player.get("_vel")
		for l in range(3):
			var off := Vector2(pv.x, pv.z) * 0.8 if l == 0 else Vector2(_bless_rng.randf_range(-7, 7), _bless_rng.randf_range(-7, 7))
			_boss_telegraph_strike(player.global_position + Vector3(off.x, 0, off.y), 3.6, 1.1 * tier_value("tele"), 1.6, Color(1, 0.3, 0.25))
	do_set.call()
	if enr:
		_later(0.7, do_set)
	return 3.8 if enr else 3.0

func _boss_move_ring() -> float:
	var enr := _boss_enraged
	var shots := 18 if enr else 14
	var waves_n := 3 if enr else 1
	var base_ang := _bless_rng.randf()
	var g := guardian
	spawn_nova(guardian.global_position + Vector3(0, 0.4, 0), 3.0, Color(1, 0.6, 0.3))
	for s in range(waves_n):
		_later(0.4 + float(s) * 0.5, func() -> void:
			if g == null or not is_instance_valid(g) or g.hp <= 0.0:
				return
			for i in range(shots):
				_boss_shot(base_ang + (float(i) + float(s) * 0.5) / float(shots) * TAU, 10.0, 0.8, 4.0, Color(1, 0.62, 0.3))
			audio.shot("fire"))
	return 2.8 + float(waves_n - 1) * 0.4

func _boss_move_charge() -> float:
	var enr := _boss_enraged
	var dir := _boss_to_player()
	_boss_hold_t = maxf(_boss_hold_t, 0.75 * tier_value("tele"))
	_later(0.75 * tier_value("tele"), func() -> void:
		if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
			return
		_boss_start_charge(dir, 30.0, 0.75, 1.5,
			func() -> void:
				if enr and guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
					_boss_start_charge(_boss_to_player(), 30.0, 0.75, 1.5, Callable())))
	return 4.4 if enr else 3.2

func _boss_move_volley() -> float:
	var enr := _boss_enraged
	var bursts := 4 if enr else 3
	var g := guardian
	var gc := _boss_type_color()
	for i in range(bursts):
		_later((0.45 + float(i) * 0.4) * tier_value("tele"), func() -> void:
			if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null:
				return
			var pv: Vector3 = player.get("_vel")
			var tp := Vector2(player.global_position.x + pv.x * 0.5, player.global_position.z + pv.z * 0.5)
			var base := atan2(tp.y - g.global_position.z, tp.x - g.global_position.x)
			for k in range(-2, 3):
				_boss_shot(base + float(k) * 0.17, 15.0, 0.6, 3.0, gc))
	return 2.6 + float(bursts) * 0.2

func _boss_type_color() -> Color:
	if guardian == null:
		return Color(1, 0.6, 0.3)
	var types: Array = GameData.species(guardian.species_id).get("types", [])
	if types.is_empty():
		return Color(1, 0.6, 0.3)
	return UiTheme.type_color(String(types[0]))

func _boss_move_wave() -> float:
	var enr := _boss_enraged
	var n := 3 if enr else 2
	_boss_hold_t = maxf(_boss_hold_t, 0.8 * tier_value("tele") + float(n) * 0.55)
	var g := guardian
	for i in range(n):
		_later(0.8 * tier_value("tele") + float(i) * 0.55, func() -> void:
			if g == null or not is_instance_valid(g) or g.hp <= 0.0:
				return
			_boss_waves.append({"x": g.global_position.x, "z": g.global_position.z,
				"r": g.radius + 0.5, "max": 26.0, "hit": false, "col": Color(1, 0.55, 0.2), "fx_t": 0.0})
			audio.boom())
	return 3.0 + float(n) * 0.3

func _boss_move_spiral() -> float:
	_boss_hold_t = maxf(_boss_hold_t, 3.2)
	_later(0.6, func() -> void:
		if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
			return
		_boss_spiral = {"t": 2.6, "a": _bless_rng.randf() * TAU, "acc": 0.0,
			"arms": 3, "spin": (1.9 if _bless_rng.randf() < 0.5 else -1.9)})
	return 3.8

func _boss_move_meteor() -> float:
	var count := 8 + zone * 2
	var g := guardian
	for i in range(count):
		_later(float(i) * 0.2, func() -> void:
			if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null:
				return
			var tp := player.global_position
			if i % 3 == 0:
				var pv: Vector3 = player.get("_vel")
				tp += Vector3(pv.x * 0.9, 0, pv.z * 0.9)
			else:
				tp += Vector3(_bless_rng.randf_range(-9, 9), 0, _bless_rng.randf_range(-9, 9))
			_boss_telegraph_strike(tp, 2.6, 1.1 * tier_value("tele"), 1.2, Color(1, 0.5, 0.25)))
	return 2.4 + float(count) * 0.12

func _boss_move_pools() -> float:
	if player == null:
		return 2.8
	for i in range(3):
		var tp := player.global_position
		if i > 0:
			tp += Vector3(_bless_rng.randf_range(-6, 6), 0, _bless_rng.randf_range(-6, 6))
		var px := tp.x
		var pz := tp.z
		var col := Color(0.65, 0.3, 0.9)
		_boss_telegraph_strike(tp, 3.4, tier_value("tele"), 0.0, col)
		var g := guardian
		_later(tier_value("tele"), func() -> void:
			if g == null or not is_instance_valid(g) or g.hp <= 0.0:
				return
			# The bundle strikes 1.0 on pool spawn when the
			# player stands in the telegraph.
			if player and Vector2(player.global_position.x - px, player.global_position.z - pz).length() < 3.4 and _boss_low(2.0):
				_boss_strike(1.0)
			_boss_pools.append({"x": px, "z": pz, "r": 3.1, "t": 6.0, "col": col, "vortex": false}))
	return 2.8

## ---- signatures (Pb kinds over the shared impls) ----
func _boss_sig_cross(sig: Dictionary) -> float:
	var enr := _boss_enraged
	var col := _boss_col(int(sig["color"]))
	var center := Vector2(player.global_position.x, player.global_position.z)
	var base := _bless_rng.randf_range(0.0, PI * 0.5)
	var angs := [PI * 0.25, -PI * 0.25, PI * 0.5] if enr else [PI * 0.25, -PI * 0.25]
	for i in range(angs.size()):
		var a := base + float(angs[i])
		var dir := Vector2(cos(a), sin(a))
		_boss_line_strike(center - dir * 10.0, center + dir * 10.0, 1.3,
			(1.05 + float(i) * 0.2) * tier_value("tele"), 1.2, col)
	_later((1.2 + (0.2 if enr else 0.0)) * tier_value("tele"), func() -> void:
		if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
			return
		var d := center - Vector2(guardian.global_position.x, guardian.global_position.z)
		var dist := d.length()
		_boss_start_charge(d.normalized() if dist > 0.01 else Vector2(0, 1), 34.0,
			minf(0.7, (dist + 4.0) / 34.0), 1.2,
			func() -> void:
				if enr:
					_boss_shards(10, col)))
	return 3.8 if enr else 3.2

func _boss_sig_leap(sig: Dictionary) -> float:
	var enr := _boss_enraged
	var col := _boss_col(int(sig["color"]))
	var target := Vector2(player.global_position.x, player.global_position.z)
	var delay := 1.07 * tier_value("tele")
	_boss_hold_t = maxf(_boss_hold_t, delay)
	_boss_telegraph_strike(Vector3(target.x, 0, target.y), 5.0, delay, 0.0, col)
	var g := guardian
	_later(delay, func() -> void:
		if g == null or not is_instance_valid(g) or g.hp <= 0.0 or player == null:
			return
		g.global_position = Vector3(target.x, height_at(target.x, target.y), target.y)
		spawn_nova(g.global_position + Vector3(0, 0.4, 0), 5.0, col)
		audio.boom()
		if Vector2(player.global_position.x - target.x, player.global_position.z - target.y).length() < 5.0 and _boss_low(2.2):
			_boss_strike(1.8)
		_boss_shards(12, col)
		if enr:
			_boss_waves.append({"x": target.x, "z": target.y, "r": 5.0, "max": 24.0,
				"hit": false, "col": col, "fx_t": 0.0}))
	return 3.8 if enr else 3.4

func _boss_sig_charge(sig: Dictionary) -> float:
	var enr := _boss_enraged
	var col := _boss_col(int(sig["color"]))
	var dir := _boss_to_player()
	var dist := 0.0
	if guardian and player:
		dist = Vector2(player.global_position.x - guardian.global_position.x,
			player.global_position.z - guardian.global_position.z).length()
	var len := minf(30.0, dist + 8.0)
	var from := Vector2(guardian.global_position.x, guardian.global_position.z)
	_boss_line_strike(from, from + dir * len, 1.8, 0.8 * tier_value("tele"), 0.0, col)
	_boss_hold_t = maxf(_boss_hold_t, 0.8 * tier_value("tele"))
	_later(0.8 * tier_value("tele"), func() -> void:
		if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
			return
		_boss_start_charge(dir, 42.0, len / 42.0, 2.2,
			func() -> void:
				if enr and guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
					_boss_shards(8, col)
					_boss_start_charge(_boss_to_player(), 42.0, len / 42.0, 2.2, Callable())))
	return 4.6 if enr else 3.0

## ---- mech casts (db classes; fidelity per class in DIFF §21) ----
func _boss_mech_cast() -> float:
	var enr := _boss_enraged
	match _boss_mech:
		"kingler":
			var guard := 4.0 if enr else 3.2
			_boss_mech_data["guard_t"] = guard
			_boss_mech_data["facing"] = _boss_to_player()
			_boss_hold_t = maxf(_boss_hold_t, guard + 0.2)
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "守卫！", Color(1, 0.69, 0.54))
			_later(guard, func() -> void: _boss_kingler_hammer(enr))
			return guard + 2.6
		"gyarados":
			var nxt := String(_boss_mech_data.get("next", "pool"))
			_boss_mech_data["next"] = "beam" if nxt == "pool" else "pool"
			if nxt == "pool":
				var n := 3 if enr else 2
				for i in range(n):
					var ang := _bless_rng.randf() * TAU
					var dist := _bless_rng.randf_range(5.0, 9.0)
					var px := player.global_position.x + cos(ang) * dist
					var pz := player.global_position.z + sin(ang) * dist
					_boss_telegraph_strike(Vector3(px, 0, pz), 5.5, 0.9, 0.0, Color(0.29, 0.55, 1.0))
					_later(0.9, func() -> void:
						if guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
							_boss_pools.append({"x": px, "z": pz, "r": 5.5, "t": 7.0,
								"col": Color(0.29, 0.55, 1.0), "vortex": true}))
				spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "漩涡！", Color(0.42, 0.72, 1.0))
				return 3.2
			# hyper beam: sweep, one strike, then recharge.
			_boss_hold_t = maxf(_boss_hold_t, 4.2)
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "龙之舞！", Color(0.54, 0.48, 1.0))
			var dir0 := _boss_to_player()
			var a0 := atan2(dir0.y, dir0.x) - (1.75 if _bless_rng.randf() < 0.5 else -1.75)
			var sdir := 1.0 if a0 < atan2(dir0.y, dir0.x) else -1.0
			_later(1.3 * tier_value("tele"), func() -> void:
				if guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
					_boss_mech_data["beam"] = {"t": 1.8 if enr else 2.2, "a0": a0, "dir": sdir, "hit": false, "dur": 1.8 if enr else 2.2})
			return 6.0
		"cloyster":
			if bool(_boss_mech_data.get("open", false)):
				return 1.0
			var n := 4 if enr else 3
			var g := guardian
			for i in range(n):
				var vi := i
				_later(float(i) * 0.45, func() -> void:
					if g == null or not is_instance_valid(g) or g.hp <= 0.0:
						return
					# Bundle: the ring's base angle is the
					# volley index x .11 (not random).
					var base := float(vi) * 0.11
					for k in range(14):
						_boss_shot(base + float(k) / 14.0 * TAU, 11.0, 0.6, 3.0, Color(0.75, 0.9, 1.0))
					var aim := _boss_to_player()
					var aa := atan2(aim.y, aim.x)
					for k in range(-1, 2):
						_boss_shot(aa + float(k) * 0.12, 16.0, 0.7, 2.5, Color(0.75, 0.9, 1.0))
					audio.shot("ice"))
			return 2.8
		"starmie":
			# Cycle 22: the true reflecting path (db class
			# 121, mined in full). Centre = the player's
			# position; the start point clamps onto the
			# r=14 circle around it; each leg solves the
			# r=15 circle exit, reflects the direction off
			# the circle normal, then jitters it by up to
			# .35 rad. Legs: 6 enraged / 4 normal.
			var legs := 6 if enr else 4
			var c := Vector2(player.global_position.x, player.global_position.z)
			var bp := Vector2(guardian.global_position.x, guardian.global_position.z)
			var start := bp
			if start.distance_to(c) > 14.0:
				start = c + (start - c).normalized() * 14.0
			var dir := _boss_to_player()
			var path: Array = [start]
			var cur := start
			for li in range(legs):
				var e := cur - c
				var n := e.dot(dir)
				var rr := e.length_squared() - 225.0
				var o := -n + sqrt(maxf(0.0, n * n - rr))
				cur = cur + dir * o
				path.append(cur)
				var nrm := (cur - c) / 15.0
				dir = dir - 2.0 * dir.dot(nrm) * nrm
				dir = dir.rotated(_bless_rng.randf_range(-0.35, 0.35))
			_boss_mech_data["path"] = path
			var u := 1.2 * tier_value("tele")
			for li in range(path.size() - 1):
				_telegraph_line(path[li], path[li + 1],
					_boss_col(16747224) if li % 2 == 1 else _boss_col(16765034))
			_boss_mech_data["pending"] = true
			_boss_hold_t = maxf(_boss_hold_t, u + 3.0)
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "高速旋转！", Color(1, 0.82, 0.42))
			_later(u, func() -> void:
				if guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
					_boss_mech_data["pending"] = false
					_boss_mech_data["run"] = {"k": 0, "s": 0.0, "hit": false}
					audio.whoosh())
			# C22 estimated cooldown retained; C23 F1 gates dispatch
			# on actual occupancy as this clock may run up to x1.89.
			var travel := 0.0
			for li in range(path.size() - 1):
				travel += (path[li] as Vector2).distance_to(path[li + 1])
			return u + travel / 26.0 + 2.5 + 0.3
		"dewgong":
			# Cycle 22: the true slide chain (db class 87):
			# each slide is telegraphed .65tk, runs at
			# 22 u/s for min(24, dist+7), and leaves a
			# 6 s ice TRAIL segment (slip + a 1.2 s burst).
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "冰之滑行！", Color(0.6, 0.91, 1.0))
			_boss_dewgong_next(4 if enr else 3, enr)
			return 6.4 if enr else 5.2
		"lapras":
			# Cycle 22: the true cast (db class 131):
			# 5 (enr 7) ice pillars lobbed onto a r=4.6
			# ring around the player — real attackable
			# OBJECTS (hp = 1.2% of the boss's max), 9 s
			# life — then hydro pump at +1.8 s (the
			# pillars BLOCK it) and surf at +5 s (the
			# wave breaks them).
			var n := 7 if enr else 5
			var base_a := _bless_rng.randf() * TAU
			for i in range(n):
				var px := player.global_position.x + cos(base_a + float(i) / float(n) * TAU) * 4.6
				var pz := player.global_position.z + sin(base_a + float(i) / float(n) * TAU) * 4.6
				if absf(px) > BOUND - 3.0 or absf(pz) > BOUND - 3.0:
					continue
				var land := 0.6 + float(i) * 0.08
				spawn_nova(Vector3(px, height_at(px, pz) + 0.3, pz), 1.4, Color(0.6, 0.9, 1.0))
				_later(land, func() -> void:
					if guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
						_boss_lapras_pillar(px, pz))
			_boss_hold_t = maxf(_boss_hold_t, 1.6)
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "冰柱林！", Color(0.61, 0.91, 1.0))
			_later(1.8, func() -> void: _boss_lapras_pump())
			_later(5.0, func() -> void: _boss_lapras_surf())
			return 7.5
		"hypno":
			# Pendulum field; landed sleep triggers dream eater (Cycle 22).
			_boss_mech_data["swing"] = {"t": 6.5 if enr else 5.0,
				"base": atan2(_boss_to_player().y, _boss_to_player().x), "rage": enr}
			_boss_hold_t = maxf(_boss_hold_t, 6.5 if enr else 5.0)
			spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "催眠摆！", Color(0.78, 0.66, 1.0))
			return (6.5 if enr else 5.0) + 1.5
	return 3.0

## Cycle 22: hypno's dream eater — on a landed sleep it
## teleports to the player's side, and .8 s later strikes
## 1.4; if the strike lands (the player's HP actually
## drops), hypno heals 4% of its max HP (bundle
## dreamEater @db+15760).
func _boss_hypno_dream_eat() -> void:
	if guardian == null or not is_instance_valid(guardian) or player == null:
		return
	_boss_mech_data["swing"] = {}
	_boss_hold_t = maxf(_boss_hold_t, 1.4)
	var ang := _bless_rng.randf() * TAU
	var pos := player.global_position + Vector3(cos(ang) * 2.5, 0, sin(ang) * 2.5)
	pos.x = clampf(pos.x, -BOUND + 2.0, BOUND - 2.0)
	pos.z = clampf(pos.z, -BOUND + 2.0, BOUND - 2.0)
	pos.y = height_at(pos.x, pos.z)
	guardian.global_position = pos
	spawn_nova(pos + Vector3(0, 0.5, 0), 3.0, Color(0.78, 0.66, 1.0))
	spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "梦食！", Color(0.78, 0.66, 1.0))
	_later(0.8, func() -> void:
		if guardian and is_instance_valid(guardian) and guardian.hp > 0.0 and player and player.hp > 0.0:
			var before := player.hp
			_boss_strike(1.4)
			if player.hp < before - 0.01:
				guardian.hp = minf(guardian.max_hp, guardian.hp + guardian.max_hp * 0.04)
				spawn_floater(guardian.global_position + Vector3(0, 3.4, 0), "+4% 回复", Color(0.55, 0.95, 0.5)))

func _boss_kingler_hammer(enr: bool) -> void:
	if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
		return
	var facing: Vector2 = _boss_mech_data.get("facing", Vector2(0, 1))
	var lanes := [0.0, -0.45, 0.45] if enr else [0.0]
	var base_ang := atan2(facing.y, facing.x)
	for lane in lanes:
		for n in range(6):
			var dist := 3.0 + float(n) * 3.0
			var px := guardian.global_position.x + cos(base_ang + float(lane)) * dist
			var pz := guardian.global_position.z + sin(base_ang + float(lane)) * dist
			_boss_telegraph_strike(Vector3(px, 0, pz), 2.2, (0.7 + float(n) * 0.12) * tier_value("tele"), 1.2, Color(0.4, 0.75, 0.85))

## Cycle 22: dewgong's next() — telegraph the slide line
## (.65tk), hold for the slide's duration, then start the
## slide state the mech tick drives. Slides chain with a
## .35 s gap (the tick starts the next one).
func _boss_dewgong_next(count: int, rage: bool) -> void:
	if count <= 0 or guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
		return
	_boss_mech_data["pending"] = count
	var dir := _boss_to_player()
	var bp := Vector2(guardian.global_position.x, guardian.global_position.z)
	var dist := Vector2(player.global_position.x, player.global_position.z).distance_to(bp) if player else 0.0
	var r := minf(24.0, dist + 7.0)
	var i := 0.65 * tier_value("tele")
	_telegraph_line(bp, bp + dir * r, Color(0.62, 0.89, 1.0))
	_boss_hold_t = maxf(_boss_hold_t, i + r / 22.0 + 0.55)
	_later(i, func() -> void:
		if guardian and is_instance_valid(guardian) and guardian.hp > 0.0:
			_boss_mech_data["slide"] = {"t": r / 22.0, "dx": dir.x, "dz": dir.y,
				"left": count - 1, "rage": rage, "hit": false,
				"ax": guardian.global_position.x, "az": guardian.global_position.z}
			audio.whoosh())

## Cycle 22: a lapras ice pillar — a real Enemy body with
## the Object flag (bundle obj(): hp = 1.2% of the boss's
## max, dmg 0, speed 0, radius 1), wearing an ice shard
## mesh instead of the species rig (the bundle hangs a
## separate frost_pillar model on the object).
func _boss_lapras_pillar(px: float, pz: float) -> void:
	var pos := Vector3(px, 0, pz)
	pos.y = height_at(px, pz)
	# The pillar body needs a MODELLED donor species (the
	# rig table has no lapras entry — unmodelled species
	# are never spawned as enemies anywhere in the port);
	# the rig is hidden and the identity overridden.
	var e := _spawn_enemy_at("bulbasaur", pos, 1.0, false, 1.0)
	e.species_id = "lapras"
	e.types = ["ice"]
	e.is_object = true
	e.max_hp = maxf(1.0, guardian.max_hp * 0.012)
	e.hp = e.max_hp
	e.dmg = 0.0
	e.speed = 0.0
	e.radius = 1.0
	if e.rig:
		e.rig.visible = false
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.85
	cm.height = 3.4
	cm.radial_segments = 7
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	mi.position = Vector3(0, 1.7, 0)
	e.add_child(mi)
	spawn_nova(pos + Vector3(0, 0.5, 0), 1.6, Color(0.78, 0.92, 1.0))
	audio.shot("ice")
	var pillars: Array = _boss_mech_data.get("pillars", [])
	pillars.append({"e": e, "x": px, "z": pz, "t": 9.0})
	_boss_mech_data["pillars"] = pillars

func _boss_lapras_kill_pillar(rec: Dictionary) -> void:
	var pev = rec.get("e")
	if pev != null and is_instance_valid(pev) and pev.hp > 0.0:
		var e: Enemy = pev
		spawn_nova(Vector3(float(rec["x"]), height_at(float(rec["x"]), float(rec["z"])) + 1.2, float(rec["z"])), 1.8, Color(0.78, 0.92, 1.0))
		audio.shot("ice")
		e._die_real()

## Cycle 22: hydro pump — the beam runs 34 u toward the
## player but STOPS at the first pillar within 1.2 of the
## line (bundle block()); a blocked pump deals nothing
## ("the ice covers you"), an unblocked one strikes 1.8
## if the player is within 1.2 + radius of the segment.
func _boss_lapras_pump() -> void:
	if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0 or player == null:
		return
	var from := Vector2(guardian.global_position.x, guardian.global_position.z)
	var dir := _boss_to_player()
	var to := from + dir * 34.0
	var o := 1.1 * tier_value("tele")
	_telegraph_line(from, to, Color(0.29, 0.55, 1.0))
	_boss_hold_t = maxf(_boss_hold_t, o + 1.2)
	spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "水炮！", Color(0.42, 0.72, 1.0))
	_later(o, func() -> void:
		if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0 or player == null:
			return
		var frac := 1.0
		var ab := to - from
		var len2 := ab.length_squared()
		for rec in _boss_mech_data.get("pillars", []):
			var pev = rec.get("e")
			if pev == null or not is_instance_valid(pev) or pev.hp <= 0.0:
				continue
			var tt := 0.0
			if len2 > 0.001:
				tt = clampf((Vector2(float(rec["x"]), float(rec["z"])) - from).dot(ab) / len2, 0.0, 1.0)
			if from.lerp(to, tt).distance_to(Vector2(float(rec["x"]), float(rec["z"]))) < 1.2:
				frac = minf(frac, tt)
		var end := from.lerp(to, frac)
		spawn_nova(Vector3(end.x, height_at(end.x, end.y) + 0.8, end.y), 2.4, Color(0.29, 0.55, 1.0))
		audio.shot("water")
		if frac < 1.0:
			spawn_floater(Vector3(end.x, height_at(end.x, end.y) + 2.4, end.y), "冰柱挡住了！", Color(0.48, 1, 0.54))
		elif _seg_dist(player.global_position.x, player.global_position.z, from.x, from.y, end.x, end.y) < 1.75 and _boss_low(1.6):
			_boss_strike(1.8, dir, 5.0))

## Cycle 22: surf — lapras's own wave (speed 11, max r
## 26, strike 1.3) that also SHATTERS the pillars it
## passes (bundle tick: pillars inside the ring band are
## removed). Ticked in _boss_mech_tick.
func _boss_lapras_surf() -> void:
	if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0:
		return
	_boss_mech_data["wave"] = {"x": guardian.global_position.x, "z": guardian.global_position.z,
		"r": guardian.radius + 1.0, "hit": false, "fx_t": 0.0}
	spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "冲浪！", Color(0.42, 0.72, 1.0))
	audio.shot("water")

## ---- the boss tick (Nb update + tick) ----
func _boss_enrage() -> void:
	_boss_enraged = true
	_refresh_boss_tag()
	show_banner("狂怒！%s 狂暴化：新招式，更快！" % String(ModelRig.SPECIES[guardian.species_id]["label"]), 3.0)
	guardian.speed *= 1.2
	audio.cry(guardian.species_id)
	spawn_nova(guardian.global_position + Vector3(0, 0.4, 0), 8.0, Color(1, 0.23, 0.23))
	spawn_nova(guardian.global_position + Vector3(0, 0.4, 0), 14.0, Color(1, 1, 1))
	if player:
		var d := Vector2(player.global_position.x - guardian.global_position.x,
			player.global_position.z - guardian.global_position.z)
		if d.length() < 10.0 and d.length() > 0.01:
			_boss_strike(0.0, d.normalized(), 12.0)
	_boss_charge = {}
	_boss_t = 1.4
	_boss_call_t = 0.6

func _boss_call_escorts() -> void:
	var t := run_roars + int(tier_value("escorts"))  # pack §1.1
	_boss_escorts = _boss_escorts.filter(func(e) -> bool: return is_instance_valid(e) and e.hp > 0.0)
	if _boss_escorts.size() >= 4 + zone * 2 + t * 2:
		return
	var n := 2 + zone + t
	var elites := (2 if zone >= 2 else 1) + t
	var boss_types: Array = GameData.species(guardian.species_id).get("types", [])
	var pool: Array = []
	for sp in (ZONES[zone - 1]["pool"] as Array):
		var st: Array = GameData.species(String(sp)).get("types", [])
		for bt in boss_types:
			if st.has(bt):
				pool.append(String(sp))
	if pool.is_empty():
		pool = [guardian.species_id]
	audio.cry(guardian.species_id)
	for i in range(n):
		var ang := _bless_rng.randf() * TAU
		var dist := guardian.radius + _bless_rng.randf_range(3.0, 6.0)
		var pos := Vector3(guardian.global_position.x + cos(ang) * dist, 0,
			guardian.global_position.z + sin(ang) * dist)
		pos.x = clampf(pos.x, -BOUND + 4.0, BOUND - 4.0)
		pos.z = clampf(pos.z, -BOUND + 4.0, BOUND - 4.0)
		pos.y = height_at(pos.x, pos.z)
		var e := _spawn_enemy_at(String(pool[_bless_rng.randi_range(0, pool.size() - 1)]),
			pos, _spawn_mult(), false, 1.0)
		if i < elites:
			e.flag = 1
			e.dmg *= 1.4
		_boss_escorts.append(e)

func _boss_tick(delta: float) -> void:
	if guardian == null or not is_instance_valid(guardian) or guardian.hp <= 0.0 or player == null:
		return
	_boss_move_t = maxf(0.0, _boss_move_t - delta)
	_boss_hold_t = maxf(0.0, _boss_hold_t - delta)
	# Hostile shots.
	for i in range(_hostiles.size() - 1, -1, -1):
		var h: Dictionary = _hostiles[i]
		h["life"] = float(h["life"]) - delta
		var node: Node3D = h["node"]
		if float(h["life"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_hostiles.remove_at(i)
			continue
		node.global_position += (h["vel"] as Vector3) * delta
		# Qm checks terrain before a player overlap. There is no sanctuary cover system here.
		if height_at(node.global_position.x, node.global_position.z) > node.global_position.y + 0.4:
			node.queue_free()
			_hostiles.remove_at(i)
			continue
		if hostile_reaches(node.global_position, float(h.get("radius", 0.6))):
			if hostile_hurt(float(h["dmg"]), bool(h.get("capped", false)), bool(h.get("alpha", false)), String(h.get("type", "")), h.get("attacker") if is_instance_valid(h.get("attacker")) else null):
				var shove: Vector3 = (h["vel"] as Vector3).normalized() * 3.5
				player.set("_vel", (player.get("_vel") as Vector3) + shove)
			node.queue_free()
			_hostiles.remove_at(i)
	# Charge movement (the world drives the body).
	if not _boss_charge.is_empty():
		var c: Dictionary = _boss_charge
		c["t"] = float(c["t"]) - delta
		var dir := Vector2(float(c["dx"]), float(c["dz"]))
		guardian.global_position += Vector3(dir.x, 0, dir.y) * float(c["speed"]) * delta
		guardian.global_position.x = clampf(guardian.global_position.x, -BOUND + 2.0, BOUND - 2.0)
		guardian.global_position.z = clampf(guardian.global_position.z, -BOUND + 2.0, BOUND - 2.0)
		guardian.global_position.y = height_at(guardian.global_position.x, guardian.global_position.z)
		if not bool(c["hit"]):
			var dp2 := Vector2(player.global_position.x - guardian.global_position.x,
				player.global_position.z - guardian.global_position.z)
			if dp2.length() < guardian.radius + 1.3 and _boss_low(2.0):
				c["hit"] = true
				_boss_strike(float(c["mul"]), dir, 11.0)
		_boss_charge = c
		if float(c["t"]) <= 0.0:
			_boss_charge = {}
			var chain: Callable = c["chain"]
			if chain.is_valid():
				chain.call()
	# Waves.
	for i in range(_boss_waves.size() - 1, -1, -1):
		var wv: Dictionary = _boss_waves[i]
		var prev := float(wv["r"])
		wv["r"] = prev + 13.0 * delta
		wv["fx_t"] = float(wv["fx_t"]) - delta
		if float(wv["fx_t"]) <= 0.0:
			wv["fx_t"] = 0.18
			spawn_nova(Vector3(float(wv["x"]), height_at(float(wv["x"]), float(wv["z"])) + 0.3, float(wv["z"])),
				float(wv["r"]), wv["col"])
		if not bool(wv["hit"]):
			var dl := Vector2(player.global_position.x - float(wv["x"]),
				player.global_position.z - float(wv["z"])).length()
			if dl >= prev - 0.6 and dl < float(wv["r"]) + 0.6:
				wv["hit"] = true
				if _boss_low(1.3):
					_boss_strike(1.3)
				else:
					spawn_floater(player.global_position + Vector3(0, 2.4, 0), "跳过了！", Color(0.48, 1, 0.54))
		_boss_waves[i] = wv
		if float(wv["r"]) > float(wv["max"]):
			_boss_waves.remove_at(i)
	# Pools.
	_boss_pool_hurt_t = maxf(0.0, _boss_pool_hurt_t - delta)
	for i in range(_boss_pools.size() - 1, -1, -1):
		var pl: Dictionary = _boss_pools[i]
		pl["t"] = float(pl["t"]) - delta
		if float(pl["t"]) <= 0.0:
			_boss_pools.remove_at(i)
			continue
		var dp3 := Vector2(player.global_position.x - float(pl["x"]),
			player.global_position.z - float(pl["z"]))
		if bool(pl.get("vortex", false)):
			if dp3.length() < 6.5 and _boss_low(1.5) and dp3.length() > 0.05:
				var pull := 6.5 * (1.0 - dp3.length() / 7.0)
				var v: Vector3 = player.get("_vel")
				player.set("_vel", v - Vector3(dp3.x, 0, dp3.y).normalized() * pull * 9.0 * delta)
			if dp3.length() < 1.8 and _boss_pool_hurt_t <= 0.0 and _boss_low(1.5):
				_boss_pool_hurt_t = 0.5
				player.hurt_fixed(player.max_hp * 0.05)
		elif not bool(pl.get("pillar", false)):
			if dp3.length() < float(pl["r"]) and _boss_pool_hurt_t <= 0.0 and _boss_low(1.0):
				_boss_pool_hurt_t = 0.5
				player.hurt_fixed(player.max_hp * 0.04)
		_boss_pools[i] = pl
	# Spiral.
	if not _boss_spiral.is_empty():
		var sp: Dictionary = _boss_spiral
		sp["t"] = float(sp["t"]) - delta
		sp["a"] = float(sp["a"]) + float(sp["spin"]) * delta
		sp["acc"] = float(sp["acc"]) + delta * 9.0
		while float(sp["acc"]) >= 1.0:
			sp["acc"] = float(sp["acc"]) - 1.0
			for arm in range(int(sp["arms"])):
				_boss_shot(float(sp["a"]) + float(arm) / float(sp["arms"]) * TAU, 8.5, 0.5, 3.6, Color(1, 0.62, 0.3))
		_boss_spiral = sp if float(sp["t"]) > 0.0 else {}
	# Mech tick.
	_boss_mech_tick(delta)
	# Guardian hold gate for the enemy AI.
	guardian.boss_hold = _boss_hold_t > 0.0 or not _boss_charge.is_empty()
	# Enrage.
	if not _boss_enraged and guardian.hp < guardian.max_hp * tier_value("fury"):
		_boss_enrage()
		return
	# Escort calls.
	_boss_call_t -= delta
	if _boss_call_t <= 0.0:
		_boss_call_t = 16.0 if _boss_enraged else 22.0
		_boss_call_escorts()
	# C23 @1000489: player time since a landed hit, close range only.
	var near := Vector2(player.global_position.x - guardian.global_position.x,
		player.global_position.z - guardian.global_position.z).length() < 30.0
	var s := 0.4 * clampf((player.no_hit_t - 12.0) / 20.0, 0.0, 1.0) if near else 0.0
	if s == 0.0:
		_boss_impatient = false
	if s > 0.0 and not _boss_impatient:
		_boss_impatient = true
		spawn_floater(guardian.global_position + Vector3(0, 3.4, 0), "不耐烦了！", Color(1, 0.54, 0.23))
	_boss_t -= delta * (1.35 if _boss_enraged else 1.0) * (1.0 + s)
	# C23 F1 adaptation: occupancy follows the actual state, independent
	# of the brain clock's enrage/impatience acceleration. Includes windup.
	if _boss_mech == "starmie" and (bool(_boss_mech_data.get("pending", false))
			or not (_boss_mech_data.get("run", {}) as Dictionary).is_empty()
			or float(_boss_mech_data.get("dizzy", 0.0)) > 0.0):
		return
	# Far rule.
	var dist_p := Vector2(player.global_position.x - guardian.global_position.x,
		player.global_position.z - guardian.global_position.z).length()
	if dist_p > 18.0:
		_boss_far_t += delta
	else:
		_boss_far_t = maxf(0.0, _boss_far_t - delta * 2.0)
	if _boss_far_t > 2.5 and _boss_t < 1.2:
		_boss_far_t = 0.0
		_boss_t = _boss_sig_leap({"color": 16747066}) - 1.0
		return
	# The cycle.
	if _boss_t > 0.0:
		return
	if _boss_mech != "" and _boss_sig_next:
		_boss_sig_next = false
		_boss_say(String(BOSS_MECH_NAMES.get(_boss_mech, "")))
		_boss_t = _boss_mech_cast()
		return
	var sig: Dictionary = BOSS_SIG.get(guardian.species_id, {})
	if not sig.is_empty() and _boss_sig_next:
		_boss_sig_next = false
		_boss_say(String(sig["name"]))
		match String(sig["kind"]):
			"cross":
				_boss_t = _boss_sig_cross(sig)
			"leap":
				_boss_t = _boss_sig_leap(sig)
			_:
				_boss_t = _boss_sig_charge(sig)
		return
	_boss_sig_next = true
	var moves := ["slams", "ring", "charge", "volley", "wave"]
	if _boss_enraged:
		moves = ["slams", "ring", "charge", "volley", "wave", "spiral", "meteor", "pools"]
	var opts := moves.filter(func(m) -> bool: return String(m) != _boss_last)
	var pick := String(opts[_bless_rng.randi_range(0, opts.size() - 1)])
	_boss_last = pick
	if BOSS_MOVE_NAMES.has(pick):
		_boss_say(String(BOSS_MOVE_NAMES[pick]))
	match pick:
		"slams":
			_boss_t = _boss_move_slams()
		"ring":
			_boss_t = _boss_move_ring()
		"charge":
			_boss_t = _boss_move_charge()
		"volley":
			_boss_t = _boss_move_volley()
		"wave":
			_boss_t = _boss_move_wave()
		"spiral":
			_boss_t = _boss_move_spiral()
		"meteor":
			_boss_t = _boss_move_meteor()
		"pools":
			_boss_t = _boss_move_pools()

func _boss_mech_tick(delta: float) -> void:
	match _boss_mech:
		"kingler":
			if float(_boss_mech_data.get("guard_t", 0.0)) > 0.0:
				_boss_mech_data["guard_t"] = float(_boss_mech_data["guard_t"]) - delta
				var facing: Vector2 = _boss_mech_data.get("facing", Vector2(0, 1))
				var want := _boss_to_player()
				var cur := atan2(facing.y, facing.x)
				var tgt := atan2(want.y, want.x)
				var diff := wrapf(tgt - cur, -PI, PI)
				var na := cur + clampf(diff, -1.5 * delta, 1.5 * delta)
				_boss_mech_data["facing"] = Vector2(cos(na), sin(na))
				_boss_mech_data["counter_cd"] = float(_boss_mech_data.get("counter_cd", 0.0)) - delta
				var dp := Vector2(player.global_position.x - guardian.global_position.x,
					player.global_position.z - guardian.global_position.z)
				if float(_boss_mech_data["counter_cd"]) <= 0.0 and dp.length() < guardian.radius + 5.0 \
						and facing.dot(dp.normalized()) > 0.5:
					_boss_mech_data["counter_cd"] = 1.8
					_boss_telegraph_strike(player.global_position, 2.6, 0.45 * tier_value("tele"), 1.3, Color(1, 0.35, 0.3))
		"gyarados":
			_boss_mech_data["recharge"] = maxf(0.0, float(_boss_mech_data.get("recharge", 0.0)) - delta)
			var beam: Dictionary = _boss_mech_data.get("beam", {})
			if not beam.is_empty():
				beam["t"] = float(beam["t"]) - delta
				var prog := 1.0 - maxf(0.0, float(beam["t"])) / float(beam["dur"])
				var ang := float(beam["a0"]) + float(beam["dir"]) * 3.5 * minf(1.0, prog)
				if not bool(beam["hit"]):
					var a := Vector2(guardian.global_position.x, guardian.global_position.z)
					var b := a + Vector2(cos(ang), sin(ang)) * 26.0
					var ab := b - a
					var tt := clampf((Vector2(player.global_position.x, player.global_position.z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if Vector2(player.global_position.x, player.global_position.z).distance_to(a + ab * tt) < 1.4 + 0.5 and _boss_low(1.6):
						beam["hit"] = true
						_boss_strike(2.0)
				if float(beam["t"]) <= 0.0:
					beam = {}
					_boss_mech_data["recharge"] = 2.5
					_boss_hold_t = maxf(_boss_hold_t, 2.5)
					spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "必须充能！", Color(1, 0.89, 0.23))
				_boss_mech_data["beam"] = beam
		"cloyster":
			_boss_mech_data["phase"] = float(_boss_mech_data.get("phase", 4.5)) - delta
			if float(_boss_mech_data["phase"]) <= 0.0:
				var open_now := not bool(_boss_mech_data.get("open", false))
				_boss_mech_data["open"] = open_now
				_boss_mech_data["phase"] = 3.5 if open_now else 4.5
				if open_now:
					_boss_hold_t = maxf(_boss_hold_t, 3.4)
					spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "打开了！", Color(1, 0.89, 0.23))
				else:
					spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "夹击！", Color(0.61, 0.91, 1.0))
					var dp := Vector2(player.global_position.x - guardian.global_position.x,
						player.global_position.z - guardian.global_position.z)
					if dp.length() < guardian.radius + 2.2 and _boss_low(1.6):
						# Cycle 22: the bundle's close also
						# BINDS (inflict 'bound' 1 s) — the
						# strike need not land for the bind.
						_boss_strike(1.4)
						player.inflict("bound", 1.0)
		"starmie":
			_boss_mech_data["dizzy"] = maxf(0.0, float(_boss_mech_data.get("dizzy", 0.0)) - delta)
			# Cycle 22: the reflecting-path run (26 u/s
			# along the precomputed legs; one contact
			# strike 1.4 per leg; dizzy 2.5 at the end).
			var run: Dictionary = _boss_mech_data.get("run", {})
			if not run.is_empty():
				_boss_hold_t = maxf(_boss_hold_t, 0.1)
				var path: Array = _boss_mech_data.get("path", [])
				var k := int(run["k"])
				if k >= path.size() - 1:
					_boss_mech_data["run"] = {}
					_boss_mech_data["dizzy"] = 2.5
					_boss_hold_t = maxf(_boss_hold_t, 2.5)
					spawn_floater(guardian.global_position + Vector3(0, 3.2, 0), "晕了！", Color(1, 0.82, 0.42))
				else:
					var a: Vector2 = path[k]
					var b: Vector2 = path[k + 1]
					var leg := a.distance_to(b)
					run["s"] = float(run["s"]) + 26.0 * delta
					var l := clampf(float(run["s"]) / maxf(leg, 0.001), 0.0, 1.0)
					var np := a.lerp(b, l)
					guardian.global_position = Vector3(np.x, height_at(np.x, np.y), np.y)
					if not bool(run["hit"]) and player:
						var dp := Vector2(player.global_position.x - np.x, player.global_position.z - np.y)
						if dp.length() < guardian.radius + 1.0 and _boss_low(1.6):
							run["hit"] = true
							_boss_strike(1.4)
					if l >= 1.0:
						run["k"] = k + 1
						run["s"] = 0.0
						run["hit"] = false
						spawn_nova(guardian.global_position + Vector3(0, 0.3, 0), 2.5, _boss_col(16765034))
						audio.boom()
					_boss_mech_data["run"] = run
		"dewgong":
			# Cycle 22: slide movement + trail lifecycle.
			var slide: Dictionary = _boss_mech_data.get("slide", {})
			if not slide.is_empty():
				_boss_hold_t = maxf(_boss_hold_t, 0.1)
				slide["t"] = float(slide["t"]) - delta
				var dir := Vector2(float(slide["dx"]), float(slide["dz"]))
				var np := guardian.global_position + Vector3(dir.x, 0, dir.y) * 22.0 * delta
				np.x = clampf(np.x, -BOUND + 2.0, BOUND - 2.0)
				np.z = clampf(np.z, -BOUND + 2.0, BOUND - 2.0)
				np.y = height_at(np.x, np.z)
				guardian.global_position = np
				if not bool(slide["hit"]) and player:
					var dp := Vector2(player.global_position.x - np.x, player.global_position.z - np.z)
					if dp.length() < guardian.radius + 1.0 and _boss_low(1.6):
						slide["hit"] = true
						_boss_strike(1.3, dir, 10.0)
				if float(slide["t"]) <= 0.0:
					var trails: Array = _boss_mech_data.get("trails", [])
					trails.append({"ax": float(slide["ax"]), "az": float(slide["az"]),
						"bx": np.x, "bz": np.z, "t": 6.0, "burst": 1.2})
					_boss_mech_data["trails"] = trails
					var left := int(slide["left"])
					var rage := bool(slide["rage"])
					_boss_mech_data["slide"] = {}
					if left > 0:
						_later(0.35, func() -> void: _boss_dewgong_next(left, rage))
				else:
					_boss_mech_data["slide"] = slide
			var trails2: Array = _boss_mech_data.get("trails", [])
			if not trails2.is_empty():
				var kept: Array = []
				for tr in trails2:
					tr["t"] = float(tr["t"]) - delta
					if float(tr["t"]) <= 0.0:
						continue
					var on := false
					if player:
						on = _seg_dist(player.global_position.x, player.global_position.z,
							float(tr["ax"]), float(tr["az"]), float(tr["bx"]), float(tr["bz"])) < 1.2
						if on:
							player.arena_slip = maxf(player.arena_slip, 0.85)
					if float(tr["burst"]) > 0.0:
						tr["burst"] = float(tr["burst"]) - delta
						if float(tr["burst"]) <= 0.0:
							# The trail bursts: shards along
							# the segment; a player standing
							# on it takes strike 1.1 + frozen.
							var a2 := Vector2(float(tr["ax"]), float(tr["az"]))
							var b2 := Vector2(float(tr["bx"]), float(tr["bz"]))
							var steps := maxi(1, int(a2.distance_to(b2) / 1.4))
							for si in range(steps + 1):
								var sp2 := a2.lerp(b2, float(si) / float(steps))
								spawn_nova(Vector3(sp2.x, height_at(sp2.x, sp2.y) + 0.4, sp2.y), 1.1, Color(0.78, 0.92, 1.0))
							audio.shot("ice")
							if on and _boss_low(1.3):
								_boss_strike(1.1)
								player.inflict("frozen", 0.9)
					kept.append(tr)
				_boss_mech_data["trails"] = kept
		"lapras":
			# Cycle 22: pillar lifetimes + the surf wave.
			var pillars: Array = _boss_mech_data.get("pillars", [])
			if not pillars.is_empty():
				var keptp: Array = []
				for rec in pillars:
					var pev = rec.get("e")
					if pev == null or not is_instance_valid(pev) or pev.hp <= 0.0:
						continue  # broken by the player (or freed)
					rec["t"] = float(rec["t"]) - delta
					if float(rec["t"]) <= 0.0:
						_boss_lapras_kill_pillar(rec)
						continue
					keptp.append(rec)
				_boss_mech_data["pillars"] = keptp
			var wave: Dictionary = _boss_mech_data.get("wave", {})
			if not wave.is_empty():
				var prev := float(wave["r"])
				wave["r"] = prev + 11.0 * delta
				wave["fx_t"] = float(wave.get("fx_t", 0.0)) - delta
				if float(wave["fx_t"]) <= 0.0:
					wave["fx_t"] = 0.18
					spawn_nova(Vector3(float(wave["x"]), height_at(float(wave["x"]), float(wave["z"])) + 0.3, float(wave["z"])),
						float(wave["r"]), Color(0.29, 0.55, 1.0))
				# The wave shatters pillars in its band.
				var pillars2: Array = _boss_mech_data.get("pillars", [])
				if not pillars2.is_empty():
					var kept2: Array = []
					for rec in pillars2:
						var pd := Vector2(float(rec["x"]) - float(wave["x"]), float(rec["z"]) - float(wave["z"])).length()
						if pd >= prev - 1.0 and pd < float(wave["r"]) + 1.0:
							_boss_lapras_kill_pillar(rec)
						else:
							kept2.append(rec)
					_boss_mech_data["pillars"] = kept2
				if not bool(wave["hit"]) and player:
					var dl := Vector2(player.global_position.x - float(wave["x"]),
						player.global_position.z - float(wave["z"])).length()
					if dl >= prev - 0.7 and dl < float(wave["r"]) + 0.7:
						wave["hit"] = true
						if _boss_low(1.3):
							_boss_strike(1.3)
						else:
							spawn_floater(player.global_position + Vector3(0, 2.4, 0), "跳过了！", Color(0.48, 1, 0.54))
				_boss_mech_data["wave"] = {} if float(wave["r"]) > 26.0 else wave
		"hypno":
			# Cycle 22: the pendulum field + the drowsy
			# payoff (db class 97). The beam tracks the
			# player at <= .4 rad/s and swings
			# sin(t x pi / .8) x .87 around the tracked
			# base; enraged swings TWO beams. Standing in
			# a beam (dist < 16, |angle diff| < .61) adds
			# .2 drowsy every .25 s (decay .35/s); at 1.0
			# the player sleeps 1.6 s and hypno dream-eats.
			_boss_mech_data["drowsy"] = maxf(0.0, float(_boss_mech_data.get("drowsy", 0.0)) - 0.35 * delta)
			var swing: Dictionary = _boss_mech_data.get("swing", {})
			if not swing.is_empty():
				swing["t"] = float(swing["t"]) - delta
				if float(swing["t"]) <= 0.0:
					_boss_mech_data["swing"] = {}
				else:
					var to_p := _boss_to_player()
					var want := atan2(to_p.y, to_p.x)
					var base := float(swing["base"])
					var diff := wrapf(want - base, -PI, PI)
					base += clampf(diff, -0.4 * delta, 0.4 * delta)
					swing["base"] = base
					var s := sin(run_time * PI / 0.8) * 0.87
					var beams := [base + s, base - s] if bool(swing.get("rage", false)) else [base + s]
					var in_field := false
					if player:
						var pd := Vector2(player.global_position.x - guardian.global_position.x,
							player.global_position.z - guardian.global_position.z)
						if pd.length() < 16.0:
							var pa := atan2(pd.y, pd.x)
							for ba in beams:
								if absf(wrapf(pa - float(ba), -PI, PI)) < 0.61:
									in_field = true
					_boss_mech_data["dtick"] = float(_boss_mech_data.get("dtick", 0.0)) - delta
					if in_field and float(_boss_mech_data["dtick"]) <= 0.0:
						_boss_mech_data["dtick"] = 0.25
						_boss_mech_data["drowsy"] = float(_boss_mech_data["drowsy"]) + 0.2
						spawn_floater(player.global_position + Vector3(0, 2.2, 0), "z", Color(0.85, 0.65, 1.0))
						if float(_boss_mech_data["drowsy"]) >= 1.0:
							_boss_mech_data["drowsy"] = 0.0
							if player.inflict("sleep", 1.6):
								_boss_hypno_dream_eat()
								swing = {}
					_boss_mech_data["swing"] = swing

## ------------------------------------------------ cycle 21: stage events
## The bundle's ax table + sx machine (@1035191): four
## random stage events fired from timeline slots — fog
## (45 s), storm (40 s), eclipse (40 s), golden meowth
## (25 s). Each kind fires at most once per run (the done
## set); startRandom refuses while a boss is alive, the
## stage is cleared, or another event runs. PORTED:
## fog / storm / eclipse with their looks, pools, storm
## bolts and the eclipse shiny roll. Cycle 22: all four
## kinds are ported now — the golden meowth included
## (below) — and the spawn internals are the bundle's
## own (updateSpawns: a batch of 3 + stage every 4 s at
## dist 20-27, 30 spawned cap, stops when < 6 s remain;
## fog spawns earn xp x2; the eclipse's first-of-batch
## after 90 s is Elite). C23B2 preserves Flying=16. The
## separate map-ground hazard system is not yet ported;
## this does not change the event-wide map blind getter.
const EVENT_DEFS := {
	"fog": {"name": "幽灵迷雾", "sub": "冰冷的雾笼罩一切……雾里有东西在动", "dur": 45.0,
		"pool": [[92, 41, 96], [93, 42, 96], [94, 93, 97]],
		"fog": Color(0.353, 0.29, 0.478), "near": 2.0, "far": 26.0, "light": 0.62},
	"storm": {"name": "雷暴", "sub": "落雷不断：离黄色标记远一点", "dur": 40.0,
		"pool": [[100, 81, 25], [101, 82, 125, 26], [101, 82, 125, 135]],
		"fog": Color(0.337, 0.325, 0.4), "near": 22.0, "far": 110.0, "light": 0.58},
	"eclipse": {"name": "日蚀", "sub": "光熄灭了。夜行者们出来了……也许还有流光", "dur": 40.0,
		"pool": [[41, 92, 96, 35, 43], [42, 93, 97, 36, 44], [42, 94, 97, 36, 45]],
		"fog": Color(0.224, 0.184, 0.263), "near": 26.0, "far": 120.0, "light": 0.42},
	# The meowth def has no pool and no look in the bundle
	# (the running weather look simply persists).
	"meowth": {"name": "金鼹鼠", "sub": "每次命中都会掉金币：在它逃走前抓住它！", "dur": 25.0},
}
var _event_kind := ""
var _event_left := 0.0
var _event_done: Array = []
var _event_try_t := 75.0
var _zone_t := 0.0
var _event_spawn_t := 0.0
var _event_spawned: Array = []
var _event_spawned_n := 0
var _event_shiny_rolled := false
var _event_bolt_t := 2.0
# Cycle 22: sx.k intensity envelope (ramps dt/3) — gates
# the fog's minimap blinding (blind = fog && k > .5).
var _event_k := 0.0
var _event_meowth: Enemy = null
var _event_coin_cd := 0.0

## Cycle 22: sx.blind — while the fog event runs at
## k > .5 the maps show only the player (bundle draws
## @2031938/@1980426; the world pins hide too — this
## port's pins live on the maps, covered by the same
## treatment in minimap.gd / big_map.gd).
func event_blind() -> bool:
	return _event_kind == "fog" and _event_k > 0.5

## Cycle 22: sx.marker — the golden meowth's position
## for the maps while its event runs.
func event_marker_pos() -> Variant:
	if _event_kind == "meowth" and _event_meowth != null and is_instance_valid(_event_meowth) \
			and _event_meowth.hp > 0.0:
		return _event_meowth.global_position
	return null

func _event_pool_keys() -> Array:
	if _event_kind == "":
		return []
	var def: Dictionary = EVENT_DEFS[_event_kind]
	var dexes: Array = def["pool"][mini(zone, 3) - 1]
	var keys: Array = []
	for d in dexes:
		var k := String(GameData.species_by_id(int(d)).get("key", ""))
		if k != "" and ModelRig.SPECIES.has(k):
			keys.append(k)
	return keys

func _event_try_start() -> void:
	_event_try_t = _zone_t + 45.0  # retry cadence (bundle timeline +20 s, ours relaxed)
	var kinds: Array = []
	for k in EVENT_DEFS.keys():
		if not _event_done.has(k):
			kinds.append(k)
	if kinds.is_empty():
		return
	# Bundle startRandom: F.weighted with the meowth at
	# .8 against 1.0 for the weather kinds.
	var total := 0.0
	for k in kinds:
		total += 0.8 if k == "meowth" else 1.0
	var roll := _rng.randf() * total
	var kind := String(kinds[0])
	for k in kinds:
		roll -= 0.8 if k == "meowth" else 1.0
		if roll <= 0.0:
			kind = String(k)
			break
	_event_kind = kind
	_event_done.append(kind)
	var def: Dictionary = EVENT_DEFS[kind]
	_event_left = float(def["dur"])
	_event_spawn_t = 2.0
	_event_bolt_t = 3.0
	_event_shiny_rolled = false
	_event_spawned.clear()
	_event_spawned_n = 0
	_event_k = 0.0
	# Bundle start(): a failed meowth spawn cancels the
	# event silently (the kind stays in the done set).
	if kind == "meowth" and not _event_spawn_meowth():
		_event_kind = ""
		_event_left = 0.0
		return
	show_banner("【%s】%s" % [String(def["name"]), String(def["sub"])], 4.0)
	audio.alarm()
	# The look (ax look): fog color + depth + light scale.
	# The meowth def has no look — the weather persists.
	if def.has("fog"):
		if _env:
			_env.fog_light_color = def["fog"]
			_env.fog_depth_begin = float(def["near"])
			_env.fog_depth_end = float(def["far"])
		if _sun:
			_sun.light_energy = _WX_SUN_BASE * float(def["light"])
		if _env:
			_env.ambient_light_energy = _WX_AMB_BASE * float(def["light"])
	_refresh_event_pills()

## Cycle 22: spawnMeowth — up to 12 tries at dist 14-20
## (in-bounds margin 10); the Treasure spawn gets hp x9
## (bundle spawn @325834), speed 7.4 flat, damage mult 1
## flat, and the Treasure steering (enemy.gd). The gold
## ring under it stands in for the bundle's gold sprite
## grade (@339684).
func _event_spawn_meowth() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for n in range(12):
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(14.0, 20.0)
		var pos := player.global_position + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if absf(pos.x) > BOUND - 10.0 or absf(pos.z) > BOUND - 10.0:
			continue
		pos.y = height_at(pos.x, pos.z)
		var e := _spawn_enemy_at("meowth", pos, _spawn_mult() * 9.0, false, 1.0)
		e.treasure = true
		e.speed = 7.4
		e.dmg = Enemy.base_dmg("meowth")
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.85
		tm.outer_radius = 1.15
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1.0, 0.78, 0.23, 0.85)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rm
		ring.position = Vector3(0, 0.12, 0)
		e.add_child(ring)
		_event_meowth = e
		_event_coin_cd = 0.0
		spawn_nova(pos + Vector3(0, 0.6, 0), 3.0, Color(1.0, 0.78, 0.23))
		audio.cry("meowth")
		return true
	return false

## Cycle 22: events.onHit — a hit on the golden meowth
## (0.16 s cooldown) drops a coin worth
## ceil((2 + stage x 2) x gold). This port credits coin
## pickups directly (the guardian reward's standing
## adaptation, cycle 9), with the coin sound + floater.
func event_hit(e: Enemy) -> void:
	if _event_kind != "meowth" or e != _event_meowth or _event_coin_cd > 0.0:
		return
	_event_coin_cd = 0.16
	var gm := player.gold_mult if player else 1.0
	var v := int(ceil((2.0 + float(zone) * 2.0) * gm))
	spawn_pickup(1, e.global_position, v)

## Cycle 22: events.onKilled — the fountain: 30 coins of
## ceil((4 + stage x 4) x gold), the Pay Day banner, and
## the event ends silently.
func _event_meowth_killed() -> void:
	var gm := player.gold_mult if player else 1.0
	var each := int(ceil((4.0 + float(zone) * 4.0) * gm))
	var total := 30 * each
	var death_pos: Vector3 = _event_meowth.global_position
	for i in range(30):
		spawn_pickup(1, death_pos, each)
	show_banner("【金币雨！】金鼹鼠掉出了所有金币（+%d）" % total, 4.0)
	_event_meowth = null
	_event_end()

func _event_end() -> void:
	# Bundle end() toasts for the weather kinds (the
	# meowth's ends are silent or carry their own text).
	var end_msgs := {"fog": "雾散了", "storm": "风暴远去了", "eclipse": "光回来了"}
	if end_msgs.has(_event_kind) and player and is_instance_valid(player):
		spawn_floater(player.global_position + Vector3(0, 2.6, 0), String(end_msgs[_event_kind]), Color(0.85, 0.85, 0.95))
	_event_kind = ""
	_event_left = 0.0
	_event_try_t = _zone_t + 90.0
	apply_weather_look()  # restore the zone/weather look
	_refresh_event_pills()

func _event_tick(delta: float) -> void:
	_zone_t += delta
	if _event_kind == "":
		_event_k = maxf(0.0, _event_k - delta / 3.0)
		if state == "playing" and guardian == null and _zone_t >= _event_try_t:
			_event_try_start()
		return
	_event_k = minf(1.0, _event_k + delta / 3.0)
	_event_left -= delta
	if _event_kind == "meowth":
		# Cycle 22: updateMeowth — coin cooldown, the
		# twinkle trail, and the escape at time-out.
		_event_coin_cd = maxf(0.0, _event_coin_cd - delta)
		if _event_meowth == null or not is_instance_valid(_event_meowth) or _event_meowth.hp <= 0.0:
			_event_meowth = null
			_event_end()
			return
		if _rng.randf() < delta * 6.0:
			spawn_nova(_event_meowth.global_position + Vector3(0, 0.5, 0), 0.9, Color(1.0, 0.78, 0.23))
		if _event_left <= 0.0:
			var mp := _event_meowth.global_position
			spawn_nova(mp + Vector3(0, 0.6, 0), 3.0, Color(1.0, 0.78, 0.23))
			_event_meowth.capture_remove()
			_event_meowth = null
			show_banner("金鼹鼠带着战利品逃走了", 2.5)
			_event_end()
		return
	if _event_left <= 0.0:
		_event_end()
		return
	# Pool spawns (bundle updateSpawns): a batch of
	# 3 + stage every 4 s at dist 20-27, a 30-spawned
	# cap, nothing in the event's last 6 s. Fog spawns
	# earn xp x2; the eclipse's first-of-batch after
	# 90 s is Elite.
	_event_spawned = _event_spawned.filter(func(e) -> bool: return is_instance_valid(e) and e.hp > 0.0)
	_event_spawn_t -= delta
	if _event_spawn_t <= 0.0:
		_event_spawn_t = 4.0
		var keys := _event_pool_keys()
		if not keys.is_empty() and _event_spawned_n < 30 and _event_left >= 6.0 and player:
			for bi in range(int(ceil(float(3 + zone) * tier_value("events")))):
				var elite := _event_kind == "eclipse" and bi == 0 and elapsed > 90.0
				var e := _spawn_enemy_at(String(keys[_rng.randi_range(0, keys.size() - 1)]),
					_ring_pos(20.0, 27.0), _spawn_mult(), false, 1.35 if elite else 1.0)
				_event_spawned_n += 1
				_event_spawned.append(e)
				if _event_kind == "fog":
					e.flag |= 16  # R.Flying; independent of the species' type
					e.xp_mult = 2.0
				if elite:
					e.flag = 1
					e.dmg *= 1.4
					e.max_hp *= 4.5
					e.hp = e.max_hp
	# Storm bolts: a yellow mark, then the strike (fixed
	# 30% max HP — the bundle's combat.hit .3 branch).
	if _event_kind == "storm":
		_event_bolt_t -= delta
		if _event_bolt_t <= 0.0 and player:
			_event_bolt_t = 2.5
			var tp := player.global_position
			if _rng.randf() < 0.5:
				tp += Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9))
			spawn_nova(Vector3(tp.x, height_at(tp.x, tp.z) + 0.3, tp.z), 2.8, Color(1, 0.82, 0.23))
			spawn_floater(Vector3(tp.x, height_at(tp.x, tp.z) + 2.2, tp.z), "⚡", Color(1, 0.82, 0.23))
			_later(0.9, func() -> void:
				if player == null or not is_instance_valid(player) or player.hp <= 0.0:
					return
				spawn_nova(Vector3(tp.x, height_at(tp.x, tp.z) + 0.3, tp.z), 2.8, Color(1, 1, 1))
				audio.boom()
				if Vector2(player.global_position.x - tp.x, player.global_position.z - tp.z).length() < 2.8 and _boss_low(2.0):
					player.hurt_fixed(player.max_hp * 0.3)
					spawn_floater(player.global_position + Vector3(0, 2.4, 0), "落雷！", Color(1, 0.82, 0.23)))
	# Eclipse shiny roll (bundle events tick @1040950):
	# once, after the opening 12 s, while no capture runs.
	if _event_kind == "eclipse" and not _event_shiny_rolled and _event_left < 28.0:
		_event_shiny_rolled = true
		if _shiny_e == null and state == "playing" and player:
			var p := minf(0.9, (0.2 + minf(0.08, player.luck / 1000.0)) * GameProfile.shiny_rate())
			if _rng.randf() < p:
				_spawn_shiny(_event_pool_keys())

## ------------------------------------------------ cycle 21: passive ticks
## Passive backlog I — the bundle's per-ability tick
## functions (defs @791920-798760) and its tick table N_
## (@719919): damage F_(key) = (a + b x unit level) x
## j_[stage-1], j_ = [1, 1.8, 3.2, 4]. Ticked for the
## player and every ally (the bundle ticks per unit); the
## level is the player's (our allies scale off it too).
## Static's contact half was already wired (player
## _contact_status); this block adds its discharge.
const PTICK_TABLE := {
	"tentacles": {"every": 2.0, "a": 6.0, "b": 1.5},
	"arena-trap": {"every": 2.0, "a": 4.0, "b": 1.2},
	"chlorophyll": {"every": 6.0, "a": 3.0, "b": 0.6},
}
const PTICK_EVERY := {"tentacles": 2.0, "arena-trap": 2.0, "chlorophyll": 6.0,
	"serpent-glare": 4.0, "loyal-guard": 3.0, "beacon": 5.0,
	"intimidate": 3.0, "static": 4.0, "imposter": 30.0}
const PTICK_STAGE := [1.0, 1.8, 3.2, 4.0]
var _ptick_next: Dictionary = {}

func _ptick_f(key: String, lvl: int) -> float:
	var t: Dictionary = PTICK_TABLE[key]
	return (float(t["a"]) + float(t["b"]) * float(lvl)) * PTICK_STAGE[mini(zone, 4) - 1]

func _ptick_enemies_within(pos: Vector3, r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en := e as Enemy
		if en.hp <= 0.0 or en.is_weakened or en.is_downed:
			continue
		var d := Vector2(en.global_position.x - pos.x, en.global_position.z - pos.z)
		if d.length() <= r:
			out.append(en)
	return out

func _passive_ticks() -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	var units: Array = [player]
	for a in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(a):
			units.append(a)
	for u in units:
		var is_pl: bool = u == player
		var sp: String = player.species_id if is_pl else String((u as Enemy).species_id)
		var pid: String = player.passive_id if is_pl else GameData.passive_for_species(sp)
		if not PTICK_EVERY.has(pid):
			continue
		var uid: int = u.get_instance_id()
		var nxt := float(_ptick_next.get(uid, 0.0))
		if run_time < nxt:
			continue
		_ptick_next[uid] = run_time + float(PTICK_EVERY[pid])
		_ptick_fire(u, sp, pid, is_pl)

func _ptick_fire(u: Node3D, sp: String, pid: String, is_pl: bool) -> void:
	var pos := u.global_position
	var lvl := player.level
	var sd: Dictionary = GameData.species(sp)
	# Cycle 22: the unit's CURRENT types (an imposter copy
	# replaces them — the bundle reads t.types live).
	var utypes: Array = player.types() if is_pl else Array((u as Enemy).types)
	var dex := int(sd.get("id", 0))
	var opts: Dictionary = {}
	if not is_pl:
		opts["ally"] = u
	match pid:
		"tentacles":
			var n := 4 if dex == 73 else 2
			var cands := _ptick_enemies_within(pos, 7.0)
			cands.sort_custom(func(a: Enemy, b: Enemy) -> bool:
				return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
			for i in range(mini(n, cands.size())):
				var o := (opts.duplicate())
				o["status"] = "poison"
				o["status_chance"] = 80.0
				o["knock"] = 0.6
				o["from"] = pos
				combat_hit(cands[i], _ptick_f("tentacles", lvl), "poison", "physical", utypes, o)
		"arena-trap":
			var r := 6.0 if dex == 51 else 4.5
			spawn_nova(pos + Vector3(0, 0.3, 0), r, Color(0.85, 0.7, 0.45))
			for e in _ptick_enemies_within(pos, r):
				var o := (opts.duplicate())
				o["status"] = "root"
				o["status_chance"] = 80.0
				o["knock"] = 0.0
				o["from"] = pos
				combat_hit(e, _ptick_f("arena-trap", lvl), "ground", "physical", utypes, o)
		"chlorophyll":
			spawn_nova(pos + Vector3(0, 0.5, 0), 4.5, Color(0.45, 0.9, 0.4))
			for e in _ptick_enemies_within(pos, 4.5):
				var o := (opts.duplicate())
				o["status"] = "poison"
				o["status_chance"] = 100.0
				o["knock"] = 0.0
				o["from"] = pos
				combat_hit(e, _ptick_f("chlorophyll", lvl), "poison", "special", utypes, o)
		"serpent-glare":
			var rig: Node3D = u.get("rig")
			var fy := 0.0
			if rig:
				fy = rig.rotation.y
			var facing := Vector2(sin(fy), cos(fy))
			if is_pl:
				var v: Vector3 = player.get("_vel")
				if Vector2(v.x, v.z).length() > 0.5:
					facing = Vector2(v.x, v.z).normalized()
			var center := pos + Vector3(facing.x, 0, facing.y) * 3.5
			for e in _ptick_enemies_within(center, 4.5):
				var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z)
				if d.length() < 7.0 and d.length() > 0.01 and facing.dot(d.normalized()) > 0.45:
					e.apply_ailment("paralysis")
					spawn_floater(e.global_position + Vector3(0, 2.6, 0), "麻痹！", Color(1, 0.9, 0.4))
		"loyal-guard", "intimidate":
			var r := 5.5 if pid == "loyal-guard" else 5.0
			for e in _ptick_enemies_within(pos, r):
				e.apply_status("charm", 3.0)
		"beacon":
			for e in _ptick_enemies_within(pos, 5.0):
				var o := (opts.duplicate())
				o["status"] = "paralysis"
				o["status_chance"] = 70.0
				o["knock"] = 0.2
				o["from"] = pos
				combat_hit(e, 4.0 + float(lvl), "electric", "special", utypes, o)
		"static":
			var cands := _ptick_enemies_within(pos, 10.0)
			if not cands.is_empty():
				cands.sort_custom(func(a: Enemy, b: Enemy) -> bool:
					return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
				var o := (opts.duplicate())
				o["status"] = "paralysis"
				o["status_chance"] = 100.0
				combat_hit(cands[0], 10.0 + float(lvl) * 2.0, "electric", "special", utypes, o)
				spawn_nova((cands[0] as Enemy).global_position + Vector3(0, 0.8, 0), 1.6, Color(1, 0.9, 0.4))
		"imposter":
			# Cycle 22: the bundle tick (@711560) — every
			# 30 s copy the NEAREST enemy's types (within
			# 25 u); the copy drives the unit's type bonus
			# channels until the next copy. DIFF C22 recorded offensive-only
			# scope; C23B1 also added typed incoming hurt (player.take_damage).
			var cands := _ptick_enemies_within(pos, 25.0)
			if cands.is_empty():
				return
			cands.sort_custom(func(a: Enemy, b: Enemy) -> bool:
				return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
			var copied := Array((cands[0] as Enemy).types)
			if copied.is_empty():
				return
			if is_pl:
				player.types_override = copied
			else:
				(u as Enemy).types = copied
			var names: Array = []
			for t in copied:
				names.append(String(TYPE_HUD.get(String(t), [String(t)])[0]))
			var col: Color = TYPE_HUD.get(String(copied[0]), ["", Color.WHITE])[1]
			spawn_nova(pos + Vector3(0, 0.4, 0), 3.0, col)
			spawn_floater(pos + Vector3(0, 2.8, 0), "变身！%s" % " / ".join(names), col)

## ------------------------------------------------ cycle 15 prop prompts

func _prop_near(flat_p: Vector2) -> Dictionary:
	var st: Dictionary = _inter_state.get(zone, {})
	if st.is_empty():
		return {}
	var best: Dictionary = {}
	var best_d := 1e18
	for p in st.get("props", []):
		var kind := String(p["kind"])
		# Slots never spend; the nest stays addressable while
		# carrying (its label becomes the deny/progress line).
		if bool(p["used"]) and kind != "nest":
			continue
		var d := flat_p.distance_to(Vector2(float(p["x"]), float(p["z"])))
		if d < float(p["r"]) + 0.8 and d < best_d:
			best_d = d
			best = p
	return best

## UI-mobile P1.1: the prop prompts carry the live interact
## verb (_ik) — the table below keeps the keyboard form.
func _prop_label(p: Dictionary) -> String:
	return _prop_label_kbd(p).replace("按 E", _ik())

func _prop_label_kbd(p: Dictionary) -> String:
	var kind := String(p["kind"])
	match kind:
		"fossil":
			return "化石遗迹 · 按 E 献祭最大生命：物品或祝福"
		"magnet":
			return "磁铁 · 按 E 拾取：吸引经验与金币"
		"berry":
			return "树果丛 · 按 E 食用：回复 50% 生命"
		"rock":
			return "碎石堆 · 按 E 敲开：金币（偶尔滚出回复）"
		"snorlax":
			return "卡比兽 · 按 E 叫醒它：祝福，或金币"
		"greed":
			return "贪婪祭坛 · 按 E 献祭：难度 +20%，经验与金币 +25%"
		"cursed":
			return "诅咒祭坛 · 按 E 接受诅咒：敌人更多更强，换一份宝藏"
		"chest":
			# Bundle label @1245997: price, plus the
			# insufficient-funds state.
			if gold < float(_chest_cost()):
				return "藤纹宝箱 · %d 金币（金币不足）：三选一，或全部出售" % _chest_cost()
			return "藤纹宝箱 · 按 E 开启（%d 金币）：三选一，或全部出售" % _chest_cost()
		"freechest":
			return "免费宝箱 · 按 E 开启"
		"cursedchest":
			return "诅咒宝箱 · 按 E 开启：宝藏与埋伏一起来"
		"challenge":
			return "挑战神龛 · 按 E 开始挑战：扛住兽群，赢取宝箱"
		"slots":
			return "老虎机 · 按 E 拉一次（%d 金币）" % _slots_cost()
		"cage":
			return "笼子 · 按 E 付 %d 金币放生：换取经验" % (20 + zone * 10)
		"nest":
			if not _egg.is_empty():
				return "蛋正在孵化中（还差 %d 次击杀）" % maxi(0, int(_egg["need"]) - (kills - int(_egg["from"])))
			return "神秘的蛋 · 按 E 抱回孵化（击杀 %d 后孵化）" % (200 + 100 * (mini(3, zone) - 1))
		"porygon":
			return "机关匣 · 按 E 重编译：三选一（增益＋代价）"
		"meowth":
			return "獾掌柜铺 · 按 E 逛逛：买入物品，或按市价出售"
		"ditto":
			return "拟态团 · 按 E 让它复制你持有的一件物品"
	return kind

## ------------------------------------------------ cycle 15 prop effects

func _interact_prop(p: Dictionary) -> void:
	var kind := String(p["kind"])
	var d: Dictionary = p["data"]
	var pp := player.global_position
	match kind:
		"fossil":
			Fossils.open(self, p)
		"meowth":
			# Cycle 21: never consumed; opens the shop.
			_open_shop()
		"ditto":
			# Cycle 22: the bundle handler (@1251293) —
			# empty inventory: toast, prop NOT consumed;
			# otherwise the clone picker opens.
			if player.items.is_empty():
				spawn_floater(pp + Vector3(0, 2.6, 0), "拟态团没有可复制的东西…", Color(0.85, 0.75, 1.0))
				return
			_open_ditto(p)
		"magnet":
			_prop_set_used(p)
			pickup_manager().magnet_all = 5.0
			spawn_floater(pp+Vector3(0,2.6,0),"磁铁！",Color(0.6,0.5,1.0))
		"berry":
			_prop_set_used(p)
			count_run_event("berries")
			player.leech_heal(player.max_hp * 0.5)
			audio.heal()  # cycle 16
			spawn_floater(pp + Vector3(0, 2.6, 0), "树果：回复 50% 生命！", Color(0.55, 0.95, 0.5))
		"rock":
			_prop_set_used(p)
			count_run_event("rocks")
			var g := int(round(_bless_rng.randf_range(6.0, 14.0) * maxf(float(zone), _chest_value() / 90.0)))
			gold += float(g)
			spawn_floater(pp + Vector3(0, 2.6, 0), "+%d 金币" % g, Color(1.0, 0.85, 0.3))
			if _bless_rng.randf() < 0.15 * _luck_mult():
				spawn_pickup([2,3,4][_bless_rng.randi_range(0,2)], pp)

		"snorlax":
			_prop_set_used(p)
			var lines := ["卡比兽翻了个身，掉出了点什么。", "卡比兽说梦话：『再睡五分钟……』", "卡比兽的肚子咕咕叫。", "卡比兽梦见了大餐。"]
			var flavor := String(lines[_bless_rng.randi_range(0, lines.size() - 1)])
			if _bless_rng.randf() < minf(0.85, 0.5 * _luck_mult()):
				show_banner(flavor, 2.5)
				offer_blessing("卡比兽的祝福", 0, 3, 1)
			else:
				var g2 := int(round(maxf(30.0 * float(zone), 0.5 * _chest_value())))
				gold += float(g2)
				show_banner(flavor + "\n它滚开后压着 %d 金币！" % g2, 2.5)
		"greed":
			_prop_set_used(p)
			count_run_event("greed")
			player.temp_mods.append({"stat": "difficulty", "mul": 1.2})
			player.temp_mods.append({"stat": "xpGain", "mul": 1.25})
			player.temp_mods.append({"stat": "gold", "mul": 1.25})
			player.recalc()
			show_banner("贪婪祭坛：难度 +20%，经验与金币 +25%（本局）", 3.0)
		"cursed":
			_prop_set_used(p)
			count_run_event("curses")
			player.temp_mods.append({"stat": "enemyAmount", "mul": 1.15})
			player.temp_mods.append({"stat": "difficulty", "mul": 1.1})
			player.recalc()
			show_banner("你被诅咒了：敌人更多更强，但宝藏在等你…", 3.0)
			_later(0.8, func() -> void: _chest_roll_single(2))
		"chest":
			_chest_open(p)
		"freechest":
			_prop_set_used(p)
			_chest_roll_single(1)
		"cursedchest":
			_prop_set_used(p)
			player.temp_mods.append({"stat": "difficulty", "mul": 1.05})
			player.recalc()
			count_run_event("curses")
			_chest_roll_single(2 if _bless_rng.randf() < 0.5 else 1)
			_later(0.2, func() -> void: _cursed_ambush())
		"challenge":
			_challenge_start(p)
		"slots":
			_slots_prop = p
			_slots_spin()
		"cage":
			var cost := 20 + zone * 10
			if gold < float(cost):
				spawn_floater(pp + Vector3(0, 2.6, 0), "金币不足（需要 %d）" % cost, Color(0.9, 0.6, 0.5))
				return
			gold -= float(cost)
			_prop_set_used(p)
			if d.get("rig") and is_instance_valid(d["rig"]):
				(d["rig"] as Node3D).visible = false
			player.gain_xp(player.xp_next() * 0.5)
			show_banner("放生了%s：获得一半升级经验！" % String(ModelRig.SPECIES[String(d["species"])]["label"]), 2.5)
		"nest":
			if not _egg.is_empty():
				spawn_floater(pp + Vector3(0, 2.6, 0), "你已经抱着一颗蛋了", Color(0.9, 0.85, 0.6))
				return
			_prop_set_used(p)
			var need := 200 + 100 * (mini(3, zone) - 1)
			_egg_carry(String(d["species"]), need)
			show_banner("🥚 你抱起了一颗蛋（击杀 %d 后孵化）" % need, 3.0)
		"porygon":
			_porygon_open(p)

## Cycle 22: Ditto (openDitto @1478546 / showDitto
## @2051392). The picker lists one card per held item kind;
## the bundle greys maxed kinds (badge "Máx.", opacity
## .45) and denies the pick with the modal staying open.
## Our choice cards have no disabled state, so a maxed
## card carries a 【已满】 line and picking it denies +
## reopens the picker — the same player-visible outcome
## (DIFF §22). A successful pick adds the copy, spends
## the prop (bundle: used -> "Ditto descansa") and plays
## cry(132), as does opening the picker.
func _open_ditto(p: Dictionary, with_cry := true) -> void:
	if with_cry:
		audio.cry("ditto")
	var keys: Array = []
	for k in player.items.keys():
		if player.item_count(String(k)) > 0:
			keys.append(String(k))
	keys.sort()
	var opts: Array = []
	var maxed: Array = []
	for k in keys:
		var t := _item_card_text(String(k))
		if not player.can_hold_item(String(k)):
			t += "\n【已满】"
			maxed.append(String(GameData.item_def(String(k)).get("name", String(k))))
		opts.append(t)
	var sub := "选择一件物品，拟态团会变成它"
	if not maxed.is_empty():
		sub += "（已满：%s）" % "、".join(maxed)
	_choice_show("拟态团：复制哪件物品？", sub, opts, "现在不要",
		func(idx: int) -> void:
			var key := String(keys[idx])
			if not player.can_hold_item(key):
				audio.deny()
				spawn_floater(player.global_position + Vector3(0, 2.6, 0), "这件物品已持有上限", Color(0.9, 0.6, 0.5))
				_open_ditto(p, false)
				return
			player.add_item(key)
			_prop_set_used(p)
			audio.cry("ditto")
			show_banner("拟态团变成了%s！" % _item_zh_name(key), 2.5),
		func() -> void: pass)

## Paid chest (openChest @1253770): pay, chestsBought += 1,
## then a pick-1 choice of 3 rolled vitamins — or sell all
## for the minimum qC of the three.
func _chest_open(p: Dictionary) -> void:
	var cost := _chest_cost()
	if gold < float(cost):
		audio.deny()  # cycle 16
		spawn_floater(player.global_position + Vector3(0, 2.6, 0), "金币不足（需要 %d）" % cost, Color(0.9, 0.6, 0.5))
		return
	audio.chest()
	audio.coin()
	gold -= float(cost)
	_prop_set_used(p)
	_chests_bought += 1
	# Cycle 21: the paid chest is rollChestItem(false, 0, 3)
	# — three distinct items, pick one or sell all (bundle
	# @1478468); the vitamin rolls it used through C20 are
	# replaced by the real item roll (which counts the
	# chest event itself).
	_roll_chest_item(0, 3)


func _cursed_ambush() -> void:
	if player == null or not is_instance_valid(player):
		return
	var n := 4 + 2 * zone
	var center := player.global_position
	for i in range(n):
		var idx := mini(4, zone - 1 + (2 if i == 0 else 0))
		var sp: String = GHOST_ROSTER[idx]
		var ang := float(i) / float(n) * TAU
		var dist := _bless_rng.randf_range(6.0, 8.0)
		var pos := Vector3(clampf(center.x + cos(ang) * dist, -BOUND + 2.0, BOUND - 2.0), 0,
			clampf(center.z + sin(ang) * dist, -BOUND + 2.0, BOUND - 2.0))
		pos.y = height_at(pos.x, pos.z)
		var elite := i == 0
		var e := _spawn_enemy_at(sp, pos, _spawn_mult() * (4.5 if elite else 1.0), false, 1.35 if elite else 1.0)
		if elite:
			e.flag = 1
			e.dmg *= 1.4
	show_banner("诅咒宝箱的埋伏！", 2.5)

## Challenge (startChallenge @~1255600): one pool species,
## 8 + 3 x stage ringed 8-11u around the SHRINE, the first
## 1 + floor(stage/2) Elite, staggered .15 + i x .08 s.
func _challenge_start(p: Dictionary) -> void:
	_prop_set_used(p)
	var d: Dictionary = p["data"]
	var pool: Array = ZONES[zone - 1]["pool"]
	var species := String(pool[_bless_rng.randi_range(0, pool.size() - 1)])
	var n := 8 + 3 * zone
	var elites := 1 + zone / 2
	d["pending"] = n
	d["wave"] = []
	d["done"] = false
	show_banner("⚔ 挑战开始！%s 群来袭！" % String(ModelRig.SPECIES[species]["label"]), 3.0)
	for i in range(n):
		_later(0.15 + float(i) * 0.08, _challenge_spawn.bind(p, species, i, elites))

func _challenge_spawn(p: Dictionary, species: String, i: int, elites: int) -> void:
	var d: Dictionary = p["data"]
	d["pending"] = int(d["pending"]) - 1
	if state == "menu" or state == "dead" or state == "victory":
		return
	var ang := float(i) / float(maxi(1, 8 + 3 * zone)) * TAU + _bless_rng.randf_range(-0.2, 0.2)
	var dist := _bless_rng.randf_range(8.0, 11.0)
	var pos := Vector3(clampf(float(p["x"]) + cos(ang) * dist, -BOUND + 2.0, BOUND - 2.0), 0,
		clampf(float(p["z"]) + sin(ang) * dist, -BOUND + 2.0, BOUND - 2.0))
	pos.y = height_at(pos.x, pos.z)
	var elite := i < elites
	var e := _spawn_enemy_at(species, pos, _spawn_mult() * (4.5 if elite else 1.0), false, 1.35 if elite else 1.0)
	if elite:
		e.flag = 1
		e.dmg *= 1.4
	(d["wave"] as Array).append(e)

## ------------------------------------------------ cycle 15 slots
## iS cost / rS weights / cS prizes (JW table @1077215).

func _slots_cost() -> int:
	# Cycle 21: gold-teeth discount (bundle tS on iS).
	return maxi(5, int(round(40.0 * _wc(2.0) * pow(1.08, float(_slot_spins)) * _teeth_mult())))

func _slots_spin() -> void:
	var cost := _slots_cost()
	if gold < float(cost):
		audio.deny()  # cycle 16
		spawn_floater(player.global_position + Vector3(0, 2.6, 0), "金币不足（需要 %d）" % cost, Color(0.9, 0.6, 0.5))
		return
	audio.slot_lever()
	gold -= float(cost)
	_slot_spins += 1
	_slot_spent += cost
	var luck_c := clampf(_luck_mult(), 1.0, 2.0)
	var gengar_open := int(_slot_prizes.get("gengar", 0)) < 15
	var table := [["seven", 0.018 * luck_c], ["pikachu", 0.05 * luck_c], ["berry", 0.09 * luck_c],
		["meowth", 0.1], ["voltorb", 0.06], ["gengar", 0.06 if gengar_open else 0.0]]
	var roll := _bless_rng.randf()
	var prize := "none"
	for row in table:
		if roll < float(row[1]):
			prize = String(row[0])
			break
		roll -= float(row[1])
	_slot_prizes[prize] = int(_slot_prizes.get(prize, 0)) + 1
	var pp := player.global_position
	match prize:
		"seven":
			audio.jackpot()
			show_banner("🎰 大奖！！三份宝藏！", 3.0)
			_chest_roll_single(3)
			_chest_roll_single(1)
			_chest_roll_single(1)
		"pikachu":
			audio.jackpot()
			show_banner("🎰 金橡果！一份宝藏", 2.5)
			_chest_roll_single(2)
		"berry":
			audio.heal()
			player.leech_heal(player.max_hp * 0.25)
			spawn_floater(pp + Vector3(0, 2.6, 0), "树果：回复 25%！", Color(0.55, 0.95, 0.5))
			_chest_roll_single(0)
		"meowth":
			audio.slot_coins()
			audio.coin()
			var win := int(round(float(cost) * 2.5))
			gold += float(win)
			show_banner("🎰 金币袋！金币 +%d" % win, 2.5)
		"gengar":
			audio.slot_curse()
			count_run_event("curses")
			player.temp_mods.append({"stat": "enemyAmount", "mul": 1.05})
			player.temp_mods.append({"stat": "difficulty", "mul": 1.05})
			player.recalc()
			show_banner("🎰 鬼火！诅咒降临：敌人更多更强…", 2.5)
		"voltorb":
			audio.zap()
			show_banner("🎰 咬人箱从机器里蹦了出来！", 2.5)
			_later(0.3, func() -> void: _slots_ambush())
		_:
			audio.slot_stop()
			spawn_floater(pp + Vector3(0, 2.6, 0), "什么也没中…", Color(0.8, 0.8, 0.85))

## lS @~1078560: 3 + stage ambush ringed 5-7u around the
## MACHINE, first spawn Elite (electrode at stage >= 2).
## Species mapped to the zone pool — voltorb/electrode
## have no models in our build (DIFF cycle 15).

func _slots_ambush() -> void:
	if _slots_prop.is_empty() or player == null or not is_instance_valid(player):
		return
	var cx := float(_slots_prop["x"])
	var cz := float(_slots_prop["z"])
	var n := 3 + zone
	var pool: Array = ZONES[zone - 1]["pool"]
	for i in range(n):
		var ang := float(i) / float(n) * TAU
		var dist := _bless_rng.randf_range(5.0, 7.0)
		var pos := Vector3(clampf(cx + cos(ang) * dist, -BOUND + 2.0, BOUND - 2.0), 0,
			clampf(cz + sin(ang) * dist, -BOUND + 2.0, BOUND - 2.0))
		pos.y = height_at(pos.x, pos.z)
		var sp := String(pool[_bless_rng.randi_range(0, pool.size() - 1)])
		var elite := i == 0
		var e := _spawn_enemy_at(sp, pos, _spawn_mult() * (4.5 if elite else 1.0), false, 1.35 if elite else 1.0)
		if elite:
			e.flag = 1
			e.dmg *= 1.4

## ------------------------------------------------ cycle 15 porygon
## By table @866978 (exact stat vocabulary of our blessing
## system); Vy @868812 pairs 3 shuffled gains with 3
## shuffled loss-capable entries outside the gain stats.

const PORYGON_BY := [
	{"stat": "damage", "gain": {"mul": 1.3}, "loss": {"mul": 0.85}},
	{"stat": "attackSpeed", "gain": {"mul": 1.25}, "loss": {"mul": 0.88}},
	{"stat": "maxHp", "gain": {"mul": 1.25}, "loss": {"mul": 0.85}},
	{"stat": "moveSpeed", "gain": {"mul": 1.2}, "loss": {"mul": 0.9}},
	{"stat": "critChance", "gain": {"add": 0.15}, "loss": {"add": -0.08}},
	{"stat": "area", "gain": {"mul": 1.3}, "loss": {"mul": 0.85}},
	{"stat": "xpGain", "gain": {"mul": 1.4}, "loss": {"mul": 0.8}},
	{"stat": "regen", "gain": {"add": 2.5}, "loss": {"mul": 0.6}},
	{"stat": "armor", "gain": {"add": 20.0}, "loss": {"mul": 0.75}},
	{"stat": "duration", "gain": {"mul": 1.4}, "loss": {"mul": 0.8}},
	{"stat": "statusChance", "gain": {"mul": 1.4}, "loss": {"mul": 0.8}},
	{"stat": "luck", "gain": {"add": 40.0}, "loss": {}},
]
const PORYGON_STAT_CN := {"damage": "伤害", "attackSpeed": "攻速", "maxHp": "最大生命",
	"moveSpeed": "移速", "critChance": "暴击率", "area": "范围", "xpGain": "经验",
	"regen": "回复/秒", "armor": "护甲", "duration": "状态持续", "statusChance": "状态概率", "luck": "幸运"}

func _porygon_mod_text(stat: String, m: Dictionary, is_gain: bool) -> String:
	var name := String(PORYGON_STAT_CN.get(stat, stat))
	if m.has("mul"):
		var pct := int(round((float(m["mul"]) - 1.0) * 100.0))
		return "%s %+d%%" % [name, pct]
	var add := float(m.get("add", 0.0))
	if stat == "critChance":
		return "%s %+d%%" % [name, int(round(add * 100.0))]
	return "%s +%s" % [name, _fmt_num(add)] if add >= 0.0 else "%s %s" % [name, _fmt_num(add)]

func _porygon_roll() -> Array:
	var gains := PORYGON_BY.duplicate()
	for i in range(gains.size() - 1, 0, -1):
		var j := _bless_rng.randi_range(0, i)
		var t = gains[i]
		gains[i] = gains[j]
		gains[j] = t
	gains = gains.slice(0, 3)
	var gain_stats: Array = []
	for g in gains:
		gain_stats.append(String(g["stat"]))
	var losses: Array = []
	for e in PORYGON_BY:
		if not (e["loss"] as Dictionary).is_empty() and not gain_stats.has(String(e["stat"])):
			losses.append(e)
	for i in range(losses.size() - 1, 0, -1):
		var j := _bless_rng.randi_range(0, i)
		var t = losses[i]
		losses[i] = losses[j]
		losses[j] = t
	var out: Array = []
	for i in range(3):
		out.append({"gain": gains[i], "loss": losses[i]})
	return out

func _porygon_open(p: Dictionary) -> void:
	var d: Dictionary = p["data"]
	if (d["offers"] as Array).is_empty():
		d["offers"] = _porygon_roll()
	var offers: Array = d["offers"]
	var opts: Array = []
	for o in offers:
		var g: Dictionary = o["gain"]
		var l: Dictionary = o["loss"]
		opts.append("重编译\n%s\n代价：%s" % [_porygon_mod_text(String(g["stat"]), g["gain"], true),
			_porygon_mod_text(String(l["stat"]), l["loss"], false)])
	_choice_show("机关匣 · 重编译", "选择一组重编译（本局生效）", opts, "离开（不选择）",
		func(idx: int) -> void:
			var o: Dictionary = offers[idx]
			var g: Dictionary = o["gain"]
			var l: Dictionary = o["loss"]
			var gm: Dictionary = {"stat": String(g["stat"])}
			gm.merge(g["gain"])
			var lm: Dictionary = {"stat": String(l["stat"])}
			lm.merge(l["loss"])
			player.recompiled_mods.append(gm)
			player.recompiled_mods.append(lm)
			player.recalc()
			_prop_set_used(p)
			show_banner("重编译完成：%s / %s" % [_porygon_mod_text(String(g["stat"]), g["gain"], true),
				_porygon_mod_text(String(l["stat"]), l["loss"], false)], 3.0),
		func() -> void: pass)

func _altar_update(a: Dictionary, pp: Vector3, delta: float) -> void:
	var cfg: Dictionary = ALTAR_CFG[int(a["tier"])]
	# Seal (tier 3 only, ZC.seal = 90 s of stage time).
	var sealed_now := elapsed < float(cfg["seal"])
	if sealed_now:
		a["sealed"] = true
		return
	if bool(a["sealed"]) and not bool(a["woke"]):
		a["woke"] = true
		show_banner("✦ %s 苏醒了！" % ALTAR_NAMES[int(a["tier"])], 2.5)
		spawn_nova(Vector3(float(a["x"]), height_at(float(a["x"]), float(a["z"])) + 1.0, float(a["z"])),
			6.0 + float(a["tier"]) * 3.0, cfg["color"])
	a["sealed"] = false
	if bool(a["used"]):
		return
	var d := Vector2(pp.x - float(a["x"]), pp.z - float(a["z"])).length()
	# Cycle 21: secret-key (altarUpdate @1267643): charge
	# time / (1 + .3 x stacks), and the drain halves while
	# any key is held.
	var sk := player.item_count("secret-key") if player else 0
	var s := float(cfg["charge"]) * (1.0 + 0.25 * float(mini(3, zone) - 1)) / (1.0 + 0.3 * float(sk))
	if d < float(cfg["r"]):
		a["out_t"] = 0.0
		a["charge"] = minf(1.0, float(a["charge"]) + delta / s)
		# Cycle 16: the bundle's altarUpdate plays
		# charge(min(1, charge)) while the player stands in
		# the radius (@1268185); our charge() self-throttles.
		audio.charge(float(a["charge"]))
		if int(cfg["wave"]) > 0:
			if not bool(a["warned"]):
				a["warned"] = true
				# Cycle 15: the comet variant of the wave
				# warning (altarUpdate @1267643).
				if bool(a.get("comet", false)):
					show_banner("彗星吸引了兽群！留在圈内！", 2.5)
				else:
					show_banner("未知图腾召唤了兽群！留在圈内！", 2.5)
			a["wave_t"] = float(a["wave_t"]) - delta
			if float(a["wave_t"]) <= 0.0:
				a["wave_t"] = s / float(cfg["wave"])
				a["wave_n"] = int(a["wave_n"]) + 1
				_altar_wave(a)
		if float(a["charge"]) >= 1.0:
			_altar_done(a)
	else:
		a["out_t"] = float(a["out_t"]) + delta
		if float(a["out_t"]) > 1.2:
			a["charge"] = maxf(0.0, float(a["charge"]) - delta / (float(cfg["drain"]) * (2.0 if sk > 0 else 1.0)))

## altarWave: (tier3 ? 4 : 3) + min(3, stage) enemies ringed 9-12 u
## around the altar, hp/dmg at the ZC.floor minutes floor; tier 3's
## first enemy of every even wave is Elite.
func _altar_wave(a: Dictionary) -> void:
	var cfg: Dictionary = ALTAR_CFG[int(a["tier"])]
	var tier := int(a["tier"])
	var n := (4 if tier == 3 else 3) + mini(3, zone)
	var pool: Array = ZONES[zone - 1]["pool"]
	var fmin := float(cfg["floor"])
	var eff := maxf(fmin, _eff_minutes())
	var hp_mult := _hp_curve(zone, eff) * _toughness_now()
	var cx := float(a["x"])
	var cz := float(a["z"])
	for l in range(n):
		var ang := float(l) / float(n) * TAU + _bless_rng.randf_range(-0.3, 0.3)
		var dist := _bless_rng.randf_range(9.0, 12.0)
		var pos := Vector3(clampf(cx + cos(ang) * dist, -BOUND + 2.0, BOUND - 2.0), 0,
			clampf(cz + sin(ang) * dist, -BOUND + 2.0, BOUND - 2.0))
		pos.y = height_at(pos.x, pos.z)
		var sp := String(pool[_bless_rng.randi_range(0, pool.size() - 1)])
		var elite := tier == 3 and l == 0 and int(a["wave_n"]) % 2 == 0
		var e := _spawn_enemy_at(sp, pos, hp_mult * (4.5 if elite else 1.0), false,
			1.35 if elite else 1.0, eff)
		if elite:
			e.flag = 1
			e.dmg *= 1.4

func _altar_done(a: Dictionary) -> void:
	a["used"] = true
	audio.bell()  # cycle 16: ringBell at altar completion (@1387268)
	var tier := int(a["tier"])
	var cfg: Dictionary = ALTAR_CFG[tier]
	spawn_nova(Vector3(float(a["x"]), height_at(float(a["x"]), float(a["z"])) + 1.0, float(a["z"])),
		6.0 + float(tier) * 3.0, cfg["color"])
	if tier >= 2:
		add_trauma(0.3)
		hitstop(0.12)
	offer_blessing(ALTAR_NAMES[tier], int(cfg["min"]), int(cfg["offers"]), int(cfg["picks"]))

func _altar_visual(a: Dictionary, delta: float) -> void:
	var cfg: Dictionary = ALTAR_CFG[int(a["tier"])]
	var col: Color = cfg["color"]
	var charge := float(a["charge"])
	a["spin"] = float(a["spin"]) + delta * (0.15 if bool(a["sealed"]) else 0.5 + charge * 1.6)
	# Unown orbit (unownPos): radius 3.1 - 1.3 charge, height
	# 2.6 + bob + .8 charge.
	var unowns: Array = a["unowns"]
	for k in range(unowns.size()):
		var ang := float(a["spin"]) + TAU * float(k) / float(maxi(unowns.size(), 1))
		var u := unowns[k] as MeshInstance3D
		u.position = Vector3(cos(ang) * (3.1 - charge * 1.3),
			2.6 + sin(Time.get_ticks_msec() * 0.0018 + float(k) * 2.0) * 0.35 + charge * 0.8,
			sin(ang) * (3.1 - charge * 1.3))
		u.rotation.y = -ang
	# Crystal tint: grey while sealed, dim when spent.
	var cm := a["cmat"] as StandardMaterial3D
	if bool(a["used"]):
		cm.albedo_color = Color(0.3, 0.3, 0.32)
		cm.emission_energy_multiplier = 0.0
	elif bool(a["sealed"]):
		cm.albedo_color = Color(0.55, 0.55, 0.6)
		cm.emission_energy_multiplier = 0.15
	else:
		cm.albedo_color = col
		cm.emission_energy_multiplier = 0.8 + charge * 0.9
	(a["crys"] as Node3D).rotation.y = float(a["spin"]) * 0.6
	# Charge fan: rebuild on bucket change only.
	var bucket := int(charge * 24.0)
	if bucket != int(a["bucket"]):
		a["bucket"] = bucket
		var prog := a["prog"] as MeshInstance3D
		prog.mesh = _ring_fan(float(cfg["r"]), charge, Color(col, 0.55)) if charge > 0.001 else null

func _ring_fan(r: float, frac: float, col: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var segs := clampi(int(round(28.0 * frac)), 1, 28)
	for i in range(segs):
		var t0 := float(i) / 28.0 * TAU
		var t1 := float(i + 1) / 28.0 * TAU
		var base := verts.size()
		for t in [t0, t1]:
			verts.append(Vector3(cos(t) * (r - 0.28), 0.0, sin(t) * (r - 0.28)))
			verts.append(Vector3(cos(t) * (r + 0.28), 0.0, sin(t) * (r + 0.28)))
			cols.append(col)
			cols.append(col)
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## ------------------------------------------------ roar totem (zy)

func _totem_label(tot: Dictionary) -> String:
	if bool(tot["used"]) or boss_spawned:
		return "犀牛图腾沉睡中 · 已咆哮 %d 次" % run_roars
	if run_roars > 0:
		return "咆哮神龛（%d/3）· 再吼：守护者 +30%% 生命、+1 金纹宝箱" % run_roars
	return "咆哮神龛 · 互动咆哮：守护者更强，但击败掉落 +1 金纹宝箱/次"

func _roar_at_totem(tot: Dictionary) -> void:
	var tp := Vector3(float(tot["x"]), height_at(float(tot["x"]), float(tot["z"])), float(tot["z"]))
	if boss_spawned:
		spawn_floater(tp + Vector3(0, 3.4, 0), "守护者已经苏醒，图腾没有回应", Color(0.8, 0.8, 0.85))
		return
	run_roars += 1
	var n := run_roars
	# Cycle 16: the totem answers with the Rhydon's cry + boom.
	audio.cry("rhydon")
	audio.boom(0.5)
	if n >= 3:
		tot["used"] = true
	tot["horn_t"] = 0.9
	spawn_nova(tp + Vector3(0, 0.5, 0), 10.0 + 3.0 * float(n), Color(200.0 / 255.0, 120.0 / 255.0, 58.0 / 255.0))
	spawn_nova(tp + Vector3(0, 0.5, 0), 6.0 + 2.0 * float(n), Color(1.0, 0.85, 0.3))
	add_trauma(0.35 + 0.12 * float(n))
	hitstop(0.08)
	show_banner("🦏 犀牛咆哮！（%d/3）\n守护者将以 +%d%% 生命、+%d%% 伤害登场，精英护卫更多；击败后 +%d 个金纹宝箱" % [
		mini(n, 3), n * 30, n * 12, n], 3.5)

## The live zone's totem when the player is inside its interact
## radius (r 3.2 + .8), else an empty dict.
func _totem_near(flat_p: Vector2) -> Dictionary:
	var st: Dictionary = _inter_state.get(zone, {})
	if st.is_empty():
		return {}
	var tot: Dictionary = st["totem"]
	if flat_p.distance_to(Vector2(float(tot["x"]), float(tot["z"]))) < 4.0:
		return tot
	return {}

## Blessing-altar proximity hint (altars charge by presence — the
## bundle excludes them from the E-interact chain; the label is
## informational only).
func _altar_hint(flat_p: Vector2) -> String:
	var st: Dictionary = _inter_state.get(zone, {})
	if st.is_empty():
		return ""
	for a in st["altars"]:
		var cfg: Dictionary = ALTAR_CFG[int(a["tier"])]
		if flat_p.distance_to(Vector2(float(a["x"]), float(a["z"]))) < float(cfg["r"]) + 0.8:
			if bool(a["used"]):
				return "祭坛已耗尽"
			if bool(a["sealed"]):
				return "%s · 尚未苏醒（%d 秒）" % [ALTAR_NAMES[int(a["tier"])], int(ceil(float(cfg["seal"]) - elapsed))]
			var pct := ""
			if float(a["charge"]) > 0.0:
				pct = " · 充能 %d%%" % int(float(a["charge"]) * 100.0)
			return "%s · 站在圈内为其充能%s" % [ALTAR_NAMES[int(a["tier"])], pct]
	return ""

## ------------------------------------------------ blessings

func _build_blessing(root: Control) -> void:
	_blessing_panel = PanelContainer.new()
	_blessing_panel.set_anchors_preset(Control.PRESET_CENTER)
	_blessing_panel.offset_left = -430
	_blessing_panel.offset_right = 430
	_blessing_panel.offset_top = -198  # cycle 19: +team row
	_blessing_panel.offset_bottom = 198
	_blessing_panel.visible = false
	_blessing_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_blessing_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_blessing_panel.add_child(vb)
	# 对齐定稿 S14_v1.jpg：金色月桂枝＋粗深棕大字标题＋高对比副标题
	if _p5_on:
		var bt_wrap := CenterContainer.new()
		vb.add_child(bt_wrap)
		var bt_row := HBoxContainer.new()
		bt_row.add_theme_constant_override("separation", 8)
		bt_wrap.add_child(bt_row)
		var ll := UiTheme.art("laurel_gold", Vector2(26, 30))
		ll.flip_h = true
		bt_row.add_child(ll)
		_blessing_title = _mk_dlabel(bt_row, "", 26, UiTheme.TEXT)
		_blessing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lr := UiTheme.art("laurel_gold", Vector2(26, 30))
		bt_row.add_child(lr)
	else:
		_blessing_title = _mk_dlabel(vb, "", 24, UiTheme.TEXT)
		_blessing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blessing_sub = _mk_label(vb, "", 15, Color("5e4427"))
	_blessing_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blessing_opts_box = HBoxContainer.new()
	_blessing_opts_box.add_theme_constant_override("separation", 10)
	_blessing_opts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_blessing_opts_box)
	# Cycle 19 (audit punch #13): the bundle appends the
	# "Ver mi equipo" [Tab] button to the blessing modal
	# too (Yk @1552417, body at @2064649).
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_END if _p5_on else BoxContainer.ALIGNMENT_CENTER
	vb.add_child(team_row)
	var team_b := UiTheme.make_button("查看我的队伍 [Tab]", "ghost", "small")
	team_b.pressed.connect(func() -> void:
		audio.click()
		_open_team_view())
	team_row.add_child(team_b)
	_blessing_team_btn = team_b  # UI-mobile P1.1

## offerBlessing @1481319: while another modal owns the run the
## blessing queues (their whenFree); else it opens at once.
func offer_blessing(title: String, min_tier: int, n_offers: int, picks: int, power_mult: float = 1.0) -> void:
	if _blessing_open or state in ["draft", "dead", "victory", "menu", "blessing", "choice"]:
		_blessing_queue.append({"title": title, "min": min_tier, "offers": n_offers, "picks": picks, "power": power_mult})
		return
	_blessing_return = state
	_blessing_offers = _blessing_roll(min_tier, n_offers, power_mult)
	_blessing_picks_left = picks
	_blessing_open = true
	state = "blessing"
	running = false
	_blessing_title.text = title + " · 祝福"
	_blessing_opened_msec = Time.get_ticks_msec()
	_render_blessing()
	_blessing_panel.visible = true

## Blessing cards (UI_SPEC §2.6): rarity-colored rim, top
## zone washed in the rarity color with the stat icon, the
## rarity chip, and the [n] key footer.
func _render_blessing() -> void:
	_blessing_sub.text = "选择一项祝福（本祭坛还可选 %d 次）" % _blessing_picks_left
	for c in _blessing_opts_box.get_children():
		c.queue_free()
	for i in range(_blessing_offers.size()):
		var offer: Dictionary = _blessing_offers[i]
		var rar := int(offer["rarity"])
		var rar_c := UiTheme.rarity_color(rar)
		# Icon order 2: heights follow the frames' equal ratio
		# (216 -> 300 phone / 258 desktop at these widths).
		var bsz := Vector2(_p5_card_w(_blessing_panel, _blessing_offers.size(), 220.0), 300.0) \
			if _p5_on else Vector2(190, 258)
		var card := UiTheme.make_card(rar_c, bsz, rar)
		var top := Panel.new()
		top.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top.offset_left = 14
		top.offset_right = -14
		top.offset_top = 15
		top.offset_bottom = 148
		var tc := rar_c
		tc.a = 0.88
		var top_sb := UiTheme.flat_box(tc, 10)
		top_sb.corner_radius_top_left = 16
		top_sb.corner_radius_top_right = 16
		top.add_theme_stylebox_override("panel", top_sb)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(top)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/glyphs/glyph_blessing.png")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(76, 76)
		ic.position = Vector2((bsz.x - 76.0) * 0.5, 42)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ic)
		var rchip := UiTheme.chip(String(GameData.RARITY_NAMES[rar]), rar_c.darkened(0.15), 14)
		var rlab := rchip.get_child(0) as Label
		if UiTheme.luminance(rar_c) < 0.75:
			rlab.add_theme_color_override("font_color", Color.WHITE)
		rchip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		rchip.offset_left = -78
		rchip.offset_right = -10
		rchip.offset_top = 10
		rchip.offset_bottom = 38
		card.add_child(rchip)
		# 定稿 S14_v1.jpg：效果数字居中于下方奶油区，深棕粗体醒目清晰不压边界
		var flow := VBoxContainer.new()
		flow.set_anchors_preset(Control.PRESET_FULL_RECT)
		flow.offset_left = 12
		flow.offset_right = -12
		flow.offset_top = 166
		flow.offset_bottom = -10
		flow.add_theme_constant_override("separation", 4)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(flow)
		var tl := Label.new()
		tl.text = String(offer["label"])
		tl.add_theme_font_override("font", UiTheme.display_font())
		tl.add_theme_font_size_override("font_size", 19)
		tl.add_theme_color_override("font_color", UiTheme.TEXT)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(tl)
		var bsp := Control.new()
		bsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(bsp)
		var krow := HBoxContainer.new()
		krow.alignment = BoxContainer.ALIGNMENT_CENTER
		krow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(krow)
		krow.add_child(UiTheme.kbd("[%d]" % (i + 1)))
		krow.visible = not _touch_wanted()  # UI-mobile P5 (plan M1/M2)
		var idx := i
		card.pressed.connect(func() -> void: _apply_blessing_offer(idx))
		_blessing_opts_box.add_child(card)

## The pick path (blessing buttons connect here; the harness drives
## it too): tempMods.push + recompute, re-pick from the REMAINING
## offers while picks last, then resume.
func _apply_blessing_offer(idx: int) -> void:
	if not _blessing_open or idx < 0 or idx >= _blessing_offers.size():
		return
	var offer: Dictionary = _blessing_offers[idx]
	run_blessings.append(String(offer["label"]))  # cycle 18: results pacts
	for m in offer["mods"]:
		player.temp_mods.append((m as Dictionary).duplicate())
	player.recalc()
	audio.power()  # cycle 16: blessing pick
	spawn_floater(player.global_position + Vector3(0, 2.6, 0), String(offer["label"]), Color(1.0, 0.9, 0.45))
	_blessing_offers.remove_at(idx)
	_blessing_picks_left -= 1
	if _blessing_picks_left > 0 and not _blessing_offers.is_empty():
		_render_blessing()
	else:
		_close_blessing()

func _close_blessing() -> void:
	_blessing_panel.visible = false
	_blessing_open = false
	state = _blessing_return
	running = true

## Xx @1075554: shuffle the 12 generators, take n; each offer's
## tier = max(minT, Bx) and its power = pe[tier].
func _blessing_roll(min_tier: int, n: int, power_mult: float = 1.0) -> Array:
	var defs := BLESSING_DEFS.duplicate()
	for i in range(defs.size() - 1, 0, -1):
		var j := _bless_rng.randi_range(0, i)
		var t = defs[i]
		defs[i] = defs[j]
		defs[j] = t
	var out: Array = []
	for k in range(mini(n, defs.size())):
		var d: Dictionary = defs[k]
		var tier := maxi(min_tier, _blessing_tier_roll())
		var e := float(BLESSING_PE[tier]) * power_mult
		var per := float(d["per"])
		var mod := {"stat": String(d["stat"])}
		if String(d["mode"]) == "mul":
			mod["mul"] = 1.0 + per * e
		else:
			mod["add"] = per * e
		var label: String
		if bool(d.get("dec", false)):
			label = String(d["label"]) % ("%.1f" % (per * e))
		elif String(d["mode"]) == "mul" or bool(d.get("pct", false)):
			label = String(d["label"]) % int(round(per * e * 100.0))
		else:
			label = String(d["label"]) % int(round(per * e))
		out.append({"label": label, "mods": [mod], "rarity": tier, "stat": String(d["stat"])})
	return out

## Bx @1069962 rarity roll (min 0 — Xx maxes with its own minT).
func _blessing_tier_roll() -> int:
	var i := maxf(0.0, player.luck if player else 0.0)
	var a := i / 100.0
	var o := float(player.level if player else 1) + i / 8.0 + float(zone - 1) * 12.0
	var s := func(lo: float, hi: float) -> float: return clampf((o - lo) / (hi - lo), 0.0, 1.0)
	var w := [70.0 / (1.0 + a), 24.0 * (1.0 + 0.5 * a),
		5.0 * pow(1.0 + a, 2.0) * s.call(3.0, 10.0),
		0.9 * pow(1.0 + a, 3.0) * s.call(8.0, 18.0),
		0.12 * pow(1.0 + a, 4.0) * s.call(14.0, 26.0)]
	var total := 0.0
	for x in w:
		total += float(x)
	if total <= 0.0:
		return 0
	var roll := _bless_rng.randf() * total
	for t in range(5):
		roll -= float(w[t])
		if roll <= 0.0:
			return t
	return 4

## A free chest (cycle 9): a red/white ball chest on the ground.
## Walk within 2.3 u to open it (the original's interactable
## radius is 2.6, @1238236 region; ours is a proximity open since
## this build has no interact key channel for objects).
func spawn_supply_chest(pos: Vector3, super_ball: bool) -> void:
	_spawn_chest(pos)
	var c: Dictionary = _chests.back()
	c["super_ball"] = super_ball
	c["fall_y"] = pos.y
	c["fall_v"] = 0.0
	c.node.position.y += 22.0

func _spawn_chest(pos: Vector3) -> void:
	pos.x = clamp(pos.x, -BOUND + 2.0, BOUND - 2.0)
	pos.z = clamp(pos.z, -BOUND + 2.0, BOUND - 2.0)
	pos.y = height_at(pos.x, pos.z)
	var n := Node3D.new()
	var top := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.42
	tm.height = 0.84
	tm.radial_segments = 14
	tm.rings = 7
	top.mesh = tm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.16, 0.14)
	top.material_override = red
	top.scale = Vector3(1, 0.62, 1)
	top.position = Vector3(0, 0.30, 0)
	n.add_child(top)
	var bot := MeshInstance3D.new()
	bot.mesh = tm
	var wh := StandardMaterial3D.new()
	wh.albedo_color = Color(0.92, 0.92, 0.9)
	bot.material_override = wh
	bot.scale = Vector3(1, -0.62, 1)
	bot.position = Vector3(0, 0.30, 0)
	n.add_child(bot)
	var btn := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	btn.mesh = bm
	btn.material_override = wh
	btn.position = Vector3(0, 0.32, 0.40)
	n.add_child(btn)
	add_child(n)
	n.global_position = pos
	_chests.append({"node": n, "opened": false})

func _open_chest(c: Dictionary) -> void:
	c["opened"] = true
	audio.chest()  # cycle 16
	var n = c["node"]
	if is_instance_valid(n):
		n.queue_free()
	# Cycle 21: the guardian chest rolls a real item
	# (rollChestItem floor 0, count 1 — the item roll
	# counts the chest event and shows take-or-sell).
	_roll_chest_item(0, 1)  # super_ball style retained; its reward policy is outside pack §2

## Vitamin grant shared by the draft and chest rewards: feeds the
## player's accumulator and re-derives stats (same math the draft
## applies — see _apply_draft_choice's vitamin branch).
func _grant_vitamin(key: String, pe: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var vd: Dictionary = GameData.VITAMINS[key]
	var acc := String(vd["acc"])
	player.vit[acc] = float(player.vit.get(acc, 0.0)) + float(vd["per"]) * pe
	player.vit_levels[key] = int(player.vit_levels.get(key, 0)) + 1
	player.recalc()

func chests_positions() -> Array:
	var out: Array = []
	for c in _chests:
		if not bool(c["opened"]) and is_instance_valid(c["node"]):
			out.append((c["node"] as Node3D).global_position)
	return out

## Portal entry: advance to the next zone, or (zone 4) victory.
func _on_portal_entered() -> void:
	if zone < 4:
		if _switch_pending == 0 and not _scene_cache.has(zone + 1):
			# Uncached scene (prebuild aborted or still running):
			# give the loading banner one rendered frame before
			# the data-warm build stall; _process performs the
			# switch on the next frame.
			_switch_pending = zone + 1
			show_banner("正在开辟下一区域…", 3.0)
			return
		_advance_zone()
	else:
		_finish_run(true)

func _advance_zone() -> void:
	audio.whoosh()  # cycle 16: portal transit
	zone += 1
	state = "playing"
	elapsed = 0.0
	_zone_t = 0.0  # cycle 21: event clock is per-stage
	_event_try_t = 60.0
	if _event_kind != "":
		_event_kind = ""
		apply_weather_look()
	boss_spawned = false  # cycle 14: bossSpawned is per-stage (zy)
	_comet_clear()  # cycle 15: the stage's list is rebuilt —
		# the comet ref dies with it (updateComet); timer runs on
	_swarm = false
	_swarm_announced = false
	_alpha_idx = 0
	if _boost_honey:
		_honey_at = 240.0  # cycle 18: honey re-arms per zone (bundle schedule)
	# Cycle 20: the bundle's stage setup re-rolls the shiny
	# probability and clears shinySpawned per stage (roll
	# @1048868); a live shiny dies with the old stage's
	# rebuild like the league one.
	_roll_shiny_director()
	_roll_classic_director()
	_shiny_e = null
	_league_e = null
	_league_done = false
	_league_spawn_at = _rng.randf_range(50.0, 120.0)
	guardian = null
	if portal_node:
		portal_node.queue_free()
		portal_node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	_pal = ZONES[zone - 1]["pal"]
	_apply_zone_visuals()
	_weather_pick(zone)  # cycle 12: stage-entry base weather re-pick
	_altar_label.visible = true
	player.global_position = Vector3(SPAWN_XZ.x, height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)
	player.reset_physics_interpolation()
	# Allies are in-run companions (§5.3): they follow through the
	# portal instead of being left behind.
	for a in get_tree().get_nodes_in_group("allies"):
		a.global_position = player.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		a.reset_physics_interpolation()
	_cam_focus = player.global_position
	_apply_zone_card()
	_refresh_hud()
	show_banner("第 %d 关 · %s — 继续向祭坛进发！" % [zone, String(ZONES[zone - 1]["cn"])], 4.0)

## ---- Cycle 12: scene park / restore / prebuild -------------------

## Detach the live zone's scene into its cache entry (nodes are
## kept alive, just out of the tree).
func _park_live_scene() -> void:
	if _live_zone == 0 or not _scene_cache.has(_live_zone):
		return
	var e: Dictionary = _scene_cache[_live_zone]
	e["terrain_mi"] = _terrain_mi
	if _terrain_mi and _terrain_mi.get_parent() == self:
		remove_child(_terrain_mi)
	_terrain_mi = null
	var dn: Array = []
	for c in _dress_root.get_children():
		_dress_root.remove_child(c)
		dn.append(c)
	e["dress_nodes"] = dn
	var wn: Array = []
	if _water_root:
		for c in _water_root.get_children():
			_water_root.remove_child(c)
			wn.append(c)
	e["water_nodes"] = wn
	# Cycle 14: the interactables root parks with the scene.
	var ir = e.get("inter_root")
	if ir and is_instance_valid(ir) and (ir as Node).get_parent() == self:
		remove_child(ir)

## Bring a cached zone's scene back into the tree.
func _restore_scene(z: int) -> void:
	var e: Dictionary = _scene_cache[z]
	_terrain_mi = e["terrain_mi"]
	if _terrain_mi:
		add_child(_terrain_mi)
	for c in e["dress_nodes"]:
		_dress_root.add_child(c)
	for c in e["water_nodes"]:
		_water_root.add_child(c)
	var ir2 = e.get("inter_root")
	if ir2 and is_instance_valid(ir2):
		add_child(ir2)
	_props = (e["props"] as Array).duplicate()
	minimap_baked = e["minimap"]
	if _minimap:
		_minimap.baked = minimap_baked
	_live_zone = z

## The historical full build, into the tree, for the active zone
## (member data + zone + _pal already set). Registers the result
## as the zone's live cache entry.
func _build_live_scene() -> void:
	_build_terrain()
	_build_water()
	_bake_minimap()
	if _minimap:
		_minimap.baked = minimap_baked
	_props = [Vector3(ALTAR_XZ.x, ALTAR_XZ.y, 2.7)]  # altar pedestal (_build_altar)
	_pk.clear()
	_rng.seed = 7 + zone * 13
	_build_props()
	_build_set_dressing()
	_cull_subtree(_dress_root)
	var iroot := _build_interactables(zone)
	_scene_cache[zone] = {"terrain_mi": _terrain_mi, "dress_nodes": [],
		"water_nodes": [], "props": _props.duplicate(), "minimap": minimap_baked,
		"inter_root": iroot}
	_live_zone = zone

## Menu-time prebuild of zones 2-4 (data from the worker threads,
## scenes phase-sliced so the menu stays live). Aborted cleanly by
## start_game: the partial scene is freed and the live zone's state
## restored; a later portal falls back to the build path.
func _prebuild_scenes() -> void:
	if _prebuild_running:
		return
	_prebuild_running = true
	_prebuild_abort = false
	_slice_builds = true
	var live := _live_zone
	var live_mi = _terrain_mi
	var live_minimap = minimap_baked
	for z in range(2, 5):
		if _prebuild_abort or _scene_cache.has(z):
			continue
		if _terrain_tasks.has(z):
			while not WorkerThreadPool.is_task_completed(int(_terrain_tasks[z])):
				if _prebuild_abort:
					break
				await get_tree().process_frame
		if _prebuild_abort:
			break
		zone = z
		_pal = ZONES[z - 1]["pal"]
		_apply_zone_data(_zone_data(z))
		var dress_holder := Node3D.new()
		var water_holder := Node3D.new()
		_dress_target = dress_holder
		_water_target = water_holder
		var props_save: Array = _props
		_props = [Vector3(ALTAR_XZ.x, ALTAR_XZ.y, 2.7)]
		_pk.clear()
		_rng.seed = 7 + z * 13
		await _build_terrain()
		var mi_z = _terrain_mi if _terrain_mi != live_mi else null
		if not _prebuild_abort:
			if mi_z:
				remove_child(mi_z)
			_terrain_mi = live_mi
			await _build_water()
		if not _prebuild_abort:
			await _bake_minimap()
		var map_z = minimap_baked
		minimap_baked = live_minimap
		if not _prebuild_abort:
			await _build_props()
		if not _prebuild_abort:
			_build_set_dressing()
			_cull_subtree(dress_holder)
		_dress_target = null
		_water_target = null
		# Cycle 14: interactables build into a detached holder too.
		var inter_holder := Node3D.new()
		var iroot_z: Node3D = null
		if not _prebuild_abort:
			_inter_target = inter_holder
			iroot_z = _build_interactables(z)
			_inter_target = null
			inter_holder.remove_child(iroot_z)
		if _prebuild_abort:
			if mi_z and is_instance_valid(mi_z):
				if mi_z.get_parent():
					mi_z.get_parent().remove_child(mi_z)
				mi_z.queue_free()
			_terrain_mi = live_mi
			dress_holder.queue_free()
			water_holder.queue_free()
			inter_holder.queue_free()
			_props = props_save
			break
		inter_holder.queue_free()
		var dnodes: Array = []
		for c in dress_holder.get_children():
			dress_holder.remove_child(c)
			dnodes.append(c)
		var wnodes: Array = []
		for c in water_holder.get_children():
			water_holder.remove_child(c)
			wnodes.append(c)
		dress_holder.queue_free()
		water_holder.queue_free()
		_scene_cache[z] = {"terrain_mi": mi_z, "dress_nodes": dnodes,
			"water_nodes": wnodes, "props": _props.duplicate(), "minimap": map_z,
			"inter_root": iroot_z}
		_props = props_save
		print("C12 prebuild: zone ", z, " scene cached")
	zone = live
	_pal = ZONES[live - 1]["pal"]
	_apply_zone_data(_zone_data(live))
	_slice_builds = false
	_prebuild_running = false

## Terrain + dressing + minimap for the active zone config: a warm
## cache restores in ~ms; anything else takes the full build path.
func _apply_zone_visuals() -> void:
	_zone_fog_base = ZONES[zone - 1]["fog"]
	var t0 := Time.get_ticks_msec()
	if _live_zone != 0 and _live_zone != zone:
		_park_live_scene()
	if _live_zone == zone and _scene_cache.has(zone):
		_apply_zone_data(_zone_data(zone))
	elif _scene_cache.has(zone):
		_apply_zone_data(_zone_data(zone))
		_restore_scene(zone)
		print("C12 switch zone ", zone, ": cached restore ", Time.get_ticks_msec() - t0, " ms")
	else:
		_apply_zone_data(_zone_data(zone))
		_build_live_scene()
		print("C12 switch zone ", zone, ": full build ", Time.get_ticks_msec() - t0, " ms")
	apply_weather_look()

## ---- Cycle 12: weather (spec in DIFF cycle 12; bundle offsets) ---
## States: clear/rain/sun/sand/hail/fog/ash. Base weather is picked
## per zone entry from the biome's candidate list, overridden by a
## weather passive on the player (drizzle/drought/sand-stream/
## snow-warning hooks). Timed weather (set_weather, from boss kits
## in the original — kits unported, so the API's in-game triggers
## land with them) reverts to base on expiry.

const WEATHER_TABLE := {
	"clear": {"cn": "晴", "boost": [], "nerf": []},
	"rain": {"cn": "雨", "boost": ["water", "electric"], "nerf": ["fire"]},
	"sun": {"cn": "烈日", "boost": ["fire", "grass"], "nerf": ["water"]},
	"sand": {"cn": "沙暴", "boost": ["rock", "ground", "steel"], "nerf": []},
	"hail": {"cn": "冰雹", "boost": ["ice"], "nerf": []},
	"fog": {"cn": "雾", "boost": ["ghost", "dark"], "nerf": []},
	"ash": {"cn": "灰烬雨", "boost": ["fire", "dragon"], "nerf": ["ice"]},
}
var weather := "clear"
var base_weather := "clear"
var weather_t := 0.0        # timed-weather seconds remaining
var _zone_fog_base := Color(0.749, 0.89, 1.0)  # active zone's fog color
var _weather_rng := RandomNumberGenerator.new()
var _wx_root: Node3D = null          # precipitation emitters (follow camera)
var _wx_emitters := {}               # weather id -> GPUParticles3D
var _wx_hazard_armed := false        # rand<dt*2 gate state (debug/test visibility)

const _WX_FOG_NEAR := 40.0   # our zone look bases (bundle defaults)
const _WX_FOG_FAR := 160.0
const _WX_SUN_BASE := 1.65
const _WX_AMB_BASE := 1.05
const _WX_SKY_BOTTOM := Color(0.847, 0.941, 1.0)  # #d8f0ff

func _weather_pick(z: int) -> void:
	# Stage entry (bundle @1446551): uniform pick from the biome's
	# candidate list; the player's weather passive overrides. Our
	# RNG is fixed-seed (distribution-equivalent, deterministic
	# under test — the house treatment, cf. terrain seeds).
	var list: Array = ZONES[z - 1].get("weather", ["clear"])
	base_weather = String(list[_weather_rng.randi_range(0, list.size() - 1)])
	if player and is_instance_valid(player):
		var hooks := GameData.passive_hooks(player.passive_id)
		if hooks.has("weather"):
			base_weather = String(hooks["weather"])
	weather = base_weather
	weather_t = 0.0
	apply_weather_look()

func set_base_weather(w: String) -> void:
	# Bundle @1452859: applies immediately only when no timed
	# weather is running.
	base_weather = w
	if weather_t <= 0.0:
		weather = w
		apply_weather_look()
		_refresh_weather_chip()

func set_weather(w: String, secs: float) -> void:
	# Bundle @1452897: timed override + toast + look.
	weather = w
	weather_t = secs
	apply_weather_look()
	_refresh_weather_chip()
	show_banner("天气变化：%s！" % String(WEATHER_TABLE[w]["cn"]), 2.5)

## Strike-pipeline weather multiplier (bundle @723641: boost x1.3,
## nerf x0.75). Called from combat_hit (player/ally strikes only,
## never for fixed/environmental damage).
func weather_damage_mul(move_type: String) -> float:
	var row: Dictionary = WEATHER_TABLE[weather]
	if (row["boost"] as Array).has(move_type):
		return 1.3
	if (row["nerf"] as Array).has(move_type):
		return 0.75
	return 1.0

## Bundle applyWeatherLook @1452968 mapped onto our environment:
## fog distances scale off the zone base (40/160), fog color and
## sky bottom per the table, sun + ambient scale with the light
## factor. (Their shared uWind sway has no counterpart in our
## deco shader — recorded as a gap in DIFF, not faked.)
func apply_weather_look() -> void:
	if _env == null:
		return
	var near_mul := 1.0
	var far_mul := 1.0
	match weather:
		"fog":
			near_mul = 0.5
			far_mul = 0.6
		"sand":
			near_mul = 0.6
			far_mul = 0.7
		"hail":
			near_mul = 0.7
			far_mul = 0.75
		"rain":
			far_mul = 0.85
	_env.fog_depth_begin = _WX_FOG_NEAR * near_mul
	_env.fog_depth_end = _WX_FOG_FAR * far_mul
	var fog_col := _zone_fog_base
	match weather:
		"sand":
			fog_col = Color(0.847, 0.725, 0.502)       # 14203008 #D8B980
		"rain":
			fog_col = _zone_fog_base * 0.8
		"hail":
			fog_col = _zone_fog_base.lerp(Color(0.91, 0.957, 1.0), 0.5)  # -> 15266559
	_env.fog_light_color = fog_col
	if _sky_mat:
		_sky_mat.sky_horizon_color = Color(0.604, 0.718, 0.784) if weather == "rain" else _WX_SKY_BOTTOM
	var light_mul := 1.0
	if weather == "rain":
		light_mul = 0.8
	elif weather == "sun":
		light_mul = 1.15
	if _sun:
		_sun.light_energy = _WX_SUN_BASE * light_mul
	_env.ambient_light_energy = _WX_AMB_BASE * light_mul
	_wx_refresh_emitters()

## Precipitation: one GPUParticles3D per weather kind under a root
## that follows the camera (their spawns are camera-centred +-25).
## Amounts are rate x lifetime from the spec, capped for fill rate
## (fog) and node-less GPU cost; velocities/lifetimes/sizes/colors
## are the bundle's (weatherFx @1489897).
func _wx_soft_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for j in range(64):
		for i in range(64):
			var d := Vector2(float(i) - 31.5, float(j) - 31.5).length() / 31.5
			var a := pow(maxf(0.0, 1.0 - d), 2.0)
			img.set_pixel(i, j, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _wx_scale_curve(a: float, b: float) -> CurveTexture:
	var cv := Curve.new()
	cv.add_point(Vector2(0, a))
	cv.add_point(Vector2(1, b))
	var ct := CurveTexture.new()
	ct.curve = cv
	return ct

func _wx_make_emitter(kind: String, soft: Texture2D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-70, -40, -70), Vector3(140, 90, 140))
	p.draw_pass_1 = QuadMesh.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 5, 25)
	pm.gravity = Vector3.ZERO
	pm.spread = 0.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := p.draw_pass_1 as QuadMesh
	match kind:
		"rain":
			p.amount = 700
			p.lifetime = 0.55
			p.position.y = 7.0
			pm.direction = Vector3(0.077, -1, 0)
			pm.initial_velocity_min = 26.0
			pm.initial_velocity_max = 26.0
			quad.size = Vector2(0.06, 0.55)
			mat.albedo_color = Color(0.604, 0.78, 1.0, 0.55)  # 10143999 #9AC7FF
		"sand":
			p.amount = 600
			p.lifetime = 1.4
			p.position.y = -1.0
			pm.direction = Vector3(0.96, -0.07, 0.27)
			pm.initial_velocity_min = 14.6
			pm.initial_velocity_max = 14.6
			pm.scale_curve = _wx_scale_curve(0.5, 0.9)
			quad.size = Vector2(1, 1)
			mat.albedo_texture = soft
			mat.albedo_color = Color(0.847, 0.725, 0.502, 0.5)  # 14203008
		"hail":
			p.amount = 450
			p.lifetime = 1.0
			p.position.y = 7.0
			pm.direction = Vector3(0.07, -1, 0)
			pm.initial_velocity_min = 14.0
			pm.initial_velocity_max = 14.0
			pm.angular_velocity_min = -230.0
			pm.angular_velocity_max = 230.0
			quad.size = Vector2(0.2, 0.2)
			mat.albedo_color = Color(1, 1, 1, 0.9)
		"ash":
			p.amount = 800
			p.lifetime = 3.0
			p.position.y = 7.0
			pm.direction = Vector3(0, -1, 0)
			pm.spread = 30.0
			pm.initial_velocity_min = 2.2
			pm.initial_velocity_max = 2.2
			pm.scale_curve = _wx_scale_curve(0.18, 0.1)
			quad.size = Vector2(1, 1)
			mat.albedo_texture = soft
			mat.albedo_color = Color(1.0, 0.616, 0.384, 0.8)  # 16747066 #FF9D62
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.616, 0.384)
			mat.emission_energy_multiplier = 0.6
		"fog":
			p.amount = 90
			p.lifetime = 4.0
			p.position.y = -3.0
			pm.emission_box_extents = Vector3(25, 2, 25)
			pm.direction = Vector3(0.85, 0, 0.5)
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 0.6
			pm.scale_curve = _wx_scale_curve(6.0, 9.0)
			quad.size = Vector2(1, 1)
			mat.albedo_texture = soft
			mat.albedo_color = Color(0.69, 0.612, 0.471, 0.13)  # 11575496 #B09C78
	p.process_material = pm
	quad.material = mat
	return p

func _wx_refresh_emitters() -> void:
	if _wx_root == null:
		_wx_root = Node3D.new()
		_wx_root.name = "Weather"
		add_child(_wx_root)
		var soft := _wx_soft_texture()
		for kind in ["rain", "sand", "hail", "ash", "fog"]:
			var e := _wx_make_emitter(kind, soft)
			_wx_root.add_child(e)
			_wx_emitters[kind] = e
	for kind in _wx_emitters:
		(_wx_emitters[kind] as GPUParticles3D).emitting = kind == weather

## Per-frame weather: timed-weather expiry, precipitation around
## the camera, and the ambient hazard gate (bundle weatherFx
## @1489897: rand < dt*2, expected every ~0.5 s, enemies within
## 25 u of the player).
func _weather_tick(delta: float) -> void:
	if weather_t > 0.0:
		weather_t -= delta
		if weather_t <= 0.0:
			weather = base_weather
			apply_weather_look()
	if _wx_root and _cam:
		_wx_root.global_position = _cam.global_position
	if not running or player == null or not is_instance_valid(player):
		return
	if weather != "sand" and weather != "hail" and weather != "rain":
		return
	_wx_hazard_armed = randf() < delta * 2.0
	if not _wx_hazard_armed:
		return
	var pp: Vector3 = player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if bool(e.get("is_downed")) or bool(e.get("is_weakened")):
			continue
		var d: Vector3 = e.global_position - pp
		d.y = 0.0
		if d.length() > 25.0:
			continue
		var types: Array = e.get("types")
		if weather == "rain":
			# Cycle 14 (weatherFx @1489897): rain soaks — wet =
			# max(wet, 2) raw on the parallel timer; 'soaked' counts
			# only while the rain is TIMED (weatherT > 0).
			(e as Enemy).apply_wet_raw(2.0, weather_t > 0.0)
		elif weather == "sand":
			# Fixed chip 2 + stage*2 through the DoT channel (fixed,
			# silent, no reaction — the bundle's fixed-hit semantics).
			if not types.has("rock") and not types.has("ground") and not types.has("steel"):
				e._dot_tick(2.0 + float(zone) * 2.0)
		else:  # hail
			# 20% freeze onto a free/already-frozen status slot
			# (their chill stack is parallel; ours is single-slot,
			# so other statuses are never clobbered).
			if not types.has("ice") and randf() < 0.2:
				var sk := String(e.get("status_kind"))
				if sk == "" or sk == "freeze":
					e.apply_status("freeze", 2.0)
					e._count_status("frozen")

## Run-end gold -> stardust conversion (§6.1).
func _gold_to_dust(g: float) -> int:
	# §6.1 piecewise: each rate applies to the gold INSIDE its bracket.
	return int(0.04 * minf(g, 5000.0) + 0.012 * clampf(g - 5000.0, 0.0, 35000.0) + 0.001 * clampf(g - 40000.0, 0.0, 160000.0))

func _finish_run(victory: bool) -> void:
	state = "victory" if victory else "dead"
	running = false
	# Cycle 16: run-end stingers; clearing the run track hands
	# the music director back to the menu track.
	_run_music = ""
	if victory:
		audio.victory()
	else:
		audio.defeat()
	if ult:
		ult.dispose()  # clear ground-zone visuals + pending casts
	# §3 lifetime counters settle at run end (cycle 8): 'runs' counts
	# completed runs win or lose (roster descs, news @99636+); best_*
	# records merge with 'max' semantics (hA @1567900).
	GameProfile.count("runs")
	GameProfile.count_max("maxTime", run_time)
	if player and is_instance_valid(player):
		GameProfile.count_max("best_healed", player.healed_run)
		GameProfile.count("healed", player.healed_run)
	GameProfile.count_max("best_burned", float(run_counts.get("burned", 0)))
	GameProfile.count_max("best_poisoned", float(run_counts.get("poisoned", 0)))
	GameProfile.count_max("best_alphas", float(_run_alphas))
	GameProfile.count_max("best_kills", float(kills))
	# Cycle 9: the per-run event counts merge into the lifetime
	# counters with hA's two modes — 'add' into the lifetime total
	# AND 'max' into the best_* record. Cycle 8 merged only
	# best_burned/best_poisoned, so the roster's lifetime status
	# counters (burned/poisoned/slept/crits...) sat at 0 forever
	# and their challenges could never complete.
	for k in ["burned", "poisoned", "slept", "frozen", "paralyzed", "confused", "crits", "soaked", "reactions", "rocks", "berries", "fossil_helix", "fossil_dome"]:
		var v := float(run_counts.get(k, 0))
		if v > 0.0:
			GameProfile.count(k, v)
		GameProfile.count_max("best_" + k, v)
	GameProfile.save_profile()
	var dust := int(round(float(_gold_to_dust(gold)) * (1.0 + float(run_tier) * 0.75)))
	if dust > 0:
		GameProfile.add_stardust(dust)
	# §8 classic score (tier 0): kills*2 + time*3 + damage/200 +
	# (stage-1)*1500 + bosses*800 + victory 6000.
	var score := run_score(victory)
	_fill_result(victory, score, dust)
	_result_panel.visible = true
	if _result_wrap != null:
		_result_wrap.visible = true
	_apply_ui_scale()
	_refresh_meta()

func _on_player_died() -> void:
	# Cycle 21: max-revive charges (bundle player.revives)
	# resurrect at 60% HP, consumed before the Lab row.
	if player and player.revives > 0:
		player.revives -= 1
		player.revive(0.6)
		audio.heal()
		show_banner("最大复活生效！", 3.0)
		return
	# Lab revive (§6.2): one in-run resurrection at 35% HP.
	if GameProfile.lab_level("revive") > 0 and not revive_used:
		revive_used = true
		player.revive(0.35)
		audio.heal()  # cycle 16
		show_banner("研究室复活生效！", 3.0)
		return
	_finish_run(false)

func add_damage(d: float) -> void:
	damage_dealt += d
	# Lifesteal stat (vampire passive, cycle 9): dealing damage
	# heals the player for lifesteal x damage (bundle strike).
	if d > 0.0 and player and is_instance_valid(player) and player.lifesteal > 0.0:
		player.leech_heal(d * player.lifesteal)

## ------------------------------------------------------------------
## Cycle 8: trauma shake, dive slam, lifetime-counter glue.
## shake(e, t, n) in the bundle (@1446581): with a source position,
## the distance factor is clamp(1 - dist/40, 0, 1); the raise is
## e * factor * 0.55 * screenShake(=1), and the new trauma is capped
## at oO = 0.22 for small shakes (e < 0.15) else 0.7 (module consts
## @1436233). Decay/apply @1493252: trauma -= dt * 2 per frame;
## offset = trauma^2 * 0.3 * (sin(T*1.1), sin(T*1.7+1)*0.8,
## sin(T*1.3+2)) with T = time * 26, added to the camera position
## (the lookAt target is NOT shaken).
## ------------------------------------------------------------------
const TRAUMA_CAP_SMALL := 0.22
const TRAUMA_CAP_BIG := 0.7

func add_trauma(power: float, at: Vector3 = Vector3(1.0e18, 0, 0)) -> void:
	# Cycle 9: the bundle's shake() reads the profile settings
	# FIRST (@1447934): shakeOn off = no shake at all, and the
	# raise scales by screenShake (default 1). Cycle 8 had neither.
	if not bool(GameProfile.setting("shakeOn")):
		return
	var factor := 1.0
	if at.x < 1.0e17 and player and is_instance_valid(player):
		factor = clampf(1.0 - player.global_position.distance_to(at) / 40.0, 0.0, 1.0)
	var cap := TRAUMA_CAP_SMALL if power < 0.15 else TRAUMA_CAP_BIG
	trauma = maxf(trauma, minf(cap, trauma + power * factor * 0.55 * float(GameProfile.setting("screenShake"))))

## Hitstop (cycle 9): bundle hitstop(e) sets hitstopT = max
## (@1448302); while it runs, the world clock, spawner, projectiles
## and all bodies freeze (player/enemy gate on hitstop_active()).
func hitstop(t: float) -> void:
	_hitstop_t = maxf(_hitstop_t, t)

func hitstop_active() -> bool:
	return _hitstop_t > 0.0

## Camera kick (cycle 9): the renderer's chroma punch — see the
## vignette shader. kick(e): chromaAmt = min(0.012, chromaAmt + e).
func camera_kick(e: float) -> void:
	_chroma = minf(0.012, _chroma + e)

## ui.damageFlash (cycle 9): red overlay pulse on player hurt.
func damage_flash() -> void:
	_dmg_flash = 1.0

## Floating combat text (bundle vfx.text): a rising, fading
## Label3D. Used for the dodge "-" and reward notices.
func spawn_floater(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	# Cycle 17: floaters take the display face and the
	# original's #1a1030 stroke (UI_SPEC §1.1/§2.3); the tick
	# below scales them with camera distance.
	l.font = _font_display
	l.font_size = 42
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(UiTheme.INK_DEEP.r, UiTheme.INK_DEEP.g, UiTheme.INK_DEEP.b, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = pos
	_floaters.append({"node": l, "t": 0.0, "px": l.pixel_size})

func count_max_level() -> void:
	if player and is_instance_valid(player):
		GameProfile.count_max("maxLevel", float(player.level))

## Photosynthesis leech throttle (bundle photoT, 0.2 s): heals
## 0.4% of max HP per grass-hit window.
func photosynthesis_tick() -> void:
	if player == null or not is_instance_valid(player):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _photo_t < 0.2:
		return
	_photo_t = now
	player.leech_heal(player.max_hp * 0.004)

func guardian_roar(e: Enemy) -> void:
	add_trauma(0.3, e.global_position)
	spawn_floater(e.global_position + Vector3(0, 2.6, 0), "咆哮！", Color(1.0, 0.6, 0.3))
	if e.rig:
		e.rig.set_flash(0.6)

## The original's combat.hit/strike pipeline (bundle @722351),
## attacker side, in bundle order: base x damage x (physical |
## special), STAB x1.25 when the move type is among the ATTACKER's
## types (ally attacks pass the ally's own types — strike's
## slot>=10 branch), crit roll (critChance x critDamage). The
## defender side (type chart, sleeping x1.8 / frozen x1.2, status
## application, knockback) lives in Enemy.take_damage.
## Not ported (no counterpart systems in this build): the
## superEffective ITEM stat, thick-club/stick/binding-band
## items, endless. (typeBoost and weather landed in cycles
## 12/21; boss mech multipliers in cycle 21.)
## ------------------------------------------------------ cycle 14
## Combat meter (B_ @720250): damage per target accumulates in
## 1-second windows; each tick keeps the window's BEST single
## target; dps = the element at floor(len x .85) of the sorted
## history (cap 120). budget(secs) = dps x secs — the guardian
## HP raise in summon_guardian (Tb @995317 / Cb @995145).
func meter_add(e: Enemy, amount: float) -> void:
	if amount <= 0.0 or not is_finite(amount):
		return
	var k := e.get_instance_id()
	_meter_win[k] = float(_meter_win.get(k, 0.0)) + amount
	_meter_best = maxf(_meter_best, float(_meter_win[k]))

func _meter_tick(delta: float) -> void:
	_meter_acc += delta
	while _meter_acc >= 1.0:
		_meter_acc -= 1.0
		if _meter_best > 0.0:
			_meter_hist.append(_meter_best)
			if _meter_hist.size() > 120:
				_meter_hist.pop_front()
		_meter_win.clear()
		_meter_best = 0.0

func meter_dps() -> float:
	if _meter_hist.is_empty():
		return 0.0
	var s := _meter_hist.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(float(s.size()) * 0.85))])

func _meter_reset() -> void:
	_meter_win.clear()
	_meter_best = 0.0
	_meter_hist.clear()
	_meter_acc = 0.0

func combat_hit(target: Enemy, base: float, move_type: String, cls: String, attacker_types: Array, opts: Dictionary = {}) -> float:
	if player == null or not is_instance_valid(player) or target == null or not is_instance_valid(target):
		return 0.0
	var s := base * player.damage_mult * (player.phys if cls == "physical" else player.spec)
	if attacker_types.has(move_type):
		s *= 1.25  # STAB (1.5625 with adaptability — Eevee line not modelled)
	# Cycle 12 weather table (bundle @723641: boost x1.3 / nerf
	# x0.75 on the acting move's type; player/ally strikes only —
	# this function IS that pipeline. Fixed/environmental damage
	# never passes through here.)
	s *= weather_damage_mul(move_type)
	# Passive hooks, same order as the player's _roll_damage:
	# lowHp multiplier, per-type boost, pickup's critAdd.
	var hooks := GameData.passive_hooks(player.passive_id)
	if hooks.has("lowHp") and player.hp < player.max_hp * 0.4:
		s *= float(hooks["lowHp"])
	# Cycle 21: beacon — paralyzed targets take +25% from
	# the beacon carrier (player-attributed hits; combat_hit
	# is the player's pipeline).
	if player.passive_id == "beacon" and opts.get("ally") == null \
			and target.status_kind == "paralyze" and target.status_t > 0.0:
		s *= 1.25
	# Cycle 21: chlorophyll's sun damage (+20%), player side
	# (ally-attributed hits ride the same pipeline today).
	if player.passive_id == "chlorophyll" and weather == "sun":
		s *= 1.2
	var tb: Dictionary = hooks.get("typeBoost", {})
	if tb.has(move_type):
		s *= 1.0 + float(tb[move_type])
	var cc := player.crit_chance
	if player.passive_id == "pickup":
		cc += minf(0.15, gold / 10000.0)
	if randf() < cc:
		s *= player.crit_dmg
		count_run_event("crits")
		audio.hit_mega()  # cycle 16: crits prepend the mega jingle
	var fx: Dictionary = {}
	if opts.has("knock"):
		fx["knock"] = float(opts["knock"])
		fx["from"] = opts.get("from", target.global_position)
	if opts.get("ally") != null:
		fx["ally"] = opts["ally"]
	# Cycle 13: hit-slot attribution (ult hits pass slot 8; the
	# enemy records it as last_hit_slot for the ult charge rules).
	# opts "silent" needs no handling: this build spawns no
	# per-hit damage numbers to suppress.
	if opts.has("slot"):
		fx["slot"] = int(opts["slot"])
	# Cycle 14 ELECTROCUTE (reactions() @733583): an electric hit
	# landing on a WET target (global 0.25 s reaction cooldown,
	# noReact packets excluded) consumes the target's wet, chains
	# packet x .8 to up to 12 other wet enemies within 9u (their
	# wet is NOT consumed; paralysis at 60%; the packet already
	# carries the primary's type chart — the bundle's `fixed`
	# chain does not re-chart, so the chain take_damage passes no
	# move type) and boosts THIS hit x1.5. Multiplication commutes
	# with take_damage's chart, so the boost lands identically.
	if move_type == "electric" and not bool(opts.get("noreact", false)) \
			and target.wet_t > 0.0 and not target.is_downed and not target.is_weakened \
			and run_time - _elec_t >= 0.25:
		_elec_t = run_time
		target.wet_t = 0.0
		count_run_event("electro")
		count_run_event("reactions")
		spawn_floater(target.global_position + Vector3(0, 2.6, 0), "触电！", Color(1.0, 0.9, 0.35))
		var packet := s * GameData.type_mult("electric", target.types)
		var chained := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if chained >= 12:
				break
			if e == target or not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
				continue
			var ce := e as Enemy
			if ce.wet_t <= 0.0 or ce.is_downed or ce.is_weakened:
				continue
			var cd: Vector3 = ce.global_position - target.global_position
			cd.y = 0.0
			if cd.length() > 9.0:
				continue
			ce.take_damage(packet * 0.8, "", "paralysis", 60.0,
				{"knock": 1.5, "from": target.global_position, "slot": int(opts.get("slot", 0))})
			if int(opts.get("slot", 0)) != 8 and ce.last_meter_amount >= 0.0:
				meter_add(ce, ce.last_meter_amount)
			spawn_nova(ce.global_position + Vector3(0, 0.6, 0), 1.6, Color(1.0, 0.9, 0.35))
			chained += 1
		s *= 1.5
	# Cycle 15: the remaining reactions (reactions() @733487 —
	# branch order steam, wildfire, shatter, gas, mind; each
	# gated by its own 0.25 s canReact key; noReact packets
	# excluded). Branch state is read BEFORE this hit's own
	# status lands (the bundle reads its status arrays before
	# hit0 applies the new status — electrocute precedent).
	# Boosts multiply the pre-chart packet (the chart
	# commutes); chain packets carry the primary's chart
	# (the bundle's `fixed`) and pass no move type. Dragon
	# fury is NOT here: charm has no source in this build
	# (DIFF cycle 15).
	if not bool(opts.get("noreact", false)) and not target.is_downed and not target.is_weakened:
		var slot_kind := target.status_kind
		var slot_on := target.status_t > 0.0 and slot_kind != ""
		if slot_on and slot_kind == "burn" and move_type == "water" and _react_ready("steam"):
			# STEAM @733964: the primary's burn is consumed;
			# EVERY enemy within 6u (primary included) gains
			# confuse 2.5x resist + root 2x resist (raw field
			# writes in the bundle), confusion counted once
			# per enemy. Return x1.4.
			_react_fire("steam")
			target.status_kind = ""
			target.status_t = 0.0
			count_run_event("reactions")
			spawn_floater(target.global_position + Vector3(0, 2.6, 0), "蒸汽！", Color8(224, 240, 255))
			for e in get_tree().get_nodes_in_group("enemies"):
				var ce := e as Enemy
				if not is_instance_valid(ce) or ce.hp <= 0.0 or ce.is_downed or ce.is_weakened:
					continue
				var d3: Vector3 = ce.global_position - target.global_position
				d3.y = 0.0
				if d3.length() > 6.0:
					continue
				var rs := ce.resist_factor()
				ce.confuse_t = maxf(ce.confuse_t, 2.5 * rs)
				ce.root_t = maxf(ce.root_t, 2.0 * rs)
				ce.count_once("confused32", "confused")
			s *= 1.4
		elif slot_on and slot_kind == "burn" and (move_type == "grass" or move_type == "flying") and _react_ready("fire"):
			# WILDFIRE @734411: EVERY enemy within 7u (primary
			# included) gains burn via applyStatus; the
			# primary's burn is NOT consumed. The bundle's
			# per-enemy burnDps magnitudes ride its DoT
			# model; ours is the standing flat tick (DIFF).
			# Return x1.3.
			_react_fire("fire")
			count_run_event("reactions")
			spawn_floater(target.global_position + Vector3(0, 2.6, 0), "野火！", Color8(255, 106, 26))
			for e in get_tree().get_nodes_in_group("enemies"):
				var ce := e as Enemy
				if not is_instance_valid(ce) or ce.hp <= 0.0 or ce.is_downed or ce.is_weakened:
					continue
				var d3: Vector3 = ce.global_position - target.global_position
				d3.y = 0.0
				if d3.length() > 7.0:
					continue
				ce.apply_ailment("burn")
			s *= 1.3
		elif slot_on and slot_kind == "freeze" and (move_type == "fighting" or move_type == "rock" or move_type == "steel") and _react_ready("shatter"):
			# SHATTER @734743: frozen consumed; every OTHER
			# enemy within 5u takes packet x .7 (ice, fixed).
			# Return x2.6. ORDER: the bundle's damage()
			# applies its frozen x1.2 strike multiplier
			# (@724799) BEFORE hit() calls reactions(), so
			# the shatter hit earns both — our take_damage
			# can no longer see the freeze (the reaction
			# clears it first), so the x1.2 is folded in
			# here explicitly. Same product, same order.
			_react_fire("shatter")
			target.status_kind = ""
			target.status_t = 0.0
			count_run_event("reactions")
			spawn_floater(target.global_position + Vector3(0, 2.6, 0), "碎裂！", Color8(138, 232, 255))
			var spacket := s * GameData.type_mult(move_type, target.types)
			for e in get_tree().get_nodes_in_group("enemies"):
				var ce := e as Enemy
				if ce == target or not is_instance_valid(ce) or ce.hp <= 0.0 or ce.is_downed or ce.is_weakened:
					continue
				var d3: Vector3 = ce.global_position - target.global_position
				d3.y = 0.0
				if d3.length() > 5.0:
					continue
				ce.take_damage(spacket * 0.7, "", "", 0.0, {"slot": int(opts.get("slot", 0))})
				if int(opts.get("slot", 0)) != 8 and ce.last_meter_amount >= 0.0:
					meter_add(ce, ce.last_meter_amount)
			s *= 2.6 * 1.2
		elif slot_on and slot_kind == "poison" and move_type == "fire" and _react_ready("gas"):
			# GAS @735065: r = the primary's poison stacks;
			# poison + stacks consumed; every OTHER enemy
			# within 6u takes packet x (.5 + .12r) with
			# poison at chance 1. Return x (1.4 + .1r).
			var r := target.poison_stacks
			_react_fire("gas")
			target.status_kind = ""
			target.status_t = 0.0
			target.poison_stacks = 0
			count_run_event("reactions")
			spawn_floater(target.global_position + Vector3(0, 2.6, 0), "毒气！", Color8(192, 90, 255))
			var gpacket := s * GameData.type_mult(move_type, target.types)
			for e in get_tree().get_nodes_in_group("enemies"):
				var ce := e as Enemy
				if ce == target or not is_instance_valid(ce) or ce.hp <= 0.0 or ce.is_downed or ce.is_weakened:
					continue
				var d3: Vector3 = ce.global_position - target.global_position
				d3.y = 0.0
				if d3.length() > 6.0:
					continue
				ce.take_damage(gpacket * (0.5 + 0.12 * float(r)), "", "poison", 100.0, {"slot": int(opts.get("slot", 0))})
				if int(opts.get("slot", 0)) != 8 and ce.last_meter_amount >= 0.0:
					meter_add(ce, ce.last_meter_amount)
			s *= 1.4 + 0.1 * float(r)
		elif slot_on and slot_kind == "paralyze" and move_type == "psychic" and _react_ready("mind"):
			# MIND COLLAPSE @~735500: paralysis consumed; the
			# primary gains confuse 4x resist (counted once).
			# Return x1.6.
			_react_fire("mind")
			target.status_kind = ""
			target.status_t = 0.0
			target.confuse_t = maxf(target.confuse_t, 4.0 * target.resist_factor())
			target.count_once("confused32", "confused")
			count_run_event("reactions")
			spawn_floater(target.global_position + Vector3(0, 2.6, 0), "精神崩溃！", Color8(255, 90, 160))
			s *= 1.6
	var dealt: float = target.take_damage(s, move_type, String(opts.get("status", "")), float(opts.get("status_chance", 0.0)), fx)
	# Cycle 14: feed the combat meter (hit0 @727415 — every slot
	# except 8; the enemy recorded the post-cap/exhaust-adjusted
	# amount in take_damage).
	if int(opts.get("slot", 0)) != 8 and target.last_meter_amount >= 0.0:
		meter_add(target, target.last_meter_amount)
	add_damage(dealt)
	# Cycle 18: per-move / per-ally attribution for the
	# results screen (damage bars + capture grid damage).
	if opts.get("ally") != null:
		var ae := opts["ally"] as Enemy
		if ae != null and is_instance_valid(ae):
			run_ally_dmg[ae.species_id] = float(run_ally_dmg.get(ae.species_id, 0.0)) + dealt
	elif int(opts.get("slot", 0)) == 8:
		add_move_damage("ult", dealt)
	elif opts.has("move"):
		add_move_damage(String(opts["move"]), dealt)
	return dealt

## Ally physical attack resolution (bundle land() @527300):
## every enemy inside r = 2.6 * sqrt(player area) of the ally takes
## a typed combat.hit at the ally's live power, with the ally
## type's J_ status at 20% and knock 2.
func ally_land(ally: Enemy) -> void:
	if player == null or not is_instance_valid(player):
		return
	var r := 2.6 * sqrt(player.area_mult)
	var atype := String(ally.types[0]) if not ally.types.is_empty() else "normal"
	var status := GameData.ally_status_for(atype)
	audio.slash()  # cycle 16: ally melee landing
	spawn_nova(ally.global_position + Vector3(0, 0.35, 0), r, Color(0.5, 1.0, 0.6))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if bool(e.get("is_downed")) or bool(e.get("is_weakened")):
			continue
		var d: Vector3 = e.global_position - ally.global_position
		d.y = 0.0
		if d.length() <= r:
			combat_hit(e, ally.ally_power_now(), atype, "physical", ally.types,
				{"status": status, "status_chance": 20.0, "knock": 2.0,
				"from": ally.global_position, "ally": ally})

## Ally special attack (bundle @527200): a homing projectile that
## explodes on impact (r = 2.2 * sqrt(player area), knock 1),
## damage resolved through combat_hit on arrival.
func ally_shoot(ally: Enemy, foe: Enemy) -> void:
	if player == null or not is_instance_valid(player):
		return
	var atype := String(ally.types[0]) if not ally.types.is_empty() else "normal"
	audio.shot(atype)  # cycle 16: ally cast
	var col: Color = Player.TYPE_COLORS.get(atype, Color.WHITE)
	if not _proj_mats.has(col):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
		_proj_mats[col] = m
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.26
	sm.height = 0.52
	mi.mesh = sm
	mi.material_override = _proj_mats[col]
	add_child(mi)
	mi.global_position = ally.global_position + Vector3(0, 1.0, 0)
	_projectiles.append({"node": mi, "target": foe, "dmg": ally.ally_power_now(),
		"speed": 19.0, "mtype": atype, "ailment": "", "achance": 0.0,
		"ally": ally, "explode_r": 2.2 * sqrt(player.area_mult)})

## §3 counter glue: additive lifetime counters go straight to the
## Profile; per-run events accumulate here and merge as best_* at
## run end (the original's 'add' vs 'max' counter modes).
func count_event(counter: String, n: float = 1.0) -> void:
	GameProfile.count(counter, n)

func count_run_event(counter: String) -> void:
	run_counts[counter] = int(run_counts.get(counter, 0)) + 1

## Cycle 15: canReact @733151 — one global per-key 0.25 s
## cooldown map for the reaction layer (electrocute keeps
## its cycle-14 _elec_t field, same semantics).
func _react_ready(key: String) -> bool:
	return run_time - float(_react_cd.get(key, -1000.0)) >= 0.25

func _react_fire(key: String) -> void:
	_react_cd[key] = run_time

## Cycle 15: the bundle's t.later(delay, fn) — delayed world
## callbacks on the run clock (cursed chest's 0.2 s ambush,
## slots' 0.3 s voltorb, challenge's staggered spawns).
func _later(delay: float, fn: Callable) -> void:
	_timers.append({"t": delay, "fn": fn})

func _timers_tick(delta: float) -> void:
	for i in range(_timers.size() - 1, -1, -1):
		var tm: Dictionary = _timers[i]
		tm["t"] = float(tm["t"]) - delta
		if float(tm["t"]) <= 0.0:
			_timers.remove_at(i)
			(tm["fn"] as Callable).call()

## stats.luckMult (recompute @~787526): 1 + luck/100, raw
## (the slots weight walk clamps its own copy to [1,2]).
func _luck_mult() -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	return 1.0 + player.luck / 100.0

## ------------------------------------------------------ cycle 13 ult
## Glue + presentation for scripts/ult.gd (spec in DIFF.md).

## The gauge button's edge: latched into the controller's
## trigger poll (same edge as KeyR).
func _on_ult_button() -> void:
	if ult:
		ult.press_button()

## Player.take_damage reports the HP damage that landed (bundle:
## ult.onHurt(f / maxHp) inside hurt() @820982).
func ult_on_player_hurt(frac: float) -> void:
	if ult:
		ult.on_hurt(frac)

## ui.ultCutIn (@2011156): medal + name band, 1.3 s.
func show_ult_cutin(ult_name_: String, color: Color) -> void:
	if _cutin_panel == null:
		return
	var bg_col := color.darkened(0.68)
	bg_col.a = 0.92
	var rim_col := color.lightened(0.35)
	var csb := _style(bg_col, 32, rim_col, 2.5, true)
	csb.shadow_color = Color(color.r, color.g, color.b, 0.48)
	csb.shadow_size = 10
	csb.shadow_offset = Vector2(0, 3)
	_cutin_panel.add_theme_stylebox_override("panel", csb)
	_cutin_name.text = ult_name_
	_cutin_name.add_theme_color_override("font_color", color.lightened(0.45))
	_cutin_panel.visible = true
	_cutin_t = 1.3
	if _p3_on == 1:
		_layout_hud()  # UI-mobile P3: it heads the centre stack

## ultLook (@1453942): atmosphere grade toward the tint for the
## duration — approximated as a fading fullscreen tint.
func show_ult_look(color: Color, dur: float) -> void:
	if _ult_look_rect == null:
		return
	_ult_look_rect.color = Color(color.r, color.g, color.b, 0.16)
	_ult_look_t = dur
	_ult_look_dur = dur

## Cast twinkles: 24 star particles converging from radius 4.5
## over .35 s (bundle vfx cast preamble).
func ult_twinkle_fx(pos: Vector3, color: Color) -> void:
	_fx_textures()
	for i in range(24):
		var a := TAU * float(i) / 24.0 + randf() * 0.2
		var from := pos + Vector3(cos(a) * 4.5, 1.2, sin(a) * 4.5)
		var vel := (pos + Vector3(0, 1.0, 0) - from) / 0.35
		_spawn_particle(from, vel, 0.35, 0.55, 0.1,
			Color(color.r, color.g, color.b, 0.95), _tex_star)

## Fissure-step eruptions: root spikes (grass) read as leaf/star
## bursts, magma cracks as flame discs — particle approximations
## of the bundle's PixRoot/lava sprites.
func ult_step_fx(pos: Vector3, kind: String, color: Color) -> void:
	_fx_textures()
	if kind == "root":
		_spawn_particle(pos + Vector3(0, 0.5, 0), Vector3(0, 2.2, 0),
			0.4, 0.8, 0.3, Color(0.45, 0.85, 0.35, 0.9), _tex_leaf)
		if randf() < 0.5:
			_spawn_particle(pos + Vector3(0, 0.3, 0),
				Vector3(randf_range(-1.0, 1.0), 1.6, randf_range(-1.0, 1.0)),
				0.45, 0.5, 0.15, Color(0.7, 0.95, 0.5, 0.8), _tex_leaf)
	elif kind == "magma":
		_spawn_particle(pos + Vector3(0, 0.4, 0),
			Vector3(0, 2.6, 0), 0.35, 0.9, 0.2,
			Color(1.0, 0.55, 0.2, 0.95), _tex_disc)
		if randf() < 0.3:
			_spawn_particle(pos + Vector3(0, 0.6, 0),
				Vector3(randf_range(-0.8, 0.8), 3.2, randf_range(-0.8, 0.8)),
				0.4, 0.6, 0.1, Color(1.0, 0.8, 0.3, 0.9), _tex_star)

## Cast preamble flame jet (Bg[4]: 26 flame particles upward).
func ult_flame_jet(pos: Vector3, color: Color, count: int) -> void:
	_fx_textures()
	for i in range(count):
		var a := randf() * TAU
		var rr := randf() * 1.2
		_spawn_particle(pos + Vector3(cos(a) * rr, 0.3, sin(a) * rr),
			Vector3(0, randf_range(5.0, 8.0), 0), randf_range(0.35, 0.55),
			0.8, 0.15, Color(1.0, 0.6, 0.25, 0.95), _tex_disc)

const SLAM_STAGE_MULT := [1.0, 1.8, 3.2, 4.0]  # j_ (@718961)

## Dive slam (bundle slam(groundY, fallH) @829714, cycle 9 rewrite):
## o = clamp(fallH/8, 0, 1) (hy = 8); radius = (3.2 + 3.3o) *
## sqrt(area); base damage = (12 + 1.5 * level) * stageMult *
## slamStat * (1 + 2o) — then EVERY enemy in radius takes a real
## combat.hit {type: player.types[0], cls: physical, knock: 3+3o,
## status: stun @ 35+40o%} (audit §3: cycle 8 dealt the raw base
## through take_damage, skipping STAB x1.25, the damage/physical
## multipliers, crit and slamStat — about 20% light at our stats).
## Also: player squash = 0.9 at slam start, shake(0.14 + 0.26o),
## r.kick(0.008 + 0.012o), hitstop(0.04 + 0.05o) when >= 1 enemy
## was hit, iframes = max(iframes, 0.3). On cooldown (2 s) the
## original plays dust only. Stun duration 1.0 s INFERRED (the
## bundle's genome example applies applyStatus(t, 'stun', 1)).
func player_slam(pos: Vector3, fall_h: float, can_slam: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not can_slam:
		spawn_nova(pos + Vector3(0, 0.3, 0), 1.6, Color(0.85, 0.8, 0.7))
		return
	var o := clampf(fall_h / 8.0, 0.0, 1.0)
	audio.slam(o)  # cycle 16: the bundle's slam(o) one-shot
	var radius := (3.2 + 3.3 * o) * sqrt(player.area_mult)
	var dmg := (12.0 + 1.5 * float(player.level)) * float(SLAM_STAGE_MULT[zone - 1]) * player.slam_mult * (1.0 + 2.0 * o)
	var sp: Dictionary = GameData.species(player.species_id)
	var ptypes: Array = player.types()  # cycle 22: current types
	var ptype := String(ptypes[0]) if not ptypes.is_empty() else "normal"
	if player.rig:
		player.rig.set_squash(0.9)  # bundle: this.squash = .9 at slam()
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if bool(e.get("is_downed")) or bool(e.get("is_weakened")):
			continue
		var d: Vector3 = e.global_position - pos
		d.y = 0.0
		if d.length() <= radius:
			combat_hit(e, dmg, ptype, "physical", ptypes,
				{"status": "stun", "status_chance": (0.35 + 0.4 * o) * 100.0,
				"knock": 3.0 + 3.0 * o, "from": pos, "move": "slam"})
			hits += 1
	spawn_nova(pos + Vector3(0, 0.3, 0), radius, Color(1.0, 0.95, 0.85))
	spawn_nova(pos + Vector3(0, 0.35, 0), radius * 0.55, Color.WHITE)
	add_trauma(0.14 + 0.26 * o, pos)
	camera_kick(0.008 + 0.012 * o)
	if hits > 0:
		hitstop(0.04 + 0.05 * o)
	player._invuln_t = maxf(player._invuln_t, 0.3)  # original: iframes = max(iframes, 0.3)
	count_event("slams")

func spawn_projectile(from: Vector3, target: Node3D, dmg: float, color: Color, move_type: String = "", ailment: String = "", ailment_chance: float = 0.0, move_key: String = "") -> void:
	if not _proj_mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
		_proj_mats[color] = m
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	mi.mesh = sm
	mi.material_override = _proj_mats[color]
	mi.global_position = from
	add_child(mi)
	# Only the player fires through here; tailwind's projSpeed
	# passive scales the shot (bundle ay mods, cycle 9).
	var spd := 24.0 * (player.proj_speed_mult if player and is_instance_valid(player) else 1.0)
	_projectiles.append({"node": mi, "target": target, "dmg": dmg, "speed": spd, "mtype": move_type, "ailment": ailment, "achance": ailment_chance, "move": move_key})

## Status-nova visual (sleep/poison powder): a flat expanding ring.
func spawn_nova(pos: Vector3, radius_: float, color: Color) -> void:
	# Cycle 11: the bundle's nova/slam rings are FLAT ground rings
	# (vfx.ring: y + 0.15, radii expanding over ~0.35 s) — the old
	# vertical torus read as a giant hoop dominating the frame.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	if _ring_mesh == null:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.84
		tm.outer_radius = 1.0
		tm.rings = 64
		tm.ring_segments = 24
		_ring_mesh = tm
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	add_child(holder)
	holder.global_position = pos + Vector3(0, 0.15, 0)
	holder.scale = Vector3(radius_ * 0.3, 1.0, radius_ * 0.3)
	_effects.append({"node": holder, "mat": mat, "t": 0.0, "life": 0.35, "kind": "ring",
		"r0": radius_ * 0.3, "r1": radius_})

## Beam visual (solar-beam): a stretched fading box along the shot.
func spawn_beam(from: Vector3, dir: Vector3, len_: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.7, len_)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(0, 0, -len_ * 0.5)
	holder.add_child(mi)
	add_child(holder)
	holder.global_position = from
	var tgt := from - dir
	if tgt.distance_to(from) > 0.01:
		holder.look_at(tgt, Vector3.UP)
	_effects.append({"node": holder, "mat": mat, "t": 0.0})

## ------------------------------------------------------ cycle 11 strike FX
## Melee visuals ported from the bundle: the generic strike falls
## to slash() (@1448959) — 8 beam segments (class Lu @178238) along
## a 126-degree arc of radius 0.7 * range centred on the strike
## point, heights tilted +-0.3 alternating per cast, segment width
## 0.45 * (1 - |k/7 - 0.5|), life 0.16 s — plus Spark particles at
## even nodes and a centre flash (@189900). Vine Whip has a custom
## strike (@413916): two vm() vine chains (@406497), a Twinkle
## burst (B() @406784) and six leaf particles (hm() @405655). The
## old effect was a full vertical torus of outer diameter 6.2 u —
## ~4.8x the creature's height — which is what filled the user's
## screenshots with a giant beige hoop.

func _fx_textures() -> void:
	if _tex_disc != null:
		return
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var img2 := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var img3 := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var dx := float(x) / 31.0 * 2.0 - 1.0
			var dy := float(y) / 31.0 * 2.0 - 1.0
			var d := sqrt(dx * dx + dy * dy)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
			var star := clampf(1.0 - minf(absf(dx), absf(dy)) * 3.5 - d * 0.55, 0.0, 1.0)
			img2.set_pixel(x, y, Color(1, 1, 1, star))
			var lx := (dx + dy) * 0.7071
			var ly := (dy - dx) * 0.7071
			var leaf := 0.0
			if (lx * lx) / 0.81 + (ly * ly) / 0.16 < 1.0:
				leaf = 1.0
			img3.set_pixel(x, y, Color(1, 1, 1, leaf))
	_tex_disc = ImageTexture.create_from_image(img)
	_tex_star = ImageTexture.create_from_image(img2)
	_tex_leaf = ImageTexture.create_from_image(img3)

func _spawn_particle(pos: Vector3, vel: Vector3, life: float, s0: float, s1: float, color: Color, tex: Texture2D, add_blend := true, grav := 0.0, drag := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if add_blend:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * s0
	_particles.append({"node": mi, "mat": m, "vel": vel, "t": 0.0, "life": life,
		"s0": s0, "s1": s1, "grav": grav, "drag": drag, "a0": color.a})

func _beam_mesh(pts: Array, widths: Array, cam: Vector3) -> ArrayMesh:
	# One camera-facing ribbon quad per segment (the bundle's Lu
	# beams are view-aligned cylinders, @178238). The side offset is
	# carried in NORMAL and scaled by the shrink uniform in the
	# vertex shader, mirroring their (0.4 + 0.6 * frac) width curve.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var base := 0
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var mid := (a + b) * 0.5
		var dirv := b - a
		dirv.y = 0.0
		var side := dirv.cross(cam - mid)
		if side.length() < 0.001:
			side = Vector3.UP.cross(dirv)
		side = side.normalized()
		var off := side * (float(widths[k - 1]) * 0.5)
		verts.append(a - off)
		normals.append(-off)
		uvs.append(Vector2(0, 0))
		verts.append(a + off)
		normals.append(off)
		uvs.append(Vector2(0, 1))
		verts.append(b + off)
		normals.append(off)
		uvs.append(Vector2(1, 1))
		verts.append(b - off)
		normals.append(-off)
		uvs.append(Vector2(1, 0))
		idx.append(base)
		idx.append(base + 1)
		idx.append(base + 2)
		idx.append(base)
		idx.append(base + 2)
		idx.append(base + 3)
		base += 4
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return am

func _spawn_beam_fx(pts: Array, widths: Array, color: Color, life: float) -> void:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color;
uniform float fade = 1.0;
uniform float shrink = 1.0;
void vertex() {
	VERTEX = VERTEX + NORMAL * shrink;
}
void fragment() {
	float e = abs(UV.y * 2.0 - 1.0);
	float tip = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.94, UV.x);
	vec3 col = tint.rgb;
	col *= mix(1.0, 0.6, smoothstep(0.7, 1.0, e));
	col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.26, e)) * 0.45);
	float a = mix(1.0, 0.85, smoothstep(0.7, 1.0, e)) * tip * fade;
	ALBEDO = col;
	ALPHA = a;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _beam_shader
	mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
	var mi := MeshInstance3D.new()
	var cam_pos := Vector3(0, 8, 10)
	if _cam:
		cam_pos = _cam.global_position
	mi.mesh = _beam_mesh(pts, widths, cam_pos)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	add_child(mi)
	_effects.append({"node": mi, "smat": mat, "t": 0.0, "life": life, "kind": "beam"})

func _spawn_flash(pos: Vector3, size: float, color: Color) -> void:
	# vfx.flash: additive disc growing 0.42r -> 0.6r of the flash
	# size (capped at 4.5), life 0.08 s. Called with size = 0.6 *
	# range, matching slash()'s flash(range * 0.6).
	var s1 := minf(size, 4.5)
	_spawn_particle(pos, Vector3.ZERO, 0.08, s1 * 0.7, s1, color, _tex_disc)

func spawn_strike_fx(from: Vector3, target_pos: Vector3, dir: Vector3, range_: float, color: Color, move_key: String) -> void:
	# Bundle dispatch (@781314): a move with a custom strike uses
	# it; everything else falls to the generic slash() (@1448959).
	_cast_parity += 1
	_fx_textures()
	if move_key == "vine-whip":
		_spawn_vines(from, target_pos, dir, range_)
		return
	var alt := _cast_parity % 2 == 1
	var dh := Vector2(target_pos.x - from.x, target_pos.z - from.z).length()
	var center := from + dir * minf(dh, range_ * 0.6)
	center.y = from.y + 1.0
	var l := range_ * 0.7
	var sweep := 1.0 if alt else -1.0
	var base_ang := atan2(dir.z, dir.x)
	var pts: Array = []
	for k in range(8):
		var fk := base_ang + sweep * (-1.1 + float(k) / 7.0 * 2.2)
		pts.append(Vector3(
			center.x + cos(fk) * l - dir.x * l * 0.5,
			center.y + (float(k) / 7.0 - 0.5) * 0.6 * (-sweep),
			center.z + sin(fk) * l - dir.z * l * 0.5))
	var widths: Array = []
	for k in range(1, 8):
		widths.append(0.68 * (1.0 - absf(float(k) / 7.0 - 0.5)))
	_spawn_beam_fx(pts, widths, color, 0.24)
	for k in range(0, 8, 2):
		var fk2 := base_ang + sweep * (-1.1 + float(k) / 7.0 * 2.2)
		_spawn_particle(pts[k], Vector3(cos(fk2), 0.35, sin(fk2)) * 3.4, 0.30, 0.62, 0.0, color, _tex_disc)
	_spawn_flash(center, range_ * 0.85, color)

func _spawn_vines(from: Vector3, target_pos: Vector3, dir: Vector3, range_: float) -> void:
	# Vine Whip's custom strike (@413916): two vm() vine chains
	# (@406497) from the caster toward the strike centre, a Twinkle
	# burst at the tip (B() @406784) and six leaf particles (hm()
	# @405655, leaf 8050762 / leafDark 3840570 from the V table).
	var alt := _cast_parity % 2 == 1
	var origin := from + Vector3(0, 0.9, 0)
	var end := target_pos + dir * (range_ * 0.3)
	end.y = from.y + 1.0
	var leaf_dark := Color(0.227, 0.604, 0.227)
	var sweeps := [1.1, -0.66] if alt else [-1.1, 0.66]
	for sw in sweeps:
		var dx := end.x - origin.x
		var dz := end.z - origin.z
		var len := sqrt(dx * dx + dz * dz)
		var nx := -dz / maxf(len, 0.001)
		var nz := dx / maxf(len, 0.001)
		var pts: Array = [origin]
		var widths: Array = []
		for s_i in range(1, 9):
			var s := float(s_i) / 8.0
			var wob := sin(s * PI) * float(sw)
			pts.append(Vector3(
				origin.x + dx * s + nx * wob,
				origin.y + (end.y - origin.y) * s + sin(s * PI) * absf(float(sw)) * 0.4,
				origin.z + dz * s + nz * wob))
			widths.append(0.22 * (1.0 - s * 0.4))
		_spawn_beam_fx(pts, widths, leaf_dark, 0.2)
	_spawn_particle(end + Vector3(0, 0.2, 0), Vector3.ZERO, 0.15, 0.4, 2.2, Color(1, 1, 1), _tex_star)
	var leaf_col := Color(0.478, 0.875, 0.259)
	for i in range(6):
		var ang := randf() * TAU
		var sp := 5.0 * randf_range(0.8, 1.1)
		_spawn_particle(end, Vector3(cos(ang) * sp, randf_range(0.0, 1.5), sin(ang) * sp),
			0.4, 0.45, 0.135, leaf_col, _tex_leaf, false, 0.0, 2.5)

## Cycle 10: per-frame drive for the two HUD HP bars. Lag math is
## the bundle's: player bar hold 0.4 s / drain 0.9 per s (@2023679);
## boss bar hold 0.45 s / drain 0.6 per s (@2028444), lag resets
## when a (new) boss appears.
func _update_hud_bars(delta: float) -> void:
	# Cycle 13: ult gauge + cut-in + ultLook timers.
	if _ult_circle:
		if ult:
			_ult_circle.set_state(ult.charge, ult.tint_color(), ult.deny_t)
		else:
			_ult_circle.set_state(0.0, Color(0.55, 0.85, 0.4), 0.0)
		# Cycle 18: mirror into the touch cluster gauge and
		# yield the corner to it while touch is up.
		if touch_controls:
			if ult:
				# UI-mobile P1.3: deny_t is a float window (the
				# cluster gauge's parameter is now typed to it).
				touch_controls.set_ult_state(ult.charge, ult.tint_color(), ult.deny_t)
			# UI-mobile P4: the phone rows never carry the
			# ult (the cluster gauge is the ult button there).
			_ult_circle.visible = not touch_controls.visible and _p4_on != 1
			# Cycle 21.3 (audit F5/O11): the ult NAME label
			# hides with its circle — it used to stay
			# behind as an orphan floating mid-bottom,
			# exactly where the pinned prompt needs to go.
			if _ult_name_label:
				_ult_name_label.visible = _ult_circle.visible
	_p4_tick_sweeps()
	if _cutin_t > 0.0:
		_cutin_t -= delta
		if _cutin_t <= 0.0 and _cutin_panel:
			_cutin_panel.visible = false
			if _p3_on == 1:
				_layout_hud()
	if _ult_look_t > 0.0:
		_ult_look_t -= delta
		if _ult_look_rect:
			var k := clampf(_ult_look_t / maxf(_ult_look_dur, 0.01), 0.0, 1.0)
			_ult_look_rect.color.a = 0.16 * k
			if _ult_look_t <= 0.0:
				_ult_look_rect.color.a = 0.0
	if _hud_hp_fill and player and is_instance_valid(player):
		var frac := clampf(player.hp / maxf(player.max_hp, 1.0), 0.0, 1.0)
		if frac >= _php_lag:
			_php_lag = frac
			_php_lag_hold = 0.4
		else:
			_php_lag_hold -= delta
			if _php_lag_hold <= 0.0:
				_php_lag = maxf(frac, _php_lag - delta * 0.9)
		# U1 1:1 round 13: fill widths track the HP track's own
		# inner width — desktop 232-2 = 230 (unchanged), phone
		# 154-2 = 152 after the round-13 track narrowing.
		var hp_inw := _hud_hp_track.size.x - 2.0
		_hud_hp_fill.size.x = hp_inw * frac
		_hud_hp_lag.size.x = hp_inw * _php_lag
		_hud_hp_num.text = player.hp_hud_text()
		_hud_hp_num.add_theme_color_override("font_color", Color(1.0, 0.42, 0.54) if player.wound_t > 0.0 else Color.WHITE)
		if _hud_shield_fill:
			_hud_shield_fill.size = Vector2(hp_inw * player.shield_hud_fraction(), _hud_hp_fill.size.y)
		# Bundle classes low (<0.30) / mid (0.30-0.55): recolor the
		# fill by band (CSS values were not captured; band thresholds
		# are the bundle's).
		var band := 0 if frac >= 0.55 else (1 if frac >= 0.3 else 2)
		if band != _php_band:
			_php_band = band
			var c := Color(0.32, 0.90, 0.48) if band == 0 else (Color(0.98, 0.75, 0.25) if band == 1 else Color(0.96, 0.32, 0.3))
			_hud_hp_fill.add_theme_stylebox_override("panel", _style(c, 8))
	var show_boss := guardian != null and is_instance_valid(guardian) and guardian.hp > 0.0
	if _boss_card:
		_boss_card.visible = show_boss

	if show_boss:
		if not _boss_shown or _boss_key != guardian.species_id:
			_boss_key = guardian.species_id
			_boss_lag = 1.0
			_boss_lag_hold = 0.0
			var info := _hud_info_for(guardian.species_id)
			_boss_name_label.text = String(info["name"])
			_boss_tag_label.text = "传说守护者" if zone == 4 else "守护者"
			# Cycle 21: phase ticks only for kit bosses
			# (a mech or a signature — the bundle's rule).
			var kit := BOSS_MECH.has(guardian.species_id) or BOSS_SIG.has(guardian.species_id)
			for tk in _boss_ticks:
				(tk as Control).visible = kit
			if _boss_pic:
				_boss_pic.texture = UiTheme.portrait(guardian.species_id)
		_boss_shown = true
		# Cycle 21: rage state on the tag (bundle bossRage).
		_refresh_boss_tag()
		if _boss_foot:
			# Cycle 21: while a move is announced (say(),
			# 2.2 s), the foot row carries the move name —
			# the bundle's bossSub line (ours shares the
			# foot row; DIFF §21).
			if _boss_move_t > 0.0 and _boss_move_name != "":
				_boss_foot.text = "▶ " + _boss_move_name
				_boss_foot.add_theme_color_override("font_color", UiTheme.GOLD)
			else:
				_boss_foot.add_theme_color_override("font_color", UiTheme.HUD_DIM)
				var foot: Array = []
				for t in GameData.species(guardian.species_id).get("types", []):
					foot.append(String((TYPE_HUD.get(String(t), [String(t)]) as Array)[0]))
				const SCN := {"burn": "灼伤", "poison": "中毒", "paralysis": "麻痹", "paralyze": "麻痹",
					"sleep": "睡眠", "freeze": "冰冻", "confuse": "混乱", "charm": "魅惑", "root": "缠绕"}
				if guardian.status_kind != "" and SCN.has(guardian.status_kind):
					foot.append(String(SCN[guardian.status_kind]))
				if guardian.wet_t > 0.0:
					foot.append("湿润")
				if run_roars > 0:
					foot.append("咆哮 ×%d" % run_roars)
				_boss_foot.text = " · ".join(foot)
			# U1 1:1 round 4: the foot shows ONLY for the move
			# announcement — the reference bar has no static
			# type row; the telegraph itself is kept.
			_boss_foot.visible = _boss_move_t > 0.0 and _boss_move_name != ""
		var bf := clampf(guardian.hp / maxf(guardian.max_hp, 1.0), 0.0, 1.0)
		if bf >= _boss_lag:
			_boss_lag = bf
			_boss_lag_hold = 0.45
		else:
			_boss_lag_hold -= delta
			if _boss_lag_hold <= 0.0:
				_boss_lag = maxf(bf, _boss_lag - delta * 0.6)
		_boss_hp_fill.size.x = 612.0 * bf
		_boss_hp_lag.size.x = 612.0 * _boss_lag
		_boss_hp_num.text = str(int(maxf(guardian.hp, 0.0)))
	else:
		_boss_shown = false
	_update_mini_bars(delta)
	# UI-mobile P4 (found by the full-slots state): the objective
	# pill drops / regains its alpha entry with the bars (plan
	# R4g) — refresh on the frame the visible-bar set changes,
	# not on the next 0.15 s tick (a stale "头领" / count).
	if _p3_on == 1:
		var nb := 0
		for bar in _mini_bars:
			if (bar["panel"] as Control).visible:
				nb += 1
		if nb != _p4_bars_seen:
			_p4_bars_seen = nb
			_refresh_event_pills()

## Cycle 19: the HUD move slot mirrors the player's first
## move — its type icon and a level strip (audit punch #15).
## Refreshed on signature change (drafts mutate moves).
func _refresh_boss_tag() -> void:
	if _boss_tag_label:
		# Keep the compact right-hand tag readable even during a move announcement.
		_boss_tag_label.text = "狂怒！" if _boss_enraged else ("传说守护者" if zone == 4 else "守护者")
		# U1 1:1 round 4: the tag sits on a cream chip —
		# dark ink normally, red while enraged.
		_boss_tag_label.add_theme_color_override("font_color",
			Color(1, 0.35, 0.3) if _boss_enraged else UiTheme.TEXT)

func _reskin_boss_visibility() -> void:
	# After this frame's camera / rig animation updates, before canvas rendering.
	if _boss_card != null and _boss_card.is_visible_in_tree():
		_boss_card.modulate.a = 0.0 if _boss_body_overlaps_header() else float(GameProfile.setting("bossOpacity"))

func _boss_body_overlaps_header() -> bool:
	if _cam == null or guardian == null or not is_instance_valid(guardian):
		return false
	var header := _p3_draw_rect(_boss_card)
	var stack: Array[Node] = [guardian]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
			var mesh := node as MeshInstance3D
			var bounds := mesh.get_aabb()
			var projected := Rect2()
			var first := true
			for i in range(8):
				var point := mesh.global_transform * bounds.get_endpoint(i)
				if _cam.is_position_behind(point):
					continue
				var screen := _cam.unproject_position(point)
				if first:
					projected = Rect2(screen, Vector2.ZERO)
					first = false
				else:
					projected = projected.expand(screen)
			if not first and projected.grow(16).intersects(header):
				return true
	return false

func _refresh_move_slot() -> void:
	if _move_slot_icon == null or player == null or not is_instance_valid(player):
		return
	if player.moves.is_empty():
		return
	var m0: Dictionary = player.moves[0]
	var sig := String(m0["key"]) + ":" + str(int(m0["level"]))
	if sig == _move_slot_sig:
		return
	_move_slot_sig = sig
	var t := String(GameData.move(String(m0["key"])).get("type", ""))
	_move_slot_icon.icon = _type_icon(t)
	_move_slot_icon.color = UiTheme.type_color(t).lightened(0.25)
	_move_name_label.text = "%d级" % int(m0["level"])

## Cycle 19: any modal surface up (draft / blessing / choice /
## pause / big map / results / menu overlays). Drives the
## shared scrim and the banner suppression in _process.
func _any_modal_open() -> bool:
	# Cycle 21.3 (audit §3, found by the hardened gate):
	# _meowth_panel (the in-run shop) joins the list — it
	# was missing, so the scrim never dimmed for the shop
	# and the banner was never suppressed under it.
	for p in [_draft_panel, _blessing_panel, _choice_panel,
			_pause_panel, _bigmap_panel, _result_panel,
			_lab_panel, _shop_panel, _sound_panel,
			_wallet_panel, _unlock_panel, _loadout_panel,
			_meowth_panel]:
		if p != null and (p as Control).visible:
			return true
	return false

func _refresh_hud() -> void:
	_timer_label.text = _fmt_time(ZONE_TIME - elapsed)
	_elapsed_label.text = _fmt_elapsed(elapsed)
	_kills_label.text = "击杀 %d" % kills
	_dust_label.text = str(GameProfile.stardust())
	_gold_label.text = str(int(gold))
	# Cycle 21: next-ball price (bundle wallet(): the price
	# is chestCost(); the element dims when unaffordable).
	if _ball_price_label:
		var bc := _chest_cost()
		_ball_price_label.text = str(bc)
		_ball_price_label.add_theme_color_override("font_color",
			Color.WHITE if gold >= float(bc) else Color("ffa694"))
	if player and is_instance_valid(player):
		_lv_label.text = "%d级" % player.level
		var frac := clampf(player.xp / maxf(float(player.xp_next()), 1.0), 0.0, 1.0)
		_medal_panel.set_xp(frac)
		_refresh_move_slot()
		_p4_refresh_slots(true)
		_refresh_meta()
	# Danger meter (cycle 17): the tier comes from a nearby-
	# threat sum — OUR proxy input (the bundle's exact danger
	# input is not in the mined evidence; thresholds, ramp and
	# names are bundle-verified, @1997817): normal 0.6, elite
	# 1.5, alpha 2.5, guardian 3.0, within 13 u of the player.
	var threat := 0.0
	if player and is_instance_valid(player) and state != "menu":
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en := e as Enemy
			if player.global_position.distance_to(en.global_position) < 13.0:
				threat += 3.0 if en.is_guardian else (2.5 if en.flag == 2 else (1.5 if en.flag == 1 else 0.6))
	var tier := 0
	for i in range(UiTheme.DANGER_THRESHOLDS.size()):
		if threat >= UiTheme.DANGER_THRESHOLDS[i]:
			tier = i
	_danger_name.text = UiTheme.DANGER_NAMES[tier]
	_danger_name.add_theme_color_override("font_color", UiTheme.DANGER_COLORS[tier])
	for i in range(_danger_segs.size()):
		var c: Color = UiTheme.DANGER_COLORS[i] if i <= tier else Color(1, 1, 1, 0.16)
		(_danger_segs[i] as Panel).add_theme_stylebox_override("panel", _style(c, 7))
	_refresh_weather_chip()
	# Cycle 18 HUD remainder, on the same 0.15 s tick.
	_refresh_party()
	_p2_hud_tick()
	_refresh_pw_chips()
	_refresh_goal_card()
	_refresh_event_pills()

## Cycle 17: the HUD weather chip (UI_SPEC §2.3 ht-weather) —
## drawn icon + the WEATHER_TABLE CN name of the live weather.
func _refresh_weather_chip() -> void:
	if _wx_label == null:
		return
	var row: Dictionary = WEATHER_TABLE.get(weather, WEATHER_TABLE["clear"])
	# UI-mobile P2 (plan T6): icon + one character on phone;
	# the full name + modifiers are a tap away (and on the
	# pause status page).
	_wx_label.text = String(row["cn"]).substr(0, 1) if _p2_on == 1 else String(row["cn"])
	# Icon order 2: every weather gets its own tile — clear and
	# harsh sun now differ, sandstorm is not wind, ashfall is
	# not fog (badges/weather_*.png via UiBadge.set_icon).
	var ic := "weather_sunny"
	match weather:
		"sun": ic = "weather_harsh_sun"
		"rain": ic = "weather_rain"
		"sand": ic = "weather_sandstorm"
		"hail": ic = "weather_hail"
		"fog": ic = "weather_fog"
		"ash": ic = "weather_ashfall"
	if _wx_icon:
		_wx_icon.set_icon(ic)

# --------------------------------------------------------------------- loop
## Touch input feeds the player through the same logical controls as the
## keyboard (see player.gd). Getters are null-safe for the menu state.
func get_touch_move() -> Vector2:
	return touch_controls.move_vector if touch_controls else Vector2.ZERO

func is_touch_jump() -> bool:
	return touch_controls != null and touch_controls.jump_held

func is_touch_dash() -> bool:
	return touch_controls != null and touch_controls.dash_held

func consume_touch_interact() -> bool:
	return touch_controls != null and touch_controls.consume_interact()

func _touch_wanted() -> bool:
	return _touch_forced or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()

func _input(event: InputEvent) -> void:
	# UI-mobile P3 (plan I4): a press outside the open drawer
	# folds it (the press itself is not consumed); a press
	# inside counts as interaction (re-arms the 4 s fold).
	if _obj_drawer != null and _obj_drawer.visible:
		var pp := Vector2.INF
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			pp = (event as InputEventScreenTouch).position
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			pp = (event as InputEventMouseButton).position
		if pp != Vector2.INF:
			if _p3_draw_rect(_obj_drawer).has_point(pp):
				_obj_drawer_t = 4.0
			elif not (_obj_hit.visible and _obj_hit.get_global_rect().has_point(pp)):
				_obj_close_drawer()
	# UI-mobile P3: the camera touch's drags turn the camera
	# HERE, before GUI routing — Godot hands a touch drag to
	# whatever STOP control is under the finger, so a camera
	# swipe sliding across a cluster button (lock now sits
	# on the arc, in the right thumb's swipe path) stalled
	# (gate-caught at 1920 s1.50: 1 of 6 drag steps turned).
	# The touch only BECOMES the camera touch in
	# _unhandled_input (its press hit no control).
	if event is InputEventScreenDrag and _cam_touch_id != -1 \
			and (event as InputEventScreenDrag).index == _cam_touch_id \
			and state != "menu" and not _any_modal_open():
		_cam_rotate((event as InputEventScreenDrag).relative)
	if event is InputEventScreenTouch:
		_touch_forced = true
		# UI-mobile P1 addendum: a camera touch's release can
		# land on a modal that opened mid-drag (GUI eats it
		# before _unhandled_input) — clear the id here, where
		# every touch passes first.
		if not (event as InputEventScreenTouch).pressed \
				and (event as InputEventScreenTouch).index == _cam_touch_id:
			_cam_touch_id = -1
	elif event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo:
			_handle_ui_key(ek.keycode)

## Modal number keys (UI_SPEC §1.3/§2.5/§2.6): 1–9 pick a
## card; R rerolls the draft. Blessing keys arm 350 ms after
## the modal opens (their anti-misclick rule); draft keys are
## live at once (YR parses them directly).
func _handle_ui_key(keycode: Key) -> void:
	# Cycle 18: the pause channel (Esc/P). Opens only from
	# live run states; the draft/blessing/choice states own
	# their keys below and never reach pause.
	if state == "pause":
		if keycode == KEY_ESCAPE or keycode == KEY_P \
				or (keycode == KEY_TAB and _pause_peek_return != ""):
			_close_pause()
		return
	if (keycode == KEY_ESCAPE or keycode == KEY_P) \
			and state in ["playing", "guardian", "portal", "bigmap"]:
		if state == "bigmap":
			_close_big_map()
		else:
			_open_pause()
		return
	if state == "draft":
		# Cycle 19: Tab peeks the team (Yk); S/B are the
		# skip/banish tool keys the kbd caps name.
		if keycode == KEY_TAB:
			_open_team_view()
			return
		if keycode == KEY_R:
			_draft_reroll()
			return
		if keycode == KEY_S:
			_draft_skip()
			return
		if keycode == KEY_B:
			_draft_toggle_banish()
			return
		var di := int(keycode) - int(KEY_1)
		if di >= 0 and di < _draft_options.size():
			if _draft_banish_mode:
				_banish_press(di)  # same digit twice commits (audit §4.1)
			else:
				_apply_draft_option(di)
	elif state == "blessing" and _blessing_open:
		if keycode == KEY_TAB:
			_open_team_view()
			return
		if Time.get_ticks_msec() - _blessing_opened_msec < 350:
			return
		var bi := int(keycode) - int(KEY_1)
		if bi >= 0 and bi < _blessing_offers.size():
			_apply_blessing_offer(bi)
	elif state == "choice" and _choice_open:
		var ci := int(keycode) - int(KEY_1)
		if ci >= 0 and ci < _choice_opts_box.get_child_count():
			_choice_pick(ci)

func _unhandled_input(event: InputEvent) -> void:
	if state == "menu":
		return
	# UI-mobile P1 addendum (plan A6 K9 / B5 P9): two-thumb
	# camera. Touch drags rotate the camera from their OWN
	# events, tracked by touch index — the old path only saw
	# the mouse Godot emulates from touch index 0, and the
	# joystick zone (MOUSE_FILTER_STOP) owns index 0 whenever
	# the left thumb lands first, so a right-thumb drag
	# (index 1) never turned the camera. A touch reaches here
	# only when no GUI control took it (the joystick zone and
	# the buttons consume theirs); the joystick's own id is
	# excluded as a belt-and-braces guard.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var jid: int = touch_controls.joy_touch_id() if touch_controls else -1
			if _cam_touch_id == -1 and st.index != jid:
				_cam_touch_id = st.index
		elif st.index == _cam_touch_id:
			_cam_touch_id = -1
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# Mouse motion EMULATED from touch is skipped: the
		# touch path above already turned the camera for it.
		if mm.device != InputEvent.DEVICE_ID_EMULATION \
				and (mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
			_cam_rotate(mm.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 1.0, 4.5, 20.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 1.0, 4.5, 20.0)

## Drag -> camera (mouse and touch share it). Cycle 18
## settings: sensitivity multiplier + Y invert.
func _cam_rotate(rel: Vector2) -> void:
	var cs := float(GameProfile.setting("camSpeed"))
	var iy := -1.0 if bool(GameProfile.setting("invertY")) else 1.0
	cam_yaw -= rel.x * 0.005 * cs
	cam_pitch = clampf(cam_pitch + rel.y * 0.005 * cs * iy, 0.12, 1.25)

func _process(delta: float) -> void:
	_music_director_tick(delta)
	_touch_text_sync()
	# Cycle 17: the HUD cluster belongs to a run; the menu
	# floats over the bare 3D scene (the pre-17 menu showed
	# the whole HUD through/behind its panel).
	if _hud_root != null:
		# U5: the result screen is a clean celebration over the
		# scene (reference: no HUD) -- hide the HUD while the
		# result panel is up; the scrim still dims the scene.
		var want_hud := state != "menu" and not (_result_panel != null and _result_panel.visible)
		if _hud_root.visible != want_hud:
			_hud_root.visible = want_hud
	# Cycle 12: an uncached portal switch deferred one frame so its
	# loading banner renders before the build stall.
	if _switch_pending != 0:
		var pz := _switch_pending
		_switch_pending = 0
		if zone + 1 == pz:
			_on_portal_entered()
	_weather_tick(delta)
	# Cycle 14: the combat meter ticks on the world clock while a
	# run is live (its windows are wall-clock seconds, B_ @720250).
	if running:
		_meter_tick(delta)
	# Cycle 9 hitstop: the timer burns in real time; while it runs,
	# the simulation blocks below (zone clock, spawner, projectiles,
	# alpha/league lifecycles, chests) are skipped and bodies
	# self-freeze through hitstop_active(). UI keeps running.
	if _hitstop_t > 0.0:
		_hitstop_t -= delta
	var sim_frozen := _hitstop_t > 0.0
	# Evolution morph shake (cycle 9): continuous shake(.02) feed.
	if _evo_fx_t > 0.0:
		_evo_fx_t -= delta
		add_trauma(0.02)
	# Camera kick decay (rate INFERRED — the bundle shows the kick
	# raise and the 0.012 cap, not the renderer's decay constant).
	if _chroma > 0.0:
		_chroma *= exp(-5.0 * delta)
		if _chroma < 0.0004:
			_chroma = 0.0
		if _vignette_mat:
			_vignette_mat.set_shader_parameter("chroma", _chroma)
	# ui.damageFlash decay.
	if _dmg_flash > 0.0:
		_dmg_flash = maxf(0.0, _dmg_flash - delta * 2.2)
		if _dmg_flash_rect:
			_dmg_flash_rect.color.a = _dmg_flash * 0.38
	# Cycle 13: the ult controller ticks on the world's clock.
	# It is NOT gated on hitstop — the bundle's later() scheduler
	# runs through their freeze frames too (the cast lands at
	# +0.03 s, inside the .32 s cast hitstop).
	if ult and running:
		ult.update(delta)
	_update_hud_bars(delta)
	# Floating texts rise and fade (0.9 s life).
	for i in range(_floaters.size() - 1, -1, -1):
		var fx: Dictionary = _floaters[i]
		fx["t"] = float(fx["t"]) + delta
		var node = fx["node"]
		if not is_instance_valid(node) or float(fx["t"]) >= 0.9:
			if is_instance_valid(node):
				node.queue_free()
			_floaters.remove_at(i)
			continue
		node.global_position.y += delta * 0.9
		var k: float = float(fx["t"]) / 0.9
		node.modulate.a = 1.0 - k * k
		# Cycle 17: distance compensation (UI_SPEC §2.3's
		# scale-with-distance rule, clamped).
		if _cam != null and fx.has("px"):
			var dist := _cam.global_position.distance_to(node.global_position)
			node.pixel_size = float(fx["px"]) * clampf(dist * 0.08, 0.6, 2.4)
	# Chests: gentle spin; walk-over opens (guardian reward).
	if running and not sim_frozen and player and is_instance_valid(player):
		for c in _chests:
			if bool(c["opened"]):
				continue
			var cn = c["node"]
			if not is_instance_valid(cn):
				continue
			if c.has("fall_y"):
				c.fall_v = float(c.fall_v) + 18.0 * delta
				cn.position.y = maxf(float(c.fall_y),cn.position.y-float(c.fall_v)*delta)
				if cn.position.y > float(c.fall_y):
					continue
				c.erase("fall_y")
			cn.rotation.y += delta * 1.2
			if player.global_position.distance_to(cn.global_position) < 2.3:
				_open_chest(c)
	if _crystal:
		_crystal.rotation.y += delta * 0.9
		_crystal.position.y = _crystal_base_y + sin(Time.get_ticks_msec() * 0.002) * 0.25
	if _ring and state == "playing":
		var p := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.05
		_ring.scale = Vector3.ONE * p
	if portal_node:
		portal_node.rotation.y += delta * 1.4
	# UI-mobile P1.4: the banner clock FREEZES while a modal
	# owns the screen (it used to burn down unseen, losing
	# every line raised under a draft / shop / pause); the
	# queue advances once the live line has had its minimum
	# min(secs, 1.2) s, or when it expires.
	if not _any_modal_open():
		if _banner_t > 0.0:
			_banner_t -= delta
			_banner_shown_t += delta
		if not _banner_q.is_empty() and (_banner_t <= 0.0
				or _banner_shown_t >= minf(_banner_secs, 1.2)):
			var nx: Array = _banner_q.pop_front()
			_banner_show_now(String(nx[0]), float(nx[1]))
			_layout_hud()
	# Cycle 19 (audit punch #8/#9): the banner and its
	# backing band never show while a modal owns the screen
	# (P1.4: its clock is frozen meanwhile), and the shared
	# scrim tracks modal visibility.
	var banner_a := 1.0 if (_banner_t > 0.0 and not _any_modal_open()) else 0.0
	if _banner:
		_banner.modulate.a = banner_a
	if _banner_back:
		_banner_back.modulate.a = banner_a
	# Cycle 19: draft-card shine sweep (rarity >= 2 cards).
	if _draft_panel and _draft_panel.visible and not _draft_shines.is_empty():
		var st := float(Time.get_ticks_msec()) / 1000.0
		for rec in _draft_shines:
			var r := rec["rect"] as TextureRect
			if is_instance_valid(r):
				r.position.x = -140.0 + fmod(st * 130.0 + float(rec["phase"]) * 130.0, 360.0)
	if _modal_scrim:
		var mo := _any_modal_open()
		if _modal_scrim.visible != mo:
			_modal_scrim.visible = mo
	if _p5_on:
		_p5_tick()
	# Effects (cycle 11: beam ribbons / ground rings / legacy beams).
	for i in range(_effects.size() - 1, -1, -1):
		var fx: Dictionary = _effects[i]
		fx["t"] = float(fx["t"]) + delta
		var life: float = float(fx.get("life", 0.18))
		var node = fx["node"]
		if not is_instance_valid(node):
			_effects.remove_at(i)
			continue
		var k: float = float(fx["t"]) / life
		if k >= 1.0:
			node.queue_free()
			_effects.remove_at(i)
			continue
		var kind := String(fx.get("kind", "legacy"))
		if kind == "beam":
			var frac := 1.0 - k
			var sm := fx["smat"] as ShaderMaterial
			sm.set_shader_parameter("fade", minf(1.0, frac * 2.0))
			sm.set_shader_parameter("shrink", 0.4 + 0.6 * frac)
		elif kind == "ring":
			var rr := lerpf(float(fx["r0"]), float(fx["r1"]), 1.0 - (1.0 - k) * (1.0 - k))
			node.scale = Vector3(rr, 1.0, rr)
			var rm := fx["mat"] as StandardMaterial3D
			rm.albedo_color.a = 0.55 * (1.0 - k)
		else:
			node.scale = Vector3.ONE * (0.7 + 0.45 * k)
			var m := fx["mat"] as StandardMaterial3D
			m.albedo_color.a = 0.9 * (1.0 - k)
	# Cycle 11 sprite particles (sparks, flashes, leaves, twinkles).
	for i in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[i]
		pt["t"] = float(pt["t"]) + delta
		var pnode = pt["node"]
		if not is_instance_valid(pnode):
			_particles.remove_at(i)
			continue
		var pk: float = float(pt["t"]) / float(pt["life"])
		if pk >= 1.0:
			pnode.queue_free()
			_particles.remove_at(i)
			continue
		var vel: Vector3 = pt["vel"]
		vel.y -= float(pt["grav"]) * delta
		if float(pt["drag"]) > 0.0:
			vel *= exp(-float(pt["drag"]) * delta)
		pt["vel"] = vel
		pnode.global_position += vel * delta
		pnode.scale = Vector3.ONE * lerpf(float(pt["s0"]), float(pt["s1"]), pk)
		var pm := pt["mat"] as StandardMaterial3D
		pm.albedo_color.a = float(pt["a0"]) * (1.0 - pk)
	# Zone clock.
	if running and not sim_frozen:
		elapsed += delta
		run_time += delta
		pickup_manager().tick(delta)
		if elapsed >= ZONE_TIME and not _swarm:
			_swarm = true
			show_banner("Final Swarm！野怪暴走了，坚持住！", 4.0)
	# Level-up sequence: evolution/growth consume no draft (§1.2);
	# other levels open the draft (world clock paused meanwhile).
	if player and is_instance_valid(player) and player.pending_levels > 0 and state in ["playing", "guardian", "portal"]:
		_step_level_up()
	# Alpha timeline + league encounter lifecycle (§4.3 / §5.2).
	if running and not sim_frozen and state in ["playing", "guardian"]:
		if _alpha_idx < ALPHA_TIMES.size() and elapsed >= tier_timeline_time(float(ALPHA_TIMES[_alpha_idx])):
			_alpha_idx += 1
			_spawn_alpha()
		_tick_capture_director()
		if not _league_done and is_instance_valid(_league_e):
			if not _league_e.is_weakened:
				_league_escape -= delta
				if _league_escape <= 0.0:
					show_banner("%s 逃走了…" % String(ModelRig.SPECIES[_league_e.species_id]["label"]), 3.0)
					_league_e.capture_remove()
					_league_e = null
					_league_done = true
	# Camera: the original's updateCamera (bundle-traced; DIFF "Game feel"):
	# focus damps per-axis (solo rates XZ 18 / Y 10), position = focus
	# +1.5 base + pitch/dist offset + 0.6, lookAt focus +1.8, FOV =
	# 70 + clamp((speed-8)*0.8, 0, 10) damped at rate 6, terrain lift
	# damped 22 rising / 5 falling.
	var target := _cam_focus
	if player and is_instance_valid(player):
		target = player.global_position
	_cam_focus.x = _damp(_cam_focus.x, target.x, 18.0, delta)
	_cam_focus.z = _damp(_cam_focus.z, target.z, 18.0, delta)
	_cam_focus.y = _damp(_cam_focus.y, target.y, 10.0, delta)
	var cp := cos(cam_pitch)
	var off := Vector3(sin(cam_yaw) * cp, sin(cam_pitch), cos(cam_yaw) * cp) * cam_dist
	var cam_pos := _cam_focus + Vector3(0, 1.5, 0) + off + Vector3(0, 0.6, 0)
	var need := maxf(height_at(cam_pos.x, cam_pos.z) + 1.0 - cam_pos.y, 0.0)
	_cam_lift = _damp(_cam_lift, need, 22.0 if need > _cam_lift else 5.0, delta)
	cam_pos.y += _cam_lift
	# Trauma shake (cycle 8, bundle @1493252): decay 2/s; the offset
	# is added to the camera POSITION only — the look target below
	# stays unshaken, exactly like the original.
	trauma = maxf(0.0, trauma - delta * 2.0)
	if trauma > 0.0:
		var w := trauma * trauma * 0.3
		var tt := Time.get_ticks_msec() / 1000.0 * 26.0
		cam_pos += Vector3(sin(tt * 1.1) * w, sin(tt * 1.7 + 1.0) * w * 0.8, sin(tt * 1.3 + 2.0) * w)
	_cam.global_position = cam_pos
	var look := _cam_focus + Vector3(0, 1.8, 0)
	if cam_pos.distance_to(look) > 0.05:
		_cam.look_at(look, Vector3.UP)
	if player and is_instance_valid(player):
		var fov_t := 70.0 + clampf((player.get_speed_now() - 8.0) * 0.8, 0.0, 10.0)
		_cam_fov = _damp(_cam_fov, fov_t, 6.0, delta)
		_cam.fov = _cam_fov
	# Cycle 18 aim assist (the tc-aim toggle's consumer): with
	# it on, the yaw eases to sit behind the player's lock
	# target (or travel direction) — a gentle 2.5/s damp, and
	# manual drags still win while they happen (the drag
	# writes cam_yaw directly in _unhandled_input).
	if bool(GameProfile.setting("camAssist")) and running \
			and state in ["playing", "guardian", "portal"] \
			and player and is_instance_valid(player):
		var face := Vector3.ZERO
		var lt: Node = null
		if player.lock_target != null and is_instance_valid(player.lock_target):
			lt = player.lock_target
		if lt != null:
			face = (lt as Node3D).global_position - player.global_position
		else:
			face = Vector3(player._vel.x, 0, player._vel.z)
		face.y = 0.0
		if face.length() > 0.5:
			face = face.normalized()
			var want_yaw := atan2(-face.x, -face.z)
			cam_yaw = lerp_angle(cam_yaw, want_yaw, 1.0 - exp(-2.5 * delta))
	# Spawner.
	if not sim_frozen and state in ["playing", "guardian", "portal"]:
		_boss_tick(delta)  # cycle 21: Nb boss brain
		_event_tick(delta)  # cycle 21: stage events (ax/sx)
		_passive_ticks()  # cycle 21: passive backlog I
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			# Cycle 15: the bundle's spawn credit rate scales
			# with stats.difficulty x stats.enemyAmount
			# (director @858327) — the interval divides by
			# the same product (the 60-enemy perf cap stays).
			var rate := 1.0
			if player != null and is_instance_valid(player):
				rate = maxf(0.05, player.difficulty_mult * player.enemy_amount_mult * tier_value("amount"))
			_spawn_t = (0.45 if _swarm else 0.9) / rate
			if get_tree().get_nodes_in_group("enemies").size() < _enemy_cap():
				_spawn_enemy()
		_timers_tick(delta)
		# Cycle 18 boost events on the world clock: honey's
		# extra alpha (bundle stage schedule t=240, @852778).
		if _honey_at > 0.0 and elapsed >= tier_timeline_time(_honey_at):
			_honey_at = -1.0
			_spawn_alpha()
		if is_instance_valid(_classic_e):
			if _classic_e.mode != Enemy.MODE_LEAGUE:
				_classic_e = null
			elif not _classic_e.is_weakened:
				_classic_escape -= delta
				if _classic_escape <= 0.0:
					_classic_e.capture_remove()
					_classic_e = null
		# Shiny encounter lifecycle (mirrors the league one:
		# the ladder flee clock — 120 s, 150 s with the Shiny
		# Charm — that holds while weakened).
		if _shiny_e != null:
			if not is_instance_valid(_shiny_e) or _shiny_e.mode != Enemy.MODE_LEAGUE:
				_shiny_e = null
			elif not _shiny_e.is_weakened:
				_shiny_escape -= delta
				if _shiny_escape <= 0.0:
					show_banner("流光的 %s 逃走了…" % String(ModelRig.SPECIES[_shiny_e.species_id]["label"]), 3.0)
					_shiny_e.capture_remove()
					_shiny_e = null
		# Fog of war (big map): mark the player's cell ring
		# visited ~4x/s.
		_fog_t -= delta
		if _fog_t <= 0.0:
			_fog_t = 0.25
			_fog_mark(player.global_position, 18.0)
	# Cycle 14: altar charging + totem animation tick on the same
	# world clock; queued blessings open once the run is back in
	# play (offerBlessing's whenFree).
	if not sim_frozen and running and state in ["playing", "guardian", "portal"]:
		_inter_tick(delta)
	if not _blessing_open and not _blessing_queue.is_empty() and state in ["playing", "guardian"]:
		var bq: Dictionary = _blessing_queue.pop_front()
		offer_blessing(String(bq["title"]), int(bq["min"]), int(bq["offers"]), int(bq["picks"]), float(bq.get("power", 1.0)))
	# Touch UI visibility: only during play, only on touch devices
	# (or when forced by the harness / a first real touch).
	if touch_controls:
		# Cycle 21.3 (audit §3): the modal clause is
		# EXPLICIT — the touch layer is the last child of
		# the outer root and draws above every modal, so
		# it must never rely on the state machine alone
		# to stay hidden while a modal owns the screen.
		var show_tc := state in ["playing", "guardian", "portal"] and _touch_wanted() \
			and not _any_modal_open()
		if touch_controls.visible != show_tc:
			touch_controls.visible = show_tc
		# Cycle 18 cluster buttons: pause / aim edges.
		if touch_controls.visible:
			if touch_controls.consume_touch_pause() and state in ["playing", "guardian", "portal"]:
				_open_pause()
			if touch_controls.consume_touch_lock():
				_toggle_target_lock()
			if touch_controls.consume_touch_aim():
				var na := not bool(GameProfile.setting("camAssist"))
				GameProfile.set_setting("camAssist", na)
				touch_controls.set_aim_state(na)
				show_banner("镜头辅助：%s" % ("开" if na else "关"), 1.5)
		# UI-mobile P3 (plan I4): the objective drawer never
		# pauses; it folds after 4 s without input, when a
		# modal opens, or when the run leaves play.
		if _obj_drawer != null and _obj_drawer.visible:
			if _p3_on != 1 or _any_modal_open() \
					or state not in ["playing", "guardian", "portal"]:
				_obj_close_drawer()
			else:
				_obj_drawer_t -= delta
				if _obj_drawer_t <= 0.0:
					_obj_close_drawer()
	# P3 class D: rebuilt drawer rows have sorted — measure now.
	if _obj_drawer_settle > 0:
		_obj_drawer_settle -= 1
		if _obj_drawer_settle == 0:
			_layout_hud()
	# Capture candidate: a weakened league encounter or a downed
	# alpha within throw range (9 u, §5.1) outranks the altar for E.
	var cand := _capture_candidate()
	# Altar prompt + E interaction + portal entry.
	var e_now := Input.is_key_pressed(KEY_E) or consume_touch_interact()
	# UI-mobile P1.2 (plan §B3 I8): what a tap on the
	# interact button would do RIGHT NOW — 0 idle (nothing
	# in range), 1 ready, 2 throw; pushed to the button.
	var act := 0
	if player and is_instance_valid(player):
		var flat_p := Vector2(player.global_position.x, player.global_position.z)
		if cand != null and state in ["playing", "guardian", "portal"]:
			act = 2
			var what := "结伴匣" if cand.is_downed else "结伴它加入伙伴营"
			_prompt.text = "%s邀伴：%s！（%s）" % [_ik(), what, String(ModelRig.SPECIES[cand.species_id]["label"])]
			if e_now and not _e_prev:
				_throw_ball(cand)
		elif state == "playing":
			var near_altar := flat_p.distance_to(ALTAR_XZ) < 6.5
			var hint := "%s召唤守护者" % _ik()
			# Cycle 14: the roar totem outranks the boss altar inside
			# its own interact radius (the bundle picks the nearest
			# interactable; the capture candidate still outranks all).
			# Cycle 15: populate props join the same nearest-wins
			# chain — a prop nearer than the totem takes the prompt.
			var tot := _totem_near(flat_p)
			var prop := _prop_near(flat_p)
			var prop_wins := false
			if not prop.is_empty():
				if tot.is_empty():
					prop_wins = true
				else:
					var pd := flat_p.distance_to(Vector2(float(prop["x"]), float(prop["z"])))
					var td := flat_p.distance_to(Vector2(float(tot["x"]), float(tot["z"])))
					prop_wins = pd < td
			if not tot.is_empty() and not prop_wins:
				act = 1
				_prompt.text = _totem_label(tot)
				if e_now and not _e_prev and not bool(tot["used"]):
					_roar_at_totem(tot)
			elif prop_wins:
				act = 1
				_prompt.text = _prop_label(prop)
				if e_now and not _e_prev:
					_interact_prop(prop)
			elif near_altar:
				act = 1
				_prompt.text = hint
				if e_now and not _e_prev:
					summon_guardian()
			else:
				_prompt.text = _altar_hint(flat_p)
		elif state == "guardian":
			# Cycle 15: props stay usable during the guardian
			# fight (the bundle's stage keeps running its
			# interactables; its boss fight is inside 'play').
			var gprop := _prop_near(flat_p)
			if not gprop.is_empty():
				act = 1
				_prompt.text = _prop_label(gprop)
				if e_now and not _e_prev:
					_interact_prop(gprop)
			else:
				_prompt.text = "击败守护者！"
		elif state == "portal":
			_prompt.text = "走进紫色传送门！"
			if portal_node and flat_p.distance_to(Vector2(portal_node.global_position.x, portal_node.global_position.z)) < 2.8:
				_on_portal_entered()
		else:
			_prompt.text = ""
	if touch_controls:
		touch_controls.set_interact_mode(act)
	# Cycle 21.3 (§5): the prompt's ink-glass backing
	# tracks its text.
	# One semantic hint: generic boss/portal prompt yields while its banner is on screen.
	var duplicate_hint := _banner != null and _banner.modulate.a > 0.0 and (
		(_prompt.text == "击败守护者！" and _banner.text.contains("守护者"))
		or (_prompt.text == "走进紫色传送门！" and _banner.text.contains("传送门")))
	_prompt.modulate.a = 0.0 if duplicate_hint else 1.0
	if _prompt_tri:
		_prompt_tri.modulate.a = _prompt.modulate.a
	if _prompt_back:
		_prompt_back.modulate.a = _prompt.modulate.a
		_prompt_back.visible = _prompt.text != ""
		# Cycle 21.3.1 (re-audit N2): on desktop the
		# phone branch never mirrors the backing, so
		# it kept its creation slab (624x130, bottom
		# past the viewport, over the slot band)
		# while the label draws at content size
		# (600x32). Mirror the label's drawn rect
		# here, with the same pads _layout_prompt
		# uses on phone (8 side / 6 vertical).
		if _prompt_back.visible and _phone_factor() <= 1.01:
			_prompt_back.position = _prompt.position - Vector2(8.0, 6.0)
			_prompt_back.size = _prompt.size + Vector2(16.0, 12.0)
	# UI-mobile P4: the bubble is sized to its text — re-fit
	# on every text change (a stale width would wrap past 2).
	if _p4_on == 1 and _prompt != null and _prompt.text != _p4_prompt_last:
		_p4_prompt_last = _prompt.text
		_layout_hud()
	_e_prev = e_now
	# Projectiles (frozen during hitstop).
	for i in range(_projectiles.size() - 1, -1, -1):
		if sim_frozen:
			break
		var pr: Dictionary = _projectiles[i]
		var node = pr["node"]
		var tgt = pr["target"]
		if not is_instance_valid(tgt) or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_projectiles.remove_at(i)
			continue
		var aim: Vector3 = tgt.global_position + Vector3(0, 1.0, 0)
		var to: Vector3 = aim - node.global_position
		if to.length() < 1.0:
			if pr.has("ally"):
				# Ally shot (cycle 9): explode — every enemy in
				# explode_r takes the combat.hit (bundle @527200).
				var ally = pr["ally"]
				var er := float(pr["explode_r"])
				var mt := String(pr["mtype"])
				if is_instance_valid(ally):
					for e in get_tree().get_nodes_in_group("enemies"):
						if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
							continue
						if bool(e.get("is_downed")) or bool(e.get("is_weakened")):
							continue
						var dd: Vector3 = e.global_position - tgt.global_position
						dd.y = 0.0
						if dd.length() <= er:
							combat_hit(e, float(pr["dmg"]), mt, "special", ally.types,
								{"status": GameData.ally_status_for(mt), "status_chance": 20.0,
								"knock": 1.0, "from": ally.global_position, "ally": ally})
			else:
				var dealt: float = tgt.take_damage(float(pr["dmg"]), String(pr.get("mtype", "")), String(pr.get("ailment", "")), float(pr.get("achance", 0.0)))
				add_damage(dealt)
				if pr.has("move"):
					add_move_damage(String(pr["move"]), dealt)
			node.queue_free()
			_projectiles.remove_at(i)
			continue
		node.global_position += to.normalized() * float(pr["speed"]) * delta
	# HUD refresh tick.
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.15
		_refresh_hud()

# ---------------------------------------------------------------- capture
## Nearest throwable target (§5.1 range gate: horizontal distance < 9).
func _capture_candidate() -> Enemy:
	if player == null or not is_instance_valid(player):
		return null
	var best: Enemy = null
	var best_d := 9.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not (bool(e.get("is_weakened")) or bool(e.get("is_downed"))):
			continue
		var d: float = player.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## Throw resolution (§5.2 league / §5.3 friend ball):
##   chance = base + captureRate/255*0.35 + attempts*0.20 (+0.15 if
##   the target is asleep), capped at 0.97 (league) / 0.95 (friend).
func _throw_ball(e: Enemy) -> void:
	if not is_instance_valid(e) or e.mode == Enemy.MODE_ALLY:
		return  # Captured/pending allies cannot be captured again.
	var is_league := e.mode == Enemy.MODE_LEAGUE
	# Team cap first (§5.3): don't burn a throw on a full party.
	if not is_league and _normal_ally_count() >= _team_cap():
		show_banner("队伍已满（%d 只）！研究室 party 可扩到 3 只" % _team_cap(), 3.0)
		return
	# Cycle 16: throw + open sounds; our capture resolves
	# instantly (the bundle animates shakes over seconds and
	# ducks the music for the cinematic — no window here).
	audio.throw_ball()
	audio.ball_open()
	var base := 0.55 if is_league else 0.45
	var chance := base + float(e.capture_rate) / 255.0 * 0.35 + float(e.capture_attempts) * 0.20
	if e.has_capture_status():
		chance += 0.15
	var cap := 0.97 if is_league else 0.95
	var label := String(ModelRig.SPECIES[e.species_id]["label"])
	# Cycle 18: the Master Ball boost — the run's FIRST throw
	# at a capturable target (league / downed alpha) is sure
	# (bundle throwBall @1057676: useMasterBall() -> n = 1).
	# Consumed by the throw itself; the team-cap return above
	# never reaches here, so a full party can't burn it.
	var mb := false
	if _master_ball and (is_league or e.is_downed):
		_master_ball = false
		mb = true
	# §5.2's exact判定 (cycle 8 fix): rand < min(cap, chance) OR
	# chance >= 1 (a built-up chance is a SURE capture, not 97%).
	# Cycle 21: the shiny-boss takeover throw is guaranteed
	# (bundle capture.sure for takeOver targets).
	var success := mb or _takeover_e == e or _rng.randf() < minf(cap, chance) or (is_league and chance >= 1.0)
	if success:
		audio.ball_click()
		audio.caught()
		audio.cry(e.species_id)
		run_captures.append(e.species_id)  # cycle 18: results grid
		if e.shiny and _shiny_e == e:
			# Cycle 20 (bundle spawnShiny): the encounter is
			# spawned with the unlock flag FALSE — capturing it
			# records the shiny dex ONLY; it does not join the
			# league or complete its challenge. The capture
			# grant is Stardust: +120 for a NEW shiny species,
			# +50 for a repeat (main @1058894-area), paid with
			# the bundle's pink capture beam.
			_shiny_e = null
			_takeover_e = null
			var is_new := not GameProfile.has_shiny(e.species_id)
			GameProfile.record_shiny(e.species_id)
			var grant := 120 if is_new else 50
			GameProfile.add_stardust(grant)
			captured += 1
			_shiny_beam(e.global_position)
			_offer_shiny_ally(e)
			show_banner("流光的 %s 被结伴了！萤尘 +%d（流光伙伴册 %d 只）\n%s" % [label, grant, GameProfile.shiny_count(), _skin_unlock_note(e.species_id)], 3.5)
			_refresh_meta()
		elif e.classic:
			_classic_e = null
			var grant := GameProfile.record_classic(e.species_id)
			captured += 1
			e.capture_remove()
			show_banner("经典流光 %s 被结伴！萤尘 +%d；家族经典皮肤已记录" % [label, grant], 3.5)
			_refresh_meta()
		elif is_league:
			var sd: Dictionary = GameData.species(e.species_id)
			GameProfile.join_league(int(sd.get("family", 0)), e.species_id)
			captured += 1
			if _league_e == e:
				_league_e = null
				_league_done = true
			e.capture_remove()
			show_banner("%s 加入了伙伴营！（伙伴营共 %d 只）" % [label, (GameProfile.data.get("league", []) as Array).size()], 3.5)
			_refresh_meta()
		else:
			# Cycle 9: no frozen power/cooldown snapshot — the ally
			# record recomputes both live (Enemy.ally_power_now /
			# ally_cd_now, bundle power(e) @519822).
			e.make_ally()
			GameProfile.count("alphaCaught")  # roster counter (Ditto gate)
			captured += 1
			show_banner("%s 成了你的队友！（本局为你而战）" % label, 3.5)
	else:
		audio.ball_shake()
		e.capture_attempts += 1
		if is_league:
			if e.capture_attempts >= 3:
				show_banner("%s 挣脱并逃走了…" % label, 3.0)
				if _league_e == e:
					_league_e = null
					_league_done = true
				if _classic_e == e:
					_classic_e = null
				if _shiny_e == e:
					_shiny_e = null
				e.capture_remove()
			else:
				e.weak_t = 6.0  # §5.2: re-weakened with a 6 s window
				show_banner("挣脱了！再投一次（成功率上升）", 2.0)
		else:
			e.friend_ball_fail()
			show_banner("%s 挣脱并恢复了战斗！" % label, 2.5)

# ------------------------------------------------------------- debug hooks
func debug_show_touch() -> void:
	_touch_forced = true

func debug_start(p_species: String) -> void:
	start_game(p_species)

func debug_teleport_player(x: float, z: float) -> void:
	if player:
		player.global_position = Vector3(x, height_at(x, z), z)
		player.reset_physics_interpolation()
		_cam_focus = player.global_position

func debug_summon() -> void:
	summon_guardian()

func debug_kill_guardian() -> void:
	if guardian and is_instance_valid(guardian):
		guardian.take_damage(99999.0)

func debug_time_set(sec: float) -> void:
	elapsed = sec

func debug_gain_xp(n: float) -> void:
	if player:
		player.gain_xp(n)

func debug_set_zone(n: int) -> void:
	if player and n != zone and n >= 1 and n <= 4:
		zone = n - 1
		state = "portal"
		_advance_zone()

func debug_spawn_league_now() -> void:
	_league_done = false
	_league_e = null
	_spawn_league()

func debug_spawn_alpha_now() -> void:
	_spawn_alpha()

func debug_give_stardust(n: int) -> void:
	GameProfile.add_stardust(n)
	_refresh_meta()

func debug_spawn_pack() -> void:
	if player == null:
		return
	var species_list := ["rattata", "pidgey", "sandshrew", "geodude", "rattata", "geodude"]
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		var pos := player.global_position + Vector3(cos(ang) * 8.0, 0, sin(ang) * 8.0)
		pos.y = height_at(pos.x, pos.z)
		_spawn_enemy_at(species_list[i], pos, 1.0)

# ------------------------------------------------------------- cycle 8 debug
func debug_add_counter(counter: String, n: float) -> void:
	GameProfile.count(counter, n)

func debug_counter(counter: String) -> float:
	return GameProfile.counter_value(counter)

func debug_challenge_done(species_key: String) -> bool:
	return GameProfile.challenge_done(species_key)

func debug_trauma() -> float:
	return trauma

func debug_slam(fall_h: float) -> void:
	if player:
		player_slam(player.global_position, fall_h, true)

func debug_league_species() -> String:
	if _league_e and is_instance_valid(_league_e):
		return _league_e.species_id
	return ""

func debug_dressing_count(kind: String) -> int:
	var n := 0
	var stack: Array = [_dress_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur.has_meta("kind") and String(cur.get_meta("kind")) == kind:
			n += 1
		for c in cur.get_children():
			stack.append(c)
	return n

func debug_unlock_rows() -> int:
	_refresh_unlock_panel()
	return _unlock_list.get_child_count() if _unlock_list else 0

func debug_starter_unlock_buttons() -> int:
	_refresh_starter_unlocks()
	return _starter_unlock_box.get_child_count() if _starter_unlock_box else 0


# =====================================================================
# Cycle 18: UI round 2 — adaptation layer, bag bring-in, results,
# pause, settings glue, big map, loadout, HUD remainder.
# =====================================================================

# ---------------------------------------------------------- adaptation
## The kR-style scaler (UI_SPEC §3): the bundle's factor is
## clamp(min(vw/1920, vh/1080), 1, 2) x 1.1 — DEFINED against
## its 1920x1080 design surface. This build's surface is
## 1280x720 (SPEC §3 blesses the equivalent conversion), so
## the factor here is clamp(min(vw/1280, vh/720), 1, 2), times
## the player's hudScale. Registered nodes are the HUD root's
## and the modal layer's POINT-anchored children; each scales
## about its own anchor corner/center via pivot (the anchor
## point's screen position is pivot-invariant, so layout
## never shifts — elements grow into the screen).
func _kr() -> float:
	var vp := get_viewport().get_visible_rect().size
	var fit := clampf(minf(vp.x / 1280.0, vp.y / 720.0), 1.0, 2.0)
	return clampf(fit * _phone_factor(), 1.0, 2.0)

## Audit §9 (the scaler's top fix): the bundle's kR formula
## multiplies CSS px — and a phone's CSS viewport is only
## ~393 px tall, so its design px are ~2x physically larger
## than this build's logical px (720-tall surface under
## `expand`): porting the formula literally evaluates to
## 1.0 on every landscape phone and ships text at ~1 mm.
## The factor below converts surfaces the way the bundle's
## physics works: css_h = physical height / density ratio
## (dpi/160), and the UI grows by (720 / css_h) x 1.1 (the
## 1.1 is kR's floor on that surface), capped at 2. On
## non-touch desktops it is exactly 1 — the dev surface and
## the harness are untouched.
func _phone_factor() -> float:
	if debug_phone_factor >= 0.0:
		return debug_phone_factor
	if OS.get_name() != "Android" and not DisplayServer.is_touchscreen_available():
		return 1.0
	var dpi := DisplayServer.screen_get_dpi()
	var phys := DisplayServer.screen_get_size()
	if dpi <= 0 or phys.y <= 0:
		return 1.0
	var css_h := float(phys.y) / (float(dpi) / 160.0)
	if css_h <= 0.0:
		return 1.0
	return clampf((720.0 / css_h) * 1.1, 1.0, 2.0)

func _register_ui_scale() -> void:
	_ui_scale_nodes.clear()
	_collect_scale(_hud_root)
	for c in _ui_root.get_children():
		var ctl := c as Control
		if ctl != null and ctl != _hud_root:
			_register_one(ctl)
	# The loadout's centered panel rides inside a full-rect
	# shell; register the panel itself.
	if _loadout_panel:
		for c in _loadout_panel.get_children():
			if c is PanelContainer:
				_register_one(c)

func _register_one(ctl: Control) -> void:
	if ctl.anchor_left == ctl.anchor_right \
			and ctl.anchor_top == ctl.anchor_bottom \
			and not (ctl is ColorRect):
		_ui_scale_nodes.append(ctl)

func _collect_scale(container: Control) -> void:
	# Only the container's DIRECT children (a scaled parent
	# carries its subtree with it).
	for c in container.get_children():
		var ctl := c as Control
		if ctl != null:
			_register_one(ctl)

func _apply_ui_scale() -> void:
	var s := _kr() * float(GameProfile.setting("hudScale"))
	var vp := get_viewport().get_visible_rect().size
	for n in _ui_scale_nodes:
		var c := n as Control
		if not is_instance_valid(c):
			continue
		# UI-mobile P5 (plan M0): phone modals size and scale by
		# their design height, not the 4:3 fit clamp below.
		if _p5_on and _p5_spec.has(c):
			_p5_place_modal(c, s)
			continue
		var sn := s
		# Fit clamp: at phone factors a centered modal must
		# still fit the screen — shrink-to-fit beats overflow.
		if sn > 1.0 and c.size.x > 0.0 and c.size.y > 0.0:
			sn = minf(sn, minf(vp.x * 0.96 / c.size.x, vp.y * 0.96 / c.size.y))
		c.scale = Vector2(sn, sn)
		if c.size.x > 0.0 and c.size.y > 0.0:
			c.pivot_offset = Vector2(c.size.x * c.anchor_left,
				c.size.y * c.anchor_top)
	if _p5_on:
		_p5_layout_menu(s)
	# Cycle 19 hotfix: scaling alone does not REFLOW — the
	# cluster layout pass runs on top of every scale apply.
	_layout_hud()

# ------------------------------------------------ UI-mobile P5: M0
## Plan §B0.4 / §B0.5 / §B3 M0 floors, in drawn (logical) px:
## modal text 21 (tag chips 17), buttons 76 (44 dp; the primary
## 83 = 48 dp), sliders / drag bands 70.
const P5_TEXT_PX := 21.0
const P5_TAG_PX := 17.0
const P5_BTN_PX := 76.0
const P5_PRIMARY_PX := 83.0
const P5_TAP_PX := 70.0

## Register a modal panel for M0: W_max (design px; the width
## flows to the screen up to it) and its fixed design height.
func _p5_register(panel: Control, w_max: float, h: float) -> void:
	if panel == null:
		return
	_p5_spec[panel] = Vector2(w_max, h)
	if _p5_on:
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel.resized.connect(func() -> void:
			panel.pivot_offset = panel.size * 0.5)

## The design width a phone modal lays out to (M0's W).
func _p5_w(panel: Control, fallback: float) -> float:
	return float(panel.get_meta("p5_w", fallback)) if panel else fallback

## M0: fit against the larger of the nominal and live content heights;
## card rows can make the latter taller than the original design box.
## Keep a small vertical inset in _ui_root space and centre the result.
## U5 fix4: the fix3 place+fit loop is reverted. It diverged in
## practice: the s100 run landed result at scale 0.036 and bigmap
## at 0.266 (both red), and a probe showed the loop bistable --
## repeated placements swung the result panel between 0.143 and
## 1.275 with off-screen rects. Cause: _p5_fit floors scale as
## 1/sm, so a smaller sm grows the content min (wrapped text grows
## ~1/sm^2 once fonts blow up) and the loop post-fit check keeps
## shrinking sm with no fixed point. Single-pass placement (fix2)
## is deterministic; the result panel 14 px spill is fixed by
## trimming its live min instead (see _fill_result row/payout
## plate margins).
## post_layout is retained for call compatibility.
func _p5_place_modal(c: Control, s: float, post_layout: bool = false) -> void:
	var spec: Vector2 = _p5_spec[c]
	var area := _ui_root.size if _ui_root and _ui_root.size.y > 0.0 \
		else get_viewport().get_visible_rect().size
	# U5: scrollable modals fit against their nominal design height
	# only -- their content is unbounded by design (the scroll clips
	# it), so fitting against the live content height collapses the
	# panel whenever the scroll holds a long list (the result panel
	# fell to scale 0.53 on the s100 run for exactly this). Panels
	# opt in via the p5_fixed_h meta (result only, for now).
	var content_h := spec.y if bool(c.get_meta("p5_fixed_h", false)) else maxf(spec.y, c.get_combined_minimum_size().y)
	var sm := minf(s, (area.y - 6.0) / content_h)
	var w := floorf(minf(spec.x, (area.x - 24.0) / sm))
	# U5 re-audit #1: authored frame-relative translation survives every
	# placement pass. Other modals retain the zero translation default.
	var frame_shift: Vector2 = c.get_meta("p5_frame_shift", Vector2.ZERO)
	var frame_offset: Vector2 = frame_shift * area
	c.offset_left = -w * 0.5 + frame_offset.x
	c.offset_right = w * 0.5 + frame_offset.x
	c.offset_top = -spec.y * 0.5 + frame_offset.y
	c.offset_bottom = spec.y * 0.5 + frame_offset.y
	c.scale = Vector2(sm, sm)
	c.pivot_offset = c.size * 0.5
	var relay := absf(float(c.get_meta("p5_w", -1.0)) - w) > 0.5
	c.set_meta("p5_sm", sm)
	c.set_meta("p5_w", w)
	_p5_fit(c, sm)
	if relay:
		_p5_relayout(c)
		# Width-dependent content can grow beyond the nominal height
		# during its first layout (notably the 300 px draft/blessing
		# cards). Refit once against that measured content height.
		if not post_layout:
			_p5_place_modal(c, s, true)

## Width-dependent modal content re-renders when W changes
## (hudScale slider, safe-area change).
func _p5_relayout(c: Control) -> void:
	if not c.is_visible_in_tree():
		return
	if c == _draft_panel and state == "draft":
		_render_draft()
	elif c == _blessing_panel and _blessing_open:
		_render_blessing()
	elif c == _meowth_panel and _shop_open:
		_shop_refresh()
	elif _loadout_panel and c.get_parent() == _loadout_panel:
		_loadout_refresh()

func _p5_floor_font(c: Control, px: int) -> void:
	if not c.has_meta("p5_fs0"):
		c.set_meta("p5_fs0", c.get_theme_font_size("font_size"))
	var want := maxi(int(c.get_meta("p5_fs0")), px)
	if c.get_theme_font_size("font_size") != want:
		c.add_theme_font_size_override("font_size", want)

## The floors at drawn scale sm, over a whole modal subtree
## (hidden pages included): text fonts, tag-chip fonts, Button
## heights (primary = meta p5_primary), switch size, LineEdit
## and slider bands. Idempotent (originals kept in meta), so
## it re-runs whenever content is rebuilt or s_m changes.
func _p5_fit(root: Control, sm: float) -> void:
	if root == null or sm <= 0.0:
		return
	var ft := int(ceil(P5_TEXT_PX / sm - 0.001))
	var fg := int(ceil(P5_TAG_PX / sm - 0.001))
	var hb := ceilf(P5_BTN_PX / sm - 0.001)
	var hp := ceilf(P5_PRIMARY_PX / sm - 0.001)
	var hs := ceilf(P5_TAP_PX / sm - 0.001)
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label:
			var l := n as Label
			var par := l.get_parent()
			var tag := par is PanelContainer and par.get_child_count() == 1 and par != root
			_p5_floor_font(l, fg if tag else ft)
		elif n is Button:
			var b := n as Button
			if b.text != "":
				_p5_floor_font(b, ft)
			# U2: the two resource pills are reference-sized info
			# counters (their button_cream face is 108x25 ref px);
			# the 76 UI touch floor would force them to 49 design
			# tall and overlap the hero, so they skip the floor.
			var _res_pill := b.get_parent() != null and b.get_parent().name == "Resources"
			if b.get_node_or_null("knob") != null:
				UiTheme.size_switch(b, hb / 28.0)
			elif not _res_pill:
				if not b.has_meta("p5_h0"):
					b.set_meta("p5_h0", b.custom_minimum_size.y)
				var want := maxf(float(b.get_meta("p5_h0")), hp if b.has_meta("p5_primary") else hb)
				if absf(b.custom_minimum_size.y - want) > 0.01:
					b.custom_minimum_size.y = want
			if b.has_meta("label"):
				var il := b.get_meta("label") as Label
				_p5_floor_font(il, ft)
				var fs := il.get_theme_font_size("font_size")
				if int(b.get_meta("fs_over", -1)) != fs:
					b.set_meta("fs_over", fs)
					UiTheme.set_icon_button_text(b, il.text)
		elif n is LineEdit:
			_p5_floor_font(n as Control, ft)
			(n as Control).custom_minimum_size.y = maxf((n as Control).custom_minimum_size.y, hb)
		elif n is HSlider:
			(n as Control).custom_minimum_size.y = maxf((n as Control).custom_minimum_size.y, hs)
		for ch in (n as Node).get_children():
			stack.append(ch)

func _p5_node_added(n: Node) -> void:
	if n is Control:
		_p5_dirty = true

## Per frame (phone): refit the open modals when content was
## rebuilt, or when a modal just opened.
func _p5_tick() -> void:
	var sig := 0
	var i := 0
	for p in _p5_spec.keys():
		if is_instance_valid(p) and (p as Control).is_visible_in_tree():
			sig |= 1 << i
		i += 1
	if not _p5_dirty and sig == _p5_vis_sig:
		return
	_p5_dirty = false
	_p5_vis_sig = sig
	if _menu_design:
		var shake_switch := _menu_design.get_node_or_null("MenuShake/ShakeSwitch") as Button
		if shake_switch:
			UiTheme.set_switch(shake_switch, bool(GameProfile.setting("shakeOn")))
	for p in _p5_spec.keys():
		if is_instance_valid(p) and (p as Control).is_visible_in_tree():
			_p5_fit(p, float((p as Control).get_meta("p5_sm", (p as Control).scale.x)))
	if _menu_design and _menu_design.is_visible_in_tree():
		_p5_fit(_menu_design, _menu_design.scale.x)

## Plan §B3 G1-G6: the phone menu's design surface (450 tall,
## width flowing to the safe area) at s_menu = min(s, (vh - 8) /
## 450), centred; the hero card shows where >= 240 design px are
## left beside the item column (16:9 drops it — the same species
## facts are one tap away on the loadout page).
func _p5_layout_menu(s: float) -> void:
	if _menu_design == null or _ui_root == null:
		return
	var area := _ui_root.size
	if area.y <= 0.0:
		return
	var sm := minf(s, (area.y - 8.0) / 450.0)
	var w := floorf((area.x - 16.0) / sm)
	_menu_design.size = Vector2(w, 450)
	_menu_design.scale = Vector2(sm, sm)
	_menu_design.position = ((area - Vector2(w, 450) * sm) * 0.5).floor()
	if _menu_hero and not _p5_on:
		var hw := w - 8.0 - 686.0
		_menu_hero.visible = hw >= 240.0
		_menu_hero.position = Vector2(686, 80)
		_menu_hero.size = Vector2(hw, 250)
	if _menu_hint:
		var hb := _menu_hint.get_meta("back") as Control
		if hb:
			hb.size = Vector2(w - 16.0, 48)
		_menu_hint.size = Vector2(245.0 if _p5_on else w - 36.0, 42)
	var start := _menu_design.get_node_or_null("StartButton") as Control
	if start and not _p5_on:
		start.position = Vector2(maxf(328, w - 248), 348)
		var selection := _menu_design.get_node_or_null("StarterSelection") as Control
		if selection:
			selection.size.x = minf(420.0, start.position.x - selection.position.x - 8.0)
			(selection.get_node("StarterPanel") as Control).size.x = selection.size.x
			(selection.get_node("StarterNext") as Control).position.x = selection.size.x - 44.0
	var resources := _menu_design.get_node_or_null("Resources") as Control
	if resources:
		for pill in resources.get_children():
			var resource_text := pill.get_node_or_null("ResourceText") as Label
			if resource_text:
				var font := resource_text.get_theme_font("font")
				var font_size := resource_text.get_theme_font_size("font_size")
				var text_width := ceilf(font.get_string_size(resource_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
				resource_text.size.x = text_width
				(pill as Control).custom_minimum_size.x = maxf(float(pill.get_meta("p5_pill_min_w", 142.0)), 52.0 + text_width)
				(pill as Control).size.y = 34.0
		resources.position = Vector2(maxf(328.0, w - resources.get_combined_minimum_size().x - 12.0), 12.0)
	_p5_fit(_menu_design, sm)
	if _menu_hint and not _p5_on:
		var hb2 := _menu_hint.get_meta("back") as Control
		var lh := _menu_hint.get_minimum_size().y
		var top := 450.0 - lh - 6.0
		_menu_hint.position.y = top + 3.0
		_menu_hint.size.y = minf(lh, 450.0 - top - 3.0)
		if hb2:
			hb2.position.y = top
			hb2.size.y = 450.0 - top
	if _p5_on:
		_p5_menu_reference_layout(w)

## U2 1:1 全安全区布局：左右两翼贴靠安全边界舒展（告别 20:9/22:9 宽屏两侧留白），
## 中央舞台（萌宠 + 唯一实踩石台 + 接地接触阴影 + 初始伙伴大托盘）严格共缩放居中锁定，
## 确保萌宠双脚在任意纵横比手机上实踩青苔石台绝不悬空或重影。
func _p5_menu_reference_layout(width: float) -> void:
	var btn_min_h := ceilf(P5_BTN_PX / _menu_design.scale.x)
	var row_h := maxf(49.0, btn_min_h)
	var col_w := clampf(width * 0.258, 224.0, 256.0)
	var card_gap := 8.0
	var card_w := (col_w - card_gap) * 0.5
	var card_h := card_w * (185.0 / 224.0)
	var lx := 12.0
	var y_wallet := 75.0
	var y_r1 := y_wallet + row_h + 7.0
	var y_r2 := y_r1 + card_h + 7.0
	var y_shake := y_r2 + card_h + 7.0
	var y_hint := y_shake + row_h + 7.0

	var start_w := clampf(width * 0.235, 196.0, 240.0)
	var start_h := maxf(88.0, btn_min_h)
	var start_x := width - 12.0 - start_w
	var start_y := 352.0
	var mid_l := lx + col_w + 14.0
	var mid_r := start_x - 14.0
	var stage_cx := (mid_l + mid_r) * 0.5

	var tray_w := minf(426.0, maxf(mid_r - mid_l, 260.0))
	var tray_h := 166.0
	var tray_x := stage_cx - tray_w * 0.5
	var tray_y := 274.0

	var resources := _menu_design.get_node_or_null("Resources") as Control
	var res_x := resources.position.x if resources != null else width
	var hero_w := 200.0
	var hero_top := 25.0 if (stage_cx + hero_w * 0.52) < res_x - 6.0 else 48.0
	var hero_bot := 259.5
	var hero_h := hero_bot - hero_top
	hero_w = hero_h * (947.0 / 1109.0)

	var rects := {
		"MenuLogo": Rect2(lx + 2.0, 4.0, col_w * 1.04, 66.0),
		"MenuWallet": Rect2(lx, y_wallet, col_w, row_h),
		"MenuLab": Rect2(lx, y_r1, card_w, card_h),
		"MenuShop": Rect2(lx + card_w + card_gap, y_r1, card_w, card_h),
		"MenuChallenge": Rect2(lx, y_r2, card_w, card_h),
		"MenuSettings": Rect2(lx + card_w + card_gap, y_r2, card_w, card_h),
		"MenuShake": Rect2(lx, y_shake, col_w, row_h),
		"MenuPartnerHero": Rect2(stage_cx - hero_w * 0.5, hero_top, hero_w, hero_h),
		"StarterSelection": Rect2(tray_x, tray_y, tray_w, tray_h),
		"StartButton": Rect2(start_x, start_y, start_w, start_h),
		"StartCaptionBack": Rect2(start_x, start_y - 40.0, start_w, 32.0),
		"StartCaption": Rect2(start_x + 8.0, start_y - 35.0, start_w - 16.0, 22.0),
	}
	for key in rects:
		var node := _menu_design.get_node_or_null(key) as Control
		if node == null:
			continue
		var rect: Rect2 = rects[key]
		node.position = rect.position
		var extent := rect.size
		if node is Button:
			var start_f: Font = node.get_meta("u2_start_font") if key == "StartButton" and node.has_meta("u2_start_font") else UiTheme.body_font()
			node.add_theme_font_override("font", start_f)
			for child in node.get_children():
				if child is Label:
					child.add_theme_font_override("font", UiTheme.body_font())
			extent.y = maxf(extent.y, btn_min_h)
			node.custom_minimum_size = extent
			node.set_meta("p5_h0", extent.y)
		node.size = extent
		var art := node.get_node_or_null("MenuEntryArt") as Control
		var logo_art := node.get_node_or_null("LogoArt") as Control
		if logo_art:
			logo_art.scale = Vector2.ONE * (extent.x / 286.0)
		if node is Label:
			node.add_theme_font_override("font", UiTheme.display_font() if key == "StartCaption" else UiTheme.body_font())
		if art:
			var title := node.get_child(1) as Label
			var title_height := title.get_combined_minimum_size().y
			title.position = Vector2(6, extent.y - title_height - 7)
			title.size = Vector2(extent.x - 12, title_height)
			title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			art.size = Vector2(extent.x * 0.68, title.position.y - 10)
			art.position = Vector2((extent.x - art.size.x) * 0.5, 6)
	var start := _menu_design.get_node("StartButton") as Control
	start.add_theme_font_size_override("font_size", 44)
	for leaf_side in [false, true]:
		var leaf := start.get_node("StartLeafRight" if leaf_side else "StartLeafLeft") as Control
		leaf.size = Vector2(24, 18)
		var lx_leaf := (start.size.x - 46.0) if leaf_side else 22.0
		leaf.position = Vector2(lx_leaf, (start.size.y - leaf.size.y) * 0.5 + 1.0)
	var caption := _menu_design.get_node("StartCaption") as Label
	var caption_back := _menu_design.get_node("StartCaptionBack") as Control
	caption_back.size.y = maxf(32.0, caption.get_combined_minimum_size().y + 12.0)
	caption.position = caption_back.position + Vector2(8, 5)
	caption.size = caption_back.size - Vector2(16, 10)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 唯一高清石台与萌宠脚底投影随 _menu_design 完全同比例同坐标系定位：
	# 萌宠实底 y=258 踩入石台青苔顶面 y=255（深嵌入 3 设计 px），跨屏 0 悬空
	var stone := _menu_panel.get_node_or_null("MenuHeroStone") as Control
	if stone != null:
		var stone_sz := Vector2(344.0, 116.0)
		var stone_pos := Vector2(stage_cx - stone_sz.x * 0.5, 255.0 - stone_sz.y * 0.34)
		stone.position = _menu_design.position + stone_pos * _menu_design.scale
		stone.size = stone_sz * _menu_design.scale
	var hero_shadow := _menu_panel.get_node_or_null("MenuHeroShadow") as Control
	if hero_shadow != null:
		var sh_sz := Vector2(138.0, 26.0)
		var sh_pos := Vector2(stage_cx - sh_sz.x * 0.5, 255.0 - sh_sz.y * 0.45)
		hero_shadow.position = _menu_design.position + sh_pos * _menu_design.scale
		hero_shadow.size = sh_sz * _menu_design.scale

	var selection := _menu_design.get_node("StarterSelection") as Control
	for child in selection.get_children():
		if child is Label:
			child.add_theme_font_override("font", UiTheme.body_font())
	var heading := selection.get_node("StarterHeading") as Label
	heading.add_theme_font_size_override("font_size", 19)
	heading.size = heading.get_combined_minimum_size()
	heading.position = Vector2((selection.size.x - heading.size.x) * 0.5, 8)
	for leaf_side in [false, true]:
		var leaf := selection.get_node("StarterLeafRight" if leaf_side else "StarterLeafLeft") as Control
		leaf.size = Vector2(18, 16)
		leaf.position = Vector2(heading.position.x + heading.size.x + 8 if leaf_side else heading.position.x - 26,
			heading.position.y + (heading.size.y - leaf.size.y) * 0.5)
	(selection.get_node("StarterPanel") as Control).size = selection.size
	(selection.get_node("StarterNext") as Control).position = Vector2(selection.size.x - 42.0, (selection.size.y - 38.0) * 0.5 + 10.0)
	_menu_starters.position = Vector2(selection.size.x * 0.048, 38.0)
	_menu_starters.size = Vector2(ceilf(selection.size.x * 0.825) + 2.0, selection.size.y - 52.0)
	(_menu_starters.get_child(0) as HBoxContainer).add_theme_constant_override("separation", int(round(selection.size.x * 0.022)))
	var card_sz := Vector2(selection.size.x * 0.258, selection.size.y - 54.0)
	for card in _menu_starters.get_child(0).get_children():
		if card is Button and card.has_meta("starter_species"):
			card.custom_minimum_size = card_sz
			card.size = card_sz
			card.set_meta("p5_h0", card_sz.y)
			var portrait := card.get_child(0) as Control
			portrait.position = Vector2(8, 6)
			portrait.size = card_sz - Vector2(16, 12)
			(card.get_node("SelectedMark") as Control).position = Vector2(card_sz.x - 26.0, 4.0)

	var wallet_button := _menu_design.get_node("MenuWallet") as Control
	var wallet_face := wallet_button.get_node("MenuWalletFace") as Control
	wallet_face.size = wallet_button.size
	var wallet_height := wallet_face.size.y
	var chip := wallet_button.get_node("WalletChip") as Control
	chip.size = Vector2(72, 24)
	chip.position = Vector2(wallet_button.size.x - chip.size.x - 10.0, (wallet_height - chip.size.y) * 0.5)
	var wallet_art := wallet_button.get_node("MenuWalletArt") as Control
	wallet_art.size = Vector2(28, 28)
	wallet_art.position = Vector2(12, (wallet_height - wallet_art.size.y) * 0.5)
	var wallet_title := wallet_button.get_child(1) as Label
	wallet_title.size = Vector2(chip.position.x - 56.0, wallet_title.get_combined_minimum_size().y)
	wallet_title.position = Vector2(48, (wallet_height - wallet_title.size.y) * 0.5)
	wallet_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var shake_row := _menu_design.get_node("MenuShake") as Control
	var shake_switch := shake_row.get_node("ShakeSwitch") as Control
	shake_switch.custom_minimum_size = Vector2.ONE * row_h
	shake_switch.size = shake_switch.custom_minimum_size
	shake_row.size.y = row_h
	shake_row.add_theme_stylebox_override("panel", _style(Color("fff3dd"), 12, Color("e4bd77"), 2))
	shake_switch.position = Vector2(shake_row.size.x - shake_switch.size.x - 10.0, (shake_row.size.y - shake_switch.size.y) * 0.5)
	UiTheme.set_switch(shake_switch, bool(GameProfile.setting("shakeOn")))
	var shake_icon := shake_row.get_node("MenuShakeIcon") as Control
	shake_icon.size = Vector2(30, 30)
	shake_icon.position = Vector2(12, (shake_row.size.y - shake_icon.size.y) * 0.5)
	var shake_text := shake_row.get_node("MenuShakeText") as Label
	shake_text.size = Vector2(shake_switch.position.x - 56.0, shake_text.get_combined_minimum_size().y)
	shake_text.position = Vector2(48, (shake_row.size.y - shake_text.size.y) * 0.5)
	shake_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _menu_hint:
		var backing := _menu_hint.get_meta("back") as Control
		var hint_need_w := _menu_hint.get_combined_minimum_size().x + 50.0
		var hint_w := clampf(maxf(col_w, hint_need_w), col_w, tray_x - lx - 10.0)
		var hint_h := clampf(446.0 - y_hint, 30.0, 36.0)
		backing.position = Vector2(lx, y_hint)
		backing.size = Vector2(hint_w, hint_h)
		var pad := backing.get_node_or_null("MenuHintPad") as Control
		if pad:
			pad.size = Vector2(22, 22)
			pad.position = Vector2(10, (hint_h - 22.0) * 0.5)
		_menu_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		_menu_hint.position = backing.position + Vector2(36, (hint_h - _menu_hint.get_combined_minimum_size().y) * 0.5)
		_menu_hint.size = Vector2(hint_w - 44.0, _menu_hint.get_combined_minimum_size().y)

func _safe_insets() -> Vector4:
	# Cycle 21.3 (audit F6): the gate's simulated insets win.
	if debug_safe_insets.x >= 0.0:
		return debug_safe_insets
	# Audit §9.2: get_display_safe_area() returns PHYSICAL
	# screen px while the UI lives in logical canvas units —
	# convert per axis (physical x logical/screen), or the
	# right/bottom insets clamp to 0 and notches there are
	# never avoided.
	var sa := DisplayServer.get_display_safe_area()
	var vp := get_viewport().get_visible_rect().size
	var scr := DisplayServer.screen_get_size()
	if sa.size.x <= 0 or sa.size.y <= 0 or scr.x <= 0 or scr.y <= 0:
		return Vector4.ZERO
	var kx := vp.x / float(scr.x)
	var ky := vp.y / float(scr.y)
	return Vector4(maxf(float(sa.position.x) * kx, 0.0),
		maxf(float(sa.position.y) * ky, 0.0),
		maxf((float(scr.x) - float(sa.position.x + sa.size.x)) * kx, 0.0),
		maxf((float(scr.y) - float(sa.position.y + sa.size.y)) * ky, 0.0))

func _apply_safe_area() -> void:
	var ins := _safe_insets()
	if _ui_root:
		_ui_root.offset_left = ins.x
		_ui_root.offset_top = ins.y
		_ui_root.offset_right = -ins.z
		_ui_root.offset_bottom = -ins.w
	# Cycle 21.3 (audit §3): the modal scrim must cover
	# the WHOLE screen, not just the inset UI area — it
	# is a _ui_root child, so its offsets reach back out
	# over the insets. It stays below the modal panels
	# (earlier sibling), only its coverage grows.
	if _modal_scrim:
		_modal_scrim.offset_left = -ins.x
		_modal_scrim.offset_top = -ins.y
		_modal_scrim.offset_right = ins.z
		_modal_scrim.offset_bottom = ins.w
	if touch_controls:
		touch_controls.offset_left = ins.x
		touch_controls.offset_top = ins.y
		touch_controls.offset_right = -ins.z
		touch_controls.offset_bottom = -ins.w

func _on_viewport_resized() -> void:
	_apply_safe_area()
	_apply_ui_scale()
	_layout_top_card()

## Audit §3.2: the 640-wide top cluster's left edge (vw/2 -
## 320) covers the player info plate's right edge (x 338)
## below vw 1316 — including the 16:9 baseline. Shift the
## cluster right until its left edge clears plate + 12 px
## (contents are card-local, so nothing inside moves).
## Cycle 19 hotfix: this grew into _layout_hud (below) —
## the audit's rule was unscaled; at phone factors the
## SCALED card is up to 1280 wide and eats both neighbours.
func _layout_top_card() -> void:
	_layout_hud()

func _set_scaled(c: Control, sc: float) -> void:
	if c == null:
		return
	c.scale = Vector2(sc, sc)
	if c.size.x > 0.0 and c.size.y > 0.0:
		c.pivot_offset = Vector2(c.size.x * c.anchor_left,
			c.size.y * c.anchor_top)

func _kills_pill_node() -> Control:
	if _hud_root == null:
		return null
	return _hud_root.get_node_or_null("KillsPill") as Control

## Cycle 19 hotfix (user's Seeker capture, C18 build): the
## top card buried the hero plate's name, the goal card
## hung off the right edge under the minimap, and the ult
## name printed across the move card. Root cause: the
## scaler grows every registered node about its own anchor
## while sibling POSITIONS stay in design px, and the old
## shift rule used the UNSCALED 640 width. This pass —
## run after every _apply_ui_scale and on goal refresh —
## treats the top row as one design row [hero 466 | 12 |
## top card 640 | 12 | minimap 176] = 1282 wide (Cycle
## 21.3 / audit F7: the card is 726 wide now, row 1368)
## and:
##  * caps the whole top region at a fit scale s_top so
##    the row never exceeds the viewport (s_top == s at
##    the 1280 baseline — desktop geometry is untouched);
##  * positions the top card in the free span, clearing
##    the hero plate's info panel (the audit's 350 rule,
##    scaled) and the minimap;
##  * re-stacks the right column (kills -> goal -> pills)
##    by SCALED heights (constants reproduce the shipped
##    190 / 226 / 320 tops exactly at s_top == 1);
##  * at phone factors only (s > 1.01), shifts the boss
##    card and mini bars into the same free span and fits
##    their scale to it — desktop keeps them centered.
func _layout_hud() -> void:
	if _top_card == null or _hud_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# Cycle 21.3 (audit F6): layout maths runs in the
	# INSET layer's space — the HUD nodes live in
	# _ui_root, so its size (not the raw viewport's) is
	# the width every centre/span computation must use.
	# The viewport fallback covers pre-layout frames
	# where _ui_root has no size yet.
	var vw := _ui_root.size.x
	if vw <= 1.0:
		vw = vp.x
	var vh := _ui_root.size.y
	if vh <= 1.0:
		vh = vp.y
	var s := _kr() * float(GameProfile.setting("hudScale"))
	var s_top := s
	# UI-mobile P3 (plan D6): the new phone layout unless the
	# player picked the classic one (= the 21.3.2 geometry:
	# every phone-branch change from P2 on stays off).
	var phone := _new_layout()
	_apply_top_card_phone(phone)
	_p3_apply_mode(phone)
	_p4_apply_mode(phone)
	# Cycle 21.3 (F7): the design row is now [hero 466 |
	# 12 | top card 726 | 12 | minimap 176] = 1368 +
	# margins. The fit engages on wide viewports (the
	# C19 rule) OR at phone factors — a 1920x1080 phone
	# window is exactly 1280 logical wide, where the
	# unclamped factor 1.925 cannot fit the row at all.
	# Desktop at 1280 (factor 1) keeps s_top == s, so
	# the shipped desktop pins survive.
	var mm_w := 176.0 * float(GameProfile.setting("minimapScale"))
	# UI-mobile P2 (plan §B2): on phone the top band is
	# [hero 340 | card 560] with the right column on its
	# own scale s_mm = min(s, 1.30); s_t (s_top here) =
	# min(s, 1.45, fit). The card and the right column
	# (minimap -> kills -> goal -> pills, zone Z3) ride
	# s_card / s_col; on desktop all three equal s_top.
	var s_col := s_top
	if phone:
		s_col = minf(s, 1.30)
		# UI-mobile P3 (plan risk P7): minimapScale 1.50 at
		# touchScale 1.50 grows the minimap past the ult gauge
		# (kills under it). The column (minimap + 4 + kills 28)
		# must end above the cluster piece under it - 8; the
		# x-range is the uncapped column (conservative). Never
		# binds at the default minimap scale.
		var zc := _p3_z_over(vw - 12.0 - mm_w * s_col, vw - 12.0)
		if zc < INF:
			s_col = minf(s_col, maxf((zc - 14.0) / (mm_w + 28.0), 0.5))
		s_top = minf(minf(s, 1.45), (vw - 48.0 - mm_w * s_col) / (340.0 + 560.0))
	elif vw > 1280.0 or _phone_factor() > 1.01:
		# The 21.3.2 fit (classic layout on phone, wide desktop).
		s_top = minf(s, (vw - 24.0) / 1368.0)
		s_col = s_top
	var hero_r := 12.0 + (340.0 if phone else 466.0) * s_top
	var mm_l := vw - 12.0 - mm_w * s_col
	_set_scaled(_hero_cluster, s_top)
	_set_scaled(_minimap, s_col)
	_set_scaled(_hud_root.get_node_or_null("MinimapFrame") as Control, s_col)
	var kills := _kills_pill_node()
	_set_scaled(kills, s_col)
	_set_scaled(_goal_card, s_col)
	_set_scaled(_pill_box, s_col)
	# Cycle 21.3 (audit F1a): clear a lane for the touch
	# cluster — push the right column's left edge (the
	# minimap frame's visual left) to the touch layer,
	# which parks pause / aim immediately left of
	# it. Converted through global origins; the two
	# layers share the same inset offsets in practice.
	if touch_controls != null:
		var ui_ox := _ui_root.get_global_rect().position.x
		var tc_ox: float = touch_controls.get_global_rect().position.x
		touch_controls.set_right_column_left(mm_l + ui_ox - tc_ox)
	# Top card in the free span (band rule: in the card's
	# y-band the widest hero piece is the info panel, whose
	# right edge is cluster-local 326).
	# 手机模式下英雄信息面板隐藏，左避让界对齐修长英雄背板右缘 242，维持顶栏居中呼吸缝
	var band_r := 12.0 + (242.0 if phone else 326.0) * s_top + 12.0
	var s_card := s_top
	if phone:
		var right_b := mm_l - 12.0
		if touch_controls != null:
			var tc_o: Vector2 = touch_controls.get_global_rect().position \
				- _ui_root.get_global_rect().position
			var ct: float = touch_controls.column_top()
			var cl: float = touch_controls.column_left()
			if ct < INF and cl < INF and ct + tc_o.y < 10.0 + 68.0 * s_top + 12.0:
				right_b = minf(right_b, cl + tc_o.x - 12.0)
		s_card = minf(s_top, maxf(right_b - band_r, 1.0) / 560.0)
		# 对标 U1_final.jpg：顶栏严格对齐屏幕水平正中心 vw * 0.5（仅当安全边距不足时微幅让步），同时显式同步 size 与 pivot 防止缩放漂移
		var pc := clampf(vw * 0.5, band_r + 280.0 * s_card, right_b - 280.0 * s_card)
		_top_card.offset_left = pc - vw * 0.5 - 280.0
		_top_card.offset_right = pc - vw * 0.5 + 280.0
		_top_card.size = Vector2(560.0, 68.0)
		_top_card.pivot_offset = Vector2(280.0, 0.0)
		_set_scaled(_top_card, s_card)
		_p2_fit_fonts(s_card, s_top)
		_p2_place_wx_hit()
	else:
		_set_scaled(_top_card, s_top)
		var card_l := maxf(vw * 0.5 - 363.0 * s_top, band_r)
		card_l = minf(card_l, mm_l - 12.0 - 726.0 * s_top)
		var card_c := card_l + 363.0 * s_top
		_top_card.offset_left = card_c - vw * 0.5 - 363.0
		_top_card.offset_right = card_c - vw * 0.5 + 363.0
	_p2_hero_box()
	if phone:
		_p3_place_hit(_portrait_hit, _medal_panel)
	# Right column re-stack by scaled heights.
	var mm_bot := 10.0 + mm_w * s_col
	if kills:
		kills.offset_top = mm_bot + 4.0
		kills.offset_bottom = mm_bot + 4.0 + 28.0
	if _goal_card:
		_goal_card.offset_top = mm_bot + 4.0 + 28.0 * s_col + 8.0
		var gh := _goal_card.get_combined_minimum_size().y
		if gh < 40.0:
			gh = maxf(_goal_card.size.y, 86.0)
		_goal_card.offset_bottom = _goal_card.offset_top + gh
		if _pill_box:
			# Cycle 21.3 (audit F2/O10): gh is UNSCALED
			# but the card DRAWS at gh x s_col (top
			# pivot) — the pill box must start from
			# the drawn bottom. offset_bottom above
			# stays the design height on purpose:
			# scaling it too would apply s_col twice
			# (the gate measures the drawn rect).
			_pill_box.offset_top = _goal_card.offset_top + gh * s_col + 8.0
	if phone:
		_p3_place_objective(mm_bot, mm_l, s_col, vw, vh)
	# Centre stack: PHONE factors only. A desktop
	# hudScale > 1 is the player's explicit choice and the
	# standing contract is that it drives these nodes'
	# scale directly (harness ui2) — the span fit/shift is
	# the remedy for the phone factor's involuntary growth.
	if _phone_factor() > 1.01:
		# Audit F3/F4 span: left edge clears the hero
		# cluster AND the stat-chip row's measured right
		# (the chips overflow the cluster's design box);
		# right edge clears the minimap and the F1 touch
		# lane.
		var pw_r := hero_r
		if _pw_row and _pw_row.visible:
			pw_r = 12.0 + (94.0 + _pw_row.get_combined_minimum_size().x) * s_top
		var span_l := maxf(hero_r, pw_r) + 12.0
		var lane_l := mm_l
		# UI-mobile P3 fix round 2 (P7 corners minimapScale
		# 0.75): the kills pill (134) and the objective pill
		# (176) ride s_col like the minimap but are WIDER than
		# a 0.75 minimap (132), so they jut left of mm_l and
		# the toast ran over the pill. The span clears the
		# whole column; at minimapScale >= 1 the minimap is
		# the widest piece and nothing moves.
		if phone:
			var ux := _ui_root.get_global_rect().position.x
			for cp in [kills, _obj_pill]:
				if cp != null and (cp as Control).visible:
					lane_l = minf(lane_l, _p3_draw_rect(cp as Control).position.x - ux)
		if touch_controls != null:
			var cl: float = touch_controls.column_left()
			if cl < INF:
				lane_l = minf(lane_l, cl
					+ touch_controls.get_global_rect().position.x
					- _ui_root.get_global_rect().position.x)
		var span_r := lane_l - 12.0
		var span_w := maxf(span_r - span_l, 1.0)
		var span_c := (span_l + span_r) * 0.5
		# 保持顶栏、Boss条、必杀切入、头领条、大横幅全居中同一屏中轴线对齐
		var align_c := clampf(vw * 0.5, band_r + 280.0 * s_card, span_r - 280.0 * s_card) if phone else span_c
		var sym_w_vis := maxf(2.0 * minf(align_c - band_r, span_r - align_c), 1.0)
		var sym_w_safe := maxf(2.0 * minf(align_c - span_l, span_r - align_c), 1.0)
		_dbg_span = Vector2(span_l, span_r)
		if phone:
			_p4_layout_bl(s, vw, vh)
		var stack_y := 10.0 + (68.0 if phone else 84.0) * s_card + 8.0
		var boss_y := stack_y
		var bs_top := minf(s, (sym_w_vis if phone else span_w) / 642.0)
		if _boss_card and _boss_card.visible:
			stack_y += 46.0 * bs_top + 8.0
		if phone and _cutin_panel:
			var cs := minf(s_top, sym_w_vis / 460.0)
			_cutin_panel.offset_left = align_c - vw * 0.5 - 230.0
			_cutin_panel.offset_right = align_c - vw * 0.5 + 230.0
			_cutin_panel.size = Vector2(460.0, 64.0)
			_cutin_panel.pivot_offset = Vector2(230.0, 0.0)
			_set_scaled(_cutin_panel, cs)
			if _cutin_panel.visible:
				_cutin_panel.offset_top = stack_y
				_cutin_panel.offset_bottom = stack_y + 64.0
				stack_y += 64.0 * cs + 8.0
		if _boss_card:
			var bc_c := align_c if phone else span_c
			_boss_card.offset_left = bc_c - vw * 0.5 - 321.0
			_boss_card.offset_right = bc_c - vw * 0.5 + 321.0
			_boss_card.size = Vector2(642.0, 46.0)
			_boss_card.pivot_offset = Vector2(321.0, 0.0)
			_set_scaled(_boss_card, bs_top)
			if _boss_card.visible:
				_boss_card.offset_top = boss_y
				_boss_card.offset_bottom = boss_y + 46.0
		var bar_s := minf(s_top, (sym_w_safe if phone else span_w) / 300.0)
		_layout_prompt(span_l, span_r, vw, vh, s)
		var bars_top := stack_y
		var bars_n := 0
		var vis_bars := 0
		for bar in _mini_bars:
			if (bar["panel"] as Control).visible:
				vis_bars += 1
		if phone and vis_bars == 2:
			# 若双头领条已经落在头像圆底缘之下则以居中对称宽展开，否则安全退回 span_l 避让 hero_deep
			var bar_clear := bars_top >= 12.0 + 108.0 * s_top + 2.0
			var b_area_w := sym_w_vis if bar_clear else span_w
			var b_area_l := (align_c - sym_w_vis * 0.5) if bar_clear else span_l
			var bar_s2 := minf(s_top, (b_area_w * 0.5 - 8.0) / 300.0)
			var k := 0
			for bar in _mini_bars:
				var mp2 := bar["panel"] as Control
				var cx := b_area_l + b_area_w * (0.25 if k == 0 else 0.75)
				mp2.offset_left = cx - vw * 0.5 - 150.0
				mp2.offset_right = cx - vw * 0.5 + 150.0
				mp2.offset_top = bars_top
				mp2.offset_bottom = bars_top + 40.0
				mp2.size = Vector2(300.0, 40.0)
				mp2.pivot_offset = Vector2(150.0, 0.0)
				_set_scaled(mp2, bar_s2)
				k += 1
			stack_y = bars_top + 40.0 * bar_s2 + 8.0
		else:
			for bar in _mini_bars:
				var mp := bar["panel"] as Control
				var bc_m := align_c if (phone and bars_top >= 12.0 + 108.0 * s_top + 2.0) else span_c
				mp.offset_left = bc_m - vw * 0.5 - 150.0
				mp.offset_right = bc_m - vw * 0.5 + 150.0
				mp.size = Vector2(300.0, 40.0)
				mp.pivot_offset = Vector2(150.0, 0.0)
				_set_scaled(mp, bar_s)
				if mp.visible:
					mp.offset_top = bars_top + float(bars_n) * 46.0 * bar_s
					mp.offset_bottom = mp.offset_top + 40.0
					bars_n += 1
			if bars_n > 0:
				stack_y = bars_top + float(bars_n - 1) * 46.0 * bar_s \
					+ 40.0 * bar_s + 8.0
		if _banner_back and _banner:
			var tw := 860.0
			if _banner.text != "":
				tw = maxf(_banner.get_theme_font("font").get_string_size(
					_banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					_banner.get_theme_font_size("font_size")).x, 1.0)
			# 判断当前 y 高度带是否仍在头像区右缘碰撞区内（未过 108*s_top 下方则按 sym_w_safe 对齐中轴线，过线则按全对称）
			var ban_clear := stack_y >= 12.0 + 108.0 * s_top + 2.0
			var b_l := (align_c - sym_w_vis * 0.5) if (phone and ban_clear) else span_l
			var b_r := (align_c + sym_w_vis * 0.5) if (phone and ban_clear) else span_r
			var b_w := maxf(b_r - b_l, 1.0)
			var b_c := align_c if phone else span_c
			var max_sym_w := maxf(2.0 * minf(b_c - b_l, b_r - b_c), 1.0) if phone else span_w
			var bsc := minf(s, max_sym_w / maxf(tw + 48.0, 1.0))
			if phone and stack_y + 56.0 * bsc > 0.55 * vh:
				bsc = minf(bsc, 1.0)
			if phone and _prompt != null and _prompt.text != "":
				var ux := _ui_root.get_global_rect().position.x
				var uy := _ui_root.get_global_rect().position.y
				var pr := _p3_draw_rect(_prompt)
				if _prompt_back != null and _prompt_back.visible:
					pr = pr.merge(_p3_draw_rect(_prompt_back))
				pr.position -= Vector2(ux, uy)
				if pr.end.x > span_l and pr.position.x < span_r \
						and stack_y + 56.0 * bsc > pr.position.y - 4.0:
					bsc = minf(bsc, maxf((pr.position.y - 4.0 - stack_y) / 56.0, 0.5))
			if phone:
				var lane := _p3_lane_above(stack_y + 56.0 * bsc + 8.0)
				if lane < b_r:
					b_r = maxf(lane, b_l + 1.0)
					b_w = b_r - b_l
					b_c = clampf(b_c, b_l + 1.0, b_r - 1.0)
					max_sym_w = maxf(2.0 * minf(b_c - b_l, b_r - b_c), 1.0)
					bsc = minf(bsc, max_sym_w / maxf(tw + 48.0, 1.0))
			# 先设置固定尺寸与准确中心锚点后再应用缩放，消除偏移甩偏！
			_banner.offset_left = b_c - vw * 0.5 - 430.0
			_banner.offset_right = b_c - vw * 0.5 + 430.0
			_banner.offset_top = stack_y + 8.0
			_banner.offset_bottom = stack_y + 48.0
			_banner.size = Vector2(860.0, 40.0)
			_banner.pivot_offset = Vector2(430.0, 0.0)
			_set_scaled(_banner, bsc)
			var back_w := minf(max_sym_w / maxf(bsc, 0.01), tw + 48.0)
			_banner_back.offset_left = b_c - vw * 0.5 - back_w * 0.5
			_banner_back.offset_right = b_c - vw * 0.5 + back_w * 0.5
			_banner_back.offset_top = stack_y
			_banner_back.offset_bottom = stack_y + 56.0
			_banner_back.size = Vector2(back_w, 56.0)
			_banner_back.pivot_offset = Vector2(back_w * 0.5, 0.0)
			_set_scaled(_banner_back, bsc)
	# Cycle 21.3 (audit F1c): the right column's info
	# stack must end above the touch ult gauge — shed
	# pills, then goal detail, then the first pill.
	_apply_stack_budget(s_col, vw, vh)
	# Cycle 20.2 (re-audit HOLD): hand the touch layer the
	# slot row's visual top (cluster-local y 56, the same
	# bound the phonehud gate asserts) so the idle joystick
	# ring clamps against it at ANY touchScale. The row
	# rides the HUD factor; the ring rides touchScale only —
	# at 0.70-0.85 the raw ring bottom crossed the row.
	if touch_controls != null and _bl_cluster != null:
		var blr := _bl_cluster.get_global_rect()
		# UI-mobile P4: the cluster IS the two slot rows —
		# the limit is Z7's drawn top (bottom-left pivot).
		if _p4_on == 1:
			touch_controls.set_ring_bottom_limit(_p3_draw_rect(_bl_cluster).position.y)
		else:
			touch_controls.set_ring_bottom_limit(
				blr.position.y + 56.0 * _bl_cluster.scale.y)

## UI-mobile P2 (plan §B4 P2): the top card's phone content
## version (card design 560 x 84, card-local coords from the
## plan) and the hero cluster's phone pieces (HP track 20
## tall, party row under it). Collapsed items hide: pw row,
## EN zone name, stopwatch, zone chip (T4 = the pips), tier
## chip (T5), stardust — all on the pause status page.
## Desktop restores the build-time rects (captured on the
## first call). Acts only on a flip.
func _apply_top_card_phone(on: bool) -> void:
	if _top_card == null or _hero_cluster == null:
		return
	var want := 1 if on else 0
	if want == _p2_on:
		return
	_p2_on = want
	_p2_font_sig = ""
	# 切换顶栏背板与钱包内托风格：手机切为定稿半透明灰蓝流线大胶囊（高 64、半圆端盖 r=32），并取消内嵌黑钱包底框
	if not _top_card.has_meta("p2_desk_sb"):
		_top_card.set_meta("p2_desk_sb", _top_card.get_theme_stylebox("panel"))
		_top_card.set_meta("p2_desk_bot", _top_card.offset_bottom)
	if _wallet_pill != null and not _wallet_pill.has_meta("p2_desk_sb"):
		_wallet_pill.set_meta("p2_desk_sb", _wallet_pill.get_theme_stylebox("panel"))
	if on:
		_top_card.add_theme_stylebox_override("panel", UiTheme.hud_glass(34, 0.80, Color(0.90, 0.95, 1.0, 0.72), 2, 0))
		_top_card.offset_bottom = _top_card.offset_top + 68.0
		if _wallet_pill != null:
			_wallet_pill.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		_top_card.add_theme_stylebox_override("panel", _top_card.get_meta("p2_desk_sb"))
		_top_card.offset_bottom = float(_top_card.get_meta("p2_desk_bot"))
		if _wallet_pill != null:
			_wallet_pill.add_theme_stylebox_override("panel", _wallet_pill.get_meta("p2_desk_sb"))
	var lay := [
		[_zone_cn, Rect2(18, 8, 120, 26)],
		# 560x68 流线胶囊内部三段式居中排布：拉开时间与「平静」行缝，放大三元图标与数字
		[_zone_chip, Rect2(18, 21, 76, 26)],
		[_zone_chip_label, Rect2(0, 0, 76, 26)],
		[_tier_chip, Rect2(99, 21, 46, 26)],
		[_tier_chip_label, Rect2(0, 0, 46, 26)],
		[_wx_chip, Rect2(150, 21, 48, 26)],
		[_wx_icon, Rect2(5, 6, 14, 14)],
		[_wx_label, Rect2(21, 0, 25, 26)],
		[_timer_label, Rect2(200, -1, 146, 32)],
		[_danger_name, Rect2(200, 31, 146, 17)],
		[_wallet_pill, Rect2(344, 16, 210, 36)],
		[_dust_icon, Rect2(0, 5, 26, 26)],
		[_dust_label, Rect2(28, 0, 38, 36)],
		[_coin_icon, Rect2(68, 5, 26, 26)],
		[_gold_label, Rect2(96, 0, 40, 36)],
		[_ball_icon, Rect2(138, 5, 26, 26)],
		[_ball_price_label, Rect2(166, 0, 46, 36)],
		# 手机模式下 _hero_info 虽然隐藏，但 phonehud.gd 仍校验其矩形与顶栏不相交；同步缩至修长灰蓝背板范围（桌面自动恢复）
		[_hero_info, Rect2(56, 22, 182, 62)],
		# 英雄血条加长至 140、数字区域从 x=22 开始以避开左侧圆形奖章遮挡，使数字视觉严格居中在可见绿条中线
		[_hud_hp_track, Rect2(84, 44, 140, 20)],
		[_hud_hp_lag, Rect2(1, 1, 138, 18)],
		[_hud_hp_fill, Rect2(1, 1, 138, 18)],
		[_hud_hp_num, Rect2(22, 0, 118, 20)],
		[_hud_shield_fill, Rect2(1, 1, 0, 18)],
		[_party_row, Rect2(94, 60, 240, 44)],
	]
	for i in range(_pips.size()):
		lay.append([_pips[i], Rect2(18 + i * 17, 64, 11, 11)])
	for i in range(_danger_segs.size()):
		lay.append([_danger_segs[i], Rect2(215 + i * 17, 50, 13, 14)])
	for e in lay:
		var c := e[0] as Control
		if c == null:
			continue
		if not c.has_meta("p2_desk"):
			c.set_meta("p2_desk", Rect2(c.position, c.size))
		var r: Rect2 = e[1] if on else c.get_meta("p2_desk")
		c.position = r.position
		if c == _hud_hp_fill or c == _hud_hp_lag:
			c.size.y = r.size.y
		else:
			c.size = r.size
	if _top_card != null:
		_top_card.size = Vector2(560.0, 68.0) if on else Vector2(726.0, 84.0)
	# U1 1:1 round 3: zone / tier chips and the stardust
	# item are restored on phone (reference U1_final.jpg) —
	# only the English name, elapsed clock and power row stay
	# collapsed (parity via the pause status page).
	# U1 1:1 round 4: the hero info plate joins them — the
	# reference cluster is medallion + Lv + HP only (the
	# name / chips / evo line live on the pause status page).
	# U1 1:1 round 7: the zone NAME joins them — the
	# reference top bar carries no place name (the zone
	# chip "区域 1/4" already says where you are).
	for c in [_pw_row, _zone_en, _elapsed_label, _hero_info, _zone_cn]:
		if c != null:
			(c as Control).visible = not on
	# U1 1:1 round 13: the four stage pips join the collapsed
	# set on phone — U1_final.jpg carries no pip row (the
	# "区域 1/4" chip already states the stage); round 3 had
	# parked them on a third row under the chips, which read
	# as a stray dot row in every capture. Desktop keeps them.
	for p in _pips:
		(p as Control).visible = not on
	if _mm_expand:
		_mm_expand.visible = on
	if _hud_name and _hud_name_full != "":
		_hud_name.text = _hud_name_full.get_slice(" ", 0) if on else _hud_name_full
	if not on:
		_p2_restore_fonts()
	_refresh_weather_chip()
	_p2_hud_tick()

## UI-mobile P2 (plan B0.5 + D7): the phone top band's drawn
## text floors — 19 logical px on the 20:9 line, 17 on the
## 16:9 line (viewport aspect < 2); must-glance numerals 24
## (HP 20) scaled by the same ratio. Each label keeps the
## plan's phone size and only grows where size x its node
## scale would draw under the floor (the plan's 11-13 px
## chips / Lv badge / danger name do at s_t 1.45, and every
## size does on 16:9 or with the card fitted to the touch
## column). Signature-gated (P11: the layout pass is hot).
func _p2_fit_fonts(s_card: float, s_hero: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var fl := 19.0 if vp.x / maxf(vp.y, 1.0) >= 2.0 else 17.0
	var chips: Array = []
	for c in _hud_chips.get_children():
		if not (c as Node).is_queued_for_deletion():
			for l in c.get_children():
				if l is Label:
					chips.append(l)
	var sig := "%.4f|%.4f|%.0f|%d" % [s_card, s_hero, fl, chips.size()]
	if sig == _p2_font_sig:
		return
	_p2_font_sig = sig
	var f24 := 24.0 * fl / 19.0
	var f20 := 20.0 * fl / 19.0
	var rows := [[_zone_cn, 19, fl, s_card], [_wx_label, 14, fl, s_card],
		[_timer_label, 31, f24, s_card], [_danger_name, 13, fl, s_card],
		[_gold_label, 18, f24, s_card], [_ball_price_label, 18, f24, s_card],
		[_dust_label, 18, f24, s_card],
		[_zone_chip_label, 11, fl, s_card], [_tier_chip_label, 11, fl, s_card],
		[_hud_name, 19, fl, s_hero], [_lv_label, 12, fl, s_hero],
		[_hud_evo, 14, fl, s_hero], [_hud_hp_num, 14, f20, s_hero]]
	for l in chips:
		rows.append([l, 12, fl, s_hero])
	for r in rows:
		var l := r[0] as Label
		if l == null:
			continue
		var px := int(r[1])
		px = maxi(px, int(ceil((float(r[2]) - 0.01) / maxf(float(r[3]), 0.01))))
		if not l.has_meta("p2_desk_fs"):
			l.set_meta("p2_desk_fs", l.get_theme_font_size("font_size"))
		if l.get_theme_font_size("font_size") != px:
			l.add_theme_font_size_override("font_size", px)
		if l in chips:
			var chip := l.get_parent() as Control
			chip.custom_minimum_size.y = maxf(20.0, float(px) + 4.0)

## Desktop: the fitted labels go back to their build sizes.
func _p2_restore_fonts() -> void:
	var rows: Array = [_zone_cn, _wx_label, _timer_label, _danger_name, _gold_label,
		_ball_price_label, _dust_label, _zone_chip_label, _tier_chip_label,
		_hud_name, _lv_label, _hud_evo, _hud_hp_num]
	for c in _hud_chips.get_children():
		var chip := c as Control
		chip.custom_minimum_size.y = 20.0
		for l in chip.get_children():
			if l is Label:
				rows.append(l)
	for l in rows:
		if l != null and (l as Label).has_meta("p2_desk_fs"):
			(l as Label).add_theme_font_size_override("font_size", int(l.get_meta("p2_desk_fs")))

## Hero cluster box (plan Z1): phone 340 x HP bottom (86,
## the medallion's bottom — the 20-tall track rides centred
## beside it since U1 1:1 round 4) or party bottom (104)
## when allies are up; desktop keeps 454 x 216.
func _p2_hero_box() -> void:
	if _hero_cluster == null:
		return
	if _hero_plate != null:
		_hero_plate.visible = _p2_on == 1
	if _p2_on == 1:
		# U1 1:1 round 14: the 108-tall medallion is now the
		# cluster's tallest element in both states (the party
		# row's bottom is 104), so the box height follows it.
		var h := 108.0
		_hero_cluster.size = Vector2(340, h)
	else:
		_hero_cluster.size = Vector2(454, 216)

## Weather chip hit area (plan I2: >= 70 logical px), centred
## on the chip's drawn rect, in the touch layer's space.
func _p2_place_wx_hit() -> void:
	if _wx_hit == null or _wx_chip == null or touch_controls == null:
		return
	_wx_hit.visible = _p2_on == 1
	if _p2_on != 1:
		return
	var t := _wx_chip.get_global_transform()
	var a := t * Vector2.ZERO
	var b := t * _wx_chip.size
	var c := (a + b) * 0.5
	var sz := Vector2(maxf(b.x - a.x, 70.0), maxf(b.y - a.y, 70.0))
	var o: Vector2 = touch_controls.get_global_rect().position
	_wx_hit.position = c - sz * 0.5 - o
	_wx_hit.size = sz

## The 0.15 s HUD tick's phone-contextual pieces: H6 evo line
## (only within 3 levels of evolving) and H8 party row (only
## with allies), plus the hero box height that follows it.
func _p2_hud_tick() -> void:
	if _hud_evo == null or _party_row == null:
		return
	if _p2_on == 1 and player != null and is_instance_valid(player):
		var ev := GameData.evo_level_for(String(player.species_id))
		_hud_evo.visible = ev > 0 and ev - int(player.level) <= 3
		_party_row.visible = get_tree().get_nodes_in_group("allies").size() > 0
	elif _p2_on != 1:
		_hud_evo.visible = true
		_party_row.visible = true
	_p2_hero_box()

func _on_wx_hit_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventMouseButton and event.pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	# UI-mobile P3 (plan I3): press feedback, a+0.25 while held.
	var up: bool = (event is InputEventMouseButton and not event.pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if up:
		_p3_press_fx(_wx_chip, false)
		_wx_hit.accept_event()
		return
	if not down:
		return
	_p3_press_fx(_wx_chip, true)
	_wx_hit.accept_event()
	# Touch + its emulated mouse press arrive as two events.
	var now := Time.get_ticks_msec()
	if now - _wx_tap_ms < 300:
		return
	_wx_tap_ms = now
	show_banner(_weather_explain(), 1.5)

## T6 explanation (tap toast + the status page): the live
## weather's name and its move-type damage modifiers, read
## through weather_damage_mul (one source).
func _weather_explain() -> String:
	var row: Dictionary = WEATHER_TABLE.get(weather, WEATHER_TABLE["clear"])
	var parts: Array = []
	for key in ["boost", "nerf"]:
		var names: Array = []
		var mul := 1.0
		for t in row[key]:
			names.append(String((TYPE_HUD.get(String(t), [String(t)]) as Array)[0]))
			mul = weather_damage_mul(String(t))
		if not names.is_empty():
			parts.append("%s 招式伤害 ×%s" % ["/".join(names), str(snappedf(mul, 0.01))])
	if parts.is_empty():
		parts.append("无属性修正")
	return "天气：%s · %s" % [String(row["cn"]), " · ".join(parts)]

# ------------------------------------------------ UI-mobile P3
## Plan D6: the new phone layout is the default; the classic
## switch (设置→界面) returns the phone HUD to the 21.3.2
## geometry. Desktop (factor 1) is always "classic".
func _new_layout() -> bool:
	return _phone_factor() > 1.01 and not bool(GameProfile.setting("classicLayout"))

## Flip-only mode switch (called from _layout_hud): the touch
## cluster layout, the resident goal card / pill stack vs
## the objective pill, the portrait tap, the cut-in's home.
func _p3_apply_mode(on: bool) -> void:
	var want := 1 if on else 0
	if want == _p3_on:
		return
	_p3_on = want
	if touch_controls:
		touch_controls.set_layout_classic(not on)
	# U1 1:1 round 10: the portrait pause badge stays hidden —
	# the reference has none (see the build site above).
	if _goal_card:
		_goal_card.visible = not on and _goal_species != "" and state != "menu"
	if _pill_box:
		_pill_box.visible = not on
	if not on:
		for c in [_obj_pill, _kills_badge, _obj_hit, _portrait_hit, _wx_hit]:
			if c != null:
				(c as Control).visible = false
		_obj_close_drawer()
		if _kills_label and _kills_label.has_meta("p3_desk_fs"):
			_kills_label.add_theme_font_size_override("font_size", int(_kills_label.get_meta("p3_desk_fs")))
		if _cutin_panel:
			_cutin_panel.offset_left = -230
			_cutin_panel.offset_right = 230
			_cutin_panel.offset_top = 120
			_cutin_panel.offset_bottom = 184
			_set_scaled(_cutin_panel, _kr() * float(GameProfile.setting("hudScale")))
	_pill_sig = ""
	_obj_sig = ""
	call_deferred("_refresh_event_pills")

## Lowest top (in _ui_root space) of the touch-cluster pieces
## under the x-range [x0, x1] (ui space), minus 8; INF when
## there is no cluster / nothing under the range.
func _p3_z_over(x0: float, x1: float) -> float:
	if touch_controls == null:
		return INF
	var d: Vector2 = touch_controls.get_global_rect().position - _ui_root.get_global_rect().position
	var ct: float = touch_controls.cluster_top_over(x0 - d.x, x1 - d.x)
	if ct == INF:
		return INF
	return ct + d.y - 8.0

## Leftmost x (in _ui_root space) of the touch-cluster pieces
## whose top is above y (ui space), minus 12; INF when there
## is no cluster / no piece reaches that high.
func _p3_lane_above(y: float) -> float:
	if touch_controls == null or touch_controls.size.y <= 1.0:
		return INF
	var d: Vector2 = touch_controls.get_global_rect().position - _ui_root.get_global_rect().position
	var rs: Array = []
	for kind in touch_controls._buttons.keys():
		var area := (touch_controls._buttons[kind] as Dictionary)["area"] as Control
		if area != null and area.visible:
			rs.append(area.get_rect())
	if touch_controls.ult_gauge != null and touch_controls.ult_gauge.visible:
		rs.append(touch_controls.ult_gauge.get_rect())
	var m := INF
	for r in rs:
		if (r as Rect2).position.y + d.y < y:
			m = minf(m, (r as Rect2).position.x + d.x)
	if m == INF:
		return INF
	return m - 12.0

## A drawn (transformed) rect in global space.
func _p3_draw_rect(c: Control) -> Rect2:
	var t := c.get_global_transform()
	var a := t * Vector2.ZERO
	var b := t * c.size
	return Rect2(a, b - a).abs()

## Plan I2: a >= 70 px hit area on the touch layer centred
## on the target's drawn rect.
func _p3_place_hit(hit: Control, target: Control) -> void:
	if hit == null or target == null or touch_controls == null:
		return
	hit.visible = _p3_on == 1 and target.is_visible_in_tree()
	if not hit.visible:
		return
	var r := _p3_draw_rect(target)
	var sz := Vector2(maxf(r.size.x, 70.0), maxf(r.size.y, 70.0))
	hit.position = r.get_center() - sz * 0.5 - touch_controls.get_global_rect().position
	hit.size = sz

## Plan B0.5 / D7 floor for the column's text at scale sc.
func _p3_px(design: int, sc: float) -> int:
	var vp := get_viewport().get_visible_rect().size
	var fl := 19.0 if vp.x / maxf(vp.y, 1.0) >= 2.0 else 17.0
	return maxi(design, int(ceil((fl - 0.01) / maxf(sc, 0.01))))

## Plan R3+R4+R5 -> one objective pill (176 design wide,
## title 13 + sub 11 lifted to the D7 floor, tappable "+N"
## badge) + the kills pill's fold badge + the drawer (I4).
func _build_objective(root: Control, kpill: Control) -> void:
	_obj_pill = PanelContainer.new()
	_obj_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_obj_pill.offset_left = -188
	_obj_pill.offset_right = -12
	_obj_pill.offset_top = 226
	_obj_pill.offset_bottom = 290
	_obj_pill.custom_minimum_size = Vector2(176, 0)
	_obj_pill.add_theme_stylebox_override("panel", UiTheme.hud_glass(16, 0.74, Color(0.92, 0.96, 1.0, 0.70), 1.5, 12))
	_obj_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_pill.visible = false
	root.add_child(_obj_pill)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	_obj_pill.add_child(hb)
	_obj_dot = Panel.new()
	_obj_dot.custom_minimum_size = Vector2(10, 10)
	_obj_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_obj_dot.add_theme_stylebox_override("panel", UiTheme.flat_box(Color.WHITE, 5))
	hb.add_child(_obj_dot)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 4)
	vb.add_child(th)
	_obj_title = _mk_label(th, "", 13, Color.WHITE, true)
	_obj_title.add_theme_font_override("font", UiTheme.display_font())
	_obj_title.clip_text = true  # never widen the 176 pill
	_obj_title.custom_minimum_size = Vector2(80, 0)
	_obj_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_badge = Panel.new()
	_obj_badge.custom_minimum_size = Vector2(30, 20)
	_obj_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_obj_badge.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.20, 0.92), 10, Color(1, 1, 1, 0.35), 1, true))
	_obj_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(_obj_badge)
	_obj_badge_label = _label_in(_obj_badge, "+0", Vector2(0, 0), Vector2(30, 20), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_obj_sub = _mk_label(vb, "", 11, UiTheme.HUD_DIM, true)
	_obj_sub.clip_text = true
	_obj_sub.custom_minimum_size = Vector2(120, 0)
	# Plan Z3: past Z the pill folds into the kills pill's "+N"
	# (kills-local, right of the count; tappable through _obj_hit).
	_kills_badge = Panel.new()
	_kills_badge.position = Vector2(100, 4)
	_kills_badge.size = Vector2(30, 20)
	_kills_badge.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.20, 0.92), 10, Color(1, 1, 1, 0.35), 1, true))
	_kills_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kills_badge.visible = false
	kpill.add_child(_kills_badge)
	_kills_badge_label = _label_in(_kills_badge, "+0", Vector2(0, 0), Vector2(30, 20), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	# Plan I4 drawer: right edge = minimap left - 8, top =
	# minimap top, 320 x s_mm wide, never pauses.
	_obj_drawer = PanelContainer.new()
	_obj_drawer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_obj_drawer.offset_left = -520
	_obj_drawer.offset_right = -200
	_obj_drawer.offset_top = 10
	_obj_drawer.offset_bottom = 300
	# U1 1:1 round 13: fully opaque — at 0.92 the top bar's
	# bright wallet icons ghosted through the open drawer.
	_obj_drawer.add_theme_stylebox_override("panel", UiTheme.hud_glass(16, 0.99, Color(0.88, 0.94, 1.0, 0.65), 2, 14))
	_obj_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_obj_drawer.visible = false
	root.add_child(_obj_drawer)
	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 6)
	_obj_drawer.add_child(dvb)
	_obj_drawer_scroll = ScrollContainer.new()
	_obj_drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_obj_drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dvb.add_child(_obj_drawer_scroll)
	_obj_drawer_box = VBoxContainer.new()
	_obj_drawer_box.add_theme_constant_override("separation", 6)
	_obj_drawer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_drawer_scroll.add_child(_obj_drawer_box)
	# A fixed footer (never scrolls out of reach).
	_obj_drawer_all = UiTheme.make_button("查看全部挑战", "blue", "small")
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		_obj_drawer_all.add_theme_color_override(st, Color.WHITE)
	_obj_drawer_all.add_theme_color_override("font_outline_color", Color("13548c"))
	_obj_drawer_all.add_theme_constant_override("outline_size", 3)
	_obj_drawer_all.pressed.connect(_obj_open_challenges)
	dvb.add_child(_obj_drawer_all)

## The objective's tap target: the pill, or the kills pill
## once the pill has folded into it.
func _p3_obj_target() -> Control:
	return _kills_pill_node() if _obj_folded else _obj_pill

## Plan P3 objective pill: the most urgent entry (meowth only
## as the last resort — plan R4f), else the goal; "+N" = the
## rest. Signature-gated (P11).
func _p3_refresh_objective() -> void:
	if _obj_pill == null:
		return
	var evs := _event_list(true)
	var has_goal := _goal_species != ""
	var res: Array = []
	for ev in evs:
		if String(ev[3]) != "meowth":
			res = ev
			break
	if res.is_empty() and has_goal:
		res = ["伙伴营挑战", _goal_name.text, Color(0.35, 0.95, 0.55), "goal"]
	if res.is_empty() and not evs.is_empty():
		res = evs[0]
	var total := evs.size() + (1 if has_goal else 0)
	var sig := "%d|" % total
	for ev in evs:
		sig += String(ev[0]) + String(ev[1]) + ";"
	if has_goal:
		sig += _goal_name.text + _goal_next.text + _goal_count.text
	if sig == _obj_sig:
		return
	_obj_sig = sig
	_obj_total = total
	if not res.is_empty():
		_obj_title.text = String(res[0])
		_obj_sub.text = String(res[1])
		_obj_dot.add_theme_stylebox_override("panel", UiTheme.flat_box(res[2], 5))
	_obj_badge.visible = total > 1
	_obj_badge_label.text = "+%d" % (total - 1)
	_kills_badge_label.text = "+%d" % total
	if _obj_drawer.visible:
		_p3_fill_drawer()
	_layout_hud()

## Plan Z3 + P7: the pill rides s_mm under the kills pill; if
## its drawn bottom crosses Z (the cluster piece under it - 8)
## it folds into the kills pill's "+N".
func _p3_place_objective(mm_bot: float, mm_l: float, s_col: float, vw: float, vh: float) -> void:
	if _obj_pill == null:
		return
	if absf(s_col - _p3_s_col) > 0.0001:
		_p3_s_col = s_col
		_obj_sig = ""
	for r in [[_obj_title, 13], [_obj_sub, 11], [_obj_badge_label, 11], [_kills_badge_label, 11]]:
		var px := _p3_px(int(r[1]), s_col)
		if (r[0] as Label).get_theme_font_size("font_size") != px:
			(r[0] as Label).add_theme_font_size_override("font_size", px)
	_obj_badge.custom_minimum_size.y = maxf(20.0, float(_p3_px(11, s_col)) + 4.0)
	_obj_badge_label.size.y = _obj_badge.custom_minimum_size.y
	_kills_badge.size.y = maxf(20.0, float(_p3_px(11, s_col)) + 4.0)
	_kills_badge.position.y = (28.0 - _kills_badge.size.y) * 0.5
	_kills_badge_label.size.y = _kills_badge.size.y
	# The kills count (plan P2 gate: drawn >= 18) at a P7-
	# capped column scale (minimapScale 1.50 -> s_mm ~1.12).
	var kpx := maxi(14, int(ceil((18.0 - 0.01) / maxf(s_col, 0.01))))
	if not _kills_label.has_meta("p3_desk_fs"):
		_kills_label.set_meta("p3_desk_fs", _kills_label.get_theme_font_size("font_size"))
	if _kills_label.get_theme_font_size("font_size") != kpx:
		_kills_label.add_theme_font_size_override("font_size", kpx)
	_set_scaled(_obj_pill, s_col)
	var top := mm_bot + 4.0 + 28.0 * s_col + 8.0
	var h := _obj_pill.get_combined_minimum_size().y
	_obj_pill.offset_top = top
	_obj_pill.offset_bottom = top + h
	var z := _p3_z_over(vw - 12.0 - 176.0 * s_col, vw - 12.0)
	var has := _obj_total > 0
	_obj_folded = has and z < INF and top + h * s_col > z
	_obj_pill.visible = has and not _obj_folded and state != "menu"
	# U1 1:1 round 10 (main-controller ruling 12:2x): the "+N"
	# badge is OFF the kills pill for good — it was the folded
	# objective's target count (Plan Z3), not a kill floater,
	# and the reference kills pill is clean. The folded
	# objectives now live only in the target drawer (S17),
	# reached by tapping the kills pill (_p3_obj_target).
	_kills_badge.visible = false
	_p3_place_hit(_obj_hit, _p3_obj_target())
	# The hit never reaches into the cluster below (it is a
	# later touch-layer sibling and would steal the ult).
	if _obj_hit != null and _obj_hit.visible and touch_controls != null:
		var d: Vector2 = touch_controls.get_global_rect().position - _ui_root.get_global_rect().position
		var lim := _p3_z_over(_obj_hit.position.x + d.x, _obj_hit.position.x + d.x + _obj_hit.size.x)
		if lim < INF and _obj_hit.position.y + d.y + _obj_hit.size.y > lim + 6.0:
			_obj_hit.position.y = lim + 6.0 - d.y - _obj_hit.size.y
	_p3_place_drawer(mm_l, s_col, vw, vh)

func _p3_place_drawer(mm_l: float, s_col: float, vw: float, vh: float) -> void:
	_set_scaled(_obj_drawer, s_col)
	_obj_drawer.offset_right = (mm_l - 8.0) - vw
	_obj_drawer.offset_left = _obj_drawer.offset_right - 320.0
	_obj_drawer.offset_top = 10.0
	var x1 := mm_l - 8.0
	var z := _p3_z_over(x1 - 320.0 * s_col, x1)
	var max_h := (((z if z < INF else vh - 12.0) - 10.0) / s_col)
	# Rows rebuilt this frame: their autowrap minimums are not
	# real until the containers sort — keep the last height, the
	# process tick re-places once they have (_obj_drawer_settle).
	if _obj_drawer_settle > 0:
		_obj_drawer.offset_bottom = 10.0 + minf(_obj_drawer.offset_bottom - 10.0, max_h)
		return
	_obj_drawer_scroll.custom_minimum_size.y = 0.0
	var fixed := _obj_drawer.get_combined_minimum_size().y
	var want := fixed + _obj_drawer_box.get_combined_minimum_size().y
	var hh := minf(want, max_h)
	_obj_drawer_scroll.custom_minimum_size.y = maxf(hh - fixed, 0.0)
	_obj_drawer.offset_bottom = 10.0 + hh

## Plan I4 drawer content: every event (title + sub, list
## order = the pill's priority), the FULL goal card (name,
## bar, condition line + count) and 查看全部挑战.
## Rows are rebuilt only when the STRUCTURE changes (row count,
## goal / count presence, s_col); a text-only change (the
## countdowns tick every second) is written into the live rows.
## P3 fix round 2 class D: a rebuild's fresh autowrap labels
## report a width-0 minimum (one glyph per line) until their
## containers sort next frame, so measuring in the rebuild frame
## snapped the drawer to its Z-capped max height for a frame
## every tick — a press just under the drawer landed inside it.
func _p3_fill_drawer() -> void:
	var evs := _event_list(true)
	var sig := ""
	for ev in evs:
		sig += String(ev[0]) + String(ev[1]) + ";"
	sig += "%s|%s|%s|%.2f|%.3f" % [_goal_name.text, _goal_next.text, _goal_count.text,
		_goal_bar_fill.size.x, _p3_s_col]
	if sig == _obj_drawer_sig and _obj_drawer_box.get_child_count() > 0:
		return
	_obj_drawer_sig = sig
	var has_goal := _goal_species != ""
	var shape := "%d|%s|%s|%.3f" % [evs.size(), str(has_goal), str(_goal_count.text != ""), _p3_s_col]
	if shape == _obj_drawer_shape and _obj_drawer_box.get_child_count() > 0:
		_p3_write_drawer(evs)
		return
	_obj_drawer_shape = shape
	_obj_drawer_settle = 2
	_obj_drawer_refs = {"ev": []}
	for c in _obj_drawer_box.get_children():
		_obj_drawer_box.remove_child(c)
		c.queue_free()
	var sc := _p3_s_col
	var head := _mk_label(_obj_drawer_box, "目标 · %d 项" % _obj_total, _p3_px(15, sc), UiTheme.SKY, true)
	head.add_theme_font_override("font", UiTheme.display_font())
	_obj_drawer_refs["head"] = head
	for ev in evs:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		_obj_drawer_box.add_child(hb)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiTheme.flat_box(ev[2], 5))
		hb.add_child(dot)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		var t := _mk_label(vb, String(ev[0]), _p3_px(13, sc), Color.WHITE, true)
		t.add_theme_font_override("font", UiTheme.display_font())
		var sub := _mk_label(vb, String(ev[1]), _p3_px(11, sc), UiTheme.HUD_DIM, true)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(_obj_drawer_refs["ev"] as Array).append([dot, t, sub])
	if has_goal:
		var gt := _mk_label(_obj_drawer_box, "伙伴营挑战", _p3_px(13, sc), Color(0.35, 0.95, 0.55), true)
		gt.add_theme_font_override("font", UiTheme.display_font())
		var ghb := HBoxContainer.new()
		ghb.add_theme_constant_override("separation", 8)
		_obj_drawer_box.add_child(ghb)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(32, 32)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = _goal_pic.texture
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghb.add_child(pic)
		var gn := _mk_label(ghb, _goal_name.text, _p3_px(13, sc), Color.WHITE, true)
		gn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var track := Panel.new()
		track.custom_minimum_size = Vector2(0, 9)
		track.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(UiTheme.INK_DEEP.r, UiTheme.INK_DEEP.g, UiTheme.INK_DEEP.b, 0.85), 4))
		_obj_drawer_box.add_child(track)
		var fill := Panel.new()
		fill.position = Vector2(1, 1)
		fill.size = Vector2(maxf(290.0 * _p3_goal_frac(), 1.0), 7)
		fill.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.35, 0.95, 0.55), 3))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		var nhb := HBoxContainer.new()
		nhb.add_theme_constant_override("separation", 6)
		_obj_drawer_box.add_child(nhb)
		var nx := _mk_label(nhb, _goal_next.text, _p3_px(11, sc), UiTheme.HUD_DIM, true)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cnt: Label = null
		if _goal_count.text != "":
			cnt = _mk_label(nhb, _goal_count.text, _p3_px(11, sc), Color.WHITE, true)
		_obj_drawer_refs["goal"] = [pic, gn, fill, nx, cnt]
	_obj_drawer_all.add_theme_font_size_override("font_size", _p3_px(13, sc))
	# Plan I2: a HUD tappable draws >= 70 logical px tall.
	_obj_drawer_all.custom_minimum_size.y = ceilf(70.0 / maxf(sc, 0.01))

func _p3_goal_frac() -> float:
	return clampf(_goal_bar_fill.size.x / maxf(float(_goal_bar_fill.get_meta("track_w", 142.0)), 1.0), 0.0, 1.0)

## Same-shape refresh: texts / colours into the live rows (their
## widths are already sorted, so the measure stays exact).
func _p3_write_drawer(evs: Array) -> void:
	(_obj_drawer_refs["head"] as Label).text = "目标 · %d 项" % _obj_total
	var rows: Array = _obj_drawer_refs["ev"]
	for i in evs.size():
		var ev: Array = evs[i]
		(rows[i][0] as Panel).add_theme_stylebox_override("panel", UiTheme.flat_box(ev[2], 5))
		(rows[i][1] as Label).text = String(ev[0])
		(rows[i][2] as Label).text = String(ev[1])
	if _obj_drawer_refs.has("goal"):
		var g: Array = _obj_drawer_refs["goal"]
		(g[0] as TextureRect).texture = _goal_pic.texture
		(g[1] as Label).text = _goal_name.text
		(g[2] as Panel).size.x = maxf(290.0 * _p3_goal_frac(), 1.0)
		(g[3] as Label).text = _goal_next.text
		if g[4] != null:
			(g[4] as Label).text = _goal_count.text

func _obj_toggle_drawer() -> void:
	if _obj_drawer.visible:
		_obj_close_drawer()
	else:
		_obj_open_drawer()

func _obj_open_drawer() -> void:
	if _p3_on != 1 or _any_modal_open() or state not in ["playing", "guardian", "portal"]:
		return
	_obj_drawer_sig = ""
	_p3_fill_drawer()
	_obj_drawer.visible = true
	_obj_drawer_t = 4.0
	_layout_hud()

func _obj_close_drawer() -> void:
	if _obj_drawer != null:
		_obj_drawer.visible = false

## Plan §B4 P3: "查看全部挑战" — read-only G10, the run paused
## first; its close returns to the pause panel.
func _obj_open_challenges() -> void:
	audio.click()
	_obj_close_drawer()
	if state not in ["playing", "guardian", "portal"]:
		return
	_open_pause()
	_pause_panel.visible = false
	_unlock_from_pause = true
	_refresh_unlock_panel()
	_unlock_panel.visible = true
	_apply_ui_scale()

## Plan D1: the portrait pauses (status tab first).
func _p3_portrait_tap() -> void:
	if state in ["playing", "guardian", "portal"]:
		_obj_close_drawer()
		_open_pause()
		_pause_show_tab(0)

## Plan I1/I3 tap: press feedback while held, the action on
## release (touch + its emulated mouse arrive as two events
## — one action per 300 ms).
func _p3_tap_input(event: InputEvent, hit: Control, fx: Control, action: Callable) -> void:
	var down := false
	var up := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenTouch:
		down = event.pressed
		up = not event.pressed
	else:
		return
	hit.accept_event()
	if down:
		_p3_press_fx(fx, true)
		return
	if up:
		_p3_press_fx(fx, false)
		_p3_press_fx(_obj_pill, false)
		_p3_press_fx(_kills_pill_node(), false)
		var now := Time.get_ticks_msec()
		if now - _p3_tap_ms < 300:
			return
		_p3_tap_ms = now
		action.call()

## Plan I3: a+0.25 while pressed (the touch buttons' rule) —
## the panel's own fill (its stylebox is made unique on the
## first press), or the portrait's white wash.
func _p3_press_fx(target: Control, on: bool) -> void:
	if target == null:
		return
	if target is UiMedallion:
		(target as UiMedallion).press_a = 0.25 if on else 0.0
		return
	var sb := target.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	if not target.has_meta("p3_base_a"):
		if not on:
			return
		sb = sb.duplicate() as StyleBoxFlat
		target.add_theme_stylebox_override("panel", sb)
		target.set_meta("p3_base_a", sb.bg_color.a)
	var base := float(target.get_meta("p3_base_a"))
	sb.bg_color.a = minf(base + 0.25, 1.0) if on else base
	target.queue_redraw()

# ------------------------------------------------ UI-mobile P4
## Plan §B4 P4 / D5: the BL cluster's phone rows. Row 1 = one
## 130 slot per learned move (type icon + Lv + cooldown sweep),
## a lock slot at its end while the lab still has locked move
## slots; row 2 = one 34 slot per drafted vitamin (icon + level).
## Display only (plan I1) — the pause status page is the other
## home of the same player data (same reads, same tick).
## U1 1:1 round 6 (user ruling 2026-11-11 09:01): the move
## slots follow the v2 reference literally — ~130 design px
## (the 2340 shot measures ~126 screen px once the 0.30·vw
## cap binds), overturning the approved P4 46 px layout.
const P4_SLOT := 130.0
const P4_ROWS_H := 192.0   # 130 + 28 + 34: Z7 top stays under the ts1 ring
const P4_ROW_GAP := 28.0   # move row -> vitamin row: clears the Lv chip's overhang
const P4_MOVE_STEP := 140.0
const P4_VIT_STEP := 38.0
const P4_VIT_SLOT := 34.0
const P4_STRIP_PAD := 8.0  # dark band overhangs the outer slots by 8 px (reference)
const P4_BAND_H := 80.0   # dark band height: the slots protrude above/below it (reference)
## U1 1:1 round 6: the s_bl floor is a minimum legible SLOT size,
## not a scale — the pre-round-6 floor kept a 46 slot at >= 36.8
## logical px (46 x 0.8). Preserve that px floor at the new slot
## size (36.8 / 130 ~= 0.28) so the B0.2 caps can bind again;
## at 0.8 the floor overrode the caps and the rows overran the
## centre rect and the bubble span (fix6 batch: 20 P4 fails).
const P4_SBL_FLOOR := 0.28
const P4_VIT_ICON := {"phys_pct": "sword", "spec_pct": "spark", "armor_flat": "shield",
	"speed_pct": "speed", "hp_flat": "heart", "atkspd_pct": "hourglass", "crit_pct": "crit",
	"xp_pct": "candy", "gold_pct": "coin", "regen_flat": "plus", "luck_flat": "luck"}

## Flip-only (called from _layout_hud): legacy row vs rows.
func _p4_apply_mode(on: bool) -> void:
	var want := 1 if on else 0
	if want == _p4_on or _bl_cluster == null:
		return
	_p4_on = want
	for c in _bl_legacy:
		(c as Control).visible = not on
	_bl_rows.visible = on
	if _prompt_tri:
		_prompt_tri.visible = false
	_bl_sig = ""
	_bl_font_sig = ""
	if on:
		_p4_refresh_slots(false)
	else:
		# The 21.3.2 cluster: 460 x 118 at the factor scale
		# (_apply_ui_scale's value, re-pivoted on the restored
		# size — the scaler pivoted on the rows' size).
		_bl_cluster.offset_left = 0
		_bl_cluster.offset_right = 460
		_bl_cluster.offset_top = -118
		_bl_cluster.offset_bottom = 0
		var s := _kr() * float(GameProfile.setting("hudScale"))
		var vp := get_viewport().get_visible_rect().size
		if s > 1.0:
			s = minf(s, minf(vp.x * 0.96 / 460.0, vp.y * 0.96 / 118.0))
		_set_scaled(_bl_cluster, s)

## Rows' design width (the exact slot span: no ult gap).
## U1 1:1 round 6: the span, not the trimmed width — the
## cluster adds the band's 2x8 overhang on top of this.
func _p4_rows_w() -> float:
	var nm := _bl_move_slots.size() + _bl_locks.size() + (1 if _bl_lock.visible else 0)
	var w := maxf(nm * P4_MOVE_STEP - (P4_MOVE_STEP - P4_SLOT),
		_bl_vit_slots.size() * P4_VIT_STEP - (P4_VIT_STEP - P4_VIT_SLOT))
	return maxf(w, P4_SLOT)

## Signature-gated rebuild (plan risk P11): moves (key, level),
## vitamins (key, level), the lock slot.
func _p4_refresh_slots(relayout: bool) -> void:
	if _p4_on != 1 or _bl_rows == null or player == null or not is_instance_valid(player):
		return
	var parts: Array = []
	for m in player.moves:
		parts.append("%s:%d" % [String(m["key"]), int(m["level"])])
	parts.append("|")
	for vk in player.vit_levels.keys():
		parts.append("%s:%d" % [String(vk), int(player.vit_levels[vk])])
	var locked: bool = player.move_slots() < player.move_cap() and player.moves.size() < player.move_cap()
	parts.append("L" if locked else "-")
	var sig := ",".join(parts)
	if sig == _bl_sig:
		return
	_bl_sig = sig
	for d in _bl_move_slots + _bl_vit_slots:
		var p := (d as Dictionary)["panel"] as Control
		_bl_rows.remove_child(p)
		p.queue_free()
	for lp in _bl_locks:
		var lpc := lp as Control
		_bl_rows.remove_child(lpc)
		lpc.queue_free()
	_bl_locks.clear()
	_bl_move_slots.clear()
	_bl_vit_slots.clear()
	var i := 0
	for m in player.moves:
		var key := String(m["key"])
		var t := String(GameData.move(key).get("type", ""))
		var pnl := Panel.new()
		pnl.position = Vector2(P4_STRIP_PAD + i * P4_MOVE_STEP, 0)
		pnl.size = Vector2(P4_SLOT, P4_SLOT)
		pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 对齐定稿 U1_final.jpg：已学槽配 6px 厚实暖金立体外环；下方「1级」为立体奶油圆角小牌
		var tc := UiTheme.type_color(t)
		pnl.add_theme_stylebox_override("panel",
			_style(tc, 65, Color("efc038"), 6, true))
		_bl_rows.add_child(pnl)
		# 先绘一层偏深色立体浮雕阴影，保证高亮度浅底属性（如普通系白星）在真机强光下依然立体锐利
		var ic_sh := UiIcon.new(_type_icon(t), tc.darkened(0.45), 64)
		ic_sh.position = Vector2(33, 37)
		ic_sh.size = Vector2(64, 64)
		pnl.add_child(ic_sh)
		var ic := UiIcon.new(_type_icon(t), Color(1, 1, 1, 0.98), 64)
		ic.position = Vector2(33, 33)
		ic.size = Vector2(64, 64)
		pnl.add_child(ic)
		# Cooldown sweep (UltGauge-style arc): the remaining
		# fraction of the move's cooldown, drawn over the face.
		var sw := Control.new()
		sw.set_anchors_preset(Control.PRESET_FULL_RECT)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.set_meta("frac", 0.0)
		sw.draw.connect(_p4_draw_sweep.bind(sw))
		pnl.add_child(sw)
		var chip := _panel(pnl, Vector2(20, 110), Vector2(90, 30),
			Color(0.99, 0.98, 0.95, 0.98), 11, Color("c0b090"), 2, true)
		var lv := _label_in(chip, "%d级" % int(m["level"]), Vector2(0, 0),
			Vector2(90, 30), 14, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		_bl_move_slots.append({"panel": pnl, "lv": lv, "key": key, "sweep": sw})
		i += 1
	var display_n := maxi(5, player.moves.size() + (1 if locked else 0))
	var n_locks := display_n - player.moves.size()
	_bl_lock.visible = n_locks > 0
	_bl_lock.position = Vector2(P4_STRIP_PAD + i * P4_MOVE_STEP, 0)
	for k in range(1, n_locks):
		var lp := Panel.new()
		lp.position = Vector2(P4_STRIP_PAD + (i + k) * P4_MOVE_STEP, 0)
		lp.size = Vector2(P4_SLOT, P4_SLOT)
		lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lp.add_theme_stylebox_override("panel", _style(Color(0.24, 0.27, 0.34, 0.72), 65, Color("d8dde8"), 5, true))
		_bl_rows.add_child(lp)
		var lic := UiIcon.new("lock", Color(0.98, 0.98, 0.99, 0.95), 68)
		lic.position = Vector2(31, 31)
		lic.size = Vector2(68, 68)
		lp.add_child(lic)
		_bl_locks.append(lp)
	var j := 0
	for vk in player.vit_levels.keys():
		var vd: Dictionary = GameData.VITAMINS.get(vk, {})
		var pv := Panel.new()
		pv.position = Vector2(P4_STRIP_PAD + j * P4_VIT_STEP, P4_SLOT + P4_ROW_GAP)
		pv.size = Vector2(P4_VIT_SLOT, P4_VIT_SLOT)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.add_theme_stylebox_override("panel", _style(UiTheme.GREEN_DEEP, 17,
			Color(1, 1, 1, 0.25), 1))
		_bl_rows.add_child(pv)
		var vic := UiIcon.new(String(P4_VIT_ICON.get(String(vd.get("acc", "")), "flask")),
			Color(1, 1, 1, 0.9), 15)
		vic.position = Vector2(9.5, 1)
		vic.size = Vector2(15, 15)
		pv.add_child(vic)
		var vl := _label_in(pv, str(int(player.vit_levels[vk])), Vector2(0, 14), Vector2(34, 20),
			14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_bl_vit_slots.append({"panel": pv, "lv": vl, "key": String(vk)})
		j += 1
	_bl_font_sig = ""
	if relayout:
		_layout_hud()

## Plan Z7: anchor (23, vh - 12), width = the rows + the band's
## 2x8 overhang, s_bl = min(s, 1.35) — narrowed only where the
## rows would cost the bubble its 300 px span or reach the
## centre rect (plan B0.2: x past 0.30·vw AND top above
## 0.85·vh); floor P4_SBL_FLOOR (minimum legible slot size).
## U1 1:1 round 10 (main-controller ruling): the row's left
## edge sits at 23 so the first slot's left edge is 31 design
## px (reference U1_final.jpg) — the 12 px edge hugged the
## screen edge. P4_SLOT / P4_MOVE_STEP untouched; the s_bl
## cap's left-margin term tracks the new offset (23), so the
## centre-clear rule still binds at 0.30·vw with the same
## strength (phonehud assertion unchanged).
func _p4_layout_bl(s: float, vw: float, vh: float) -> void:
	if _p4_on != 1 or _bl_cluster == null:
		return
	var w := _p4_rows_w()
	var cw := w + 2.0 * P4_STRIP_PAD
	_bl_cluster.offset_left = 23.0
	_bl_cluster.offset_right = 23.0 + cw
	_bl_cluster.offset_top = -12.0 - P4_ROWS_H
	_bl_cluster.offset_bottom = -12.0
	_bl_rows.position = Vector2.ZERO
	_bl_rows.size = Vector2(cw, P4_ROWS_H)
	# U1 1:1 round 6: the band is the move row's bar only —
	# overhangs the outer slots by P4_STRIP_PAD, slots
	# protrude above/below it (reference U1_final.jpg).
	_bl_strip.position = Vector2(0, (P4_SLOT - P4_BAND_H) * 0.5)
	_bl_strip.size = Vector2(cw, P4_BAND_H)
	var s_bl := minf(s, 1.35)
	s_bl = minf(s_bl, maxf((0.30 * vw - 23.0) / cw, (0.15 * vh - 12.0) / P4_ROWS_H))
	# The cluster's geometry, visible or not: a layout pass
	# under a modal (layer hidden) must not leave a stale s_bl
	# once the layer is back (D6 round trip, it1 b).
	if touch_controls != null and touch_controls.size.x > 1.0:
		var cl: float = touch_controls.cluster_left()
		if cl < INF:
			var cl_ui: float = cl + touch_controls.get_global_rect().position.x \
				- _ui_root.get_global_rect().position.x
			s_bl = minf(s_bl, (cl_ui - 16.0 - 300.0 - 16.0 - 12.0) / cw)
	s_bl = maxf(s_bl, P4_SBL_FLOOR)
	# Keep the joystick at its original home for normal touch sizes.
	# Fit the rows below the ring while retaining the 12 px bottom inset.
	if touch_controls != null:
		var touch_scale: float = touch_controls.get("_scale_s")
		if touch_scale >= 0.999:
			var ring_bottom: float = touch_controls.get_global_rect().end.y - 134.0 * touch_scale
			ring_bottom -= _ui_root.get_global_rect().position.y
			s_bl = maxf(P4_SBL_FLOOR, minf(s_bl, (vh - 12.0 - ring_bottom) / P4_ROWS_H))
	_set_scaled(_bl_cluster, s_bl)
	_p4_fit_fonts(s_bl)

## Slot labels at their design size unless that draws below the
## D7 floor (19 on 20:9, 17 on 16:9) — the P2 font rule.
func _p4_fit_fonts(s_bl: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var fl := 19.0 if vp.x / maxf(vp.y, 1.0) >= 2.0 else 17.0
	var sig := "%.4f|%.0f|%s" % [s_bl, fl, _bl_sig]
	if sig == _bl_font_sig:
		return
	_bl_font_sig = sig
	var px := maxi(14, int(ceil((fl - 0.01) / maxf(s_bl, 0.01))))
	for d in _bl_move_slots + _bl_vit_slots:
		var l := (d as Dictionary)["lv"] as Label
		l.add_theme_font_size_override("font_size", px)
		# Bottom-aligned on the font's line box (this face's box
		# is ~1.65x its size — a fixed rect would outgrow the
		# slot and the cluster's rows).
		var slot_h := (l.get_parent() as Control).size.y
		var lh := l.get_theme_font("font").get_height(px) + float(l.get_theme_constant("line_spacing"))
		# 招式芯片「1级」垂直居中在独立白牌中央，维他命行仍居底部给上方图标留位
		l.position = Vector2(0, (slot_h - lh) * 0.5 if (d as Dictionary).has("sweep") else (slot_h - lh))
		l.size = Vector2((l.get_parent() as Control).size.x, lh)
		# "Lv.10" outgrows the 94 chip at the lifted sizes.
		if (d as Dictionary).has("sweep"):
			var lvn := _p4_lv_of(l.text)
			l.text = "%d级" % lvn
			if l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > (l.get_parent() as Control).size.x - 2.0:
				l.text = str(lvn)

func _p4_lv_of(t: String) -> int:
	var dg := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			dg += ch
	return int(dg) if dg != "" else 0

## Per frame: each move slot's sweep = cd_t / its cooldown.
func _p4_tick_sweeps() -> void:
	if _p4_on != 1 or player == null or not is_instance_valid(player):
		return
	var n := mini(_bl_move_slots.size(), player.moves.size())
	for i in range(n):
		var m: Dictionary = player.moves[i]
		var cdmax := float(GameData.ARCH_CD[GameData.archetype(String(m["key"]))]) \
			/ maxf(float(player.atk_speed), 0.01)
		var f := clampf(float(m["cd_t"]) / maxf(cdmax, 0.01), 0.0, 1.0)
		var sw := (_bl_move_slots[i] as Dictionary)["sweep"] as Control
		if absf(f - float(sw.get_meta("frac", 0.0))) > 0.01 or (f == 0.0) != (float(sw.get_meta("frac", 0.0)) == 0.0):
			sw.set_meta("frac", f)
			sw.queue_redraw()

func _p4_draw_sweep(sw: Control) -> void:
	var f := float(sw.get_meta("frac", 0.0))
	if f <= 0.001:
		return
	var c := sw.size * 0.5
	var r := minf(sw.size.x, sw.size.y) * 0.5 - 3.0
	# Remaining cooldown: a dim veil + the arc shrinking toward
	# the top, as the ult gauge's sweep fills from it.
	sw.draw_circle(c, r, Color(0, 0, 0, 0.28 * f + 0.10))
	sw.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * f, 32, Color(1, 1, 1, 0.85), 3.0, true)

## Plan §B1 C5 / §B4 P4 (Z6): the interaction bubble. Right
## edge = the thumb cluster's left - 16, left bound = the BL
## rows' drawn right + 16, backing bottom = vh - 24, <= 2 lines,
## scale <= 1.4 — and its top held at/below 0.85·vh (the plan's
## P4 centre-clear rule: only the part below 0.85·vh may share
## the centre rect's x range). One line when it reads larger.
## A pointer on the backing's right edge aims at the ❗ centre.
func _p4_layout_bubble(span_r: float, vw: float, vh: float) -> void:
	var ui_o := _ui_root.get_global_rect().position
	var fx_l := _p3_draw_rect(_bl_cluster).end.x - ui_o.x + 16.0
	var fx_r := span_r - 4.0
	var ic_y := INF
	if touch_controls != null and touch_controls.size.x > 1.0:
		var cl: float = touch_controls.cluster_left()
		if cl < INF:
			fx_r = cl + touch_controls.get_global_rect().position.x - ui_o.x - 16.0
		if touch_controls._buttons.has("interact"):
			var ipan := (touch_controls._buttons["interact"] as Dictionary)["panel"] as Control
			ic_y = _p3_draw_rect(ipan).get_center().y
	var avail := maxf(fx_r - fx_l, 40.0)
	_prompt.max_lines_visible = 2
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _prompt.text == "":
		_prompt_tri.visible = false
		return
	var fnt := _prompt.get_theme_font("font")
	var fsz := _prompt.get_theme_font_size("font_size")
	var w1 := fnt.get_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz).x
	var lh := fnt.get_height(fsz) + float(_prompt.get_theme_constant("line_spacing"))
	var hcap := vh * 0.15 - 24.0
	var p1 := minf(1.4, minf(avail / (w1 + 4.0 + 16.0), hcap / (lh + 12.0)))
	var p2 := minf(1.4, minf(2.0 * avail / (w1 * 1.06 + 32.0), hcap / (2.0 * lh + 12.0)))
	var pscale := maxf(p1, p2)
	var one := p1 >= p2
	var w := 0.0
	var min_h := 0.0
	for k in range(8):
		w = minf(600.0, avail / pscale - 16.0)
		if one:
			w = minf(w, w1 + 4.0)
		var cx := fx_r - 8.0 * pscale - w * pscale * 0.5
		_prompt.offset_left = cx - vw * 0.5 - w * 0.5
		_prompt.offset_right = cx - vw * 0.5 + w * 0.5
		_set_scaled(_prompt, pscale)
		_prompt.update_minimum_size()
		min_h = _prompt.get_combined_minimum_size().y
		if _prompt.get_line_count() <= 2 and (maxf(min_h, 24.0) + 12.0) * pscale <= hcap + 0.5:
			break
		one = false
		pscale *= 0.94
	_prompt.offset_top = _prompt.offset_bottom - maxf(min_h, 24.0)
	_set_scaled(_prompt, pscale)
	# Pin: the backing's drawn bottom = label bottom + 6 (both
	# pivot on their bottom edge) = vh - 24.
	var target_bot := ui_o.y + vh - 30.0
	for i in range(2):
		var d := target_bot - _prompt.get_global_rect().end.y
		if absf(d) < 0.5:
			break
		_prompt.offset_bottom += d
		_prompt.offset_top += d
	if _prompt_back:
		_prompt_back.offset_left = _prompt.offset_left - 8.0
		_prompt_back.offset_right = _prompt.offset_right + 8.0
		_prompt_back.offset_top = _prompt.offset_top - 6.0
		_prompt_back.offset_bottom = _prompt.offset_bottom + 6.0
		_set_scaled(_prompt_back, pscale)
		var br := _p3_draw_rect(_prompt_back)
		var bs := _prompt_back.size
		var gy := br.get_center().y if ic_y == INF else ic_y
		var ty := clampf((gy - br.position.y) / pscale, 10.0, bs.y - 10.0)
		_prompt_tri.polygon = PackedVector2Array([Vector2(bs.x + 10.0, ty),
			Vector2(bs.x - 1.0, ty - 9.0), Vector2(bs.x - 1.0, ty + 9.0)])
		_prompt_tri.visible = true

## Cycle 21.3 (audit F5): pin the prompt into the free
## span between the bottom-left cluster and the touch
## lane, its visual bottom 8 px above the move slot's
## visual top. Phone branch only — the desktop prompt
## geometry is shipped and overlap-free (factor 1 puts
## the slot band below the prompt's bottom).
func _layout_prompt(span_l: float, span_r: float, vw: float, vh: float, s: float) -> void:
	if _prompt == null or _bl_cluster == null:
		return
	# UI-mobile P4 (plan §B1 C5 / §B4 P4): the new layout's
	# prompt is the interaction bubble (Z6) — the 21.3.2
	# lifted regime below stays for the classic layout only.
	if _p4_on == 1:
		_p4_layout_bubble(span_r, vw, vh)
		return
	if _prompt_tri:
		_prompt_tri.visible = false
	var pscale := minf(s, 1.6)
	var ui_o := _ui_root.get_global_rect().position
	var blr := _bl_cluster.get_global_rect()
	if blr.size.x <= 0.0:
		return  # pre-layout frame; a later pass settles it
	var fx_l := blr.end.x - ui_o.x + 16.0
	var fx_r := span_r - 4.0
	# UI-mobile P3: on the new layout the cluster clamp also
	# runs BEFORE the regime choice. The 21.3 order was safe
	# only while the pause / aim column narrowed the
	# lane (span_r); with the column gone the clamp below
	# could drive a "wide enough" span negative after the
	# choice (P7 corner hud 1.30: BL 1151 wide, lock left
	# 1150 -> a 34 px, 27-line prompt). Classic keeps the
	# 21.3 order verbatim.
	if _p3_on == 1 and touch_controls != null and touch_controls.visible:
		var cl0: float = touch_controls.cluster_left()
		if cl0 < INF:
			fx_r = minf(fx_r, cl0 + touch_controls.get_global_rect().position.x - ui_o.x - 16.0)
	if fx_r - fx_l < 80.0:
		fx_l = span_l
		fx_r = span_r
	# Audit F5c: the free span ends at the touch
	# CLUSTER's left edge (the big dash / jump buttons
	# protrude past the moved column at large
	# touchScales), minus 16. Applied last so the
	# narrow-span fallback above cannot undo it.
	# Cycle 21.3.1 note: at 1920x1080 + touchScale
	# 1.50 this leaves a ~38 px gap (the cluster
	# protrudes across the whole centre of the
	# narrow viewport). A lane-bound fallback was
	# tried and REVERTED the same cycle: the drawn
	# prompt then reached x~1009 and overlapped
	# the dash/jump buttons (left edge 956) in the
	# gate — printing over buttons is worse than a
	# narrow prompt. The cluster bound always wins;
	# the narrow-span regime below keeps the column
	# bounded instead. Real relocation = C22.
	if touch_controls != null and touch_controls.visible:
		var cl: float = touch_controls.cluster_left()
		if cl < INF:
			fx_r = minf(fx_r, cl
				+ touch_controls.get_global_rect().position.x
				- ui_o.x - 16.0)
	# Cycle 21.3.1 (re-audit N1): the span is already
	# fully used at touchScale 1.50 (the BL cluster and
	# the touch cluster leave ~360 visual px), so the
	# long strings (chest insufficient-funds, meowth)
	# wrapped to 3 lines under the 1.6 scale and the
	# new max_lines_visible = 2 cap would CLIP them.
	# Widen-within-the-span here means lowering the
	# scale until the measured one-line text width
	# fits two lines of the span, with 6% wrap slack —
	# deterministic, no feedback (the width is
	# re-derived from the text each pass).
	# Cycle 21.3.2 (re-audit issue 1, BLOCKING): the
	# 21.3.1 lift set max_lines_visible = 0 — in
	# Godot 4.3 that means SHOW NO LINES (unlimited
	# is -1), so on the 10 phone combos with
	# fit2 < 1.0 the prompt rendered as an EMPTY
	# glass box (a regression vs 21.3, misdescribed
	# in the 21.3.1 record). The cap now stays
	# engaged whenever 2 lines fit at scale >= 0.6:
	# the fit scale may drop below the old 1.0 floor
	# down to fit2 itself (hard floor 0.6). Only
	# below fit2 0.6 — the 16:9 span is ~140 visual
	# px and 2 legible lines are geometrically
	# impossible there — does the cap lift, to -1
	# (ALL lines), and then the scale ALSO fits by
	# height so the wrapped column stays within the
	# gate's 288 px bound: an analytic first estimate
	# (height ~= (w1 * 1.06 * pscale / span) lines *
	# 24 * pscale, solved for a 260 px target) seeds
	# the scale, and the measure-and-correct loop at
	# the tail of this function then enforces the
	# bound against the TRUE wrapped height — the
	# estimate's 24 px line model underestimates
	# this font. At the ~38 px strangled span the
	# pair pulls the scale to ~0.9 and below. The
	# gate asserts visible lines == total lines in
	# every prompt state, plus lines <= cap where
	# capped and height <= 288 where lifted.
	if _prompt.text != "":
		var fnt := _prompt.get_theme_font("font")
		var fsz := _prompt.get_theme_font_size("font_size")
		var w1 := fnt.get_string_size(_prompt.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz).x
		if w1 > 0.0 and fx_r - fx_l > 0.0:
			var fit2 := 2.0 * (fx_r - fx_l) / (w1 * 1.06)
			if fit2 >= 0.6:
				_prompt.max_lines_visible = 2
				pscale = minf(pscale, maxf(0.6, fit2))
			else:
				_prompt.max_lines_visible = -1
				var hfit := sqrt(260.0 * (fx_r - fx_l)
					/ (24.0 * w1 * 1.06))
				pscale = minf(pscale, hfit)
			# The label's cached minimum size was
			# computed under the PREVIOUS cap (the text
			# was set while the creation cap 2 was in
			# force, and set_max_lines_visible does not
			# dirty that cache): without this, the
			# min_h read below returns the old cap's
			# height and the rect clips the lifted
			# column back to 2 visible lines.
			_prompt.update_minimum_size()
	# Cycle 21.3.2: in the LIFTED regime the analytic
	# hfit alone does not hold the 288 bound once the
	# text really renders — its 24 px line model
	# underestimates this font's ~33 px line height,
	# and the wrapped line count is discrete (the
	# first fixed build measured h=334 at 1920x1080
	# ts 0.70). So: apply width + scale, MEASURE the
	# true wrapped height, and correct the scale
	# against the measurement, bounded iterations,
	# all inside this pass. Drawn height grows
	# monotonically with scale, so the ratio step
	# converges (1-2 steps on every real combo); the
	# min_h used below is the final measured one.
	# The capped regime measures once and exits.
	var w_design := 0.0
	var min_h := 0.0
	for htry in range(4):
		w_design = minf(600.0, (fx_r - fx_l) / pscale)
		var cx := (fx_l + fx_r) * 0.5
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt.offset_left = cx - vw * 0.5 - w_design * 0.5
		_prompt.offset_right = cx - vw * 0.5 + w_design * 0.5
		_set_scaled(_prompt, pscale)
		if _prompt_back:
			_set_scaled(_prompt_back, pscale)
		_prompt.update_minimum_size()
		min_h = _prompt.get_combined_minimum_size().y
		if _prompt.max_lines_visible >= 0:
			break
		var vis_h := (min_h + 12.0) * pscale
		if vis_h <= 288.0:
			break
		pscale *= 288.0 / vis_h
	# Height from the wrapped text at the new width, then
	# pin the visual bottom: for a bottom-anchored label
	# the drawn bottom is anchor + offset_bottom exactly
	# (the pivot sits on the bottom edge), so the delta
	# correction is exact — the second pass is a no-op
	# check.
	_prompt.offset_top = _prompt.offset_bottom - maxf(min_h, 24.0)
	# Cycle 21.3.2: refresh the pivot from the FINAL
	# size before pinning. _set_scaled computes the
	# pivot from the size current at call time, and
	# the label's height trails its minimum size
	# (container-fitted with a lag), so during the
	# loop the pivot referenced a STALE height (626
	# when the final height was 196). The pin below
	# would bake that pivot error into the offsets,
	# and the backing — copied offsets but a fresh
	# pivot — drew ~236 px away from the label (the
	# gate's union rect caught it at 1920x1080 /
	# touchScale 1.50, no inset). With the pivot
	# refreshed here, the pin measures honestly and
	# the backing's copied offsets land on the label.
	_set_scaled(_prompt, pscale)
	var target_bot := blr.position.y + 48.0 * _bl_cluster.scale.y - 8.0
	for i in range(2):
		var d := target_bot - _prompt.get_global_rect().end.y
		if absf(d) < 0.5:
			break
		_prompt.offset_bottom += d
		_prompt.offset_top += d
	if _prompt_back:
		# Cycle 21.3.1 (re-audit N2): side pads trimmed
		# 12 -> 8 design px. At pscale 1.6 the +-12 pad
		# pushed the backing ~3 px INTO the jump/dash
		# buttons past the span's right bound (the gate
		# now asserts label + backing as one rect); 8
		# keeps the ink-glass rim and clears the lane.
		_prompt_back.offset_left = _prompt.offset_left - 8.0
		_prompt_back.offset_right = _prompt.offset_right + 8.0
		_prompt_back.offset_top = _prompt.offset_top - 6.0
		_prompt_back.offset_bottom = _prompt.offset_bottom + 6.0
		_set_scaled(_prompt_back, pscale)

## Cycle 21.3 (audit F1c): the info-stack budget. The
## kills -> goal -> pills stack must end at or above
## Z = (vh - 248 x touchScale) - 8 — the touch ult
## gauge's top minus a margin (the gauge binds before
## the dash button). When it would cross, shed in the
## audit's order: (1) pills past the first collapse
## into a "+N" badge on the first pill, (2) the goal
## card drops its bar + next line (header only),
## (3) the first pill hides and the badge moves to the
## goal header. Only while the touch layer is visible;
## desktop keeps today's stacking. The pass RESETS the
## shed state first, so it re-derives from the live
## stack on every layout.
func _apply_stack_budget(s_top: float, vw: float, vh: float) -> void:
	if _goal_card == null or _pill_box == null:
		return
	# UI-mobile P3 (plan Z3): the new phone layout has no
	# goal card / pill stack — the objective pill folds into
	# the kills pill's "+N" instead (_p3_place_objective).
	if _p3_on == 1:
		if _pill_badge:
			_pill_badge.visible = false
		return
	# Reset: full goal card, every live pill, no badge.
	if _goal_track:
		_goal_track.visible = true
	if _goal_next:
		_goal_next.visible = true
	if _goal_count:
		_goal_count.visible = true
	var pills: Array = []
	for c in _pill_box.get_children():
		var pc := c as Control
		if pc != null and not pc.is_queued_for_deletion():
			pc.visible = true
			pills.append(pc)
	if _pill_badge:
		_pill_badge.visible = false
	# Re-derive the full-stack positions from the
	# post-reset heights BEFORE measuring: the main
	# body's pass may have run against last pass's
	# shed state (its gh reads the children's CURRENT
	# visibility), and a Control never draws below its
	# combined minimum — so a goal card whose detail
	# was just un-hidden draws FULL height again while
	# the pill box still sits at the shed position.
	# Measuring from that stale offset understates the
	# settled stack and the shed never re-fires
	# (1920x1080 @ touchScale 1.50, gate-caught).
	_restack_goal(s_top)
	if touch_controls == null or not touch_controls.visible:
		return
	var ts := float(touch_controls.get("_scale_s"))
	var z := (vh - 248.0 * ts) - 8.0
	var sep := 6.0
	var hidden := 0
	# Stack geometry (drawn space): the goal card's
	# bottom, then each visible pill in order.
	var goal_bot := _goal_card.offset_top + _goal_gh(s_top) * s_top
	var pill_top := _pill_box.offset_top
	var bottoms: Array = []
	var y := pill_top
	for pc in pills:
		y += (pc as Control).get_combined_minimum_size().y * s_top
		bottoms.append(y)
		y += sep * s_top
	var stack_bot := goal_bot
	if not bottoms.is_empty():
		stack_bot = float(bottoms[bottoms.size() - 1])
	if stack_bot <= z:
		return
	# Shed 1: pills past the first collapse.
	if pills.size() > 1:
		for i in range(1, pills.size()):
			(pills[i] as Control).visible = false
		hidden = pills.size() - 1
		stack_bot = float(bottoms[0])
		_badge_on_pill(pills[0] as Control, hidden, s_top, vw)
	if stack_bot <= z:
		return
	# Shed 2: the goal card drops bar + next line.
	if _goal_track:
		_goal_track.visible = false
	if _goal_next:
		_goal_next.visible = false
	if _goal_count:
		_goal_count.visible = false
	_restack_goal(s_top)
	goal_bot = _goal_card.offset_top + _goal_gh(s_top) * s_top
	if pills.is_empty():
		stack_bot = goal_bot
	elif (pills[0] as Control).visible:
		stack_bot = _pill_box.offset_top \
			+ (pills[0] as Control).get_combined_minimum_size().y * s_top
	else:
		stack_bot = goal_bot
	if stack_bot <= z:
		return
	# Shed 3: the first pill hides; the badge moves to
	# the goal header.
	if not pills.is_empty():
		(pills[0] as Control).visible = false
		hidden = pills.size()
		if _goal_card.visible:
			_badge_on_goal(hidden, s_top, vw)
	stack_bot = goal_bot

## The goal card's current design height (the C19
## fallback covers pre-content frames).
func _goal_gh(s_top: float) -> float:
	var gh := _goal_card.get_combined_minimum_size().y
	if gh < 40.0:
		gh = maxf(_goal_card.size.y, 86.0)
	return gh

## Re-derive the goal card's design height + the pill
## box's top (F2 formula) after a shed changed the
## card's content.
func _restack_goal(s_top: float) -> void:
	var gh := _goal_gh(s_top)
	_goal_card.offset_bottom = _goal_card.offset_top + gh
	_pill_box.offset_top = _goal_card.offset_top + gh * s_top + 8.0

func _badge_on_pill(pill: Control, hidden: int, s_top: float, vw: float) -> void:
	if _pill_badge == null:
		return
	_pill_badge_label.text = "+%d" % hidden
	_set_scaled(_pill_badge, s_top)
	_pill_badge.offset_left = (vw - 12.0) - 34.0 * s_top
	_pill_badge.offset_right = _pill_badge.offset_left + 34.0
	_pill_badge.offset_top = _pill_box.offset_top
	_pill_badge.offset_bottom = _pill_badge.offset_top + 20.0
	_pill_badge.visible = true

func _badge_on_goal(hidden: int, s_top: float, vw: float) -> void:
	if _pill_badge == null:
		return
	_pill_badge_label.text = "+%d" % hidden
	_set_scaled(_pill_badge, s_top)
	_pill_badge.offset_left = (vw - 12.0) - 34.0 * s_top
	_pill_badge.offset_right = _pill_badge.offset_left + 34.0
	_pill_badge.offset_top = _goal_card.offset_top
	_pill_badge.offset_bottom = _pill_badge.offset_top + 20.0
	_pill_badge.visible = true

func _apply_visibility_settings() -> void:
	if _hud_root:
		_hud_root.modulate.a = float(GameProfile.setting("hudOpacity"))
	if _boss_card:
		_boss_card.modulate.a = float(GameProfile.setting("bossOpacity"))
	for bar in _mini_bars:
		(bar["panel"] as Panel).modulate.a = float(GameProfile.setting("bossOpacity"))
	_apply_minimap_scale()
	Engine.max_fps = int(GameProfile.setting("fpsCap"))
	_layout_hud()

func _apply_minimap_scale() -> void:
	if _minimap == null:
		return
	var s := float(GameProfile.setting("minimapScale"))
	var w := 168.0 * s
	_minimap.offset_left = -16.0 - w
	_minimap.offset_right = -16.0
	_minimap.offset_top = 14.0
	_minimap.offset_bottom = 14.0 + w
	var frame := _hud_root.get_node_or_null("MinimapFrame") as Control
	if frame:
		var fw := 176.0 * s
		frame.offset_left = -12.0 - fw
		frame.offset_right = -12.0
		frame.offset_top = 10.0
		frame.offset_bottom = 10.0 + fw

# ---------------------------------------------------------- bag boosts
## add_move_damage: results-screen attribution (combat_hit /
## slam / projectiles / player melee all funnel here).
func add_move_damage(key: String, dmg: float) -> void:
	if dmg <= 0.0 or key == "":
		return
	run_move_dmg[key] = float(run_move_dmg.get(key, 0.0)) + dmg

## applyBoosts mirror (bundle @1444306): each selected item
## is SPENT from the profile bag, then its effect lands.
func _apply_boosts(boosts: Array) -> void:
	var applied: Array = []
	for raw in boosts:
		var id := String(raw)
		if not GameProfile.bag_consume(id):
			continue
		applied.append(id)
		match id:
			"rare-candy":
				player.level += 2
				player.pending_levels += 2
			"lucky-egg":
				player.temp_mods.append({"stat": "xpGain", "mul": 1.25})
			"amulet-coin":
				player.temp_mods.append({"stat": "gold", "mul": 1.5})
			"honey":
				_boost_honey = true
				_honey_at = 240.0
			"shiny-stone":
				# Bundle @1049102: the stone min()s the stage-1
				# director roll into [40,150]. Against a FAILED
				# roll (shinyAt = ∞) that makes the stone a
				# stage-1 GUARANTEE — min(∞, x) is finite
				# (cycle 20 truth; the roll itself is the
				# probability roll in _roll_shiny_director).
				_shiny_at = minf(_shiny_at, _rng.randf_range(40.0, 150.0))
			"master-ball":
				_master_ball = true
	if applied.is_empty():
		return
	player.recalc()
	var names: Array = []
	for it in GameProfile.SHOP_ITEMS:
		if applied.has(String(it["id"])):
			names.append(String(it["name"]))
	_later(1.2, func() -> void:
		show_banner("背包：" + " · ".join(names), 3.0))

## Cycle 20 (DIFF §7 correction): the shiny stage director
## is a PROBABILITY roll per stage (bundle roll main
## @1048868; constants data chunk @84289):
##   P = (0.08 + min(0.08, luck/1000)) * shinyRate()
## On success shinyAt = the stage clock + range(40, 420) s
## (fire @1049322, at most one scheduled shiny per stage);
## on failure there is NO shiny this stage (shinyAt =
## Infinity). shinyRate() is the Shiny Charm ladder rung
## (x1.5 from 6 unique shiny species, @1579031). Rolled at
## run start (after the player's setup — the roll reads the
## player's luck) and at every zone advance; the shiny
## stone min()s the stage-1 roll into [40,150] at
## applyBoosts time (@1049102), which against a failed roll
## makes the stone a stage-1 GUARANTEE (min(∞, x) finite).
## Cycle 19's guaranteed range(600,1100) schedule was the
## first mining pass's misread and is removed.
func _roll_shiny_director() -> void:
	_shiny_spawned = false
	var luck := 0.0
	if player != null and is_instance_valid(player):
		luck = player.luck
	var p := (0.08 + minf(0.08, luck / 1000.0)) * GameProfile.shiny_rate()
	_shiny_at = elapsed + _rng.randf_range(40.0, 420.0) if _rng.randf() < p else INF

## spawnShiny species pick (bundle main @1051777): the
## current horde pool filtered to animated species,
## PREFERRING families not yet shiny-caught, weighted by
## Cx = 0.15 + 0.85 * captureRate/255 (@1047818);
## fallback = dex id 25.
func _pick_shiny_species(pool: Array, prefer_fresh: bool = true) -> String:
	var modelled: Dictionary = {}
	for k in GameData.roster_species_keys():
		modelled[String(k)] = true
	var cands: Array = []
	for k in pool:
		if modelled.has(String(k)) or (not prefer_fresh and ModelRig.SPECIES.has(String(k))):
			cands.append(String(k))
	if cands.is_empty():
		return String(GameData.species_by_id(25).get("key", "pikachu"))
	var shiny_fams := GameProfile.shiny_families()
	var fresh: Array = []
	for k in cands:
		if not shiny_fams.has(int(GameData.species(String(k)).get("family", 0))):
			fresh.append(String(k))
	var src: Array = fresh if prefer_fresh and not fresh.is_empty() else cands
	var total := 0.0
	var weights: Array = []
	for k in src:
		# Cycle 20.1 (audit N16): the bundle's pick weight is
		# Cx = floor + (1 - floor) * captureRate/255 (main
		# @1047818; floor 0.15 in the data chunk) — a LINEAR
		# LIFT, not the maxf(0.15, cr/255) clamp cycle 20
		# shipped (cr 45: 0.30 bundle vs 0.176 clamped).
		var wgt := 0.15 + 0.85 * float(GameData.species(String(k)).get("captureRate", 255)) / 255.0
		weights.append(wgt)
		total += wgt
	var r := _rng.randf() * total
	for i in range(src.size()):
		r -= float(weights[i])
		if r <= 0.0:
			return String(src[i])
	return String(src[src.size() - 1])

## spawnShiny: a league-chassis encounter — roam, weaken,
## throw — of a horde-pool species (pick above); the
## encounter does NOT unlock its family (the spawn call
## passes the unlock flag false). Spawn HP x2.5 (@1052378).
## The render variant is the rig's hue rotation zl(id)
## (ModelRig.apply_shiny, main @125961) at the 1.25x sprite
## scale (@1335362), plus twinkle sparkles, the standing
## pink lamp and the cyan minimap ring. The flee clock is
## the ladder's: 120 s, 150 s with the Shiny Charm
## (shinyFlee @1579088).
func _spawn_shiny(pool_override: Array = []) -> void:
	if is_instance_valid(_league_e) or is_instance_valid(_shiny_e) or is_instance_valid(_classic_e):
		return  # Direct event calls share the capture state gate.
	var sp := _pick_shiny_species(pool_override if not pool_override.is_empty() else ZONES[zone - 1]["pool"])
	var e := _spawn_enemy_at(sp, _ring_pos(24.0, 40.0), _spawn_mult() * 2.5, false, 1.25)
	e.shiny = true
	if e.rig:
		e.rig.apply_shiny()
	e.mode = Enemy.MODE_LEAGUE
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.5, 0.8)
	lamp.light_energy = 1.5
	lamp.omni_range = 5.0
	lamp.position = Vector3(0, 1.8, 0)
	e.add_child(lamp)
	_attach_shiny_sparkles(e)
	_shiny_e = e
	_shiny_escape = GameProfile.shiny_flee_time()
	audio.cry(sp)
	show_banner("流光的 %s 出现了！打弱它再邀伴结伴！" % String(ModelRig.SPECIES[sp]["label"]), 4.0)

## The bundle's twinkle sparkles on a shiny encounter: a
## small GPU emitter riding the enemy — the weather
## system's particle idiom (soft disc texture, unshaded
## billboard quads), pink-white, on a slow rise with a
## swell-and-fade twinkle curve.
func _attach_shiny_sparkles(e: Enemy) -> void:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.15
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_texture = _wx_soft_texture()
	qm.albedo_color = Color(1.0, 0.72, 0.9, 0.9)
	quad.material = qm
	p.draw_pass_1 = quad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.85
	pm.gravity = Vector3(0, 0.3, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	var tw := Curve.new()
	tw.add_point(Vector2(0, 0.2))
	tw.add_point(Vector2(0.5, 1.0))
	tw.add_point(Vector2(1, 0.15))
	var ct := CurveTexture.new()
	ct.curve = tw
	pm.scale_curve = ct
	p.process_material = pm
	p.position = Vector3(0, 0.9, 0)
	e.add_child(p)

## The bundle's pink capture beam: a brief vertical shaft
## at the spot where a shiny is caught.
func _shiny_beam(pos: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.8
	cyl.height = 14.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.45, 0.75, 0.45)
	cyl.material = m
	beam.mesh = cyl
	add_child(beam)
	beam.global_position = pos + Vector3(0, 7.0, 0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(beam.queue_free)

# ---------------------------------------------------------- results
## The sectioned summary (UI_SPEC §2.7). Sections appear
## only when their system fed them this run. Two bundle
## sections are omitted with cause: the BONK payout chip
## (this economy pays stardust in-run; $SPRT settles only
## by 14-day season, tokenomics v1.0) and the online
## rivals/season block (no online system in this build).
# P5-only gold material; no global chip/flat_box behaviour changes.
func _p5_gold_pill(height: int = 60) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	# Match the old flat-box cap radius at each authored height.
	var image := UiTheme.asset("textures", "pill_gold").get_image()
	image.resize(height * 4, height, Image.INTERPOLATE_LANCZOS)
	box.texture = ImageTexture.create_from_image(image)
	box.texture_margin_left = minf(height * 0.5, 29.0)
	box.texture_margin_right = minf(height * 0.5, 29.0)
	box.texture_margin_top = 0
	box.texture_margin_bottom = 0
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box

func _fill_result(victory: bool, score: float, dust: int) -> void:
	_result_title.text = "★ 全区通关！★" if victory else "你倒下了…"
	_result_body.text = "到达第 %d 关 · %s · 击杀 %d · 用时 %s · 总伤害 %d" % [
		zone, String(ZONES[zone - 1]["cn"]), kills, _fmt_time(run_time), int(damage_dealt)]
	for c in _result_box.get_children():
		(c as Node).queue_free()
	if _p5_on and _result_core != null:
		for c in _result_core.get_children():
			(c as Node).queue_free()
	# U5: three gold stars for a full clear, two + one empty on
	# defeat (reference victory shows three gold stars; the stars
	# were previously fixed at two filled + one empty in both).
	for i in _result_stars.size():
		var st := _result_stars[i] as TextureRect
		if st != null:
			st.texture = UiTheme.asset("decorations", ("p5_" if _p5_on else "") + ("star_filled" if (victory or i < 2) else "star_empty"))
	# Approved U5: four readable summary rows before extended statistics.
	# On phone the rows + payout live in _result_core (always
	# visible); on desktop they stay in the scroll as approved.
	var core_box := _result_core if (_p5_on and _result_core != null) else _result_box
	for data in [["tile_clock", "用时", _fmt_time(run_time)], ["tile_sword", "击杀", str(kills)], ["tile_star", "等级", str(player.level if player else 1)], ["tile_coin", "金币", str(int(gold))]]:
		var plate := PanelContainer.new()
		var row_style: StyleBox = UiTheme.panel_texture(14)
		if _p5_on:
			var face := UiTheme.flat_box(Color8(253, 246, 219) if core_box.get_child_count() % 2 == 0 else Color8(252, 244, 215), 0)
			face.border_color = Color8(246, 229, 179)
			face.border_width_bottom = 1
			face.content_margin_left = 3
			face.content_margin_right = 3
			row_style = face
		if _p5_on:
			# Keep the accepted pitch and value-pill right edge intact.
			row_style.content_margin_top = 1
			row_style.content_margin_bottom = 1
			plate.custom_minimum_size.y = 66.3
		plate.add_theme_stylebox_override("panel", row_style)
		core_box.add_child(plate)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		plate.add_child(row)
		if _p5_on:
			# Frame-relative left edge, including both phone aspect ratios.
			# The value pill remains anchored by its existing trailing inset.
			var lead := Control.new()
			lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lead)
			var place_lead := func() -> void:
				var sx := row.get_global_transform().get_scale().x
				lead.custom_minimum_size.x = maxf(0, (get_viewport().get_visible_rect().size.x * 0.3044 - row.global_position.x) / sx - 14)
			row.resized.connect(place_lead)
			place_lead.call_deferred()
		var tile := UiBadge.new(String(data[0]), UiTheme.SKY, 40)
		if _p5_on:
			# Stretch the complete tile and its glyph to the reference rectangle.
			tile.custom_minimum_size = Vector2(96, 61)
			tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tile)
		# The current phone fit floor is 23, so 31 (not authored 24)
		# yields the requested ~1.34x glyph height after fitting.
		if _p5_on:
			var label_gap := Control.new()
			label_gap.custom_minimum_size.x = 4
			label_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(label_gap)
		var label := _mk_label(row, String(data[1]), 31 if _p5_on else 18, UiTheme.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# U5 re-audit #2: 185 design px is ~11.3% of the 2340-wide
		# capture at x1.5 / modal scale 0.952; preserve 32 px digits.
		var value := UiTheme.chip(String(data[2]), Color8(252, 232, 159) if _p5_on else UiTheme.GOLD.lightened(0.65), 32 if _p5_on else 22, UiTheme.TEXT, 185 if _p5_on else 160)
		if _p5_on:
			value.custom_minimum_size.y = 45
			value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Keep the authored height independent of chip content padding.
			var vsb := _p5_gold_pill(45)
			vsb.content_margin_left = 8
			vsb.content_margin_right = 8
			value.add_theme_stylebox_override("panel", vsb)
		row.add_child(value)
		if _p5_on:
			# U5 re-audit #2: trailing space + HBox separation = 138
			# design px, bringing pill right to ~65.7% of the frame.
			var value_inset := Control.new()
			value_inset.custom_minimum_size.x = 124
			value_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(value_inset)
	if _p5_on:
		# U5 re-audit 3: scan2 goldblob5 needs +1.1%H (9 design px).
		# Only this gap grows; all four row centres stay fixed.
		var _payout_gap := Control.new()
		_payout_gap.custom_minimum_size = Vector2(0, 17.8)
		_payout_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core_box.add_child(_payout_gap)
	# Payout pill (reference: one pale pill, three segments).
	var payout := PanelContainer.new()
	# U5 fix5: same slim margin as the rows on P5 (-12 px live min).
	# U5 fix8: 8 -> 3, matching the rows (see above).
	payout.add_theme_stylebox_override("panel", UiTheme.panel_texture(3 if _p5_on else 14))
	if _p5_on:
		# U5 fix11: reference payout pill is pale gold (252,230,154),
		# the same gold as the value pills -- not the cream 9-patch
		# (ours rendered 248,235,212, near-invisible against the
		# panel). Flat capsule, no border, mirroring the value pills.
		# P5 only: desktop keeps the legacy 9-patch pill.
		payout.add_theme_stylebox_override("panel",
			_p5_gold_pill())
	if _p5_on:
		# U5 re-audit #6: 60 * 0.952 = 57.1 logical px (~8%H).
		payout.custom_minimum_size.y = 60
	if _p5_on:
		# Inset only the payout: 34 design px is ~2.1%W per side
		# at the phone fit scale. Keep its height and row centres fixed.
		var payout_inset := MarginContainer.new()
		payout_inset.add_theme_constant_override("margin_left", 34)
		payout_inset.add_theme_constant_override("margin_right", 34)
		core_box.add_child(payout_inset)
		payout_inset.add_child(payout)
	else:
		core_box.add_child(payout)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	payout.add_child(prow)
	if _p5_on:
		# Three equal sections keep the larger glyphs at the pill's left
		# and the coin section, independently of the changing result values.
		var payout_bold := FontVariation.new()
		payout_bold.base_font = load("res://assets/fonts/NotoSC-Black-sub.ttf")
		var pad := Control.new()
		pad.custom_minimum_size.x = 0
		prow.add_child(pad)
		for part in range(3):
			var segment := HBoxContainer.new()
			segment.add_theme_constant_override("separation", 8)
			segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			segment.alignment = BoxContainer.ALIGNMENT_BEGIN if part == 0 else BoxContainer.ALIGNMENT_CENTER
			if part == 2:
				segment.alignment = BoxContainer.ALIGNMENT_END
			prow.add_child(segment)
			if part == 0:
				segment.add_child(UiIcon.new("result_spark", Color(0.62, 0.35, 0.95), 40))
			elif part == 1:
				var coins := UiIcon.new("result_coins", UiTheme.GOLD, 48)
				coins.custom_minimum_size = Vector2(46, 61)
				segment.add_child(coins)
			var text: String = ["星尘 +%d" % dust, "金币 %d" % int(gold), "得分 %s" % str(score)][part]
			var caption := _mk_label(segment, text, 32, UiTheme.TEXT)
			caption.add_theme_font_override("font", payout_bold)
			if part < 2:
				# 以居中 2px 精致竖线替代粗重黑字竖杠，贴合定稿汇总条比例
				var sep_wrap := CenterContainer.new()
				sep_wrap.custom_minimum_size = Vector2(8, 36)
				sep_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var sep_bar := ColorRect.new()
				sep_bar.custom_minimum_size = Vector2(2, 28)
				sep_bar.color = Color("8a7035")
				sep_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sep_wrap.add_child(sep_bar)
				prow.add_child(sep_wrap)
	else:
		prow.add_child(UiIcon.new("spark", Color(0.62, 0.35, 0.95), 24))
		_mk_label(prow, "星尘 +%d" % dust, 32 if _p5_on else 18, UiTheme.TEXT)
		_mk_label(prow, "|", 32 if _p5_on else 18, UiTheme.MUTED)
		prow.add_child(UiBadge.new("tile_coin", UiTheme.GOLD, 24))
		_mk_label(prow, "金币 %d" % int(gold), 32 if _p5_on else 18, UiTheme.TEXT)
		_mk_label(prow, "|", 32 if _p5_on else 18, UiTheme.MUTED)
		_mk_label(prow, "得分 %s" % str(score), 32 if _p5_on else 18, UiTheme.TEXT)
	if _p5_on:
		# U5 fix6: phone shows the reference card only (rows +
		# payout). The extended statistics lived in the scroll,
		# whose viewport only ever showed a clipped sliver (the
		# stray "0 0 0 0" fact-grid row) plus a scrollbar.
		# Desktop keeps the full sectioned summary in its scroll.
		call_deferred("_size_result_bars")
		return
	# 4-up fact grid.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	_result_box.add_child(grid)
	_result_fact(grid, "守护者", bosses)
	_result_fact(grid, "结伴", captured)
	_result_fact(grid, "元素反应", int(run_counts.get("reactions", 0)))
	_result_fact(grid, "成长", run_evos)
	# Per-move damage bars.
	if not run_move_dmg.is_empty():
		_result_section_title("招式伤害")
		var keys := run_move_dmg.keys()
		keys.sort_custom(func(a: String, b: String) -> bool:
			return float(run_move_dmg[a]) > float(run_move_dmg[b]))
		var mx := 1.0
		for k in keys:
			mx = maxf(mx, float(run_move_dmg[k]))
		for k in keys.slice(0, mini(keys.size(), 8)):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_result_box.add_child(row)
			var nm := "大招" if k == "ult" else ("下砸" if k == "slam" else _move_zh(k))
			if k == "ult" and player and is_instance_valid(player):
				nm = Ult.display_name(player.ult_name)
			var lab := _mk_label(row, nm, 13)
			lab.custom_minimum_size = Vector2(120, 0)
			var track := Panel.new()
			track.custom_minimum_size = Vector2(160 if _p5_on else 300, 12)
			track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			track.add_theme_stylebox_override("panel",
				UiTheme.flat_box(Color(0.08, 0.05, 0.16, 0.9), 6))
			row.add_child(track)
			var fillp := Panel.new()
			fillp.position = Vector2(1, 1)
			fillp.size = Vector2(1, 10)
			fillp.add_theme_stylebox_override("panel",
				UiTheme.flat_box(Color(0.98, 0.6, 0.25), 5))
			fillp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			track.add_child(fillp)
			fillp.set_meta("frac", float(run_move_dmg[k]) / mx)
			_result_bar_fills.append(fillp)
			_mk_label(row, str(int(float(run_move_dmg[k]))), 13, UiTheme.MUTED)
	# Pact chips (blessings taken this run).
	if not run_blessings.is_empty():
		_result_section_title("本局祝福")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_result_box.add_child(flow)
		var seen: Dictionary = {}
		for bname in run_blessings:
			seen[bname] = int(seen.get(bname, 0)) + 1
		for bname in seen.keys():
			var txt := String(bname) + (" ×%d" % int(seen[bname]) if int(seen[bname]) > 1 else "")
			flow.add_child(UiTheme.chip(txt, Color(0.30, 0.20, 0.48, 0.95)))
	# Capture grid.
	if not run_captures.is_empty():
		_result_section_title("本局结伴")
		var flow2 := HFlowContainer.new()
		flow2.add_theme_constant_override("h_separation", 10)
		flow2.add_theme_constant_override("v_separation", 6)
		_result_box.add_child(flow2)
		var counted: Dictionary = {}
		for sp in run_captures:
			counted[sp] = int(counted.get(sp, 0)) + 1
		for sp in counted.keys():
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 1)
			flow2.add_child(cell)
			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(48, 48)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = UiTheme.portrait(sp)
			cell.add_child(tr)
			var cl := _mk_label(cell, String(ModelRig.SPECIES[sp]["label"]), 11, Color.WHITE)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if run_ally_dmg.has(sp):
				var dl := _mk_label(cell, "伤害 %d" % int(float(run_ally_dmg[sp])), 10, UiTheme.MUTED)
				dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Completed-task rows (challenges finished DURING the run).
	var new_done: Array = []
	for sp in GameProfile.challenge_order():
		if GameProfile.challenge_done(sp) and not _snap_done.has(sp):
			new_done.append(sp)
	if not new_done.is_empty():
		_result_section_title("完成的挑战")
		for sp in new_done:
			var row := _mk_label(_result_box, "", 13, Color(0.75, 1, 0.8))
			row.text = "★ %s 挑战完成" % String(ModelRig.SPECIES[sp]["label"])
	# Dex lines (totals + this run's deltas).
	_result_section_title("伙伴册")
	var seen_now := (GameProfile.data.get("seen", []) as Array).size()
	var cap_now := (GameProfile.data.get("captured", {}) as Dictionary).size()
	var league_now := (GameProfile.data.get("league", []) as Array).size()
	_mk_label(_result_box, "已见 %d（+%d） · 已结伴 %d（+%d） · 伙伴营 %d（+%d） · 流光 %d" % [
		seen_now, seen_now - _snap_seen, cap_now, cap_now - _snap_captured,
		league_now, league_now - _snap_league,
		(GameProfile.data.get("shinies", []) as Array).size()], 13, UiTheme.MUTED)
	if _p5_on:
		_p5_wrap_page(_result_box, false)
	# Bar fills size once the panel has laid out.
	call_deferred("_size_result_bars")

var _result_bar_fills: Array = []

func _size_result_bars() -> void:
	for f in _result_bar_fills:
		if is_instance_valid(f):
			var p := (f as Panel).get_parent() as Control
			if p:
				(f as Panel).size.x = maxf((p.size.x - 2.0) * float((f as Panel).get_meta("frac", 0.0)), 1.0)
	_result_bar_fills.clear()

func _result_section_title(t: String) -> void:
	var l := _mk_dlabel(_result_box, t, 16, UiTheme.SKY)
	l.add_theme_color_override("font_color", UiTheme.SKY)

func _result_fact(grid: GridContainer, label: String, value: int) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	grid.add_child(cell)
	var v := _mk_label(cell, str(value), 22, Color.WHITE)
	v.add_theme_font_override("font", UiTheme.display_font())
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l := _mk_label(cell, label, 12, UiTheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# ---------------------------------------------------------- pause
## The tabbed pause (UI_SPEC §2.9): moves / legend /
## settings pages over the frozen run (state = "pause",
## running = false — the same world-clock channel the
## draft modal uses). Settings opens as the pause's
## sub-page (the bundle embeds the settings inline; ours
## swaps panels and returns, named).
func _build_pause(root: Control) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -390
	_pause_panel.offset_right = 390
	_pause_panel.offset_top = -270
	_pause_panel.offset_bottom = 270
	_pause_panel.visible = false
	_pause_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	_mk_dlabel(head, "暂停", 26, UiTheme.SKY)
	_pause_sub = _mk_label(head, "", 14, UiTheme.MUTED)
	# UI-mobile P1.5 (plan §B3 M5): "状态" replaces "招式" —
	# the one-tap home for everything the phone HUD will
	# collapse (power chips, every move, vitamins, held
	# items, party, the run block); the moves list is its
	# second section.
	var seg := UiTheme.make_segmented(["状态", "图例", "设置"], 0)
	for b in seg.get_children():
		var bb := b as Button
		bb.pressed.connect(func() -> void:
			audio.click()
			_pause_show_tab(int(bb.get_meta("seg_i"))))
	_pause_panel.set_meta("seg", seg)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _p5_on:
		# UI-mobile P5 (plan §B3 M5): the tabs sit in a left
		# column (the left thumb's side), the page fills the rest;
		# the panel is a fixed 430 tall (M0). The group stays a
		# row — make_segmented returns an HBoxContainer (its
		# orientation is fixed; set_segmented and the P1 gate
		# both take that type).
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 12)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(body)
		seg.add_theme_constant_override("separation", 8)
		seg.custom_minimum_size = Vector2(120, 0)
		seg.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body.add_child(seg)
		scroll.custom_minimum_size = Vector2(0, 0)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
	else:
		vb.add_child(seg)
		vb.add_child(scroll)
	var moves_box := VBoxContainer.new()
	moves_box.add_theme_constant_override("separation", 6)
	moves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(moves_box)
	_pause_moves_box = moves_box
	_pause_pages["status"] = moves_box
	var legend_box := VBoxContainer.new()
	legend_box.add_theme_constant_override("separation", 6)
	legend_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_box.visible = false
	scroll.add_child(legend_box)
	_pause_pages["legend"] = legend_box
	_pause_fill_legend(legend_box)
	var set_box := VBoxContainer.new()
	set_box.add_theme_constant_override("separation", 6)
	set_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_box.visible = false
	scroll.add_child(set_box)
	_pause_pages["settings"] = set_box
	# UI-mobile P1.5: the quick-toggle row (filled on show
	# so it mirrors Profile) — the aim toggle's future home
	# (plan D2) — above the full settings entry.
	var quick := VBoxContainer.new()
	quick.name = "QuickRow"
	quick.add_theme_constant_override("separation", 6)
	set_box.add_child(quick)
	var openb := UiTheme.make_button("全部设置", "blue", "normal")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			openb.add_theme_color_override(st, Color.WHITE)
		openb.add_theme_color_override("font_outline_color", Color("13548c"))
		openb.add_theme_constant_override("outline_size", 3)
	openb.pressed.connect(func() -> void:
		audio.click()
		_pause_panel.visible = false
		_settings_return = "pause"
		_sound_panel.visible = true
		_settings_show_tab(_settings_tab_now))
	set_box.add_child(openb)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	var resume := UiTheme.make_button("继续", "green", "big")
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			resume.add_theme_color_override(st, Color.WHITE)
		resume.add_theme_color_override("font_outline_color", Color("326b08"))
		resume.add_theme_constant_override("outline_size", 4)
	resume.pressed.connect(func() -> void:
		audio.click()
		_close_pause())
	var quit := UiTheme.make_button("回主菜单", "ghost", "big")
	# UI-mobile P1.5: two-step armed confirm (the account
	# reset's pattern) — one stray tap no longer throws the
	# run away.
	quit.pressed.connect(_pause_quit_press)
	_pause_quit_btn = quit
	if _p5_on:
		# Plan §B3 M5 / M0: the primary (继续, big green) bottom-
		# right under the right thumb; the destructive action
		# (回主菜单, ghost, still two-step) top-left by the title.
		var fsp := Control.new()
		fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(fsp)
		resume.size_flags_horizontal = Control.SIZE_SHRINK_END
		resume.custom_minimum_size.x = 260
		resume.set_meta("p5_primary", true)
		foot.add_child(resume)
		quit.add_theme_font_size_override("font_size", 16)
		head.add_child(quit)
		head.move_child(quit, 1)
		_pause_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pause_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pause_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		foot.add_child(resume)
		foot.add_child(quit)

func _pause_quit_press() -> void:
	audio.click()
	var now := Time.get_ticks_msec()
	if _pause_quit_armed_ms >= 0 and now - _pause_quit_armed_ms <= 3000:
		get_tree().reload_current_scene()
		return
	_pause_quit_armed_ms = now
	_pause_quit_btn.text = "再点一次回主菜单（3 秒）"
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if _pause_quit_armed_ms == now:
			_pause_quit_disarm())

func _pause_quit_disarm() -> void:
	_pause_quit_armed_ms = -1
	if _pause_quit_btn:
		_pause_quit_btn.text = "回主菜单"

func _pause_show_tab(i: int) -> void:
	var names := ["status", "legend", "settings"]
	for n in names:
		(_pause_pages[n] as Control).visible = n == names[i]
	var seg := _pause_panel.get_meta("seg") as HBoxContainer
	if seg:
		UiTheme.set_segmented(seg, i)
		# 对齐定稿 S08/S18/S19：暂停页选中页签使用蓝胶囊配白字
		for b in seg.get_children():
			var bb := b as Button
			var sel := int(bb.get_meta("seg_i", -1)) == i
			UiTheme.retint_button(bb, "blue" if sel else "ghost")
			bb.add_theme_color_override("font_color", Color.WHITE if sel else UiTheme.TEXT)
			bb.add_theme_color_override("font_hover_color", Color.WHITE if sel else UiTheme.TEXT)
			bb.add_theme_color_override("font_pressed_color", Color.WHITE if sel else UiTheme.TEXT)
	if names[i] == "status":
		_pause_fill_status()
	elif names[i] == "settings":
		_pause_fill_quick()

## UI-mobile P1.5: the quick toggles (rebuilt on show so a
## change made in the full settings is reflected).
func _pause_fill_quick() -> void:
	var quick := (_pause_pages["settings"] as Control).find_child("QuickRow", false, false) as VBoxContainer
	if quick == null:
		return
	for c in quick.get_children():
		quick.remove_child(c)
		c.queue_free()
	_st_switch(quick, "镜头辅助（瞄准）", "camAssist",
		func() -> void:
			if touch_controls:
				touch_controls.set_aim_state(bool(GameProfile.setting("camAssist"))))
	# U1 1:1 round 10 (main-controller ruling): the target-lock
	# button left the combat HUD — its home is this quick row.
	# The lock itself is live state (player.lock_target), not a
	# Profile setting, so the switch is built by hand: it shows
	# the live state on every rebuild and re-syncs its visual
	# to the live state after each press (a press with no enemy
	# in range leaves it off, honestly).
	var lock_hb := _st_row(quick, "锁定目标")
	var lock_sw := UiTheme.make_switch(player != null and is_instance_valid(player) and player.lock_target != null and is_instance_valid(player.lock_target), 0.62 if _p5_on else 1.0)
	lock_sw.pressed.connect(func() -> void:
		audio.click()
		_toggle_target_lock()
		UiTheme.set_switch(lock_sw, player != null and is_instance_valid(player) and player.lock_target != null and is_instance_valid(player.lock_target)))
	lock_hb.add_child(lock_sw)
	_st_switch(quick, "固定摇杆", "fixedStick",
		func() -> void:
			if touch_controls:
				touch_controls.fixed_stick = bool(GameProfile.setting("fixedStick")))
	_st_switch(quick, "大招自动释放", "autoUlt")
	_st_slider(quick, "触控按钮大小", "touchScale", 0.7, 1.5, 0.05, "%.2f",
		func() -> void:
			if touch_controls:
				touch_controls.apply_scale(float(GameProfile.setting("touchScale"))))

## UI-mobile P1.5 (plan §B4 P1.5): the pause "状态" page —
## the one-tap home for the values the phone HUD collapses
## in P2/P3. Sections: power (the SAME _pw_defs the HUD row
## renders), moves + ult (the old moves page), vitamins,
## held items, party, the run block.
func _pause_fill_status() -> void:
	for c in _pause_moves_box.get_children():
		_pause_moves_box.remove_child(c)
		(c as Node).queue_free()
	if player == null or not is_instance_valid(player):
		return
	var box := _pause_moves_box
	# 1. 战力
	_mk_sky_banner(box, "战力", 16, false)
	var pw := HFlowContainer.new()
	pw.name = "PwChips"
	pw.add_theme_constant_override("h_separation", 6)
	pw.add_theme_constant_override("v_separation", 4)
	box.add_child(pw)
	for d in _pw_defs():
		pw.add_child(UiTheme.chip(String(d[0]),
			Color("f7dc94") if bool(d[1]) else Color("efe3c8"), 13, UiTheme.TEXT))
	# 2. 招式 (the former moves page)
	_mk_sky_banner(box, "招式", 16, false)
	for m in player.moves:
		var md: Dictionary = GameData.move(String(m["key"]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_pause_moves_box.add_child(row)
		var t := String(md.get("type", "normal"))
		var ic := UiBadge.new(_move_icon(t), UiTheme.type_color(t), 22)
		ic.custom_minimum_size = Vector2(22, 22)
		row.add_child(ic)
		_mk_label(row, "%s %d级" % [_move_zh(String(m["key"])), int(m["level"])], 15)
		row.add_child(UiTheme.chip(String((TYPE_HUD.get(t, [t]) as Array)[0]),
			Color(UiTheme.type_color(t), 0.85), 11))
		var pwv2 = md.get("power", 0)
		_mk_label(row, "威力 %d · %s" % [int(pwv2) if pwv2 != null else 0,
			"物理" if String(md.get("category", "")) == "physical" else "特殊"], 12, UiTheme.MUTED)
	# The ult line (its charge lives on the gauge; the pause
	# lists what it will do).
	_mk_label(_pause_moves_box, "大招：%s（充能 %.0f%%）" % [
		Ult.display_name(player.ult_name), (ult.charge * 100.0 if ult else 0.0)], 13, Color("a35e08") if _p5_on else UiTheme.GOLD)
	# 3. 维生素 (the draft buildMini's vitamin chips)
	_mk_sky_banner(box, "维生素", 16, false)
	if player.vit_levels.is_empty():
		_mk_label(box, "（无）", 13, UiTheme.MUTED)
	else:
		var vf := HFlowContainer.new()
		vf.add_theme_constant_override("h_separation", 6)
		vf.add_theme_constant_override("v_separation", 4)
		box.add_child(vf)
		for vk in player.vit_levels.keys():
			vf.add_child(UiTheme.chip("%s %d级" % [
				String(GameData.VITAMINS[vk]["label"]), int(player.vit_levels[vk])],
				Color8(106, 90, 168), 13))
	# 4. 物品 (held items — before this page the meowth
	# shop's sell row was the only in-run view of them)
	_mk_sky_banner(box, "物品", 16, false)
	var ikeys: Array = player.items.keys()
	ikeys.sort()
	if ikeys.is_empty():
		_mk_label(box, "（无）", 13, UiTheme.MUTED)
	for ik in ikeys:
		var key := String(ik)
		var irow := HBoxContainer.new()
		irow.add_theme_constant_override("separation", 8)
		box.add_child(irow)
		irow.add_child(_item_icon_rect(key, 26.0))
		_mk_label(irow, "%s ×%d" % [String(GameData.item_def(key).get("name", key)),
			int(player.items[ik])], 15)
		_mk_label(irow, _item_label(key), 12, UiTheme.MUTED)
	# 5. 队伍 (same source as the HUD party row)
	_mk_sky_banner(box, "队伍", 16, false)
	var allies := get_tree().get_nodes_in_group("allies")
	if allies.is_empty():
		_mk_label(box, "（无）", 13, UiTheme.MUTED)
	for a in allies:
		var e := a as Enemy
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 8)
		box.add_child(prow)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(30, 30)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = UiTheme.portrait(e.species_id)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prow.add_child(tr)
		_mk_label(prow, "%s · 生命 %d/%d" % [String(ModelRig.SPECIES[e.species_id]["label"]),
			int(ceil(e.hp)), int(ceil(e.max_hp))], 14)
	# 6. 本局 (the top card's collapsible values: EN zone
	# name, tier, stopwatch, stardust — plus gold / kills /
	# roars)
	_mk_sky_banner(box, "本局", 16, false)
	var zrow: Dictionary = ZONES[zone - 1]
	# UI-mobile P2: the phone hero plate keeps only the CN
	# name (H4) and shows the evo line near evolving only
	# (H6); the weather chip is icon + 1 char (T6) — the
	# full values live here.
	var hinfo: Dictionary = _hud_info_for(String(player.species_id))
	for line in [
			"伙伴：%s %s · %s" % [String(hinfo["name"]), String(hinfo["en"]),
				String(hinfo["evo"]).trim_prefix("› ")],
			_weather_explain(),
			"区域：%s %s · 第 %d/%d 区" % [String(zrow["cn"]), String(zrow["en"]), zone, ZONES.size()],
			"难度：普通",
			"用时：%s" % _fmt_elapsed(elapsed),
			"萤尘：%d" % GameProfile.stardust(),
			"金币：%d" % int(gold),
			"击杀：%d" % kills,
			"咆哮 ×%d" % run_roars]:
		_mk_label(box, String(line), 14)
	if _p5_on:
		_p5_wrap_page(box)

## UI-mobile P5 (plan §B3 "钱包 / Lab / 商店 / 解锁: 套 M0；关闭在
## 右下"): the overlay's list scroll takes the fixed panel
## height left over, and its close button goes bottom-right
## as the primary.
func _p5_overlay(scroll: ScrollContainer, closeb: Button) -> void:
	if not _p5_on:
		return
	if scroll:
		scroll.custom_minimum_size = Vector2(0, 0)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if closeb:
		closeb.size_flags_horizontal = Control.SIZE_SHRINK_END
		closeb.custom_minimum_size.x = 180
		closeb.set_meta("p5_primary", true)

## UI-mobile P5: one card's width in a phone card row — the
## plan's card width, or the share of the modal's flowing
## width when n cards would not fit (16:9 with four).
func _p5_card_w(panel: Control, n: int, want: float) -> float:
	var w := _p5_w(panel, 860.0) - 32.0
	n = maxi(n, 1)
	return floorf(minf(want, (w - 10.0 * float(n - 1)) / float(n)))

## UI-mobile P5: a phone page's free text wraps to the page
## width instead of widening the modal (a row's last label
## takes the leftover width and wraps).
func _p5_wrap_page(box: Control, rows: bool = true) -> void:
	for c in box.get_children():
		if c is Label:
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif rows and c is HBoxContainer and c.get_child_count() > 0:
			var last := c.get_child(c.get_child_count() - 1)
			if last is Label:
				(last as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(last as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _pause_fill_legend(box: VBoxContainer) -> void:
	_mk_sky_banner(box, "地图图例", 16, false)
	# Ring colors from the bundle's marker table (gR @2093942).
	var rows := [["守护者", Color("ff2a4a")], ["头领", Color("ff8a2a")],
		["可结伴目标", Color("5af0ff")], ["宝藏", Color("ffc83a")],
		["祭坛 / 图腾", Color("c25aff")], ["队友", Color("3ac85a")],
		["玩家标记（大地图）", UiTheme.PIN]]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		box.add_child(hb)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.add_theme_stylebox_override("panel", UiTheme.flat_box(r[1], 7))
		hb.add_child(dot)
		_mk_label(hb, String(r[0]), 14)
	_mk_sky_banner(box, "稀有度", 16, false)
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 6)
	box.add_child(rb)
	for i in range(4):
		rb.add_child(UiTheme.chip(["普通", "稀有", "史诗", "传说"][i],
			Color(UiTheme.rarity_color(i), 0.85)))

## Cycle 19 (audit punch #13): a kbd cap naming a tool
## button's key (the bundle's ez caps, @1999261).
func _kbd_cap(b: Button, key_text: String) -> void:
	var k := UiTheme.kbd(key_text)
	k.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	k.offset_left = -24
	k.offset_right = -3
	k.offset_top = -7
	k.offset_bottom = 13
	b.add_child(k)
	# UI-mobile P1.1: caps hide on touch (_touch_text_sync).
	k.visible = not _touch_wanted()
	_kbd_caps.append(k)

## Cycle 19 (audit punch #13): "Ver mi equipo" (Yk
## @1552417) — the pause moves page as a peek over the
## draft/blessing modal: the modal hides while peeking
## and returns on close, the world frozen throughout.
func _open_team_view() -> void:
	if state not in ["draft", "blessing"]:
		return
	_pause_peek_return = state
	if state == "draft":
		_draft_panel.visible = false
	else:
		_blessing_panel.visible = false
	state = "pause"
	_pause_sub.text = "%s · 第 %d 区 · %s" % [
		String(ZONES[zone - 1]["cn"]), zone, _fmt_time(run_time)]
	_pause_panel.visible = true
	_pause_show_tab(0)
	_apply_ui_scale()

func _open_pause() -> void:
	if state not in ["playing", "guardian", "portal"]:
		return
	_pre_pause_state = state
	state = "pause"
	running = false
	_pause_quit_disarm()
	_pause_sub.text = "%s · 第 %d 区 · %s" % [
		String(ZONES[zone - 1]["cn"]), zone, _fmt_time(run_time)]
	_pause_panel.visible = true
	_pause_show_tab(0)
	_apply_ui_scale()

func _close_pause() -> void:
	if state != "pause":
		return
	_pause_quit_disarm()
	_pause_panel.visible = false
	if _unlock_from_pause:
		_unlock_from_pause = false
		_unlock_panel.visible = false
	if _pause_peek_return != "":
		# Cycle 19: back to the modal that opened the peek.
		state = _pause_peek_return
		_pause_peek_return = ""
		running = false
		if state == "draft":
			_draft_panel.visible = true
		elif state == "blessing":
			_blessing_panel.visible = true
		return
	state = _pre_pause_state
	running = true

# ---------------------------------------------------------- big map
## The big-map modal (UI_SPEC §4.2): opened by clicking the
## minimap; fog = visited ground only (48x48 cells over the
## +-170 u zone, objectives stay visible); up to 3 pins,
## click to place, click a pin to remove it.
func _build_bigmap(root: Control) -> void:
	_bigmap_panel = PanelContainer.new()
	_bigmap_panel.set_anchors_preset(Control.PRESET_CENTER)
	var side := 590.0  # min(vh*.82, vw*.9) at 1280x720
	_bigmap_panel.offset_left = -(side + 190.0) * 0.5
	_bigmap_panel.offset_right = (side + 190.0) * 0.5
	_bigmap_panel.offset_top = -side * 0.5 - 10.0
	_bigmap_panel.offset_bottom = side * 0.5 + 10.0
	_bigmap_panel.visible = false
	_bigmap_panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	root.add_child(_bigmap_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_bigmap_panel.add_child(hb)
	# UI-mobile P5 (plan §B3 M6): a 398 map (the 430 design
	# height less the panel margins) on the left, the side
	# column takes the flowing width, 关闭 bottom-right.
	# 对齐定稿 S15_v1.jpg：宽阔大地图＋亮天蓝胶囊「大地图」标题＋浅金「已探索 %」胶囊＋亮绿白字关闭钮
	if _p5_on:
		side = 402.0
	_bigmap = BigMap.new()
	_bigmap.world = self
	_bigmap.custom_minimum_size = Vector2(side, side)
	hb.add_child(_bigmap)
	if _p5_on:
		_bigmap.custom_minimum_size = Vector2(side, side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_box.custom_minimum_size = Vector2(210 if _p5_on else 178, 0)
	hb.add_child(side_box)
	if _p5_on:
		var map_cap := PanelContainer.new()
		map_cap.add_theme_stylebox_override("panel", UiTheme._btn_box(UiTheme.SKY, 18, Color(0, 0, 0, 0.15), 1, 14))
		var mt := _mk_label(map_cap, "大地图", 22, Color.WHITE, true)
		mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mt.add_theme_color_override("font_shadow_color", Color("14548a"))
		mt.add_theme_constant_override("shadow_offset_y", 2)
		mt.add_theme_color_override("font_outline_color", Color("176098"))
		mt.add_theme_constant_override("outline_size", 1)
		side_box.add_child(map_cap)
	else:
		_mk_dlabel(side_box, "大地图", 20, UiTheme.TEXT)
	var mhint := _mk_label(side_box, "点击地图放置标记（最多 3 个）；点已有标记可删除。", 14 if _p5_on else 11, Color("6e502f"))
	_bigmap_list = VBoxContainer.new()
	_bigmap_list.add_theme_constant_override("separation", 6)
	side_box.add_child(_bigmap_list)
	var closeb := UiTheme.make_button("关闭", "green", "big" if _p5_on else "normal")
	if _p5_on:
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			closeb.add_theme_color_override(st, Color.WHITE)
		closeb.add_theme_color_override("font_outline_color", Color("326b08"))
		closeb.add_theme_constant_override("outline_size", 4)
	closeb.pressed.connect(func() -> void:
		audio.click()
		_close_big_map())
	if _p5_on:
		side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mhint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var msp := Control.new()
		msp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_box.add_child(msp)
		closeb.size_flags_horizontal = Control.SIZE_SHRINK_END
		closeb.custom_minimum_size.x = 180
		closeb.set_meta("p5_primary", true)
	side_box.add_child(closeb)

func open_big_map() -> void:
	if state not in ["playing", "guardian", "portal"]:
		return
	_pre_bigmap_state = state
	state = "bigmap"
	running = false
	_fog_mark(player.global_position, 18.0)
	_bigmap_panel.visible = true
	_bigmap.queue_redraw()
	_bigmap_refresh_list()
	_apply_ui_scale()

func _close_big_map() -> void:
	if state != "bigmap":
		return
	_bigmap_panel.visible = false
	state = _pre_bigmap_state
	running = true

func _bigmap_click(local: Vector2) -> void:
	if _bigmap == null or _bigmap.size.x <= 0.0:
		return
	var wx := (local.x / _bigmap.size.x - 0.5) * 340.0
	var wz := (local.y / _bigmap.size.y - 0.5) * 340.0
	for i in range(_map_pins.size()):
		var p: Vector3 = _map_pins[i]
		if Vector2(p.x - wx, p.z - wz).length() < 12.0:
			_map_pins.remove_at(i)
			_bigmap.queue_redraw()
			return
	if _map_pins.size() >= 3:
		return
	_map_pins.append(Vector3(wx, height_at(wx, wz), wz))
	audio.click()
	_bigmap.queue_redraw()

func _bigmap_refresh_list() -> void:
	for c in _bigmap_list.get_children():
		(c as Node).queue_free()
	var visited := 0
	for v in _fog:
		if v > 0:
			visited += 1
	var pct := int(round(100.0 * float(visited) / float(maxi(_fog.size(), 1))))
	var exp_pill := PanelContainer.new()
	var e_sb := _style(Color("f7dc92"), 14, Color("dfb458"), 1.5, false)
	e_sb.content_margin_left = 12
	e_sb.content_margin_right = 12
	e_sb.content_margin_top = 4
	e_sb.content_margin_bottom = 4
	exp_pill.add_theme_stylebox_override("panel", e_sb)
	var exp_l := _mk_label(exp_pill, "已探索 %d%%" % pct, 18 if _p5_on else 15, UiTheme.TEXT)
	exp_l.add_theme_font_override("font", UiTheme.display_font())
	exp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bigmap_list.add_child(exp_pill)
	var ist: Dictionary = _inter_state.get(zone, {})
	var rows := [["祭坛", (ist.get("altars", []) as Array).size(), "map_star"],
		["宝箱", chests_positions().size(), "map_chest"],
		["标记", _map_pins.size(), "map_pin_player"]]
	for r in rows:
		_bigmap_legend_row(String(r[2]), "%s · %d" % [String(r[0]), int(r[1])], UiTheme.TEXT)
	if guardian != null and is_instance_valid(guardian) and guardian.hp > 0.0:
		_bigmap_legend_row("event_dot_red", "守护者 · 存活", Color("c4421a"))
	if _shiny_e != null and is_instance_valid(_shiny_e):
		_bigmap_legend_row("event_dot_blue", "流光遭遇 · 出现中", Color("1e6ca8"))
	if _p5_on and _bigmap_panel != null and _bigmap_panel.scale.x > 0.01:
		_p5_fit(_bigmap_panel, float(_bigmap_panel.get_meta("p5_sm", _bigmap_panel.scale.x)))

func _bigmap_legend_row(tex_key: String, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_bigmap_list.add_child(row)
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/badges/%s.png" % tex_key)
	tr.custom_minimum_size = Vector2(16, 16)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tr)
	_mk_label(row, text, 13, color)

func _fog_mark(pos: Vector3, radius: float) -> void:
	if _fog.size() != 48 * 48:
		return
	var cell := 340.0 / 48.0
	var cx := int(floor((pos.x + 170.0) / cell))
	var cz := int(floor((pos.z + 170.0) / cell))
	var cr := int(ceil(radius / cell))
	for gz in range(maxi(cz - cr, 0), mini(cz + cr + 1, 48)):
		for gx in range(maxi(cx - cr, 0), mini(cx + cr + 1, 48)):
			var wx := -170.0 + (float(gx) + 0.5) * cell
			var wz := -170.0 + (float(gz) + 0.5) * cell
			if Vector2(wx - pos.x, wz - pos.z).length() <= radius:
				_fog[gz * 48 + gx] = 1

# ---------------------------------------------------------- target lock
var _lock_ui_state := false

func _toggle_target_lock() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.lock_target != null and is_instance_valid(player.lock_target):
		player.lock_target = null
		spawn_floater(player.global_position + Vector3(0, 2.6, 0), "取消锁定", Color(0.9, 0.9, 0.9))
	else:
		var e := player._nearest_enemy(30.0)
		if e != null:
			player.lock_target = e as Enemy
			spawn_floater(player.global_position + Vector3(0, 2.6, 0),
				"锁定 " + String(ModelRig.SPECIES[player.lock_target.species_id]["label"]),
				Color(0.6, 1, 0.7))
	if touch_controls:
		touch_controls.set_lock_state(player.lock_target != null)


# ---------------------------------------------------------- HUD remainder
## Party row (.party @2002233): one portrait disc + mini HP
## track per ally; rebuilt only when the set/health signature
## changes (the 0.15 s HUD tick drives it).
func _refresh_party() -> void:
	if _party_row == null:
		return
	var allies := get_tree().get_nodes_in_group("allies")
	var parts: Array = []
	for a in allies:
		var e := a as Enemy
		parts.append("%s:%d" % [e.species_id, int(ceil(e.hp))])
	var sig := "|".join(parts)
	if sig == _party_sig:
		return
	_party_sig = sig
	for c in _party_row.get_children():
		(c as Node).queue_free()
	for a in allies:
		var e := a as Enemy
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		_party_row.add_child(cell)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(38, 38)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = UiTheme.portrait(e.species_id)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
		var track := Panel.new()
		track.custom_minimum_size = Vector2(38, 5)
		track.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(0.08, 0.05, 0.16, 0.88), 2))
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(track)
		var fillp := Panel.new()
		fillp.position = Vector2(0, 0)
		fillp.size = Vector2(38.0 * clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0), 5)
		fillp.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(0.48, 1, 0.6), 2))
		fillp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fillp)

## pw-row: live power chips — multipliers + crit from the
## player's recalculated fields (the egg/coin boosts show up
## here the moment they land).
func _refresh_pw_chips() -> void:
	if _pw_row == null or player == null or not is_instance_valid(player):
		return
	var sig := "%.3f|%.3f|%.3f|%.3f|%.3f|%.3f" % [
		player.damage_mult, player.crit_chance, player.atk_speed,
		player.area_mult, player.xp_mult, player.gold_mult]
	if sig == _pw_row.get_meta("sig", ""):
		return
	_pw_row.set_meta("sig", sig)
	_pw_change_toast()
	for c in _pw_row.get_children():
		(c as Node).queue_free()
	for d in _pw_defs():
		_pw_row.add_child(UiTheme.chip(String(d[0]),
			UiTheme.GOLD.lightened(0.65) if bool(d[1]) else UiTheme.CREAM, 11, UiTheme.TEXT))

## UI-mobile P2 (plan H9 / D3): with the pw row collapsed on
## phone, a change to any of the six values flashes one 1.5 s
## toast line ("伤害 ×1.10 ↑"; several changes join). The
## first fill (run start) only records the baseline.
func _pw_change_toast() -> void:
	var vals := [player.damage_mult, player.crit_chance, player.atk_speed,
		player.area_mult, player.xp_mult, player.gold_mult]
	var defs := _pw_defs()
	var cur: Array = []
	for i in range(defs.size()):
		cur.append([String(defs[i][0]), float(vals[i])])
	var parts: Array = []
	if _p2_on == 1 and _pw_last.size() == cur.size():
		for i in range(cur.size()):
			if String(cur[i][0]) != String(_pw_last[i][0]):
				parts.append("%s %s" % [String(cur[i][0]),
					"↑" if float(cur[i][1]) > float(_pw_last[i][1]) else "↓"])
	_pw_last = cur
	if not parts.is_empty():
		show_banner(" · ".join(parts), 1.5)

## UI-mobile P1.5: the six power chips' [text, boosted]
## pairs — ONE source for the HUD row and the pause status
## page (parity by construction).
func _pw_defs() -> Array:
	var defs := [["伤害 ×%.2f", player.damage_mult], ["暴击 %.0f%%", player.crit_chance * 100.0],
		["攻速 ×%.2f", player.atk_speed], ["范围 ×%.2f", player.area_mult],
		["经验 ×%.2f", player.xp_mult], ["金币 ×%.2f", player.gold_mult]]
	var out: Array = []
	for i in range(defs.size()):
		var boosted := (i == 4 and player.xp_mult > 1.01) or (i == 5 and player.gold_mult > 1.01)
		out.append([String(defs[i][0]) % float(defs[i][1]), boosted])
	return out

## Goal card: anatomy per the constructor (portrait, name,
## "n left", progress bar, next line); data = the next
## incomplete League challenge (see the build comment for
## the adaptation note).
func _refresh_goal_card() -> void:
	if _goal_card == null:
		return
	var target := ""
	for key in GameProfile.challenge_order():
		if not GameProfile.challenge_done(key) and not GameProfile.in_league(
				int(GameData.species(key).get("family", 0))):
			target = key
			break
	if target == "":
		_goal_card.visible = false
		_goal_species = ""
		return
	# UI-mobile P3 (plan R3): not resident in the new phone
	# layout — the objective pill / drawer carry it.
	_goal_card.visible = state != "menu" and _p3_on != 1
	if target != _goal_species:
		_goal_species = target
		_goal_pic.texture = UiTheme.portrait(target)
	var parts := GameProfile.challenge_parts(target)
	var first_inc: Dictionary = {}
	var done_parts := 0
	for p in parts:
		if float(p["value"]) >= float(p["goal"]):
			done_parts += 1
		elif first_inc.is_empty():
			first_inc = p
	var label := String(ModelRig.SPECIES[target]["label"])
	if first_inc.is_empty():
		_goal_name.text = "%s · 挑战完成" % label
		_goal_bar_fill.size.x = float(_goal_bar_fill.get_meta("track_w", 158.0))
		_goal_next.text = "等待伙伴营遭遇"
		_goal_count.text = ""
	else:
		var left := int(float(first_inc["goal"]) - float(first_inc["value"]))
		_goal_name.text = "%s · 还差 %d" % [label, left]
		_goal_bar_fill.size.x = maxf(float(_goal_bar_fill.get_meta("track_w", 158.0))
			* clampf(float(first_inc["value"]) / maxf(float(first_inc["goal"]), 1.0), 0.0, 1.0), 1.0)
		# Cycle 21.3 (§5): count in its own label (above).
		_goal_next.text = "%s · 条件 %d/%d" % [
			String(first_inc["desc"]), done_parts + 1, parts.size()]
		_goal_count.text = "%d/%d" % [
			int(float(first_inc["value"])), int(float(first_inc["goal"]))]
	# Hotfix: the goal card's height feeds the pill stack.
	_layout_hud()

## Event pills (UI_SPEC §2.10): glass pill + accent dot +
## bold title + sub, one per ACTIVE event source. Sources
## are this build's live events: comet altar, league
## encounter, swarm, alpha. The bundle's shop pill has no
## counterpart (no in-run shop exists) — omitted, named.
## UI-mobile P3 (plan §B4 P3): the event sources as ONE
## list — [title, sub, colour, key] — shared by the desktop /
## classic pill stack, the phone objective pill and the
## drawer (parity by construction). new_layout = the phone
## ordering (plan priority: timed stage event > shiny /
## league > comet > swarm > alpha > meowth; deterministic)
## with the alpha entry dropped while a mini bar shows the
## alphas (plan R4g -> C2).
func _event_list(new_layout: bool = false) -> Array:
	var evs: Array = []
	# Cycle 21: the active stage event (bundle evpill).
	if _event_kind != "":
		var edef: Dictionary = EVENT_DEFS[_event_kind]
		evs.append([String(edef["name"]), "剩余 %ds" % int(ceil(_event_left)), Color(1, 0.42, 0.35), "event"])
	if not _comet.is_empty() and not bool(_comet.get("used", false)):
		evs.append(["彗星祭坛", "剩余 %ds · 充能 %d%%" % [
			int(float(_comet.get("life", 0.0))),
			int(float(_comet.get("charge", 0.0)))], Color("4aa8ff"), "comet"])
	if _league_e != null and is_instance_valid(_league_e) and _league_e.mode == Enemy.MODE_LEAGUE:
		evs.append(["伙伴营遭遇", "%s · 逃走 %ds" % [
			String(ModelRig.SPECIES[_league_e.species_id]["label"]),
			int(maxf(_league_escape, 0.0))], Color("9a6aff"), "league"])
	if _shiny_e != null and is_instance_valid(_shiny_e):
		evs.append(["流光遭遇", "%s · 逃走 %ds" % [
			String(ModelRig.SPECIES[_shiny_e.species_id]["label"]),
			int(maxf(_shiny_escape, 0.0))], Color("5af0ff"), "shiny"])
	if _swarm:
		evs.append(["虫群", "虫群来袭中", Color("ff4a3a"), "swarm"])
	# Cycle 21: the visiting-Meowth pill (bundle evpill
	# .shop @2002585, "Meowth de visita") — shown while
	# the live zone holds its shopkeeper. UI-mobile plan R4f
	# (CONTEXTUALIZE): the phone layout lists it only while
	# the player is within P3_MEOWTH_NEAR of it — every zone
	# places one, so the zone-wide entry was a permanent
	# drawer row (desktop / classic keep the bundle pill).
	var shop_state: Dictionary = _inter_state.get(zone, {})
	for pr in (shop_state.get("props", []) as Array):
		if String((pr as Dictionary)["kind"]) == "meowth":
			if not new_layout or _p3_meowth_near(pr as Dictionary):
				evs.append(["獾掌柜铺", "本区有獾掌柜铺", Color("ffd23a"), "meowth"])
			break
	var any_alpha := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.flag == 2 and en.hp > 0.0 and en.mode != Enemy.MODE_ALLY and not en.is_downed:
			any_alpha = true
			break
	if any_alpha:
		evs.append(["头领", "头领出没", Color("ff8a2a"), "alpha"])
	if not new_layout:
		return evs
	var bars_up := false
	for bar in _mini_bars:
		if (bar["panel"] as Control).visible:
			bars_up = true
	var out: Array = []
	for k in ["event", "shiny", "league", "comet", "swarm", "alpha", "meowth"]:
		for ev in evs:
			if String(ev[3]) == k and not (k == "alpha" and bars_up):
				out.append(ev)
	return out

## Plan R4f: the shopkeeper's drawer entry radius (world u).
const P3_MEOWTH_NEAR := 30.0

func _p3_meowth_near(pr: Dictionary) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var pp: Vector3 = player.global_position
	return Vector2(pp.x, pp.z).distance_to(Vector2(float(pr["x"]), float(pr["z"]))) <= P3_MEOWTH_NEAR

func _refresh_event_pills() -> void:
	if _pill_box == null:
		return
	if _p3_on == 1:
		_p3_refresh_objective()
		return
	var evs := _event_list(false)
	var sig := ""
	for ev in evs:
		sig += String(ev[0]) + String(ev[1]) + ";"
	if sig == _pill_sig:
		return
	_pill_sig = sig
	for c in _pill_box.get_children():
		(c as Node).queue_free()
	for ev in evs:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.dark_glass(11, 0.92))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill_box.add_child(pill)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 7)
		pill.add_child(hb)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.add_theme_stylebox_override("panel", UiTheme.flat_box(ev[2], 5))
		hb.add_child(dot)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		hb.add_child(vb)
		var tl := _mk_label(vb, String(ev[0]), 13, Color.WHITE, true)
		tl.add_theme_font_override("font", UiTheme.display_font())
		_mk_label(vb, String(ev[1]), 11, UiTheme.HUD_DIM, true)
	# Cycle 21.3: a rebuild replaces every pill node
	# (fresh nodes are visible by default), which would
	# silently undo the layout's info-stack budget shed
	# until the next goal refresh. Re-run the layout in
	# the same tick so the shed is never observably lost.
	_layout_hud()

## The 2 mini boss bars: alphas in latch order, with the
## main bar's lag math (0.45 s hold, 0.6/s drain).
func _update_mini_bars(delta: float) -> void:
	var actives: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.flag == 2 and en.hp > 0.0 and en.mode != Enemy.MODE_ALLY and not en.is_downed:
			actives.append(en)
	for i in range(_mini_bars.size()):
		var bar: Dictionary = _mini_bars[i]
		var target: Enemy = null
		var latched_v = bar["key"]
		var latched: Enemy = latched_v if is_instance_valid(latched_v) else null
		if latched != null and actives.has(latched):
			target = latched
		else:
			for a in actives:
				var used := false
				for j in range(_mini_bars.size()):
					if j != i and _mini_bars[j]["key"] == a:
						used = true
				if not used:
					target = a
					break
		bar["key"] = target
		var panel := bar["panel"] as Panel
		if target == null:
			panel.visible = false
			continue
		panel.visible = state in ["playing", "guardian", "portal"]
		(bar["name"] as Label).text = String(ModelRig.SPECIES[target.species_id]["label"])
		var frac := clampf(target.hp / maxf(target.max_hp, 1.0), 0.0, 1.0)
		var lagv := float(bar["lagv"])
		var hold := float(bar["hold"])
		if frac >= lagv:
			lagv = frac
			hold = 0.45
		else:
			hold -= delta
			if hold <= 0.0:
				lagv = maxf(frac, lagv - delta * 0.6)
		bar["lagv"] = lagv
		bar["hold"] = hold
		(bar["fill"] as Panel).size.x = 278.0 * frac
		(bar["lag"] as Panel).size.x = 278.0 * lagv
		(bar["num"] as Label).text = str(int(maxf(target.hp, 0.0)))
		# UI-mobile P3 (plan R4g): past two alphas the second
		# bar names the rest ("+N") — the alpha pill is gone.
		if i == 1 and _p3_on == 1 and actives.size() > 2:
			(bar["name"] as Label).text += " +%d" % (actives.size() - 2)

# ---------------------------------------------------------- loadout
## The pre-run screen (UI_SPEC §2.2 region select + the
## Mochila boost row, main @1880600): hero detail, a 6-slot
## team bar (slot 0 = the starting hero; tap a bench member
## to swap it in — drag-reorder is replaced by tap-to-swap,
## named), the species tile grid with lock progress, and
## the bag-boost toggles capped by GameProfile.bag_slots().
func _build_loadout(root: Control) -> void:
	_loadout_panel = Control.new()
	_loadout_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loadout_panel.visible = false
	root.add_child(_loadout_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.10, 0.72)
	_loadout_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -545
	panel.offset_right = 545
	panel.offset_top = -318
	panel.offset_bottom = 318
	panel.add_theme_stylebox_override("panel", UiTheme.panel_texture())
	_loadout_panel.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var dscroll := ScrollContainer.new()
	dscroll.custom_minimum_size = Vector2(330, 0)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(dscroll)
	if _p5_on:
		# UI-mobile P5 (plan §B3 G12): the loadout is a full-
		# screen page (M0 W flows to the safe area, H 440): the
		# detail column takes 38 %, the right side 62 %.
		dscroll.custom_minimum_size = Vector2(0, 0)
		dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dscroll.size_flags_stretch_ratio = 38.0
	_ls_detail = VBoxContainer.new()
	_ls_detail.add_theme_constant_override("separation", 6)
	_ls_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_ls_detail)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	if _p5_on:
		right.size_flags_stretch_ratio = 62.0
		_ls_team_hint = _mk_label(right, "队伍（点队友可换为出战）", 11, UiTheme.MUTED)
	_ls_team = HBoxContainer.new()
	_ls_team.add_theme_constant_override("separation", 6)
	right.add_child(_ls_team)
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(0, 300)
	gscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gscroll)
	if _p5_on:
		gscroll.custom_minimum_size = Vector2(0, 0)
		gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ls_grid = GridContainer.new()
	_ls_grid.columns = 6
	_ls_grid.add_theme_constant_override("h_separation", 6)
	_ls_grid.add_theme_constant_override("v_separation", 6)
	_ls_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gscroll.add_child(_ls_grid)
	_ls_bagrow = HBoxContainer.new()
	_ls_bagrow.add_theme_constant_override("separation", 6)
	if _p5_on:
		# The bag toggles scroll sideways in one row.
		var bsc := ScrollContainer.new()
		bsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(bsc)
		bsc.add_child(_ls_bagrow)
	else:
		right.add_child(_ls_bagrow)
	_ls_cap_label = _mk_label(right, "", 12, UiTheme.MUTED)
	# Cycle 19: archive presets row (bundle UP mounted on
	# the pre-run screen @1880686; empty until unlocked).
	_ls_archive_row = HBoxContainer.new()
	_ls_archive_row.add_theme_constant_override("separation", 6)
	right.add_child(_ls_archive_row)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	right.add_child(brow)
	var back := UiTheme.make_button("返回", "ghost", "big")
	back.pressed.connect(func() -> void:
		audio.click()
		_loadout_panel.visible = false)
	brow.add_child(back)
	if _p5_on:
		# Plan §B3 G12: [返回] left, [开始 · X] bottom-right.
		var bsp := Control.new()
		bsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(bsp)
	_ls_start_btn = UiTheme.make_button("开始", "green", "big")
	_ls_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _p5_on:
		_ls_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		_ls_start_btn.custom_minimum_size.x = 240
		_ls_start_btn.set_meta("p5_primary", true)
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			_ls_start_btn.add_theme_color_override(st, Color.WHITE)
		_ls_start_btn.add_theme_color_override("font_outline_color", Color("326b08"))
		_ls_start_btn.add_theme_constant_override("outline_size", 4)
	_ls_start_btn.pressed.connect(func() -> void:
		audio.click()
		_loadout_start())
	brow.add_child(_ls_start_btn)

func _ls_playable(sp: String) -> bool:
	if STARTER_HUD.has(sp):
		return true
	return GameProfile.in_league(int(GameData.species(sp).get("family", 0)))

func _open_loadout(sp: String) -> void:
	_ls_species = sp
	if _ls_playable(sp):
		_ls_hero = sp
	_ls_boosts.clear()
	_loadout_panel.visible = true
	_loadout_refresh()
	_apply_ui_scale()

## Cycle 19: archive presets on the pre-run screen (the
## bundle mounts UP beside the start controls @1880686 and
## it renders nothing until the archive upgrade exists).
func _loadout_fill_archive() -> void:
	if _ls_archive_row == null:
		return
	for c in _ls_archive_row.get_children():
		c.queue_free()
	if GameProfile.archive_capacity() <= 0:
		return
	_mk_label(_ls_archive_row, "档案预设", 12, UiTheme.MUTED)
	var presets := GameProfile.archive_presets()
	if presets.is_empty():
		_mk_label(_ls_archive_row, "（在研究室 · 物品档案中保存）", 12, UiTheme.MUTED)
		return
	for i in range(presets.size()):
		var idx := i
		var b := UiTheme.make_button(String((presets[i] as Dictionary).get("name", "预设")), "ghost", "small")
		b.disabled = GameProfile.archive_preset_active() == i
		if b.disabled:
			b.text += "（使用中）"
		b.pressed.connect(func() -> void:
			GameProfile.archive_preset_apply(idx)
			audio.click()
			_loadout_fill_archive())
		_ls_archive_row.add_child(b)

func _loadout_refresh() -> void:
	_loadout_fill_detail()
	_loadout_fill_team()
	_loadout_fill_grid()
	_loadout_fill_bag()
	_loadout_fill_archive()
	var info := _hud_info_for(_ls_hero)
	_ls_start_btn.text = "开始 · %s" % String(info["name"])

func _loadout_fill_detail() -> void:
	for c in _ls_detail.get_children():
		(c as Node).queue_free()
	var sp := _ls_species
	var sd: Dictionary = GameData.species(sp)
	var info := _hud_info_for(sp)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(110, 110)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = UiTheme.portrait(sp)
	_ls_detail.add_child(tr)
	var nm := _mk_dlabel(_ls_detail, String(info["name"]), 22, UiTheme.TEXT)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 5)
	_ls_detail.add_child(chips)
	for t in sd.get("types", []):
		chips.add_child(UiTheme.chip(String((TYPE_HUD.get(String(t), [String(t)]) as Array)[0]),
			Color(UiTheme.type_color(String(t)), 0.85), 11))
	var rentry := GameData.roster_for_species(sp)
	if not rentry.is_empty():
		# Rank arrives as an EN slug — localize (audit §7 class).
		var rank_zh: String = String({"common": "普通", "uncommon": "优秀", "rare": "稀有",
			"epic": "史诗", "legendary": "传说"}.get(String(rentry.get("rank", "")), ""))
		if rank_zh != "":
			chips.add_child(UiTheme.chip("伙伴册 · " + rank_zh, Color(0.16, 0.13, 0.30, 0.95), 11))
	# Base stats with bars (frac of 180). The species dict
	# keys them "stats" (the starter cards read the same).
	var base: Dictionary = sd.get("stats", {})
	for row in [["hp", "体力"], ["atk", "攻击"], ["def", "防御"],
			["spa", "特攻"], ["spd", "特防"], ["spe", "速度"]]:
		var v := int(base.get(String(row[0]), 0))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		_ls_detail.add_child(hb)
		var lab := _mk_label(hb, String(row[1]), 12, UiTheme.MUTED)
		lab.custom_minimum_size = Vector2(34, 0)
		var track := Panel.new()
		track.custom_minimum_size = Vector2(150, 9)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(0.08, 0.05, 0.16, 0.9), 4))
		hb.add_child(track)
		var fillp := Panel.new()
		fillp.position = Vector2(1, 1)
		fillp.size = Vector2(1, 7)
		fillp.add_theme_stylebox_override("panel",
			UiTheme.flat_box(Color(0.45, 0.85, 0.55), 3))
		fillp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fillp)
		fillp.set_meta("frac", clampf(float(v) / 180.0, 0.0, 1.0))
		_ls_detail_fills.append(fillp)
		var num_l := _mk_label(hb, str(v), 12)
		num_l.custom_minimum_size = Vector2(28, 0)
	# Passive — rendered MECHANICALLY in CN: abilities.json
	# carries the bundle's ES flavor name/desc verbatim, and
	# surfacing that prose would leak unlocalized original
	# copy (audit §7 class — and the reskin line says the
	# original's prose is not ours to ship). The mods/hooks
	# ARE the effect; render those.
	var pid := GameData.passive_for_species(sp)
	if pid != "":
		var pe := GameData.passive_entry(pid)
		var stat_zh := {"maxHp": "生命", "damage": "伤害", "physical": "物理",
			"special": "特殊", "armor": "护甲", "critChance": "暴击率",
			"critDamage": "暴伤", "attackSpeed": "攻速", "area": "范围",
			"projSpeed": "弹速", "projectiles": "弹射物", "moveSpeed": "移速",
			"lifesteal": "吸血", "regen": "回复", "healing": "治疗",
			"shieldMax": "护盾", "evasion": "闪避", "gold": "金币",
			"xpGain": "经验", "luck": "幸运", "pickupRange": "拾取范围",
			"statusChance": "状态概率", "eliteDamage": "精英伤害",
			"flinch": "硬直", "extraJumps": "额外跳跃"}
		var parts: Array = []
		for m in pe.get("mods", []):
			var md2: Dictionary = m
			var pct := int(round((float(md2.get("mul", 1.0)) - 1.0) * 100.0))
			parts.append("%s %+d%%" % [String(stat_zh.get(String(md2.get("stat", "")), String(md2.get("stat", "")))), pct])
		var hooks: Dictionary = pe.get("hooks", {})
		if not hooks.is_empty():
			parts.append("触发效果 ×%d" % hooks.size())
		_mk_label(_ls_detail, "特性：%s" % (" · ".join(parts) if not parts.is_empty() else "触发型"), 13, Color("a35e08") if _p5_on else UiTheme.GOLD)
	# Kit moves.
	_mk_sky_banner(_ls_detail, "初始招式", 15, false)
	for mk in GameData.kit(sp):
		var md: Dictionary = GameData.move(String(mk))
		var pwv = md.get("power", 0)
		_mk_label(_ls_detail, "%s · %s · 威力 %d" % [
			_move_zh(String(mk)),
			String((TYPE_HUD.get(String(md.get("type", "")), [String(md.get("type", ""))]) as Array)[0]),
			int(pwv) if pwv != null else 0], 12)
	# Matchups.
	_mk_sky_banner(_ls_detail, "相性", 15, false)
	var weak: Array = []
	var resist: Array = []
	var immune: Array = []
	for t in TYPE_HUD.keys():
		var m := GameData.type_mult(String(t), sd.get("types", []))
		var zh := String((TYPE_HUD[t] as Array)[0])
		var ms := "×%d" % int(m) if m == floor(m) else "×%.2f" % m
		if m == 0.0:
			immune.append(zh)
		elif m > 1.0:
			weak.append(zh + " " + ms)
		elif m < 1.0:
			resist.append(zh + " " + ms)
	if not weak.is_empty():
		_mk_label(_ls_detail, "弱点：" + " · ".join(weak), 11, Color("b84432") if _p5_on else Color(1, 0.65, 0.55))
	if not resist.is_empty():
		_mk_label(_ls_detail, "抗性：" + " · ".join(resist), 11, Color("2e7d32") if _p5_on else Color(0.65, 0.95, 0.7))
	if not immune.is_empty():
		_mk_label(_ls_detail, "免疫：" + " · ".join(immune), 11, UiTheme.MUTED)
	# Evolution chain (walk the family's evo targets).
	var chain: Array = [sp]
	var cur := sp
	var chain_cut := ""
	while true:
		var nxd := GameData.evo_target(cur)
		if nxd.is_empty():
			break
		var nx := String(nxd.get("key", ""))
		if nx == "" or chain.has(nx):
			break
		if not ModelRig.SPECIES.has(nx):
			chain_cut = nx  # unmodelled form: the chain stops here (player.gd guard)
			break
		chain.append(nx)
		cur = nx
	if chain.size() > 1 or chain_cut != "":
		_mk_sky_banner(_ls_detail, "成长", 15, false)
		var evo_txt: Array = []
		for i in range(chain.size()):
			var seg := String(ModelRig.SPECIES[chain[i]]["label"])
			if i > 0:
				seg = "Lv.%d → %s" % [GameData.evo_level_for(chain[i - 1]), seg]
			evo_txt.append(seg)
		if chain_cut != "":
			evo_txt.append("Lv.%d → %s（未建模）" % [
				GameData.evo_level_for(chain[chain.size() - 1]), chain_cut])
		var el := _mk_label(_ls_detail, " → ".join(evo_txt), 12)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Ult list (DEFS covers families 1/4/7 in this build).
	_mk_sky_banner(_ls_detail, "大招", 15, false)
	var fam := int(sd.get("family", 0))
	if Ult.DEFS.has(fam):
		var names: Array = (Ult.DEFS[fam] as Dictionary)["names"]
		for i in range(names.size()):
			_mk_label(_ls_detail, "%s（%d 阶）" % [String(names[i]), i + 1], 12, Color("a35e08") if _p5_on else UiTheme.GOLD)
	else:
		_mk_label(_ls_detail, "大招数据未建模（本构建仅三条初始线有专属大招）", 11, UiTheme.MUTED)
	# Lock progress for unplayable species.
	if not _ls_playable(sp):
		_mk_dlabel(_ls_detail, "解锁条件（伙伴营挑战）", 15, Color("c45424") if _p5_on else Color(1, 0.7, 0.5))
		for p in GameProfile.challenge_parts(sp):
			var pd2 := p as Dictionary
			_mk_label(_ls_detail, "%s：%d / %d%s" % [
				String(pd2["desc"]), int(float(pd2["value"])), int(float(pd2["goal"])),
				"（系统未实装）" if bool(pd2.get("unsupported", false)) else ""], 12, UiTheme.MUTED)
	if _p5_on:
		var pad_bot := Control.new()
		pad_bot.custom_minimum_size.y = 8
		_ls_detail.add_child(pad_bot)
		_p5_wrap_page(_ls_detail, false)
	call_deferred("_size_ls_fills")

var _ls_detail_fills: Array = []
var _ls_size_retries := 0

## The fills live inside a ScrollContainer: on the deferred
## call the layout may not have settled (parent width 0),
## which left the bars at 1 px in the first ui18 shots.
## Re-defer until the tracks have real width (bounded).
func _size_ls_fills() -> void:
	var pending := false
	for f in _ls_detail_fills:
		if is_instance_valid(f):
			var p := (f as Panel).get_parent() as Control
			if p:
				if p.size.x <= 2.0:
					pending = true
				else:
					(f as Panel).size.x = maxf((p.size.x - 2.0) * float((f as Panel).get_meta("frac", 0.0)), 1.0)
	if pending and _ls_size_retries < 30:
		_ls_size_retries += 1
		call_deferred("_size_ls_fills")
	else:
		_ls_detail_fills.clear()
		_ls_size_retries = 0

func _loadout_fill_team() -> void:
	for c in _ls_team.get_children():
		(c as Node).queue_free()
	var bench: Array = []
	for fam in GameProfile.data.get("league", []):
		for k in GameData.roster_species_keys():
			var sd: Dictionary = GameData.species(k)
			if int(sd.get("family", 0)) == int(fam) and int(sd.get("id", 0)) == int(fam):
				bench.append(k)
				break
	for i in range(6):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.focus_mode = Control.FOCUS_NONE
		var sp := ""
		if i == 0:
			sp = _ls_hero
		elif i - 1 < bench.size():
			sp = String(bench[i - 1])
		if sp != "":
			slot.icon = UiTheme.portrait(sp)
			slot.expand_icon = true
			slot.tooltip_text = String(ModelRig.SPECIES[sp]["label"])
			var captured2: String = sp
			slot.pressed.connect(func() -> void:
				audio.click()
				_ls_species = captured2
				if _ls_playable(captured2):
					_ls_hero = captured2
				_loadout_refresh())
		else:
			slot.text = "·"
			slot.disabled = true
		slot.add_theme_stylebox_override("normal", UiTheme.card_box(
			UiTheme.GOLD if i == 0 else Color(1, 1, 1, 0.25), false))
		_ls_team.add_child(slot)
	if not _p5_on:
		_mk_label(_ls_team, "队伍（点队友可换为出战）", 11, UiTheme.MUTED)

func _loadout_fill_grid() -> void:
	for c in _ls_grid.get_children():
		(c as Node).queue_free()
	# UI-mobile P5 (plan §B3 G12): columns = floor(right width /
	# 120), 112 x 112 tiles whose portrait is fitted INSIDE the
	# tile (the shipped icon tiles overflowed — audit §5).
	if _p5_on:
		var lw := _p5_w(_ls_grid.get_parent().get_parent().get_parent().get_parent() as Control, 985.0)
		var rw := (lw - 32.0 - 14.0) * 0.62 - 14.0
		_ls_grid.columns = maxi(1, int(floor(rw / 108.0)))
	for sp in GameData.roster_species_keys():
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(96, 104)
		tile.focus_mode = Control.FOCUS_NONE
		var playable := _ls_playable(sp)
		var tname := String(ModelRig.SPECIES[sp]["label"]) if playable \
			else "锁 · " + String(ModelRig.SPECIES[sp]["label"])
		if _p5_on:
			# 调优每格为 100 高，确保两整行（206px）完全露在可视区内不再被底部截断名字；锁定角标挂在头像子节点下以保持单 TextureRect 测试断言
			tile.custom_minimum_size = Vector2(102, 100)
			var ptr := TextureRect.new()
			ptr.texture = UiTheme.portrait(sp)
			ptr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ptr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ptr.position = Vector2(15, 5)
			ptr.size = Vector2(72, 64)
			ptr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not playable:
				ptr.modulate = Color(0.68, 0.72, 0.80, 0.75)
				var lk_badge := UiBadge.new("lab_locked", UiTheme.MUTED, 22)
				lk_badge.position = Vector2(46, 40)
				ptr.add_child(lk_badge)
			tile.add_child(ptr)
			var tl := _mk_label(tile, tname, 12, Color("6d6255") if not playable else UiTheme.TEXT)
			tl.position = Vector2(4, 70)
			tl.size = Vector2(94, 26)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tl.clip_text = true
			tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			tile.icon = UiTheme.portrait(sp)
			tile.expand_icon = true
			tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			tile.text = tname
		tile.add_theme_font_override("font", UiTheme.body_font())
		tile.add_theme_font_size_override("font_size", 12)
		tile.add_theme_color_override("font_color", UiTheme.TEXT if _p5_on else Color.WHITE)
		var accent := UiTheme.GOLD if sp == _ls_hero else (
			Color(0.5, 0.55, 0.7) if not playable else Color(1, 1, 1, 0.3))
		if _p5_on and not playable:
			var lsb := _style(Color("eae4d6"), 16, Color("c8bda8"), 1.5, false)
			tile.add_theme_stylebox_override("normal", lsb)
			tile.add_theme_stylebox_override("hover", _style(Color("f0ebdf"), 16, Color("b4a68e"), 1.5, false))
		else:
			tile.add_theme_stylebox_override("normal", UiTheme.card_box(accent, false))
			tile.add_theme_stylebox_override("hover", UiTheme.card_box(accent, true))
		if not playable and not _p5_on:
			tile.modulate = Color(0.62, 0.62, 0.68)
		var captured3: String = sp
		tile.pressed.connect(func() -> void:
			audio.click()
			audio.cry(captured3)
			_ls_species = captured3
			if _ls_playable(captured3):
				_ls_hero = captured3
			_loadout_refresh())
		_ls_grid.add_child(tile)

const LS_ITEM_ICONS := {"rare-candy": "candy", "lucky-egg": "egg",
	"amulet-coin": "coin", "honey": "drop", "shiny-stone": "spark",
	"master-ball": "ball"}

func _loadout_fill_bag() -> void:
	for c in _ls_bagrow.get_children():
		(c as Node).queue_free()
	var cap := GameProfile.bag_slots()
	_ls_cap_label.text = "背包带入 %d/%d（开局时消耗 · 研究室可扩到 3）" % [_ls_boosts.size(), cap]
	for it in GameProfile.SHOP_ITEMS:
		var id := String(it["id"])
		var n := GameProfile.bag_count(id)
		if n <= 0:
			continue
		var b := UiTheme.make_icon_button(String(LS_ITEM_ICONS.get(id, "bag")),
			"%s ×%d" % [String(it["name"]), n],
			"green" if _ls_boosts.has(id) else "ghost", "small")
		var captured4: String = id
		b.pressed.connect(func() -> void:
			audio.click()
			_loadout_toggle_boost(captured4))
		_ls_bagrow.add_child(b)

func _loadout_toggle_boost(id: String) -> void:
	if _ls_boosts.has(id):
		_ls_boosts.erase(id)
	elif _ls_boosts.size() >= GameProfile.bag_slots():
		_ls_cap_label.text = "背包带入已满（%d 件）" % GameProfile.bag_slots()
		_ls_cap_label.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
		return
	else:
		_ls_boosts.append(id)
	_loadout_fill_bag()

func _loadout_start() -> void:
	_loadout_panel.visible = false
	start_game(_ls_hero, _ls_boosts.duplicate())

# C24: Classic is an independent collection and encounter, not a Liga capture.
# Original @1051478 excludes families already covered by classics (pack prose inverted).
func _classic_pool(pool: Array) -> Array:
	var out: Array = []
	var covered := GameProfile.classic_covered_members()
	for key in pool:
		var sp: Dictionary = GameData.species(String(key))
		var missing := false
		for member in GameProfile.classic_members(String(key)):
			if not covered.has(member):
				missing = true
		if not bool(sp.get("legendary", false)) and not bool(sp.get("mythical", false)) \
				and ModelRig.SPECIES.has(String(key)) and missing:
			out.append(String(key))
	return out

func _classic_chance(luck: float) -> float:
	return (.025 + minf(.025, luck / 3000.0)) * GameProfile.shiny_rate()

func _roll_classic_director() -> void:
	_classic_at = INF
	_classic_e = null
	if not _classic_pool(ZONES[zone - 1]["pool"]).is_empty() and _rng.randf() < _classic_chance(player.luck if player else 0.0):
		_classic_at = elapsed + _rng.randf_range(60.0, 420.0)

func _spawn_classic() -> void:
	if is_instance_valid(_league_e) or is_instance_valid(_shiny_e) or is_instance_valid(_classic_e):
		return
	var pool := _classic_pool(ZONES[zone - 1]["pool"])
	if pool.is_empty():
		return
	# Every pool family is fresh here; shared picker therefore uses only Cx weights.
	var sp := _pick_shiny_species(pool, false)
	var e := _spawn_enemy_at(sp, _ring_pos(18.0, 32.0), _spawn_mult() * 2.5, false)
	e.classic = true
	e.mode = Enemy.MODE_LEAGUE
	if e.rig:
		e.rig.apply_shiny()  # Documented 3D equivalent; no PMD atlas in this port.
	_classic_e = e
	_classic_escape = GameProfile.shiny_flee_time()
	GameProfile.mark_seen(sp)
	audio.cry(sp)
	show_banner("经典流光 %s 出现了！打弱后邀伴结伴" % String(ModelRig.SPECIES[sp]["label"]), 4.0)

func _make_shiny_ally(e: Enemy) -> void:
	e.make_ally()
	e.is_weakened = false
	e.weak_t = 0.0
	e.status_t = 0.0
	e.status_kind = ""
	e.shiny = true
	e.classic = false
	e.bond_level = 2 if GameProfile.shiny_bond_unlocked() else 0
	e.ally_slot = 10 + _shiny_serial % 100
	_shiny_serial += 1

func _offer_shiny_ally(e: Enemy) -> void:
	_make_shiny_ally(e)
	if not is_instance_valid(_shiny_ally):
		_shiny_ally = e
		return
	_pending_shiny_ally = e
	e.remove_from_group("allies")
	e.set_physics_process(false)
	e.visible = false
	_choice_show("流光队友", "只能带一只流光队友；替换后旧队友回到森林", ["留下新队友", "放生新队友"], "放生新队友",
		func(i: int) -> void: _settle_shiny_swap(i == 0), func() -> void: _settle_shiny_swap(false))

func _settle_shiny_swap(keep: bool) -> void:
	if not is_instance_valid(_pending_shiny_ally):
		return
	if keep:
		if is_instance_valid(_shiny_ally):
			_shiny_ally.remove_from_group("allies")
			_shiny_ally.queue_free()
		_shiny_ally = _pending_shiny_ally
		_shiny_ally.add_to_group("allies")
		_shiny_ally.set_physics_process(true)
		_shiny_ally.visible = true
	else:
		_pending_shiny_ally.queue_free()
	_pending_shiny_ally = null

func _skin_unlock_note(species_key: String) -> String:
	var family := int(GameData.species(species_key).get("family", -1))
	return "家族流光皮肤已解锁" if GameProfile.in_league(family) else "家族加入伙伴营后可使用此流光皮肤"

# Original capture update @1047800+: idle/done gates BEFORE consuming clocks.
# Resolve only one encounter per tick: shiny, Classic, then Liga.
func _tick_capture_director() -> void:
	if is_instance_valid(_league_e) or is_instance_valid(_shiny_e) or is_instance_valid(_classic_e):
		return
	if not _shiny_spawned and _shiny_at > 0.0 and elapsed >= _shiny_at:
		_shiny_spawned = true
		_shiny_at = INF
		_spawn_shiny()
	elif elapsed >= _classic_at:
		_classic_at = INF
		_spawn_classic()
	elif not _league_done and elapsed >= tier_timeline_time(_league_spawn_at):
		_spawn_league()

# The original's team getter excludes shiny allies (@519492): independent extra slot.
func _normal_ally_count() -> int:
	var count := 0
	for ally in get_tree().get_nodes_in_group("allies"):
		if not ally.shiny:
			count += 1
	return count

func _menu_feature_portrait(sp: String) -> Texture2D:
	if _p5_on:
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://assets/menu/u2-art-mascot.png")
		portrait.region = Rect2(89, 91, 947, 1109)
		return portrait
	if sp == "bulbasaur":
		return load("res://assets/menu/fern-hero.png")
	return _menu_card_portrait(sp)


func _menu_card_portrait(sp: String) -> Texture2D:
	match sp:
		"bulbasaur": return load("res://assets/menu/v2-starter-stump.svg")
		"charmander": return load("res://assets/menu/v2-starter-coal.svg")
		"squirtle": return load("res://assets/menu/v2-starter-shell.svg")
	return UiTheme.portrait(sp)
