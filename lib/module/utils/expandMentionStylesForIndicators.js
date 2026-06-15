"use strict";

import { DEFAULT_HTML_STYLE } from "./defaultHtmlStyle.js";
import { isMentionStyleRecord } from "./isMentionStyleRecord.js";
export function expandMentionStylesForIndicators(mention, indicators) {
  const out = {};
  for (const indicator of indicators) {
    out[indicator] = {
      ...DEFAULT_HTML_STYLE.mention,
      ...(isMentionStyleRecord(mention) ? mention[indicator] ?? mention.default ?? {} : mention)
    };
  }
  return out;
}
//# sourceMappingURL=expandMentionStylesForIndicators.js.map