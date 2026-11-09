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

# C23B 施工子批 B1（2026-11-09）

规格前置：完整读取 pack 与 addendum；本段续写，不改 C23A 关账裁定。addendum 纠正 alphaCap1 为伤害上限，原A关于生成概率的历史描述仅为历史记录。禁止新增 alpha 概率门；逐招 mul/n/out_dmg 上游等价仍 UNPROVEN。

## B1 进度与红基线

**B1 已完成实现与最终验收**：13种拾取物、shield/wound、strike完整管线、alphaCap1伤害cap均落地。最终suite645/0、bootsmoke rc0，全部长跑已等到ALLDONE；详细数字与边界见本段末尾。此前按工作区协作约定进行的实现/检查与同池只读复审为施工履历，不冒充官方 Claude 审计。

- 拾取改前：`c23b_pickups_red.log` 1/1（缺 manager，后续扩展确定性数值检查）。
- 伤害改前：`c23b_damage_red.log` 12/12，API 守卫后才进入行为检查，缺实现不会以解析错误冒充行为红。
- 首轮伤害 79/1：water-veil 缺少 pack 已证 shieldMax15，补数据后扩展至143/0。
- 复审新增记账检查改前：`c23b_bookkeeping_red.log`145/2，命中睡眠未清/缺独立来源归因；`c23b_contact_red.log`146/3 含缺 contact_reaches。随后修复，等待最终定向重验。

## B1 游戏代码变更（与检查分列，持续补全）

- `scripts/player.gd`：8种被动 shieldMax 的公共 recalc 消费者，shield/overheal/wound/guard 与 noHit 计时；alive simulated tick中 wound/pop可递减为负，回盾严格 noHit>3，.25 shieldMax/s，wound有效时减半。heal与leech共用 healing×wound，fresh-water存储及overheal基于减半后的有效治疗；直接赋HP不扩推wound。HUD纯getter按maxHp分母、shield+overheal>1时追加+round。
- `scripts/player.gd`：take_damage返回命中布尔；type clamp→armor→ability dmgTaken→magic-guard非接触.7→multiscale满血.5容差→可选hurtMod→折算floor→cap→TM iron.4→overheal→shield→HP。全吸收仍清sleep/重置noHit/iframes并成功；guard-spec全挡/闪避/无敌为false。独立source与attacker字段，HP损伤才更新last_hit，接触反伤只source>=0。
- `assets/data/abilities.json`：补 pack指定 water-veil +15 shieldMax，保留其他已存在数据。
- `scripts/world.gd`：Sp alpha_hurt_cap用于主体碰与Alpha hostile；Capped优先.15/.02*S；主体碰Boss floor.05*S、Alpha优先cap；qy floor>=.3不乘tier，其余乘strike，evade.5。_boss_strike对接Nb/ix结构，经miniboss_strike成功施wound4/5/6并成功才shove；独立legendary_hurt保留Yy负frac关闭floor/wound与>=.3 cap.6规则，Nb/ix维持.34。_boss_shot带Capped及来源。honey时间事件经early提前。
- `scripts/world.gd`：新增shield HUD层与wound数值颜色；新层随phone布局高度调整。
- `scripts/enemy.gd`：主体碰接独立hurt分派，Capture/Treasure/Object/不可行动门、radius+Player.RADIUS与高度严格门、成功才shove。body_height按现有3D模型height×scale适配，未宣称sprite atlas尺寸等价。

## B1 检查代码变更（与游戏代码分列，持续补全）

- `Test/c23_damage.gd`：独立SceneTree数值回归，所有防御与伤害公式、8来源实际recalc、三tier分派与三wrapper、全盾/false返回、HUD口径、归因与几何边界；详见后续最终数字。
- `Test/c23_pickups.gd`：独立拾取实体/生命周期/合并/分派/范围效果检查，详见后续最终数字。
- `Test/c23b_batch.sh`：新NUC脱离批处理，逐改动脚本check-only、两新定向、既有完整suite、bootsmoke与中立成品冒烟、phonehud a与s070 i0；ALLDONE前不算交付。

## B1 规格边界 / 待核

