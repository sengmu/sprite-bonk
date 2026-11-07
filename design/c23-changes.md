# C23 施工子批 A 记录

派单：2026-11-06。唯一规格：`design/c23-mining-pack.md` §1（完整读取）；F1：`/home/hatch/workspace/claude-audits/spritebonk-c22-2026-10-28/AUDIT_REPORT.md` 第4节及发现F1（完整读取）。

## 交付状态 / 待核断点

已完成：17行精确数据表及有已证现成消费者的接线、Profile biomes重构、玩家受击时钟的不耐烦修正、F1真实占用门控。所有验证阶段已等到.done结束：NUC定向129/0，全量643/0，既有bootsmoke rc=0，中立目录成品冒烟rc=0，phonehud a1651/0与s070_i0 1626/0。无本批或非本批失败签名。

**未达到“全部阶梯消费者落地”的完成口径**：wound、strike、alphaCap1只有已证表值，当前树缺相应机制/基础公式，pack没有完整补足；已发补证问题，未擅自发明。待补证位置和原因见下方「待核」。kills/level按pack明确保持no-op，不计为施工缺口。事件数量的ceil整数化与guardian-clear写入时机属于明确披露的移植适配。

所有长跑已结束；无需接续后台测试。下一步是主控补充三项消费者规格后继续接线，再针对新改动验证。当前代码、证据和逐处清单可独立验收；不冒充整批三项全部完成。

## ① 游戏代码变更（与检查分开）

逐处当前行号与内容见后文①清单，已对照全部58个游戏代码差异块核验。

- `scripts/world.gd`：新增 run_tier、17 行精确数据表、Normal/Difícil/Pesadilla 名称、tier getter、setup cap 数据入口（start_game 第三个可选参数）；无新选择 UI。
- `scripts/world.gd`：统一生成入口在 Enemy.setup 时乘 hp、随后乘 speed、dmg 与 stage≥2 的 late，覆盖普通、guardian、祭坛等通过该入口的单位；guardian 伤害上限随最终HP同比。
- `scripts/world.gd`：普通生成间隔乘 amount；既有性能上限前乘 cap；elite 概率加 elite；weather event 每批数量乘 events；alpha 与 league 非 card/event 时间提前 early，最早60秒。
- `scripts/world.gd`：原 BOSS_TK 的全部消费者改读 tele，狂暴阈值读 fury，机制增援读取 escorts；结算星尘乘派生值（公共XP入口位于player.gd，见下条），分数先 round 基值再乘 1+tier×.5，保留半分。
- `scripts/world.gd`：不耐烦删除 Boss 掉血钟，改读 player.no_hit_t，Db12/Ob20/kb.4，平面距离严格<30；下降至0时清标志，正向边沿弹原有提示。
- `scripts/world.gd`：F1 改为前摇 pending / run 非空 / dizzy>0 的真实占用门控，脑钟仍按狂暴及不耐烦加速；门控同时阻止远距跳跃与招式派发。保留 C22 返回值估算，明确为移植适配。
- `scripts/world.gd`：原 guardian clear 的 tier_* 写入改为 Profile.record_biome_clear（当前事件时机的适配，原作写入点未知）。
- `scripts/player.gd`：公共 gain_xp 入口乘 run tier XP，涵盖击杀及道具等来源；新增 no_hit_t，随有效模拟帧累加，普通命中（闪避/无敌提前返回之后）及固定命中复位。
- `scripts/profile.gd`：schema v3，biomes 字典与旧 tier_* 的保值迁移（旧1仍为1）；biome stored-tier / unlocked-by-chain / cap readers；tier_* challenge 从 biomes 读；hard/night 按≥2/≥3聚合；clear以最高 tier+1 保存。

## ② 检查 / harness 变更

