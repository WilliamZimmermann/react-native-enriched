package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedAiSuggestionSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputAiSuggestionSpan(
  private val aiId: String,
  private val status: String,
  private val model: String,
  @Suppress("UNUSED_PARAMETER") htmlStyle: HtmlStyle,
) : EnrichedAiSuggestionSpan(aiId, status, model),
  EnrichedInputSpan {
  // AI marks use fixed colours, so they don't re-derive from the html style.
  override val dependsOnHtmlStyle: Boolean = false

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputAiSuggestionSpan =
    EnrichedInputAiSuggestionSpan(aiId, status, model, htmlStyle)
}
