package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Per-selection highlight (text background colour).
 *
 * iOS has had this since the feature landed; Android only had a no-op stub, so
 * the toolbar's colour swatches did nothing there. The HTML contract is the one
 * iOS already emits and parses — `<mark style="background-color:#RRGGBB;">`,
 * which is also what TipTap's highlight extension writes, so a note round-trips
 * between phone, tablet and web unchanged.
 *
 * Carries its own colour rather than reading the theme: a highlight is the
 * user's choice and must survive a light/dark switch.
 */
open class EnrichedHighlightSpan(
  private val color: Int,
) : CharacterStyle(),
  EnrichedInlineSpan {
  override fun updateDrawState(textPaint: TextPaint) {
    textPaint.bgColor = color
  }

  fun getColor(): Int = color

  /** `#RRGGBB`, for HTML serialization. */
  fun getColorHex(): String = String.format("#%06X", 0xFFFFFF and color)
}