- `_boss_strike`仅集中管线与Nb结构对应。既有每招mul/n、guardian.out_dmg上游倍率未逐招重审，不宣称数值等价，不按看似接近的倍率猜原作n。
- 当前无原作Yy传奇类/ix敌人系统、co-op proxy、tower/endless玩法。提供已证wrapper数据路径，不伪造新模式或把新增Yy helper声称既有招式全接。endless布尔只为Sp cap情境，不新增玩法；未实现模式的来源不冒充已运行验证。
- 直接赋HP的恢复、既有hurt_fixed固定路径未证可等价改入本hurt链，保留原路径，不无证推广wound或shield规则。
- DIFF.md保持原SHA256 `30d976ea328b84c616b843a49c741fd60a09a60045180a13cffcccc3b6affad4`；不建APK，不入reference。

- 弹体补充红基线 `c23b_hostile_red.log`161/1（缺几何API）；修后伤害独立检查 `c23b_damage_final.log`166/0、rc=0，check-only rc=0。新增`hostile_reaches`并接实际boss shot：半径和严格高度门、保持弹道高度、先terrain挡；当前无sanctuary cover系统，不虚构消费者。
- 实际隔离mutation：复制player与测试至.tmp（不改原实现），floor折扣系数.35→0，核心66项中2项准确失败（HP92而非94.52/94.8），`c23b_damage_mutant.done`rc=1，证明检查对公式变异敏感。
- 工作区约定的Claude独立审计已尝试，`c23b_claude_audit.done`rc=1 ALLDONE；CLI返回“Failed to authenticate. API Error: 403 Insufficient account balance”。未充值/改信任配置；此轮只能计同池只读复审，不能声称官方Claude审计通过。此为审计通道欠账，不是suite成功证据。

## B1 拾取物完整变更补记（游戏代码）

- 新` scripts/pickups.gd`：13种、2500容量、共享网格实体；寿命60/120/无限、末8秒闪烁；随机水平1–3.5/vy4–7，落地+0.6、静止/激活；age>.35后range吸引、16+age×6速度及9/s lerp、dist<.9收集；xp>500/coin>200同种近4u合并、总量>1800或远距dist²>3600回收并重置速度/age/rest；总量>260时每1.2s按3.5格、格内xp>240/coin>100合并。
- manager分派：xp及.45声音链、coin记账及.4s浮字批次、heal计berries并heal25%maxHp、magnet4×powerup、bomb28u普通1e9/特殊8%maxHp/Object跳过/knock6、repel20u knock40×resist及stun1.5×resist、candy整级、chestkey仅counter；swords伤害1.5×10s、agility移动1.35/攻速1.3×10s、iron8s、payday金币2×15s，时长×powerup；thunder40u stun4×powerup。
- manager来源：击杀XP实体；goldFrac .2×gold×weight、floor后落coin；heal .006×powerup×weight；powerUp .0018×luckMult×powerup×weight，间隔max(18,40/powerup)，bomb冷却120；Alpha糖果；预留4096/8192敌人旗标糖果+金币bundle；harvest每15秒heal；sky首次55–75s/后续70–95s，22–38u且距玩家≥15，65%+22胸箱（15%super_ball标记）/35%+16 pickup池，mewtwo事件门。
- `scripts/world.gd`：lazy manager、spawn/count入口、run keys及开局清池；仅running&&!hitstop时tick；击杀改落实体，streak≥25magnet4；guardian20×ceil(5×stage×gold) coins+candy，Meowth命中/死亡金币实体、rock15%luck三选实体；PROP_PLAN增加magnet×2、primitive外观/提示/交互used并magnet5；supply宝箱落地前禁交互，保留super_ball标记而不猜不同奖励算法。
- `scripts/player.gd`：pickup_range6、powerup_mult1、timed_buffs及激活/到期recalc；已证passive/item pickupRange/powerup消费者、Lab magnet .6/level与已有bug level字段+1；按pack修正beacon2/static-wool3/magneton pickup4。未虚构当前缺失的bug维生素producer。
- `scripts/enemy.gd`：weight1（当前无swarm聚合），pickup_fixed_damage绕过普通combat倍率/cap而保留lethal/capture路由；并行pickup_stun_t，无自主行动；为repel修正pickup-only stun仍立刻积分knockback并衰减。重叠旧root/sleep/freeze保留旧门控，本批未扩改其他状态政策。
- `scripts/profile.gd`：Lab magnet fx=true，已有live消费者。

## B1 检查变更补记

