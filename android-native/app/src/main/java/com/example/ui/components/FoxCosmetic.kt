package com.example.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.evolution.EvolutionVisualStyle
import com.example.game.model.CosmeticCatalog
import com.example.game.model.CosmeticItem
import com.example.game.model.CosmeticLoadout
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.HudInkDeep
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.WarmOrange
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

internal fun EvolutionVisualStyle.withFoxCosmetic(equipped: Boolean): EvolutionVisualStyle =
    if (equipped && starterId == "spark") copy(
        primaryColor = Color(0xFF697AE6),
        secondaryColor = Color(0xFFBDC8FF),
        accentColor = Color(0xFF78EDFF),
        auraColor = Color(0xFF8E9BFF)
    ) else this

internal fun EvolutionVisualStyle.withCosmeticSkinId(skinId: String?): EvolutionVisualStyle =
    when (skinId) {
        CosmeticCatalog.ID_FOX_SKIN -> withFoxCosmetic(true)
        CosmeticCatalog.ID_EMERALD_STUMP -> if (starterId == "stump") copy(
            primaryColor = Color(0xFF22B88C),
            secondaryColor = Color(0xFFB8FFE2),
            accentColor = Color(0xFF5CFFD0),
            auraColor = Color(0xFF39E6B2)
        ) else this
        CosmeticCatalog.ID_CRIMSON_CHAR -> if (starterId == "char") copy(
            primaryColor = Color(0xFFE63946),
            secondaryColor = Color(0xFFFFE599),
            accentColor = Color(0xFFFFD23A),
            auraColor = Color(0xFFFF6B35)
        ) else this
        else -> this
    }

internal fun EvolutionVisualStyle.withCosmeticLoadout(
    loadout: CosmeticLoadout,
    devnetFoxEquipped: Boolean
): EvolutionVisualStyle {
    val activeSkin = loadout.activeSkinIdFor(starterId, devnetFoxEquipped)
    return withCosmeticSkinId(activeSkin)
}

/**
 * Reusable zero-allocation Starlight Entrance aura & rising sparkles rendered on the
 * Main Menu Pedestal, Battle Canvas, and Roam Training Sandbox when equipped.
 */
fun DrawScope.drawStarlightEntranceAura(
    center: Offset,
    radius: Float,
    animTime: Float,
    subtle: Boolean = false
) {
    val alphaScale = if (subtle) 0.72f else 1f
    val pulse = 1f + 0.06f * sin(animTime * 4.2f)
    val ringR = radius * 1.48f * pulse

    // Soft celestial starlight halo
    drawCircle(
        color = GoldAccent.copy(alpha = 0.12f * alphaScale),
        radius = ringR * 1.18f,
        center = center
    )
    drawCircle(
        color = SkyBlue.copy(alpha = 0.34f * alphaScale),
        radius = ringR,
        center = center,
        style = Stroke(width = 2.2f)
    )

    // 5 orbiting luminous 4-point star sparkles
    val count = if (subtle) 4 else 6
    for (i in 0 until count) {
        val angle = animTime * 1.35f + i * (2f * PI.toFloat() / count)
        val bobY = sin(animTime * 3.1f + i * 1.7f) * (radius * 0.24f)
        val sx = center.x + cos(angle) * ringR
        val sy = center.y + sin(angle) * (ringR * 0.62f) + bobY
        val starR = (if (i % 2 == 0) 6.5f else 4.5f) * (0.78f + 0.28f * sin(animTime * 5.2f + i))
        val col = if (i % 2 == 0) GoldAccent else Color(0xFF9DF2FF)

        drawLine(
            color = col.copy(alpha = 0.92f * alphaScale),
            start = Offset(sx - starR, sy),
            end = Offset(sx + starR, sy),
            strokeWidth = 2.2f,
            cap = StrokeCap.Round
        )
        drawLine(
            color = col.copy(alpha = 0.92f * alphaScale),
            start = Offset(sx, sy - starR * 1.15f),
            end = Offset(sx, sy + starR * 1.15f),
            strokeWidth = 2.2f,
            cap = StrokeCap.Round
        )
        drawCircle(
            color = Color.White.copy(alpha = 0.90f * alphaScale),
            radius = starR * 0.32f,
            center = Offset(sx, sy)
        )
    }
}

@Composable
fun CosmeticFramePill(
    frame: CosmeticItem,
    modifier: Modifier = Modifier
) {
    val isGenesis = frame.id == CosmeticCatalog.ID_GENESIS_FRAME
    val borderBrush = if (isGenesis) {
        Brush.horizontalGradient(listOf(GoldAccent, WarmOrange, Color(0xFFFFF1A8), GoldAccent))
    } else {
        Brush.horizontalGradient(listOf(GrassGreen, Color(0xFF9BFFB8), GrassGreen))
    }
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(HudInkDark.copy(alpha = 0.88f))
            .border(1.6.dp, borderBrush, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 2.5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = frame.iconGlyph,
            fontSize = 10.sp,
            color = frame.primaryTint,
            fontWeight = FontWeight.Black
        )
        Text(
            text = frame.nameZh,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 9.5.sp,
                fontWeight = FontWeight.ExtraBold
            ),
            color = if (isGenesis) GoldAccent else Color(0xFFD8FFE2),
            maxLines = 1
        )
    }
}

/**
 * Miniature custom-drawn preview for non-skin cosmetics (Starlight Entrance & Avatar Frames)
 * used inside the fullscreen shop catalog cards and detail modal.
 */
@Composable
fun CosmeticArtEmblemPreview(
    item: CosmeticItem,
    animTime: Float,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                Brush.radialGradient(
                    listOf(
                        item.primaryTint.copy(alpha = 0.28f),
                        HudInkDeep
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        when (item.id) {
            CosmeticCatalog.ID_STARLIGHT_ENTRANCE -> {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val center = Offset(size.width * 0.5f, size.height * 0.52f)
                    val baseR = minOf(size.width, size.height) * 0.24f
                    drawStarlightEntranceAura(center, baseR, animTime, subtle = false)
                    drawCircle(
                        brush = Brush.radialGradient(
                            listOf(Color.White, GoldAccent, SkyBlue.copy(alpha = 0.2f)),
                            center = center,
                            radius = baseR * 0.85f
                        ),
                        radius = baseR * 0.65f,
                        center = center
                    )
                }
            }
            CosmeticCatalog.ID_FOREST_NAMEPLATE, CosmeticCatalog.ID_GENESIS_FRAME -> {
                val isGenesis = item.id == CosmeticCatalog.ID_GENESIS_FRAME
                val outerBrush = if (isGenesis) {
                    Brush.sweepGradient(listOf(GoldAccent, WarmOrange, Color(0xFFFFF4B8), GoldAccent))
                } else {
                    Brush.sweepGradient(listOf(GrassGreen, Color(0xFF9BFFB8), Color(0xFF28B57C), GrassGreen))
                }
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(HudInkDark)
                        .border(3.2.dp, outerBrush, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(item.primaryTint.copy(alpha = 0.22f))
                            .border(1.2.dp, item.accentTint.copy(alpha = 0.72f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = item.iconGlyph,
                            fontSize = 22.sp,
                            color = if (isGenesis) GoldAccent else Color(0xFFC8FFD4),
                            fontWeight = FontWeight.Black
                        )
                    }
                }
            }
            else -> {
                Text(item.iconGlyph, style = MaterialTheme.typography.headlineMedium, color = GoldAccent)
            }
        }
    }
}
