package com.example.game

import com.example.data.MetaProgressionSnapshot
import com.example.data.ProfileEntity
import com.example.game.engine.GameSimulation
import com.example.game.model.BossRelicId
import com.example.game.model.BossRelicSystem
import com.example.game.model.ChallengeModifier
import com.example.game.model.DifficultyTier
import com.example.game.model.ElementType
import com.example.game.model.ElementalBondId
import com.example.game.model.ElementalBondSystem
import com.example.game.model.GameCatalog
import com.example.game.model.GameMode
import com.example.game.model.MetaMasteryCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class RelicsDifficultyAndBondsTest {

    @Test
    fun `difficulty tiers scale enemy threat and stack stardust bonus with challenge modifiers`() {
        assertEquals(0, DifficultyTier.STANDARD.stardustBonusPct)
        assertEquals(35, DifficultyTier.ELITE.stardustBonusPct)
        assertEquals(75, DifficultyTier.ABYSS.stardustBonusPct)
        assertTrue(DifficultyTier.ELITE.enemyHpMult > DifficultyTier.STANDARD.enemyHpMult)
        assertTrue(DifficultyTier.ABYSS.enemyHpMult > DifficultyTier.ELITE.enemyHpMult)
        assertTrue(DifficultyTier.ABYSS.enemyDamageMult > DifficultyTier.ELITE.enemyDamageMult)
        assertEquals(DifficultyTier.STANDARD, DifficultyTier.fromId("unknown_tier"))
        assertEquals(DifficultyTier.ABYSS, DifficultyTier.fromId("abyss"))

        val combined = MetaMasteryCalculator.combinedChallengeStardustBonusPct(
            modifiers = setOf(ChallengeModifier.SWARM_FRENZY, ChallengeModifier.IRON_CARAPACE),
            difficulty = DifficultyTier.ABYSS
        )
        assertEquals(75 + 30 + 30, combined)
    }

    @Test
    fun `new elemental bonds phantom frost and solar tempest evaluate and emit draft hints`() {
        val frostBonds = ElementalBondSystem.evaluateActiveBonds(
            moveElements = listOf(ElementType.GHOST, ElementType.WATER),
            moveLevels = listOf(1, 1),
            vitaminLevels = emptyMap(),
            awakenedCount = 0,
            fusedCount = 0
        )
        assertTrue(ElementalBondId.PHANTOM_FROST in frostBonds)
        assertFalse(ElementalBondId.SOLAR_TEMPEST in frostBonds)

        val tempestFireBonds = ElementalBondSystem.evaluateActiveBonds(
            moveElements = listOf(ElementType.ELECTRIC, ElementType.FIRE),
            moveLevels = listOf(1, 1),
            vitaminLevels = emptyMap(),
            awakenedCount = 0,
            fusedCount = 0
        )
        assertTrue(ElementalBondId.SOLAR_TEMPEST in tempestFireBonds)

        val tempestStarBonds = ElementalBondSystem.evaluateActiveBonds(
            moveElements = listOf(ElementType.ELECTRIC, ElementType.STAR),
            moveLevels = listOf(1, 1),
            vitaminLevels = emptyMap(),
            awakenedCount = 0,
            fusedCount = 0
        )
        assertTrue(ElementalBondId.SOLAR_TEMPEST in tempestStarBonds)

        val frostHint = ElementalBondSystem.bondUnlockHintForElement(
            currentElements = setOf(ElementType.GHOST),
            candidateElement = ElementType.WATER
        )
        assertNotNull(frostHint)
        assertTrue(frostHint!!.contains("幽冥霜潮"))

        val tempestHint = ElementalBondSystem.bondUnlockHintForElement(
            currentElements = setOf(ElementType.ELECTRIC),
            candidateElement = ElementType.STAR
        )
        assertNotNull(tempestHint)
        assertTrue(tempestHint!!.contains("烈阳雷暴"))
    }

    @Test
    fun `boss relic system rolls distinct unowned options and computes relic multipliers`() {
        val owned = setOf(BossRelicId.CRIMSON_FANG, BossRelicId.AEGIS_SHELL)
        val rolled = BossRelicSystem.rollDraftOptions(ownedRelics = owned, count = 3, rng = Random(42))
        assertEquals(3, rolled.size)
        assertEquals(3, rolled.toSet().size)
        assertTrue(rolled.none { it in owned })

        val exhausted = BossRelicSystem.rollDraftOptions(ownedRelics = BossRelicId.entries.toSet(), count = 3)
        assertTrue(exhausted.isEmpty())

        assertEquals(0, BossRelicSystem.combinedStardustBonusPct(emptyList()))
        assertEquals(35, BossRelicSystem.combinedStardustBonusPct(listOf(BossRelicId.GREED_COMPASS)))
        assertEquals(1.0f, BossRelicSystem.bondDamageMultiplier(emptyList()), 0.0001f)
        assertEquals(1.30f, BossRelicSystem.bondDamageMultiplier(listOf(BossRelicId.PRISM_LENS)), 0.0001f)
        assertEquals(0.55f, BossRelicSystem.invulnWindowSec(emptyList()), 0.0001f)
        assertEquals(0.90f, BossRelicSystem.invulnWindowSec(listOf(BossRelicId.AEGIS_SHELL)), 0.0001f)
    }

    @Test
    fun `game simulation relic draft pauses sim and applies relic stats on selection`() {
        val sim = GameSimulation(
            starter = GameCatalog.starterById("stump"),
            biome = GameCatalog.biomeById("forest"),
            gameMode = GameMode.CLASSIC,
            labLevels = emptyMap(),
            autoAimEnabled = true,
            screenShakeEnabled = false,
            onSfx = {},
            onHaptic = {},
            difficulty = DifficultyTier.ELITE
        )

        val beforeSnapshot = sim.step(0f)
        assertEquals(DifficultyTier.ELITE, beforeSnapshot.difficulty)
        assertNull(beforeSnapshot.relicDraftOptions)
        assertTrue(beforeSnapshot.activeRelics.isEmpty())

        assertTrue(sim.forceOpenRelicDraftForTest())
        val draftSnapshot = sim.step(0f)
        val options = draftSnapshot.relicDraftOptions
        assertNotNull(options)
        assertEquals(3, options!!.size)

        // While relic draft is open, step() must keep elapsedSec paused
        val pausedElapsed = draftSnapshot.elapsedSec
        val stillPaused = sim.step(0.5f)
        assertEquals(pausedElapsed, stillPaused.elapsedSec, 0.0001f)

        val chosen = options.first()
        assertTrue(sim.selectRelic(chosen))
        val afterSnapshot = sim.step(0f)
        assertNull(afterSnapshot.relicDraftOptions)
        assertTrue(chosen in afterSnapshot.activeRelics)

        // Selecting AEGIS_SHELL / CRIMSON_FANG specifically mutates live combat stats
        if (chosen == BossRelicId.AEGIS_SHELL) {
            assertTrue(afterSnapshot.maxHp >= beforeSnapshot.maxHp + 44f)
        } else if (chosen == BossRelicId.CRIMSON_FANG) {
            assertTrue(afterSnapshot.buildStats.critPct >= beforeSnapshot.buildStats.critPct + 12)
        }

        // Simulation resumes advancing elapsed time after selection
        val resumed = sim.step(0.1f)
        assertTrue(resumed.elapsedSec > pausedElapsed)
    }

    @Test
    fun `abyss difficulty scales boss hp and increases settlement stardust over standard`() {
        val standardSim = GameSimulation(
            starter = GameCatalog.starterById("char"),
            biome = GameCatalog.biomeById("forest"),
            gameMode = GameMode.SURVIVAL,
            labLevels = emptyMap(),
            autoAimEnabled = true,
            screenShakeEnabled = false,
            onSfx = {},
            onHaptic = {},
            difficulty = DifficultyTier.STANDARD
        )
        val abyssSim = GameSimulation(
            starter = GameCatalog.starterById("char"),
            biome = GameCatalog.biomeById("forest"),
            gameMode = GameMode.SURVIVAL,
            labLevels = emptyMap(),
            autoAimEnabled = true,
            screenShakeEnabled = false,
            onSfx = {},
            onHaptic = {},
            difficulty = DifficultyTier.ABYSS
        )

        standardSim.forceSpawnBossForTest()
        abyssSim.forceSpawnBossForTest()
        val stdBossHp = standardSim.step(1f / 60f).enemies.first { it.isBoss }.maxHp
        val abyssBossHp = abyssSim.step(1f / 60f).enemies.first { it.isBoss }.maxHp
        assertTrue(
            "Expected ABYSS boss maxHp ($abyssBossHp) >= 1.55x STANDARD ($stdBossHp)",
            abyssBossHp >= stdBossHp * 1.55f
        )

        standardSim.addKillsForTest(40)
        abyssSim.addKillsForTest(40)
        val standardSummary = standardSim.abandonRun()
        val abyssSummary = abyssSim.abandonRun()
        assertEquals(DifficultyTier.STANDARD, standardSummary.difficulty)
        assertEquals(DifficultyTier.ABYSS, abyssSummary.difficulty)
        assertTrue(
            "Expected ABYSS stardust (${abyssSummary.stardustEarned}) >= 1.65x STANDARD (${standardSummary.stardustEarned})",
            abyssSummary.stardustEarned >= standardSummary.stardustEarned * 1.65f
        )
    }

    @Test
    fun `endgame mastery achievements unlock at 180s survival and 3 victories`() {
        val earlyMeta = MetaProgressionSnapshot(
            profile = ProfileEntity(
                bestSurvivalSec = 90,
                totalVictories = 1
            )
        )
        val earlyBonuses = MetaMasteryCalculator.compute(earlyMeta)
        val earlyEndless = earlyBonuses.achievements.first { it.id == "ach_endless_survivor" }
        val earlyChamp = earlyBonuses.achievements.first { it.id == "ach_champion_streak" }
        assertFalse(earlyEndless.completed)
        assertFalse(earlyChamp.completed)

        val endgameMeta = MetaProgressionSnapshot(
            profile = ProfileEntity(
                bestSurvivalSec = 215,
                totalVictories = 4
            )
        )
        val endgameBonuses = MetaMasteryCalculator.compute(endgameMeta)
        assertTrue(endgameBonuses.achievements.first { it.id == "ach_endless_survivor" }.completed)
        assertTrue(endgameBonuses.achievements.first { it.id == "ach_champion_streak" }.completed)
        assertTrue(endgameBonuses.stardustBonusPct >= 0.10f)
    }

    @Test
    fun `plan A xp curve scales steeply and banks overflow xp without overwriting active draft`() {
        assertEquals(75f, GameSimulation.xpRequirementForLevel(1), 0.01f)
        assertEquals(119.5f, GameSimulation.xpRequirementForLevel(2), 0.01f)
        assertEquals(331f, GameSimulation.xpRequirementForLevel(5), 0.01f)
        assertEquals(943.5f, GameSimulation.xpRequirementForLevel(10), 0.01f)

        val sim = GameSimulation(
            starter = GameCatalog.starterById("stump"),
            biome = GameCatalog.biomeById("forest"),
            gameMode = GameMode.CLASSIC,
            labLevels = emptyMap(),
            autoAimEnabled = true,
            screenShakeEnabled = false,
            onSfx = {},
            onHaptic = {}
        )
        assertEquals(75f, sim.step(0f).xpToNext, 0.01f)

        // Grant enough XP for 2 full level-ups at once (75 + 119.5 + 10 = 204.5)
        sim.grantXpForTest(204.5f)
        val firstDraft = sim.step(0f)
        assertEquals("Should only advance 1 level while draft modal is open", 2, firstDraft.level)
        assertNotNull("Draft modal should open on Lv.2", firstDraft.draftOptions)
        assertTrue("Overflow XP should remain safely banked", firstDraft.xp >= 119.5f)

        // Picking a draft card closes modal and triggers a 0.65s breather before next banked level-up
        val chosenOptionId = firstDraft.draftOptions!!.first().id
        sim.selectDraftOption(chosenOptionId)
        val duringBreather = sim.step(0.05f)
        assertEquals("Should remain Lv.2 during post-draft breather", 2, duringBreather.level)
        assertNull("Should not immediately slam a second modal", duringBreather.draftOptions)

        // Once 0.65s breather elapses (14 * 0.05s = 0.70s), banked XP automatically triggers Lv.3 draft
        repeat(14) { sim.step(0.05f) }
        val secondDraft = sim.step(0.05f)
        assertEquals("Banked XP should trigger Lv.3 after breather", 3, secondDraft.level)
        assertNotNull("Second level-up draft should open cleanly", secondDraft.draftOptions)
    }
}
