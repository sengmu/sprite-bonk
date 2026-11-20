package com.example.game.engine

import com.example.game.model.ElementType

/**
 * PokéBonk-aligned elemental type effectiveness table for Sprite Bonk's 9 original elements.
 * Super-effective hits deal 1.45x damage with a crisp "克制!" visual indicator;
 * resisted hits deal 0.82x damage so build variety and drafting choices matter strategically.
 */
object ElementalMatchup {
    const val SUPER_EFFECTIVE_MULT = 1.45f
    const val RESISTED_MULT = 0.82f
    const val NEUTRAL_MULT = 1.0f

    fun multiplier(attack: ElementType, defend: ElementType): Float = when (attack) {
        ElementType.GRASS -> when (defend) {
            ElementType.WATER, ElementType.GROUND, ElementType.ROCK -> SUPER_EFFECTIVE_MULT
            ElementType.FIRE, ElementType.POISON -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.FIRE -> when (defend) {
            ElementType.GRASS, ElementType.POISON -> SUPER_EFFECTIVE_MULT
            ElementType.WATER, ElementType.ROCK -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.WATER -> when (defend) {
            ElementType.FIRE, ElementType.GROUND, ElementType.ROCK -> SUPER_EFFECTIVE_MULT
            ElementType.GRASS -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.ELECTRIC -> when (defend) {
            ElementType.WATER, ElementType.STAR -> SUPER_EFFECTIVE_MULT
            ElementType.GROUND, ElementType.GRASS -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.GHOST -> when (defend) {
            ElementType.GHOST, ElementType.POISON -> SUPER_EFFECTIVE_MULT
            ElementType.ROCK -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.STAR -> when (defend) {
            ElementType.GHOST, ElementType.ROCK, ElementType.FIRE -> SUPER_EFFECTIVE_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.GROUND -> when (defend) {
            ElementType.FIRE, ElementType.ELECTRIC, ElementType.ROCK, ElementType.POISON -> SUPER_EFFECTIVE_MULT
            ElementType.GRASS -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.ROCK -> when (defend) {
            ElementType.FIRE, ElementType.ELECTRIC -> SUPER_EFFECTIVE_MULT
            ElementType.GROUND -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
        ElementType.POISON -> when (defend) {
            ElementType.GRASS -> SUPER_EFFECTIVE_MULT
            ElementType.GROUND, ElementType.ROCK, ElementType.GHOST -> RESISTED_MULT
            else -> NEUTRAL_MULT
        }
    }

    fun isSuperEffective(attack: ElementType, defend: ElementType): Boolean =
        multiplier(attack, defend) >= 1.3f
}
