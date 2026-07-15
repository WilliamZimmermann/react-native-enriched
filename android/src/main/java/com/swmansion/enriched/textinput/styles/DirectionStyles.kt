package com.swmansion.enriched.textinput.styles

import android.text.Spannable
import android.text.SpannableStringBuilder
import com.swmansion.enriched.textinput.EnrichedTextInputView
import com.swmansion.enriched.textinput.spans.EnrichedInputDirectionSpan
import com.swmansion.enriched.textinput.utils.getParagraphBounds
import com.swmansion.enriched.textinput.utils.getSafeSpanBoundaries

/**
 * Manages per-paragraph writing direction ("ltr" / "rtl" / "auto") as marker spans,
 * mirroring [AlignmentStyles]' per-paragraph span model.
 *
 * IMPORTANT LIMITATION: Android has no framework span that overrides a paragraph's
 * base bidi direction (alignment maps to AlignmentSpan.Standard; there is no
 * direction equivalent). These spans therefore only *carry* the direction so it can
 * be reported in the onChangeState event and serialized to HTML (dir="..."). The
 * visible base direction is applied at the field level by
 * [EnrichedTextInputView.setTextDirection], which affects the whole field — so an
 * explicit ltr/rtl override is not rendered per paragraph. "auto" (first-strong) is
 * the platform default and resolves per paragraph naturally.
 *
 * Because these are pure data markers, the newline-inheritance / auto-stretch
 * machinery that [AlignmentStyles] runs from the text watcher is intentionally not
 * replicated here: a direction span applies to the selected paragraph(s) at the
 * moment the command runs and does not auto-propagate to newly split paragraphs.
 */
class DirectionStyles(
  private val view: EnrichedTextInputView,
) {
  private fun setDirectionSpan(
    spannable: Spannable,
    cssValue: String,
    start: Int,
    end: Int,
    flags: Int = Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
  ) {
    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    spannable.setSpan(
      EnrichedInputDirectionSpan(cssValue),
      safeStart,
      safeEnd,
      flags,
    )
  }

  fun setDirection(direction: String) {
    val spannable = view.text as? SpannableStringBuilder ?: return
    val selection = view.selection ?: return

    val (start, end) = selection.getParagraphSelection()

    var cursor = start
    while (cursor <= end) {
      val (paraStart, paraEnd) = spannable.getParagraphBounds(cursor)

      cleanUpExistingSpans(spannable, paraStart, paraEnd)

      // "auto" is the platform default and stores no span (mirrors alignment).
      if (direction != "auto" && paraStart < paraEnd) {
        setDirectionSpan(spannable, direction, paraStart, paraEnd)
      }

      if (paraEnd >= end || paraEnd == spannable.length) break
      cursor = paraEnd + 1
    }
  }

  fun getCurrentDirection(): String {
    val spannable = view.text as? Spannable ?: return "auto"
    val selection = view.selection ?: return "auto"

    val cursorPos = selection.start.coerceAtLeast(0).coerceAtMost(spannable.length)
    val (paraStart, paraEnd) = spannable.getParagraphBounds(cursorPos)
    val spans = spannable.getSpans(paraStart, paraEnd, EnrichedInputDirectionSpan::class.java)

    return spans.firstOrNull()?.cssValue ?: "auto"
  }

  /**
   * Removes all direction spans that overlap [paraStart, paraEnd], trimming any span
   * that extends beyond the paragraph rather than deleting it entirely.
   */
  private fun cleanUpExistingSpans(
    spannable: SpannableStringBuilder,
    paraStart: Int,
    paraEnd: Int,
  ) {
    val existing = spannable.getSpans(paraStart, paraEnd, EnrichedInputDirectionSpan::class.java)
    for (span in existing) {
      val sStart = spannable.getSpanStart(span)
      val sEnd = spannable.getSpanEnd(span)
      spannable.removeSpan(span)

      // This ensures top fragments always end before the '\n' character, not at the paraStart
      if (sStart < paraStart) {
        val topEnd = if (paraStart > 0 && spannable[paraStart - 1] == '\n') paraStart - 1 else paraStart
        if (sStart < topEnd) {
          setDirectionSpan(spannable, span.cssValue, sStart, topEnd)
        }
      }
      // This ensures bottom fragments always begin at the first character of the next paragraph, not on the '\n'  character
      if (sEnd > paraEnd) {
        val bottomStart = if (paraEnd < spannable.length && spannable[paraEnd] == '\n') paraEnd + 1 else paraEnd
        if (bottomStart < sEnd) {
          setDirectionSpan(spannable, span.cssValue, bottomStart, sEnd)
        }
      }
    }
  }
}
