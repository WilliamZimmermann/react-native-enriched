package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/** Fraction of the current size a sub/superscript is drawn at. */
const val ENRICHED_SCRIPT_SCALE = 0.7f

/** How far the baseline moves, as a fraction of the current size. */
const val ENRICHED_SCRIPT_SHIFT = 0.25f

/**
 * Subscript — `H<sub>2</sub>O`.
 *
 * Android ships `SubscriptSpan`, but it only shifts the baseline and leaves the
 * glyphs full size, which reads as a misaligned character rather than a
 * subscript. Shrinking with the shift is what every editor does, and it matches
 * what the web note shows.
 *
 * Serializes to `<sub>`.
 */
class EnrichedSubscriptSpan :
  MetricAffectingSpan(),
  EnrichedInlineSpan {
  override fun updateDrawState(textPaint: TextPaint) = apply(textPaint)

  override fun updateMeasureState(textPaint: TextPaint) = apply(textPaint)

  private fun apply(textPaint: TextPaint) {
    textPaint.baselineShift -= (textPaint.textSize * ENRICHED_SCRIPT_SHIFT).toInt()
    textPaint.textSize = textPaint.textSize * ENRICHED_SCRIPT_SCALE
  }
}