- `Test/harness.gd:494`：_c9_start_run支持requested_tier（默认0）；`Test/harness.gd:617` 将新phase纳入全量；`Test/harness.gd:5473`：新增 c23 suite phase，可 `--only=c23`，全量自动纳入。17×3表值、实际spawn的HP/速度/伤害+late、分数与early、biomes解锁/最高纪录、玩家命中钟与不耐烦数值采样、两种狂暴状态的真实脑tick占用与完整冲刺晕眩检查。
- `Test/c23_batch.sh:1`：NUC setsid批处理，逐文件check-only，定向与全量suite、bootsmoke、phonehud a（phone 2400×1080 s100 i0）和 s070 i0。增量.done与最终ALLDONE分开，任何未到ALLDONE的长跑不算收尾。
- `Test/c23_neutral_smoke.sh:1`：补充成品验证；复用刚导出的Linux产物，复制到唯一 `/tmp/c23-neutral.*`，从项目树外启动75秒，检查存活及SCRIPT ERROR，完成后清理自己的副本并最后写ALLDONE；`bash -n`通过。
- `Test/phonehud.gd` 与原判定口径未修改。

## 红基线 / 验证证据

- 仅加入最初13项新检查、游戏代码未改时：NUC `Test/out/c23_red.done` rc=1，`c23_red.log` SUMMARY checks=13 fails=9。失败：缺少阶梯入口1项、noHitT22/32加速2项、普通/固定命中复位2项、狂暴/非狂暴run/dizzy占用4项。未用屏蔽脑钟的方法测F1。
- 改前同步：`c23_red_sync.log` TREE PARITY OK，103文件，diffs=0。
- 红基线拉回：`c23red_pull.done` RC=0 files=3 bytes=12117，逐文件核验。
- 本地 check-only 使用工程内 XDG_DATA_HOME 隔离目录；默认 user:// 不可写导致第一次本地引擎日志崩溃，改隔离目录后可解析。此为运行环境问题，不作为游戏行为红基线。

## 待核（不发明规格）

1. kills / level 两行按pack明确保持数据 no-op，原客户端无消费者。
2. wound：当前树没有 wound 机制；pack只给时长4/5/6，未给何时施加及完整作用。保留精确表值，尚无玩法消费者。
3. strike：pack给两处floor基数.05/.02与倍率，但未给两种分派及完整公式。现有_boss_strike仅take_damage(dmg×mul)，不能将数值相近的水池硬认作对应项。保留精确表值，尚未接线。
4. alphaCap1：当前只按ALPHA_TIMES固定生怪，没有stage1 alpha chance基础公式。保留精确表值，不改elite概率冒充alpha概率。
5. events：正数数量整数化使用ceil（对应i<count的循环效果），这是移植适配，pack未证明原作取整。只改现有事件批次数；30总上限保持既有口径。
6. Profile clear原作写入点仍未知；保留移植版guardian-clear触发时机。单机只有forest开局、四区链，setup cap以forest读；无tower/endless/co-op模式，不新增模式。
7. 金色喵喵与冰柱等特殊单位会在通用生成之后重写部分属性，未擅改pack未证明的特殊规则。
8. 当前树没有pack所称director_beats；仅接已存在、可确认的非card/event时间入口。

## 边界

不改DIFF.md既有结论或F2占位符；不建APK；不入reference/；未触碰本批以外玩法。

## 中间验证与断点履历

- 第一次修后定向：NUC 四文件 check-only rc=0；88 checks / 2 fails（`c23target1_pull.done` RC=0 files=6 bytes=14453）。两红均是新完整冲刺检查错误地将晕眩结束边界帧的新一轮合法派发计入上一轮占用，读到约5.0/4.6秒；修正结束边界，仍硬断言完整2.5秒（离散步长.02，采样≥2.46）内不被重置。原有判定未放宽。
- `c23_target_sync.log` 在同步期间本地world又有更新，parity报2diff，未放行。随后 `c23_target_sync2.log` TREE PARITY OK (104 files)，此版用于88项定向。
- 后续加强检查、修复reset_all biomes与公共XP入口后，sync3 rc12 Broken pipe；sync4/5/6 rc255 Connection closed。均保留失败日志，不冒充同步完成。
- 本地四文件逐个check-only已过；本地无窗口headless定向未完成（只到场景构造），不计行为验证。随后本地Xvfb定向 `c23_local_gl_target.log` SUMMARY checks=129 fails=0，两次完整cast dizzy_seconds=2.5。

