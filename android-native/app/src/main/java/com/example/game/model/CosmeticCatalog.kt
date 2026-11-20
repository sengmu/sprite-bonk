package com.example.game.model

import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Color
import com.example.R
import com.example.ui.theme.CrimsonRed
import com.example.ui.theme.EpicPurple
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange

enum class CosmeticCategory(val labelZh: String) {
    SKIN("外观"),
    EFFECT("特效"),
    FRAME("头像框")
}

enum class CosmeticUnlockMethod {
    DEVNET_TOKEN,
    STARDUST,
    VICTORY_OR_STARDUST
}

data class CosmeticItem(
    val id: String,
    val nameZh: String,
    val category: CosmeticCategory,
    val rarity: Rarity,
    val starterId: String? = null,
    val stardustCost: Int = 0,
    val unlockMethod: CosmeticUnlockMethod = CosmeticUnlockMethod.STARDUST,
    val taglineZh: String,
    val descZh: String,
    val iconGlyph: String,
    val primaryTint: Color,
    val accentTint: Color,
    @DrawableRes val portraitRes: Int? = null
)

data class CosmeticLoadout(
    val ownedIds: Set<String> = emptySet(),
    val equippedSkinsByStarter: Map<String, String> = emptyMap(),
    val equippedEntranceEffectId: String? = null,
    val equippedFrameId: String? = null
) {
    val hasStarlightEntrance: Boolean
        get() = equippedEntranceEffectId == CosmeticCatalog.ID_STARLIGHT_ENTRANCE

    fun isOwned(itemId: String, devnetFoxOwned: Boolean = false): Boolean =
        itemId in ownedIds || (itemId == CosmeticCatalog.ID_FOX_SKIN && devnetFoxOwned)

    fun isEquipped(itemId: String, devnetFoxEquipped: Boolean = false): Boolean = when (itemId) {
        CosmeticCatalog.ID_FOX_SKIN ->
            devnetFoxEquipped || equippedSkinsByStarter["spark"] == itemId
        CosmeticCatalog.ID_STARLIGHT_ENTRANCE ->
            equippedEntranceEffectId == itemId
        CosmeticCatalog.ID_FOREST_NAMEPLATE, CosmeticCatalog.ID_GENESIS_FRAME ->
            equippedFrameId == itemId
        else -> {
            val item = CosmeticCatalog.byId(itemId)
            item?.starterId != null && equippedSkinsByStarter[item.starterId] == itemId
        }
    }

    fun activeSkinIdFor(starterId: String, devnetFoxEquipped: Boolean = false): String? {
        if (starterId == "spark" && devnetFoxEquipped) return CosmeticCatalog.ID_FOX_SKIN
        return equippedSkinsByStarter[starterId]
    }

    fun equippedFrame(): CosmeticItem? = equippedFrameId?.let { CosmeticCatalog.byId(it) }
}

object CosmeticCatalog {
    const val ID_FOX_SKIN = "railing-fox-shop-skin"
    const val ID_EMERALD_STUMP = "emerald-stump-skin"
    const val ID_CRIMSON_CHAR = "crimson-char-skin"
    const val ID_STARLIGHT_ENTRANCE = "starlight-entrance"
    const val ID_FOREST_NAMEPLATE = "forest-nameplate"
    const val ID_GENESIS_FRAME = "genesis-frame"

