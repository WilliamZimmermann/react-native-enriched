package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Superscript — `x<sup>2</sup>`.
 *
 * Same shape as [EnrichedSubscriptSpan], shifting the baseline the other way.
 * Serializes to `<sup>`.
 */
class EnrichedSuperscriptSpan :
  MetricAffectingSpan(),
  EnrichedInlineSpan {
  override fun updateDrawState(textPaint: TextPaint) = apply(textPaint)

  override fun updateMeasureState(textPaint: TextPaint) = apply(textPaint)

  private fun apply(textPaint: TextPaint) {
    textPaint.baselineShift += (textPaint.textSize * ENRICHED_SCRIPT_SHIFT).toInt()
    textPaint.textSize = textPaint.textSize * ENRICHED_SCRIPT_SCALE
  }
}
