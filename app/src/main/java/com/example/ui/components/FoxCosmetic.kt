package com.example.ui.components

import androidx.compose.ui.graphics.Color
import com.example.game.evolution.EvolutionVisualStyle

internal fun EvolutionVisualStyle.withFoxCosmetic(equipped: Boolean): EvolutionVisualStyle =
    if (equipped && starterId == "spark") copy(
        primaryColor = Color(0xFF697AE6),
        secondaryColor = Color(0xFFBDC8FF),
        accentColor = Color(0xFF78EDFF),
        auraColor = Color(0xFF8E9BFF)
    ) else this
