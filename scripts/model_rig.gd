class_name ModelRig
extends Node3D
## Wraps a raw GLB model: auto-fits it to a target height, grounds it, and animates it.
## - Species with real skeletal clips (Bulbasaur) get clip playback (idle/walk/fight).
## - Others get procedural motion (bob / rock / lunge) — logged in README as a known gap.

const SPECIES := {
	"bulbasaur": {"path": "res://assets/models/bulbasaur_anim.glb", "height": 1.3, "yaw": 0.0, "native": 0.833, "feet": -0.03, "label": "妙蛙种子"},
	"charmander": {"path": "res://assets/models/charmander.glb", "height": 1.3, "native": 1.5616, "feet": -0.0737, "yaw": 0.0, "label": "小火龙"},
	"squirtle": {"path": "res://assets/models/squirtle.glb", "height": 1.06, "native": 1.1348, "feet": -0.0217, "yaw": 0.0, "label": "杰尼龟"},
	"rattata": {"path": "res://assets/models/rattata.glb", "height": 1.0, "native": 0.8641, "feet": -0.0737, "yaw": 0.0, "label": "小拉达"},
	"pidgey": {"path": "res://assets/models/pidgey.glb", "height": 1.24, "native": 0.76, "feet": -0.0217, "yaw": 0.0, "label": "波波"},
	"sandshrew": {"path": "res://assets/models/sandshrew.glb", "height": 1.24, "native": 1.5616, "feet": -0.0529, "yaw": 0.0, "label": "穿山鼠"},
	"geodude": {"path": "res://assets/models/geodude.glb", "height": 0.89, "native": 1.1348, "feet": 0.02, "yaw": 0.0, "label": "小拳石", "pose_arms_down": 65.0, "tint": Color(1.12, 1.05, 0.98)},
	"scyther": {"path": "res://assets/models/scyther.glb", "height": 1.65, "native": 4.4246, "feet": -0.1258, "yaw": 0.0, "label": "飞天螳螂", "pose_arms_down": 65.0},
	"pinsir": {"path": "res://assets/models/pinsir.glb", "height": 1.59, "native": 3.6855, "feet": -0.0425, "yaw": 0.0, "label": "凯罗斯", "pose_arms_down": 40.0},
	"nidoking": {"path": "res://assets/models/nidoking.glb", "height": 1.71, "native": 4.5183, "feet": -0.2715, "yaw": 0.0, "label": "尼多王", "pose_arms_down": 40.0},
	"snorlax": {"path": "res://assets/models/snorlax.glb", "height": 2.12, "native": 20.85, "feet": -0.34, "yaw": 0.0, "label": "卡比兽"},
	# Cycle 7: starter evolutions, alpha evo-forms, zone 2-4 species.
	# Heights INFERRED (scaled to the existing roster's sprite-fh ratios);
	# same GLB source repo as the original 11.
	"ivysaur": {"path": "res://assets/models/ivysaur.glb", "height": 1.5, "native": 3.3315, "feet": -0.0945, "yaw": 0.0, "label": "妙蛙草"},
	"venusaur": {"path": "res://assets/models/venusaur.glb", "height": 1.9, "native": 5.0389, "feet": -0.2819, "yaw": 0.0, "label": "妙蛙花"},
	"charmeleon": {"path": "res://assets/models/charmeleon.glb", "height": 1.5, "native": 2.9671, "feet": -1.4167, "yaw": 0.0, "label": "火恐龙"},
	"charizard": {"path": "res://assets/models/charizard.glb", "height": 1.85, "native": 4.6953, "feet": -1.7082, "yaw": 0.0, "label": "喷火龙"},
	"wartortle": {"path": "res://assets/models/wartortle.glb", "height": 1.35, "native": 3.3315, "feet": -0.6984, "yaw": 0.0, "label": "卡咪龟"},
	"blastoise": {"path": "res://assets/models/blastoise.glb", "height": 1.8, "native": 4.0811, "feet": -0.1362, "yaw": 0.0, "label": "水箭龟"},
	"pidgeotto": {"path": "res://assets/models/pidgeotto.glb", "height": 1.4, "native": 3.3107, "feet": -0.1466, "yaw": 0.0, "label": "比比鸟"},
	"raticate": {"path": "res://assets/models/raticate.glb", "height": 1.05, "native": 1.9781, "feet": -0.1154, "yaw": 0.0, "label": "拉达"},
	"sandslash": {"path": "res://assets/models/sandslash.glb", "height": 1.35, "native": 2.6652, "feet": -0.0529, "yaw": 0.0, "label": "穿山王"},
	"graveler": {"path": "res://assets/models/graveler.glb", "height": 1.15, "native": 2.6027, "feet": -0.0633, "yaw": 0.0, "label": "隆隆石", "pose_arms_down": 50.0},
	"gastly": {"path": "res://assets/models/gastly.glb", "height": 1.3, "native": 1.8323, "feet": 0.1865, "yaw": 0.0, "label": "鬼斯", "hover": 0.35},
	"haunter": {"path": "res://assets/models/haunter.glb", "height": 1.5, "native": 3.2898, "feet": -0.3444, "yaw": 0.0, "label": "鬼斯通"},
	"gengar": {"path": "res://assets/models/gengar.glb", "height": 1.6, "native": 3.7687, "feet": 0.0096, "yaw": 0.0, "label": "耿鬼"},
	"cubone": {"path": "res://assets/models/cubone.glb", "height": 0.85, "native": 1.0411, "feet": -0.0113, "yaw": 0.0, "label": "卡拉卡拉"},
	"marowak": {"path": "res://assets/models/marowak.glb", "height": 1.35, "native": 2.5715, "feet": -0.0217, "yaw": 0.0, "label": "嘎啦嘎啦"},
	"zubat": {"path": "res://assets/models/zubat.glb", "height": 0.9, "native": 1.4888, "feet": -1.1669, "yaw": 0.0, "label": "超音蝠", "hover": 0.55},
	"diglett": {"path": "res://assets/models/diglett.glb", "height": 0.6, "native": 0.5726, "feet": -0.0529, "yaw": 0.0, "label": "地鼠"},
	"dugtrio": {"path": "res://assets/models/dugtrio.glb", "height": 0.95, "native": 1.9885, "feet": -0.2195, "yaw": 0.0, "label": "三地鼠"},
	"rhyhorn": {"path": "res://assets/models/rhyhorn.glb", "height": 1.3, "native": 117.5, "feet": -11.96, "yaw": 0.0, "label": "独角犀牛"},
	"growlithe": {"path": "res://assets/models/growlithe.glb", "height": 1.0, "native": 2.1238, "feet": -0.0321, "yaw": 0.0, "label": "卡蒂狗"},
	"arcanine": {"path": "res://assets/models/arcanine.glb", "height": 1.9, "native": 5.81, "feet": -0.27, "yaw": 0.0, "label": "风速狗"},
	"ponyta": {"path": "res://assets/models/ponyta.glb", "height": 1.25, "native": 3.3003, "feet": -0.1154, "yaw": 0.0, "label": "小火马"},
	"magmar": {"path": "res://assets/models/magmar.glb", "height": 1.5, "native": 155.51, "feet": -14.16, "yaw": 0.0, "label": "鸭嘴火兽"},
	"dragonite": {"path": "res://assets/models/dragonite.glb", "height": 2.0, "native": 2.3216, "feet": -0.0633, "yaw": 0.0, "label": "快龙"},
	# Cycle 9: twenty new League-encounter species (audit §5 — the
	# league-size goals need >= 30 completable families; these are
	# the roster families whose challenges run on counters this
	# build actually tracks). Heights = sprite idle fh / 32, the
	# anchor the original base forms cluster on. native/feet are
	# probe-measured (Test/probe.tscn), replacing the placeholders
	# the day they were added.
	"caterpie": {"path": "res://assets/models/caterpie.glb", "height": 1.0, "native": 0.7184, "feet": -0.3548, "yaw": 0.0, "label": "绿毛虫", "gait": "quad"},
	"weedle": {"path": "res://assets/models/weedle.glb", "height": 1.25, "native": 0.6559, "feet": -0.2507, "yaw": 0.0, "label": "独角虫", "gait": "quad"},
	"spearow": {"path": "res://assets/models/spearow.glb", "height": 1.25, "native": 0.7704, "feet": 0.0096, "yaw": 0.0, "label": "烈雀", "gait": "hopper"},
	"nidoran-f": {"path": "res://assets/models/nidoran-f.glb", "height": 1.25, "native": 1.0515, "feet": -0.0113, "yaw": 0.0, "label": "尼多兰", "gait": "quad"},
	"vulpix": {"path": "res://assets/models/vulpix.glb", "height": 1.0, "native": 1.5096, "feet": -0.0425, "yaw": 0.0, "label": "六尾", "gait": "quad"},
	"jigglypuff": {"path": "res://assets/models/jigglypuff.glb", "height": 1.0, "native": 1.4575, "feet": -0.0321, "yaw": 0.0, "label": "胖丁", "gait": "hopper"},
	"oddish": {"path": "res://assets/models/oddish.glb", "height": 1.25, "native": 1.291, "feet": -0.0217, "yaw": 0.0, "label": "走路草", "gait": "biped"},
	"paras": {"path": "res://assets/models/paras.glb", "height": 0.75, "native": 0.8953, "feet": -0.105, "yaw": 0.0, "label": "派拉斯", "gait": "quad"},
	"venonat": {"path": "res://assets/models/venonat.glb", "height": 1.25, "native": 4.435, "feet": -0.1258, "yaw": 0.0, "label": "毛球", "gait": "biped"},
	"meowth": {"path": "res://assets/models/meowth.glb", "height": 1.0, "native": 1.1348, "feet": -0.0321, "yaw": 0.0, "label": "獾掌柜", "gait": "quad"},
	"mankey": {"path": "res://assets/models/mankey.glb", "height": 1.75, "native": 1.4367, "feet": -0.1154, "yaw": 0.0, "label": "猴怪", "gait": "biped"},
	"poliwag": {"path": "res://assets/models/poliwag.glb", "height": 1.5, "native": 0.6038, "feet": -0.0217, "yaw": 0.0, "label": "蚊香蝌蚪", "gait": "hover"},
	"abra": {"path": "res://assets/models/abra.glb", "height": 1.5, "native": 2.3945, "feet": -0.0841, "yaw": 0.0, "label": "凯西", "gait": "biped"},
	"machop": {"path": "res://assets/models/machop.glb", "height": 1.25, "native": 2.0301, "feet": -0.0425, "yaw": 0.0, "label": "腕力", "gait": "biped"},
	"tentacool": {"path": "res://assets/models/tentacool.glb", "height": 1.5, "native": 2.3216, "feet": -0.0321, "yaw": 0.0, "label": "玛瑙水母", "gait": "hover"},
	"slowpoke": {"path": "res://assets/models/slowpoke.glb", "height": 1.0, "native": 1.9989, "feet": -0.1882, "yaw": 0.0, "label": "呆呆兽", "gait": "quad"},
	"doduo": {"path": "res://assets/models/doduo.glb", "height": 1.25, "native": 3.8416, "feet": -0.105, "yaw": 0.0, "label": "嘟嘟", "gait": "biped"},
	"farfetchd": {"path": "res://assets/models/farfetchd.glb", "height": 1.0, "native": 2.0405, "feet": -0.0633, "yaw": 0.0, "label": "大葱鸭", "gait": "hopper"},
	"magikarp": {"path": "res://assets/models/magikarp.glb", "height": 1.0, "native": 2.0197, "feet": 0.0408, "yaw": 0.0, "label": "鲤鱼王", "gait": "hopper"},
	# Cycle 21: ekans joins via the geometry-space fit (the
	# GLB's bind geometry lies along Z, head at +Z per the
	# vertex-density bins in Test/geo_probe.gd; the idle
	# pose stands it upright like a cobra). span/center are
	# the node-chain AABB at scale 1 (length 4.9725, plan
	# center (0.0957, -0.4367)); feet -3.046 is the POSE's
	# lowest point (the skeleton pivots mid-body: head
	# +1.9 / tail -3.05), probe-measured — Test/
	# analyze_probe.py ekans = OK (h ratio 1.063, ground
	# +0.021). height 2.0 = canonical length (height 20
	# dm). Roster + challenge exist (dex 23: serpent-glare).
	"ekans": {"path": "res://assets/models/ekans.glb", "height": 2.0, "span": 4.9725, "feet": -3.046, "center": Vector2(0.0957, -0.4367), "yaw": 0.0, "label": "阿柏蛇", "gait": "serpent"},
}