    val items: List<CosmeticItem> = listOf(
        CosmeticItem(
            id = ID_FOX_SKIN,
            nameZh = "蓝紫雷铃狐",
            category = CosmeticCategory.SKIN,
            rarity = Rarity.LEGENDARY,
            starterId = "spark",
            stardustCost = 0,
            unlockMethod = CosmeticUnlockMethod.DEVNET_TOKEN,
            taglineZh = "雷铃狐限定 · 星穹电弧配色",
            descZh = "为雷铃狐披上蓝紫星辉电羽，主界面展台、实战与训练场同步生效。",
            iconGlyph = "⚡",
            primaryTint = Color(0xFF697AE6),
            accentTint = Color(0xFF78EDFF)
        ),
        CosmeticItem(
            id = ID_EMERALD_STUMP,
            nameZh = "青绒林语",
            category = CosmeticCategory.SKIN,
            rarity = Rarity.EPIC,
            starterId = "stump",
            stardustCost = 120,
            unlockMethod = CosmeticUnlockMethod.STARDUST,
            taglineZh = "绒叶墩专属 · 翡翠月露涂装",
            descZh = "将绒叶墩染上秘境翠玉青与月光嫩芽光晕，全进化形态同步变色。",
            iconGlyph = "🌿",
            primaryTint = Color(0xFF28C99A),
            accentTint = Color(0xFFB5FFDC),
            portraitRes = R.drawable.img_starter_stump
        ),
        CosmeticItem(
            id = ID_CRIMSON_CHAR,
            nameZh = "赤焰伙伴",
            category = CosmeticCategory.SKIN,
            rarity = Rarity.EPIC,
            starterId = "char",
            stardustCost = 150,
            unlockMethod = CosmeticUnlockMethod.STARDUST,
            taglineZh = "炎尾幼龙专属 · 熔金赤龙鳞",
            descZh = "赋予炎尾幼龙炽红龙鳞与熔金烈焰尾光，展台、战斗与训练场实时呈现。",
            iconGlyph = "🔥",
            primaryTint = CrimsonRed,
            accentTint = GoldAccent,
            portraitRes = R.drawable.img_starter_char
        ),
        CosmeticItem(
            id = ID_STARLIGHT_ENTRANCE,
            nameZh = "星光出场",
            category = CosmeticCategory.EFFECT,
            rarity = Rarity.LEGENDARY,
            starterId = null,
            stardustCost = 180,
            unlockMethod = CosmeticUnlockMethod.STARDUST,
            taglineZh = "全精灵通用 · 环绕星芒光环",
            descZh = "装备后在主界面展台、战斗与招式训练场为任意精灵点亮旋转星辉与飘浮星尘。",
            iconGlyph = "✦",
            primaryTint = GoldAccent,
            accentTint = SkyBlue
        ),
        CosmeticItem(
            id = ID_FOREST_NAMEPLATE,
            nameZh = "森林名牌",
            category = CosmeticCategory.FRAME,
            rarity = Rarity.RARE,
            starterId = null,
            stardustCost = 100,
            unlockMethod = CosmeticUnlockMethod.STARDUST,
            taglineZh = "翠森鎏叶徽章 · 主页与档案生效",
            descZh = "为训练家档案星尘库与主界面铭牌镶嵌翡翠枝叶边框与森灵徽标。",
            iconGlyph = "❖",
            primaryTint = GrassGreen,
            accentTint = Color(0xFFBAFF8C)
        ),
        CosmeticItem(
            id = ID_GENESIS_FRAME,
            nameZh = "创世头像框",
            category = CosmeticCategory.FRAME,
            rarity = Rarity.LEGENDARY,
            starterId = null,
            stardustCost = 240,
            unlockMethod = CosmeticUnlockMethod.VICTORY_OR_STARDUST,
            taglineZh = "典藏王冠金框 · 首胜免费解锁",
            descZh = "达成任意 1 次冒险胜利即可免费领取（或消耗星尘提前解锁），点亮皇冠金辉铭牌。",
            iconGlyph = "♛",
            primaryTint = GoldAccent,
            accentTint = WarmOrange
        )
    )

    private val byIdMap = items.associateBy { it.id }

    fun byId(id: String): CosmeticItem? = byIdMap[id]

    fun canClaimFreeMilestone(item: CosmeticItem, totalVictories: Int): Boolean =
        item.unlockMethod == CosmeticUnlockMethod.VICTORY_OR_STARDUST && totalVictories >= 1

    fun canAfford(item: CosmeticItem, stardust: Int, totalVictories: Int): Boolean =
        when (item.unlockMethod) {
            CosmeticUnlockMethod.DEVNET_TOKEN -> false
            CosmeticUnlockMethod.STARDUST -> stardust >= item.stardustCost
            CosmeticUnlockMethod.VICTORY_OR_STARDUST ->
                totalVictories >= 1 || stardust >= item.stardustCost
        }

    fun statusBadgeText(
        item: CosmeticItem,
        loadout: CosmeticLoadout,
        totalVictories: Int,
        devnetFoxEquipped: Boolean
    ): String {
        if (loadout.isEquipped(item.id, devnetFoxEquipped)) return "已装备"
        if (loadout.isOwned(item.id, devnetFoxEquipped)) return "已拥有"
        return when (item.unlockMethod) {
            CosmeticUnlockMethod.DEVNET_TOKEN -> "1 枚测试代币"
            CosmeticUnlockMethod.STARDUST -> "${item.stardustCost} 星尘"
            CosmeticUnlockMethod.VICTORY_OR_STARDUST ->
                if (totalVictories >= 1) "首胜免费领" else "首胜免费 / ${item.stardustCost} 星尘"
        }
    }

    fun rarityBorderColor(rarity: Rarity): Color = when (rarity) {
        Rarity.COMMON -> SkyBlue
        Rarity.UNCOMMON -> Color(0xFF39C6D8)
        Rarity.RARE -> GrassGreen
        Rarity.EPIC -> EpicPurple
        Rarity.LEGENDARY -> GoldAccent
    }
}
