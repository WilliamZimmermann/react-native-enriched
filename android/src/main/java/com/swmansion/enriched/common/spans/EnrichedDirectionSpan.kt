package com.swmansion.enriched.common.spans

import android.text.style.ParagraphStyle

/**
 * Paragraph-scoped marker span that records an explicit writing direction
 * ("ltr" or "rtl") for a block.
 *
 * Unlike [EnrichedAlignmentSpan], which maps to a framework AlignmentSpan.Standard,
 * Android has no first-class span that overrides a paragraph's base bidi direction.
 * This span therefore only carries the direction so it can be reported in state and
 * round-tripped through HTML (dir="..."); the visible base direction is applied at
 * the field level in EnrichedTextInputView.setTextDirection.
 */
open class EnrichedDirectionSpan(
  val cssValue: String,
) : ParagraphStyle
