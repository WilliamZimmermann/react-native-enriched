package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * AI gap-fill suggestion mark. Carries its payload (aiId/status/model) and
 * round-trips as `<span data-ai-suggestion=...>`. Pending suggestions render as
 * a green tint + underline; accepted (not yet claimed) as a blue highlight;
 * claiming removes the span entirely, so no visual remains.
 *
 * ClickableSpan (like Mention/Link) so the range styles as a distinct element;
 * the input editor doesn't tap-dispatch here — it emits onAiMarkTap from the
 * selection change instead.
 */
open class EnrichedAiSuggestionSpan(
  private val aiId: String,
  private val status: String,
  private val model: String,
) : ClickableSpan(),
  EnrichedInlineSpan {
  override fun onClick(view: View) {
    // no-op inside the input
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)
    if (status == "accepted") {
      textPaint.bgColor = AI_ACCEPTED_TINT
    } else {
      textPaint.bgColor = AI_SUGGESTION_TINT
      textPaint.isUnderlineText = true
    }
  }

  fun getAiId(): String = aiId

  fun getStatus(): String = status

  fun getModel(): String = model

  companion object {
    // ~20% alpha tints (ARGB). Green while pending, blue once accepted.
    const val AI_SUGGESTION_TINT = 0x331E9A55
    const val AI_ACCEPTED_TINT = 0x333B82F6
  }
}