- 新`Test/c23_pickups_mutations.py`：隔离.tmp源变异，heal/bomb/repel/thunder/magnet/expiry/gold/motion/merge九类变异逐一要求rc1且断言FAIL且无SCRIPT ERROR；不修改游戏原实现。9/9检出，日志`c23b_pickups_mutations.log`。
- `Test/c23_pickups.gd`：最终本地38/0，含真实Enemy physics；repel位移/衰减检查先跑`c23b_pickups_impulse_red.log`37/2，再修后38/0。逐enemy/test check-only rc0。
- `Test/c23_damage.gd`：追加真实_hostile_process驱动追逐检查，改前`c23b_chase_red.log`169/2；游戏只把追逐停止阈值从1.35改为radius+Player.RADIUS，修后`c23b_chase_green.log`169/0、enemy/test check-only均0，ALLDONE。
- `Test/harness.gd`：guardian/c20金币检查改核pending实体金额，仍精确20×ceil；candy检查实体等待收集；c22 Meowth检查pending实体并精确包含goldFrac floor滴落；音频检查由击杀后将XP实体放入收集半径验证拾取声，pop/streak保留；props预期54/16、magnet2及真实交互used/magnetAll5；新增实体求和/收集fixture helpers。
- `Test/c23b_batch.sh`：完整逐脚本解析加入profile与新测试；新增隔离pickup mutation gate；bootsmoke前删除指定旧Linux产物，必须重新导出，不能让旧成品冒充本树。无APK步骤。

## B1 新发现的原料冲突（待主控裁定，未替换派单口径）

以pack/addendum为施工权威。施工代理定点复核同哈希原料时发现下述摘要差异，本次保持pack口径，不擅自扩大授权：

1. spawnMerged main @504099附近原文`if(this.count>(e===0?500:200))`为全池数量门；pack写同种数量，本次按同种。
2. consolidate @511750原文先全池alive&&!attract计xp/coin，`let n=e>240,r=t>100`后格合并；pack写in cell，本次按格内数量门。
3. update @505600附近到期为`age>dh && !attract`；pack未列已吸引豁免，本次按有限寿命。
4. repel @1455400 knock的i为Boss|Summoner?.05:flags12290?.2:1，但stun另用combat.resist；@731082该值为Boss .35 / flags12290 .6 / else1。pack写统一resist，本次统一.05/.2/1。
5. pack给thunder的secs但未写常量；其明确引用tp表 @314400补得secs=4（实现必需值）。原料同段另有status resist/para+1，pack未要求，不接。
6. pack给miniboss金币bundle但省数量，所引用main @1032925–1033450连续原文补得totem10/summoner8 coins，each=ceil((3+stage×3)×gold)，仅预留flags分派；现无对应敌人身体，不虚构运行覆盖。
7. tower/sanctuary与proxy不存在，未造新模式；super_ball仅分类标记，pack未证单独奖励消费者，保留现通用宝箱策略；chestkey保持reserved。

## B1 冻结树逐处清单（游戏/检查分开）

### 游戏代码
- `scripts/pickups.gd:1`：新增完整文件，276行。
- `scripts/player.gd`：全部22个差异块的新树起始行 136, 248, 255, 282, 286, 398, 406, 606, 622, 627, 652, 666, 688, 719, 1058, 1060, 1071, 1087, 1091, 1116, 1126, 1146。各块功能列于上方分项，无遗漏脚本。
- `scripts/enemy.gd`：全部14个差异块的新树起始行 42, 53, 78, 168, 383, 428, 460, 466, 470, 532, 557, 564, 566, 687。各块功能列于上方分项，无遗漏脚本。
- `scripts/world.gd`：全部28个差异块的新树起始行 479, 2892, 5525, 5585, 5628, 6018, 6026, 6028, 6155, 6317, 6546, 7788, 7790, 7795, 7826, 8502, 9099, 9108, 9398, 9458, 9474, 10262, 10317, 11874, 12300, 12408, 12507, 13693。各块功能列于上方分项，无遗漏脚本。
- `scripts/profile.gd`：全部1个差异块的新树起始行 31。各块功能列于上方分项，无遗漏脚本。
- `assets/data/abilities.json`：全部1个差异块的新树起始行 1301。各块功能列于上方分项，无遗漏脚本。

### 检查代码
- `Test/harness.gd`：全部22个差异块的新树起始行 1007, 1009, 1014, 1017, 1019, 1024, 1187, 1190, 1212, 1218, 2772, 2774, 2778, 2781, 3338, 3349, 3354, 3356, 5247, 5250, 5256, 5703。各块功能列于上方分项，无遗漏脚本。
- `Test/c23_damage.gd:1`：新增完整文件，410行。
- `Test/c23_pickups.gd:1`：新增完整文件，241行。
- `Test/c23_pickups_mutations.py:1`：新增完整文件，36行。
- `Test/c23b_batch.sh:1`：新增完整文件，37行。

