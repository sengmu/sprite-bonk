package com.example.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.R
import com.example.game.engine.ActiveMoveSlot
import com.example.game.model.ElementType
import com.example.game.model.Rarity
import com.example.ui.theme.CreamSurface
import com.example.ui.theme.CreamSurfaceWarm
import com.example.ui.theme.DarkButtonRim
import com.example.ui.theme.EspressoDark
import com.example.ui.theme.EspressoInk
import com.example.ui.theme.GoldAccent
import com.example.ui.theme.GrassGreen
import com.example.ui.theme.GrassGreenDeep
import com.example.ui.theme.HudInkDark
import com.example.ui.theme.SandstoneRim
import com.example.ui.theme.SilverLockRim
import com.example.ui.theme.SkyBlue
import com.example.ui.theme.SkyBlueDeep
import com.example.ui.theme.WarmOrange
import com.example.ui.theme.WarmOrangeDeep
import com.example.ui.theme.WoodenChestBrown
import com.example.ui.theme.WoodenChestGold
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * In-memory LRU cache of downsampled ImageBitmaps decoded strictly on Dispatchers.IO.
 * Eliminates synchronous main-thread JPEG decoding and prevents SurfaceSyncGroup 1000ms timeouts.
 */
private object AsyncDrawableCache {
    private val cache = object : LruCache<String, ImageBitmap>(18) {}

    fun get(key: String): ImageBitmap? = synchronized(cache) { cache.get(key) }

    fun put(key: String, bitmap: ImageBitmap) = synchronized(cache) { cache.put(key, bitmap) }

    fun decodeDownsampled(
        context: Context,
        @DrawableRes resId: Int,
        maxDimPx: Int,
        preferRgb565: Boolean
    ): ImageBitmap? = runCatching {
        val res = context.resources
        val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeResource(res, resId, boundsOpts)
        var sampleSize = 1
        val maxOrig = maxOf(boundsOpts.outWidth, boundsOpts.outHeight)
        if (maxOrig > 0 && maxDimPx > 0) {
            while (maxOrig / (sampleSize * 2) >= maxDimPx) {
                sampleSize *= 2
            }
        }
        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = if (preferRgb565) Bitmap.Config.RGB_565 else Bitmap.Config.ARGB_8888
            inScaled = false
        }
        BitmapFactory.decodeResource(res, resId, decodeOpts)?.asImageBitmap()
    }.getOrNull()
}

@Composable
fun rememberAsyncDrawableBitmap(
    @DrawableRes resId: Int,
    maxDimPx: Int = 960,
    preferRgb565: Boolean = true
): ImageBitmap? {
    val context = LocalContext.current.applicationContext
    val cacheKey = "${resId}_${maxDimPx}_${preferRgb565}"
    val cached = remember(cacheKey) { AsyncDrawableCache.get(cacheKey) }
    val state by produceState(initialValue = cached, key1 = cacheKey) {
        if (value == null) {
            val decoded = withContext(Dispatchers.IO) {
                AsyncDrawableCache.decodeDownsampled(context, resId, maxDimPx, preferRgb565)
            }
            if (decoded != null) {
                AsyncDrawableCache.put(cacheKey, decoded)
                value = decoded
            }
        }
    }
    return state
}

@Composable
fun AsyncDrawableImage(
    @DrawableRes resId: Int,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    maxDimPx: Int = 960,
    preferRgb565: Boolean = true,
    contentScale: ContentScale = ContentScale.Crop,
    fallbackColor: Color = HudInkDark
) {
    val bitmap = rememberAsyncDrawableBitmap(
        resId = resId,
        maxDimPx = maxDimPx,
        preferRgb565 = preferRgb565
    )
    if (bitmap != null) {
        Image(
            bitmap = bitmap,
            contentDescription = contentDescription,
            contentScale = contentScale,
            modifier = modifier
        )
    } else {
        Box(modifier = modifier.background(fallbackColor))
    }
}