var species_id: String = ""
var model: Node3D
var anim_player: AnimationPlayer
var base_pos := Vector3.ZERO
var fitted := false

var _bob_phase := 0.0
var _move_speed := 0.0
var _lunge_t := 0.0
var _cast_t := 0.0  # bundle attackT window (0.3 s) — cast squash pulse
var _ult_pose_t := 0.0  # cycle 13: ultPoseT (.6 s) — the "attack" pose is reserved for ults (@1397186)
var _clip_state := ""
# Combat response (cycle 9, audit §1 — replaces the cycle-8 invented
# flinch/collapse with the original's actual channels, bundle-verified):
# - Hit flash: flash[e] = 1 on damage (strike @727571), decays 6/s
#   (updateProxy @336849), sprite tint lerps toward (1.5, 0.45, 0.4)
#   (@340200). Applied here by modulating the per-rig calibrated
#   material overrides recorded in _calibrate_materials.
# - Squash: squash[e] = 0.6 on enemy hit, 0.5 on player hurt
#   (hurt() @821025), 0.9 on the player's own slam (@829714); decays
#   exp(-10t) (@336849). Rendered as a volume-preserving Y squash.
# - Death: enemies fade out over dying = 0.35 s (w = 1 - dying/0.35,
#   @340280) — no tip-over, no sink. The PLAYER keeps a procedural
#   tip-over collapse (its death ends the run or triggers the Lab
#   revive; the original's player is a sprite with a hurt row, and a
#   readable collapse is our deliberate local choice) — and
#   revive_reset() now restores the rig fully (audit P0: cycle 8
#   latched _faint_t forever, so a revived player stayed collapsed).
var _flash := 0.0
var _squash := 0.0
var _fx_active := false
var _faint_t := -1.0
var _faint_clip := false
var _base_scale := Vector3.ZERO
var is_player := false
var lod_enabled := false
var lod_target: Node3D = null
var _lod_tick := 0
var _gait_accum := 0.0
var _hulls_vis := true
var _flash_mats: Array = []  # [{mat, base: Color}] calibrated overrides
var _hull_mats: Array = []   # outline materials (fade with the corpse)
var _body_meshes: Array = []
var _hull_nodes: Array = []
static var _shared_hull_mat: StandardMaterial3D = null
const FLASH_TINT := Color(1.2, 0.36, 0.30)

# Procedural skeletal gait for clip-less species (DIFF ⚑ #1 local pass):
# the source GLBs ship skeletons with consistent bone names (…LThigh/LLeg/
# LFoot, …LArm/LForeArm, Tail1..4) but no animation clips. We swing the
# leg/arm bones around their local X axis in anti-phase, bend the shins with
# a lag, and wag the tail — driven by actual move speed.
var _skel: Skeleton3D
var _gait_bones := {}  # suffix -> bone index
var _gait_rest := {}  # suffix -> rest rotation (Quaternion)
var _axis_pitch := {} # suffix -> 模型左右(+X)轴折算至该骨骼局部的单位旋转轴（迈步/点头/弯腰）
var _axis_yaw := {}   # suffix -> 模型竖直(+Y)轴折算至该骨骼局部的单位旋转轴（转头/摇尾/扭腰）
var _axis_roll := {}  # suffix -> 模型前后(+Z)轴折算至该骨骼局部的单位旋转轴（展翅/侧倾）
var _target_yaw := 0.0
var _has_facing := false
var _atk_hand := 1.0
# --- Segment Z (de-stiffening): springs, phase-locked stride,
# idle life. See DIFF "Segment Z".
var _gait_kind := ""
var _springs := {}  # suffix -> [x, v] spring-damper state
var _step_squash := 0.0
var _last_sin := 0.0
var _hop_y := 0.0
var _sway_yaw := 0.0
var _breath_t := 0.0
var _head_turn_yaw := 0.0
var _head_turn_next := 3.0
var _head_turn_hold := 0.0
var _prev_rot_y := 0.0
var _bank := 0.0
var _stance_bones: Array = []  # bones held by a global pose override (skip)
var _gait_phase := 0.0
var _gait_amp := 0.0

