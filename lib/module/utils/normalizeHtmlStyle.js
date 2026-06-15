"use strict";

import { processColor } from 'react-native';
import { DEFAULT_HTML_STYLE, DEFAULT_ENRICHED_TEXT_STYLE } from "./defaultHtmlStyle.js";
import { expandMentionStylesForIndicators } from "./expandMentionStylesForIndicators.js";
const MENTION_DEFAULT_KEY = '_default';
const parseOlStyles = style => {
  let markerFontWeight;
  if (style.ol?.markerFontWeight) {
    if (typeof style.ol?.markerFontWeight === 'number') {
      markerFontWeight = String(style.ol?.markerFontWeight);
    } else if (typeof style.ol?.markerFontWeight === 'string') {
      markerFontWeight = style.ol?.markerFontWeight;
    }
  }
  return {
    ...style.ol,
    markerFontWeight: markerFontWeight
  };
};
const convertToHtmlStyleInternal = (style, mentionIndicators) => {
  const mentionStyles = expandMentionStylesForIndicators(style.mention, mentionIndicators);
  let markerFontWeight;
  if (style.ol?.markerFontWeight) {
    if (typeof style.ol?.markerFontWeight === 'number') {
      markerFontWeight = String(style.ol?.markerFontWeight);
    } else if (typeof style.ol?.markerFontWeight === 'string') {
      markerFontWeight = style.ol?.markerFontWeight;
    }
  }
  const olStyles = {
    ...style.ol,
    markerFontWeight: markerFontWeight
  };
  return {
    ...style,
    mention: mentionStyles,
    ol: olStyles
  };
};
const convertToEnrichedTextHtmlStyleInternal = style => {
  const mentionStyles = {};
  const mention = style.mention;
  if (mention && typeof mention === 'object' && !Array.isArray(mention)) {
    for (const key of Object.keys(mention)) {
      const value = mention[key];
      if (typeof value === 'object' && value !== null) {
        mentionStyles[key] = {
          ...DEFAULT_ENRICHED_TEXT_STYLE.mention,
          ...value
        };
      } else {
        mentionStyles[MENTION_DEFAULT_KEY] = {
          ...DEFAULT_ENRICHED_TEXT_STYLE.mention,
          ...mention
        };
      }
    }
  }
  if (mentionStyles[MENTION_DEFAULT_KEY] === undefined) {
    mentionStyles[MENTION_DEFAULT_KEY] = {
      ...DEFAULT_ENRICHED_TEXT_STYLE.mention
    };
  }
  return {
    ...style,
    mention: mentionStyles,
    ol: parseOlStyles(style)
  };
};
const assignDefaultValues = (style, base) => {
  const merged = {
    ...base
  };
  for (const key in style) {
    if (key === 'mention') {
      merged[key] = {
        ...style.mention
      };
      continue;
    }
    merged[key] = {
      ...(base[key] ?? {}),
      ...style[key]
    };
  }
  return merged;
};
const parseStyle = (name, value) => {
  if (name !== 'color' && !name.endsWith('Color')) {
    return value;
  }
  return processColor(value);
};
const parseColors = style => {
  const finalStyle = {};
  for (const [tagName, tagStyle] of Object.entries(style)) {
    const tagStyles = {};
    if (tagName === 'mention') {
      for (const [indicator, mentionStyle] of Object.entries(tagStyle)) {
        tagStyles[indicator] = {};
        for (const [styleName, styleValue] of Object.entries(mentionStyle)) {
          tagStyles[indicator][styleName] = parseStyle(styleName, styleValue);
        }
      }
      finalStyle[tagName] = tagStyles;
      continue;
    }
    for (const [styleName, styleValue] of Object.entries(tagStyle)) {
      tagStyles[styleName] = parseStyle(styleName, styleValue);
    }
    finalStyle[tagName] = tagStyles;
  }
  return finalStyle;
};
export const normalizeHtmlStyle = (style, mentionIndicators) => {
  const converted = convertToHtmlStyleInternal(style, mentionIndicators);
  const withDefaults = assignDefaultValues(converted, DEFAULT_HTML_STYLE);
  return parseColors(withDefaults);
};
export const normalizeEnrichedTextHtmlStyle = style => {
  const converted = convertToEnrichedTextHtmlStyleInternal(style);
  const withDefaults = assignDefaultValues(converted, DEFAULT_ENRICHED_TEXT_STYLE);
  return parseColors(withDefaults);
};
//# sourceMappingURL=normalizeHtmlStyle.js.map