### 冻结SHA-256

```text
68e76adc03b29a36338549eeab7d9f23b77243f9f10fd01066bfd3059cdfa043  scripts/pickups.gd
ee5e5bdcdeb4bfaa012638511e82dbceac05e86eab9385fbc0c3f7646122f41e  scripts/player.gd
eaf905ce4b41e51767e31b092d56004e94fa223e749d38599028cc432ff02928  scripts/enemy.gd
223b0cec773817276c23f9d5291061a6cc1470de57b00ee39a7f6e8a55420be0  scripts/world.gd
92aa30c2ac9b569923849993e5c756878d80e50860943fd4f5aa4e3153e630e1  scripts/profile.gd
2d65019db7ca0ce9e86dc719c7f1cf822abf16bb65fbfa567bdfb136bbbbf691  assets/data/abilities.json
333863bc2c2d3937d76765b9ddbb21702ae97303262a46eec459271153d4ce36  Test/harness.gd
9c4a5cb96ace6ac5c3925a6f12ace718a0a5191632c5d96cc1bd103455aea0bf  Test/c23_damage.gd
91a110df512d9c8b3389c51b6651e44178b7c2f4e05e30dcecacd9d6bae44a36  Test/c23_pickups.gd
562373b3075fd824b075facd5d74fe0b10ace5f33e921c7f698006f02936ac87  Test/c23_pickups_mutations.py
7a191eab27358a2345b72dc6819067f76ad4a29f78227b596c03f32f160b8ffb  Test/c23b_batch.sh
```

- 冻结同步 `c23b_sync1.log`：TREE PARITY OK (110 files)，local=110 nuc=110 diffs=0；随后NUC通过setsid脱离启动`Test/c23b_batch.sh`，launcher日志`c23b_launcher.log`。八文件check-only各0，damage/pickups及九类mutation gate均0，已进入全量suite。正在等`.done`最终ALLDONE，不以启动器rc代替结束。
- 11个冻结代码/检查文件SHA256逐个再核均OK；DIFF.md仍为原哈希。

## B1 全量首轮发现 / 检查补强

- NUC首轮suite运行中捕获 `shrine: chests == 1 + roars after the kill :: spawned=5`：新增合法55–75s天空补给在长战斗期间增加一箱，旧fixture把整场新增箱数当守护者同步奖励。已据真实红签名修harness两处guardian/shrine为致死take_damage调用前后同步delta，仍精确要求1+roars/4，不禁补给、不放宽断言。`c23b_chest_check_harness.log`及`...world.log`均check-only0（world只更新失实的旧直接付金币注释）。首轮未中断，继续等ALLDONE收齐签名后重跑。
- 额外检查源码：新`Test/c23_pickup_stats.gd`，真实Player.recalc 50/0，新增脚本check-only0，`.done`check=0/run=0/ALLDONE。覆盖基础range6、7种passive、honey/exp-share与叠加、Lab .6/level、bug level字段+1、三TM真实倍率/重算不累加/精确到期/分批共存到期恢复；不启动world/rig，不写profile，临时cache和内存均恢复。
- 隔离stat mutation：Lab .6→.5，50/4（Lab1/3/5与叠加检查红）；swords1.5→1.4，50/3（live/recalc/到期前红），`c23b_pickup_stats_mutants.done`lab=1/swords=1/ALLDONE，原游戏未改。
- NUC核心证据已核验拉回：`c23bcore_pull.done` RC=0 files=11 bytes=1035；八解析日志+damage169/0+pickups38/0+九类mutation9/9全部落盘，未拉取尚在增长的suite/done冒充最终证据。

- 首轮第二个红签名：`audio: guardian death plays boom + coin :: boom=38/37 coin=2/2 frames=1`，旧断言把拾取声要求在死亡时响。harness已拆成死亡即时boom与真实金币实体收集后的coin严格增量，走manager.tick收集，不直接调audio.coin伪造。检查数因此+1。`c23b_coin_audio_check_harness.log`check-only0；首轮其他阶段继续等ALLDONE。