## Cycle-5 character calibration (DIFF cycle 5, evidence-based):
## the scene light totals ~2.7x (sky ambient 1.05 + sun 1.65) under a LINEAR
## tonemapper, so un-compensated GLB albedos clip: Bulbasaur's bulb texture
## #80c080 rendered #dfffff, body texture #90c0b0 rendered #7df6da (bulb at
## value ~1.0, hue dragged cyan by the blue sky ambient). The terrain palette
## was compensated x0.32 in cycle 2; characters never were. ALBEDO_SCALE is
## that compensation for character materials (calibrated by frame sampling:
## bulb/body medians vs source textures + the original's sprite samples).
const ALBEDO_SCALE := 0.52
## Sprite-palette hue correction per species (albedo multiplier, applied on
## top of ALBEDO_SCALE): the GLB body texture is teal (#90c0b0) while the
## original sprite's body family is yellow-green (#d0f0a0 / #90d060).
const HUE_TINTS := {
	"bulbasaur": Color(1.22, 1.02, 0.62),
	# Hotfix: Charmander's texture orange (224,160,96) rendered as
	# desaturated tan (149,124,95) under the scene's green-bouncing
	# ambient — the user read it as muddy brown. Boost red, cut the
	# green/blue lift so the render lands in the sprite orange family.
	"charmander": Color(1.15, 0.83, 0.70),
}

func setup(p_species: String, scale_mult: float = 1.0) -> void:
	species_id = p_species
	var cfg: Dictionary = SPECIES[p_species]
	var ps: PackedScene = load(cfg["path"])
	model = ps.instantiate()
	add_child(model)
	if cfg.has("rot_x"):
		# Authored-upright models (ekans' GLB is a vertical pole:
		# body length along +Y) get laid flat before fitting; the
		# probe measures the same laid pose (see Test/probe.gd).
		model.rotation.x = float(cfg["rot_x"])
	_calibrate_materials(model, cfg)
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_clip("idle")
	if anim_player == null:
		_collect_gait_bones()
	# Cycle 15: rigs built into a parked (out-of-tree) holder —
	# the cage props inside prebuilt zone scenes — must wait
	# for the tree before the frame awaits, or the coroutine
	# dies on a null get_tree() and the rig never fits. Live
	# rigs are always in-tree, so this is a no-op for them.
	if not is_inside_tree():
		await tree_entered
	# Two frames so the (possibly animated) pose settles before measuring.
	await get_tree().process_frame
	await get_tree().process_frame
	_fit(cfg, scale_mult)
	if anim_player == null:
		_auto_relax_tpose_arms(float(cfg.get("pose_arms_down", 52.0)))
	_add_outlines()

## Character material calibration (cycle 5): multiplies every surface
## albedo by ALBEDO_SCALE (light-exposure compensation), plus the species'
## hue tint and any legacy per-species tint (Geodude) on non-eye materials.
func _calibrate_materials(n: Node, cfg: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue  # authored translucency (gas, membranes) stays untouched
				var nm := sm.resource_name
				var is_eye := "Eye" in nm or "Iris" in nm
				var f := Color(ALBEDO_SCALE, ALBEDO_SCALE, ALBEDO_SCALE)
				if not is_eye:
					if HUE_TINTS.has(species_id):
						var ht: Color = HUE_TINTS[species_id]
						f = Color(f.r * ht.r, f.g * ht.g, f.b * ht.b)
					if cfg.has("tint"):
						var t: Color = cfg["tint"]
						f = Color(f.r * t.r, f.g * t.g, f.b * t.b)
				var dup := sm.duplicate() as StandardMaterial3D
				if dup.albedo_texture:
					dup.albedo_color = Color(dup.albedo_color.r * f.r, dup.albedo_color.g * f.g, dup.albedo_color.b * f.b, dup.albedo_color.a)
				else:
					dup.albedo_color = Color(sm.albedo_color.r * f.r, sm.albedo_color.g * f.g, sm.albedo_color.b * f.b, sm.albedo_color.a)
				mi.set_surface_override_material(i, dup)
				# Cycle 9: the flash/fade channels modulate these
				# per-rig overrides; remember each one's calibrated base.
				_flash_mats.append({"mat": dup, "base": dup.albedo_color})
	for c in n.get_children():
		_calibrate_materials(c, cfg)

## PMD-style dark outline (cycle 5): the original's sprites all carry a
## heavy near-black outline (#000000 is the largest non-grass cluster in
## the sprite crop). Implemented as an inverted hull: a duplicate of each
## mesh instance with an unshaded dark material, front faces culled, and
## the node scaled up slightly about its own origin. Two "proper" routes
## were probe-tested and REJECTED with evidence (screenshots/probe_rig):
## (1) StandardMaterial3D grow_amount — pink hull at grow 0.35 world
## rendered nothing: grow does not displace skinned meshes in this
## Godot 4.3 Compatibility build; (2) ShaderMaterial vertex displacement
## — custom shaders get NO automatic skinning here, the hull exploded
## across the screen. Standard materials DO skin correctly (the un-grown
## hull renders exactly under the body), so the scale-hull it is: rim
## thickness ~7% of distance from the mesh origin — uneven (thicker at
## the head/bulb, zero at the feet) but reads as the sprite outline at
## gameplay distance.
const OUTLINE_SCALE := Vector3(1.07, 1.045, 1.07)
const OUTLINE_COLOR := Color(0.05, 0.08, 0.04)

static var _hull_cache: Dictionary = {}

func _add_outlines() -> void:
	if _shared_hull_mat == null:
		_shared_hull_mat = StandardMaterial3D.new()
		_shared_hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_hull_mat.albedo_color = OUTLINE_COLOR
		_shared_hull_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var meshes: Array = []
	_collect_meshes(model, meshes)
	_body_meshes = meshes
	for mi in meshes:
		var hull := _closed_hull_mesh(mi.mesh)
		if hull == null:
			continue
		var ol := MeshInstance3D.new()
		ol.mesh = hull
		ol.transform = mi.transform
		ol.scale = mi.scale * OUTLINE_SCALE
		ol.skeleton = mi.skeleton
		var skin_res = mi.get("skin")
		if skin_res != null:
			ol.set("skin", skin_res)
		ol.material_override = _shared_hull_mat
		ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.get_parent().add_child(ol)
		_hull_nodes.append(ol)

func set_shadow_casting(on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in _body_meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).cast_shadow = mode

## Hull mesh built from CLOSED surfaces only (cycle 7 fix). An open
## sheet (petal disc, leaf, wing membrane) scaled about the mesh
## origin floats its dark backface over the real sheet and paints it
## black — probe-proven on Venusaur: raw GLB flower pink, rig flower
## black, hull hidden -> pink again (screenshots/c7_probe_venu*.png).
## Closedness = boundary-edge share of the surface (an edge used by
## exactly one triangle); sheets have long open rims, solids ~none.
## Cached per source mesh: rigs spawn often, topology never changes.
func _closed_hull_mesh(src: Mesh) -> ArrayMesh:
	var key := src.resource_path + "|" + str(src.get_surface_count())
	if _hull_cache.has(key):
		return _hull_cache[key]
	var out := ArrayMesh.new()
	var kept := 0
	for i in range(src.get_surface_count()):
		if not _surface_closed(src, i):
			continue
		# Transparent surfaces (alpha blend/scissor — Gastly's gas,
		# wing membranes) get no hull either: an opaque dark shell
		# over a translucent surface renders as a black blob (probe:
			# screenshots/c7_probe_gastly.png).
		var smat := src.surface_get_material(i)
		if smat is BaseMaterial3D and (smat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), src.surface_get_arrays(i))
		kept += 1
	var result: ArrayMesh = out if kept > 0 else null
	_hull_cache[key] = result
	return result