@Composable
fun CreamPanel(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 22.dp,
    borderColor: Color = SandstoneRim,
    borderWidth: Dp = 2.5.dp,
    containerColor: Color = CreamSurface,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier.shadow(10.dp, RoundedCornerShape(cornerRadius)),
        shape = RoundedCornerShape(cornerRadius),
        color = containerColor,
        border = BorderStroke(borderWidth, borderColor)
    ) {
        Box(
            modifier = Modifier
                .background(
                    Brush.verticalGradient(
                        listOf(Color.White.copy(alpha = 0.36f), Color.Transparent, CreamSurfaceWarm.copy(alpha = 0.28f))
                    )
                )
                .padding(contentPadding)
        ) {
            content()
        }
    }
}

/**
 * Maps each of the 4 Sprite Bonk biomes to its dedicated stylized scenic backdrop artwork.
 */
@DrawableRes
fun biomeBackdropRes(biomeId: String): Int = when (biomeId) {
    "graveyard" -> R.drawable.img_graveyard_backdrop
    "desert" -> R.drawable.img_desert_backdrop
    "volcano" -> R.drawable.img_volcano_backdrop
    else -> R.drawable.img_meadow_backdrop
}

/**
 * Cohesive dark-glass surface panel matching the flagship Main Lobby & Modals aesthetic.
 */
@Composable
fun DarkGlassPanel(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 20.dp,
    borderColor: Color = Color.White.copy(alpha = 0.16f),
    borderWidth: Dp = 1.4.dp,
    containerColor: Color = HudInkDark.copy(alpha = 0.84f),
    contentPadding: PaddingValues = PaddingValues(14.dp),
    content: @Composable () -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    Box(
        modifier = modifier
            .shadow(10.dp, shape)
            .clip(shape)
            .background(containerColor)
            .border(borderWidth, borderColor, shape)
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.06f),
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.16f)
                    )
                )
            )
            .padding(contentPadding)
    ) {
        content()
    }
}

/**
 * Atmospheric scenic background for secondary screens (Lab, Dex, Profile) built directly on
 * the active biome's bespoke painting with a rich tinted glass veil for effortless legibility.
 */
@Composable
fun ScreenScenicBackdrop(
    biomeId: String,
    accentTint: Color,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.fillMaxSize()) {
        AsyncDrawableImage(
            resId = biomeBackdropRes(biomeId),
            contentDescription = null,
            maxDimPx = 960,
            preferRgb565 = true,
            contentScale = ContentScale.Crop,
            fallbackColor = HudInkDark,
            modifier = Modifier.fillMaxSize()
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            HudInkDark.copy(alpha = 0.72f),
                            accentTint.copy(alpha = 0.42f),
                            HudInkDark.copy(alpha = 0.88f)
                        )
                    )
                )
        )
    }
}

enum class ChunkyButtonTone { GREEN, ORANGE, BLUE, CREAM, RED }

/**
 * Tactile 3D extruded arcade button with spring press depression, specular top highlight, and optional shimmer sweep.
 */
