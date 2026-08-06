package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedHorizontalRuleSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

/** Editable-surface variant of the horizontal rule span. The rule has no
 *  configurable payload, so it never rebuilds on html-style changes. */
class EnrichedInputHorizontalRuleSpan :
  EnrichedHorizontalRuleSpan(),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = false

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputHorizontalRuleSpan = this
}