func _surface_closed(src: Mesh, si: int) -> bool:
	var arrays := src.surface_get_arrays(si)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var counts: Dictionary = {}
	var tri_count := 0
	if idx.is_empty():
		tri_count = verts.size() / 3
		for t in range(tri_count):
			_count_edge(counts, t * 3, t * 3 + 1)
			_count_edge(counts, t * 3 + 1, t * 3 + 2)
			_count_edge(counts, t * 3 + 2, t * 3)
	else:
		tri_count = idx.size() / 3
		for t in range(tri_count):
			_count_edge(counts, idx[t * 3], idx[t * 3 + 1])
			_count_edge(counts, idx[t * 3 + 1], idx[t * 3 + 2])
			_count_edge(counts, idx[t * 3 + 2], idx[t * 3])
	if counts.is_empty():
		return false
	var boundary := 0
	for k in counts:
		if int(counts[k]) == 1:
			boundary += 1
	return float(boundary) / float(counts.size()) < 0.03

func _count_edge(counts: Dictionary, a: int, b: int) -> void:
	var key: int = (mini(a, b) << 32) | maxi(a, b)
	counts[key] = int(counts.get(key, 0)) + 1

func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null

const GAIT_SUFFIXES := ["LThigh", "RThigh", "LLeg", "RLeg", "LFoot", "RFoot",
	"LForeArm", "RForeArm", "LArm", "RArm", "LArm2", "RArm2", "LForeArm2", "RForeArm2",
	"Spine", "Spine1", "Spine2", "Waist", "Jaw", "Tail1", "Tail2", "Tail3", "Tail4"]
const LIFE_SUFFIXES := ["Head", "Neck"]
## Gait archetypes for the species whose SPECIES entry predates the
## cfg "gait" key (Segment Z). Body-plan calls: quadruped walkers,
## bipeds, hoppers (both feet together), hoverers (bank on turns),
## serpents (no legs to swing — root sway only).
const GAIT_BY_SPECIES := {
	"bulbasaur": "quad", "ivysaur": "quad", "venusaur": "quad",
	"rattata": "quad", "raticate": "quad", "sandshrew": "quad",
	"sandslash": "quad", "rhyhorn": "quad", "growlithe": "quad",
	"arcanine": "quad", "ponyta": "quad",
	"charmander": "biped", "charmeleon": "biped", "squirtle": "biped",
	"wartortle": "biped", "blastoise": "biped", "nidoking": "biped",
	"snorlax": "biped", "charizard": "biped", "graveler": "biped",
	"gengar": "biped", "cubone": "biped", "marowak": "biped",
	"scyther": "biped", "pinsir": "biped", "magmar": "biped",
	"dragonite": "biped",
	"pidgey": "hopper", "pidgeotto": "hopper", "geodude": "hopper",
	"gastly": "hover", "haunter": "hover", "zubat": "hover",
	"diglett": "serpent", "dugtrio": "serpent",
}

func _resolve_gait_kind() -> String:
	if _gait_kind != "":
		return _gait_kind
	var cfg: Dictionary = SPECIES.get(species_id, {})
	if cfg.has("gait"):
		_gait_kind = String(cfg["gait"])
	else:
		_gait_kind = String(GAIT_BY_SPECIES.get(species_id, "biped"))
	return _gait_kind

