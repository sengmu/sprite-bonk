package com.example.game.model

import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Color
import com.example.R
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.RarityCommon
import com.example.ui.theme.RarityEpic
import com.example.ui.theme.RarityLegendary
import com.example.ui.theme.RarityRare
import com.example.ui.theme.RarityUncommon
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.TypeFire
import com.example.ui.theme.TypeGhost
import com.example.ui.theme.TypeGrass
import com.example.ui.theme.TypeGround
import com.example.ui.theme.TypePoison
import com.example.ui.theme.TypeRock
import com.example.ui.theme.TypeWater
import com.example.ui.theme.WarmOrange
import kotlin.math.pow
import kotlin.math.roundToInt

enum class ElementType(val zhName: String, val color: Color) {
    GRASS("草系", TypeGrass),
    FIRE("火系", TypeFire),
    WATER("水系", TypeWater),
    ELECTRIC("电系", Color(0xFFF5C428)),
    GHOST("幽灵", TypeGhost),
    STAR("星辰", Color(0xFF7B6CFF)),
    GROUND("地面", TypeGround),
    ROCK("岩石", TypeRock),
    POISON("毒系", TypePoison)
}

enum class GameMode(val id: String, val nameZh: String, val subtitleZh: String) {
    CLASSIC("classic", "经典群落", "探索传送门与圣坛，击败区域守护者通关"),
    SURVIVAL("survival", "无尽生存", "敌潮与守护者无限递增，冲击最高存活纪录"),
    DUEL("duel", "守护者决斗", "开局自选双轮构筑，1v1 速战多阶段守护者");

    companion object {
        fun fromId(id: String): GameMode = entries.firstOrNull { it.id == id } ?: CLASSIC
    }
}

data class MoveSynergyDef(
    val moveId: String,
    val vitaminId: String,
    val evolvedNameZh: String,
    val bonusDescZh: String
)

enum class MoveArchetype {
    STRIKE,      // Short-range whip / slam / cleave
    PROJECTILE,  // Targeted or multi-shot elemental bolts
    NOVA,        // Expanding radial status ring
    BEAM,        // Piercing high-damage directional laser/jet
    ORBIT        // Rapid spinning blades/water-ring around hero
}

enum class Rarity(val zhName: String, val multiplier: Float, val color: Color) {
    COMMON("普通", 1.0f, RarityCommon),
    UNCOMMON("优秀", 1.2f, RarityUncommon),
    RARE("稀有", 1.45f, RarityRare),
    EPIC("史诗", 1.75f, RarityEpic),
    LEGENDARY("传说", 2.1f, RarityLegendary)
}

data class MoveDef(
    val id: String,
    val nameZh: String,
    val type: ElementType,
    val archetype: MoveArchetype,
    val baseDamage: Float,
    val cooldownSec: Float,
    val rangeWorld: Float,
    val descZh: String,
    val slowsEnemy: Boolean = false,
    val burnsEnemy: Boolean = false,
    val knockback: Float = 85f
)

data class VitaminDef(
    val id: String,
    val nameZh: String,
    val shortEffectZh: String,
    val perLevel: Float,
    val isPercent: Boolean,
    val statKey: String
)

data class StarterLine(
    val id: String,
    val codeName: String,
    val stageNames: List<String>,
    val roleZh: String,
    val element: ElementType,
    val passiveNameZh: String,
    val passiveDescZh: String,
    val loreZh: String,
    val baseHp: Float,
    val baseSpeed: Float,
    val baseDamage: Float,
    val baseArmor: Float,
    val signatureMoves: List<String>,
    val ultStageNames: List<String>,
    val ultDescZh: String,
    val bodyPrimaryColor: Color,
    val bodyAccentColor: Color,
    @DrawableRes val portraitRes: Int
)

data class BiomeDef(
    val id: String,
    val nameZh: String,
    val subtitleZh: String,
    val orderIndex: Int,
    val groundBase: Color,
    val groundAlt: Color,
    val pathColor: Color,
    val accentColor: Color,
    val bossId: String,
    val bossNameZh: String,
    val enemyPool: List<String>,
    val difficultyScale: Float,
    val stardustBonus: Int
)

