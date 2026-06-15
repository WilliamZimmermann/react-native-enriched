"use strict";

import { findParentNodeClosestToPos } from '@tiptap/core';
import { EXCLUDED_MARKS as EXCLUDED_MARKS_BY_MENTION } from "../../formats/EnrichedMention.js";
export function isCaretInBlockedContext($from, schema) {
  for (const excludedMark of EXCLUDED_MARKS_BY_MENTION) {
    if (schema.marks[excludedMark]?.isInSet($from.marks())) return true;
  }
  return findParentNodeClosestToPos($from, n => n.type.name === 'codeBlock') != null;
}
//# sourceMappingURL=isCaretInBlockedContext.js.map