## 无剪辑骨骼 3D 模型（小火龙、杰尼龟、小拳石、隆隆石、飞天螳螂、凯罗斯、尼多王等）自适应破除水平 T-Pose：
## 仅旋转顶层肩臂骨骼局部姿态，使前臂与手爪随父骨自然垂放贴合身侧，彻底消除跨关节世界坐标覆盖导致的断肢脱臼现象。
func _auto_relax_tpose_arms(deg_down: float = 52.0) -> void:
	if _skel == null:
		return
	# 从 _skel 沿局部父链累乘到 model，避免离屏预构建未入场景树时调用 global_transform 报错
	var sk_b := Basis.IDENTITY
	var cur: Node = _skel
	while cur != null and cur != model:
		if cur is Node3D:
			sk_b = (cur as Node3D).transform.basis * sk_b
		cur = cur.get_parent()
	sk_b = sk_b.orthonormalized()
	var sin_y := sin(deg_to_rad(deg_down))
	var cos_x := cos(deg_to_rad(deg_down))
	for pair in [["LArm", "LForeArm"], ["RArm", "RForeArm"], ["LArm2", "LForeArm2"], ["RArm2", "RForeArm2"]]:
		var arm_suf: String = pair[0]
		var fore_suf: String = pair[1]
		if not _gait_bones.has(arm_suf) or not _gait_bones.has(fore_suf):
			continue
		var ai: int = _gait_bones[arm_suf]
		var fi: int = _gait_bones[fore_suf]
		var gp := _skel.get_bone_global_rest(ai)
		var gf := _skel.get_bone_global_rest(fi)
		var v := sk_b * (gf.origin - gp.origin)
		if v.length() < 0.02:
			continue
		var dir_w := v.normalized()
		if absf(dir_w.x) <= 0.45 or dir_w.y < -0.55:
			continue
		var sx := 1.0 if dir_w.x >= 0.0 else -1.0
		var target_w := Vector3(sx * cos_x, -sin_y, 0.28).normalized()
		var q_model := Quaternion(dir_w, target_w)
		var q_sk := (sk_b.inverse() * Basis(q_model) * sk_b).get_rotation_quaternion()
		var par := _skel.get_bone_parent(ai)
		var par_b := _skel.get_bone_global_rest(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
		var target_global_b := Basis(q_sk) * gp.basis.orthonormalized()
		var target_local_q := (par_b.inverse() * target_global_b).get_rotation_quaternion()
		_gait_rest[arm_suf] = target_local_q
		_skel.set_bone_pose_rotation(ai, target_local_q)
		var arm_bw := (sk_b * target_global_b).orthonormalized()
		var inv_arm_bw := arm_bw.inverse()
		_axis_pitch[arm_suf] = (inv_arm_bw * Vector3(1, 0, 0)).normalized()
		_axis_yaw[arm_suf] = (inv_arm_bw * Vector3(0, 1, 0)).normalized()
		_axis_roll[arm_suf] = (inv_arm_bw * Vector3(0, 0, 1)).normalized()
		# 同时令前臂沿肘关节自然向前微曲收拢，形成富有战斗生气的拳姿而不再笔直下垂
		if _skel.get_bone_parent(fi) == ai:
			var fore_target_w := Vector3(sx * 0.24, -0.45, 0.86).normalized()
			var fq_model := Quaternion(target_w, fore_target_w)
			var fq_sk := (sk_b.inverse() * Basis(fq_model) * sk_b).get_rotation_quaternion()
			var f_rest_g := _skel.get_bone_global_rest(fi).basis.orthonormalized()
			var gp_o := gp.basis.orthonormalized()
			var fore_after_sk := Basis(fq_sk) * (Basis(q_sk) * f_rest_g)
			var f_local_q := (gp_o.inverse() * Basis(q_sk).inverse() * fore_after_sk).get_rotation_quaternion()
			_gait_rest[fore_suf] = f_local_q
			_skel.set_bone_pose_rotation(fi, f_local_q)
			var f_bw := (sk_b * fore_after_sk).orthonormalized()
			var inv_f_bw := f_bw.inverse()
			_axis_pitch[fore_suf] = (inv_f_bw * Vector3(1, 0, 0)).normalized()
			_axis_yaw[fore_suf] = (inv_f_bw * Vector3(0, 1, 0)).normalized()
			_axis_roll[fore_suf] = (inv_f_bw * Vector3(0, 0, 1)).normalized()

func _collect_gait_bones() -> void:
	_skel = _find_skeleton(model)
	if _skel == null:
		return
	var sk_b := Basis.IDENTITY
	var cur: Node = _skel
	while cur != null and cur != model:
		if cur is Node3D:
			sk_b = (cur as Node3D).transform.basis * sk_b
		cur = cur.get_parent()
	sk_b = sk_b.orthonormalized()
	for i in range(_skel.get_bone_count()):
		var bname := _skel.get_bone_name(i)
		for suf in GAIT_SUFFIXES + LIFE_SUFFIXES:
			if bname.ends_with(suf) and not _gait_bones.has(suf):
				_gait_bones[suf] = i
				_gait_rest[suf] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()
				var bw := (sk_b * _skel.get_bone_global_rest(i).basis).orthonormalized()
				var inv_bw := bw.inverse()
				_axis_pitch[suf] = (inv_bw * Vector3(1, 0, 0)).normalized()
				_axis_yaw[suf] = (inv_bw * Vector3(0, 1, 0)).normalized()
				_axis_roll[suf] = (inv_bw * Vector3(0, 0, 1)).normalized()
				break

## 将在骨骼本地算好的多轴欧拉目标合成单次四元数写回，确保模型空间各个关节自然联动不拧麻花
func _pose_bone(suf: String, pitch: float, yaw: float = 0.0, roll: float = 0.0) -> void:
	if not _gait_bones.has(suf):
		return
	var idx: int = _gait_bones[suf]
	if idx in _stance_bones:
		return
	var rest_q: Quaternion = _gait_rest.get(suf, Quaternion.IDENTITY)
	var q := rest_q
	if absf(pitch) > 0.0005:
		q = q * Quaternion(_axis_pitch.get(suf, Vector3(1, 0, 0)), pitch)
	if absf(yaw) > 0.0005:
		q = q * Quaternion(_axis_yaw.get(suf, Vector3(0, 1, 0)), yaw)
	if absf(roll) > 0.0005:
		q = q * Quaternion(_axis_roll.get(suf, Vector3(0, 0, 1)), roll)
	_skel.set_bone_pose_rotation(idx, q)

## Spring-damper follow (Segment Z): secondary bones chase their
## target with lag + overshoot instead of tracking a sine exactly.
func _spring(suffix: String, target: float, delta: float) -> float:
	var st: Array = _springs.get(suffix, [0.0, 0.0])
	var x: float = st[0]
	var v: float = st[1]
	v += (26.0 * (target - x) - 6.0 * v) * delta
	x += v * delta
	_springs[suffix] = [x, v]
	return x

func _gait_rot(suffix: String, axis: Vector3, ang: float) -> void:
	if not _gait_bones.has(suffix):
		return
	var idx: int = _gait_bones[suffix]
	if idx in _stance_bones:
		return  # held by the stance override (Geodude/guardian arms)
	# Compose the swing ON the bone's rest rotation (cycle 7 fix):
	# set_bone_pose_rotation takes an ABSOLUTE local rotation, so the
	# old code discarded the rest pose every frame. Species whose limb
	# rests are near-identity (most of the repo) never noticed; PMD-
	# style skeletons (Graveler) carry real rest angles in the limbs
	# and rendered with their legs flipped skyward even at amp 0.
	var rest_q: Quaternion = _gait_rest.get(suffix, Quaternion.IDENTITY)
	_skel.set_bone_pose_rotation(idx, rest_q * Quaternion(axis, ang))

func _update_gait(delta: float) -> void:
	if _skel == null:
		return
	var kind := _resolve_gait_kind()
	var target := clampf(_move_speed / 4.5, 0.0, 1.0)
	_gait_amp = lerpf(_gait_amp, target, clampf(delta * 7.0, 0.0, 1.0))
	var amp := _gait_amp
	# Phase-locked stride (Segment Z): the phase advances with
	# GROUND SPEED over a fixed per-species stride length, so a
	# footfall lands every stride_len of travel — the old free-
	# running rate (1.6 + speed*2.1) slid feet over the ground.
	var cfg: Dictionary = SPECIES.get(species_id, {})
	var h := float(cfg.get("height", 1.2))
	var stride_len: float = h * (0.8 if kind == "hopper" else 0.55)
	if _move_speed > 0.05 and stride_len > 0.01:
		_gait_phase += delta * PI * _move_speed / stride_len
	var s := sin(_gait_phase)
	# Footfall detection (walkers at every half-cycle, hoppers at
	# the air->ground wrap): a small step squash sells the contact.
	if amp > 0.25:
		if kind == "hopper":
			if _last_sin > 0.0 and s <= 0.0:
				_step_squash = maxf(_step_squash, 0.30)
		elif kind == "quad" or kind == "biped":
			if _last_sin * s < 0.0:
				_step_squash = maxf(_step_squash, 0.07 * amp)
	_last_sin = s
	match kind:
		"quad", "biped":
			# 使用预算出的真实正交模型空间横轴迈步，彻底解决各模型骨骼轴向混乱导致的横扯拧扭
			_pose_bone("LThigh", -s * 0.65 * amp)
			_pose_bone("RThigh", s * 0.65 * amp)
			_pose_bone("LLeg", (0.5 + 0.5 * sin(_gait_phase - 1.1)) * 0.72 * amp)
			_pose_bone("RLeg", (0.5 + 0.5 * sin(_gait_phase + PI - 1.1)) * 0.72 * amp)
			_pose_bone("LFoot", s * 0.28 * amp)
			_pose_bone("RFoot", -s * 0.28 * amp)
			# 躯干随奔跑自然前倾并配合跨步微扭腰，彻底摆脱木桩感
			var atk_spine_p := 0.0
			var atk_arm_l := 0.0
			var atk_arm_r := 0.0
			var atk_fore := 0.0
			var atk_jaw := 0.0
			var atk_head_p := 0.0
			if _ult_pose_t > 0.0:
				var up := sin(clampf(_ult_pose_t / 0.6, 0.0, 1.0) * PI)
				atk_spine_p = -0.34 * up
				atk_head_p = -0.28 * up
				atk_jaw = 0.55 * up
				atk_arm_l = -1.15 * up
				atk_arm_r = -1.15 * up
			elif _lunge_t > 0.0:
				var e := 1.0 - maxf(_lunge_t, 0.0) / 0.42
				if e < 0.25:
					var bk := e / 0.25
					atk_spine_p = -0.28 * bk
					atk_head_p = -0.18 * bk
					atk_jaw = 0.35 * bk
					if _atk_hand > 0.0:
						atk_arm_l = 0.55 * bk; atk_arm_r = -0.22 * bk
					else:
						atk_arm_r = 0.55 * bk; atk_arm_l = -0.22 * bk
				else:
					var arc := sin(((e - 0.25) / 0.75) * PI)
					atk_spine_p = 0.44 * arc
					atk_head_p = -0.18 * arc
					atk_jaw = 0.52 * arc
					atk_fore = -0.68 * arc
					if _atk_hand > 0.0:
						atk_arm_l = -1.18 * arc; atk_arm_r = 0.38 * arc
					else:
						atk_arm_r = -1.18 * arc; atk_arm_l = 0.38 * arc
			var idle_sw := sin(_breath_t * 2.2) * 0.055 * (1.0 - amp)
			_pose_bone("LArm", s * 0.54 * amp + idle_sw + atk_arm_l, 0.0, -0.06 - absf(idle_sw))
			_pose_bone("RArm", -s * 0.54 * amp - idle_sw + atk_arm_r, 0.0, 0.06 + absf(idle_sw))
			_pose_bone("LForeArm", (-0.28 + s * 0.25) * amp + atk_fore)
			_pose_bone("RForeArm", (-0.28 - s * 0.25) * amp + atk_fore)
			var run_lean := 0.14 * amp + sin(_breath_t * 2.2) * 0.03 * (1.0 - amp)
			if _gait_bones.has("Spine1"):
				_pose_bone("Spine1", run_lean + atk_spine_p, s * 0.10 * amp, -s * 0.04 * amp)
			elif _gait_bones.has("Spine"):
				_pose_bone("Spine", run_lean + atk_spine_p, s * 0.10 * amp, -s * 0.04 * amp)
			if _gait_bones.has("Jaw"):
				_pose_bone("Jaw", atk_jaw)
			if _gait_bones.has("Head"):
				_pose_bone("Head", -0.06 * amp + atk_head_p, _spring("Head", _head_turn_yaw, delta))
			_hop_y = 0.0
			_sway_yaw = 0.0
		"hopper":
			# 跳跃与飞禽双翼（如波波/烈雀）绕正交模型前后轴对称上下展翅扑腾，跳跃双腿协调微曲
			var atk_p := 0.0
			if _lunge_t > 0.0:
				var e2 := 1.0 - maxf(_lunge_t, 0.0) / 0.42
				atk_p = -0.3 * (e2 / 0.25) if e2 < 0.25 else 0.55 * sin(((e2 - 0.25) / 0.75) * PI)
			_pose_bone("LThigh", -s * 0.45 * amp)
			_pose_bone("RThigh", -s * 0.45 * amp)
			_pose_bone("LLeg", (0.5 + 0.5 * sin(_gait_phase - 1.1)) * 0.55 * amp)
			_pose_bone("RLeg", (0.5 + 0.5 * sin(_gait_phase - 1.1)) * 0.55 * amp)
			var flap := sin(_bob_phase * 2.4 if amp > 0.2 else _breath_t * 3.5) * (0.18 + 0.48 * amp)
			_pose_bone("LArm", atk_p * 0.5, 0.0, -flap)
			_pose_bone("RArm", atk_p * 0.5, 0.0, flap)
			if _gait_bones.has("Spine1"):
				_pose_bone("Spine1", 0.12 * amp + atk_p)
			if _gait_bones.has("Head"):
				_pose_bone("Head", -0.05 * amp + atk_p * 0.5, _spring("Head", _head_turn_yaw, delta))
			_hop_y = maxf(0.0, s) * 0.16 * amp
			_sway_yaw = 0.0
		"hover":
			_pose_bone("LThigh", -s * 0.15 * amp)
			_pose_bone("RThigh", s * 0.15 * amp)
			_hop_y = 0.0
			_sway_yaw = 0.0
		"serpent":
			_hop_y = 0.0
			_sway_yaw = s * 0.12 * amp
	# Tail: spring-damper chase along true vertical yaw axis
	var wag := 0.18 + 0.38 * amp
	for ti in range(4):
		var suf := "Tail" + str(ti + 1)
		if _gait_bones.has(suf):
			var tgt := sin(_gait_phase * 0.55 + _breath_t * (1.8 if amp < 0.1 else 0.0) - float(ti) * 0.8) * wag * 0.45
			_pose_bone(suf, sin(_breath_t * 2.2 - float(ti) * 0.6) * 0.05, _spring(suf, tgt, delta))
	if kind != "quad" and kind != "biped" and kind != "hopper" and _gait_bones.has("Head"):
		_pose_bone("Head", 0.0, _spring("Head", _head_turn_yaw, delta))

func _merged_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var a: AABB = mi.global_transform * mi.get_aabb()
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
		for c in cur.get_children():
			stack.append(c)
	return out

func _fit(cfg: Dictionary, scale_mult: float) -> void:
	# Empirical fit (hotfix, DIFF "Charmander player" entry): every
	# species carries `native` = its RENDERED height at model scale 1
	# and `feet` = its lowest rendered point's offset above the model
	# origin, both measured by Test/probe.tscn (visibility-diff
	# silhouettes). Box math cannot substitute: the bind-pose AABB
	# through the node chain reads 5.206 u for Charmander (an authored
	# 2.54x node scale sits above its skeleton) while the skinned
	# render is 1.59 u — the old fit shrank the player to 0.25x, and a
	# GDScript skinned-AABB attempt was rejected on evidence (the
	# import's skin bind poses live in file space while skeleton poses
	# are converted, so they do not compose naively; see DIFF).
	if cfg.has("span"):
		# Cycle 21: geometry-space fit (ekans). The render
		# probe measures silhouette HEIGHT — meaningless for
		# a body whose length lies along Z. span/feet/center
		# come from the GLB's own geometry (Test/geo_probe.gd:
		# node-chain AABB at scale 1 — length, lowest point,
		# plan center), and `height` is the target LENGTH.
		var s := float(cfg["height"]) * scale_mult / float(cfg["span"])
		model.scale = Vector3.ONE * s
		var ctr: Vector2 = cfg.get("center", Vector2.ZERO)
		model.position = Vector3(-ctr.x * s, -float(cfg.get("feet", 0.0)) * s, -ctr.y * s)
		base_pos = model.position
		_base_scale = model.scale
		fitted = true
		return
	if cfg.has("native"):
		var s := float(cfg["height"]) * scale_mult / float(cfg["native"])
		model.scale = Vector3.ONE * s
		model.position = Vector3(0, -float(cfg.get("feet", 0.0)) * s, 0)
		if cfg.has("hover"):
			# Flyers (Gastly/Zubat) hover above their ground point by
			# design; this replaces their old y_offset grounding hack.
			model.position.y += float(cfg["hover"]) * scale_mult
		base_pos = model.position
		_base_scale = model.scale
		fitted = true
		return
	# Legacy fallback for unmeasured species (bind-AABB — known-wrong
	# for skinned imports; a species should not ship on this path).
	var aabb := _merged_aabb(model)
	var denom := aabb.size.y
	if cfg["fit"] == "span":
		denom = max(aabb.size.x, aabb.size.y)
	if denom < 0.0001:
		fitted = true
		return
	var s2 := float(cfg["height"]) * scale_mult / denom
	model.scale = Vector3.ONE * s2
	await get_tree().process_frame
	aabb = _merged_aabb(model)
	# Ground the model: base of AABB at local y=0, centered on x/z.
	model.global_position -= Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y, aabb.position.z + aabb.size.z * 0.5) - global_position
	if cfg.has("y_offset"):
		model.global_position.y += float(cfg["y_offset"]) * scale_mult
	base_pos = model.position
	_base_scale = model.scale
	fitted = true