data class EnemyDef(
    val id: String,
    val nameZh: String,
    val element: ElementType,
    val isBoss: Boolean,
    val baseHp: Float,
    val speed: Float,
    val contactDamage: Float,
    val radius: Float,
    val xpValue: Int,
    val primaryColor: Color,
    val secondaryColor: Color,
    val descZh: String
)

data class LabUpgradeDef(
    val id: String,
    val nameZh: String,
    val effectZh: String,
    val maxLevel: Int,
    val baseCost: Double,
    val growth: Double,
    val categoryZh: String,
    val oneTime: Boolean = false
) {
    fun costForNext(currentLevel: Int): Int {
        if (currentLevel >= maxLevel) return 0
        val raw = if (oneTime) baseCost else baseCost * growth.pow(currentLevel.toDouble())
        // Exact SpriteBonk profile.gd ke(x) formula
        return ((raw * 0.85 / 5.0).roundToInt() * 5).coerceAtLeast(15)
    }
}

object GameCatalog {

    val moves: Map<String, MoveDef> = listOf(
        // Grass (树桩洞傀)
        MoveDef("vine_whip", "藤鞭", ElementType.GRASS, MoveArchetype.STRIKE, 24f, 0.82f, 165f, "年轮缝弹出活藤横扫近敌", knockback = 130f),
        MoveDef("razor_leaf", "飞叶快刀", ElementType.GRASS, MoveArchetype.PROJECTILE, 19f, 0.78f, 440f, "冠叶脱落高速旋飞追踪目标", knockback = 70f),
        MoveDef("sleep_powder", "催眠粉", ElementType.GRASS, MoveArchetype.NOVA, 16f, 3.6f, 210f, "散播冠花花粉减速并灼伤周身", slowsEnemy = true, knockback = 50f),
        MoveDef("solar_beam", "阳光烈焰", ElementType.GRASS, MoveArchetype.BEAM, 54f, 2.35f, 520f, "林冠聚光射出高能穿透光束", knockback = 120f),
        // Fire (冷炭裂膛)
        MoveDef("ember", "火花", ElementType.FIRE, MoveArchetype.PROJECTILE, 22f, 0.72f, 420f, "胸膛裂隙迸发灼热火星连射", burnsEnemy = true, knockback = 75f),
        MoveDef("fire_spin", "火焰旋涡", ElementType.FIRE, MoveArchetype.ORBIT, 18f, 0.65f, 145f, "擂胸卷起环绕周身的煤灰火环", burnsEnemy = true, knockback = 90f),
        MoveDef("flamethrower", "喷射火焰", ElementType.FIRE, MoveArchetype.BEAM, 42f, 1.85f, 460f, "炉膛开闸喷出炽烈穿透火柱", burnsEnemy = true, knockback = 100f),
        MoveDef("fire_blast", "大字爆炎", ElementType.FIRE, MoveArchetype.NOVA, 46f, 3.1f, 235f, "以自身为中心引爆炽炎星爆", burnsEnemy = true, knockback = 180f),
        // Water (对旋双壳)
        MoveDef("water_gun", "水枪", ElementType.WATER, MoveArchetype.PROJECTILE, 21f, 0.74f, 430f, "双壳对旋甩出高压水箭", knockback = 95f),
        MoveDef("bubble", "泡沫", ElementType.WATER, MoveArchetype.NOVA, 17f, 2.8f, 200f, "水衣泛起高压泡沫环击退并减速", slowsEnemy = true, knockback = 165f),
        MoveDef("rapid_spin", "高速旋转", ElementType.WATER, MoveArchetype.ORBIT, 22f, 0.58f, 155f, "闭壳绞出涡流水刃环绕撞击", knockback = 140f),
        MoveDef("hydro_pump", "水炮", ElementType.WATER, MoveArchetype.BEAM, 52f, 2.2f, 500f, "涡衣蓄压轰出贯通战场的水柱", slowsEnemy = true, knockback = 190f),
        // Electric (雷铃狐)
        MoveDef("volt_chime", "雷铃电弧", ElementType.ELECTRIC, MoveArchetype.PROJECTILE, 21f, 0.62f, 450f, "风铃震响激射高频电弧连弹", knockback = 65f),
        MoveDef("spark_ring", "磁暴电环", ElementType.ELECTRIC, MoveArchetype.ORBIT, 20f, 0.55f, 150f, "环身浮游雷球高速旋切近敌", knockback = 85f),
        MoveDef("thunder_nova", "落雷震荡", ElementType.ELECTRIC, MoveArchetype.NOVA, 34f, 2.65f, 225f, "召唤电磁脉冲环麻痹并击退敌人", slowsEnemy = true, knockback = 145f),
        MoveDef("rail_bolt", "苍穹雷枪", ElementType.ELECTRIC, MoveArchetype.BEAM, 50f, 1.95f, 530f, "瞬间贯穿整排敌潮的高压雷柱", knockback = 120f),
        // Ghost (提灯幽灵)
        MoveDef("soul_orb", "幽冥鬼火", ElementType.GHOST, MoveArchetype.PROJECTILE, 23f, 0.72f, 440f, "灯芯跃出苍青魂火灼烧目标", burnsEnemy = true, knockback = 70f),
        MoveDef("lantern_wail", "冥灯回响", ElementType.GHOST, MoveArchetype.NOVA, 26f, 2.85f, 220f, "摇响古灯扩散减速魂波汲取生机", slowsEnemy = true, knockback = 120f),
        MoveDef("eclipse_ray", "月蚀射线", ElementType.GHOST, MoveArchetype.BEAM, 48f, 2.05f, 500f, "汇聚新月幽光贯穿敌阵", slowsEnemy = true, knockback = 110f),
        // Star (星晶幼龙)
        MoveDef("star_shard", "星屑飞刃", ElementType.STAR, MoveArchetype.PROJECTILE, 24f, 0.70f, 460f, "甩出锐利星晶碎片穿透敌人", knockback = 85f),
        MoveDef("comet_orbit", "彗星护翼", ElementType.STAR, MoveArchetype.ORBIT, 24f, 0.56f, 162f, "星尘晶羽围绕龙身持续高速切割", knockback = 125f),
        MoveDef("nova_breath", "银河龙息", ElementType.STAR, MoveArchetype.BEAM, 56f, 2.15f, 540f, "吐出璀璨星海光柱横扫全场", burnsEnemy = true, knockback = 155f)
    ).associateBy { it.id }