- 首轮第三个红签名：`c19: banner + backing show in play :: state=choice ... modals=choice scrim=true`。新增落地奖励使真实宝箱choice可在长fixture期间出现，旧banner探针只结清draft。检查改用现有`_c21_settle_modals`真实选项路径，在探针前/重试时结清choice+draft；原≥2渲染帧后的banner/backing alpha1、无modal且scrim隐藏等所有合取断言保持。`c23b_banner_check_harness.log`解析rc0。

## B1 接续验收（2026-11-09）

- 接续时工作区已有上述实现与首轮NUC批处理；保留原改动与证据，不重置工作树。首轮suite实际结束644/4、rc=1，四签名为shrine箱数、guardian coin音效、c19 banner modal、c22 meowth逃离。前三项检查修正见上文。
- 检查代码补充：`Test/harness.gd` meowth逃离探针固定起点为玩家旁6u，再走真实1秒模拟并保留原`d1>d0+1.5`断言。首轮随机起点17.6934u在18u处按既有游戏规则转为切向，不能要求继续径向远离1.5u；游戏逃离代码未改。改后harness check-only rc=0，日志`c23b_meowth_check.log`。
- 检查代码补充：`Test/c23b_batch.sh` 加入`Test/c23_pickup_stats.gd`逐脚本check-only与50项实际recalc检查；bash -n rc=0。此接续段无新增游戏代码改动。
- 首轮bootsmoke rc=0、中立成品冒烟rc=0已结束，phonehud仍在运行；待ALLDONE后保存完整首轮证据再同步最终树。不将首轮结果算作最终通过。

## B1 最终验收树补记

- 检查代码：批处理支持 `C23B_PREFIX` 独立日志前缀，最终轮为 `c23b_final`；首轮日志不覆盖。shell语法检查通过。
- 本地C22定向 `c23b_meowth_target.done` rc=0 ALLDONE；51/0，逃离距离6.00099→12.49776u。
- 最终同步 `c23b_final_sync.log` TREE PARITY OK（111文件，diffs=0）。NUC setsid最终轮九文件check-only全部0；damage169/0、pickups38/0、pickup_stats50/0、mutation9/9，完整suite及后续门禁运行中。
- 接续同步与首轮phonehud存在时间重叠：游戏行为文件与首轮冻结树相同（world仅注释变动），其余变化为harness、批处理与记录；首轮已加载的phonehud未被中断，最终轮独立重复全部门禁。

最终12个代码/检查文件SHA-256（后续不再改动这些文件）：

```text
68e76adc03b29a36338549eeab7d9f23b77243f9f10fd01066bfd3059cdfa043  scripts/pickups.gd
ee5e5bdcdeb4bfaa012638511e82dbceac05e86eab9385fbc0c3f7646122f41e  scripts/player.gd
eaf905ce4b41e51767e31b092d56004e94fa223e749d38599028cc432ff02928  scripts/enemy.gd
4984370f7dffaddef5c1aa7756ddd59247c0000c74222ee4b1f62a404a156312  scripts/world.gd
92aa30c2ac9b569923849993e5c756878d80e50860943fd4f5aa4e3153e630e1  scripts/profile.gd
2d65019db7ca0ce9e86dc719c7f1cf822abf16bb65fbfa567bdfb136bbbbf691  assets/data/abilities.json
a4265c3065cdbb3628257d3a9a17a2d15c56c30a43a4dc7eedb41463650c4ddc  Test/harness.gd
9c4a5cb96ace6ac5c3925a6f12ace718a0a5191632c5d96cc1bd103455aea0bf  Test/c23_damage.gd
91a110df512d9c8b3389c51b6651e44178b7c2f4e05e30dcecacd9d6bae44a36  Test/c23_pickups.gd
146e3e14c3e327e870804b916bcbc5c030831680a23e5198fce1ae47626181af  Test/c23_pickup_stats.gd
562373b3075fd824b075facd5d74fe0b10ace5f33e921c7f698006f02936ac87  Test/c23_pickups_mutations.py
17b3be9c4057829fcb7e3834057be594a0efc0c65c5e46c93daab04e2c99c9c4  Test/c23b_batch.sh
```