func set_facing(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var cfg: Dictionary = SPECIES[species_id]
	_target_yaw = atan2(dir.x, dir.z) + float(cfg["yaw"])
	if not _has_facing:
		_has_facing = true
		rotation.y = _target_yaw

func set_move_speed(s: float) -> void:
	_move_speed = s

func play_lunge() -> void:
	_lunge_t = 0.42
	_cast_t = 0.42
	_atk_hand = -_atk_hand
	if anim_player:
		_clip_state = ""  # 每次出招均强制从头重播，确保连击时动作不漏播
		_play_clip("fight")

## Cycle 13: the ult pose — fire() sets ultPoseT = .6 and the
## renderer holds the species' "attack" pose for the window
## (bundle @1397186; our clip set names it "fight"). No thrust:
## the lunge channel stays out of it; the cast squash pulse
## (attackT .3) rides along like every other cast.
func play_ult_pose() -> void:
	_ult_pose_t = 0.6
	_cast_t = 0.38
	if anim_player:
		_clip_state = ""
		_play_clip("fight")
	else:
		_lunge_t = 0.38

func ult_pose_value() -> float:
	return _ult_pose_t

## Hit flash (cycle 9): the original sets flash = 1 on any damage
## event (enemies @727571, player hurt() @821025) and decays it 6/s.
func set_flash(v: float = 1.0) -> void:
	_flash = maxf(_flash, v)

func flash_value() -> float:
	return _flash

## Squash impulse (cycle 9): bundle sets squash = 0.6 (enemy hit),
## 0.5 (player hurt), 0.9 (player slam start); decay exp(-10t).
func set_squash(v: float) -> void:
	_squash = maxf(_squash, v)

func squash_value() -> float:
	return _squash

## Hurt response (cycle 9, audit §1): flash + squash ONLY — the
## original has no positional flinch pose; the cycle-8 invented
## 0.22 s push/tilt is deleted. Player squash is 0.5 (hurt() @821025),
## enemy squash 0.6 (strike @727584 region).
func play_hurt() -> void:
	if _faint_t >= 0.0:
		return
	set_flash(1.0)
	set_squash(0.5 if is_player else 0.6)

## Faint (cycle 9, audit §1): enemies fade over dying = 0.35 s
## (w = 1 - dying/0.35 @340280) with no pose change. The player
## collapses procedurally (tip-over) or via its authored "ko" clip
## (Bulbasaur), and revive_reset() restores it (audit P0).
func play_faint() -> void:
	if _faint_t >= 0.0:
		return
	_faint_t = 0.0
	_lunge_t = 0.0
	_cast_t = 0.0
	_ult_pose_t = 0.0
	set_flash(1.0)
	if is_player and anim_player:
		for n in anim_player.get_animation_list():
			if "ko" in n:
				_clip_state = ""
				_play_clip("ko")
				_faint_clip = true
				break

## Audit P0: full rig reset for the Lab revive — clears the faint
## latch, flash, squash and fade, and restores the fitted transform
## so pose/gait/hurt work again immediately.
func revive_reset() -> void:
	_faint_t = -1.0
	_faint_clip = false
	_flash = 0.0
	_squash = 0.0
	_lunge_t = 0.0
	_cast_t = 0.0
	_ult_pose_t = 0.0
	_apply_flash_fade(0.0)  # restores base albedos + full opacity
	if model:
		model.rotation = Vector3.ZERO
		model.position = base_pos
		if _base_scale != Vector3.ZERO:
			model.scale = _base_scale
		model.visible = true
	if anim_player:
		_clip_state = ""
		_play_clip("idle")

## Cycle 14: wet tint channel — the bundle multiplies a wet
## target's render colour by ~(0.90, 0.95, 1.08) (@339641).
## Composes UNDER the hit flash (flash wins while active).
var _wet := false

func set_wet(on: bool) -> void:
	_wet = on

## Cycle 20 (DIFF §7 correction): the shiny visual variant.
## The bundle does NOT swap normal shinies to an alternate
## sheet — it hue-rotates the sprite by zl(id) (main
## @125961): zl(id) = 0.22 + (id * 0.618034 mod 1) * 0.56.
## The faithful 3D equivalent rotates by the same zl: the
## rigs carry their colour in the albedo TEXTURES (the tint
## bases are the gray calibration colour), so each texture
## is hue-rotated once per species (cached) with the
## bundle's own hueShift operator (Rodrigues rotation
## about the equal-weight gray axis, main @114320), and
## any saturated tint base rotates with it (eyes
## included — the bundle's shader covers the whole
## sprite). Cycle 19's gold wash + gold emission
## approximated the WRONG mechanism and is removed;
## cycle 20 used the CSS luminance-weighted matrix,
## which the C20 audit (claim 5) showed is NOT the
## bundle's operator — 20.1 swaps in hueShift itself.
## Riding _flash_mats means hit-flash and the corpse
## fade restore to the ROTATED base, not the normal one.
static func shiny_hue_shift(dex_id: int) -> float:
	var f := float(dex_id) * 0.618034
	return 0.22 + (f - floor(f)) * 0.56

static var _shiny_tex_cache: Dictionary = {}  # "species|texRID" -> rotated Texture2D

func apply_shiny() -> void:
	var dex_id := int(GameData.species(species_id).get("id", 0))
	var shift := shiny_hue_shift(dex_id)
	for rec in _flash_mats:
		var base: Color = rec["base"]
		rec["base"] = _hue_rotate_color(base, shift)
		var m := rec["mat"] as StandardMaterial3D
		if m.albedo_texture != null:
			m.albedo_texture = _shiny_rotated_texture(m.albedo_texture, shift)
	_apply_flash_fade(0.0)

func _shiny_rotated_texture(tex: Texture2D, shift: float) -> Texture2D:
	var key := species_id + "|" + str(tex.get_rid().get_id())
	if _shiny_tex_cache.has(key):
		return _shiny_tex_cache[key]
	var out := _hue_rotate_texture(tex, shift)
	_shiny_tex_cache[key] = out
	return out

## The bundle's hueShift operator (main @114320): a
## Rodrigues rotation about the equal-weight gray axis
## k = vec3(1/sqrt(3)) —
##   c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1 - cos(a))
## returned as 3x3 rows for angle a = turns * TAU (the
## bundle's shinyHue is zl in turns x 2pi, @122792).
## Cycle 20 shipped the CSS/SVG luminance-weighted
## hue-rotate matrix (0.213/0.715/0.072) here instead:
## same angle, different operator — it preserves luma
## where hueShift preserves the RGB mean, so saturated
## colours land on visibly different hues (C20 audit,
## claim 5). This matrix is the bundle's.
static func _hue_matrix(turns: float) -> Array:
	var ang := turns * TAU
	var ca := cos(ang)
	var sa := sin(ang)
	var q := 0.5773502691896258  # 1/sqrt(3)
	var t := (1.0 - ca) / 3.0    # (1-ca) * k_i * k_j
	return [
		ca + t, -sa * q + t, sa * q + t,
		sa * q + t, ca + t, -sa * q + t,
		-sa * q + t, sa * q + t, ca + t]

static func _hue_rotate_color(c: Color, turns: float) -> Color:
	var m := _hue_matrix(turns)
	return Color(
		clampf(c.r * float(m[0]) + c.g * float(m[1]) + c.b * float(m[2]), 0.0, 1.0),
		clampf(c.r * float(m[3]) + c.g * float(m[4]) + c.b * float(m[5]), 0.0, 1.0),
		clampf(c.r * float(m[6]) + c.g * float(m[7]) + c.b * float(m[8]), 0.0, 1.0), c.a)

## Hue rotation by `turns` of the hue circle with the
## bundle's hueShift matrix (see _hue_matrix;
## gray-invariant, alpha untouched). One pass over the
## image data; callers cache the result.
static func _hue_rotate_texture(tex: Texture2D, turns: float) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	if img.is_compressed():
		return tex  # no CPU decoder for this format: tint rotation still applies
	img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		# get_data() would return base + mip levels (an
		# oversized buffer set_data rejects); work on a
		# base-level copy and regenerate mips at the end.
		var plain := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		plain.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
		img = plain
	var data := img.get_data()
	var mx := _hue_matrix(turns)
	var m00 := float(mx[0])
	var m01 := float(mx[1])
	var m02 := float(mx[2])
	var m10 := float(mx[3])
	var m11 := float(mx[4])
	var m12 := float(mx[5])
	var m20 := float(mx[6])
	var m21 := float(mx[7])
	var m22 := float(mx[8])
	for i in range(0, data.size(), 4):
		var r := float(data[i]) / 255.0
		var g := float(data[i + 1]) / 255.0
		var b := float(data[i + 2]) / 255.0
		data[i] = int(clampf(r * m00 + g * m01 + b * m02, 0.0, 1.0) * 255.0)
		data[i + 1] = int(clampf(r * m10 + g * m11 + b * m12, 0.0, 1.0) * 255.0)
		data[i + 2] = int(clampf(r * m20 + g * m21 + b * m22, 0.0, 1.0) * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Push the flash tint + corpse fade into the calibrated materials.
## fade_k: 0 = opaque, 1 = fully faded (enemy dying 0.35 s curve).
func _apply_flash_fade(fade_k: float) -> void:
	var a := 1.0 - clampf(fade_k, 0.0, 1.0)
	for rec in _flash_mats:
		var m := rec["mat"] as StandardMaterial3D
		var base: Color = rec["base"]
		if _wet and _flash <= 0.0:
			base = Color(base.r * 0.90, base.g * 0.95, base.b * 1.08, base.a)
		var c: Color = base.lerp(FLASH_TINT, clampf(_flash, 0.0, 1.0)) if _flash > 0.0 else base
		c.a = base.a * a
		m.albedo_color = c
		if a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		elif base.a >= 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if a < 1.0 and _hull_mats.is_empty() and not _hull_nodes.is_empty():
		# 仅在死亡淡出 0.35s 时为描边分配独立透明材质，平时全员共享单一黑色材质
		for ol in _hull_nodes:
			if is_instance_valid(ol):
				var om := _shared_hull_mat.duplicate() as StandardMaterial3D
				(ol as MeshInstance3D).material_override = om
				_hull_mats.append(om)
	for hm in _hull_mats:
		var h := hm as StandardMaterial3D
		h.albedo_color = Color(OUTLINE_COLOR, OUTLINE_COLOR.a * a)
		h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED

func _play_clip(kind: String) -> void:
	if anim_player == null or _clip_state == kind:
		return
	var names := anim_player.get_animation_list()
	var pick := ""
	for n in names:
		if kind == "idle" and "idle" in n:
			pick = n
			break
		if kind == "walk" and ("walk" in n or "run" in n):
			pick = n
			break
		if kind == "fight" and "fight" in n:
			pick = n
			break
		if kind == "ko" and "ko" in n:
			pick = n
			break
	if pick != "":
		# 针对长骨骼攻击剪辑（如妙蛙种子 1.75 s）按自然力度倍速播放并使用 0.10 s 交叉淡变，告别硬切僵硬
		if kind == "fight":
			var alen := anim_player.get_animation(pick).length
			var target_dur := 0.55 if _ult_pose_t > 0.0 else 0.40
			anim_player.speed_scale = clampf(alen / target_dur, 1.2, 3.6)
		else:
			anim_player.speed_scale = 1.0
		anim_player.play(pick, 0.10)
		anim_player.seek(0.0)
		_clip_state = kind

func _process(delta: float) -> void:
	if model == null or not fitted:
		return
	# Faint progress: the player collapses over 0.7 s (tip-over
	# curve); enemies fade over the original's dying = 0.35 s.
	var faint_k := 0.0
	var fade_k := 0.0
	if _faint_t >= 0.0:
		_faint_t += delta
		if is_player:
			faint_k = minf(_faint_t / 0.7, 1.0)
		else:
			fade_k = minf(_faint_t / 0.35, 1.0)
	# Flash decays 6/s, squash exp(-10t) (bundle updateProxy @336849).
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - 6.0 * delta)
	if _squash > 0.0:
		_squash *= exp(-10.0 * delta)
		if _squash < 0.003:
			_squash = 0.0
	if _flash > 0.0 or fade_k > 0.0 or _fx_active:
		_apply_flash_fade(fade_k)
		_fx_active = _flash > 0.0 or fade_k > 0.0
	var lod_step := 1
	if lod_enabled and lod_target != null and is_instance_valid(lod_target) and _faint_t < 0.0:
		var dx := global_position.x - lod_target.global_position.x
		var dz := global_position.z - lod_target.global_position.z
		var d2 := dx * dx + dz * dz
		var want_hull := d2 <= 484.0  # 22m 内保持完整暗色描边
		if want_hull != _hulls_vis:
			_hulls_vis = want_hull
			for ol in _hull_nodes:
				if is_instance_valid(ol):
					(ol as MeshInstance3D).visible = want_hull
		if d2 > 1024.0:
			lod_step = 4
		elif d2 > 324.0:
			lod_step = 2
	_lod_tick += 1
	# Clip state by movement (only for models with real clips).
	# Cycle 13: the ult pose holds the fight clip for ultPoseT —
	# the locomotion selector must not stomp it mid-window.
	if anim_player:
		if _lunge_t <= 0.0 and _ult_pose_t <= 0.0 and _faint_t < 0.0:
			_play_clip("walk" if _move_speed > 0.3 else "idle")
	elif _faint_t < 0.0:
		_gait_accum += delta
		if lod_step <= 1 or (_lod_tick % lod_step) == 0:
			_update_gait(_gait_accum)
			_gait_accum = 0.0
	if _has_facing:
		rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-20.0 * delta))
	# --- Segment Z body life -------------------------------------
	# Yaw rate for hover banking (smoothed angle delta of the rig).
	var yr := 0.0
	if delta > 0.0001:
		yr = angle_difference(_prev_rot_y, rotation.y) / delta
	_prev_rot_y = rotation.y
	_bank = lerpf(_bank, clampf(-yr * 0.9, -0.5, 0.5), clampf(delta * 6.0, 0.0, 1.0))
	# Idle head-turn scheduler: only while nearly still.
	_breath_t += delta
	if _gait_amp < 0.15 and _faint_t < 0.0:
		if _head_turn_hold > 0.0:
			_head_turn_hold -= delta
			if _head_turn_hold <= 0.0:
				_head_turn_yaw = 0.0
		else:
			_head_turn_next -= delta
			if _head_turn_next <= 0.0:
				_head_turn_yaw = (0.3 + 0.25 * randf()) * (1.0 if randf() < 0.5 else -1.0)
				_head_turn_hold = 1.0 + 0.6 * randf()
				_head_turn_next = 3.5 + 3.5 * randf()
	else:
		_head_turn_yaw = 0.0
	# Step squash decays on the hurt channel's curve (exp(-10t)).
	if _step_squash > 0.0:
		_step_squash *= exp(-10.0 * delta)
		if _step_squash < 0.003:
			_step_squash = 0.0
	# Bob: phase-locked at 2x stride frequency for procedural
	# rigs (was a free-running phase — feet and body disagreed).
	_bob_phase += delta * (3.0 + _move_speed * 2.4)
	var amp: float = 0.02 + min(_move_speed, 6.0) * 0.012
	var off := Vector3(0, abs(sin(_bob_phase)) * amp, 0)
	var kind := _resolve_gait_kind() if anim_player == null else ""
	if anim_player == null and _skel != null:
		match kind:
			"quad", "biped":
				off.y = abs(sin(_gait_phase)) * amp
			"hopper":
				off.y = _hop_y
			"hover":
				off.y = 0.03 + sin(_breath_t * 1.9) * 0.03
			"serpent":
				off.y = abs(sin(_gait_phase)) * amp * 0.4
	if _faint_t >= 0.0 and is_player:
		# Ease-out: a fall tips fast, then settles (a quadratic
		# ease-in left mid-collapse at -18 degrees — unreadable).
		var fe := 1.0 - (1.0 - faint_k) * (1.0 - faint_k)
		off.y = -0.22 * fe  # sink as it collapses
	var rot_z := 0.0
	var rot_x := 0.0
	if anim_player == null:
		if kind == "hover":
			rot_z = _bank
		elif kind == "quad" or kind == "biped":
			rot_z = sin(_gait_phase) * 0.05 * _gait_amp
			rot_x = sin(_gait_phase * 2.0) * 0.02 * _gait_amp
		else:
			rot_z = sin(_bob_phase * 0.5) * 0.03 * (1.0 + _move_speed * 0.4)
	model.rotation.z = rot_z
	# Serpent root sway rides the model yaw (rig yaw is facing).
	if anim_player == null and _skel != null:
		model.rotation.y = _sway_yaw
	# Lunge (Segment Z curve): 0.30 s — brief anticipation pull-
	# back, thrust with overshoot decay. Timings of the hurt /
	# faint channels are untouched (audit P2).
	# HOTFIX (cycle 11 attack feel): the thrust direction was
	# -basis.z, but every modelled GLB faces +Z natively (the
	# Segment Z FACING BUG record — all 54 species, yaw table 0)
	# and set_facing() points the rig's +Z at the target. The
	# lunge therefore thrust AWAY from the target on every attack
	# (player auto-fire and enemy contact attacks alike) while
	# the anticipation read as a hop toward it — on device the
	# attacker visibly recoiled / showed no attack motion at all.
	# Forward is +Z in rig space; off is rig-local, so the local
	# basis is the right one (parents are unrotated).
	var lunge_rot := 0.0
	if _cast_t > 0.0:
		_cast_t -= delta
	if _ult_pose_t > 0.0:
		_ult_pose_t -= delta
		if _ult_pose_t <= 0.0:
			_clip_state = ""  # 必杀演出结束：强制回归待机/移动动画
	if _lunge_t > 0.0:
		_lunge_t -= delta
		if _lunge_t <= 0.0 and _ult_pose_t <= 0.0 and _clip_state == "fight":
			_clip_state = ""  # 攻击窗口结束：自动恢复待机/移动动画并还原播放速度
		var e: float = 1.0 - maxf(_lunge_t, 0.0) / 0.42
		var lo := 0.0
		var thrust_k := 0.55 if anim_player != null else (0.36 if _skel != null else 0.72)
		if e < 0.25:
			var bk: float = e / 0.25
			lo = -0.14 * bk
			lunge_rot = -0.14 * bk
		else:
			var pp: float = (e - 0.25) / 0.75
			var arc := sin(pp * PI)
			lo = thrust_k * pow(arc, 0.72)
			lunge_rot = 0.22 * arc
			off.y += arc * 0.16
		var fwd := transform.basis.z
		off += Vector3(fwd.x, 0, fwd.z) * lo
	if _faint_t >= 0.0 and is_player and not _faint_clip:
		model.rotation.x = -1.25 * (1.0 - (1.0 - faint_k) * (1.0 - faint_k))
	elif anim_player == null:
		model.rotation.x = float(SPECIES.get(species_id, {}).get("rot_x", 0.0)) + rot_x + lunge_rot
	model.position = base_pos + off
	if _base_scale != Vector3.ZERO:
		var shrink := 1.0 - (0.06 * faint_k if is_player else 0.0)
		var cast_pulse := 0.0
		if _cast_t > 0.0:
			cast_pulse = sin(PI * (1.0 - clampf(_cast_t, 0.0, 0.38) / 0.38)) * 0.22
		var sq := maxf(_squash, _step_squash) + cast_pulse
		var breath := 1.0 + sin(_breath_t * 1.7) * 0.012
		var sv := Vector3(1.0 + 0.35 * sq, (1.0 - 0.45 * sq) * (1.0 - (0.10 * faint_k if is_player else 0.0)), 1.0 + 0.35 * sq)
		model.scale = _base_scale * shrink * breath * sv