    // PokéBonk-style Move + Vitamin Synergy / Awakening Evolutions!
    val moveSynergies: List<MoveSynergyDef> = listOf(
        MoveSynergyDef("vine_whip", "super_potion", "★圣域巨藤", "伤害 +45% · 范围 +30% · 攻击附带生命汲取"),
        MoveSynergyDef("ember", "protein", "★超新星连炎", "伤害 +45% · 额外齐射火球并强化灼烧"),
        MoveSynergyDef("water_gun", "iron", "★深渊高压箭", "伤害 +45% · 强力击退并减速目标"),
        MoveSynergyDef("volt_chime", "carbos", "★九霄天雷链", "攻速 +35% · 伤害 +40% · 穿透提升"),
        MoveSynergyDef("soul_orb", "dire_hit", "★噬魂冥火", "伤害 +45% · 暴击必触发魂火回复"),
        MoveSynergyDef("star_shard", "ether", "★星穹裁决刃", "攻速 +35% · 伤害 +45% · 额外齐射星刃"),
        MoveSynergyDef("solar_beam", "hp_up", "★日冕圣光炮", "伤害 +50% · 激光更宽且冷却缩短"),
        MoveSynergyDef("flamethrower", "dire_hit", "★熔核焚天柱", "伤害 +50% · 必中灼烧爆燃"),
        MoveSynergyDef("hydro_pump", "ether", "★沧海巨啸炮", "伤害 +50% · 超大范围贯穿击退")
    )

    fun synergyForMove(moveId: String): MoveSynergyDef? = moveSynergies.firstOrNull { it.moveId == moveId }
    fun synergiesForVitamin(vitaminId: String): List<MoveSynergyDef> = moveSynergies.filter { it.vitaminId == vitaminId }

