package com.example.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val SpriteBonkColorScheme = lightColorScheme(
    primary = GrassGreenDeep,
    onPrimary = Color.White,
    primaryContainer = GrassGreen,
    onPrimaryContainer = EspressoDark,
    secondary = WarmOrange,
    onSecondary = Color.White,
    secondaryContainer = CreamSurfaceWarm,
    onSecondaryContainer = EspressoInk,
    tertiary = SkyBlue,
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFDDF2FF),
    onTertiaryContainer = EspressoDark,
    background = CreamSurface,
    onBackground = EspressoInk,
    surface = CreamSurface,
    onSurface = EspressoInk,
    surfaceVariant = CreamSurfaceWarm,
    onSurfaceVariant = MutedInk,
    outline = SandstoneRim,
    error = CrimsonRed,
    onError = Color.White
)

private val SpriteBonkShapes = Shapes(
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(30.dp)
)

@Composable
fun SpriteBonkTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = SpriteBonkColorScheme,
        typography = SpriteBonkTypography,
        shapes = SpriteBonkShapes,
        content = content
    )
}
