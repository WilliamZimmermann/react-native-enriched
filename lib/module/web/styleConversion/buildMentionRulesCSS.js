"use strict";

import { isMentionStyleRecord } from "../../utils/isMentionStyleRecord.js";
import { ETI_MENTION_CSS_VARS } from "./htmlStyleToCSSVariables.js";
import { MENTION_STYLE_DEFAULT_KEY } from "./mentionIndicatorCssKey.js";
function escapeIndicatorForCssAttributeSelector(indicator) {
  if (typeof CSS !== 'undefined' && typeof CSS.escape === 'function') {
    return CSS.escape(indicator);
  }
  return indicator.replace(/["\\]/g, '\\$&');
}
export function buildMentionRulesCSS(htmlStyle) {
  const mapRaw = htmlStyle?.mention;
  if (!mapRaw || typeof mapRaw !== 'object' || !isMentionStyleRecord(mapRaw)) {
    return '';
  }
  const map = mapRaw;
  const keys = Object.keys(map);
  if (keys.length === 0) {
    return '';
  }
  const lines = [];
  for (const indicator of keys) {
    const selector = indicator === MENTION_STYLE_DEFAULT_KEY ? '.eti-editor mention' : `.eti-editor mention[indicator="${escapeIndicatorForCssAttributeSelector(indicator)}"]`;
    lines.push(`${selector} {
  color: var(${ETI_MENTION_CSS_VARS.color(indicator)});
  background-color: var(${ETI_MENTION_CSS_VARS.backgroundColor(indicator)});
  text-decoration-line: var(${ETI_MENTION_CSS_VARS.textDecorationLine(indicator)});
}`.trim());
  }
  return lines.join('\n');
}
//# sourceMappingURL=buildMentionRulesCSS.js.map