## ① 游戏代码逐处行号清单（当前树；每个差异块均列出）

- `scripts/world.gd:5502`：replace（改前 5502 行）。

```gdscript
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

func run_score(victory: bool) -> float:
	var base: float = round(float(kills * 2) + run_time * 3.0 + damage_dealt / 200.0 + float(zone - 1) * 1500.0 + float(bosses * 800) + (6000.0 if victory else 0.0))
	return base * (1.0 + float(run_tier) * 0.5)

func start_game(p_species: String, boosts: Array = [], requested_tier: int = 0) -> void:
```

- `scripts/world.gd:5539`：insert（改前 5514 行）。

```gdscript
	run_tier = clampi(requested_tier, 0, Profile.biome_tier_cap("forest"))
```

- `scripts/world.gd:5815`：replace（改前 5789 行）。

```gdscript
	return mini(int(round(c * tier_value("cap"))), 60)
```

- `scripts/world.gd:5821`：replace（改前 5795 行）。

```gdscript
	e.setup(species, player, self, hp_mult * tier_value("hp"), scale_mult, is_guardian)
	e.speed *= tier_value("speed")
```

- `scripts/world.gd:5827`：replace（改前 5800 行）。

```gdscript
	e.dmg *= (1.0 + dm * 0.13) * float(STAGE_DMG[zone - 1]) * tier_value("dmg") * (tier_value("late") if zone >= 2 else 1.0)
```

- `scripts/world.gd:5860`：replace（改前 5833 行）。

```gdscript
		var p := 0.012 + (elapsed / 60.0) * 0.004 + float(zone - 1) * 0.03 + tier_value("elite")
```

- `scripts/world.gd:6038`：replace（改前 6011 行）。

```gdscript
	guardian.set_damage_cap(final_hp * tier_value("hp") / (float(BOSS_CAP_DIV[mini(2, zone - 1)]) * o))
```

- `scripts/world.gd:6074`：replace（改前 6047 行）。

```gdscript
	Profile.record_biome_clear(String(ZONES[zone - 1]["tiles"]), run_tier)  # local guardian-clear adaptation; pack §1.2 write site unknown
```

- `scripts/world.gd:7629`：replace（改前 7602 行）。

```gdscript
## at Ze.fury (C23 run-tier ladder), mid-fight escort calls, impatience,
```

- `scripts/world.gd:7631`：replace（改前 7605 行）；删除固定BOSS_TK/BOSS_FURY两常量，其消费者改读tier。

```gdscript
## their bundle numbers. tk = Ze.tele[run_tier].

```

- `scripts/world.gd:7676`：delete（改前 7651 行）。

```gdscript
（删除旧代码）
var _boss_no_hit_t := 0.0
```

- `scripts/world.gd:7677`：delete（改前 7653 行）。

```gdscript
（删除旧代码）
var _boss_last_hp := 0.0
```

- `scripts/world.gd:7699`：delete（改前 7676 行）。

```gdscript
（删除旧代码）
	_boss_no_hit_t = 0.0
```

- `scripts/world.gd:7718`：delete（改前 7696 行）。

```gdscript
（删除旧代码）
	if guardian:
		_boss_last_hp = guardian.hp
```

- `scripts/world.gd:7873`：replace（改前 7853 行）。

```gdscript
			_boss_telegraph_strike(player.global_position + Vector3(off.x, 0, off.y), 3.6, 1.1 * tier_value("tele"), 1.6, Color(1, 0.3, 0.25))
```

- `scripts/world.gd:7898`：replace（改前 7878 行）。

```gdscript
	_boss_hold_t = maxf(_boss_hold_t, 0.75 * tier_value("tele"))
	_later(0.75 * tier_value("tele"), func() -> void:
```