@Composable
fun ChunkyButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tone: ChunkyButtonTone = ChunkyButtonTone.GREEN,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    shimmer: Boolean = false,
    height: Dp = 52.dp,
    testTag: String = "chunky_button"
) {
    val (topColor, bottomColor, lipColor, rimColor, textColor) = when (tone) {
        ChunkyButtonTone.GREEN -> QuintColor(GrassGreen, GrassGreenDeep, Color(0xFF477A19), DarkButtonRim, Color.White)
        ChunkyButtonTone.ORANGE -> QuintColor(WarmOrange, WarmOrangeDeep, Color(0xFF9E4E07), DarkButtonRim, Color.White)
        ChunkyButtonTone.BLUE -> QuintColor(SkyBlue, SkyBlueDeep, Color(0xFF1F5D85), DarkButtonRim, Color.White)
        ChunkyButtonTone.CREAM -> QuintColor(CreamSurface, CreamSurfaceWarm, Color(0xFFC4AE89), SandstoneRim, EspressoInk)
        ChunkyButtonTone.RED -> QuintColor(Color(0xFFFF6262), Color(0xFFD62B3A), Color(0xFF961A25), DarkButtonRim, Color.White)
    }

    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val pressOffset by animateDpAsState(
        targetValue = if (pressed && enabled) 3.dp else 0.dp,
        animationSpec = spring(stiffness = 700f),
        label = "btn_press"
    )
    val scale by animateFloatAsState(
        targetValue = if (pressed && enabled) 0.97f else 1f,
        animationSpec = spring(stiffness = 700f),
        label = "btn_scale"
    )

    val shape = RoundedCornerShape(18.dp)
    Box(
        modifier = modifier
            .testTag(testTag)
            .minimumInteractiveComponentSize()
            .scale(scale)
            .height(height + 4.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                onClick = onClick
            )
    ) {
        // 3D bottom extruded lip
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(height)
                .clip(shape)
                .background(if (enabled) lipColor else Color(0xFF7B746B))
                .border(2.5.dp, if (enabled) rimColor else Color(0xFF6B655D), shape)
        )

        // Main glossy button face
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = pressOffset)
                .fillMaxWidth()
                .height(height)
                .clip(shape)
                .background(
                    Brush.verticalGradient(
                        colors = if (enabled) listOf(topColor, bottomColor)
                        else listOf(Color(0xFFB5ADA2), Color(0xFF948C81))
                    )
                )
                .border(2.5.dp, if (enabled) rimColor else Color(0xFF7B746B), shape)
                .padding(horizontal = 16.dp),
            contentAlignment = Alignment.Center
        ) {
            // Glossy top specular pill
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 3.dp, start = 10.dp, end = 10.dp)
                    .height(7.dp)
                    .fillMaxWidth(0.9f)
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = if (enabled) 0.34f else 0.1f))
            )

            // Optional animated shimmer sweep for hero START CTA
            if (shimmer && enabled) {
                val transition = rememberInfiniteTransition(label = "cta_shimmer")
                val sweep by transition.animateFloat(
                    initialValue = -0.35f,
                    targetValue = 1.35f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(2200, easing = LinearEasing),
                        repeatMode = RepeatMode.Restart
                    ),
                    label = "sweep"
                )
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val x = size.width * sweep
                    drawRect(
                        brush = Brush.horizontalGradient(
                            colors = listOf(Color.Transparent, Color.White.copy(alpha = 0.28f), Color.Transparent),
                            startX = x - 70f,
                            endX = x + 70f
                        ),
                        size = size
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                if (icon != null) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = textColor,
                        modifier = Modifier.size(21.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                }
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge.copy(fontSize = 15.sp),
                    color = textColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

private data class QuintColor(
    val top: Color,
    val bottom: Color,
    val lip: Color,
    val rim: Color,
    val text: Color
)

@Composable
fun ResourcePill(
    valueText: String,
    icon: ImageVector,
    iconTint: Color,
    modifier: Modifier = Modifier,
    darkTheme: Boolean = false
) {
    val bg = if (darkTheme) HudInkDark.copy(alpha = 0.88f) else CreamSurface.copy(alpha = 0.96f)
    val rim = if (darkTheme) DarkButtonRim else SandstoneRim
    val textColor = if (darkTheme) Color.White else EspressoInk
    Row(
        modifier = modifier
            .shadow(3.dp, RoundedCornerShape(50))
            .clip(RoundedCornerShape(50))
            .background(bg)
            .border(2.dp, rim, RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(16.dp)
        )
        Spacer(Modifier.width(5.dp))
        Text(
            text = valueText,
            style = MaterialTheme.typography.labelLarge.copy(fontSize = 13.sp),
            color = textColor,
            maxLines = 1
        )
    }
}

@Composable
fun WoodenChestIcon(modifier: Modifier = Modifier.size(18.dp)) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        drawRoundRect(WoodenChestBrown, Offset(w * 0.08f, h * 0.25f), Size(w * 0.84f, h * 0.65f), CornerRadius(w * 0.14f, w * 0.14f))
        drawRoundRect(Color(0xFFCC8343), Offset(w * 0.08f, h * 0.18f), Size(w * 0.84f, h * 0.32f), CornerRadius(w * 0.14f, w * 0.14f))
        drawLine(EspressoDark, Offset(w * 0.08f, h * 0.50f), Offset(w * 0.92f, h * 0.50f), h * 0.09f)
        drawRect(WoodenChestGold, Offset(w * 0.22f, h * 0.20f), Size(w * 0.10f, h * 0.68f))
        drawRect(WoodenChestGold, Offset(w * 0.68f, h * 0.20f), Size(w * 0.10f, h * 0.68f))
        drawRoundRect(GoldAccent, Offset(w * 0.41f, h * 0.40f), Size(w * 0.18f, h * 0.22f), CornerRadius(w * 0.04f, w * 0.04f))
        drawRoundRect(EspressoDark, Offset(w * 0.08f, h * 0.18f), Size(w * 0.84f, h * 0.72f), CornerRadius(w * 0.14f, w * 0.14f), style = Stroke(width = w * 0.07f))
    }
}