    fun fusedMoveTitle(moveId: String): String = when (moveId) {
        "vine_whip", "razor_leaf" -> "✦翠岚天刃"
        "ember", "fire_spin", "fire_blast" -> "✦熔星双炎"
        "water_gun", "rapid_spin", "bubble" -> "✦沧澜涡流"
        "volt_chime", "spark_ring", "thunder_nova" -> "✦天穹磁暴"
        "soul_orb", "lantern_wail", "eclipse_ray" -> "✦永夜噬魂"
        "star_shard", "comet_orbit", "nova_breath" -> "✦银河陨星"
        "solar_beam" -> "✦日冕聚星炮"
        "flamethrower" -> "✦焚天熔炉柱"
        "hydro_pump" -> "✦深渊巨啸炮"
        "rail_bolt" -> "✦天罚雷神枪"
        else -> "✦融合·${moves[moveId]?.nameZh ?: moveId}"
    }

    fun overclockFusionTitle(moveId: String): String = when (moveId) {
        "vine_whip", "razor_leaf" -> "✧终焉森罗刃"
        "ember", "fire_spin", "fire_blast" -> "✧超新星熔核"
        "water_gun", "rapid_spin", "bubble" -> "✧太古海啸核"
        "volt_chime", "spark_ring", "thunder_nova" -> "✧九霄雷穹阵"
        "soul_orb", "lantern_wail", "eclipse_ray" -> "✧幽冥轮回灯"
        "star_shard", "comet_orbit", "nova_breath" -> "✧星海审判炮"
        else -> "✧超频·${fusedMoveTitle(moveId).removePrefix("✦")}"
    }

