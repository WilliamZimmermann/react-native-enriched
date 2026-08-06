package com.swmansion.enriched.common.spans

import android.content.res.Resources
import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Renders an `<hr>` as a full-width divider line on its own line. Implemented as
 * a [ReplacementSpan] over a single object-replacement character (the same
 * placeholder images use).
 *
 * The glyph itself reserves only a couple of px of advance — the line is painted
 * across the full canvas width in [draw] so it spans the editor regardless of
 * the container width (no horizontal-scroll side effects). The colour is derived
 * from the current text colour at reduced alpha, so it adapts to light/dark
 * themes without extra configuration.
 */
open class EnrichedHorizontalRuleSpan :
  ReplacementSpan(),
  EnrichedInlineSpan {
  private val density: Float = Resources.getSystem().displayMetrics.density
  private val thicknessPx: Int = maxOf(1, (1f * density).toInt())
  private val verticalPaddingPx: Int = (10f * density).toInt()

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    if (fm != null) {
      val half = thicknessPx / 2 + verticalPaddingPx
      fm.ascent = -half
      fm.top = -half
      fm.descent = half
      fm.bottom = half
    }
    // A small non-zero advance keeps Android invoking draw(); the visible line
    // is painted full-width there.
    return maxOf(1, (2f * density).toInt())
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    val lineColor = (paint.color and 0x00FFFFFF) or (0x4D shl 24) // ~30% alpha
    val prevColor = paint.color
    val prevStyle = paint.style
    paint.color = lineColor
    paint.style = Paint.Style.FILL

    val centerY = (top + bottom) / 2f
    val halfThick = thicknessPx / 2f
    // `x` is the line's left inset (the char sits at line start); mirror it on
    // the right for a symmetric, padded rule.
    val left = x
    val right = canvas.width.toFloat() - x
    canvas.drawRect(left, centerY - halfThick, maxOf(left, right), centerY + halfThick, paint)

    paint.color = prevColor
    paint.style = prevStyle
  }
}