- `scripts/world.gd:7914`：replace（改前 7894 行）。

```gdscript
		_later((0.45 + float(i) * 0.4) * tier_value("tele"), func() -> void:
```

- `scripts/world.gd:7935`：replace（改前 7915 行）。

```gdscript
	_boss_hold_t = maxf(_boss_hold_t, 0.8 * tier_value("tele") + float(n) * 0.55)
```

- `scripts/world.gd:7938`：replace（改前 7918 行）。

```gdscript
		_later(0.8 * tier_value("tele") + float(i) * 0.55, func() -> void:
```

- `scripts/world.gd:7968`：replace（改前 7948 行）。

```gdscript
			_boss_telegraph_strike(tp, 2.6, 1.1 * tier_value("tele"), 1.2, Color(1, 0.5, 0.25)))
```

- `scripts/world.gd:7981`：replace（改前 7961 行）。

```gdscript
		_boss_telegraph_strike(tp, 3.4, tier_value("tele"), 0.0, col)
```

- `scripts/world.gd:7983`：replace（改前 7963 行）。

```gdscript
		_later(tier_value("tele"), func() -> void:
```

- `scripts/world.gd:8004`：replace（改前 7984 行）。

```gdscript
			(1.05 + float(i) * 0.2) * tier_value("tele"), 1.2, col)
	_later((1.2 + (0.2 if enr else 0.0)) * tier_value("tele"), func() -> void:
```

- `scripts/world.gd:8021`：replace（改前 8001 行）。

```gdscript
	var delay := 1.07 * tier_value("tele")
```

- `scripts/world.gd:8049`：replace（改前 8029 行）。

```gdscript
	_boss_line_strike(from, from + dir * len, 1.8, 0.8 * tier_value("tele"), 0.0, col)
	_boss_hold_t = maxf(_boss_hold_t, 0.8 * tier_value("tele"))
	_later(0.8 * tier_value("tele"), func() -> void:
```

- `scripts/world.gd:8096`：replace（改前 8076 行）。

```gdscript
			_later(1.3 * tier_value("tele"), func() -> void:
```

- `scripts/world.gd:8149`：replace（改前 8129 行）。

```gdscript
			var u := 1.2 * tier_value("tele")
```

- `scripts/world.gd:8153`：insert（改前 8133 行）。

```gdscript
			_boss_mech_data["pending"] = true
```

- `scripts/world.gd:8158`：insert（改前 8137 行）。

```gdscript
					_boss_mech_data["pending"] = false
```

- `scripts/world.gd:8161`：replace（改前 8139 行）。

```gdscript
			# C22 estimated cooldown retained; C23 F1 gates dispatch
			# on actual occupancy as this clock may run up to x1.89.
```

- `scripts/world.gd:8246`：replace（改前 8227 行）。

```gdscript
			_boss_telegraph_strike(Vector3(px, 0, pz), 2.2, (0.7 + float(n) * 0.12) * tier_value("tele"), 1.2, Color(0.4, 0.75, 0.85))
```

- `scripts/world.gd:8260`：replace（改前 8241 行）。

```gdscript
	var i := 0.65 * tier_value("tele")
```

- `scripts/world.gd:8333`：replace（改前 8314 行）。

```gdscript
	var o := 1.1 * tier_value("tele")
```

- `scripts/world.gd:8390`：replace（改前 8371 行）。

```gdscript
	var t := run_roars + int(tier_value("escorts"))  # pack §1.1
```

- `scripts/world.gd:8526`：replace（改前 8507 行）。

```gdscript
	if not _boss_enraged and guardian.hp < guardian.max_hp * tier_value("fury"):
```

- `scripts/world.gd:8534`：replace（改前 8515 行）。

```gdscript
	# C23 @1000489: player time since a landed hit, close range only.
	var near := Vector2(player.global_position.x - guardian.global_position.x,
		player.global_position.z - guardian.global_position.z).length() < 30.0
	var s := 0.4 * clampf((player.no_hit_t - 12.0) / 20.0, 0.0, 1.0) if near else 0.0
	if s == 0.0:
```

