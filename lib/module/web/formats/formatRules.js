"use strict";

import { HEADING_LEVELS, HEADING_TAGS } from "./EnrichedHeading.js";
export function isAnyParagraphFormatActive(editor) {
  return editor.isActive('blockquote') || editor.isActive('codeBlock') || HEADING_LEVELS.some(level => editor.isActive('heading', {
    level
  })) || editor.isActive('orderedList') || editor.isActive('unorderedList') || editor.isActive('checkboxList');
}
export function isLinkBlocked(editor) {
  return editor.isActive('code') || editor.isActive('codeBlock') || editor.isActive('mention') || editor.isActive('image');
}
function isMentionBlocked(editor) {
  return editor.isActive('code') || editor.isActive('codeBlock') || editor.isActive('link') || editor.isActive('image');
}
export function isImageBlocked(editor) {
  return editor.isActive('code') || editor.isActive('link') || editor.isActive('mention');
}
export function isFormatBlocked(tiptapName, editor, htmlStyle) {
  if (tiptapName === 'image') {
    return isImageBlocked(editor);
  }
  if (tiptapName === 'link') {
    return isLinkBlocked(editor);
  }
  if (tiptapName === 'code' && editor.isActive('image')) {
    return true;
  }
  if (tiptapName === 'mention') {
    return isMentionBlocked(editor);
  }
  if (editor.isActive('codeBlock')) {
    return ['bold', 'italic', 'underline', 'strike', 'code'].includes(tiptapName);
  }
  for (const level of HEADING_LEVELS) {
    if (editor.isActive('heading', {
      level
    })) {
      const key = HEADING_TAGS[level - 1];
      if (tiptapName === 'bold' && htmlStyle[key].bold) return true;
    }
  }
  return false;
}
export function toggleParagraphFormat(isActive, deactivate, activate, chain) {
  if (isActive()) return deactivate();
  return activate(chain().clearNodes()).run();
}
//# sourceMappingURL=formatRules.js.map