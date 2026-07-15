package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedDirectionSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputDirectionSpan(
  cssValue: String,
) : EnrichedDirectionSpan(cssValue),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = false

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputDirectionSpan = this
}
