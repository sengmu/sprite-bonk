package com.example.game.model

import androidx.compose.ui.graphics.Color
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

enum class ElementalBondId(
    val titleZh: String,
    val shortBadgeZh: String,
    val requirementZh: String,
    val effectZh: String,
    val accentColor: Color
) {
    HYDRO_VOLT(
        titleZh = "水电感电链",
        shortBadgeZh = "⚡感电链",
        requirementZh = "同时持有「水系」与「电系」招式",
        effectZh = "攻击触发感电弧，弹射至附近2名敌人造成22%连锁雷伤",
        accentColor = Color(0xFF4BF0FF)
    ),
    VERDANT_BLAZE(
        titleZh = "草火烈焰扩散",
        shortBadgeZh = "🔥烈焰扩散",
        requirementZh = "同时持有「草系」与「火系」招式",
        effectZh = "击败灼烧敌人引发烈焰爆燃，扩散灼烧并造成范围伤害",
        accentColor = WarmOrange
    ),
    SKYBREAKER(
        titleZh = "苍穹震地",
        shortBadgeZh = "✦苍穹震地",
        requirementZh = "持有速度/范围强化，或任意2个招式达到Lv.3",
        effectZh = "高空坠击范围+35%、伤害+45%，并施加减速破势",
        accentColor = SkyBlue
    ),
    ASTRAL_OVERLOAD(
        titleZh = "星穹过载",
        shortBadgeZh = "★星穹过载",
        requirementZh = "持有3种不同属性招式，或完成任意协同/奇术融合",
        effectZh = "必杀充能+25%，暴击伤害倍率提升至 1.95×",
        accentColor = GoldAccent
    )
}

data class ActiveElementalBond(
    val id: ElementalBondId,
    val titleZh: String = id.titleZh,
    val shortBadgeZh: String = id.shortBadgeZh,
    val effectZh: String = id.effectZh,
    val accentColor: Color = id.accentColor
)

object ElementalBondSystem {

    fun evaluateActiveBonds(
        moveElements: Collection<ElementType>,
        moveLevels: Collection<Int>,
        vitaminLevels: Map<String, Int>,
        awakenedCount: Int,
        fusedCount: Int
    ): List<ElementalBondId> {
        val elemSet = moveElements.toSet()
        val result = ArrayList<ElementalBondId>(4)

        if (ElementType.WATER in elemSet && ElementType.ELECTRIC in elemSet) {
            result.add(ElementalBondId.HYDRO_VOLT)
        }
        if (ElementType.GRASS in elemSet && ElementType.FIRE in elemSet) {
            result.add(ElementalBondId.VERDANT_BLAZE)
        }
        val highLevelMoves = moveLevels.count { it >= 3 }
        val hasMobilityVit = (vitaminLevels["carbos"] ?: 0) > 0 || (vitaminLevels["ether"] ?: 0) > 0
        if (hasMobilityVit || highLevelMoves >= 2) {
            result.add(ElementalBondId.SKYBREAKER)
        }
        if (elemSet.size >= 3 || awakenedCount > 0 || fusedCount > 0) {
            result.add(ElementalBondId.ASTRAL_OVERLOAD)
        }
        return result
    }

    /**
     * Returns a helpful draft hint if picking [candidateElement] completes a new Elemental Bond.
     */
    fun bondUnlockHintForElement(
        currentElements: Set<ElementType>,
        candidateElement: ElementType
    ): String? {
        if (candidateElement in currentElements) return null
        if (candidateElement == ElementType.ELECTRIC && ElementType.WATER in currentElements) {
            return "⚡ 凑齐羁绊：水电感电链（连锁雷伤）"
        }
        if (candidateElement == ElementType.WATER && ElementType.ELECTRIC in currentElements) {
            return "⚡ 凑齐羁绊：水电感电链（连锁雷伤）"
        }
        if (candidateElement == ElementType.FIRE && ElementType.GRASS in currentElements) {
            return "🔥 凑齐羁绊：草火烈焰扩散（爆燃清场）"
        }
        if (candidateElement == ElementType.GRASS && ElementType.FIRE in currentElements) {
            return "🔥 凑齐羁绊：草火烈焰扩散（爆燃清场）"
        }
        if (currentElements.size == 2) {
            return "★ 凑齐三属性羁绊：星穹过载（暴伤1.95×）"
        }
        return null
    }
}
