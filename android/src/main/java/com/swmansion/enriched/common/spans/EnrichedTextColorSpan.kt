package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Per-selection foreground (text) colour.
 *
 * Neither platform shipped a text-colour command — the JS API never had one and
 * app toolbars called an optional `setTextColor` that resolved to undefined, so
 * the control silently did nothing everywhere. This is the Android half.
 *
 * Serializes to `<span style="color:#RRGGBB;">`, which is what the web editor
 * writes, so a coloured note round-trips.
 */
open class EnrichedTextColorSpan(
  private val color: Int,
) : CharacterStyle(),
  EnrichedInlineSpan {
  override fun updateDrawState(textPaint: TextPaint) {
    textPaint.color = color
  }

  fun getColor(): Int = color

  /** `#RRGGBB`, for HTML serialization. */
  fun getColorHex(): String = String.format("#%06X", 0xFFFFFF and color)
}
