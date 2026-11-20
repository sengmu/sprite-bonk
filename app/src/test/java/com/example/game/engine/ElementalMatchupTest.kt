package com.example.game.engine

import com.example.game.model.ElementType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ElementalMatchupTest {
    @Test
    fun starterTriangle_dealsSuperEffectiveAndResistedDamage() {
        assertEquals(ElementalMatchup.SUPER_EFFECTIVE_MULT, ElementalMatchup.multiplier(ElementType.GRASS, ElementType.WATER), 0.001f)
        assertEquals(ElementalMatchup.SUPER_EFFECTIVE_MULT, ElementalMatchup.multiplier(ElementType.WATER, ElementType.FIRE), 0.001f)
        assertEquals(ElementalMatchup.SUPER_EFFECTIVE_MULT, ElementalMatchup.multiplier(ElementType.FIRE, ElementType.GRASS), 0.001f)

        assertEquals(ElementalMatchup.RESISTED_MULT, ElementalMatchup.multiplier(ElementType.GRASS, ElementType.FIRE), 0.001f)
        assertEquals(ElementalMatchup.RESISTED_MULT, ElementalMatchup.multiplier(ElementType.FIRE, ElementType.WATER), 0.001f)
        assertEquals(ElementalMatchup.RESISTED_MULT, ElementalMatchup.multiplier(ElementType.WATER, ElementType.GRASS), 0.001f)
    }

    @Test
    fun specialTypes_haveExpectedCounters() {
        assertTrue(ElementalMatchup.isSuperEffective(ElementType.ELECTRIC, ElementType.WATER))
        assertTrue(ElementalMatchup.isSuperEffective(ElementType.STAR, ElementType.GHOST))
        assertTrue(ElementalMatchup.isSuperEffective(ElementType.GHOST, ElementType.POISON))
        assertFalse(ElementalMatchup.isSuperEffective(ElementType.ELECTRIC, ElementType.GROUND))
    }
}
