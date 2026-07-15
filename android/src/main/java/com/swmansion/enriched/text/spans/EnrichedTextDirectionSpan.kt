package com.swmansion.enriched.text.spans

import com.swmansion.enriched.common.spans.EnrichedDirectionSpan
import com.swmansion.enriched.text.EnrichedTextStyle
import com.swmansion.enriched.text.spans.interfaces.EnrichedTextSpan

class EnrichedTextDirectionSpan(
  cssValue: String,
) : EnrichedDirectionSpan(cssValue),
  EnrichedTextSpan {
  override val dependsOnHtmlStyle = false

  override fun rebuildWithStyle(style: EnrichedTextStyle) = this
}