@Composable
fun StarterPortraitAvatar(
    @DrawableRes portraitRes: Int,
    ringColor: Color,
    size: Dp = 56.dp,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size)
            .shadow(6.dp, CircleShape)
            .clip(CircleShape)
            .background(HudInkDark)
            .border(3.2.dp, ringColor, CircleShape)
    ) {
        AsyncDrawableImage(
            resId = portraitRes,
            contentDescription = "精灵头像",
            maxDimPx = 220,
            preferRgb565 = true,
            contentScale = ContentScale.Crop,
            fallbackColor = ringColor.copy(alpha = 0.35f),
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
fun RarityChip(rarity: Rarity, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(rarity.color)
            .padding(horizontal = 9.dp, vertical = 2.dp)
    ) {
        Text(
            text = rarity.zhName,
            style = MaterialTheme.typography.labelSmall,
            color = if (rarity == Rarity.LEGENDARY) EspressoDark else Color.White
        )
    }
}

/**
 * U1 Handover-aligned Skill Slot:
 * - Unlocked: element icon + label + live vertical cooldown curtain + level badge
 * - Locked: thick silver rim (#C2C9D6) + cream lock icon (#FFF7E5)
 */
@Composable
fun SkillSlotTile(
    slot: ActiveMoveSlot?,
    slotSize: Dp = 52.dp,
    selected: Boolean = false,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(14.dp)
    val isAwakened = slot?.awakened == true
    val rimColor = when {
        selected -> CreamSurface
        slot == null -> SilverLockRim
        isAwakened -> GoldAccent
        else -> slot.element.color
    }
    val rimWidth = when {
        selected -> 3.dp
        slot == null || isAwakened -> 2.8.dp
        else -> 2.2.dp
    }
    val interactiveModifier = if (slot != null && onClick != null) {
        modifier.clickable(onClick = onClick)
    } else {
        modifier
    }
    Box(
        modifier = interactiveModifier
            .size(slotSize)
            .shadow(if (selected) 8.dp else 4.dp, shape)
            .clip(shape)
            .background(
                if (slot == null) HudInkDark.copy(alpha = 0.72f)
                else HudInkDark.copy(alpha = if (selected) 0.98f else 0.92f)
            )
            .border(rimWidth, rimColor, shape),
        contentAlignment = Alignment.Center
    ) {
        if (slot == null) {
            Icon(
                imageVector = Icons.Rounded.Lock,
                contentDescription = "未解锁招式槽",
                tint = CreamSurface.copy(alpha = 0.85f),
                modifier = Modifier.size(20.dp)
            )
        } else {
            val cdFrac = (slot.cooldownRemaining / slot.cooldownTotal.coerceAtLeast(0.1f)).coerceIn(0f, 1f)
            if (cdFrac > 0.02f) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .fillMaxHeight(cdFrac)
                        .background(slot.element.color.copy(alpha = 0.34f))
                )
            }
            // Subtle top specular strip for tactile depth
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .height(4.dp)
                    .background(Color.White.copy(alpha = if (selected) 0.24f else 0.12f))
            )
            val elemIcon = when (slot.element) {
                ElementType.GRASS -> Icons.Rounded.Eco
                ElementType.FIRE -> Icons.Rounded.LocalFireDepartment
                ElementType.WATER -> Icons.Rounded.WaterDrop
                ElementType.STAR -> Icons.Rounded.AutoAwesome
                else -> Icons.Rounded.Bolt
            }
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceEvenly,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 2.dp, vertical = 4.dp)
            ) {
                Icon(
                    imageVector = elemIcon,
                    contentDescription = slot.nameZh,
                    tint = if (isAwakened) GoldAccent else slot.element.color,
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    text = slot.nameZh.take(2),
                    style = MaterialTheme.typography.labelMedium.copy(
                        fontSize = 10.sp,
                        lineHeight = 11.sp
                    ),
                    color = Color.White,
                    maxLines = 1
                )
                Text(
                    text = if (isAwakened) "★${slot.level}" else "Lv${slot.level}",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        lineHeight = 10.sp
                    ),
                    color = if (isAwakened) GoldAccent else CreamSurface.copy(alpha = 0.90f),
                    maxLines = 1
                )
            }
        }
    }
}