- `scripts/world.gd:8540`：delete（改前 8520 行）。

```gdscript
（删除旧代码）
	else:
		_boss_no_hit_t += delta
	_boss_last_hp = guardian.hp
	var s := clampf((_boss_no_hit_t - 8.0) / 10.0, 0.0, 1.0) if _boss_no_hit_t > 8.0 else 0.0
```

- `scripts/world.gd:8543`：insert（改前 8527 行）。

```gdscript
	_boss_t -= delta * (1.35 if _boss_enraged else 1.0) * (1.0 + s)
	# C23 F1 adaptation: occupancy follows the actual state, independent
	# of the brain clock's enrage/impatience acceleration. Includes windup.
	if _boss_mech == "starmie" and (bool(_boss_mech_data.get("pending", false))
			or not (_boss_mech_data.get("run", {}) as Dictionary).is_empty()
			or float(_boss_mech_data.get("dizzy", 0.0)) > 0.0):
		return
```

- `scripts/world.gd:8562`：delete（改前 8539 行）。

```gdscript
（删除旧代码）
	_boss_t -= delta * (1.35 if _boss_enraged else 1.0) * (1.0 + s)
```

- `scripts/world.gd:8626`：replace（改前 8604 行）。

```gdscript
					_boss_telegraph_strike(player.global_position, 2.6, 0.45 * tier_value("tele"), 1.3, Color(1, 0.35, 0.3))
```

- `scripts/world.gd:9102`：replace（改前 9080 行）。

```gdscript
			for bi in range(int(ceil(float(3 + zone) * tier_value("events")))):
```

- `scripts/world.gd:10829`：replace（改前 10807 行）。

```gdscript
	var dust := int(round(float(_gold_to_dust(gold)) * (1.0 + float(run_tier) * 0.75)))
```

- `scripts/world.gd:10834`：replace（改前 10812 行）。

```gdscript
	var score := run_score(victory)
```

- `scripts/world.gd:12330`：replace（改前 12308 行）。

```gdscript
		if _alpha_idx < ALPHA_TIMES.size() and elapsed >= tier_timeline_time(float(ALPHA_TIMES[_alpha_idx])):
```

- `scripts/world.gd:12335`：replace（改前 12313 行）。

```gdscript
				if elapsed >= tier_timeline_time(_league_spawn_at):
```

- `scripts/world.gd:12412`：replace（改前 12390 行）。

```gdscript
				rate = maxf(0.05, player.difficulty_mult * player.enemy_amount_mult * tier_value("amount"))
```

- `scripts/world.gd:15143`：replace（改前 15121 行）。

```gdscript
func _fill_result(victory: bool, score: float, dust: int) -> void:
```

- `scripts/world.gd:15158`：replace（改前 15136 行）。

```gdscript
	var c3 := UiTheme.chip("得分 %s" % str(score), Color(0.13, 0.35, 0.55, 0.95))
```

- `scripts/player.gd:510`：replace（改前 510 行）。

```gdscript
	var tier_xp := 1.0 + float(world.get("run_tier")) * 0.15 if world != null else 1.0
	xp += amount * xp_mult * tier_xp
```

- `scripts/player.gd:608`：insert（改前 607 行）。

```gdscript
var no_hit_t := 0.0  # C23: simulated seconds since player last took a landed hit.

```

- `scripts/player.gd:627`：insert（改前 624 行）。

```gdscript
	no_hit_t += delta
```

- `scripts/player.gd:957`：insert（改前 953 行）。

```gdscript
	no_hit_t = 0.0
```

- `scripts/player.gd:996`：insert（改前 991 行）。

```gdscript
	no_hit_t = 0.0
```

- `scripts/profile.gd:60`：replace（改前 60 行）。

```gdscript
const PROFILE_VERSION := 3
```

