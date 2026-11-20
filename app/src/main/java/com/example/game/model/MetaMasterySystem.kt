package com.example.game.model

import com.example.data.MetaProgressionSnapshot
import com.example.game.evolution.EvolutionRegistry

/**
 * Optional high-risk, high-reward Challenge Modifiers selectable before a run.
 * Stacking multiple modifiers escalates enemy threat while multiplying Stardust rewards.
 */
enum class ChallengeModifier(
    val id: String,
    val nameZh: String,
    val shortEffectZh: String,
    val stardustBonusPct: Int,
    val enemyHpMult: Float = 1f,
    val enemySpeedMult: Float = 1f,
    val spawnRateMult: Float = 1f,
    val playerDmgMult: Float = 1f,
    val playerTakenMult: Float = 1f,
    val eliteChanceBonus: Float = 0f
) {
    SWARM_FRENZY(
        id = "swarm_frenzy",
        nameZh = "狂潮涌动",
        shortEffectZh = "敌潮密度 +35% · 移速 +12%",
        stardustBonusPct = 30,
        enemySpeedMult = 1.12f,
        spawnRateMult = 1.35f
    ),
    IRON_CARAPACE(
        id = "iron_carapace",
        nameZh = "重甲强化",
        shortEffectZh = "敌怪与守护者血量 +35%",
        stardustBonusPct = 30,
        enemyHpMult = 1.35f
    ),
    GLASS_CANNON(
        id = "glass_cannon",
        nameZh = "极限脆刃",
        shortEffectZh = "我方伤害 +25% · 承伤 +35%",
        stardustBonusPct = 25,
        playerDmgMult = 1.25f,
        playerTakenMult = 1.35f
    ),
    ELITE_SURGE(
        id = "elite_surge",
        nameZh = "精英沸腾",
        shortEffectZh = "精英怪出现率翻倍 · 攻势更密",
        stardustBonusPct = 35,
        enemyHpMult = 1.12f,
        eliteChanceBonus = 0.12f
    )
}

data class MasteryAchievement(
    val id: String,
    val titleZh: String,
    val descZh: String,
    val progressText: String,
    val progressFrac: Float,
    val completed: Boolean,
    val rewardTagZh: String
)

/**
 * Permanent account-wide bonuses derived directly from Dex collection, kill milestones,
 * and unlocked achievements — feeding long-term exploration straight back into combat!
 */
data class MetaMasteryBonuses(
    val unlockedEvolutionCount: Int = 0,
    val totalEvolutionCount: Int = 1,
    val discoveredSpeciesCount: Int = 0,
    val totalSpeciesCount: Int = 1,
    val bossDefeatedTotal: Int = 0,
    val damageBonusPct: Float = 0f,
    val maxHpFlatBonus: Float = 0f,
    val critBonusPct: Float = 0f,
    val ultChargeBonusPct: Float = 0f,
    val stardustBonusPct: Float = 0f,
    val achievements: List<MasteryAchievement> = emptyList()
) {
    val completedAchievementCount: Int
        get() = achievements.count { it.completed }

    val hasAnyBonus: Boolean
        get() = damageBonusPct > 0f || maxHpFlatBonus > 0f || critBonusPct > 0f ||
            ultChargeBonusPct > 0f || stardustBonusPct > 0f

    fun summaryChips(): List<String> = buildList {
        if (damageBonusPct > 0.001f) add("全伤 +${(damageBonusPct * 100).toInt()}%")
        if (maxHpFlatBonus > 0.5f) add("生命 +${maxHpFlatBonus.toInt()}")
        if (critBonusPct > 0.001f) add("暴击 +${(critBonusPct * 100).toInt()}%")
        if (ultChargeBonusPct > 0.001f) add("必杀充能 +${(ultChargeBonusPct * 100).toInt()}%")
        if (stardustBonusPct > 0.001f) add("星尘 +${(stardustBonusPct * 100).toInt()}%")
    }
}

object MetaMasteryCalculator {

