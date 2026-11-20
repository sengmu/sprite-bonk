package com.example.game.evolution

import androidx.compose.ui.graphics.Color
import com.example.game.model.ElementType
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

enum class EvolutionResourceType(
    val id: String,
    val nameZh: String,
    val shortZh: String,
    val color: Color
) {
    ESSENCE_BLOOM("bloom", "森灵精华", "森灵", GrassGreen),
    ESSENCE_EMBER("ember", "熔核火种", "火种", WarmOrange),
    ESSENCE_TIDE("tide", "潮汐结晶", "潮汐", SkyBlue),
    STARDUST_CORE("core", "星尘核心", "星核", GoldAccent)
}

enum class EvolutionCrownStyle {
    SPROUT,
    BLOOM_CANOPY,
    THORN_CROWN,
    SHADOW_ROOTS,
    FURNACE_CHIMNEY,
    MAGMA_TITAN,
    ASH_FLARE,
    BLUE_SERAPH_FLAME,
    VORTEX_WINGS,
    TIDAL_SPOUT,
    REEF_FORTRESS,
    ABYSS_CITADEL,
    CHIME_EARS,
    STORM_HALO,
    PLASMA_VISOR,
    LANTERN_CREST,
    ECLIPSE_CROWN,
    CRYSTAL_WINGS,
    STAR_SERAPH,
    METEOR_HORNS
}

data class EvolutionStatDelta(
    val maxHpFlat: Float = 0f,
    val damagePct: Float = 0f,
    val speedPct: Float = 0f,
    val armorFlat: Float = 0f,
    val critPct: Float = 0f,
    val areaPct: Float = 0f,
    val regenFlat: Float = 0f,
    val ultChargePct: Float = 0f
) {
    fun summaryLines(): List<String> = buildList {
        if (maxHpFlat > 0f) add("最大 HP +${maxHpFlat.toInt()}")
        if (damagePct > 0f) add("全伤害 +${(damagePct * 100).toInt()}%")
        if (speedPct > 0f) add("移速 +${(speedPct * 100).toInt()}%")
        if (armorFlat > 0f) add("护甲 +${armorFlat.toInt()}")
        if (critPct > 0f) add("暴击率 +${(critPct * 100).toInt()}%")
        if (areaPct > 0f) add("技能范围 +${(areaPct * 100).toInt()}%")
        if (regenFlat > 0f) add("生命再生 +${"%.1f".format(regenFlat)}/秒")
        if (ultChargePct > 0f) add("必杀充能 +${(ultChargePct * 100).toInt()}%")
    }
}

data class EvolutionVisualStyle(
    val starterId: String,
    val primaryColor: Color,
    val secondaryColor: Color,
    val accentColor: Color,
    val eyeColor: Color,
    val auraColor: Color,
    val crownStyle: EvolutionCrownStyle,
    val scaleFactor: Float = 1.0f
)

data class EvolutionNode(
    val id: String,
    val starterId: String,
    val tier: Int, // 0 = Base, 1 = Branch Mid, 2 = Branch Apex
    val branchLabelZh: String,
    val nameZh: String,
    val roleTagZh: String,
    val descZh: String,
    val requiredLevel: Int,
    val resourceCost: Map<EvolutionResourceType, Int>,
    val parentNodeId: String?,
    val nextNodeIds: List<String>,
    val statDelta: EvolutionStatDelta,
    val bonusMoveId: String?,
    val ultNameZh: String,
    val visualStyle: EvolutionVisualStyle
)

data class EvolutionEligibility(
    val node: EvolutionNode,
    val isCurrent: Boolean,
    val isAlreadyPassed: Boolean,
    val isReachableFromCurrent: Boolean,
    val levelMet: Boolean,
    val missingResources: Map<EvolutionResourceType, Int>,
    val canEvolveNow: Boolean
)

data class EvolutionStateSnapshot(
    val starterId: String = "stump",
    val currentNodeId: String = "stump_base",
    val historyNodeIds: List<String> = listOf("stump_base"),
    val resources: Map<EvolutionResourceType, Int> = emptyMap(),
    val hasReadyEvolution: Boolean = false,
    val readyCount: Int = 0
) {
    val currentNode: EvolutionNode
        get() = EvolutionRegistry.nodeById(currentNodeId)
}

object EvolutionRegistry {