- `scripts/profile.gd:102`：insert（改前 102 行）。

```gdscript
	# C23: old tier counters already encoded Normal clear as 1.
	if not (data.get("biomes") is Dictionary):
		data["biomes"] = {"forest": 0}
	for biome in BIOME_ORDER:
		var legacy := int(data["counters"].get("tier_" + biome, -1))
		if legacy >= 1:
			data["biomes"][biome] = maxi(int(data["biomes"].get(biome, -1)), legacy)
```

- `scripts/profile.gd:331`：insert（改前 324 行）。

```gdscript
	if counter.begins_with("tier_"):
		return float(maxi(0, biome_tier(counter.trim_prefix("tier_"))))
	if counter in ["hard", "night"]:
		var total := 0
		for biome in BIOME_ORDER:
			if biome_tier(biome) >= (2 if counter == "hard" else 3):
				total += 1
		return float(total)
```

- `scripts/profile.gd:780`：replace（改前 765 行）。

```gdscript
		"settings": {}, "bag": {}, "shinies": [], "shiny_bond": false, "items_off": [], "biomes": {"forest":0},
```

- `scripts/profile.gd:784`：insert（改前 769 行）。

```gdscript

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
```


- `c23_target_sync7.log` 于23:53:41 TREE PARITY OK (104 files)，diffs=0；最终NUC `setsid bash Test/c23_batch.sh` 脱离启动，launcher `c23_final_launcher.log`。未动树中代码，等待最终批处理各阶段完成。

## 最终运行树指纹（代码冻结于NUC最终批处理启动前）

```text
5bae41bcfb91020d30e98c5c52781b78b24131190e9f95a1ba76015f0a0b4142  scripts/world.gd
ad5bf06ba7afb28bc101d2474be6f59e2d6457279424a1a825f3e0393051e138  scripts/player.gd
f23c5a21710c8a9f3f0652d4c67d19e10599dcaa5d3144ba1f277304f0cf5c5b  scripts/profile.gd
448d1848d9c40323e80cf2765197c835bba2f3513d2f3a696e0bbe59e633c7ad  Test/harness.gd
9f73cfea5a76f9dd08b676fdcd88038f538597cbf4b21a91438ac448c1ea6ac3  Test/c23_batch.sh
```

DIFF.md收尾前对照sha256：`30d976ea328b84c616b843a49c741fd60a09a60045180a13cffcccc3b6affad4`。不修改其中既有结论。

- NUC最终批处理第一阶段：四文件check-only各rc=0；定向 SUMMARY checks=129 fails=0，target rc=0；已进入全量suite。后续数字待 .done 落盘。

- 冻结树只读复审：游戏代码逐差异块58/58均列入清单（world48、player5、profile5）；新增129项检查未发现剩余明显断言错误。此为同池独立只读复审，非官方Claude外审。

- NUC最终全量 `c23_suite.log`：SUMMARY checks=643 fails=0，suite rc=0（原514+新129）；未见SCRIPT ERROR。正在等待bootsmoke及两组phonehud，不提前宣告最终批处理结束。

- 核心结果已核验拉回：`c23core_pull.done` RC=0 files=8 bytes=286731。包括定向129/0、全量643/0、四文件解析日志、bootsmoke原始与wrapper日志。bootsmoke EXPORT_DONE rc=0，ALIVE_AT_75S，SCRIPT ERROR=0，wrapper rc=0。
- phonehud a（phone 2400x1080 s1.00 i0）：PHONEHUD DONE checks=1651 fails=0，rc=0；s070 i0已启动，继续等待最终ALLDONE。

- 因 `/home/hatch/AGENTS.md` 明确要求成品验证在中立目录运行，补充neutral smoke（原check_bootsmoke脚本仍按要求执行且rc=0）。此项不改游戏代码，原五文件冻结sha256保持一致；新shell脚本纳入最终同步/parity与检查清单。