    val starters: List<StarterLine> = listOf(
        StarterLine(
            id = "stump",
            codeName = "树桩洞傀",
            stageNames = listOf("芽桩傀", "藤洞傀", "古冠桩王"),
            roleZh = "草系 · 远程控场",
            element = ElementType.GRASS,
            passiveNameZh = "光合再生",
            passiveDescZh = "每秒自然回复 1.2 HP，草系技能范围 +12%",
            loreZh = "会走路的空心树桩，施法者藏在树洞里只露发光双眼，活藤从年轮缝隙弹出迎敌。",
            baseHp = 115f,
            baseSpeed = 235f,
            baseDamage = 1.0f,
            baseArmor = 4f,
            signatureMoves = listOf("vine_whip", "razor_leaf", "sleep_powder", "solar_beam"),
            ultStageNames = listOf("狂怒根须", "疯狂藤蔓", "巨花藤鞭"),
            ultDescZh = "大范围召唤根须冲击波清场，并瞬间回复 25% 最大生命值",
            bodyPrimaryColor = Color(0xFF8B5A2B),
            bodyAccentColor = GrassGreen,
            portraitRes = R.drawable.img_starter_stump
        ),
        StarterLine(
            id = "char",
            codeName = "冷炭裂膛",
            stageNames = listOf("炭裂崽", "裂膛炭兽", "熔核巨炭"),
            roleZh = "火系 · 爆发炮台",
            element = ElementType.FIRE,
            passiveNameZh = "猛火炉膛",
            passiveDescZh = "基础暴击率 +10%，血量低于 50% 时火焰伤害额外 +30%",
            loreZh = "通体焦黑的炭岩巨猿，静止时只有胸口裂缝透出暗红微光，出手瞬间胸膛裂开喷吐烈焰。",
            baseHp = 105f,
            baseSpeed = 248f,
            baseDamage = 1.12f,
            baseArmor = 3f,
            signatureMoves = listOf("ember", "fire_spin", "flamethrower", "fire_blast"),
            ultStageNames = listOf("升腾烈焰", "爆裂燃烧", "终极烈焰"),
            ultDescZh = "胸膛全开引爆三波熔核烈焰冲击，对全场敌人施加高额灼烧伤害",
            bodyPrimaryColor = Color(0xFF333036),
            bodyAccentColor = WarmOrange,
            portraitRes = R.drawable.img_starter_char
        ),
        StarterLine(
            id = "shell",
            codeName = "对旋双壳",
            stageNames = listOf("涡壳崽", "对旋双壳", "漩涡巨蚌"),
            roleZh = "水系 · 旋转坦克",
            element = ElementType.WATER,
            passiveNameZh = "激流双壳",
            passiveDescZh = "护甲 +8，受击后激起水环击退近身敌人",
            loreZh = "会走路的深蓝大蚌，两片巨壳反向旋转将水流绞成护身漩涡衣，闭壳即是旋转冲车。",
            baseHp = 135f,
            baseSpeed = 225f,
            baseDamage = 0.96f,
            baseArmor = 10f,
            signatureMoves = listOf("water_gun", "rapid_spin", "bubble", "hydro_pump"),
            ultStageNames = listOf("甲壳漩涡", "滔天巨浪", "强力水炮"),
            ultDescZh = "双壳极速对旋卷起巨型水涡，将周围敌人强力震退并连续绞杀",
            bodyPrimaryColor = Color(0xFF32469E),
            bodyAccentColor = SkyBlue,
            portraitRes = R.drawable.img_starter_shell
        ),
        StarterLine(
            id = "spark",
            codeName = "雷铃狐",
            stageNames = listOf("铃电幼狐", "雷鸣灵狐", "天穹雷神狐"),
            roleZh = "电系 · 极速暴击",
            element = ElementType.ELECTRIC,
            passiveNameZh = "静电共鸣",
            passiveDescZh = "移动速度 +14%，暴击率 +12%，闪避冷却大幅缩短",
            loreZh = "披着暖金瓷甲的疾风灵狐，颈间与尾尖悬着电鸣风铃，奔跑时迸发连环青金雷弧。",
            baseHp = 98f,
            baseSpeed = 278f,
            baseDamage = 1.08f,
            baseArmor = 3f,
            signatureMoves = listOf("volt_chime", "spark_ring", "thunder_nova", "rail_bolt"),
            ultStageNames = listOf("风铃雷暴", "磁极天雷", "九霄雷鸣阵"),
            ultDescZh = "引动三道苍青天雷环绕清场，令范围内敌人陷入麻痹减速",
            bodyPrimaryColor = Color(0xFFF3BC32),
            bodyAccentColor = Color(0xFF4BF0FF),
            portraitRes = R.drawable.img_starter_spark
        ),
        StarterLine(
            id = "wisp",
            codeName = "提灯幽灵",
            stageNames = listOf("青灯小灵", "冥灯大君", "永夜提灯王"),
            roleZh = "幽灵 · 汲取控场",
            element = ElementType.GHOST,
            passiveNameZh = "魂火汲取",
            passiveDescZh = "每击败 6 名敌人回复 4 HP，必杀充能效率 +18%",
            loreZh = "栖身于古铜月灯中的顽皮灵火，提灯轻摇便唤出青紫鬼火环绕吞噬逼近的敌潮。",
            baseHp = 108f,
            baseSpeed = 250f,
            baseDamage = 1.06f,
            baseArmor = 5f,
            signatureMoves = listOf("soul_orb", "lantern_wail", "eclipse_ray", "fire_spin"),
            ultStageNames = listOf("幽灯召魂", "月蚀冥潮", "永夜魂域"),
            ultDescZh = "张开永夜魂灯领域重创周身敌人，并将部分伤害化作生命回复",
            bodyPrimaryColor = Color(0xFF6249B8),
            bodyAccentColor = Color(0xFF5AF2E8),
            portraitRes = R.drawable.img_starter_wisp
        ),
        StarterLine(
            id = "drake",
            codeName = "星晶幼龙",
            stageNames = listOf("星晶幼龙", "耀星苍龙", "苍穹星神龙"),
            roleZh = "星辰 · 全能主宰",
            element = ElementType.STAR,
            passiveNameZh = "星穹鳞甲",
            passiveDescZh = "全伤害 +10%，技能范围 +12%，经验获取 +12%",
            loreZh = "覆着深蓝星鳞的结晶幼龙，双翼由半透明星辉凝聚而成，振翅间洒下锐利星屑。",
            baseHp = 124f,
            baseSpeed = 246f,
            baseDamage = 1.12f,
            baseArmor = 7f,
            signatureMoves = listOf("star_shard", "comet_orbit", "nova_breath", "fire_blast"),
            ultStageNames = listOf("星屑陨雨", "彗星风暴", "银河超新星"),
            ultDescZh = "汇聚星海之力引爆三轮璀璨星辰冲击波，兼顾超高爆发与击退",
            bodyPrimaryColor = Color(0xFF3347A8),
            bodyAccentColor = Color(0xFFFFD84D),
            portraitRes = R.drawable.img_starter_drake
        )
    )

