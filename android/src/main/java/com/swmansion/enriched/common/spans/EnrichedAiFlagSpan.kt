package com.swmansion.enriched.common.spans

import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * AI correction flag over the student's own text. Carries aiId/status/
 * explanation and round-trips as `<span data-ai-flag=...>`. Pending flags render
 * as a red tint + underline; accepted ("Keep") clears the visual (the student
 * reviewed and kept their text); rejecting removes the span entirely.
 */
open class EnrichedAiFlagSpan(
  private val aiId: String,
  private val status: String,
  private val explanation: String,
) : ClickableSpan(),
  EnrichedInlineSpan {
  override fun onClick(view: View) {
    // no-op inside the input
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)
    if (status != "accepted") {
      textPaint.bgColor = AI_FLAG_TINT
      textPaint.isUnderlineText = true
    }
  }

  fun getAiId(): String = aiId

  fun getStatus(): String = status

  fun getExplanation(): String = explanation

  companion object {
    // ~20% alpha red tint (ARGB).
    const val AI_FLAG_TINT = 0x33E11D48
  }
}