- NUC主批处理已于2026-11-07 00:35:49 +08:00 ALLDONE：check-only四文件rc=0，target rc=0，suite rc=0，bootsmoke rc=0，phonehud a rc=0（1651/0），s070_i0 rc=0（1626/0）。所有阶段已完成，不留后台未完阶段。
- 新增neutral脚本后，`c23_neutral_sync.log` TREE PARITY OK (105 files)，diffs=0（00:37:15）。neutral通过setsid单独启动，等待其.done与证据拉回。

## 最终验证汇总

| 门 | 结果 | 证据 |
|---|---|---|
| 改前红基线 | 13 checks / 9 fails，rc=1 | c23_red.log / c23_red.done |
| 四文件逐个check-only | world/player/profile/harness各rc=0 | c23_check_*.log / c23_batch.done |
| 修后定向 | 129 / 0，rc=0 | c23_target.log |
| 全量suite | 643 / 0，rc=0 | c23_suite.log |
| bootsmoke（既有脚本） | rc=0，EXPORT_DONE0，ALIVE_AT_75S，0 SCRIPT ERROR | c23_bootsmoke_wrap.log / bootsmoke_ubantu.log |
| 中立目录Linux成品 | rc=0，alive=1，script_errors=0，ALLDONE | c23_neutral_smoke.log / .done |
| phonehud a | 1651 / 0，rc=0 | c23_phonehud_a.log |
| phonehud s070 i0 | 1626 / 0，rc=0 | c23_phonehud_s070_i0.log |

- 主批处理最终ALLDONE：2026-11-07T00:35:49+08:00；中立目录冒烟独立.done也已ALLDONE。没有用启动器返回代替测试结束。
- 最终phonehud拉回：`c23final_pull.done` RC=0 files=5 bytes=9048972，包括最终批处理.done、两日志、两张主HUD PNG；与核心8文件286731字节分批核验。
- 已目视两张主HUD PNG（s100/i0与s070/i0）：HP/守护者/alpha条、地图、目标卡、左下槽位和右下触控未见明显裁切或控件互盖；数值判定均沿用未修改的phonehud.gd。
- `DIFF.md`未改；未建APK；未新增reference/。游戏代码清单58个差异块与检查清单分开记录。

- 中立成品证据已核验拉回：`c23neutral_pull.done` RC=0 files=2 bytes=713；实际CWD `/tmp/c23-neutral.UADUN9`（脚本结束已清理其副本），NEUTRAL_ALIVE_AT_75S / NEUTRAL_END rc=0。
- 新增检查脚本指纹：`94ecc973033bf5c08601eaf7f49a08e5a4dd002d1b961c147b1edace15790850  Test/c23_neutral_smoke.sh`。六文件收尾sha256 -c均OK，DIFF.md仍为上列原哈希。

- 收尾同步 `c23_close_sync.log`：2026-11-07 00:41:17，TREE PARITY OK (105 files)，local=105 nuc=105 diffs=0。记录最后补入此实测结果后再走一次既有sync脚本同步文档，游戏/检查脚本指纹不变。

## 主控裁定（2026-11-07 16:1x，关账）

- 待核 2/3/4 三项经对照 pack 原文复核，**裁定为真规格缺口、非施工停早**：wound 在 pack 中唯一实证作用点位于 §5 护盾公式（`woundT > 0` 时回盾减半），其施加点未证；strike 仅有两处 floor 偏移与倍率；alphaCap1 只有上限、无基础概率公式。施工方保留精确表值、不发明消费者的处置正确，本批按「已证部分全落地」关账。
- 处置：三项并入 C23B 前置补证挖掘（已知偏移定点提取 woundT 施加点、strike 两处分派全公式与 hurt() caps、director stage-1 alpha 基础概率）；wound 随护盾系统同批施工（其天然归属）。
- 本批验收数字（00:35 ALLDONE）：定向 129/0、全量 suite 643/0、bootsmoke rc=0、成品冒烟 rc=0、phonehud a 1651/0 / s070 i0 1626/0、TREE PARITY 105 文件。