    val vitamins: List<VitaminDef> = listOf(
        VitaminDef("protein", "力量蛋白", "全伤害 +12%", 12f, true, "dmg_pct"),
        VitaminDef("iron", "坚韧铁甲", "护甲 +5", 5f, false, "armor_flat"),
        VitaminDef("carbos", "疾风速度剂", "移速 +8%", 8f, true, "spd_pct"),
        VitaminDef("hp_up", "生命增强剂", "最大 HP +22", 22f, false, "hp_flat"),
        VitaminDef("ether", "高频以太", "攻速 +10%", 10f, true, "atkspd_pct"),
        VitaminDef("dire_hit", "要害聚焦镜", "暴击率 +7%", 7f, true, "crit_pct"),
        VitaminDef("exp_candy", "智慧经验糖", "经验获取 +15%", 15f, true, "xp_pct"),
        VitaminDef("nugget", "闪亮金块", "金币与星尘 +18%", 18f, true, "gold_pct"),
        VitaminDef("super_potion", "活力伤药", "生命再生 +1.0/秒", 1.0f, false, "regen_flat"),
        VitaminDef("star_piece", "幸运星片", "幸运 +12（提高高稀有度）", 12f, false, "luck_flat")
    )

    val enemies: Map<String, EnemyDef> = listOf(
        // Forest
        EnemyDef("thorn_bug", "荆刺滚虫", ElementType.GRASS, false, 34f, 92f, 9f, 22f, 12, Color(0xFF6BBF4E), Color(0xFFDFF08A), "密林常见小怪，喜欢成群冲撞。"),
        EnemyDef("puff_shroom", "绒球孢菇", ElementType.POISON, false, 52f, 76f, 12f, 26f, 18, Color(0xFFD9647C), Color(0xFFFFE5B8), "圆滚滚的森林毒菇，皮糙肉厚。"),
        EnemyDef("moss_hopper", "苔背跳蛙", ElementType.GRASS, false, 44f, 122f, 11f, 23f, 16, Color(0xFF3E9C67), Color(0xFFF6D96B), "移动迅捷的林间伏击者。"),
        EnemyDef("boss_briar", "荆棘古树守卫", ElementType.GRASS, true, 1250f, 84f, 22f, 54f, 180, Color(0xFF4B7D38), Color(0xFFFF7A45), "翡翠密林守护者，会蓄力释放荆棘震荡环。"),
        // Graveyard
        EnemyDef("lantern_wisp", "提灯幽影", ElementType.GHOST, false, 48f, 112f, 13f, 24f, 19, Color(0xFF7B63D9), Color(0xFF76F7FF), "游荡在雾夜墓园的诡秘灵火。"),
        EnemyDef("bone_crow", "碎骨夜鸦", ElementType.GHOST, false, 40f, 140f, 12f, 22f, 17, Color(0xFF4A4766), Color(0xFFE6E0D0), "速度极快的群居夜行灵禽。"),
        EnemyDef("mire_toad", "毒沼泥灵", ElementType.POISON, false, 78f, 78f, 15f, 29f, 24, Color(0xFF6B4C82), Color(0xFF9DF059), "沉重的腐雾怪兽，血量丰厚。"),
        EnemyDef("boss_wraith", "幽灯骸王", ElementType.GHOST, true, 1650f, 96f, 26f, 56f, 240, Color(0xFF5D3EC4), Color(0xFF5AF0FF), "迷雾幽墓霸主，高移速并召唤幽魂冲击。"),
        // Desert
        EnemyDef("dune_scorp", "沙丘钳蝎", ElementType.GROUND, false, 64f, 116f, 16f, 26f, 24, Color(0xFFD99A46), Color(0xFF8C4A22), "甲壳坚硬的荒漠猎手。"),
        EnemyDef("cacti_roll", "刺球仙人掌", ElementType.GRASS, false, 72f, 102f, 17f, 27f, 25, Color(0xFF5EA853), Color(0xFFFF6E7E), "滚滚而来的带刺荒原住民。"),
        EnemyDef("sand_golem", "赤岩沙傀", ElementType.ROCK, false, 108f, 74f, 20f, 32f, 32, Color(0xFFB5864C), Color(0xFFF5D793), "由热砂凝聚的重装石傀。"),
        EnemyDef("boss_scarab", "沙暴甲皇", ElementType.GROUND, true, 2100f, 98f, 30f, 58f, 310, Color(0xFFD98B26), Color(0xFFFFE25A), "烈阳荒漠守护者，铁甲护体且攻势凌厉。"),
        // Volcano
        EnemyDef("slag_slime", "熔渣炎灵", ElementType.FIRE, false, 84f, 108f, 19f, 26f, 30, Color(0xFFE8522E), Color(0xFFFFD147), "沸腾着岩浆的炽热精怪。"),
        EnemyDef("obsidian_beetle", "黑曜甲虫", ElementType.ROCK, false, 128f, 88f, 23f, 31f, 36, Color(0xFF3E3548), Color(0xFFFF6830), "覆满火山玻璃装甲的精英虫族。"),
        EnemyDef("ember_hound", "灰烬疾犬", ElementType.FIRE, false, 72f, 152f, 20f, 24f, 28, Color(0xFF8C2A24), Color(0xFFFFA53B), "如火星般疾驰的火山猎犬。"),
        EnemyDef("boss_magma", "黑曜熔核领主", ElementType.FIRE, true, 2750f, 104f, 34f, 62f, 420, Color(0xFF2E222B), CrimsonRed, "熔岩火山终极守护者，掌控炽焰重击波。"),
        // Dynamic Random Event Treasure Sprite
        EnemyDef("stardust_mimic", "星尘宝箱怪", ElementType.STAR, false, 165f, 158f, 6f, 25f, 95, Color(0xFFFFC93C), Color(0xFF66F6FF), "携满星尘与金币四处逃窜的稀有宝箱灵，击败它可收获丰厚战利品！")
    ).associateBy { it.id }

