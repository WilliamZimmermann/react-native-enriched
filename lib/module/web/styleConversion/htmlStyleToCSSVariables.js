"use strict";

import { DEFAULT_HTML_STYLE } from "../../utils/defaultHtmlStyle.js";
import { expandMentionStylesForIndicators } from "../../utils/expandMentionStylesForIndicators.js";
import { HEADING_TAGS } from "../formats/EnrichedHeading.js";
import { indicatorToMentionCssKey, MENTION_STYLE_DEFAULT_KEY } from "./mentionIndicatorCssKey.js";
import { toColor } from "./toColor.js";
import { isMentionStyleRecord } from "../../utils/isMentionStyleRecord.js";
export function mergeWithDefaultHtmlStyle(htmlStyle) {
  const style = htmlStyle ?? {};
  const mentionMap = expandMentionStylesForIndicatorsIncludeDefault(style);
  const converted = {
    ...style,
    mention: mentionMap
  };
  const merged = {
    ...DEFAULT_HTML_STYLE
  };
  for (const key in converted) {
    if (key === 'mention') {
      merged[key] = {
        ...converted.mention
      };
      continue;
    }
    merged[key] = {
      ...DEFAULT_HTML_STYLE[key],
      ...converted[key]
    };
  }
  return merged;
}
const ETI_CSS_VARS = {
  codeColor: '--eti-code-color',
  codeBgColor: '--eti-code-bg-color',
  blockquoteBorderColor: '--eti-blockquote-border-color',
  blockquoteBorderWidth: '--eti-blockquote-border-width',
  blockquoteGapWidth: '--eti-blockquote-gap-width',
  blockquoteColor: '--eti-blockquote-color',
  codeblockBgColor: '--eti-codeblock-bg-color',
  codeblockColor: '--eti-codeblock-color',
  codeblockBorderRadius: '--eti-codeblock-border-radius',
  linkColor: '--eti-link-color',
  linkTextDecorationLine: '--eti-link-text-decoration-line',
  ulBulletColor: '--eti-ul-bullet-color',
  ulBulletSize: '--eti-ul-bullet-size',
  ulMarginLeft: '--eti-ul-margin-left',
  ulGapWidth: '--eti-ul-gap-width',
  olMarginLeft: '--eti-ol-margin-left',
  olGapWidth: '--eti-ol-gap-width',
  olMarkerColor: '--eti-ol-marker-color',
  olMarkerFontWeight: '--eti-ol-marker-font-weight',
  checkboxBoxSize: '--eti-checkbox-box-size',
  checkboxGapWidth: '--eti-checkbox-gap-width',
  checkboxMarginLeft: '--eti-checkbox-margin-left',
  checkboxBoxColor: '--eti-checkbox-box-color'
};
export const ETI_MENTION_CSS_VARS = {
  color: indicator => `--eti-mention-${indicatorToMentionCssKey(indicator)}-color`,
  backgroundColor: indicator => `--eti-mention-${indicatorToMentionCssKey(indicator)}-background-color`,
  textDecorationLine: indicator => `--eti-mention-${indicatorToMentionCssKey(indicator)}-text-decoration-line`
};
function setColorVar(vars, name, value) {
  const c = toColor(value);
  if (c) vars[name] = c;
}
function setPxVar(vars, name, n) {
  if (n != null) vars[name] = `${n}px`;
}
function applyCodeVars(vars, code) {
  setColorVar(vars, ETI_CSS_VARS.codeColor, code?.color);
  setColorVar(vars, ETI_CSS_VARS.codeBgColor, code?.backgroundColor);
}
function applyHeadingVars(vars, htmlStyle) {
  for (const level of HEADING_TAGS) {
    const h = htmlStyle?.[level];
    if (h?.fontSize != null) vars[`--eti-${level}-font-size`] = `${h.fontSize}px`;
    if (h?.bold != null) vars[`--eti-${level}-font-weight`] = h.bold ? 'bold' : 'normal';
  }
}
function applyBlockquoteVars(vars, bq) {
  setColorVar(vars, ETI_CSS_VARS.blockquoteBorderColor, bq?.borderColor);
  setPxVar(vars, ETI_CSS_VARS.blockquoteBorderWidth, bq?.borderWidth);
  setPxVar(vars, ETI_CSS_VARS.blockquoteGapWidth, bq?.gapWidth);
  setColorVar(vars, ETI_CSS_VARS.blockquoteColor, bq?.color);
}
function applyCodeblockVars(vars, cb) {
  setColorVar(vars, ETI_CSS_VARS.codeblockBgColor, cb?.backgroundColor);
  setColorVar(vars, ETI_CSS_VARS.codeblockColor, cb?.color);
  setPxVar(vars, ETI_CSS_VARS.codeblockBorderRadius, cb?.borderRadius);
}
function applyLinkVars(vars, anchor) {
  setColorVar(vars, ETI_CSS_VARS.linkColor, anchor?.color);
  if (anchor?.textDecorationLine != null) {
    vars[ETI_CSS_VARS.linkTextDecorationLine] = anchor.textDecorationLine;
  }
}
function applyUnorderedListVars(vars, ul) {
  setColorVar(vars, ETI_CSS_VARS.ulBulletColor, ul?.bulletColor);
  setPxVar(vars, ETI_CSS_VARS.ulBulletSize, ul?.bulletSize);
  setPxVar(vars, ETI_CSS_VARS.ulMarginLeft, ul?.marginLeft);
  setPxVar(vars, ETI_CSS_VARS.ulGapWidth, ul?.gapWidth);
}
function applyOrderedListVars(vars, ol) {
  setPxVar(vars, ETI_CSS_VARS.olMarginLeft, ol?.marginLeft);
  setPxVar(vars, ETI_CSS_VARS.olGapWidth, ol?.gapWidth);
  setColorVar(vars, ETI_CSS_VARS.olMarkerColor, ol?.markerColor);
  if (ol?.markerFontWeight != null) {
    vars[ETI_CSS_VARS.olMarkerFontWeight] = String(ol.markerFontWeight);
  }
}
function applyCheckboxListVars(vars, ulCheckbox) {
  setPxVar(vars, ETI_CSS_VARS.checkboxBoxSize, ulCheckbox?.boxSize);
  setPxVar(vars, ETI_CSS_VARS.checkboxGapWidth, ulCheckbox?.gapWidth);
  setPxVar(vars, ETI_CSS_VARS.checkboxMarginLeft, ulCheckbox?.marginLeft);
  setColorVar(vars, ETI_CSS_VARS.checkboxBoxColor, ulCheckbox?.boxColor);
}
function applyMentionVars(vars, mention) {
  for (const [indicator, mentionStyle] of Object.entries(mention)) {
    setColorVar(vars, ETI_MENTION_CSS_VARS.color(indicator), mentionStyle.color);
    setColorVar(vars, ETI_MENTION_CSS_VARS.backgroundColor(indicator), mentionStyle.backgroundColor);
    if (mentionStyle.textDecorationLine != null) {
      vars[ETI_MENTION_CSS_VARS.textDecorationLine(indicator)] = mentionStyle.textDecorationLine;
    }
  }
}
function expandMentionStylesForIndicatorsIncludeDefault(htmlStyle) {
  const mentionIndicators = isMentionStyleRecord(htmlStyle?.mention) ? Object.keys(htmlStyle?.mention) : [];
  if (!mentionIndicators.includes(MENTION_STYLE_DEFAULT_KEY)) mentionIndicators.push(MENTION_STYLE_DEFAULT_KEY);
  return expandMentionStylesForIndicators(htmlStyle?.mention, mentionIndicators);
}
export function htmlStyleToCSSVariables(htmlStyle) {
  const vars = {};
  applyCodeVars(vars, htmlStyle?.code);
  applyHeadingVars(vars, htmlStyle);
  applyBlockquoteVars(vars, htmlStyle?.blockquote);
  applyCodeblockVars(vars, htmlStyle?.codeblock);
  applyLinkVars(vars, htmlStyle?.a);
  applyUnorderedListVars(vars, htmlStyle?.ul);
  applyOrderedListVars(vars, htmlStyle?.ol);
  applyCheckboxListVars(vars, htmlStyle?.ulCheckbox);
  applyMentionVars(vars, expandMentionStylesForIndicatorsIncludeDefault(htmlStyle));
  return vars;
}
//# sourceMappingURL=htmlStyleToCSSVariables.js.map