    val allNodes: Map<String, EvolutionNode> = listOf(
        // ==================== 树桩洞傀 (GRASS) EVOLUTION TREE ====================
        EvolutionNode(
            id = "stump_base",
            starterId = "stump",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "芽桩傀",
            roleTagZh = "林间初芽",
            descZh = "藏身空心木桩的林间灵傀，头顶嫩芽随时准备向不同生态方向蜕变。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("stump_canopy", "stump_thorn"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "狂怒根须",
            visualStyle = EvolutionVisualStyle(
                starterId = "stump",
                primaryColor = Color(0xFF9C6639),
                secondaryColor = Color(0xFF7A4B24),
                accentColor = GrassGreen,
                eyeColor = GoldAccent,
                auraColor = GrassGreen,
                crownStyle = EvolutionCrownStyle.SPROUT,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "stump_canopy",
            starterId = "stump",
            tier = 1,
            branchLabelZh = "分支 A · 花冠治愈",
            nameZh = "花冠藤傀",
            roleTagZh = "广域控场 · 再生",
            descZh = "汲取森灵精华绽放繁茂花冠，技能覆盖范围与生命恢复显著增强。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_BLOOM to 3),
            parentNodeId = "stump_base",
            nextNodeIds = listOf("stump_elder_bloom"),
            statDelta = EvolutionStatDelta(maxHpFlat = 35f, areaPct = 0.22f, regenFlat = 1.5f, damagePct = 0.14f),
            bonusMoveId = "sleep_powder",
            ultNameZh = "疯狂藤蔓",
            visualStyle = EvolutionVisualStyle(
                starterId = "stump",
                primaryColor = Color(0xFF8E6338),
                secondaryColor = Color(0xFF634121),
                accentColor = Color(0xFF5CE06E),
                eyeColor = Color(0xFFFFF176),
                auraColor = Color(0xFF72FF96),
                crownStyle = EvolutionCrownStyle.BLOOM_CANOPY,
                scaleFactor = 1.15f
            )
        ),
        EvolutionNode(
            id = "stump_thorn",
            starterId = "stump",
            tier = 1,
            branchLabelZh = "分支 B · 荆棘猎手",
            nameZh = "毒刺木傀",
            roleTagZh = "暴击穿刺 · 高速",
            descZh = "融合炽热火种淬炼出暗紫硬化荆棘，放弃防御换取高暴击与敏捷追击。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_BLOOM to 2, EvolutionResourceType.ESSENCE_EMBER to 2),
            parentNodeId = "stump_base",
            nextNodeIds = listOf("stump_shadow_root"),
            statDelta = EvolutionStatDelta(damagePct = 0.26f, critPct = 0.14f, speedPct = 0.12f),
            bonusMoveId = "razor_leaf",
            ultNameZh = "荆棘穿刺",
            visualStyle = EvolutionVisualStyle(
                starterId = "stump",
                primaryColor = Color(0xFF5D4148),
                secondaryColor = Color(0xFF3E2830),
                accentColor = Color(0xFFB560E0),
                eyeColor = Color(0xFFFF6E7E),
                auraColor = EpicPurple,
                crownStyle = EvolutionCrownStyle.THORN_CROWN,
                scaleFactor = 1.14f
            )
        ),
        EvolutionNode(
            id = "stump_elder_bloom",
            starterId = "stump",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "古冠花王",
            roleTagZh = "森罗圣域 · 阳光炮",
            descZh = "完全体森林守护灵，巨型花冠汇聚圣光，赋予阳光烈焰与海量生命回复。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_BLOOM to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "stump_canopy",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 65f, damagePct = 0.28f, areaPct = 0.30f, regenFlat = 2.6f, ultChargePct = 0.20f),
            bonusMoveId = "solar_beam",
            ultNameZh = "巨花藤鞭",
            visualStyle = EvolutionVisualStyle(
                starterId = "stump",
                primaryColor = Color(0xFF7D542E),
                secondaryColor = Color(0xFF4F3219),
                accentColor = Color(0xFF42E67B),
                eyeColor = GoldAccent,
                auraColor = GoldAccent,
                crownStyle = EvolutionCrownStyle.BLOOM_CANOPY,
                scaleFactor = 1.32f
            )
        ),
        EvolutionNode(
            id = "stump_shadow_root",
            starterId = "stump",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "幽根冥傀",
            roleTagZh = "暗影收割 · 极限暴击",
            descZh = "枯木逢魔化作暗夜根须君主，暴击伤害与必杀充能效率达到巅峰。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_BLOOM to 3, EvolutionResourceType.ESSENCE_EMBER to 3, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "stump_thorn",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(damagePct = 0.42f, critPct = 0.22f, speedPct = 0.16f, ultChargePct = 0.25f),
            bonusMoveId = "solar_beam",
            ultNameZh = "幽冥根爆",
            visualStyle = EvolutionVisualStyle(
                starterId = "stump",
                primaryColor = Color(0xFF39273D),
                secondaryColor = Color(0xFF231629),
                accentColor = Color(0xFFFF5A8A),
                eyeColor = Color(0xFF66F7FF),
                auraColor = Color(0xFFFF5A8A),
                crownStyle = EvolutionCrownStyle.SHADOW_ROOTS,
                scaleFactor = 1.30f
            )
        ),

        // ==================== 冷炭裂膛 (FIRE) EVOLUTION TREE ====================
        EvolutionNode(
            id = "char_base",
            starterId = "char",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "炭裂崽",
            roleTagZh = "冷炭初燃",
            descZh = "沉稳的焦炭小猿，胸膛暗红裂隙蕴藏着可塑的火山与蓝焰潜能。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("char_furnace", "char_ash"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "升腾烈焰",
            visualStyle = EvolutionVisualStyle(
                starterId = "char",
                primaryColor = Color(0xFF36323B),
                secondaryColor = Color(0xFF534D59),
                accentColor = WarmOrange,
                eyeColor = GoldAccent,
                auraColor = WarmOrange,
                crownStyle = EvolutionCrownStyle.FURNACE_CHIMNEY,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "char_furnace",
            starterId = "char",
            tier = 1,
            branchLabelZh = "分支 A · 熔炉重炮",
            nameZh = "裂膛炉猿",
            roleTagZh = "重甲火炮 · 范围爆破",
            descZh = "双肩烟囱成型，胸膛化为高温鼓风炉，显著提升火系爆发与护甲。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 3),
            parentNodeId = "char_base",
            nextNodeIds = listOf("char_magma_titan"),
            statDelta = EvolutionStatDelta(maxHpFlat = 40f, damagePct = 0.24f, armorFlat = 8f, areaPct = 0.16f),
            bonusMoveId = "flamethrower",
            ultNameZh = "爆裂燃烧",
            visualStyle = EvolutionVisualStyle(
                starterId = "char",
                primaryColor = Color(0xFF3B2B2C),
                secondaryColor = Color(0xFF663C34),
                accentColor = Color(0xFFFF6D24),
                eyeColor = GoldAccent,
                auraColor = WarmOrange,
                crownStyle = EvolutionCrownStyle.FURNACE_CHIMNEY,
                scaleFactor = 1.16f
            )
        ),
        EvolutionNode(
            id = "char_ash",
            starterId = "char",
            tier = 1,
            branchLabelZh = "分支 B · 苍焰游侠",
            nameZh = "灰烬影猿",
            roleTagZh = "高机动 · 极速暴击",
            descZh = "以潮汐结晶淬火化作轻盈苍蓝炉心，高速穿梭战阵倾泻密集弹幕。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 2, EvolutionResourceType.ESSENCE_TIDE to 2),
            parentNodeId = "char_base",
            nextNodeIds = listOf("char_blue_flare"),
            statDelta = EvolutionStatDelta(damagePct = 0.20f, speedPct = 0.18f, critPct = 0.16f, ultChargePct = 0.18f),
            bonusMoveId = "fire_spin",
            ultNameZh = "星火疾驰",
            visualStyle = EvolutionVisualStyle(
                starterId = "char",
                primaryColor = Color(0xFF2D3347),
                secondaryColor = Color(0xFF475575),
                accentColor = Color(0xFF4DE4FF),
                eyeColor = Color(0xFF8BF6FF),
                auraColor = SkyBlue,
                crownStyle = EvolutionCrownStyle.ASH_FLARE,
                scaleFactor = 1.12f
            )
        ),
        EvolutionNode(
            id = "char_magma_titan",
            starterId = "char",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "熔核巨炭",
            roleTagZh = "黑曜巨神 · 大字爆炎",
            descZh = "四管火山烟囱齐鸣，胸口熔炉完全洞开，一击点燃整片战场的巨兽。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "char_furnace",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 75f, damagePct = 0.40f, armorFlat = 14f, areaPct = 0.28f),
            bonusMoveId = "fire_blast",
            ultNameZh = "终极烈焰",
            visualStyle = EvolutionVisualStyle(
                starterId = "char",
                primaryColor = Color(0xFF261A1E),
                secondaryColor = Color(0xFF522A24),
                accentColor = Color(0xFFFF4A2A),
                eyeColor = Color(0xFFFFEE58),
                auraColor = Color(0xFFFF5E24),
                crownStyle = EvolutionCrownStyle.MAGMA_TITAN,
                scaleFactor = 1.34f
            )
        ),
        EvolutionNode(
            id = "char_blue_flare",
            starterId = "char",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "苍焰焚灵",
            roleTagZh = "超临界蓝焰 · 无限必杀",
            descZh = "炉火突破极限蜕变为耀眼蓝白等离子焰，极致移速、暴击与必杀循环。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 3, EvolutionResourceType.ESSENCE_TIDE to 3, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "char_ash",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(damagePct = 0.36f, speedPct = 0.22f, critPct = 0.24f, ultChargePct = 0.35f),
            bonusMoveId = "fire_blast",
            ultNameZh = "苍穹超新星",
            visualStyle = EvolutionVisualStyle(
                starterId = "char",
                primaryColor = Color(0xFF1F2B4D),
                secondaryColor = Color(0xFF3E5E9C),
                accentColor = Color(0xFF5CF6FF),
                eyeColor = Color.White,
                auraColor = Color(0xFF5CF6FF),
                crownStyle = EvolutionCrownStyle.BLUE_SERAPH_FLAME,
                scaleFactor = 1.28f
            )
        ),

        // ==================== 对旋双壳 (WATER) EVOLUTION TREE ====================
        EvolutionNode(
            id = "shell_base",
            starterId = "shell",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "涡壳崽",
            roleTagZh = "旋转初壳",
            descZh = "双壳反向旋转织出水流披风，既能化作疾风涡轮也可铸成深海堡垒。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("shell_vortex", "shell_fortress"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "甲壳漩涡",
            visualStyle = EvolutionVisualStyle(
                starterId = "shell",
                primaryColor = Color(0xFF33479E),
                secondaryColor = Color(0xFF6B85E0),
                accentColor = Color(0xFF5AF0FF),
                eyeColor = SkyBlue,
                auraColor = SkyBlue,
                crownStyle = EvolutionCrownStyle.VORTEX_WINGS,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "shell_vortex",
            starterId = "shell",
            tier = 1,
            branchLabelZh = "分支 A · 涡流疾轮",
            nameZh = "激流双壳",
            roleTagZh = "高速旋切 · 控场",
            descZh = "双壳轻量化并加速对旋，形成高速水刃涡翼与凌厉移速。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 3),
            parentNodeId = "shell_base",
            nextNodeIds = listOf("shell_tidal_seraph"),
            statDelta = EvolutionStatDelta(damagePct = 0.22f, speedPct = 0.16f, areaPct = 0.20f, critPct = 0.10f),
            bonusMoveId = "rapid_spin",
            ultNameZh = "滔天巨浪",
            visualStyle = EvolutionVisualStyle(
                starterId = "shell",
                primaryColor = Color(0xFF2858B8),
                secondaryColor = Color(0xFF5FA6FF),
                accentColor = Color(0xFF72FAFF),
                eyeColor = Color(0xFF72FAFF),
                auraColor = Color(0xFF72FAFF),
                crownStyle = EvolutionCrownStyle.VORTEX_WINGS,
                scaleFactor = 1.15f
            )
        ),
        EvolutionNode(
            id = "shell_fortress",
            starterId = "shell",
            tier = 1,
            branchLabelZh = "分支 B · 珊瑚要塞",
            nameZh = "玄甲礁蚌",
            roleTagZh = "铁壁护甲 · 反震再生",
            descZh = "融合森灵精华在巨壳表面生长结晶珊瑚甲，化身不可撼动的移动盾垒。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 2, EvolutionResourceType.ESSENCE_BLOOM to 2),
            parentNodeId = "shell_base",
            nextNodeIds = listOf("shell_abyss_fortress"),
            statDelta = EvolutionStatDelta(maxHpFlat = 60f, armorFlat = 16f, regenFlat = 1.6f, damagePct = 0.12f),
            bonusMoveId = "bubble",
            ultNameZh = "珊瑚壁垒",
            visualStyle = EvolutionVisualStyle(
                starterId = "shell",
                primaryColor = Color(0xFF265C6B),
                secondaryColor = Color(0xFF4AA89E),
                accentColor = Color(0xFFFF8F7A),
                eyeColor = GoldAccent,
                auraColor = Color(0xFF42E6B8),
                crownStyle = EvolutionCrownStyle.REEF_FORTRESS,
                scaleFactor = 1.18f
            )
        ),
        EvolutionNode(
            id = "shell_tidal_seraph",
            starterId = "shell",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "漩涡巨蚌",
            roleTagZh = "水柱君王 · 强力水炮",
            descZh = "立于常驻巨型水柱之上傲视战场，高压水炮与漩涡风暴横扫千军。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "shell_vortex",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(damagePct = 0.36f, speedPct = 0.20f, areaPct = 0.32f, ultChargePct = 0.25f),
            bonusMoveId = "hydro_pump",
            ultNameZh = "强力水炮",
            visualStyle = EvolutionVisualStyle(
                starterId = "shell",
                primaryColor = Color(0xFF1E449E),
                secondaryColor = Color(0xFF58C7FF),
                accentColor = Color(0xFFB3FCFF),
                eyeColor = GoldAccent,
                auraColor = Color(0xFF58C7FF),
                crownStyle = EvolutionCrownStyle.TIDAL_SPOUT,
                scaleFactor = 1.32f
            )
        ),
        EvolutionNode(
            id = "shell_abyss_fortress",
            starterId = "shell",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "深渊圣壳",
            roleTagZh = "不朽水晶堡垒",
            descZh = "黄金与深海晶甲交织的终极神壳，超高护甲与再生能力正面硬抗守护者。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 3, EvolutionResourceType.ESSENCE_BLOOM to 3, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "shell_fortress",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 110f, armorFlat = 26f, regenFlat = 3.0f, damagePct = 0.24f),
            bonusMoveId = "hydro_pump",
            ultNameZh = "深海圣域波",
            visualStyle = EvolutionVisualStyle(
                starterId = "shell",
                primaryColor = Color(0xFF1D4559),
                secondaryColor = Color(0xFF42C4B0),
                accentColor = GoldAccent,
                eyeColor = GoldAccent,
                auraColor = GoldAccent,
                crownStyle = EvolutionCrownStyle.ABYSS_CITADEL,
                scaleFactor = 1.35f
            )
        ),

        // ==================== 雷铃狐 (ELECTRIC) EVOLUTION TREE ====================
        EvolutionNode(
            id = "spark_base",
            starterId = "spark",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "铃电幼狐",
            roleTagZh = "静电初鸣",
            descZh = "戴着电鸣风铃的瓷甲小狐，可向雷暴法狐或磁暴刺客两条路线进化。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("spark_storm", "spark_plasma"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "风铃雷暴",
            visualStyle = EvolutionVisualStyle(
                starterId = "spark",
                primaryColor = Color(0xFFF3BC32),
                secondaryColor = Color(0xFFFFE58A),
                accentColor = Color(0xFF4BF0FF),
                eyeColor = Color(0xFFFF8824),
                auraColor = Color(0xFFFFD84D),
                crownStyle = EvolutionCrownStyle.CHIME_EARS,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "spark_storm",
            starterId = "spark",
            tier = 1,
            branchLabelZh = "分支 A · 雷暴神铃",
            nameZh = "雷鸣灵狐",
            roleTagZh = "广域落雷 · 连锁",
            descZh = "背后浮现青金雷鼓光环，扩大电弧范围并强化落雷控场。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 3),
            parentNodeId = "spark_base",
            nextNodeIds = listOf("spark_thunder_deity"),
            statDelta = EvolutionStatDelta(damagePct = 0.22f, areaPct = 0.24f, ultChargePct = 0.16f),
            bonusMoveId = "thunder_nova",
            ultNameZh = "磁极天雷",
            visualStyle = EvolutionVisualStyle(
                starterId = "spark",
                primaryColor = Color(0xFFEFA81E),
                secondaryColor = Color(0xFFFFEE9C),
                accentColor = Color(0xFF4BF0FF),
                eyeColor = Color(0xFF4BF0FF),
                auraColor = Color(0xFF4BF0FF),
                crownStyle = EvolutionCrownStyle.STORM_HALO,
                scaleFactor = 1.15f
            )
        ),
        EvolutionNode(
            id = "spark_plasma",
            starterId = "spark",
            tier = 1,
            branchLabelZh = "分支 B · 磁暴瞬影",
            nameZh = "磁暴机狐",
            roleTagZh = "极速暴击 · 旋切",
            descZh = "融合潮汐结晶凝成蓝紫等离子护镜，将移速与暴击推向极致。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 2, EvolutionResourceType.ESSENCE_TIDE to 2),
            parentNodeId = "spark_base",
            nextNodeIds = listOf("spark_volt_phantom"),
            statDelta = EvolutionStatDelta(damagePct = 0.20f, speedPct = 0.20f, critPct = 0.18f),
            bonusMoveId = "spark_ring",
            ultNameZh = "等离子瞬斩",
            visualStyle = EvolutionVisualStyle(
                starterId = "spark",
                primaryColor = Color(0xFF4353A8),
                secondaryColor = Color(0xFF7B94F5),
                accentColor = Color(0xFFFFD84D),
                eyeColor = Color(0xFF66F7FF),
                auraColor = SkyBlue,
                crownStyle = EvolutionCrownStyle.PLASMA_VISOR,
                scaleFactor = 1.14f
            )
        ),
        EvolutionNode(
            id = "spark_thunder_deity",
            starterId = "spark",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "天穹雷神狐",
            roleTagZh = "雷枪贯通 · 全场天雷",
            descZh = "御雷而行的金电灵尊，苍穹雷枪与九霄雷鸣阵主宰整片战场。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "spark_storm",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 50f, damagePct = 0.38f, areaPct = 0.30f, ultChargePct = 0.25f),
            bonusMoveId = "rail_bolt",
            ultNameZh = "九霄雷鸣阵",
            visualStyle = EvolutionVisualStyle(
                starterId = "spark",
                primaryColor = Color(0xFFFFC12A),
                secondaryColor = Color(0xFFFFF5B8),
                accentColor = Color(0xFF64FAFF),
                eyeColor = Color.White,
                auraColor = GoldAccent,
                crownStyle = EvolutionCrownStyle.STORM_HALO,
                scaleFactor = 1.32f
            )
        ),
        EvolutionNode(
            id = "spark_volt_phantom",
            starterId = "spark",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "极光幻电狐",
            roleTagZh = "超光速 · 无限暴击",
            descZh = "化身霓虹极光电弧，几乎每次雷击皆为致命暴击。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_EMBER to 3, EvolutionResourceType.ESSENCE_TIDE to 3, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "spark_plasma",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(damagePct = 0.34f, speedPct = 0.26f, critPct = 0.28f, ultChargePct = 0.22f),
            bonusMoveId = "rail_bolt",
            ultNameZh = "极光超载风暴",
            visualStyle = EvolutionVisualStyle(
                starterId = "spark",
                primaryColor = Color(0xFF283470),
                secondaryColor = Color(0xFF60D9FF),
                accentColor = Color(0xFFFF6CF2),
                eyeColor = Color(0xFFFFF176),
                auraColor = Color(0xFF60D9FF),
                crownStyle = EvolutionCrownStyle.PLASMA_VISOR,
                scaleFactor = 1.29f
            )
        ),

        // ==================== 提灯幽灵 (GHOST) EVOLUTION TREE ====================
        EvolutionNode(
            id = "wisp_base",
            starterId = "wisp",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "青灯小灵",
            roleTagZh = "古灯初燃",
            descZh = "古铜月灯里摇曳的幽火精灵，可蜕变为汲魂大君或月蚀刺影。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("wisp_sovereign", "wisp_eclipse"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "幽灯召魂",
            visualStyle = EvolutionVisualStyle(
                starterId = "wisp",
                primaryColor = Color(0xFF6249B8),
                secondaryColor = Color(0xFF8E73E6),
                accentColor = Color(0xFF5AF2E8),
                eyeColor = Color(0xFFFFF494),
                auraColor = Color(0xFF7B63D9),
                crownStyle = EvolutionCrownStyle.LANTERN_CREST,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "wisp_sovereign",
            starterId = "wisp",
            tier = 1,
            branchLabelZh = "分支 A · 冥灯汲魂",
            nameZh = "冥灯大君",
            roleTagZh = "永动续航 · 广域回响",
            descZh = "吸收森灵精华点亮双层灵灯，大幅强化续航再生与冥波范围。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 2, EvolutionResourceType.ESSENCE_BLOOM to 2),
            parentNodeId = "wisp_base",
            nextNodeIds = listOf("wisp_eternal_king"),
            statDelta = EvolutionStatDelta(maxHpFlat = 45f, areaPct = 0.24f, regenFlat = 2.0f, ultChargePct = 0.18f),
            bonusMoveId = "lantern_wail",
            ultNameZh = "月蚀冥潮",
            visualStyle = EvolutionVisualStyle(
                starterId = "wisp",
                primaryColor = Color(0xFF47378C),
                secondaryColor = Color(0xFF7E66D4),
                accentColor = Color(0xFF56FFBA),
                eyeColor = GoldAccent,
                auraColor = Color(0xFF56FFBA),
                crownStyle = EvolutionCrownStyle.LANTERN_CREST,
                scaleFactor = 1.16f
            )
        ),
        EvolutionNode(
            id = "wisp_eclipse",
            starterId = "wisp",
            tier = 1,
            branchLabelZh = "分支 B · 月蚀幽影",
            nameZh = "月蚀影灯",
            roleTagZh = "高爆穿透 · 诡秘疾行",
            descZh = "月轮倒悬于灯顶，放弃厚重灯甲换来凌厉的暴击与穿透射线。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 3),
            parentNodeId = "wisp_base",
            nextNodeIds = listOf("wisp_crescent_reaper"),
            statDelta = EvolutionStatDelta(damagePct = 0.28f, critPct = 0.15f, speedPct = 0.15f),
            bonusMoveId = "eclipse_ray",
            ultNameZh = "新月幽斩",
            visualStyle = EvolutionVisualStyle(
                starterId = "wisp",
                primaryColor = Color(0xFF2F2859),
                secondaryColor = Color(0xFF5B4D9E),
                accentColor = Color(0xFFFF75B8),
                eyeColor = Color(0xFF6CF7FF),
                auraColor = EpicPurple,
                crownStyle = EvolutionCrownStyle.ECLIPSE_CROWN,
                scaleFactor = 1.14f
            )
        ),
        EvolutionNode(
            id = "wisp_eternal_king",
            starterId = "wisp",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "永夜提灯王",
            roleTagZh = "不灭魂域 · 圣灯再生",
            descZh = "百鬼夜行的温和守灯君主，源源不断的生命汲取与高频必杀。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 4, EvolutionResourceType.ESSENCE_BLOOM to 2, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "wisp_sovereign",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 80f, damagePct = 0.30f, areaPct = 0.30f, regenFlat = 3.2f, ultChargePct = 0.28f),
            bonusMoveId = "eclipse_ray",
            ultNameZh = "永夜魂域",
            visualStyle = EvolutionVisualStyle(
                starterId = "wisp",
                primaryColor = Color(0xFF312469),
                secondaryColor = Color(0xFF6B52C7),
                accentColor = GoldAccent,
                eyeColor = Color(0xFF72FFCE),
                auraColor = GoldAccent,
                crownStyle = EvolutionCrownStyle.LANTERN_CREST,
                scaleFactor = 1.33f
            )
        ),
        EvolutionNode(
            id = "wisp_crescent_reaper",
            starterId = "wisp",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "绯月冥灯神",
            roleTagZh = "绯红月蚀 · 极致爆发",
            descZh = "猩红满月与幽蓝鬼火共鸣，每一次月蚀射线都宛如收割战场的镰光。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "wisp_eclipse",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(damagePct = 0.44f, critPct = 0.24f, speedPct = 0.18f, ultChargePct = 0.25f),
            bonusMoveId = "eclipse_ray",
            ultNameZh = "绯月终焉波",
            visualStyle = EvolutionVisualStyle(
                starterId = "wisp",
                primaryColor = Color(0xFF28193B),
                secondaryColor = Color(0xFF692B68),
                accentColor = Color(0xFFFF5E8E),
                eyeColor = Color(0xFFFFF494),
                auraColor = Color(0xFFFF5E8E),
                crownStyle = EvolutionCrownStyle.ECLIPSE_CROWN,
                scaleFactor = 1.30f
            )
        ),

        // ==================== 星晶幼龙 (STAR) EVOLUTION TREE ====================
        EvolutionNode(
            id = "drake_base",
            starterId = "drake",
            tier = 0,
            branchLabelZh = "初始形态",
            nameZh = "星晶幼龙",
            roleTagZh = "星辉初翼",
            descZh = "身披深蓝星鳞的结晶龙崽，可进化为星海圣龙或陨岩霸龙。",
            requiredLevel = 1,
            resourceCost = emptyMap(),
            parentNodeId = null,
            nextNodeIds = listOf("drake_astral", "drake_meteor"),
            statDelta = EvolutionStatDelta(),
            bonusMoveId = null,
            ultNameZh = "星屑陨雨",
            visualStyle = EvolutionVisualStyle(
                starterId = "drake",
                primaryColor = Color(0xFF3347A8),
                secondaryColor = Color(0xFF6680E8),
                accentColor = GoldAccent,
                eyeColor = Color(0xFFFFEE58),
                auraColor = Color(0xFF7B6CFF),
                crownStyle = EvolutionCrownStyle.CRYSTAL_WINGS,
                scaleFactor = 1.0f
            )
        ),
        EvolutionNode(
            id = "drake_astral",
            starterId = "drake",
            tier = 1,
            branchLabelZh = "分支 A · 耀星苍翼",
            nameZh = "耀星苍龙",
            roleTagZh = "星轨旋翼 · 银河光束",
            descZh = "晶翼舒展并凝聚星轨光环，攻速、范围与必杀充能全面跃升。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 3),
            parentNodeId = "drake_base",
            nextNodeIds = listOf("drake_celestial"),
            statDelta = EvolutionStatDelta(damagePct = 0.24f, areaPct = 0.22f, speedPct = 0.12f, ultChargePct = 0.20f),
            bonusMoveId = "comet_orbit",
            ultNameZh = "彗星风暴",
            visualStyle = EvolutionVisualStyle(
                starterId = "drake",
                primaryColor = Color(0xFF28409E),
                secondaryColor = Color(0xFF6D9BFF),
                accentColor = Color(0xFF75FAFF),
                eyeColor = GoldAccent,
                auraColor = Color(0xFF75FAFF),
                crownStyle = EvolutionCrownStyle.STAR_SERAPH,
                scaleFactor = 1.17f
            )
        ),
        EvolutionNode(
            id = "drake_meteor",
            starterId = "drake",
            tier = 1,
            branchLabelZh = "分支 B · 陨岩霸角",
            nameZh = "陨岩巨龙",
            roleTagZh = "重甲龙威 · 陨爆强击",
            descZh = "融合熔核火种锻造炽金陨石龙角，兼备高额护甲与毁灭级伤害。",
            requiredLevel = 3,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 2, EvolutionResourceType.ESSENCE_EMBER to 2),
            parentNodeId = "drake_base",
            nextNodeIds = listOf("drake_supernova"),
            statDelta = EvolutionStatDelta(maxHpFlat = 55f, armorFlat = 12f, damagePct = 0.28f),
            bonusMoveId = "fire_blast",
            ultNameZh = "陨星坠击",
            visualStyle = EvolutionVisualStyle(
                starterId = "drake",
                primaryColor = Color(0xFF422C66),
                secondaryColor = Color(0xFF7B4AA8),
                accentColor = WarmOrange,
                eyeColor = GoldAccent,
                auraColor = WarmOrange,
                crownStyle = EvolutionCrownStyle.METEOR_HORNS,
                scaleFactor = 1.18f
            )
        ),
        EvolutionNode(
            id = "drake_celestial",
            starterId = "drake",
            tier = 2,
            branchLabelZh = "终极形态 A",
            nameZh = "苍穹星神龙",
            roleTagZh = "星海主宰 · 银河龙息",
            descZh = "双翼化为星河结晶的传说古龙，银河龙息贯通天地无人可挡。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 5, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "drake_astral",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 70f, damagePct = 0.38f, areaPct = 0.34f, ultChargePct = 0.32f),
            bonusMoveId = "nova_breath",
            ultNameZh = "银河超新星",
            visualStyle = EvolutionVisualStyle(
                starterId = "drake",
                primaryColor = Color(0xFF1E3285),
                secondaryColor = Color(0xFF75C6FF),
                accentColor = GoldAccent,
                eyeColor = Color.White,
                auraColor = GoldAccent,
                crownStyle = EvolutionCrownStyle.STAR_SERAPH,
                scaleFactor = 1.35f
            )
        ),
        EvolutionNode(
            id = "drake_supernova",
            starterId = "drake",
            tier = 2,
            branchLabelZh = "终极形态 B",
            nameZh = "炽星霸皇龙",
            roleTagZh = "不灭龙躯 · 恒星崩塌",
            descZh = "身缠炽金星环的终极霸龙，重甲厚血与恐怖暴击一举碾碎守护者。",
            requiredLevel = 6,
            resourceCost = mapOf(EvolutionResourceType.ESSENCE_TIDE to 3, EvolutionResourceType.ESSENCE_EMBER to 3, EvolutionResourceType.STARDUST_CORE to 1),
            parentNodeId = "drake_meteor",
            nextNodeIds = emptyList(),
            statDelta = EvolutionStatDelta(maxHpFlat = 100f, armorFlat = 20f, damagePct = 0.44f, critPct = 0.18f),
            bonusMoveId = "nova_breath",
            ultNameZh = "恒星崩塌炮",
            visualStyle = EvolutionVisualStyle(
                starterId = "drake",
                primaryColor = Color(0xFF331C4A),
                secondaryColor = Color(0xFF9C3E6E),
                accentColor = Color(0xFFFF7A36),
                eyeColor = Color(0xFFFFF494),
                auraColor = Color(0xFFFF7A36),
                crownStyle = EvolutionCrownStyle.METEOR_HORNS,
                scaleFactor = 1.36f
            )
        )
    ).associateBy { it.id }

    fun baseNodeForStarter(starterId: String): EvolutionNode {
        return allNodes.values.firstOrNull { it.starterId == starterId && it.tier == 0 }
            ?: allNodes.getValue("stump_base")
    }

    fun nodeById(nodeId: String): EvolutionNode {
        return allNodes[nodeId] ?: allNodes.getValue("stump_base")
    }

    fun treeForStarter(starterId: String): List<EvolutionNode> {
        return allNodes.values
            .filter { it.starterId == starterId }
            .sortedWith(compareBy<EvolutionNode> { it.tier }.thenBy { it.id })
    }

    fun resourceForElement(element: ElementType): EvolutionResourceType = when (element) {
        ElementType.GRASS, ElementType.POISON -> EvolutionResourceType.ESSENCE_BLOOM
        ElementType.FIRE, ElementType.GROUND, ElementType.ROCK, ElementType.ELECTRIC -> EvolutionResourceType.ESSENCE_EMBER
        ElementType.WATER, ElementType.GHOST, ElementType.STAR -> EvolutionResourceType.ESSENCE_TIDE
    }
}

/**
 * Pure, decoupled Evolution Path state machine handling resource collection,
 * branch eligibility checks, cumulative stat modifiers, and evolution transitions.
 */
class EvolutionPathController(starterId: String) {
    private val baseNode = EvolutionRegistry.baseNodeForStarter(starterId)
    var currentNodeId: String = baseNode.id
        private set

    private val history = mutableListOf(baseNode.id)
    private val resources = mutableMapOf<EvolutionResourceType, Int>().apply {
        EvolutionResourceType.entries.forEach { put(it, 0) }
    }

    val currentNode: EvolutionNode
        get() = EvolutionRegistry.nodeById(currentNodeId)

    val evolutionTier: Int
        get() = currentNode.tier

    fun addResource(type: EvolutionResourceType, amount: Int = 1) {
        if (amount <= 0) return
        resources[type] = (resources[type] ?: 0) + amount
    }

    fun resourceAmount(type: EvolutionResourceType): Int = resources[type] ?: 0

    fun getAvailableNextNodes(): List<EvolutionNode> {
        return currentNode.nextNodeIds.map { EvolutionRegistry.nodeById(it) }
    }

    fun evaluateEligibility(node: EvolutionNode, playerLevel: Int): EvolutionEligibility {
        val isCurrent = node.id == currentNodeId
        val isPassed = history.contains(node.id) && !isCurrent
        val isReachable = currentNode.nextNodeIds.contains(node.id)
        val levelMet = playerLevel >= node.requiredLevel
        val missing = mutableMapOf<EvolutionResourceType, Int>()
        for ((res, need) in node.resourceCost) {
            val have = resources[res] ?: 0
            if (have < need) missing[res] = need - have
        }
        val canEvolve = isReachable && levelMet && missing.isEmpty()
        return EvolutionEligibility(
            node = node,
            isCurrent = isCurrent,
            isAlreadyPassed = isPassed,
            isReachableFromCurrent = isReachable,
            levelMet = levelMet,
            missingResources = missing,
            canEvolveNow = canEvolve
        )
    }

    fun readyNextNodes(playerLevel: Int): List<EvolutionNode> {
        return getAvailableNextNodes().filter { evaluateEligibility(it, playerLevel).canEvolveNow }
    }

    /**
     * Returns reachable next-tier evolution branches unlocked by the sprite's current level
     * (used to inject evolution form choices directly into the full-screen Level-Up Draft modal).
     */
    fun levelEligibleNextNodes(playerLevel: Int): List<EvolutionNode> {
        return getAvailableNextNodes().filter { playerLevel >= it.requiredLevel }
    }

    fun evolveTo(targetNodeId: String, playerLevel: Int): EvolutionNode? {
        val target = EvolutionRegistry.allNodes[targetNodeId] ?: return null
        val check = evaluateEligibility(target, playerLevel)
        if (!check.canEvolveNow) return null
        for ((res, cost) in target.resourceCost) {
            resources[res] = ((resources[res] ?: 0) - cost).coerceAtLeast(0)
        }
        currentNodeId = target.id
        history.add(target.id)
        return target
    }

    /**
     * Evolves directly as a Level-Up Reward choice from the full-screen upgrade modal.
     */
    fun evolveFromLevelUpReward(targetNodeId: String): EvolutionNode? {
        val target = EvolutionRegistry.allNodes[targetNodeId] ?: return null
        if (!currentNode.nextNodeIds.contains(target.id)) return null
        currentNodeId = target.id
        history.add(target.id)
        return target
    }

    /**
     * Sum cumulative stat bonuses across all evolved nodes along the chosen path.
     */
    fun cumulativeStatDelta(): EvolutionStatDelta {
        var hp = 0f
        var dmg = 0f
        var spd = 0f
        var armor = 0f
        var crit = 0f
        var area = 0f
        var regen = 0f
        var ult = 0f
        for (id in history) {
            val d = EvolutionRegistry.nodeById(id).statDelta
            hp += d.maxHpFlat
            dmg += d.damagePct
            spd += d.speedPct
            armor += d.armorFlat
            crit += d.critPct
            area += d.areaPct
            regen += d.regenFlat
            ult += d.ultChargePct
        }
        return EvolutionStatDelta(hp, dmg, spd, armor, crit, area, regen, ult)
    }

    fun snapshot(playerLevel: Int): EvolutionStateSnapshot {
        val ready = readyNextNodes(playerLevel)
        return EvolutionStateSnapshot(
            starterId = baseNode.starterId,
            currentNodeId = currentNodeId,
            historyNodeIds = history.toList(),
            resources = resources.toMap(),
            hasReadyEvolution = ready.isNotEmpty(),
            readyCount = ready.size
        )
    }
}