    val biomes: List<BiomeDef> = listOf(
        BiomeDef(
            id = "forest",
            nameZh = "翡翠密林",
            subtitleZh = "阳光草甸与初遇试炼",
            orderIndex = 0,
            groundBase = Color(0xFF7EC262),
            groundAlt = Color(0xFF72B557),
            pathColor = Color(0xFFD7BC8A),
            accentColor = Color(0xFF569A3F),
            bossId = "boss_briar",
            bossNameZh = "荆棘古树守卫",
            enemyPool = listOf("thorn_bug", "puff_shroom", "moss_hopper"),
            difficultyScale = 1.0f,
            stardustBonus = 80
        ),
        BiomeDef(
            id = "graveyard",
            nameZh = "迷雾幽墓",
            subtitleZh = "月光石碑与诡秘灵潮",
            orderIndex = 1,
            groundBase = Color(0xFF5C6C75),
            groundAlt = Color(0xFF516069),
            pathColor = Color(0xFF838E96),
            accentColor = Color(0xFF42505A),
            bossId = "boss_wraith",
            bossNameZh = "幽灯骸王",
            enemyPool = listOf("lantern_wisp", "bone_crow", "mire_toad"),
            difficultyScale = 1.32f,
            stardustBonus = 140
        ),
        BiomeDef(
            id = "desert",
            nameZh = "烈阳荒漠",
            subtitleZh = "金砂遗迹与重甲虫群",
            orderIndex = 2,
            groundBase = Color(0xFFDFBA74),
            groundAlt = Color(0xFFD2AC66),
            pathColor = Color(0xFFC49852),
            accentColor = Color(0xFFB3843E),
            bossId = "boss_scarab",
            bossNameZh = "沙暴甲皇",
            enemyPool = listOf("dune_scorp", "cacti_roll", "sand_golem"),
            difficultyScale = 1.65f,
            stardustBonus = 220
        ),
        BiomeDef(
            id = "volcano",
            nameZh = "熔岩火山",
            subtitleZh = "黑曜焦土与终极领主",
            orderIndex = 3,
            groundBase = Color(0xFF594346),
            groundAlt = Color(0xFF4B373A),
            pathColor = Color(0xFF7D4838),
            accentColor = Color(0xFFE8562A),
            bossId = "boss_magma",
            bossNameZh = "黑曜熔核领主",
            enemyPool = listOf("slag_slime", "obsidian_beetle", "ember_hound"),
            difficultyScale = 2.05f,
            stardustBonus = 340
        )
    )

