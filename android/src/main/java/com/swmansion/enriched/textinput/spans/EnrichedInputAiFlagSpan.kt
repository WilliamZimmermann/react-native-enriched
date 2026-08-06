package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedAiFlagSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputAiFlagSpan(
  private val aiId: String,
  private val status: String,
  private val explanation: String,
  @Suppress("UNUSED_PARAMETER") htmlStyle: HtmlStyle,
) : EnrichedAiFlagSpan(aiId, status, explanation),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = false

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputAiFlagSpan =
    EnrichedInputAiFlagSpan(aiId, status, explanation, htmlStyle)
}