- 首轮NUC已等到`c23b_batch.done` ALLDONE（2026-11-09T01:38:50+08:00）：suite644/4、rc1；bootsmoke0、neutral0；phonehud a1635/0、s070_i0 1626/0均rc0。四个首轮失败签名及修正已逐条记录；未抹除首轮结果。
- 最终NUC suite `c23b_final_suite.log` **645/0、rc=0**；神龛同步4箱、guardian真实金币收集音、banner模态结清、meowth6.093→12.330u四签名均绿。未见SCRIPT ERROR。仍有一条`Lambda capture at index 0 was freed`引擎诊断（既有`c22_suite_ubantu.log`/`c22_suite2_ubantu.log`同签名）及退出资源泄漏诊断，不冒充断言失败，不扩改本批外生命周期。
- 最终bootsmoke rc0（新Linux导出，ALIVE_AT_75S，0 SCRIPT ERROR）；最终中立成品冒烟rc0、alive1/script_errors0、ALLDONE。最终phonehud运行中，继续等最终批ALLDONE。
- 中间拉回使用`rsync -az`保留属主失败rc23，未记成功；随后`-rtz --no-owner --no-group`重拉已结束suite与首轮phonehud日志rc0。收尾仍走既有`Test/pull_from_nuc.sh`清单/大小核验。


## B1 最终交付状态（2026-11-09，全部长跑结束）

最终批 `Test/out/c23b_final_batch.done` 已到 **ALLDONE 2026-11-09T02:05:05+08:00**，不是启动器成功标记。上述“运行中/等待”条目均为中间履历，现已结束，无遗留后台施工任务。

| 最终门禁 | 结果 | 本地证据 |
|---|---|---|
| 改动GDScript逐个check-only（9个） | 全部rc=0 | c23b_final_check_*.log |
| 伤害/护盾/wound/strike/Alpha | 169/0，rc=0 | c23b_final_damage.log |
| 拾取实体/分派/运动 | 38/0，rc=0 | c23b_final_pickups.log |
| 实际拾取属性与TM重算 | 50/0，rc=0 | c23b_final_pickup_stats.log |
| 拾取隔离mutation | 9/9检出，missed=0，rc=0 | c23b_final_pickups_mutations.log |
| 全量suite | **645/0，rc=0** | c23b_final_suite.log |
| 新Linux成品bootsmoke | **rc=0**，75s存活，0 SCRIPT ERROR | bootsmoke_ubantu.log |
| 中立目录成品冒烟 | rc=0，75s存活，0 SCRIPT ERROR，ALLDONE | c23_neutral_smoke.log/.done |
| phonehud a（2400×1080，s100，i0） | **1635/0，rc=0** | c23b_final_phonehud_a.log |
| phonehud s070 i0 | **1642/0，rc=0** | c23b_final_phonehud_s070_i0.log |

- 核心证据既有脚本核验：`c23b_finalcore_pull.done` RC=0 files=19 bytes=221245。两张本轮HUD起始截图已目视检查HP、顶栏、触控布局，未见本批新增遮挡；`c23b_finalshots_pull.done` RC=0 files=2 bytes=8048057。两截图属于正常初始无盾角色，不冒充shield/wound视觉触发覆盖；其数值与HUD口径由169项定向验证。
- 四项均已按已证边界落地；无未解决的本批suite失败。`_boss_strike`逐招mul/n及out_dmg上游等价仍待核，未证部分未猜接；无proxy/tower/endless新玩法。原料与pack摘要差异清单保留供主控裁定。
- 游戏代码与检查代码完整分列见上方清单，接续无新增游戏行为。DIFF.md原哈希不变；未建APK，未新增reference内容。

- 最终完整证据拉回：`c23b_close_pull.done` **RC=0 files=33 bytes=3488659**；已核验最终DONE、两个phonehud及保留的首轮失败日志。最终12个代码/检查文件SHA逐个再核12/12 OK。
- 收尾既有同步脚本`c23b_close_sync.log`成功：2026-11-09 02:06:53 CST，**TREE PARITY OK（111文件，local=111/nuc=111/diffs=0）**。最终`git diff --check`通过，DIFF.md哈希再次与原值一致。

## C23A+B1 验收包构建记录（2026-11-09，主控）

- 构建：NUC 上 `android/build_apk.sh` rc=0（树 = 提交 f7314a1，TREE PARITY 111 文件 diffs=0）。
- 产物：57,745,641 B，sha256 `99ec69678c2e9dc3339b8a8440107bf0aae24e89c9b65a7c64803a150e525b17`；签名证书 b05b80e1…a232；内容审计 706 条目、reference/=0、Test/=0。
- 定位：C23A+B1 验收包（非上架包，占位 IP 未换皮）；已交付用户下载试玩。