    // Faithful SpriteBonk profile.gd Lab upgrades
    val labUpgrades: List<LabUpgradeDef> = listOf(
        LabUpgradeDef("dmg", "攻击增幅", "全招式伤害 +6% / 级", 8, 90.0, 1.4, "战斗"),
        LabUpgradeDef("hp", "生命强化", "初始最大 HP +14 / 级", 8, 90.0, 1.4, "生存"),
        LabUpgradeDef("spd", "疾行靴组", "移动速度 +3.5% / 级", 6, 110.0, 1.45, "机动"),
        LabUpgradeDef("atkspd", "高速连携", "招式攻速 +4% / 级", 5, 160.0, 1.45, "战斗"),
        LabUpgradeDef("crit", "精准要害", "暴击率 +2.5% / 级", 5, 150.0, 1.45, "战斗"),
        LabUpgradeDef("area", "广域共鸣", "技能范围 +5% / 级", 5, 160.0, 1.45, "战斗"),
        LabUpgradeDef("armor", "硬壳镀层", "初始护甲 +3 / 级", 6, 110.0, 1.42, "生存"),
        LabUpgradeDef("regen", "生命律动", "生命再生 +0.4/秒 / 级", 5, 115.0, 1.42, "生存"),
        LabUpgradeDef("ult", "必杀核心", "必杀充能效率 +8% / 级", 5, 180.0, 1.48, "必杀"),
        LabUpgradeDef("xp", "学者徽章", "经验获取 +8% / 级", 6, 100.0, 1.42, "成长"),
        LabUpgradeDef("gold", "聚宝磁阵", "星尘与金币 +10% / 级", 6, 100.0, 1.42, "成长"),
        LabUpgradeDef("magnet", "吸星磁力", "拾取半径 +18% / 级", 5, 80.0, 1.42, "成长"),
        LabUpgradeDef("luck", "星运罗盘", "幸运值 +8 / 级", 6, 125.0, 1.45, "构筑"),
        LabUpgradeDef("reroll", "重抽许可", "每局升级重抽 +1 次", 4, 120.0, 1.5, "构筑"),
        LabUpgradeDef("skip", "跳过许可", "每局升级跳过 +1 次", 4, 90.0, 1.45, "构筑"),
        LabUpgradeDef("banish", "放逐许可", "每局升级放逐 +1 次", 4, 140.0, 1.5, "构筑"),
        LabUpgradeDef("choice4", "四选一扩展", "升级草稿卡位 3 → 4", 1, 950.0, 1.0, "构筑", oneTime = true),
        LabUpgradeDef("move_slot", "招式槽位扩容", "局内最大招式槽位 4 → 5", 1, 880.0, 1.0, "构筑", oneTime = true),
        LabUpgradeDef("vit_amp", "营养剂增效舱", "所有营养剂效果 +12% / 级", 4, 150.0, 1.48, "成长"),
        LabUpgradeDef("revive", "星尘复生", "每局濒死自动复活 1 次", 1, 1400.0, 1.0, "生存", oneTime = true)
    )

    val dangerNames = listOf("平静", "温和", "危险", "极危险", "残暴", "致命", "不可能")

    fun starterById(id: String): StarterLine = starters.firstOrNull { it.id == id } ?: starters.first()
    fun biomeById(id: String): BiomeDef = biomes.firstOrNull { it.id == id } ?: biomes.first()
}