/**
 * U1 Handover ⑤: Dark-rimmed Segmented Ult Button with breathing golden ready halo.
 */
@Composable
fun SegmentedUltButton(
    charge: Float,
    ultNameZh: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 80.dp
) {
    val isReady = charge >= 0.999f
    val pulseTransition = rememberInfiniteTransition(label = "ult_ready_pulse")
    val readyScale by pulseTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = if (isReady) 1.07f else 1.0f,
        animationSpec = infiniteRepeatable(tween(620), RepeatMode.Reverse),
        label = "ult_scale"
    )

    Box(
        modifier = modifier
            .testTag("ult_action_button")
            .minimumInteractiveComponentSize()
            .scale(readyScale)
            .size(size)
            .clip(CircleShape)
            .clickable(enabled = isReady, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            if (isReady) {
                drawCircle(
                    Brush.radialGradient(listOf(GoldAccent.copy(alpha = 0.55f), Color.Transparent)),
                    radius = this.size.minDimension * 0.52f
                )
            }
            val strokeW = 6.dp.toPx()
            val inset = strokeW / 2f + 3.dp.toPx()
            val arcSize = Size(this.size.width - inset * 2, this.size.height - inset * 2)
            val segments = 8
            val gapDeg = 7f
            val segDeg = (360f / segments) - gapDeg
            val filledSegments = (charge * segments).toInt()
            val partial = (charge * segments) - filledSegments

            for (i in 0 until segments) {
                val startAngle = -90f + i * (segDeg + gapDeg)
                drawArc(
                    color = DarkButtonRim.copy(alpha = 0.82f),
                    startAngle = startAngle,
                    sweepAngle = segDeg,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = strokeW, cap = StrokeCap.Round)
                )
                val segFill = when {
                    i < filledSegments -> 1f
                    i == filledSegments -> partial
                    else -> 0f
                }
                if (segFill > 0.01f) {
                    drawArc(
                        color = if (isReady) GoldAccent else SkyBlue,
                        startAngle = startAngle,
                        sweepAngle = segDeg * segFill,
                        useCenter = false,
                        topLeft = Offset(inset, inset),
                        size = arcSize,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .size(size - 20.dp)
                .clip(CircleShape)
                .background(
                    Brush.verticalGradient(
                        if (isReady) listOf(Color(0xFFFFE77A), GoldAccent, WarmOrange)
                        else listOf(SkyBlue.copy(alpha = 0.78f), SkyBlueDeep.copy(alpha = 0.90f))
                    )
                )
                .border(3.dp, DarkButtonRim, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = if (isReady) Icons.Rounded.AutoAwesome else Icons.Rounded.Bolt,
                    contentDescription = "必杀技 $ultNameZh",
                    tint = if (isReady) EspressoDark else Color.White,
                    modifier = Modifier.size(22.dp)
                )
                Text(
                    text = if (isReady) "必杀!" else "${(charge * 100).toInt()}%",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 10.sp
                    ),
                    color = if (isReady) EspressoDark else Color.White
                )
            }
        }
    }
}
