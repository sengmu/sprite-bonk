package com.example.game.model

import androidx.compose.ui.graphics.Color
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

/**
 * High-impact Guardian / Boss Relics drafted mid-run (Lv.5 milestone in Classic/Duel,
 * and after every Guardian defeat in Endless Survival).
 */
enum class BossRelicId(
    val titleZh: String,
    val subtitleZh: String,
    val descZh: String,
    val rarity: Rarity,
    val accentColor: Color
) {
    CRIMSON_FANG(
        titleZh = "绯红猎牙",
        subtitleZh = "暴击吸血 · 猛攻遗物",
        descZh = "暴击率 +12%，每次暴击回复 2 点生命（内置 0.6 秒冷却）",
        rarity = Rarity.EPIC,
        accentColor = CrimsonRed
    ),
    TEMPEST_CHRONO(
        titleZh = "疾风时计",
        subtitleZh = "冷却缩减 · 疾速遗物",
        descZh = "全部招式攻速 +18%，闪避冲刺冷却大幅缩短 25%",
        rarity = Rarity.EPIC,
        accentColor = SkyBlue
    ),
    STARFORGE_CORE(
        titleZh = "星铸核心",
        subtitleZh = "必杀超载 · 星辉遗物",
        descZh = "必杀与超觉醒充能效率 +35%，释放必杀时立即回复 15 HP",
        rarity = Rarity.LEGENDARY,
        accentColor = GoldAccent
    ),
    AEGIS_SHELL(
        titleZh = "圣盾贝壳",
        subtitleZh = "重甲壁垒 · 守护遗物",
        descZh = "最大生命 +45，护甲 +10，受击后无敌保护延长至 0.90 秒",
        rarity = Rarity.RARE,
        accentColor = Color(0xFF4ED8B0)
    ),
    PRISM_LENS(
        titleZh = "棱镜增幅仪",
        subtitleZh = "广域共鸣 · 羁绊遗物",
        descZh = "技能范围 +22%，元素羁绊触发伤害额外提升 30%",
        rarity = Rarity.EPIC,
        accentColor = EpicPurple
    ),
    GREED_COMPASS(
        titleZh = "星尘罗盘",
        subtitleZh = "丰饶战利 · 收藏遗物",
        descZh = "本局结算星尘 +35%，经验与星尘拾取磁力半径 +45%",
        rarity = Rarity.RARE,
        accentColor = Color(0xFFFFD15C)
    ),
    ECHO_CHIME(
        titleZh = "回响风铃",
        subtitleZh = "闪避震荡 · 灵动遗物",
        descZh = "每次闪避冲刺在原地引爆高伤元素震荡环并击退敌潮",
        rarity = Rarity.EPIC,
        accentColor = Color(0xFF56F2FF)
    ),
    PHOENIX_FEATHER(
        titleZh = "炽羽余烬",
        subtitleZh = "涅槃重生 · 传说遗物",
        descZh = "额外获得 1 次濒死复生机会，复生时释放灼热清场冲击波",
        rarity = Rarity.LEGENDARY,
        accentColor = WarmOrange
    );

    val badgeZh: String
        get() = "◆ $titleZh"
}

object BossRelicSystem {
    /**
     * Rolls up to [count] distinct unowned relics for a Guardian Relic draft.
     */
    fun rollDraftOptions(
        ownedRelics: Set<BossRelicId>,
        count: Int = 3,
        rng: kotlin.random.Random = kotlin.random.Random
    ): List<BossRelicId> {
        val candidates = BossRelicId.entries.filter { it !in ownedRelics }
        if (candidates.isEmpty()) return emptyList()
        return candidates.shuffled(rng).take(count.coerceAtLeast(1))
    }

    fun combinedStardustBonusPct(ownedRelics: Collection<BossRelicId>): Int {
        return if (BossRelicId.GREED_COMPASS in ownedRelics) 35 else 0
    }

    fun bondDamageMultiplier(ownedRelics: Collection<BossRelicId>): Float {
        return if (BossRelicId.PRISM_LENS in ownedRelics) 1.30f else 1.0f
    }

    fun invulnWindowSec(ownedRelics: Collection<BossRelicId>): Float {
        return if (BossRelicId.AEGIS_SHELL in ownedRelics) 0.90f else 0.55f
    }
}
