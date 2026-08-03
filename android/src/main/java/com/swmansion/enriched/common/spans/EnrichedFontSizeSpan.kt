package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.pixelFromSpOrDp
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Per-selection font size, in dp.
 *
 * The Android half of a command iOS already had: the view manager declared
 * addFontSize/removeFontSize (codegen requires every platform to declare them)
 * but left the bodies empty, so A−/A+ resized the whole editor through the
 * style prop and did nothing to a selection.
 *
 * Serializes to `<span style="font-size:NNpx;">`, the shape TipTap's FontSize
 * mark and the iOS side both use, so a sized note round-trips between web,
 * phone and tablet.
 */
class EnrichedFontSizeSpan(
  private val size: Float,
  private val allowFontScaling: Boolean,
) : MetricAffectingSpan(),
  EnrichedInlineSpan {
  override fun updateDrawState(textPaint: TextPaint) {
    apply(textPaint)
  }

  override fun updateMeasureState(textPaint: TextPaint) {
    apply(textPaint)
  }

  private fun apply(textPaint: TextPaint) {
    textPaint.textSize = pixelFromSpOrDp(size, allowFontScaling)
  }

  fun getSize(): Float = size

  /** Whole number when it is one, so the HTML reads `18px`, not `18.0px`. */
  fun getSizeCss(): String {
    val rounded = Math.round(size)

    return if (Math.abs(size - rounded) < 0.01f) rounded.toString() else size.toString()
  }
}