    fun compute(meta: MetaProgressionSnapshot): MetaMasteryBonuses {
        val unlockedSet = meta.unlockedEvolutionSet()
        val allEvoNodes = EvolutionRegistry.allNodes.values
        val totalEvos = allEvoNodes.size.coerceAtLeast(1)
        val unlockedEvos = allEvoNodes.count { it.tier == 0 || it.id in unlockedSet }
        // Non-starter evolutions unlocked above the 6 base forms
        val extraEvosUnlocked = (unlockedEvos - GameCatalog.starters.size).coerceAtLeast(0)

        val allEnemies = GameCatalog.enemies.values
        val totalSpecies = allEnemies.size.coerceAtLeast(1)
        val discoveredSpecies = allEnemies.count { (meta.dexEntries[it.id]?.seenCount ?: 0) > 0 }
        val bossDefeatedTotal = allEnemies
            .filter { it.isBoss }
            .sumOf { meta.dexEntries[it.id]?.defeatedCount ?: 0 }
        val totalBiomesCleared = meta.biomeProgress.values.count { it.clearedCount > 0 }

        // 1. Evolution collection -> +3% Damage per 2 non-base forms unlocked (up to +18%)
        val damageBonusPct = ((extraEvosUnlocked / 2) * 0.03f).coerceAtMost(0.18f)

        // 2. Wild species discovery -> +6 Max HP per 2 species discovered (up to +48 HP)
        val maxHpFlatBonus = ((discoveredSpecies / 2) * 6f).coerceAtMost(48f)

        // 3. Lifetime kill milestones -> Crit +2% / +4% / +6% / +8%
        val kills = meta.profile.totalKills
        val critBonusPct = when {
            kills >= 1500 -> 0.08f
            kills >= 600 -> 0.06f
            kills >= 200 -> 0.04f
            kills >= 50 -> 0.02f
            else -> 0f
        }

        // 4. Guardian Boss defeats -> Ult charge efficiency +4% per boss kill tier (up to +16%)
        val ultChargeBonusPct = when {
            bossDefeatedTotal >= 8 -> 0.16f
            bossDefeatedTotal >= 4 -> 0.12f
            bossDefeatedTotal >= 2 -> 0.08f
            bossDefeatedTotal >= 1 -> 0.04f
            else -> 0f
        }

        val achievements = listOf(
            MasteryAchievement(
                id = "ach_first_blood",
                titleZh = "初露锋芒",
                descZh = "累计击败 50 名群落敌怪",
                progressText = "${kills.coerceAtMost(50)}/50",
                progressFrac = (kills / 50f).coerceIn(0f, 1f),
                completed = kills >= 50,
                rewardTagZh = "星尘 +5%"
            ),
            MasteryAchievement(
                id = "ach_species_scout",
                titleZh = "生态学者",
                descZh = "图鉴发现至少 8 种野外精灵",
                progressText = "${discoveredSpecies.coerceAtMost(8)}/8",
                progressFrac = (discoveredSpecies / 8f).coerceIn(0f, 1f),
                completed = discoveredSpecies >= 8,
                rewardTagZh = "星尘 +5%"
            ),
            MasteryAchievement(
                id = "ach_evo_keeper",
                titleZh = "进化先驱",
                descZh = "解锁至少 4 种分支进化形态",
                progressText = "${extraEvosUnlocked.coerceAtMost(4)}/4",
                progressFrac = (extraEvosUnlocked / 4f).coerceIn(0f, 1f),
                completed = extraEvosUnlocked >= 4,
                rewardTagZh = "星尘 +5%"
            ),
            MasteryAchievement(
                id = "ach_boss_slayer",
                titleZh = "守护者克星",
                descZh = "累计击败 2 位群落守护者 Boss",
                progressText = "${bossDefeatedTotal.coerceAtMost(2)}/2",
                progressFrac = (bossDefeatedTotal / 2f).coerceIn(0f, 1f),
                completed = bossDefeatedTotal >= 2,
                rewardTagZh = "星尘 +5%"
            ),
            MasteryAchievement(
                id = "ach_biome_master",
                titleZh = "群落征服者",
                descZh = "通关全部 4 大群落试炼",
                progressText = "${totalBiomesCleared.coerceAtMost(4)}/4",
                progressFrac = (totalBiomesCleared / 4f).coerceIn(0f, 1f),
                completed = totalBiomesCleared >= 4,
                rewardTagZh = "星尘 +5%"
            ),
            MasteryAchievement(
                id = "ach_stardust_tycoon",
                titleZh = "星尘大亨",
                descZh = "累计收集 1200 星尘",
                progressText = "${meta.profile.totalStardust.coerceAtMost(1200)}/1200",
                progressFrac = (meta.profile.totalStardust / 1200f).coerceIn(0f, 1f),
                completed = meta.profile.totalStardust >= 1200,
                rewardTagZh = "星尘 +5%"
            )
        )

        val completedAchCount = achievements.count { it.completed }
        val stardustBonusPct = completedAchCount * 0.05f

        return MetaMasteryBonuses(
            unlockedEvolutionCount = unlockedEvos,
            totalEvolutionCount = totalEvos,
            discoveredSpeciesCount = discoveredSpecies,
            totalSpeciesCount = totalSpecies,
            bossDefeatedTotal = bossDefeatedTotal,
            damageBonusPct = damageBonusPct,
            maxHpFlatBonus = maxHpFlatBonus,
            critBonusPct = critBonusPct,
            ultChargeBonusPct = ultChargeBonusPct,
            stardustBonusPct = stardustBonusPct,
            achievements = achievements
        )
    }

    fun combinedChallengeStardustBonusPct(modifiers: Set<ChallengeModifier>): Int {
        var total = 0
        for (mod in modifiers) total += mod.stardustBonusPct
        return total
    }
}
