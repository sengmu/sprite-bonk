package com.example.game

import com.example.data.BiomeProgressEntity
import com.example.data.DexEntryEntity
import com.example.data.MetaProgressionSnapshot
import com.example.data.ProfileEntity
import com.example.game.engine.GameSimulation
import com.example.game.evolution.EvolutionRegistry
import com.example.game.model.ChallengeModifier
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MetaMasteryAndSynergyTest {

    private fun newSim(
        starterId: String = "char",
        biomeId: String = "forest",
        challenges: Set<ChallengeModifier> = emptySet()
    ): GameSimulation = GameSimulation(
        starter = GameCatalog.starterById(starterId),
        biome = GameCatalog.biomeById(biomeId),
        gameMode = GameMode.CLASSIC,
        labLevels = emptyMap(),
        autoAimEnabled = true,
        screenShakeEnabled = true,
        onSfx = {},
        onHaptic = {},
        challengeModifiers = challenges
    )

    @Test
    fun `meta mastery calculator computes permanent bonuses and achievement progress accurately`() {
        val extraEvoIds = EvolutionRegistry.allNodes.values
            .filter { it.tier > 0 }
            .take(4)
            .map { it.id }
        val baseEvoIds = EvolutionRegistry.allNodes.values
            .filter { it.tier == 0 }
            .map { it.id }

        val bosses = GameCatalog.enemies.values.filter { it.isBoss }.take(2)
        val regulars = GameCatalog.enemies.values.filter { !it.isBoss }.take(6)
        val dexMap = buildMap {
            bosses.forEach { put(it.id, DexEntryEntity(it.id, seenCount = 2, defeatedCount = 1)) }
            regulars.forEach { put(it.id, DexEntryEntity(it.id, seenCount = 5, defeatedCount = 4)) }
        }
        val biomeProg = GameCatalog.biomes.associate { b ->
            b.id to BiomeProgressEntity(b.id, clearedCount = 1, bestTimeSec = 180)
        }

        val snapshot = MetaProgressionSnapshot(
            profile = ProfileEntity(
                stardust = 500,
                totalStardust = 1500,
                totalKills = 250,
                totalRuns = 10,
                totalVictories = 4,
                unlockedEvolutionIds = (baseEvoIds + extraEvoIds).joinToString(",")
            ),
            biomeProgress = biomeProg,
            dexEntries = dexMap
        )

        val bonuses = MetaMasteryCalculator.compute(snapshot)

        assertEquals(0.06f, bonuses.damageBonusPct, 0.001f)
        assertEquals(24f, bonuses.maxHpFlatBonus, 0.01f)
        assertEquals(0.04f, bonuses.critBonusPct, 0.001f)
        assertEquals(0.08f, bonuses.ultChargeBonusPct, 0.001f)
        assertEquals(7, bonuses.completedAchievementCount)
        assertEquals(0.35f, bonuses.stardustBonusPct, 0.001f)
        assertTrue(bonuses.hasAnyBonus)
        assertEquals(5, bonuses.summaryChips().size)
    }

    @Test
    fun `challenge modifiers stack stardust bonus and scale boss hp and run settlement reward`() {
        val mods = setOf(ChallengeModifier.IRON_CARAPACE, ChallengeModifier.GLASS_CANNON)
        assertEquals(55, MetaMasteryCalculator.combinedChallengeStardustBonusPct(mods))

        val baseSim = newSim(challenges = emptySet())
        val hardSim = newSim(challenges = mods)

        baseSim.forceSpawnBossForTest()
        hardSim.forceSpawnBossForTest()

        val baseState = baseSim.step(1f / 60f)
        val hardState = hardSim.step(1f / 60f)

        val baseBossMaxHp = baseState.enemies.first { it.isBoss }.maxHp
        val hardBossMaxHp = hardState.enemies.first { it.isBoss }.maxHp

        assertEquals(2, hardState.activeChallengeCount)
        assertEquals(55, hardState.challengeStardustBonusPct)
        assertTrue(
            "IRON_CARAPACE should boost boss max HP by ~35% (base=$baseBossMaxHp, hard=$hardBossMaxHp)",
            hardBossMaxHp > baseBossMaxHp * 1.30f
        )

        // Grant identical kills above the 15-stardust floor so challenge multiplier is verified deterministically
        baseSim.addKillsForTest(40)
        hardSim.addKillsForTest(40)
        val baseSummary = baseSim.abandonRun()
        val hardSummary = hardSim.abandonRun()
        assertTrue(
            "Challenge modifiers (+55%) should multiply earned Stardust (base=${baseSummary.stardustEarned}, hard=${hardSummary.stardustEarned})",
            hardSummary.stardustEarned > baseSummary.stardustEarned * 1.45f
        )
    }

    @Test
    fun `move and vitamin synergy triggers awakening and marks awakened projectiles or arcs`() {
        val sim = newSim()
        sim.forceSpawnBossForTest()

        // Pair ember + protein -> awakens "★超新星连炎"
        sim.grantSynergySetupForTest(moveId = "ember", vitaminId = "protein")

        var sawAwakenedProjectile = false
        var state = sim.step(0.05f)
        assertEquals("Awakened synergy count should increment to 1", 1, state.activeSynergyCount)

        repeat(45) {
            state = sim.step(0.05f)
            if (state.projectiles.any { it.isAwakened }) {
                sawAwakenedProjectile = true
            }
        }
        assertTrue("Awakened ember should spawn projectiles flagged with isAwakened=true", sawAwakenedProjectile)
    }
}
